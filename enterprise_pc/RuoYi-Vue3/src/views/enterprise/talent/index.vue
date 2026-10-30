<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { Tags, Archive, Send, Megaphone, FileText, CalendarPlus, BriefcaseBusiness, ChevronRight, ChevronDown, AlertTriangle, Bookmark, GraduationCap, Smartphone, Building2 } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listTalents, getTalentDetail, getTalentResume, archiveTalent, reapplyTalent, careNotifyTalent, inviteInterview, listApplications } from '@/api/talent'
import { listJobs } from '@/api/system/job'
import { listMembers } from '@/api/system/settings'

const toast = ref('')
const loading = ref(false)
const talents = ref([])
const total = ref(0)
const pageNum = ref(1)
const pageSize = 12

const filters = ref({ keyword: '', positionId: '', status: '' })
// 顶栏全局搜索跳转时通过 ?keyword= 带入关键字
const route = useRoute()
if (typeof route.query.keyword === 'string') filters.value.keyword = route.query.keyword
// 已在人才库时再次使用顶栏搜索，仅查询串变化，这里同步关键词并重新检索
watch(() => route.query.keyword, kw => {
  if (typeof kw !== 'string') return
  filters.value.keyword = kw
  pageNum.value = 1
  load()
})
// 归档来源：0-未归档，1-笔试淘汰，2-面试淘汰，3-主动归档，4-初筛淘汰
const ARCHIVE = { 0: ['未归档', 'gray'], 1: ['笔试淘汰', 'orange'], 2: ['面试淘汰', 'red'], 3: ['主动归档', 'purple'], 4: ['初筛淘汰', 'blue'] }
// 流程状态（t_tal.tal_status）
const STATUS = {
  0: ['新入库', 'gray'], 1: ['初筛通过', 'green'], 2: ['面试中', 'purple'], 3: ['已淘汰', 'red'],
  4: ['已录用', 'green'], 5: ['待笔试', 'orange'], 6: ['笔试中', 'orange'], 7: ['笔试通过', 'green'],
  8: ['笔试未通过', 'red'], 9: ['笔试缺考', 'gray']
}
// 投递状态（t_app_record.app_status），按岗位维度
const APP_STATUS = {
  0: ['待筛选', 'gray'], 1: ['初筛通过', 'green'], 2: ['初筛淘汰', 'red'], 3: ['已约面', 'blue'],
  4: ['待笔试', 'orange'], 5: ['笔试中', 'orange'], 6: ['笔试通过', 'green'], 7: ['笔试未通过', 'red'],
  8: ['笔试缺考', 'gray'], 9: ['已撤回', 'gray']
}

// 选中的候选人（用于批量关怀通知）
const selectedIds = ref([])
const allSelected = computed(() => talents.value.length > 0 && selectedIds.value.length === talents.value.length)

// 候选人档案
const detailRow = ref(null)
const detailInfo = ref(null)
const detailResume = ref(null)
const detailApps = ref([])
const appsLoading = ref(false)
const expandedAppId = ref(null)
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

function statusOf(v) { return STATUS[v] || ['未知', 'gray'] }
function archiveOf(v) { return ARCHIVE[v] || ARCHIVE[0] }
function appStatusOf(v) { return APP_STATUS[v] || ['未知', 'gray'] }
function educationOf() {
  const first = detailResume.value?.educationList?.[0]
  return detailInfo.value?.school || detailRow.value?.school || first?.school || '—'
}

async function load() {
  loading.value = true
  try {
    const query = { pageNum: pageNum.value, pageSize }
    if (filters.value.keyword) query.keyword = filters.value.keyword
    if (filters.value.positionId !== '') query.positionId = filters.value.positionId
    if (filters.value.status !== '') query.status = filters.value.status
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
function selectPosition(value) { filters.value.positionId = value; search() }
function positionLabel() {
  if (filters.value.positionId === '') return '投递岗位'
  const hit = positions.value.find(p => String(p.posId) === String(filters.value.positionId))
  return hit ? hit.title : '投递岗位'
}
function selectStatus(value) { filters.value.status = value; search() }
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

// 打开档案：基础信息、技能标签、投递记录并行加载，单个失败不影响其他区块展示
async function openDetail(row) {
  detailRow.value = row
  detailInfo.value = null
  detailResume.value = null
  detailApps.value = []
  expandedAppId.value = null
  detailOpen.value = true
  appsLoading.value = true
  const [infoRes, resumeRes, appsRes] = await Promise.allSettled([
    getTalentDetail(row.talentId),
    getTalentResume(row.talentId),
    listApplications({ talentId: row.talentId, pageNum: 1, pageSize: 20 })
  ])
  if (infoRes.status === 'fulfilled') detailInfo.value = infoRes.value.data
  if (resumeRes.status === 'fulfilled') detailResume.value = resumeRes.value.data
  detailApps.value = appsRes.status === 'fulfilled' ? (appsRes.value.rows || []) : []
  appsLoading.value = false
}

function toggleApp(id) { expandedAppId.value = expandedAppId.value === id ? null : id }

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
    if (detailRow.value && String(detailRow.value.talentId) === String(reapplyRow.value.talentId)) {
      const appsRes = await listApplications({ talentId: reapplyRow.value.talentId, pageNum: 1, pageSize: 20 })
      detailApps.value = appsRes.rows || []
    }
    await load()
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
  const archived = (row.archiveSource ?? 0) !== 3
  try {
    const res = await archiveTalent(row.talentId, archived)
    notify(res.data?.message || (archived ? '已主动归档' : '已取消归档'))
    if (detailInfo.value && row === detailInfo.value) detailInfo.value.archiveSource = archived ? 3 : 0
    else if (detailInfo.value && String(detailInfo.value.talentId) === String(row.talentId)) detailInfo.value.archiveSource = archived ? 3 : 0
    if (detailRow.value && String(detailRow.value.talentId) === String(row.talentId)) detailRow.value.archiveSource = archived ? 3 : 0
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

onMounted(() => { loadPositions(); load() })
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
      <div class="filter-row">
        <el-dropdown trigger="click" class="chip-dd" @command="selectPosition">
          <button class="filter-chip" :class="{ active: filters.positionId !== '' }">
            <BriefcaseBusiness :size="13" />{{ positionLabel() }}<ChevronDown :size="13" class="chip-arrow" />
          </button>
          <template #dropdown>
            <el-dropdown-menu class="chip-menu">
              <el-dropdown-item command="">全部投递岗位</el-dropdown-item>
              <el-dropdown-item v-for="p in positions" :key="p.posId" :command="String(p.posId)">{{ p.title }}</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
        <el-dropdown trigger="click" class="chip-dd" @command="selectStatus">
          <button class="filter-chip" :class="{ active: filters.status !== '' }">
            <Tags :size="13" />{{ filters.status !== '' ? STATUS[filters.status][0] : '流程状态' }}<ChevronDown :size="13" class="chip-arrow" />
          </button>
          <template #dropdown>
            <el-dropdown-menu class="chip-menu">
              <el-dropdown-item command="">全部流程状态</el-dropdown-item>
              <el-dropdown-item v-for="(item, key) in STATUS" :key="key" :command="key">{{ item[0] }}</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </div>

      <div class="select-bar">
        <label class="select-all"><input type="checkbox" :checked="allSelected" @change="toggleSelectAll" />全选当前页</label>
        <span v-if="selectedIds.length" class="selected-tip">已选 {{ selectedIds.length }} 人</span>
      </div>

      <div v-if="loading" class="empty">加载中…</div>
      <div v-else-if="!talents.length" class="empty">
        <Tags :size="26" />
        <p>暂无人才数据，可调整检索条件或等待新的候选简历入库</p>
      </div>
      <div v-else class="talent-grid">
        <article v-for="row in talents" :key="row.talentId" class="talent-card" :class="{ selected: selectedIds.includes(row.talentId) }" @click="openDetail(row)">
          <label class="card-ck" @click.stop><input type="checkbox" :checked="selectedIds.includes(row.talentId)" @change="toggleSelect(row.talentId)" /></label>
          <div class="card-top">
            <MiniAvatar :name="row.name || '?'" :size="44" color="#2563eb" />
            <div class="who">
              <b>{{ row.name || '未知候选人' }}</b>
              <small><Smartphone :size="11" />{{ row.phone || '手机号缺失' }}</small>
            </div>
            <span class="pill" :class="statusOf(row.status)[1]">{{ statusOf(row.status)[0] }}</span>
          </div>
          <div class="card-meta">
            <span><GraduationCap :size="12" />{{ row.school || '毕业学校未填写' }}</span>
            <span><BriefcaseBusiness :size="12" />{{ row.jobDirection || '岗位方向未填写' }}</span>
          </div>
          <div class="card-tags">
            <template v-if="row.tags"><span v-for="tg in row.tags.split(',')" :key="tg" class="tag">{{ tg }}</span></template>
            <span v-else class="muted">暂无标签</span>
          </div>
          <div class="card-foot">
            <span class="score">匹配分 <b>{{ row.matchedScore != null ? row.matchedScore : '—' }}</b></span>
            <ChevronRight :size="14" class="card-arrow" />
          </div>
        </article>
      </div>

      <div v-if="total > pageSize" class="pager">
        <button class="btn sm" :disabled="pageNum <= 1" @click="step(-1)"><ChevronRight :size="13" style="transform:rotate(180deg)" />上一页</button>
        <span>{{ pageNum }} / {{ Math.ceil(total / pageSize) }} 页 · 共 {{ total }} 条</span>
        <button class="btn sm" :disabled="pageNum * pageSize >= total" @click="step(1)">下一页<ChevronRight :size="13" /></button>
      </div>
    </section>

    <!-- 候选人档案：基础信息 + 技能标签 + 投递情况 + 操作 -->
    <BaseModal v-if="detailOpen" title="候选人档案" width="820px" @close="detailOpen = false">
      <div class="profile-head">
        <MiniAvatar :name="detailRow?.name || '?'" :size="56" color="#2563eb" />
        <div class="profile-who">
          <b>{{ detailRow?.name || '未知候选人' }}</b>
          <small>{{ detailRow?.phone || '手机号缺失' }} · {{ detailRow?.email || '邮箱未填写' }}</small>
        </div>
        <span class="pill" :class="statusOf(detailInfo?.status ?? detailRow?.status)[1]">{{ statusOf(detailInfo?.status ?? detailRow?.status)[0] }}</span>
        <span class="pill" :class="archiveOf(detailInfo?.archiveSource ?? detailRow?.archiveSource)[1]">{{ archiveOf(detailInfo?.archiveSource ?? detailRow?.archiveSource)[0] }}</span>
      </div>

      <div class="detail-grid">
        <div class="d-item"><label><BriefcaseBusiness :size="12" />岗位方向</label><b>{{ detailInfo?.jobDirection || detailRow?.jobDirection || '—' }}</b></div>
        <div class="d-item"><label><GraduationCap :size="12" />毕业学校</label><b>{{ educationOf() }}</b></div>
        <div class="d-item"><label>匹配分</label><b>{{ (detailInfo?.matchedScore ?? detailRow?.matchedScore) != null ? (detailInfo?.matchedScore ?? detailRow?.matchedScore) : '—' }}</b></div>
        <div class="d-item"><label>简历完整度</label><b>{{ detailResume ? detailResume.integrity + '%' : '读取中…' }}</b></div>
      </div>

      <div v-if="detailResume && detailResume.missingFields && detailResume.missingFields.length" class="missing">
        <AlertTriangle :size="13" />缺失字段：{{ detailResume.missingFields.join('、') }}
      </div>

      <div class="resume-block">
        <h3><Bookmark :size="15" />技能标签</h3>
        <div v-if="!detailResume || !detailResume.skills.length" class="empty sm">暂无技能标签</div>
        <div v-else class="tags-cell">
          <span v-for="(s, i) in detailResume.skills" :key="i" class="tag on">{{ s.name }}<template v-if="s.level">·{{ s.level }}</template></span>
        </div>
        <div v-if="detailInfo && detailInfo.tags && detailInfo.tags.length" class="tags-cell manual">
          <span v-for="(t, i) in detailInfo.tags" :key="i" class="tag">{{ t.name }}</span>
        </div>
      </div>

      <div class="resume-block">
        <div class="block-title"><h3><GraduationCap :size="15" />教育经历</h3></div>
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
        <div class="block-title">
          <h3><FileText :size="15" />投递情况</h3>
          <em v-if="detailApps.length">共 {{ detailApps.length }} 条</em>
        </div>
        <div v-if="appsLoading" class="empty sm">投递记录加载中…</div>
        <div v-else-if="!detailApps.length" class="empty sm">该候选人暂无投递记录</div>
        <div v-else class="app-list">
          <article v-for="app in detailApps" :key="app.applicationId" class="app-item" :class="{ open: expandedAppId === app.applicationId }">
            <div class="app-row" @click="toggleApp(app.applicationId)">
              <span class="app-dot" :class="appStatusOf(app.appStatus)[1]"></span>
              <div class="app-main">
                <b>{{ app.positionName || '—' }}</b>
                <small><Building2 :size="11" />{{ app.companyName || '本企业' }} · 投递于 {{ app.appliedAt || '—' }}</small>
              </div>
              <span class="pill" :class="appStatusOf(app.appStatus)[1]">{{ appStatusOf(app.appStatus)[0] }}</span>
              <ChevronDown :size="14" class="app-arrow" />
            </div>
            <div v-if="expandedAppId === app.applicationId" class="app-detail">
              <div class="app-detail-head">
                <span>流程进度</span>
                <em>当前阶段：{{ appStatusOf(app.appStatus)[0] }}</em>
              </div>
              <div class="timeline">
                <div class="node done"><i></i><b>已投递</b><small>{{ app.appliedAt || '—' }}</small></div>
                <div class="line" :class="appStatusOf(app.appStatus)[1]"></div>
                <div class="node current" :class="appStatusOf(app.appStatus)[1]"><i></i><b>{{ appStatusOf(app.appStatus)[0] }}</b><small>{{ app.updateTime || '—' }}</small></div>
              </div>
              <div class="app-extra">
                <span>当前流程：{{ app.currentStage || '未进入面试流程' }}</span>
                <span>匹配分：{{ app.matchedScore != null ? app.matchedScore : '—' }}</span>
              </div>
            </div>
          </article>
        </div>
      </div>

      <template #footer>
        <button class="btn" @click="toggleArchive(detailInfo || detailRow)"><Archive :size="14" />{{ (detailInfo?.archiveSource ?? detailRow?.archiveSource) === 3 ? '取消归档' : '归档' }}</button>
        <button class="btn" @click="openReapply(detailRow)"><Send :size="14" />转投递</button>
        <button class="btn ghost-primary" @click="openInvite(detailRow)"><CalendarPlus :size="14" />发起邀约</button>
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
.filter-row{display:flex;align-items:center;gap:10px;padding:2px 0 15px;border-bottom:1px solid #e5ebf3;flex-wrap:wrap}
.chip-dd{display:inline-block}
.filter-chip{display:inline-flex;align-items:center;gap:7px;height:38px;padding:0 15px;border:1px solid transparent;border-radius:10px;background:#f2f4f8;color:#3d4a5c;font-size:12px;cursor:pointer;transition:background .15s ease,color .15s ease}
.filter-chip:hover{background:#e9edf4}
.filter-chip.active{background:#e8f2ff;color:#1d6fd1}
.chip-arrow{color:#8d9aae}
:global(.chip-menu){min-width:150px;padding:5px 0;border-radius:11px;border:1px solid #e8edf5;box-shadow:0 8px 24px rgba(30,41,59,.12)}
:global(.chip-menu .el-dropdown-menu__item){font-size:12px;padding:8px 14px;color:#374151}
:global(.chip-menu .el-dropdown-menu__item:hover){background:#f2f5f9;color:#2563eb}
.select-bar{display:flex;align-items:center;gap:12px;padding:10px 2px 0;color:#718198;font-size:11px}
.select-all{display:flex;align-items:center;gap:6px;cursor:pointer}
.select-all input{accent-color:var(--primary);width:14px;height:14px}
.selected-tip{color:#2563eb}
.talent-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(272px,1fr));gap:13px;margin-top:13px}
.talent-card{position:relative;border:1px solid #e3eaf3;border-radius:13px;padding:14px 15px 12px;background:#fff;cursor:pointer;transition:box-shadow .18s ease,border-color .18s ease,transform .18s ease}
.talent-card:hover{border-color:#c7d8f2;box-shadow:0 10px 26px rgba(31,69,135,.10);transform:translateY(-1px)}
.talent-card.selected{border-color:#9dbbf0;background:#f7faff}
.card-ck{position:absolute;right:12px;top:12px;display:flex}
.card-ck input{accent-color:var(--primary);width:15px;height:15px}
.card-top{display:flex;align-items:center;gap:10px;padding-right:22px}
.who{min-width:0;flex:1}
.who b{display:block;font-size:14px;color:#1e293b;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.who small{display:flex;align-items:center;gap:4px;color:#7f8ea3;font-size:10px;margin-top:3px}
.card-top .pill{flex-shrink:0}
.card-meta{display:flex;flex-direction:column;gap:5px;margin-top:11px;color:#5e718c;font-size:11px}
.card-meta span{display:flex;align-items:center;gap:5px;min-width:0}
.card-meta svg{flex-shrink:0;color:#9aa9bf}
.card-tags{display:flex;flex-wrap:wrap;gap:4px;margin-top:10px;min-height:20px}
.card-tags .tag{font-size:9px;padding:2px 7px}
.card-foot{display:flex;align-items:center;gap:8px;margin-top:12px;padding-top:10px;border-top:1px dashed #e8edf4;font-size:10px;color:#718198}
.card-foot .score{margin-right:auto;color:#718198}
.card-foot .score b{color:#2563eb;font-size:12px;margin-left:2px}
.card-arrow{color:#b3c0d4}
.pager{display:flex;align-items:center;justify-content:center;gap:14px;padding-top:14px;color:#718198;font-size:10px}
.pager button:disabled{opacity:.5}
.empty{color:#a4b0c2;text-align:center;padding:40px;font-size:11px}
.empty.sm{padding:12px;font-size:10px}
.empty svg{display:block;margin:0 auto 8px}
.profile-head{display:flex;align-items:center;gap:12px;padding-bottom:15px}
.profile-who{flex:1;min-width:0}
.profile-who b{display:block;font-size:17px;color:#1e293b}
.profile-who small{display:block;color:#7f8ea3;font-size:11px;margin-top:4px}
.detail-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:11px}
.d-item{background:#f7f9fc;border-radius:9px;padding:10px 12px}
.d-item label{display:flex;align-items:center;gap:4px;font-size:9px;color:#8da0ba;margin-bottom:4px}
.d-item b{font-size:12px;color:#1e293b;font-weight:500;word-break:break-all}
.missing{display:flex;align-items:center;gap:6px;margin-top:12px;color:#d76e00;background:#fff3df;border-radius:9px;padding:9px 12px;font-size:11px}
.resume-block{margin-top:16px;border-top:1px dashed #e2e8f0;padding-top:13px}
.resume-block h3{display:flex;align-items:center;gap:6px;font-size:13px;color:#334155}
.block-title{display:flex;align-items:center;justify-content:space-between;margin-bottom:10px}
.block-title em{font-style:normal;font-size:10px;color:#8593a7}
.resume-block>.block-title h3{margin-bottom:0}
.tags-cell{display:flex;flex-wrap:wrap;gap:5px}
.tags-cell.manual{margin-top:7px}
.tag{display:inline-flex;align-items:center;padding:3px 8px;border-radius:999px;background:#eef2f7;color:#5e718c;font-size:10px}
.tag.on{background:#e8f2ff;color:#1d6fd1}
.resume-list{list-style:none;display:flex;flex-direction:column;gap:9px}
.resume-list li{background:#f7f9fc;border-radius:9px;padding:9px 12px}
.resume-list li b{font-size:12px;color:#1e293b}
.resume-list li span{display:block;color:#5e718c;font-size:10px;margin-top:3px}
.resume-list li small{display:block;color:#8d9aae;font-size:9px;margin-top:3px}
.app-list{display:flex;flex-direction:column;gap:9px}
.app-item{border:1px solid #e8edf4;border-radius:11px;overflow:hidden}
.app-item.open{border-color:#c7d8f2;background:#fbfdff}
.app-row{display:flex;align-items:center;gap:10px;padding:12px 14px;cursor:pointer}
.app-dot{width:9px;height:9px;border-radius:50%;flex-shrink:0;background:#c8d3e2}
.app-dot.green{background:#2fbf8f}.app-dot.red{background:#e56b6b}.app-dot.blue{background:#4e86e8}
.app-dot.orange{background:#f0a04b}.app-dot.purple{background:#8d78e6}.app-dot.gray{background:#b9c4d4}
.app-main{flex:1;min-width:0}
.app-main b{display:block;font-size:13px;color:#1e293b}
.app-main small{display:flex;align-items:center;gap:4px;color:#8d9aae;font-size:10px;margin-top:4px}
.app-arrow{color:#b3c0d4;transition:transform .18s ease}
.app-item.open .app-arrow{transform:rotate(180deg)}
.app-detail{padding:0 14px 14px;border-top:1px dashed #e8edf4}
.app-detail-head{display:flex;align-items:center;justify-content:space-between;padding:11px 0 14px;font-size:10px;color:#8593a7}
.app-detail-head em{font-style:normal;color:#2563eb}
.timeline{display:flex;align-items:flex-start;gap:0;padding:0 6px}
.node{display:flex;flex-direction:column;align-items:center;gap:5px;width:88px;text-align:center}
.node i{width:20px;height:20px;border-radius:50%;border:2px solid #d3ddea;background:#fff;position:relative}
.node.done i{background:#2fbf8f;border-color:#2fbf8f}
.node.done i::after{content:'';position:absolute;left:6px;top:3px;width:5px;height:9px;border:2px solid #fff;border-top:0;border-left:0;transform:rotate(45deg)}
.node.current i{background:#4e86e8;border-color:#4e86e8}
.node.current i::after{content:'2';position:absolute;inset:0;display:grid;place-items:center;color:#fff;font-size:11px;font-weight:700}
.node b{font-size:11px;color:#334155}
.node small{font-size:9px;color:#9aa9bf}
.line{flex:1;height:2px;background:#2fbf8f;margin-top:9px}
.line.red{background:#e56b6b}.line.blue{background:#4e86e8}.line.gray{background:#c8d3e2}.line.orange{background:#f0a04b}.line.purple{background:#8d78e6}
.app-extra{display:flex;flex-wrap:wrap;gap:16px;margin-top:13px;padding:9px 12px;border-radius:9px;background:#f7f9fc;font-size:10px;color:#718198}
.modal-tip{font-size:11px;color:#5e718c;margin-bottom:12px}
.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.f-item{margin-bottom:12px}
.form-grid .f-item{margin-bottom:0}
.f-item label{display:block;font-size:10px;color:#718198;margin-bottom:5px}
.textarea{padding:9px 12px;font-size:12px;resize:vertical;font-family:inherit}
</style>
