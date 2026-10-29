<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  SlidersHorizontal, ChevronRight, UserRoundCheck, ArrowUpRight, BriefcaseBusiness,
  FileText, Sparkles, GraduationCap, Bookmark, Clock3, CircleCheckBig
} from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { getTalentResume, listApplications, listUnscreenedPositions, screenUnscreenedApplicants } from '@/api/talent'
import { screenAllPending } from '@/api/screening'

const router = useRouter()
const toast = ref('')
const loading = ref(false)
const positionsLoading = ref(false)
const screening = ref(false)
const positions = ref([])
// 待初筛人数由后端按人去重统计，同一人投多个岗位只算一位
const candidateCount = ref(0)
const activePosition = ref(null)
const statusFilter = ref('')
const applicants = ref([])
const total = ref(0)
const pageNum = ref(1)
const pageSize = 10

// 投递状态（t_app_record.app_status）
const APP_STATUS = {
  0: ['待筛选', 'gray'], 1: ['初筛通过', 'green'], 2: ['初筛淘汰', 'red'], 3: ['已约面', 'blue'],
  4: ['待笔试', 'orange'], 5: ['笔试中', 'orange'], 6: ['笔试通过', 'green'], 7: ['笔试未通过', 'red'], 8: ['笔试缺考', 'gray']
}
// Offer 状态（t_off_offer.ofr_status），存在 Offer 时覆盖投递状态显示
const OFFER_STATUS = { 0: ['Offer 已发送', 'purple'], 1: ['已录取', 'green'], 2: ['Offer 已拒绝', 'red'], 3: ['Offer 已过期', 'gray'], 4: ['Offer 草稿', 'gray'], 5: ['Offer 审批中', 'orange'], 6: ['Offer 已撤回', 'gray'] }
const STATUS_OPTIONS = Object.keys(APP_STATUS).map(k => ({ value: Number(k), label: APP_STATUS[k][0] }))

// 简历解析详情
const resumeOpen = ref(false)
const resumeRow = ref(null)
const resumeData = ref(null)

const positionCount = computed(() => positions.value.length)
const activeTitle = computed(() => (activePosition.value ? activePosition.value.positionName : '全部岗位'))
const activePending = computed(() => (activePosition.value ? activePosition.value.pendingCount : candidateCount.value))
const canScreen = computed(() => !screening.value && Number(activePending.value || 0) > 0)

function displayStatus(row) {
  if (row.offerStatus !== null && row.offerStatus !== undefined && OFFER_STATUS[row.offerStatus]) return OFFER_STATUS[row.offerStatus]
  return APP_STATUS[row.appStatus] || ['待筛选', 'gray']
}

function scoreText(row) {
  return row.matchedScore == null ? '—' : Number(row.matchedScore).toFixed(1)
}

function notify(v) {
  toast.value = v
  setTimeout(() => (toast.value = ''), 2600)
}

async function loadPositions() {
  positionsLoading.value = true
  try {
    const res = await listUnscreenedPositions()
    positions.value = res.data?.rows || []
    candidateCount.value = Number(res.data?.candidateCount || 0)
    // 刷新后同步选中岗位的最新待初筛人数
    if (activePosition.value) {
      const latest = positions.value.find(p => p.positionId === activePosition.value.positionId)
      activePosition.value = latest || { ...activePosition.value, pendingCount: 0 }
    }
  } catch (e) {
    positions.value = []
    candidateCount.value = 0
  } finally {
    positionsLoading.value = false
  }
}

async function loadApplicants() {
  loading.value = true
  try {
    const q = { pageNum: pageNum.value, pageSize }
    if (activePosition.value) q.positionId = activePosition.value.positionId
    if (statusFilter.value !== '') q.status = statusFilter.value
    const res = await listApplications(q)
    applicants.value = res.rows || []
    total.value = res.total || 0
  } catch (e) {
    applicants.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

function selectPosition(p) {
  activePosition.value = p
  pageNum.value = 1
  loadApplicants()
}

function applyFilter() {
  pageNum.value = 1
  loadApplicants()
}

async function refresh() {
  await Promise.all([loadPositions(), loadApplicants()])
}

function step(delta) {
  const next = pageNum.value + delta
  if (next < 1 || (next - 1) * pageSize >= total.value) return
  pageNum.value = next
  loadApplicants()
}

// 初筛在后台异步执行，提交后短时轮询，让状态和分数尽快刷新到页面
let pollingTimer = null
function stopPolling() {
  if (pollingTimer) {
    clearInterval(pollingTimer)
    pollingTimer = null
  }
}
function startPolling() {
  stopPolling()
  let times = 0
  pollingTimer = setInterval(async () => {
    times++
    await refresh()
    if (times >= 20 || Number(activePending.value || 0) === 0) stopPolling()
  }, 15000)
}

async function triggerScreening() {
  screening.value = true
  try {
    if (activePosition.value) {
      await screenUnscreenedApplicants({ positionId: activePosition.value.positionId })
      notify('已提交 AI 初筛，正在后台分析，结果见「AI 初筛详情」')
    } else {
      const res = await screenAllPending()
      const data = res.data || {}
      notify(`已提交 ${data.queuedPositions || 0} 个岗位的 AI 初筛，正在后台分析，结果见「AI 初筛详情」`)
    }
    pageNum.value = 1
    await refresh()
    startPolling()
  } catch (e) {
    notify(e?.response?.data?.msg || e?.message || 'AI 初筛提交失败，请稍后重试')
  } finally {
    screening.value = false
  }
}

function openResume(row) {
  resumeRow.value = row
  resumeData.value = null
  resumeOpen.value = true
  getTalentResume(row.talentId).then(res => { resumeData.value = res.data }).catch(() => { resumeData.value = null })
}

onMounted(() => {
  loadPositions()
  loadApplicants()
})

onBeforeUnmount(stopPolling)
</script>

<template>
  <div class="applications-panel">
    <div class="unscreened-layout">
      <aside class="card pos-panel">
        <div class="pos-head">
          <div class="pos-head-main"><b>岗位</b><em>{{ positionCount }}</em></div>
          <small>{{ positionCount }} 个岗位存在待初筛投递</small>
        </div>
        <div v-if="positionsLoading" class="empty sm">加载中…</div>
        <div v-else class="pos-list">
          <button class="pos-item" :class="{ active: !activePosition }" @click="selectPosition(null)">
            <span class="pos-name">全部岗位</span>
            <em>{{ candidateCount }}</em>
          </button>
          <button
            v-for="p in positions"
            :key="p.positionId"
            class="pos-item"
            :class="{ active: activePosition?.positionId === p.positionId }"
            @click="selectPosition(p)"
          >
            <span class="pos-name">
              {{ p.positionName }}
              <small>{{ p.city || '城市未填' }}</small>
            </span>
            <em>{{ p.pendingCount }}</em>
          </button>
          <div v-if="!positions.length" class="empty sm">
            <CircleCheckBig :size="22" />
            <p>所有投递均已完成 AI 初筛</p>
          </div>
        </div>
      </aside>

      <section class="card list-card">
        <div class="toolbar">
          <div class="current">
            <b>{{ activeTitle }}</b>
            <span>待初筛 {{ activePending }} 位 · 共 {{ total }} 条投递</span>
          </div>
          <label class="status-filter">
            <SlidersHorizontal :size="14" />
            <select v-model="statusFilter" @change="applyFilter">
              <option value="">全部状态</option>
              <option v-for="opt in STATUS_OPTIONS" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
            </select>
          </label>
          <button class="filter-btn" @click="refresh">刷新</button>
          <button class="btn primary screen-btn" :disabled="!canScreen" @click="triggerScreening">
            <Sparkles :size="15" />{{ screening ? '提交中…' : '发起 AI 初筛' }}
          </button>
        </div>

        <div class="table-wrap">
          <div v-if="loading" class="empty">加载中…</div>
          <div v-else-if="!applicants.length" class="empty-state">
            <div class="empty-icon"><UserRoundCheck :size="26" /></div>
            <b>暂无投递记录</b>
            <p>{{ activePosition ? '该岗位还没有投递，或与当前状态筛选不符' : '当前还没有任何投递' }}</p>
          </div>
          <div v-else class="applicant-table">
            <div class="table-head">
              <span>候选人</span><span>联系方式</span><span>投递岗位</span><span>匹配度</span><span>投递时间</span><span>状态</span><span>操作</span>
            </div>
            <article v-for="row in applicants" :key="row.applicationId" class="table-row">
              <div class="person">
                <MiniAvatar :name="row.name || '?'" :size="36" color="#2563eb" />
                <div><b>{{ row.name || '未知候选人' }}</b><small>投递编号 #{{ row.applicationId }}</small></div>
              </div>
              <span>{{ row.phone || '手机号缺失' }}</span>
              <span class="pos-cell">{{ row.positionName || '—' }}</span>
              <span class="score-cell" :class="{ 'no-score': row.matchedScore == null }">{{ scoreText(row) }}</span>
              <time><Clock3 :size="12" />{{ row.appliedAt || '—' }}</time>
              <span><span class="pill" :class="displayStatus(row)[1]">{{ displayStatus(row)[0] }}</span></span>
              <div class="ops">
                <button class="act-btn" @click="openResume(row)"><FileText :size="13" />简历</button>
                <button class="act-btn" @click="router.push(`/enterprise/candidates/${row.talentId}/process`)"><ArrowUpRight :size="13" />流程</button>
              </div>
            </article>
          </div>
        </div>

        <div v-if="total > pageSize" class="pager">
          <button class="btn sm" :disabled="pageNum <= 1" @click="step(-1)"><ChevronRight :size="13" style="transform:rotate(180deg)" />上一页</button>
          <span>{{ pageNum }} / {{ Math.ceil(total / pageSize) }} 页 · 共 {{ total }} 条</span>
          <button class="btn sm" :disabled="pageNum * pageSize >= total" @click="step(1)">下一页<ChevronRight :size="13" /></button>
        </div>
      </section>
    </div>

    <BaseModal v-if="resumeOpen" title="候选人简历" width="620px" @close="resumeOpen = false">
      <div class="detail-grid">
        <div class="d-item"><label>候选人</label><b>{{ resumeRow?.name || '—' }}</b></div>
        <div class="d-item"><label>简历完整度</label><b>{{ resumeData ? (resumeData.integrity + '%') : '读取中…' }}</b></div>
      </div>
      <div class="resume-block">
        <h3><GraduationCap :size="15" />教育经历</h3>
        <div v-if="!resumeData || !resumeData.educationList.length" class="empty sm">暂无教育经历</div>
        <ul v-else class="resume-list">
          <li v-for="(e, i) in resumeData.educationList" :key="i">
            <b>{{ e.school || '—' }}</b><span>{{ e.major || '—' }} · {{ e.degree ? '学历' + e.degree : '—' }}</span><small>{{ e.startDate || '' }} ~ {{ e.endDate || '' }}</small>
          </li>
        </ul>
      </div>
      <div class="resume-block">
        <h3><BriefcaseBusiness :size="15" />工作经历</h3>
        <div v-if="!resumeData || !resumeData.workList.length" class="empty sm">暂无工作经历</div>
        <ul v-else class="resume-list">
          <li v-for="(w, i) in resumeData.workList" :key="i">
            <b>{{ w.company || '—' }}</b><span>{{ w.position || '—' }}</span><small>{{ w.startDate || '' }} ~ {{ w.endDate || '' }}</small>
          </li>
        </ul>
      </div>
      <div class="resume-block">
        <h3><Bookmark :size="15" />技能标签</h3>
        <div v-if="!resumeData || !resumeData.skills.length" class="empty sm">暂无技能标签</div>
        <div v-else class="tags-cell">
          <span v-for="(s, i) in resumeData.skills" :key="i" class="tag">{{ s.name }}<template v-if="s.level">·{{ s.level }}</template></span>
        </div>
      </div>
      <template #footer>
        <button class="btn" @click="resumeOpen = false">关闭</button>
      </template>
    </BaseModal>

    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.unscreened-layout{display:grid;grid-template-columns:250px minmax(0,1fr);gap:14px;height:calc(100vh - 250px);min-height:470px}

.pos-panel{padding:0;display:flex;flex-direction:column;overflow:hidden}
.pos-head{padding:14px 15px 11px;border-bottom:1px solid #e8edf4}
.pos-head-main{display:flex;align-items:center;gap:7px}
.pos-head-main b{font-size:13px;color:#1e293b}
.pos-head-main em{font-style:normal;display:inline-flex;align-items:center;justify-content:center;box-sizing:border-box;min-width:20px;height:20px;padding:0 5px;border-radius:999px;background:#edf4ff;color:#2563eb;font-size:10px;font-weight:600;line-height:1;font-variant-numeric:tabular-nums}
.pos-head small{display:block;margin-top:3px;color:#8da0ba;font-size:10px}
.pos-list{flex:1;overflow:auto;padding:8px}
.pos-item{display:flex;align-items:center;gap:8px;width:100%;border:0;background:transparent;border-radius:9px;padding:9px 10px;text-align:left;cursor:pointer;color:#52657f;font-size:12px;transition:background .15s}
.pos-item:hover{background:#f4f7fc}
.pos-item.active{background:#edf4ff;color:#1d4ed8;font-weight:600}
.pos-name{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.pos-name small{display:block;font-size:9px;color:#8da0ba;font-weight:400;margin-top:2px}
.pos-item em{flex:0 0 auto;font-style:normal;display:inline-flex;align-items:center;justify-content:center;box-sizing:border-box;min-width:20px;height:20px;padding:0 5px;border-radius:999px;background:#e8eef8;color:#52657f;font-size:10px;line-height:1;font-variant-numeric:tabular-nums}
.pos-item.active em{background:#2563eb;color:#fff}

.list-card{padding:0;display:flex;flex-direction:column;overflow:hidden}
.toolbar{display:flex;align-items:center;gap:10px;padding:13px 16px;border-bottom:1px solid #e5ebf3;flex-wrap:wrap}
.current{display:flex;align-items:baseline;gap:8px;margin-right:auto;min-width:0}
.current b{font-size:13px;color:#1e293b;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.current span{font-size:10px;color:#7f8ea3;white-space:nowrap}
.status-filter{display:flex;align-items:center;gap:6px;border:1px solid #dce4ee;border-radius:9px;padding:0 10px;height:36px;color:#8da0ba}
.status-filter select{border:0;outline:0;background:transparent;font-size:12px;color:var(--text);cursor:pointer}
.filter-btn{height:36px;border:1px solid #dce4ee;border-radius:9px;background:#fff;color:#52657f;display:flex;gap:6px;align-items:center;padding:0 13px;cursor:pointer}
.filter-btn:hover{background:#f4f7fc}
.screen-btn{height:36px;display:inline-flex;align-items:center;gap:6px}
.screen-btn:disabled{opacity:.55;cursor:not-allowed}

.table-wrap{flex:1;overflow:auto;padding:0 16px}
.applicant-table{min-width:760px}
.table-head,.table-row{display:grid;grid-template-columns:1.5fr 1fr 1.25fr .7fr 1.05fr .85fr 1.1fr;gap:10px;align-items:center}
.table-head{position:sticky;top:0;z-index:1;height:36px;padding:0 8px;background:#f6f8fb;color:#8593a7;font-size:9px}
.table-row{min-height:68px;padding:9px 8px;border-bottom:1px solid #edf1f7;font-size:10px;color:#5e718c;transition:background .15s}
.table-row:hover{background:#f8faff}
.person{display:flex;align-items:center;gap:9px;min-width:0}
.person b,.person small{display:block}
.person b{font-size:12px;color:#1e293b}
.person small{color:#7f8ea3;font-size:9px;margin-top:3px}
.pos-cell{color:#334155}
.score-cell{font-variant-numeric:tabular-nums;color:#1d4ed8;font-weight:600}
.score-cell.no-score{color:#a4b0c2;font-weight:400}
.table-row time{display:flex;align-items:center;gap:4px;color:#8d9aae;font-size:9px}
.ops{display:flex;gap:6px}
.act-btn{display:inline-flex;align-items:center;gap:3px;height:24px;padding:0 8px;border:1px solid #dbe5f5;border-radius:6px;background:#fff;color:#2563eb;font-size:9px;cursor:pointer}
.act-btn:hover{background:#edf4ff;border-color:#b8ccf8}

.empty{color:#a4b0c2;text-align:center;padding:40px;font-size:11px}
.empty.sm{padding:18px 8px;font-size:10px}
.empty svg{display:block;margin:0 auto 8px}
.empty-state{display:flex;flex-direction:column;align-items:center;text-align:center;padding:56px 20px;color:#8da0ba}
.empty-icon{width:52px;height:52px;border-radius:50%;background:#f1f5fb;display:grid;place-items:center;color:#a9bdd7;margin-bottom:12px}
.empty-state b{font-size:13px;color:#334155}
.empty-state p{font-size:10px;color:#8da0ba;margin:6px 0 14px}

.pager{display:flex;align-items:center;justify-content:center;gap:14px;padding:12px 16px;border-top:1px solid #eef2f7;color:#718198;font-size:10px}
.pager button{display:inline-flex;align-items:center;gap:3px}
.pager button:disabled{opacity:.5}

.detail-grid{display:grid;grid-template-columns:1fr 1fr;gap:11px}
.d-item{background:#f7f9fc;border-radius:9px;padding:10px 12px}
.d-item label{display:block;font-size:9px;color:#8da0ba;margin-bottom:4px}
.d-item b{font-size:12px;color:#1e293b;font-weight:500}
.resume-block{margin-top:16px;border-top:1px dashed #e2e8f0;padding-top:13px}
.resume-block h3{display:flex;align-items:center;gap:6px;font-size:13px;color:#334155;margin-bottom:10px}
.resume-list{list-style:none;display:flex;flex-direction:column;gap:9px}
.resume-list li{background:#f7f9fc;border-radius:9px;padding:9px 12px}
.resume-list li b{font-size:12px;color:#1e293b}
.resume-list li span{display:block;color:#5e718c;font-size:10px;margin-top:3px}
.resume-list li small{display:block;color:#8d9aae;font-size:9px;margin-top:3px}
.tags-cell{display:flex;flex-wrap:wrap;gap:4px}
.tags-cell .tag{font-size:9px;padding:2px 6px;color:#2563eb;background:#edf4ff;border-radius:4px}
</style>
