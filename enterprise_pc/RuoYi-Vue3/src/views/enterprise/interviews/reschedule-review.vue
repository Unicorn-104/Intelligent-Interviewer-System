<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import { listRescheduleRequests, getRescheduleRequest, reviewRescheduleRequest } from '@/api/interview'
import { pendingRescheduleCount, refreshPendingReschedule } from '@/views/enterprise/store/reschedule'

const route = useRoute()
const router = useRouter()
const TABS = [
  { key: 'pending', label: '待审批' },
  { key: 'approved', label: '已通过' },
  { key: 'rejected', label: '已驳回' },
  { key: '', label: '全部' }
]
// rsr_status：0-pending，1-approved，2-rejected，由后端直出字符串
const STATUS = {
  pending: { text: '待审批', cls: 'orange' },
  approved: { text: '已通过', cls: 'green' },
  rejected: { text: '已驳回', cls: 'red' }
}

const status = ref(['pending', 'approved', 'rejected'].includes(String(route.query.status)) ? String(route.query.status) : 'pending')
const rows = ref([])
const total = ref(0)
const pageNum = ref(1)
const pageSize = ref(20)
const loading = ref(false)
const error = ref('')
const pendingCount = pendingRescheduleCount
const detail = ref(null)
const target = ref(null)
const decision = ref('approved')
const note = ref('')
const noteError = ref('')
const submitting = ref(false)
const notice = ref('')

const pages = computed(() => Math.max(1, Math.ceil(total.value / pageSize.value)))
const canPrev = computed(() => pageNum.value > 1)
const canNext = computed(() => pageNum.value < pages.value)
const statusLabel = computed(() => (TABS.find(t => t.key === status.value) || {}).label || '')

async function load() {
  loading.value = true
  error.value = ''
  try {
    const params = { pageNum: pageNum.value, pageSize: pageSize.value }
    if (status.value) params.status = status.value
    const res = await listRescheduleRequests(params)
    rows.value = res.rows || []
    total.value = Number(res.total) || 0
  } catch (e) {
    rows.value = []
    total.value = 0
    error.value = (e && e.message) || '改期申请加载失败，请重试'
  } finally {
    loading.value = false
  }
}

function switchTab(key) {
  if (status.value === key) return
  status.value = key
  pageNum.value = 1
  load()
}

function flip(delta) {
  const next = pageNum.value + delta
  if (next < 1 || next > pages.value) return
  pageNum.value = next
  load()
}

async function openDetail(row) {
  detail.value = row
  try {
    const res = await getRescheduleRequest(row.requestId)
    if (res.data) detail.value = res.data
  } catch {
    // 详情接口异常时展示列表行数据
  }
}

function openReview(row, type) {
  target.value = row
  decision.value = type
  note.value = ''
  noteError.value = ''
}

function closeReview() {
  if (submitting.value) return
  target.value = null
}

async function submitReview() {
  const text = note.value.trim()
  if (decision.value === 'rejected' && !text) {
    noteError.value = '驳回时必须填写审批说明'
    return
  }
  if (text.length > 500) {
    noteError.value = '审批说明不能超过 500 字'
    return
  }
  submitting.value = true
  noteError.value = ''
  try {
    await reviewRescheduleRequest(target.value.requestId, decision.value, text)
    const approved = decision.value === 'approved'
    target.value = null
    await load()
    refreshPendingReschedule()
    notice.value = approved ? '已通过改期申请，面试时间已更新' : '已驳回改期申请'
    setTimeout(() => { notice.value = '' }, 2600)
  } catch (e) {
    noteError.value = (e && e.message) || '审批失败，请刷新后重试'
  } finally {
    submitting.value = false
  }
}

function timeRange(start, end) {
  return [start, end].filter(Boolean).join(' ~ ') || '-'
}
function statusInfo(v) {
  return STATUS[v] || { text: v || '-', cls: 'gray' }
}

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <div>
        <h1>改期审批</h1>
        <p>候选人提交的面试改期申请，通过后按新时段更新面试安排并通知相关人员</p>
      </div>
      <button class="btn" @click="router.push('/enterprise/interviews')">返回面试安排</button>
    </div>

    <div class="card panel">
      <div class="tabs">
        <button v-for="t in TABS" :key="t.key" :class="{ active: status === t.key }" @click="switchTab(t.key)">
          {{ t.label }}<em v-if="t.key === 'pending' && pendingCount">{{ pendingCount }}</em>
        </button>
      </div>

      <div v-if="error" class="state">
        <span>{{ error }}</span>
        <button class="btn sm ghost-primary" @click="load">重试</button>
      </div>
      <div v-else-if="loading" class="empty">加载中…</div>
      <div v-else-if="!rows.length" class="empty">暂无{{ statusLabel }}的改期申请</div>

      <table v-else class="list">
        <thead>
          <tr>
            <th>候选人 / 岗位</th>
            <th>原面试时间</th>
            <th>申请新时间</th>
            <th>申请理由</th>
            <th>申请时间</th>
            <th>状态</th>
            <th class="ops-col">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in rows" :key="r.requestId">
            <td>
              <b class="name">{{ r.candidateName || '-' }}</b>
              <small class="muted">{{ r.positionName || '-' }}</small>
            </td>
            <td>{{ timeRange(r.originalStartTime, r.originalEndTime) }}</td>
            <td class="new-time">{{ timeRange(r.newStartTime, r.newEndTime) }}</td>
            <td><span class="reason" :title="r.reason">{{ r.reason || '-' }}</span></td>
            <td>{{ r.requestedAt || '-' }}</td>
            <td><span class="pill" :class="statusInfo(r.status).cls">{{ statusInfo(r.status).text }}</span></td>
            <td class="ops">
              <button class="btn sm" @click="openDetail(r)">查看</button>
              <template v-if="r.status === 'pending'">
                <button class="btn sm primary" @click="openReview(r, 'approved')">通过</button>
                <button class="btn sm danger-ghost" @click="openReview(r, 'rejected')">驳回</button>
              </template>
            </td>
          </tr>
        </tbody>
      </table>

      <div v-if="!loading && !error && rows.length" class="pager">
        <span class="muted">共 {{ total }} 条</span>
        <button class="btn sm" :disabled="!canPrev" @click="flip(-1)">上一页</button>
        <span>{{ pageNum }} / {{ pages }}</span>
        <button class="btn sm" :disabled="!canNext" @click="flip(1)">下一页</button>
      </div>
    </div>

    <BaseModal v-if="detail" title="改期申请详情" width="600px" @close="detail = null">
      <div class="detail">
        <div><span>候选人</span><b>{{ detail.candidateName || '-' }}</b></div>
        <div><span>岗位</span><b>{{ detail.positionName || '-' }}</b></div>
        <div><span>原面试时间</span><b>{{ timeRange(detail.originalStartTime, detail.originalEndTime) }}</b></div>
        <div><span>申请新时间</span><b class="text-primary">{{ timeRange(detail.newStartTime, detail.newEndTime) }}</b></div>
        <div><span>面试官</span><b>{{ detail.interviewerName || '-' }}</b></div>
        <div><span>申请理由</span><b>{{ detail.reason || '-' }}</b></div>
        <div><span>申请时间</span><b>{{ detail.requestedAt || '-' }}</b></div>
        <div><span>状态</span><b><span class="pill" :class="statusInfo(detail.status).cls">{{ statusInfo(detail.status).text }}</span></b></div>
        <div v-if="detail.reviewNote"><span>审批说明</span><b>{{ detail.reviewNote }}</b></div>
        <div v-if="detail.reviewedAt"><span>审批时间</span><b>{{ detail.reviewedAt }}</b></div>
      </div>
      <template #footer>
        <button class="btn" @click="detail = null">关闭</button>
        <template v-if="detail.status === 'pending'">
          <button class="btn danger-ghost" @click="openReview(detail, 'rejected'); detail = null">驳回</button>
          <button class="btn primary" @click="openReview(detail, 'approved'); detail = null">通过</button>
        </template>
      </template>
    </BaseModal>

    <BaseModal v-if="target" :title="decision === 'approved' ? '通过改期申请' : '驳回改期申请'" width="540px" @close="closeReview">
      <p class="review-tip">
        候选人 <b>{{ target.candidateName }}</b> 申请将 <b>{{ target.positionName }}</b> 的面试从
        <b>{{ timeRange(target.originalStartTime, target.originalEndTime) }}</b> 调整为
        <b class="text-primary">{{ timeRange(target.newStartTime, target.newEndTime) }}</b>。
      </p>
      <p v-if="decision === 'approved'" class="review-tip">通过后立即按新时段更新面试安排，并通知候选人与面试官。</p>
      <div class="field">
        <label>{{ decision === 'approved' ? '审批说明（选填）' : '驳回原因（必填）' }}</label>
        <textarea v-model="note" class="textarea" maxlength="500" :placeholder="decision === 'approved' ? '可填写本次调整的说明' : '请说明驳回原因，将展示给候选人'"></textarea>
        <small class="counter">{{ note.length }}/500</small>
        <small v-if="noteError" class="error-text">{{ noteError }}</small>
      </div>
      <template #footer>
        <button class="btn" :disabled="submitting" @click="closeReview">取消</button>
        <button class="btn" :class="decision === 'approved' ? 'primary' : 'danger'" :disabled="submitting" @click="submitReview">
          {{ submitting ? '提交中…' : (decision === 'approved' ? '确认通过' : '确认驳回') }}
        </button>
      </template>
    </BaseModal>

    <div v-if="notice" class="toast">{{ notice }}</div>
  </div>
</template>

<style scoped>
.panel { padding: 0 0 16px; overflow: hidden; }
.tabs { display: flex; gap: 6px; padding: 16px 20px 12px; border-bottom: 1px solid var(--line); }
.tabs button { height: 32px; padding: 0 14px; border: 0; border-radius: 8px; background: #f2f5fa; color: var(--muted); font-size: 13px; display: inline-flex; align-items: center; gap: 6px; }
.tabs button.active { background: var(--primary-soft); color: var(--primary); font-weight: 600; }
.tabs em { font-style: normal; min-width: 18px; height: 18px; padding: 0 5px; border-radius: 9px; background: #ef4444; color: #fff; font-size: 10px; display: grid; place-items: center; }
.state { display: flex; align-items: center; justify-content: center; gap: 12px; padding: 40px; color: var(--red); }
.list { width: 100%; border-collapse: collapse; font-size: 13px; }
.list th { text-align: left; padding: 12px 16px; color: var(--muted); font-weight: 600; background: #f8fafd; white-space: nowrap; }
.list td { padding: 13px 16px; border-top: 1px solid var(--line); vertical-align: middle; }
.list .name { display: block; font-size: 13px; }
.list .muted { color: var(--muted); font-size: 12px; }
.new-time { color: var(--primary); font-weight: 600; }
.reason { display: inline-block; max-width: 180px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; vertical-align: bottom; }
.ops-col { width: 200px; }
.ops { display: flex; gap: 6px; }
.pager { display: flex; align-items: center; justify-content: flex-end; gap: 10px; padding: 14px 20px 0; font-size: 12px; }
.detail { display: grid; gap: 14px; }
.detail > div { display: grid; grid-template-columns: 96px 1fr; gap: 12px; font-size: 13px; }
.detail span { color: var(--muted); }
.review-tip { font-size: 13px; line-height: 1.8; color: var(--muted); margin-bottom: 14px; }
.review-tip b { color: var(--text); }
.counter { display: block; margin-top: 6px; color: var(--subtle); font-size: 12px; text-align: right; }
.error-text { display: block; margin-top: 6px; color: var(--red); font-size: 12px; }
.toast { position: fixed; left: 50%; bottom: 46px; transform: translateX(-50%); z-index: 200; padding: 10px 18px; border-radius: 9px; background: rgba(21, 34, 59, .92); color: #fff; font-size: 13px; box-shadow: 0 10px 24px rgba(15, 23, 42, .2); }
</style>
