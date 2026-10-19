<script setup>
import { ref, computed, onMounted } from 'vue'
import { Search, Tags, Archive, Send, Megaphone, FileText, CalendarPlus, UserRound, BriefcaseBusiness, ChevronRight, AlertTriangle, Bookmark, GraduationCap } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listTalents, getTalentOptions, getTalentResume, archiveTalent, reapplyTalent, careNotifyTalent, inviteInterview } from '@/api/talent'
import { listJobs } from '@/api/system/job'
import { listMembers } from '@/api/system/settings'

const toast = ref('')
const loading = ref(false)
const talents = ref([])
const total = ref(0)
const pageNum = ref(1)
const pageSize = 10

const filters = ref({ keyword: '', direction: '', tag: '', archiveSource: '' })
const options = ref({ directions: [], tags: [] })

// 归档来源：0-未归档，1-笔试淘汰，2-面试淘汰，3-主动归档，4-初筛淘汰
const ARCHIVE = { 0: ['未归档', 'gray'], 1: ['笔试淘汰', 'orange'], 2: ['面试淘汰', 'red'], 3: ['主动归档', 'purple'], 4: ['初筛淘汰', 'blue'] }
// 流程状态（t_tal.tal_status）
const STATUS = {
  0: ['新入库', 'gray'], 1: ['初筛通过', 'green'], 2: ['面试中', 'purple'], 3: ['已淘汰', 'red'],
  4: ['已录用', 'green'], 5: ['待笔试', 'orange'], 6: ['笔试中', 'orange'], 7: ['笔试通过', 'green'],
  8: ['笔试未通过', 'red'], 9: ['笔试缺考', 'gray']
}

// 选中的候选人（用于批量关怀通知）
const selectedIds = ref([])
const allSelected = computed(() => talents.value.length > 0 && selectedIds.value.length === talents.value.length)

// 简历详情
const detail = ref(null)
const detailResume = ref(null)
const detailOpen = ref(false)

// 一键转投递
const positions = ref([])
const reapplyRow = ref(null)
const reapplyOpen = ref(false)
const reapplyPositionId = ref('')

// 发起邀约（面试官下拉仅展示本企业「面试官」角色成员，roleId=103）
const members = ref([])
const interviewers = computed(() => members.value.filter(m => Number(m.roleId) === 103))
const inviteRow = ref(null)
const inviteOpen = ref(false)
const inviteForm = ref({ positionId: '', interviewerId: '', startTime: '', durationMin: 45 })

// 落选关怀通知
const careOpen = ref(false)
const careForm = ref({ title: '感谢参与，期待再会', content: '' })

function notify(msg) { toast.value = msg; setTimeout(() => toast.value = '', 2600) }

async function loadOptions() {
  try {
    const res = await getTalentOptions()
    options.value = { directions: res.data?.directions || [], tags: res.data?.tags || [] }
  } catch (e) { options.value = { directions: [], tags: [] } }
}

async function load() {
  loading.value = true
  try {
    const query = { pageNum: pageNum.value, pageSize }
    if (filters.value.keyword) query.keyword = filters.value.keyword
    if (filters.value.direction) query.direction = filters.value.direction
    if (filters.value.tag) query.tag = filters.value.tag
    if (filters.value.archiveSource !== '') query.archiveSource = filters.value.archiveSource
    const res = await listTalents(query)
    talents.value = res.rows || []
    total.value = res.total || 0
    selectedIds.value = []
  } catch (e) {
    talents.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

function search() { pageNum.value = 1; load() }
function step(delta) {
  const next = pageNum.value + delta
  if (next < 1 || (next - 1) * pageSize >= total.value) return
  pageNum.value = next
  load()
}

function toggleSelect(talId) {
  const i = selectedIds.value.indexOf(talId)
  if (i >= 0) selectedIds.value.splice(i, 1)
  else selectedIds.value.push(talId)
}
function toggleSelectAll() {
  selectedIds.value = allSelected.value ? [] : talents.value.map(t => t.talentId)
}

async function openDetail(row) {
  detail.value = row
  detailResume.value = null
  detailOpen.value = true
  try {
    const res = await getTalentResume(row.talentId)
    detailResume.value = res.data
  } catch (e) { detailResume.value = null }
}

async function loadPositions() {
  if (positions.value.length) return
  try {
    const res = await listJobs({ pageNum: 1, pageSize: 200 })
    positions.value = res.rows || []
  } catch (e) { positions.value = [] }
}
async function loadMembers() {
  if (members.value.length) return
  try {
    const res = await listMembers()
    members.value = res.data || []
  } catch (e) { members.value = [] }
}

async function openReapply(row) {
  reapplyRow.value = row
  reapplyPositionId.value = ''
  reapplyOpen.value = true
  await loadPositions()
}
async function submitReapply() {
  if (!reapplyPositionId.value) return notify('请选择转投岗位')
  try {
    const res = await reapplyTalent(reapplyRow.value.talentId, reapplyPositionId.value)
    notify(res.data?.message || '已创建投递记录')
    reapplyOpen.value = false
  } catch (e) { /* 拦截器已提示 */ }
}

async function openInvite(row) {
  inviteRow.value = row
  inviteForm.value = { positionId: '', interviewerId: '', startTime: '', durationMin: 45 }
  inviteOpen.value = true
  await Promise.all([loadPositions(), loadMembers()])
}
async function submitInvite() {
  const f = inviteForm.value
  if (!f.positionId || !f.interviewerId || !f.startTime) return notify('请选择岗位、面试官并填写面试时间')
  try {
    const res = await inviteInterview({
      candidateId: inviteRow.value.talentId,
      positionId: f.positionId,
      interviewerId: f.interviewerId,
      startTime: f.startTime.replace('T', ' ') + ':00',
      durationMin: f.durationMin
    })
    notify(res.data?.message || res.msg || '邀约已发起')
    inviteOpen.value = false
  } catch (e) { /* 拦截器已提示 */ }
}

async function toggleArchive(row) {
  const archived = row.archiveSource !== 3
  try {
    const res = await archiveTalent(row.talentId, archived)
    notify(res.data?.message || (archived ? '已主动归档' : '已取消归档'))
    await load()
  } catch (e) { /* 拦截器已提示 */ }
}

function openCare() {
  if (!selectedIds.value.length) return notify('请先选择候选人')
  careForm.value = {
    title: '感谢参与，期待再会',
    content: '感谢您对本次招聘的关注，很遗憾本次未能与您携手。您的简历已存入我们的人才库，期待未来有合适的机会再与您联系。'
  }
  careOpen.value = true
}
async function submitCare() {
  try {
    const res = await careNotifyTalent({ talIds: selectedIds.value, title: careForm.value.title, content: careForm.value.content })
    notify(res.data?.message || '关怀通知已发送')
    careOpen.value = false
    selectedIds.value = []
    await load()
  } catch (e) { /* 拦截器已提示 */ }
}

onMounted(() => { loadOptions(); load() })
</script>

<template>
  <div class="page talent-page">
    <div class="page-heading">
      <div><h1>人才库</h1><p>结构化人才检索、归档来源识别与二次复用 · 共 {{ total }} 位候选人</p></div>
      <button class="btn primary" :disabled="!selectedIds.length" @click="openCare">
        <Megaphone :size="15" />落选关怀通知{{ selectedIds.length ? `（${selectedIds.length}）` : '' }}
      </button>
    </div>

    <section class="card list-card">
      <div class="toolbar">
        <div class="search-box"><Search :size="15" /><input v-model="filters.keyword" class="search-input" placeholder="搜索姓名 / 手机号" @keyup.enter="search" /></div>
        <select v-model="filters.direction" class="select" @change="search">
          <option value="">全部岗位方向</option>
          <option v-for="d in options.directions" :key="d" :value="d">{{ d }}</option>
        </select>
        <select v-model="filters.tag" class="select" @change="search">
          <option value="">全部标签</option>
          <option v-for="t in options.tags" :key="t" :value="t">{{ t }}</option>
        </select>
        <select v-model="filters.archiveSource" class="select" @change="search">
          <option value="">全部归档来源</option>
          <option value="1">笔试淘汰</option>
          <option value="2">面试淘汰</option>
          <option value="3">主动归档</option>
          <option value="4">初筛淘汰</option>
          <option value="0">未归档</option>
        </select>
        <button class="btn ghost-primary" @click="search"><Search :size="14" />检索</button>
      </div>

      <div v-if="loading" class="empty">加载中…</div>
      <div v-else-if="!talents.length" class="empty">
        <Tags :size="26" />
        <p>暂无人才数据，可调整检索条件或等待新的候选简历入库</p>
      </div>
      <div v-else class="talent-table">
        <div class="table-head">
          <span class="ck"><input type="checkbox" :checked="allSelected" @change="toggleSelectAll" /></span>
          <span>候选人</span><span>岗位方向</span><span>匹配分</span><span>流程状态</span><span>归档来源</span><span>标签</span><span>操作</span>
        </div>
        <article v-for="row in talents" :key="row.talentId" class="table-row">
          <span class="ck"><input type="checkbox" :checked="selectedIds.includes(row.talentId)" @change="toggleSelect(row.talentId)" /></span>
          <div class="person">
            <MiniAvatar :name="row.name || '?'" :size="32" color="#2563eb" />
            <div><b>{{ row.name || '未知候选人' }}</b><small>{{ row.phone || '手机号缺失' }}</small></div>
          </div>
          <span class="dir-cell">{{ row.jobDirection || '—' }}</span>
          <span class="score">{{ row.matchedScore != null ? row.matchedScore : '—' }}</span>
          <span class="pill" :class="STATUS[row.status]?.[1]">{{ STATUS[row.status]?.[0] || '未知' }}</span>
          <span class="pill" :class="ARCHIVE[row.archiveSource]?.[1]">{{ ARCHIVE[row.archiveSource]?.[0] || '未归档' }}</span>
          <div class="tags-cell">
            <template v-if="row.tags"><span v-for="tg in row.tags.split(',')" :key="tg" class="tag">{{ tg }}</span></template>
            <span v-else class="muted">—</span>
          </div>
          <div class="ops">
            <button @click="openDetail(row)"><FileText :size="13" />详情</button>
            <button @click="openReapply(row)"><Send :size="13" />转投递</button>
            <button @click="openInvite(row)"><CalendarPlus :size="13" />发起邀约</button>
            <button @click="toggleArchive(row)"><Archive :size="13" />{{ row.archiveSource === 3 ? '取消归档' : '归档' }}</button>
          </div>
        </article>
      </div>

      <div v-if="total > pageSize" class="pager">
        <button class="btn sm" :disabled="pageNum <= 1" @click="step(-1)"><ChevronRight :size="13" style="transform:rotate(180deg)" />上一页</button>
        <span>{{ pageNum }} / {{ Math.ceil(total / pageSize) }} 页 · 共 {{ total }} 条</span>
        <button class="btn sm" :disabled="pageNum * pageSize >= total" @click="step(1)">下一页<ChevronRight :size="13" /></button>
      </div>
    </section>

    <!-- 候选人详情 + 简历解析 -->
    <BaseModal v-if="detailOpen" title="候选人档案与简历解析" width="640px" @close="detailOpen = false">
      <div class="detail-grid">
        <div class="d-item"><label><UserRound :size="12" />候选人</label><b>{{ detail?.name || '—' }}</b></div>
        <div class="d-item"><label><BriefcaseBusiness :size="12" />岗位方向</label><b>{{ detail?.jobDirection || '—' }}</b></div>
        <div class="d-item"><label>手机号</label><b>{{ detail?.phone || '—' }}</b></div>
        <div class="d-item"><label>邮箱</label><b>{{ detail?.email || '—' }}</b></div>
        <div class="d-item"><label>匹配分</label><b>{{ detail?.matchedScore != null ? detail.matchedScore : '—' }}</b></div>
        <div class="d-item"><label>流程状态</label><span class="pill" :class="STATUS[detail?.status]?.[1]">{{ STATUS[detail?.status]?.[0] || '未知' }}</span></div>
        <div class="d-item"><label>归档来源</label><span class="pill" :class="ARCHIVE[detail?.archiveSource]?.[1]">{{ ARCHIVE[detail?.archiveSource]?.[0] || '未归档' }}</span></div>
        <div class="d-item"><label>简历完整度</label><b>{{ detailResume ? detailResume.integrity + '%' : '读取中…' }}</b></div>
      </div>

      <div v-if="detailResume && detailResume.missingFields && detailResume.missingFields.length" class="missing">
        <AlertTriangle :size="13" />缺失字段：{{ detailResume.missingFields.join('、') }}
      </div>

      <div class="resume-block">
        <h3><GraduationCap :size="15" />教育经历</h3>
        <div v-if="!detailResume || !detailResume.educationList.length" class="empty sm">暂无教育经历</div>
        <ul v-else class="resume-list">
          <li v-for="(e, i) in detailResume.educationList" :key="i">
            <b>{{ e.school || '—' }}</b><span>{{ e.major || '—' }} · {{ e.degree ? '学历' + e.degree : '—' }}</span><small>{{ e.startDate || '' }} ~ {{ e.endDate || '' }}</small>
          </li>
        </ul>
      </div>

      <div class="resume-block">
        <h3><BriefcaseBusiness :size="15" />工作经历</h3>
        <div v-if="!detailResume || !detailResume.workList.length" class="empty sm">暂无工作经历</div>
        <ul v-else class="resume-list">
          <li v-for="(w, i) in detailResume.workList" :key="i">
            <b>{{ w.company || '—' }}</b><span>{{ w.position || '—' }}</span><small>{{ w.startDate || '' }} ~ {{ w.endDate || '' }}</small>
          </li>
        </ul>
      </div>

      <div class="resume-block">
        <h3><Bookmark :size="15" />技能标签</h3>
        <div v-if="!detailResume || !detailResume.skills.length" class="empty sm">暂无技能标签</div>
        <div v-else class="tags-cell">
          <span v-for="(s, i) in detailResume.skills" :key="i" class="tag">{{ s.name }}<template v-if="s.level">·{{ s.level }}</template></span>
        </div>
      </div>

      <template #footer>
        <button class="btn" @click="openReapply(detail); detailOpen = false"><Send :size="14" />转投递</button>
        <button class="btn ghost-primary" @click="openInvite(detail); detailOpen = false"><CalendarPlus :size="14" />发起邀约</button>
        <button class="btn" @click="detailOpen = false">关闭</button>
      </template>
    </BaseModal>

    <!-- 一键转投递 -->
    <BaseModal v-if="reapplyOpen" title="一键转投递" width="480px" @close="reapplyOpen = false">
      <p class="modal-tip">为候选人 <b>{{ reapplyRow?.name }}</b> 创建新的投递记录，选择目标岗位：</p>
      <div class="f-item">
        <label>目标岗位 *</label>
        <select v-model="reapplyPositionId" class="select">
          <option value="">请选择岗位</option>
          <option v-for="p in positions" :key="p.posId" :value="p.posId">{{ p.title }}</option>
        </select>
      </div>
      <template #footer>
        <button class="btn" @click="reapplyOpen = false">取消</button>
        <button class="btn primary" @click="submitReapply"><Send :size="14" />确认转投递</button>
      </template>
    </BaseModal>

    <!-- 发起邀约 -->
    <BaseModal v-if="inviteOpen" title="发起面试邀约" width="520px" @close="inviteOpen = false">
      <p class="modal-tip">为候选人 <b>{{ inviteRow?.name }}</b> 发起面试邀约（复用面试调度能力，自动占用时段并生成会议链接）：</p>
      <div class="form-grid">
        <div class="f-item"><label>面试岗位 *</label>
          <select v-model="inviteForm.positionId" class="select">
            <option value="">请选择岗位</option>
            <option v-for="p in positions" :key="p.posId" :value="p.posId">{{ p.title }}</option>
          </select>
        </div>
        <div class="f-item"><label>面试官 *</label>
          <select v-model="inviteForm.interviewerId" class="select">
            <option value="">请选择面试官</option>
            <option v-for="m in interviewers" :key="m.userId" :value="m.userId">{{ m.nickName }}（{{ m.dept || '未分配' }}）</option>
          </select>
        </div>
        <div class="f-item"><label>面试时间 *</label><input v-model="inviteForm.startTime" type="datetime-local" class="input" /></div>
        <div class="f-item"><label>时长（分钟）</label><input v-model.number="inviteForm.durationMin" type="number" class="input" /></div>
      </div>
      <p v-if="!interviewers.length" class="modal-tip">本企业暂无「面试官」角色成员，请先在「组织与权限」中为其分配面试官角色。</p>
      <template #footer>
        <button class="btn" @click="inviteOpen = false">取消</button>
        <button class="btn primary" @click="submitInvite"><CalendarPlus :size="14" />发起邀约</button>
      </template>
    </BaseModal>

    <!-- 落选关怀通知 -->
    <BaseModal v-if="careOpen" title="发送落选关怀通知" width="560px" @close="careOpen = false">
      <p class="modal-tip">将向已选中的 <b>{{ selectedIds.length }}</b> 位候选人发送系统关怀消息：</p>
      <div class="f-item"><label>通知标题</label><input v-model="careForm.title" class="input" placeholder="如：感谢参与，期待再会" /></div>
      <div class="f-item"><label>通知内容</label><textarea v-model="careForm.content" class="textarea" rows="4" placeholder="填写关怀寄语"></textarea></div>
      <template #footer>
        <button class="btn" @click="careOpen = false">取消</button>
        <button class="btn primary" @click="submitCare"><Megaphone :size="14" />发送通知</button>
      </template>
    </BaseModal>

    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.talent-page{padding-bottom:25px}
.talent-page .pill.blue{color:#1d6fd1;background:#e8f2ff}
.list-card{padding:17px}
.toolbar{display:flex;align-items:center;gap:10px;padding-bottom:13px;border-bottom:1px solid #e5ebf3;flex-wrap:wrap}
.search-box{display:flex;align-items:center;gap:7px;border:1px solid #dce4ee;border-radius:9px;padding:0 11px;height:38px;flex:1;min-width:180px;color:#8da0ba}
.search-input{border:0;outline:none;flex:1;font-size:12px;color:var(--text)}
.toolbar .select{width:150px}
.talent-table{margin-top:10px}
.table-head,.table-row{display:grid;grid-template-columns:30px 1.5fr 1fr .7fr .85fr .9fr 1.2fr 1.55fr;gap:8px;align-items:center}
.table-head{height:34px;padding:0 8px;background:#f6f8fb;color:#8593a7;font-size:9px}
.table-row{min-height:64px;padding:8px;border-bottom:1px solid #e8edf4;font-size:10px;color:#5e718c}
.ck{display:flex;justify-content:center}
.ck input{accent-color:var(--primary);width:15px;height:15px}
.person{display:flex;align-items:center;gap:8px;min-width:0}
.person b,.person small{display:block}
.person b{font-size:12px;color:#1e293b}
.person small{color:#7f8ea3;font-size:9px;margin-top:3px}
.dir-cell{color:#334155}
.score{color:#2563eb;font-weight:600}
.tags-cell{display:flex;flex-wrap:wrap;gap:4px}
.tags-cell .tag{font-size:9px;padding:2px 6px}
.ops{display:flex;flex-wrap:wrap;gap:6px}
.ops button{border:0;background:transparent;color:#2563eb;font-size:9px;display:flex;gap:3px;align-items:center;padding:3px 0;cursor:pointer}
.pager{display:flex;align-items:center;justify-content:center;gap:14px;padding-top:14px;color:#718198;font-size:10px}
.pager button:disabled{opacity:.5}
.empty{color:#a4b0c2;text-align:center;padding:40px;font-size:11px}
.empty.sm{padding:12px;font-size:10px}
.empty svg{display:block;margin:0 auto 8px}
.detail-grid{display:grid;grid-template-columns:1fr 1fr;gap:11px}
.d-item{background:#f7f9fc;border-radius:9px;padding:10px 12px}
.d-item label{display:flex;align-items:center;gap:4px;font-size:9px;color:#8da0ba;margin-bottom:4px}
.d-item b{font-size:12px;color:#1e293b;font-weight:500}
.missing{display:flex;align-items:center;gap:6px;margin-top:12px;color:#d76e00;background:#fff3df;border-radius:9px;padding:9px 12px;font-size:11px}
.resume-block{margin-top:16px;border-top:1px dashed #e2e8f0;padding-top:13px}
.resume-block h3{display:flex;align-items:center;gap:6px;font-size:13px;color:#334155;margin-bottom:10px}
.resume-list{list-style:none;display:flex;flex-direction:column;gap:9px}
.resume-list li{background:#f7f9fc;border-radius:9px;padding:9px 12px}
.resume-list li b{font-size:12px;color:#1e293b}
.resume-list li span{display:block;color:#5e718c;font-size:10px;margin-top:3px}
.resume-list li small{display:block;color:#8d9aae;font-size:9px;margin-top:3px}
.modal-tip{font-size:11px;color:#5e718c;margin-bottom:12px}
.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.f-item{margin-bottom:12px}
.form-grid .f-item{margin-bottom:0}
.f-item label{display:block;font-size:10px;color:#718198;margin-bottom:5px}
.textarea{padding:9px 12px;font-size:12px;resize:vertical;font-family:inherit}
</style>
