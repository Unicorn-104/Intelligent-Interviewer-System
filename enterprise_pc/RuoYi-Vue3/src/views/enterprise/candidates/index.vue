<script setup>
import { computed, ref, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Search, Tags, SlidersHorizontal, ArrowUpRight, UserRoundCheck, FileText, Send, ChevronRight, GraduationCap, BriefcaseBusiness, Bookmark, MessageCircle } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listTalents, getTalentResume, updateTalentStatus, batchTalentTags } from '@/api/talent'

const router = useRouter()
const route = useRoute()
const toast = ref('')
const loading = ref(false)
const keyword = ref('')
// 顶栏搜索跳转时通过 ?keyword= 带入关键字
keyword.value = typeof route.query.keyword === 'string' ? route.query.keyword : ''
const statusFilter = ref('')
const batchStatus = ref('')
const selected = ref([])
const talents = ref([])
const total = ref(0)
const pageNum = ref(1)
const pageSize = 10

// 流程状态（t_tal.tal_status）
const STATUS = {
  0: ['新入库', 'gray'], 1: ['初筛通过', 'green'], 2: ['面试中', 'purple'], 3: ['已淘汰', 'red'],
  4: ['已录用', 'green'], 5: ['待笔试', 'orange'], 6: ['笔试中', 'orange'], 7: ['笔试通过', 'green'],
  8: ['笔试未通过', 'red'], 9: ['笔试缺考', 'gray']
}
const STATUS_OPTIONS = Object.keys(STATUS).map(k => ({ value: Number(k), label: STATUS[k][0] }))

const allSelected = computed(() => talents.value.length > 0 && selected.value.length === talents.value.length)

// 简历解析详情
const resumeOpen = ref(false)
const resumeRow = ref(null)
const resumeData = ref(null)

function notify(v) { toast.value = v; setTimeout(() => toast.value = '', 2200) }

async function load() {
  loading.value = true
  try {
    const q = { pageNum: pageNum.value, pageSize }
    if (keyword.value) q.keyword = keyword.value
    if (statusFilter.value !== '') q.status = statusFilter.value
    const res = await listTalents(q)
    talents.value = res.rows || []
    total.value = res.total || 0
    selected.value = []
  } catch (e) {
    talents.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

function search() { pageNum.value = 1; load() }
// 与候选人建立聊天通道：跳转消息中心并按 peerId 进入新会话（首次发送时后端自动建会话）
function openChat(row) {
  if (!row.userId) return notify('该候选人未绑定用户账号，无法发起聊天')
  router.push({ path: '/enterprise/messages', query: { peerId: row.userId, peerName: row.name || ('用户' + row.userId) } })
}
// 已在该页面时再次使用顶栏搜索，跟随 query 变化重新查询
watch(() => route.query.keyword, (kw) => {
  keyword.value = typeof kw === 'string' ? kw : ''
  search()
})
function step(delta) {
  const next = pageNum.value + delta
  if (next < 1 || (next - 1) * pageSize >= total.value) return
  pageNum.value = next
  load()
}

function toggleSelect(id) {
  const i = selected.value.indexOf(id)
  if (i >= 0) selected.value.splice(i, 1)
  else selected.value.push(id)
}
function toggleSelectAll() {
  selected.value = allSelected.value ? [] : talents.value.map(t => t.talentId)
}

// 批量加标签：真实写入 t_tal_tag
const tagOpen = ref(false)
const tagNameInput = ref('')
const tagBusy = ref(false)

function batchTag() {
  if (!selected.value.length) return notify('请先选择候选人')
  tagNameInput.value = ''
  tagOpen.value = true
}

async function submitTag() {
  if (!tagNameInput.value.trim()) return notify('请填写标签名称')
  tagBusy.value = true
  try {
    const res = await batchTalentTags(selected.value, tagNameInput.value.trim())
    notify(res.data?.message || '标签已添加')
    tagOpen.value = false
  } catch (e) { /* 拦截器已提示 */ } finally {
    tagBusy.value = false
  }
}

async function submitStatus() {
  if (!selected.value.length) return notify('请先选择候选人')
  if (batchStatus.value === '') return notify('请选择要更新到的状态')
  try {
    const res = await updateTalentStatus(selected.value, batchStatus.value)
    notify(res.data?.message || '状态已更新')
    await load()
  } catch (e) { /* 拦截器已提示 */ }
}

async function openResume(row) {
  resumeRow.value = row
  resumeData.value = null
  resumeOpen.value = true
  try {
    const res = await getTalentResume(row.talentId)
    resumeData.value = res.data
  } catch (e) { resumeData.value = null }
}

onMounted(load)
</script>

<template>
  <div class="page candidates-page">
    <div class="page-heading">
      <div><h1>候选人管理</h1><p>候选人流程状态与匹配度管理 · 共 {{ total }} 位候选人</p></div>
    </div>

    <section class="card list-card">
      <div class="toolbar">
        <label class="search-box"><Search :size="16" /><input v-model="keyword" placeholder="搜索姓名或手机号" @keyup.enter="search" /></label>
        <select v-model="statusFilter" class="select" @change="search">
          <option value="">全部状态</option>
          <option v-for="s in STATUS_OPTIONS" :key="s.value" :value="s.value">{{ s.label }}</option>
        </select>
        <button class="filter-btn" @click="search"><SlidersHorizontal :size="15" />筛选</button>
      </div>

      <!-- 批量操作栏：仅在勾选了候选人时显示 -->
      <div v-if="selected.length" class="batch-bar">
        <span>已选 {{ selected.length }} 人</span>
        <button class="btn sm" @click="batchTag"><Tags :size="14" />批量加标签</button>
        <select v-model="batchStatus" class="select sm-select">
          <option value="">更新为…</option>
          <option v-for="s in STATUS_OPTIONS" :key="s.value" :value="s.value">{{ s.label }}</option>
        </select>
        <button class="btn sm primary" @click="submitStatus"><Send :size="14" />批量更新状态</button>
      </div>

      <div v-if="loading" class="empty">加载中…</div>
      <div v-else-if="!talents.length" class="empty">
        <UserRoundCheck :size="26" />
        <p>暂无候选人数据，可调整检索条件或等待新的候选简历入库</p>
      </div>
      <div v-else class="candidate-table">
        <div class="table-head">
          <span class="ck"><input type="checkbox" :checked="allSelected" @change="toggleSelectAll" /></span>
          <span>候选人</span><span>匹配度</span><span>当前阶段</span><span>状态</span><span>更新时间</span><span>操作</span>
        </div>
        <article v-for="row in talents" :key="row.talentId" class="table-row">
          <span class="ck"><input type="checkbox" :checked="selected.includes(row.talentId)" @change="toggleSelect(row.talentId)" /></span>
          <div class="person">
            <MiniAvatar :name="row.name || '?'" :size="34" color="#2563eb" />
            <div><b>{{ row.name || '未知候选人' }}</b><small>{{ row.phone || '手机号缺失' }}</small></div>
          </div>
          <span class="score">{{ row.matchedScore != null ? row.matchedScore + '%' : '—' }}</span>
          <span class="stage-text">{{ row.currentRound > 0 ? '第 ' + row.currentRound + ' 轮' : '—' }}</span>
          <span class="pill" :class="STATUS[row.status]?.[1]">{{ STATUS[row.status]?.[0] || '未知' }}</span>
          <time>{{ row.updateTime || '—' }}</time>
          <div class="ops">
            <button @click="router.push(`/enterprise/candidates/${row.talentId}/process`)"><ArrowUpRight :size="13" />流程</button>
            <button @click="openResume(row)"><FileText :size="13" />简历</button>
            <button @click="openChat(row)"><MessageCircle :size="13" />聊天</button>
          </div>
        </article>
      </div>

      <div v-if="total > pageSize" class="pager">
        <button class="btn sm" :disabled="pageNum <= 1" @click="step(-1)"><ChevronRight :size="13" style="transform:rotate(180deg)" />上一页</button>
        <span>{{ pageNum }} / {{ Math.ceil(total / pageSize) }} 页 · 共 {{ total }} 条</span>
        <button class="btn sm" :disabled="pageNum * pageSize >= total" @click="step(1)">下一页<ChevronRight :size="13" /></button>
      </div>
    </section>

    <BaseModal v-if="resumeOpen" title="简历智能解析" width="620px" @close="resumeOpen = false">
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

    <BaseModal v-if="tagOpen" title="批量加标签" width="400px" @close="tagOpen = false">
      <div class="tag-body">
        <p class="import-hint">将为已选择的 {{ selected.length }} 位候选人添加同一标签。</p>
        <input v-model="tagNameInput" class="input" placeholder="如：前端 · 高潜" maxlength="20" />
      </div>
      <template #footer>
        <button class="btn" @click="tagOpen = false">取消</button>
        <button class="btn primary" :disabled="tagBusy" @click="submitTag">{{ tagBusy ? '保存中…' : '确认添加' }}</button>
      </template>
    </BaseModal>

    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.candidates-page{padding-bottom:25px}
.heading-actions{display:flex;gap:9px}
.list-card{padding:17px;min-height:560px}
.toolbar{display:flex;align-items:center;gap:10px;padding-bottom:13px;border-bottom:1px solid #e5ebf3;flex-wrap:wrap}
.search-box{display:flex;align-items:center;gap:7px;border:1px solid #dce4ee;border-radius:9px;padding:0 11px;height:38px;flex:1;min-width:180px;color:#8da0ba}
.search-box input{width:100%;border:0;outline:0;font-size:12px;color:var(--text)}
.toolbar .select{width:150px}
.filter-btn{height:38px;border:1px solid #dce4ee;border-radius:9px;background:#fff;color:#52657f;display:flex;gap:6px;align-items:center;padding:0 13px;cursor:pointer}
.batch-bar{display:flex;align-items:center;gap:8px;padding:13px 0;border-bottom:1px solid #e5ebf3;color:#718198;font-size:11px}
.batch-bar span{margin-right:auto}
.sm-select{width:120px;height:30px;font-size:11px}
.candidate-table{margin-top:10px}
.table-head,.table-row{display:grid;grid-template-columns:30px 1.6fr .8fr 1fr .9fr 1.05fr 1.1fr;gap:8px;align-items:center}
.table-head{height:34px;padding:0 8px;background:#f6f8fb;color:#8593a7;font-size:9px}
.table-row{min-height:64px;padding:8px;border-bottom:1px solid #e8edf4;font-size:10px;color:#5e718c}
.ck{display:flex;justify-content:center}
.ck input{accent-color:var(--primary);width:15px;height:15px}
.person{display:flex;align-items:center;gap:8px;min-width:0}
.person b,.person small{display:block}
.person b{font-size:12px;color:#1e293b}
.person small{color:#7f8ea3;font-size:9px;margin-top:3px}
.score{color:#2563eb;font-weight:600}
.stage-text{color:#5e718c}
/* pill 作为 grid 项默认被拉伸占满整列导致文字偏移，改为收缩并与表头左对齐 */
.table-row .pill{justify-self:start;width:max-content;max-width:100%}
.table-row time{color:#8d9aae;font-size:9px}
.ops{display:flex;flex-wrap:wrap;gap:6px}
.ops button{border:0;background:transparent;color:#2563eb;font-size:9px;display:flex;gap:3px;align-items:center;padding:3px 0;cursor:pointer}
.pager{display:flex;align-items:center;justify-content:center;gap:14px;padding-top:14px;color:#718198;font-size:10px}
.pager button:disabled{opacity:.5}
.empty{color:#a4b0c2;text-align:center;padding:40px;font-size:11px}
.empty.sm{padding:12px;font-size:10px}
.empty svg{display:block;margin:0 auto 8px}
.detail-grid{display:grid;grid-template-columns:1fr 1fr;gap:11px}
.d-item{background:#f7f9fc;border-radius:9px;padding:10px 12px}
.d-item label{display:block;font-size:9px;color:#8da0ba;margin-bottom:4px}
.d-item b{font-size:12px;color:#1e293b;font-weight:500}
.resume-block{margin-top:16px;border-top:1px dashed #e2e8f0;padding-top:13px}
.import-hint{font-size:10px;color:#7b8ba3;line-height:1.65}.tag-body .input{margin-top:10px}
.resume-block h3{display:flex;align-items:center;gap:6px;font-size:13px;color:#334155;margin-bottom:10px}
.resume-list{list-style:none;display:flex;flex-direction:column;gap:9px}
.resume-list li{background:#f7f9fc;border-radius:9px;padding:9px 12px}
.resume-list li b{font-size:12px;color:#1e293b}
.resume-list li span{display:block;color:#5e718c;font-size:10px;margin-top:3px}
.resume-list li small{display:block;color:#8d9aae;font-size:9px;margin-top:3px}
.tags-cell{display:flex;flex-wrap:wrap;gap:4px}
.tags-cell .tag{font-size:9px;padding:2px 6px;color:#2563eb;background:#edf4ff;border-radius:4px}
</style>
