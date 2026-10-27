<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Plus, Search, Pencil, Trash2, X, Eye, WandSparkles, Save, Timer, FileText, GraduationCap, CalendarClock, Bell, Mail, Send, ShieldCheck, FileCheck2 } from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import {
  listQuestions, createQuestion, updateQuestion, deleteQuestion,
  listPapers, getPaper, createPaper, updatePaper, deletePaper, drawPreview,
  listSchedules, createSchedule, updateSchedule, cancelSchedule,
  saveNotifyConfig, listNotifyTargets, sendExamNotify,
  listExamResults, getExamResult, gradeSubjective
} from '@/api/exam'
import { listJobs } from '@/api/system/job'
import { listInterviewers } from '@/api/system/conference'

const route = useRoute()
const router = useRouter()
const toast = ref('')
const tab = ref('questions')
const initPositionId = route.query.positionId ? Number(route.query.positionId) : ''

const TYPE_OPTIONS = [
  { code: 1, label: '单选题' }, { code: 2, label: '多选题' }, { code: 3, label: '判断题' },
  { code: 4, label: '简答题' }, { code: 5, label: '编程题' }
]
const DIFF_OPTIONS = [{ code: 1, label: '简单' }, { code: 2, label: '中等' }, { code: 3, label: '困难' }]
const typeLabel = (t) => (TYPE_OPTIONS.find(x => x.code === Number(t)) || {}).label || t
const diffLabel = (d) => (DIFF_OPTIONS.find(x => x.code === Number(d)) || {}).label || d
const STATUS_META = { 0: ['待生效', 'gray'], 1: ['进行中', 'green'], 2: ['已结束', 'orange'], 3: ['已取消', 'red'] }

function notify(m) { toast.value = m; setTimeout(() => { toast.value = '' }, 2400) }
function optText(o) { return typeof o === 'string' ? o : (o && (o.text || o.label)) || '' }

/* ==================== 岗位选项 ==================== */
const positions = ref([])
async function loadPositions() {
  const res = await listJobs({ pageNum: 1, pageSize: 200 }).catch(() => null)
  positions.value = (res?.rows || []).map(r => ({ id: r.posId, title: r.title }))
}

/* ==================== 题库 ==================== */
const qFilter = reactive({ type: '', difficulty: '', skillTag: '', keyword: '' })
const qList = ref([])
const qTotal = ref(0)
const qPage = ref(1)
const qPageSize = 10

async function loadQuestions() {
  const res = await listQuestions({
    pageNum: qPage.value, pageSize: qPageSize,
    type: qFilter.type || undefined, difficulty: qFilter.difficulty || undefined,
    skillTag: qFilter.skillTag || undefined, keyword: qFilter.keyword || undefined
  }).catch(() => null)
  qList.value = res?.rows || []
  qTotal.value = res?.total || 0
}

const qModal = reactive({ open: false, id: null, saving: false, form: blankQuestion() })
function blankQuestion() {
  return { type: 1, content: '', options: ['', '', '', ''], answer: '', score: 5, difficulty: 2, skillTag: '' }
}
function openCreateQ() {
  Object.assign(qModal, { open: true, id: null, form: blankQuestion() })
}
function openEditQ(row) {
  qModal.open = true; qModal.id = row.questionId
  qModal.form = {
    type: row.type, content: row.content,
    options: Array.isArray(row.options) ? row.options.map(optText) : (row.type <= 3 ? ['', '', '', ''] : []),
    answer: row.answer || '', score: Number(row.score), difficulty: row.difficulty, skillTag: row.skillTag || ''
  }
}
function addOption() { if (qModal.form.options.length < 8) qModal.form.options.push('') }
function removeOption(i) { qModal.form.options.splice(i, 1) }
async function saveQuestion() {
  qModal.saving = true
  try {
    const body = { ...qModal.form }
    if (body.type > 3) delete body.options
    else body.options = body.options.filter(o => o.trim())
    if (qModal.id) await updateQuestion(qModal.id, body)
    else await createQuestion(body)
    qModal.open = false
    notify('题目已保存')
    loadQuestions()
  } catch (e) { /* 拦截器已提示 */ } finally { qModal.saving = false }
}
async function removeQ(row) {
  if (!confirm(`确定删除题目 #${row.questionId}？`)) return
  try { await deleteQuestion(row.questionId); notify('题目已删除'); loadQuestions() } catch (e) { /* 拦截器已提示 */ }
}

/* ==================== 试卷 ==================== */
const pFilter = reactive({ positionId: initPositionId })
const pList = ref([])
async function loadPapers() {
  const res = await listPapers(pFilter.positionId || undefined).catch(() => null)
  pList.value = res?.data || []
}

const paperModal = reactive({
  open: false, view: false, id: null, saving: false,
  form: { name: '', positionId: '', durationMin: 60, mode: 'manual', selected: [], rules: [] },
  pool: [], poolKeyword: '', preview: null
})
function blankPaper() {
  return { name: '', positionId: pFilter.positionId || '', durationMin: 60, mode: 'manual', selected: [], rules: [] }
}
async function loadPool() {
  const res = await listQuestions({ pageNum: 1, pageSize: 100, keyword: paperModal.poolKeyword || undefined }).catch(() => null)
  paperModal.pool = res?.rows || []
}
function openCreatePaper() {
  Object.assign(paperModal, { open: true, view: false, id: null, form: blankPaper(), preview: null })
  loadPool()
}
async function openEditPaper(row, view) {
  const res = await getPaper(row.paperId).catch(() => null)
  if (!res) return
  const p = res.data
  paperModal.open = true; paperModal.view = !!view; paperModal.id = p.paperId; paperModal.preview = null
  paperModal.form = {
    name: p.name, positionId: p.positionId, durationMin: p.durationMin,
    mode: p.ruleJson ? 'random' : 'manual',
    selected: (p.questions || []).map(q => ({ questionId: q.questionId, score: Number(q.score), type: q.type, content: q.content })),
    rules: (p.rule && p.rule.rules) ? p.rule.rules.map(r => ({ ...r })) : []
  }
  if (!view) loadPool()
}
function togglePool(q) {
  const i = paperModal.form.selected.findIndex(s => s.questionId === q.questionId)
  if (i >= 0) paperModal.form.selected.splice(i, 1)
  else paperModal.form.selected.push({ questionId: q.questionId, score: Number(q.score), type: q.type, content: q.content })
}
function addRule() { if (paperModal.form.rules.length < 10) paperModal.form.rules.push({ type: 1, difficulty: '', skillTag: '', count: 5, score: 5 }) }
function removeRule(i) { paperModal.form.rules.splice(i, 1) }
async function previewDraw() {
  try {
    const res = await drawPreview({ rules: paperModal.form.rules.map(r => ({ type: r.type || undefined, difficulty: r.difficulty || undefined, skillTag: r.skillTag || undefined, count: Number(r.count), score: Number(r.score) })) })
    paperModal.preview = res.data
    notify(`预览抽中 ${res.data.questionCount} 题，总分 ${res.data.totalScore}`)
  } catch (e) { paperModal.preview = null }
}
async function savePaper() {
  paperModal.saving = true
  try {
    const f = paperModal.form
    const body = { name: f.name, positionId: Number(f.positionId), durationMin: Number(f.durationMin), mode: f.mode }
    if (f.mode === 'random') body.rule = { rules: f.rules.map(r => ({ type: r.type || undefined, difficulty: r.difficulty || undefined, skillTag: r.skillTag || undefined, count: Number(r.count), score: Number(r.score) })) }
    else body.questions = f.selected.map(s => ({ questionId: s.questionId, score: Number(s.score) }))
    if (paperModal.id) await updatePaper(paperModal.id, body)
    else await createPaper(body)
    paperModal.open = false
    notify('试卷已保存')
    loadPapers()
  } catch (e) { /* 拦截器已提示 */ } finally { paperModal.saving = false }
}
async function removePaper(row) {
  if (!confirm(`确定删除试卷「${row.name}」？`)) return
  try { await deletePaper(row.paperId); notify('试卷已删除'); loadPapers() } catch (e) { /* 拦截器已提示 */ }
}

/* ==================== 考试安排 ==================== */
const sFilter = reactive({ positionId: initPositionId, status: '' })
const sList = ref([])
const sTotal = ref(0)
const sPage = ref(1)
const sPageSize = 10
async function loadSchedules() {
  const res = await listSchedules({
    pageNum: sPage.value, pageSize: sPageSize,
    positionId: sFilter.positionId || undefined, status: sFilter.status === '' ? undefined : sFilter.status
  }).catch(() => null)
  sList.value = res?.rows || []
  sTotal.value = res?.total || 0
}

const schedModal = reactive({
  open: false, id: null, saving: false, papers: [],
  form: blankSchedule()
})
const interviewers = ref([])
async function loadInterviewers() {
  try {
    const res = await listInterviewers()
    interviewers.value = res?.data || []
  } catch (e) { interviewers.value = [] }
}
function blankSchedule() {
  return {
    paperId: '', startAt: '', endAt: '', maxAttempts: 1, passThreshold: 60,
    forceDualCamera: 0, dualAngle: '侧后方 45°，须拍到桌面与双手', dualNote: '',
    autoSubmit: true, allowEarly: true, autosaveInterval: 30,
    autoInterviewerId: '', autoInviteDays: 3, autoInviteDuration: 45
  }
}
async function openCreateSched() {
  Object.assign(schedModal, { open: true, id: null, form: blankSchedule() })
  if (!interviewers.value.length) loadInterviewers()
  const res = await listPapers(sFilter.positionId || undefined).catch(() => null)
  schedModal.papers = (res?.data || []).filter(p => p.status === 1)
}
async function openEditSched(row) {
  const res = await listPapers().catch(() => null)
  schedModal.papers = res?.data || []
  schedModal.open = true; schedModal.id = row.scheduleId
  const dual = row.dualCameraConfig || {}
  const sub = row.submitRule || {}
  const flow = row.autoFlow || {}
  if (!interviewers.value.length) loadInterviewers()
  schedModal.form = {
    paperId: row.paperId, startAt: (row.startAt || '').replace(' ', 'T'), endAt: (row.endAt || '').replace(' ', 'T'),
    maxAttempts: row.maxAttempts, passThreshold: Number(row.passThreshold),
    forceDualCamera: Number(row.forceDualCamera) || 0,
    dualAngle: dual.angle || '', dualNote: dual.note || '',
    autoSubmit: sub.autoSubmit !== false, allowEarly: sub.allowEarly !== false,
    autosaveInterval: sub.autosaveInterval ?? 30,
    autoInterviewerId: flow.interviewerId ? String(flow.interviewerId) : '',
    autoInviteDays: flow.startAfterDays ?? 3, autoInviteDuration: flow.durationMin ?? 45
  }
}
const chosenPaper = computed(() => schedModal.papers.find(p => p.paperId === Number(schedModal.form.paperId)) || null)
async function saveSchedule() {
  schedModal.saving = true
  try {
    const f = schedModal.form
    const body = {
      positionId: chosenPaper.value ? chosenPaper.value.positionId : undefined,
      paperId: Number(f.paperId), startAt: f.startAt, endAt: f.endAt,
      maxAttempts: Number(f.maxAttempts), passThreshold: Number(f.passThreshold),
      forceDualCamera: Number(f.forceDualCamera),
      dualCameraConfig: Number(f.forceDualCamera) ? { angle: f.dualAngle, note: f.dualNote } : null,
      submitRule: { autoSubmit: f.autoSubmit, allowEarly: f.allowEarly, autosaveInterval: Number(f.autosaveInterval) },
      autoFlow: f.autoInterviewerId ? {
        interviewerId: Number(f.autoInterviewerId),
        startAfterDays: Number(f.autoInviteDays) || 3,
        durationMin: Number(f.autoInviteDuration) || 45
      } : null
    }
    if (schedModal.id) await updateSchedule(schedModal.id, body)
    else await createSchedule(body)
    schedModal.open = false
    notify('考试安排已保存')
    loadSchedules()
  } catch (e) { /* 拦截器已提示 */ } finally { schedModal.saving = false }
}
async function cancelSched(row) {
  if (!confirm(`确定取消该考试安排？取消后候选人将无法作答。`)) return
  try { await cancelSchedule(row.scheduleId); notify('考试安排已取消'); loadSchedules() } catch (e) { /* 拦截器已提示 */ }
}

/* ==================== 笔试通知 ==================== */
const notifyModal = reactive({
  open: false, row: null, saving: false, sending: false,
  targets: [], selected: [], result: null,
  form: { channels: ['inapp'], title: '', content: '', examUrl: '' }
})
const CHANNEL_META = [
  { code: 'email', label: '邮件', icon: Mail },
  { code: 'inapp', label: '站内信', icon: Bell }
]
const CHANNEL_RESULT = { sent: '已发送', failed: '发送失败', skipped_no_email: '无邮箱跳过', not_selected: '未选渠道' }
function defaultExamUrl(row) {
  const base = import.meta.env.VITE_CANDIDATE_APP_URL || ''
  return `${base}/exam?scheduleId=${row.scheduleId}`
}
async function openNotify(row) {
  notifyModal.open = true; notifyModal.row = row; notifyModal.result = null; notifyModal.selected = []
  const cfg = row.notifyConfig || {}
  notifyModal.form = {
    channels: Array.isArray(cfg.channels) && cfg.channels.length ? [...cfg.channels] : ['inapp'],
    title: cfg.title || '', content: cfg.content || '', examUrl: cfg.examUrl || defaultExamUrl(row)
  }
  try {
    const res = await listNotifyTargets(row.scheduleId)
    notifyModal.targets = res?.data || []
  } catch (e) { notifyModal.targets = [] }
}
function toggleChannel(code) {
  const arr = notifyModal.form.channels
  const i = arr.indexOf(code)
  if (i >= 0) arr.splice(i, 1); else arr.push(code)
}
async function saveNotifyCfg() {
  notifyModal.saving = true
  try {
    await saveNotifyConfig(notifyModal.row.scheduleId, { ...notifyModal.form })
    notify('通知配置已保存')
    loadSchedules()
  } catch (e) { /* 拦截器已提示 */ } finally { notifyModal.saving = false }
}
async function doSendNotify() {
  if (!notifyModal.form.channels.length) { notify('请至少选择一个通知渠道'); return }
  notifyModal.sending = true
  try {
    const body = { ...notifyModal.form }
    if (notifyModal.selected.length) body.candidateIds = [...notifyModal.selected]
    const res = await sendExamNotify(notifyModal.row.scheduleId, body)
    notifyModal.result = res?.data || null
    notify(`已发送 ${notifyModal.result?.sent ?? 0} 位候选人的笔试通知`)
  } catch (e) { /* 拦截器已提示 */ } finally { notifyModal.sending = false }
}

/* ==================== 成绩报告 ==================== */
const PASS_META = { 0: ['未通过', 'red'], 1: ['通过', 'green'], 2: ['待主观题评分', 'orange'] }
const rFilter = reactive({ positionId: initPositionId, passStatus: '' })
const rList = ref([])
const rTotal = ref(0)
const rPage = ref(1)
const rPageSize = 10
async function loadResults() {
  const res = await listExamResults({
    pageNum: rPage.value, pageSize: rPageSize,
    positionId: rFilter.positionId || undefined,
    passStatus: rFilter.passStatus === '' ? undefined : rFilter.passStatus
  }).catch(() => null)
  rList.value = res?.rows || []
  rTotal.value = res?.total || 0
}

const reportModal = reactive({ open: false, loading: false, saving: false, data: null, scores: {}, comment: '' })
async function openReport(row) {
  reportModal.open = true; reportModal.loading = true; reportModal.data = null; reportModal.scores = {}
  try {
    const res = await getExamResult(row.recordId)
    const d = res?.data || null
    reportModal.data = d
    reportModal.comment = d?.comment || ''
    for (const a of (d?.answers || [])) {
      if (Number(a.type) > 3) reportModal.scores[a.questionId] = a.score == null ? '' : Number(a.score)
    }
  } catch (e) { /* 拦截器已提示 */ } finally { reportModal.loading = false }
}
const subjectiveAnswers = computed(() => (reportModal.data?.answers || []).filter(a => Number(a.type) > 3))
async function saveSubjective() {
  reportModal.saving = true
  try {
    const scores = subjectiveAnswers.value.map(a => ({
      questionId: a.questionId, score: Number(reportModal.scores[a.questionId]) || 0
    }))
    const res = await gradeSubjective(reportModal.data.recordId, { scores, comment: reportModal.comment })
    reportModal.data = { ...reportModal.data, ...(res?.data || {}) }
    notify('主观题评分已保存，成绩已终判')
    loadResults()
  } catch (e) { /* 拦截器已提示 */ } finally { reportModal.saving = false }
}
function answerText(a) {
  return a.answer == null || String(a.answer).trim() === '' ? '（未作答）' : String(a.answer)
}
function optKey(i) { return String.fromCharCode(65 + i) }
// 把 "AC"/"A,C" 这类选择型作答归一化为选项字母数组；判断题的"对/错"不参与选项高亮
function choiceKeys(v) {
  const s = String(v == null ? '' : v).trim().toUpperCase()
  if (!/[A-Z]/.test(s) || /[^A-Z\s,，、;；]/.test(s)) return []
  return s.replace(/[^A-Z]/g, '').split('')
}
function answerKeys(a) { return choiceKeys(a.answer) }
function stdKeys(a) { return choiceKeys(a.stdAnswer) }

function switchTab(t) {
  tab.value = t
  if (t === 'questions' && !qList.value.length) loadQuestions()
  if (t === 'papers' && !pList.value.length) loadPapers()
  if (t === 'schedules' && !sList.value.length) loadSchedules()
  if (t === 'results') loadResults()
}

onMounted(() => {
  loadPositions()
  loadQuestions()
  loadPapers()
  loadSchedules()
})
</script>

<template>
  <div class="page exam-page">
    <div class="page-heading">
      <div>
        <h1>在线笔试</h1>
        <p>题库维护 · 组卷规则 · 考试安排与双机位/交卷配置</p>
      </div>
      <div class="tabs">
        <button :class="['tab-btn', { on: tab === 'questions' }]" @click="switchTab('questions')"><GraduationCap :size="15"/>题库</button>
        <button :class="['tab-btn', { on: tab === 'papers' }]" @click="switchTab('papers')"><FileText :size="15"/>试卷</button>
        <button :class="['tab-btn', { on: tab === 'schedules' }]" @click="switchTab('schedules')"><CalendarClock :size="15"/>考试安排</button>
        <button :class="['tab-btn', { on: tab === 'results' }]" @click="switchTab('results')"><FileCheck2 :size="15"/>成绩报告</button>
        <button class="tab-btn proctor" @click="router.push('/enterprise/exam/proctor')"><ShieldCheck :size="15"/>双机位监考</button>
      </div>
    </div>

    <!-- ============ 题库 ============ -->
    <section v-show="tab === 'questions'" class="card panel">
      <div class="toolbar">
        <select class="select slim" v-model="qFilter.type" @change="qPage = 1; loadQuestions()">
          <option value="">全部题型</option>
          <option v-for="t in TYPE_OPTIONS" :key="t.code" :value="t.code">{{ t.label }}</option>
        </select>
        <select class="select slim" v-model="qFilter.difficulty" @change="qPage = 1; loadQuestions()">
          <option value="">全部难度</option>
          <option v-for="d in DIFF_OPTIONS" :key="d.code" :value="d.code">{{ d.label }}</option>
        </select>
        <input class="input slim" v-model="qFilter.skillTag" placeholder="技能标签" @keyup.enter="qPage = 1; loadQuestions()" />
        <input class="input slim grow" v-model="qFilter.keyword" placeholder="搜索题干关键词" @keyup.enter="qPage = 1; loadQuestions()" />
        <button class="btn" @click="qPage = 1; loadQuestions()"><Search :size="15"/>查询</button>
        <button class="btn primary" @click="openCreateQ"><Plus :size="15"/>新增题目</button>
      </div>
      <table class="tbl">
        <thead><tr><th>ID</th><th>题型</th><th class="wide">题干</th><th>难度</th><th>标签</th><th>分值</th><th>创建时间</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="row in qList" :key="row.questionId">
            <td>{{ row.questionId }}</td>
            <td><span class="pill" :class="row.type <= 3 ? '' : 'purple'">{{ typeLabel(row.type) }}</span></td>
            <td class="wide ellipsis" :title="row.content">{{ row.content }}</td>
            <td>{{ diffLabel(row.difficulty) }}</td>
            <td><span v-if="row.skillTag" class="tag">{{ row.skillTag }}</span><span v-else class="muted">—</span></td>
            <td>{{ row.score }}</td>
            <td class="muted">{{ row.createdAt }}</td>
            <td class="ops">
              <button class="icon-btn" title="编辑" @click="openEditQ(row)"><Pencil :size="14"/></button>
              <button class="icon-btn danger" title="删除" @click="removeQ(row)"><Trash2 :size="14"/></button>
            </td>
          </tr>
          <tr v-if="!qList.length"><td colspan="8"><div class="empty">暂无题目，点击「新增题目」创建题库</div></td></tr>
        </tbody>
      </table>
      <div class="pager">
        <span class="muted tiny">共 {{ qTotal }} 题</span>
        <button class="btn sm" :disabled="qPage <= 1" @click="qPage--; loadQuestions()">上一页</button>
        <span class="tiny">{{ qPage }} / {{ Math.max(1, Math.ceil(qTotal / qPageSize)) }}</span>
        <button class="btn sm" :disabled="qPage * qPageSize >= qTotal" @click="qPage++; loadQuestions()">下一页</button>
      </div>
    </section>

    <!-- ============ 试卷 ============ -->
    <section v-show="tab === 'papers'" class="card panel">
      <div class="toolbar">
        <select class="select slim" v-model="pFilter.positionId" @change="loadPapers()">
          <option value="">全部岗位</option>
          <option v-for="p in positions" :key="p.id" :value="p.id">{{ p.title }}</option>
        </select>
        <button class="btn" @click="loadPapers()"><Search :size="15"/>刷新</button>
        <button class="btn primary" @click="openCreatePaper"><Plus :size="15"/>新建试卷</button>
      </div>
      <table class="tbl">
        <thead><tr><th>ID</th><th class="wide">试卷名称</th><th>岗位</th><th>组卷方式</th><th>题量</th><th>总分</th><th>时长</th><th>状态</th><th>创建时间</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="row in pList" :key="row.paperId">
            <td>{{ row.paperId }}</td>
            <td class="wide ellipsis">{{ row.name }}</td>
            <td>{{ row.positionTitle }}</td>
            <td><span class="pill" :class="row.ruleJson ? 'orange' : ''">{{ row.ruleJson ? '随机抽题' : '人工组卷' }}</span></td>
            <td>{{ row.ruleJson ? '按规则' : row.questionCount }}</td>
            <td>{{ row.totalScore }}</td>
            <td>{{ row.durationMin }} 分钟</td>
            <td><span class="pill" :class="row.status === 1 ? 'green' : 'gray'">{{ row.status === 1 ? '启用' : '停用' }}</span></td>
            <td class="muted">{{ row.createdAt }}</td>
            <td class="ops">
              <button class="icon-btn" title="查看题目" @click="openEditPaper(row, true)"><Eye :size="14"/></button>
              <button class="icon-btn" title="编辑" @click="openEditPaper(row, false)"><Pencil :size="14"/></button>
              <button class="icon-btn danger" title="删除" @click="removePaper(row)"><Trash2 :size="14"/></button>
            </td>
          </tr>
          <tr v-if="!pList.length"><td colspan="10"><div class="empty">暂无试卷，点击「新建试卷」开始组卷</div></td></tr>
        </tbody>
      </table>
    </section>

    <!-- ============ 考试安排 ============ -->
    <section v-show="tab === 'schedules'" class="card panel">
      <div class="toolbar">
        <select class="select slim" v-model="sFilter.positionId" @change="sPage = 1; loadSchedules()">
          <option value="">全部岗位</option>
          <option v-for="p in positions" :key="p.id" :value="p.id">{{ p.title }}</option>
        </select>
        <select class="select slim" v-model="sFilter.status" @change="sPage = 1; loadSchedules()">
          <option value="">全部状态</option>
          <option value="0">待生效</option><option value="1">进行中</option>
          <option value="2">已结束</option><option value="3">已取消</option>
        </select>
        <button class="btn" @click="loadSchedules()"><Search :size="15"/>刷新</button>
        <button class="btn primary" @click="openCreateSched"><Plus :size="15"/>新建考试安排</button>
      </div>
      <table class="tbl">
        <thead><tr><th>ID</th><th>岗位</th><th class="wide">试卷</th><th>开考时间</th><th>截止时间</th><th>次数</th><th>阈值</th><th>双机位</th><th>状态</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="row in sList" :key="row.scheduleId">
            <td>{{ row.scheduleId }}</td>
            <td>{{ row.positionTitle }}</td>
            <td class="wide ellipsis">{{ row.paperName }}（{{ row.durationMin }}分钟/{{ row.totalScore }}分）</td>
            <td>{{ row.startAt }}</td>
            <td>{{ row.endAt }}</td>
            <td>{{ row.maxAttempts }}</td>
            <td>{{ row.passThreshold }}</td>
            <td><span class="pill" :class="row.forceDualCamera ? 'purple' : 'gray'">{{ row.forceDualCamera ? '强制' : '不启用' }}</span></td>
            <td><span class="pill" :class="STATUS_META[row.status][1]"><i class="dot"/>{{ STATUS_META[row.status][0] }}</span></td>
            <td class="ops">
              <button class="icon-btn" title="笔试通知" :disabled="row.status >= 2" @click="openNotify(row)"><Bell :size="14"/></button>
              <button class="icon-btn" title="编辑" :disabled="row.status >= 2" @click="openEditSched(row)"><Pencil :size="14"/></button>
              <button class="icon-btn danger" title="取消" :disabled="row.status >= 2" @click="cancelSched(row)"><X :size="14"/></button>
            </td>
          </tr>
          <tr v-if="!sList.length"><td colspan="10"><div class="empty">暂无考试安排，点击「新建考试安排」发布笔试</div></td></tr>
        </tbody>
      </table>
      <div class="pager">
        <span class="muted tiny">共 {{ sTotal }} 条</span>
        <button class="btn sm" :disabled="sPage <= 1" @click="sPage--; loadSchedules()">上一页</button>
        <span class="tiny">{{ sPage }} / {{ Math.max(1, Math.ceil(sTotal / sPageSize)) }}</span>
        <button class="btn sm" :disabled="sPage * sPageSize >= sTotal" @click="sPage++; loadSchedules()">下一页</button>
      </div>
    </section>

    <!-- ============ 成绩报告 ============ -->
    <section v-show="tab === 'results'" class="card panel">
      <div class="toolbar">
        <select class="select slim" v-model="rFilter.positionId" @change="rPage = 1; loadResults()">
          <option value="">全部岗位</option>
          <option v-for="p in positions" :key="p.id" :value="p.id">{{ p.title }}</option>
        </select>
        <select class="select slim" v-model="rFilter.passStatus" @change="rPage = 1; loadResults()">
          <option value="">全部结果</option>
          <option value="1">通过</option>
          <option value="0">未通过</option>
          <option value="2">待主观题评分</option>
        </select>
        <button class="btn" @click="loadResults()"><Search :size="15"/>刷新</button>
      </div>
      <table class="tbl">
        <thead><tr><th>候选人</th><th>岗位</th><th class="wide">试卷</th><th>交卷时间</th><th>客观分</th><th>主观分</th><th>总分</th><th>阈值</th><th>结果</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="row in rList" :key="row.recordId">
            <td>{{ row.candidateName || '—' }}</td>
            <td>{{ row.positionTitle }}</td>
            <td class="wide ellipsis" :title="row.paperName">{{ row.paperName }}</td>
            <td class="muted">{{ row.submitAt || '—' }}</td>
            <td>{{ row.objectiveScore == null ? '—' : row.objectiveScore }}</td>
            <td>{{ row.subjectiveScore == null ? '—' : row.subjectiveScore }}</td>
            <td><b>{{ row.totalScore == null ? '—' : row.totalScore }}</b><span class="muted tiny"> / {{ row.paperTotalScore }}</span></td>
            <td>{{ row.passThreshold }}</td>
            <td><span v-if="PASS_META[row.passStatus]" class="pill" :class="PASS_META[row.passStatus][1]">{{ PASS_META[row.passStatus][0] }}</span><span v-else class="muted">未判分</span></td>
            <td class="ops">
              <button class="btn sm" @click="openReport(row)"><Eye :size="14"/>查看答题</button>
            </td>
          </tr>
          <tr v-if="!rList.length"><td colspan="10"><div class="empty">暂无已交卷的笔试记录</div></td></tr>
        </tbody>
      </table>
      <div class="pager">
        <span class="muted tiny">共 {{ rTotal }} 条</span>
        <button class="btn sm" :disabled="rPage <= 1" @click="rPage--; loadResults()">上一页</button>
        <span class="tiny">{{ rPage }} / {{ Math.max(1, Math.ceil(rTotal / rPageSize)) }}</span>
        <button class="btn sm" :disabled="rPage * rPageSize >= rTotal" @click="rPage++; loadResults()">下一页</button>
      </div>
    </section>

    <!-- ============ 题目编辑弹层 ============ -->
    <div v-if="qModal.open" class="mask" @click.self="qModal.open = false">
      <div class="modal">
        <header><h3>{{ qModal.id ? '编辑题目 #' + qModal.id : '新增题目' }}</h3><button class="icon-btn" @click="qModal.open = false"><X :size="15"/></button></header>
        <div class="body">
          <div class="form-grid">
            <div class="field"><label>题型</label>
              <select class="select" v-model.number="qModal.form.type">
                <option v-for="t in TYPE_OPTIONS" :key="t.code" :value="t.code">{{ t.label }}</option>
              </select>
            </div>
            <div class="field"><label>难度</label>
              <select class="select" v-model.number="qModal.form.difficulty">
                <option v-for="d in DIFF_OPTIONS" :key="d.code" :value="d.code">{{ d.label }}</option>
              </select>
            </div>
            <div class="field full"><label>题干</label><textarea class="textarea" v-model="qModal.form.content" placeholder="请输入题干内容"/></div>
            <div v-if="qModal.form.type <= 3" class="field full">
              <label>选项<span class="muted tiny">（判断题默认「对/错」，单选/多选按顺序对应 A、B、C…）</span></label>
              <div class="opt-row" v-for="(o, i) in qModal.form.options" :key="i">
                <span class="opt-key">{{ String.fromCharCode(65 + i) }}</span>
                <input class="input" v-model="qModal.form.options[i]" :placeholder="'选项 ' + String.fromCharCode(65 + i)"/>
                <button class="icon-btn" title="删除选项" @click="removeOption(i)" :disabled="qModal.form.options.length <= 2"><Trash2 :size="13"/></button>
              </div>
              <button class="btn sm ghost-primary" @click="addOption"><Plus :size="13"/>添加选项</button>
            </div>
            <div class="field full"><label>标准答案<span class="muted tiny">（单选如 A；多选如 ABD；判断填 对/错；简答/编程填参考答案）</span></label>
              <textarea class="textarea short" v-model="qModal.form.answer" placeholder="请输入标准答案"/>
            </div>
            <div class="field"><label>分值</label><input class="input" type="number" min="1" v-model.number="qModal.form.score"/></div>
            <div class="field"><label>技能标签</label><input class="input" v-model="qModal.form.skillTag" placeholder="如 Java 并发"/></div>
          </div>
        </div>
        <footer><button class="btn" @click="qModal.open = false">取消</button><button class="btn primary" :disabled="qModal.saving" @click="saveQuestion"><Save :size="15"/>保存题目</button></footer>
      </div>
    </div>

    <!-- ============ 试卷编辑弹层 ============ -->
    <div v-if="paperModal.open" class="mask" @click.self="paperModal.open = false">
      <div class="modal wide">
        <header><h3>{{ paperModal.view ? '试卷详情 #' + paperModal.id : (paperModal.id ? '编辑试卷 #' + paperModal.id : '新建试卷') }}</h3><button class="icon-btn" @click="paperModal.open = false"><X :size="15"/></button></header>
        <div class="body">
          <div class="form-grid">
            <div class="field"><label>试卷名称</label><input class="input" v-model="paperModal.form.name" :disabled="paperModal.view" placeholder="如 Java 后端基础笔试"/></div>
            <div class="field"><label>关联岗位</label>
              <select class="select" v-model="paperModal.form.positionId" :disabled="paperModal.view || !!paperModal.id">
                <option value="" disabled>请选择岗位</option>
                <option v-for="p in positions" :key="p.id" :value="p.id">{{ p.title }}</option>
              </select>
            </div>
            <div class="field"><label>考试时长（分钟）</label><input class="input" type="number" min="1" v-model.number="paperModal.form.durationMin" :disabled="paperModal.view"/></div>
            <div v-if="!paperModal.view" class="field"><label>组卷方式</label>
              <div class="seg">
                <button :class="['seg-btn', { on: paperModal.form.mode === 'manual' }]" @click="paperModal.form.mode = 'manual'">人工选题</button>
                <button :class="['seg-btn', { on: paperModal.form.mode === 'random' }]" @click="paperModal.form.mode = 'random'">随机抽题</button>
              </div>
            </div>
          </div>

          <!-- 人工组卷 -->
          <template v-if="paperModal.form.mode === 'manual' || paperModal.view">
            <div v-if="!paperModal.view" class="sub-block">
              <div class="sub-head"><b>从题库选题（点击加入/移除）</b>
                <div class="inline-search"><input class="input slim" v-model="paperModal.poolKeyword" placeholder="搜索题干" @keyup.enter="loadPool()"/><button class="btn sm" @click="loadPool()"><Search :size="13"/></button></div>
              </div>
              <div class="pool">
                <div v-for="q in paperModal.pool" :key="q.questionId" :class="['pool-item', { picked: paperModal.form.selected.some(s => s.questionId === q.questionId) }]" @click="togglePool(q)">
                  <span class="pill sm">{{ typeLabel(q.type) }}</span>
                  <span class="pool-text">{{ q.content }}</span>
                  <span class="muted tiny">{{ q.score }}分</span>
                </div>
                <div v-if="!paperModal.pool.length" class="empty">题库暂无题目</div>
              </div>
            </div>
            <div class="sub-block">
              <div class="sub-head"><b>已选题目（{{ paperModal.form.selected.length }} 题，总分 {{ paperModal.form.selected.reduce((a, s) => a + Number(s.score || 0), 0) }}）</b></div>
              <table v-if="paperModal.form.selected.length" class="tbl inner">
                <thead><tr><th>ID</th><th>题型</th><th class="wide">题干</th><th>分值</th><th v-if="!paperModal.view">操作</th></tr></thead>
                <tbody>
                  <tr v-for="s in paperModal.form.selected" :key="s.questionId">
                    <td>{{ s.questionId }}</td><td>{{ typeLabel(s.type) }}</td>
                    <td class="wide ellipsis">{{ s.content }}</td>
                    <td><input v-if="!paperModal.view" class="input tiny-input" type="number" min="1" v-model.number="s.score"/><span v-else>{{ s.score }}</span></td>
                    <td v-if="!paperModal.view"><button class="icon-btn danger" @click="togglePool(s)"><Trash2 :size="13"/></button></td>
                  </tr>
                </tbody>
              </table>
              <div v-else class="empty">尚未选择题</div>
            </div>
          </template>

          <!-- 随机抽题 -->
          <template v-if="paperModal.form.mode === 'random' && !paperModal.view">
            <div class="sub-block">
              <div class="sub-head"><b>抽题规则</b><button class="btn sm ghost-primary" @click="addRule"><Plus :size="13"/>添加规则组</button></div>
              <div v-for="(r, i) in paperModal.form.rules" :key="i" class="rule-row">
                <select class="select slim" v-model.number="r.type"><option v-for="t in TYPE_OPTIONS" :key="t.code" :value="t.code">{{ t.label }}</option></select>
                <select class="select slim" v-model="r.difficulty"><option value="">全部难度</option><option v-for="d in DIFF_OPTIONS" :key="d.code" :value="d.code">{{ d.label }}</option></select>
                <input class="input slim" v-model="r.skillTag" placeholder="技能标签(可空)"/>
                <label class="mini">数量</label><input class="input tiny-input" type="number" min="1" v-model.number="r.count"/>
                <label class="mini">每题分值</label><input class="input tiny-input" type="number" min="1" v-model.number="r.score"/>
                <button class="icon-btn danger" @click="removeRule(i)"><Trash2 :size="13"/></button>
              </div>
              <div v-if="!paperModal.form.rules.length" class="empty">暂无规则组，点击「添加规则组」</div>
              <div class="preview-row">
                <button class="btn sm" @click="previewDraw"><WandSparkles :size="14"/>预览抽题结果</button>
                <span v-if="paperModal.preview" class="muted tiny">抽中 {{ paperModal.preview.questionCount }} 题 · 总分 {{ paperModal.preview.totalScore }}</span>
              </div>
              <table v-if="paperModal.preview" class="tbl inner">
                <thead><tr><th>ID</th><th>题型</th><th class="wide">题干</th><th>分值</th></tr></thead>
                <tbody>
                  <tr v-for="q in paperModal.preview.questions" :key="q.questionId">
                    <td>{{ q.questionId }}</td><td>{{ typeLabel(q.type) }}</td><td class="wide ellipsis">{{ q.content }}</td><td>{{ q.score }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </template>
        </div>
        <footer>
          <button class="btn" @click="paperModal.open = false">{{ paperModal.view ? '关闭' : '取消' }}</button>
          <button v-if="!paperModal.view" class="btn primary" :disabled="paperModal.saving" @click="savePaper"><Save :size="15"/>保存试卷</button>
        </footer>
      </div>
    </div>

    <!-- ============ 考试安排弹层 ============ -->
    <div v-if="schedModal.open" class="mask" @click.self="schedModal.open = false">
      <div class="modal wide">
        <header><h3>{{ schedModal.id ? '编辑考试安排 #' + schedModal.id : '新建考试安排' }}</h3><button class="icon-btn" @click="schedModal.open = false"><X :size="15"/></button></header>
        <div class="body">
          <div class="form-grid">
            <div class="field full"><label>选择试卷</label>
              <select class="select" v-model="schedModal.form.paperId">
                <option value="" disabled>请选择启用中的试卷</option>
                <option v-for="p in schedModal.papers" :key="p.paperId" :value="p.paperId">{{ p.name }}（{{ p.positionTitle }} · {{ p.durationMin }}分钟 · {{ p.totalScore }}分）</option>
              </select>
              <small v-if="!schedModal.papers.length" class="muted tiny">当前岗位暂无启用试卷，请先在「试卷」页创建</small>
            </div>
            <div class="field"><label>开考时间</label><input class="input" type="datetime-local" v-model="schedModal.form.startAt"/></div>
            <div class="field"><label>截止时间</label><input class="input" type="datetime-local" v-model="schedModal.form.endAt"/></div>
            <div class="field"><label>最大考试次数</label><input class="input" type="number" min="1" v-model.number="schedModal.form.maxAttempts"/></div>
            <div class="field"><label>通过阈值（分）<span v-if="chosenPaper" class="muted tiny">总分 {{ chosenPaper.totalScore }}</span></label><input class="input" type="number" min="1" v-model.number="schedModal.form.passThreshold"/></div>
            <div class="field full"><label>交卷规则</label>
              <div class="check-row">
                <label><input type="checkbox" v-model="schedModal.form.autoSubmit"/>超时自动交卷</label>
                <label><input type="checkbox" v-model="schedModal.form.allowEarly"/>允许提前交卷</label>
                <label class="inline-interval"><Timer :size="14"/>自动保存间隔
                  <input class="input tiny-input" type="number" min="5" v-model.number="schedModal.form.autosaveInterval"/> 秒
                </label>
              </div>
            </div>
            <div class="field full"><label>双机位要求</label>
              <div class="seg">
                <button :class="['seg-btn', { on: !schedModal.form.forceDualCamera }]" @click="schedModal.form.forceDualCamera = 0">不启用</button>
                <button :class="['seg-btn', { on: schedModal.form.forceDualCamera }]" @click="schedModal.form.forceDualCamera = 1">强制双机位</button>
              </div>
              <div v-if="schedModal.form.forceDualCamera" class="form-grid dual-grid">
                <div class="field"><label>副机位角度要求</label><input class="input" v-model="schedModal.form.dualAngle"/></div>
                <div class="field"><label>补充说明</label><input class="input" v-model="schedModal.form.dualNote" placeholder="如：手机横置，拍到全身与屏幕"/></div>
              </div>
            </div>
            <div class="field full"><label>通过自动邀约面试<span class="muted tiny">（总分达到阈值后自动为候选人创建面试邀约；不选则仅更新人才库状态，需人工安排）</span></label>
              <div class="form-grid dual-grid">
                <div class="field"><label>面试官</label>
                  <select class="select" v-model="schedModal.form.autoInterviewerId">
                    <option value="">不自动邀约</option>
                    <option v-for="it in interviewers" :key="it.userId" :value="String(it.userId)">{{ it.userName }}{{ it.jobTitle ? ' · ' + it.jobTitle : '' }}</option>
                  </select>
                </div>
                <div class="field"><label>建议时间延后（天）</label><input class="input" type="number" min="1" v-model.number="schedModal.form.autoInviteDays"/></div>
                <div class="field"><label>面试时长（分钟）</label><input class="input" type="number" min="10" v-model.number="schedModal.form.autoInviteDuration"/></div>
              </div>
            </div>
          </div>
        </div>
        <footer><button class="btn" @click="schedModal.open = false">取消</button><button class="btn primary" :disabled="schedModal.saving" @click="saveSchedule"><Save :size="15"/>保存安排</button></footer>
      </div>
    </div>

    <!-- ============ 笔试通知弹层 ============ -->
    <div v-if="notifyModal.open" class="mask" @click.self="notifyModal.open = false">
      <div class="modal wide">
        <header><h3>笔试通知 · 安排 #{{ notifyModal.row?.scheduleId }}（{{ notifyModal.row?.paperName }}）</h3><button class="icon-btn" @click="notifyModal.open = false"><X :size="15"/></button></header>
        <div class="body">
          <div class="form-grid">
            <div class="field full"><label>通知渠道</label>
              <div class="check-row">
                <label v-for="c in CHANNEL_META" :key="c.code" :class="{ 'ch-on': notifyModal.form.channels.includes(c.code) }">
                  <input type="checkbox" :checked="notifyModal.form.channels.includes(c.code)" @change="toggleChannel(c.code)"/>
                  <component :is="c.icon" :size="14"/>{{ c.label }}
                </label>
              </div>
            </div>
            <div class="field full"><label>标题模板<span class="muted tiny">（支持变量 {candidateName} {positionTitle} {paperName} {startAt} {endAt} {durationMin} {examUrl}，留空用默认）</span></label>
              <input class="input" v-model="notifyModal.form.title" placeholder="笔试通知 - {positionTitle}"/></div>
            <div class="field full"><label>正文模板</label>
              <textarea class="textarea" v-model="notifyModal.form.content" rows="4" placeholder="留空使用默认文案：候选人{candidateName}您好…请在截止前进入笔试作答：{examUrl}"/></div>
            <div class="field full"><label>候选人端笔试入口地址</label><input class="input" v-model="notifyModal.form.examUrl"/></div>
          </div>
          <div class="sub-block">
            <div class="sub-head"><b>通知对象（{{ notifyModal.targets.length }} 人，勾选可定向发送，不勾选则全部）</b></div>
            <table v-if="notifyModal.targets.length" class="tbl inner">
              <thead><tr><th style="width:36px"></th><th>候选人</th><th>邮箱</th><th>手机号</th><th>投递时间</th></tr></thead>
              <tbody>
                <tr v-for="t in notifyModal.targets" :key="t.talId">
                  <td><input type="checkbox" :value="t.talId" v-model="notifyModal.selected"/></td>
                  <td>{{ t.name }}</td>
                  <td><span v-if="t.email">{{ t.email }}</span><span v-else class="muted">—</span></td>
                  <td><span v-if="t.phone">{{ t.phone }}</span><span v-else class="muted">—</span></td>
                  <td class="muted">{{ t.appliedAt }}</td>
                </tr>
              </tbody>
            </table>
            <div v-else class="empty">该岗位暂无投递候选人</div>
          </div>
          <div v-if="notifyModal.result" class="sub-block">
            <div class="sub-head"><b>发送结果（{{ notifyModal.result.sent }}/{{ notifyModal.result.total }}）</b></div>
            <table class="tbl inner">
              <thead><tr><th>候选人</th><th>邮件</th><th>站内信</th></tr></thead>
              <tbody>
                <tr v-for="r in notifyModal.result.results" :key="r.talId">
                  <td>{{ r.name }}</td>
                  <td><span class="pill" :class="r.channels.email === 'sent' ? 'green' : 'gray'">{{ CHANNEL_RESULT[r.channels.email] || r.channels.email }}</span></td>
                  <td><span class="pill" :class="r.channels.inapp === 'sent' ? 'green' : 'gray'">{{ CHANNEL_RESULT[r.channels.inapp] || r.channels.inapp }}</span></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <footer>
          <button class="btn" @click="notifyModal.open = false">关闭</button>
          <button class="btn" :disabled="notifyModal.saving" @click="saveNotifyCfg"><Save :size="15"/>保存配置</button>
          <button class="btn primary" :disabled="notifyModal.sending || !notifyModal.targets.length" @click="doSendNotify"><Send :size="15"/>发送通知</button>
        </footer>
      </div>
    </div>

    <!-- ============ 成绩报告详情弹层 ============ -->
    <div v-if="reportModal.open" class="mask" @click.self="reportModal.open = false">
      <div class="modal wide">
        <header><h3>笔试报告 · {{ reportModal.data ? (reportModal.data.candidateName || ('记录 #' + reportModal.data.recordId)) : '' }}</h3><button class="icon-btn" @click="reportModal.open = false"><X :size="15"/></button></header>
        <div class="body">
          <div v-if="reportModal.loading" class="empty">报告加载中…</div>
          <template v-else-if="reportModal.data">
            <div class="report-meta">
              <div class="rm-item"><span class="muted tiny">试卷</span><b>{{ reportModal.data.paperName }}</b></div>
              <div class="rm-item"><span class="muted tiny">岗位</span><b>{{ reportModal.data.positionTitle }}</b></div>
              <div class="rm-item"><span class="muted tiny">交卷时间</span><b>{{ reportModal.data.submitAt || '—' }}</b></div>
              <div class="rm-item"><span class="muted tiny">客观题得分</span><b>{{ reportModal.data.objectiveScore == null ? '—' : reportModal.data.objectiveScore }}</b></div>
              <div class="rm-item"><span class="muted tiny">主观题得分</span><b>{{ reportModal.data.subjectiveScore == null ? '—' : reportModal.data.subjectiveScore }}</b></div>
              <div class="rm-item"><span class="muted tiny">总分 / 通过阈值</span><b>{{ reportModal.data.totalScore == null ? '—' : reportModal.data.totalScore }} / {{ reportModal.data.passThreshold }}</b></div>
              <div class="rm-item"><span class="muted tiny">试卷总分</span><b>{{ reportModal.data.paperTotalScore }}</b></div>
              <div class="rm-item"><span class="muted tiny">结果</span>
                <span v-if="PASS_META[reportModal.data.passStatus]" class="pill" :class="PASS_META[reportModal.data.passStatus][1]">{{ PASS_META[reportModal.data.passStatus][0] }}</span>
                <span v-else class="muted">未判分</span>
              </div>
            </div>
            <div class="sub-block">
              <div class="sub-head"><b>逐题作答与判分（{{ (reportModal.data.answers || []).length }} 题）</b></div>
              <div class="qa-list">
                <div v-for="(a, i) in reportModal.data.answers" :key="a.eanId" class="qa-item">
                  <div class="qa-head">
                    <span class="qa-no">第 {{ i + 1 }} 题</span>
                    <span class="pill sm" :class="a.type <= 3 ? '' : 'purple'">{{ typeLabel(a.type) }}</span>
                    <span class="qa-score">
                      <template v-if="Number(a.type) > 3 && Number(reportModal.data.passStatus) === 2">
                        <input class="input tiny-input" type="number" :min="0" :max="Number(a.maxScore)" v-model="reportModal.scores[a.questionId]"/>
                        <span class="muted tiny"> / {{ a.maxScore }} 分</span>
                      </template>
                      <template v-else>{{ a.score == null ? '—' : a.score }} / {{ a.maxScore }} 分</template>
                    </span>
                    <span v-if="a.type <= 3" class="pill sm" :class="a.isCorrect == null ? '' : (Number(a.isCorrect) === 1 ? 'green' : 'red')">
                      {{ a.isCorrect == null ? '未判' : (Number(a.isCorrect) === 1 ? '正确' : '错误') }}
                    </span>
                    <span v-else class="muted tiny">{{ Number(reportModal.data.passStatus) === 2 ? '待人工评分' : '已评分' }}</span>
                  </div>
                  <div class="qa-content">{{ a.content || '（题干缺失）' }}</div>
                  <div v-if="(a.options || []).length" class="qa-options">
                    <div v-for="(opt, j) in a.options" :key="j" class="qa-opt"
                         :class="{ picked: answerKeys(a).includes(optKey(j)), right: stdKeys(a).includes(optKey(j)) }">
                      <b>{{ optKey(j) }}</b>
                      <span>{{ optText(opt) }}</span>
                      <em v-if="answerKeys(a).includes(optKey(j))" class="tag-cand">候选人选择</em>
                      <em v-if="stdKeys(a).includes(optKey(j))" class="tag-right">正确答案</em>
                    </div>
                  </div>
                  <div class="qa-answer">
                    <label>候选人作答</label>
                    <pre :class="{ blank: answerText(a) === '（未作答）' }">{{ answerText(a) }}</pre>
                  </div>
                  <div v-if="Number(a.type) > 3" class="qa-answer">
                    <label>参考答案</label>
                    <pre>{{ a.stdAnswer || '—' }}</pre>
                  </div>
                  <div v-else class="qa-std-line">参考答案：{{ a.stdAnswer || '—' }}</div>
                </div>
              </div>
            </div>
            <div v-if="Number(reportModal.data.passStatus) === 2" class="sub-block">
              <div class="sub-head"><b>终判评语（可选）</b></div>
              <textarea class="textarea short" v-model="reportModal.comment" placeholder="保存后系统将按总分与阈值自动判定通过/未通过并执行流转"/>
            </div>
            <div v-else-if="reportModal.data.comment" class="sub-block">
              <div class="sub-head"><b>评语</b></div>
              <div class="comment-box">{{ reportModal.data.comment }}</div>
            </div>
          </template>
          <div v-else class="empty">未获取到报告数据</div>
        </div>
        <footer>
          <button class="btn" @click="reportModal.open = false">关闭</button>
          <button v-if="reportModal.data && Number(reportModal.data.passStatus) === 2" class="btn primary" :disabled="reportModal.saving" @click="saveSubjective"><Save :size="15"/>保存并终判</button>
        </footer>
      </div>
    </div>

    <ToastMessage :message="toast"/>
  </div>
</template>

<style scoped>
.exam-page{padding-bottom:30px}
.page-heading h1{font-size:22px}.page-heading p{font-size:12px;color:var(--muted);margin-top:5px}
.tabs{display:flex;gap:6px;background:#eef3fa;padding:5px;border-radius:11px}
.tab-btn{border:0;background:transparent;height:34px;padding:0 15px;border-radius:8px;font-size:13px;font-weight:600;color:#5a6c88;display:inline-flex;align-items:center;gap:6px;cursor:pointer}
.tab-btn.on{background:#fff;color:var(--primary);box-shadow:0 2px 8px rgba(24,52,98,.08)}
.tab-btn.proctor{margin-left:6px;color:var(--primary);background:#fff;border:1px solid #d5e2f5}
.tab-btn.proctor:hover{background:#f3f8ff}
.panel{padding:18px}
.toolbar{display:flex;gap:9px;align-items:center;margin-bottom:14px;flex-wrap:wrap}
.slim{width:auto;min-width:130px}.grow{flex:1;min-width:180px}
.tbl{width:100%;border-collapse:collapse;font-size:12.5px}
.tbl th{text-align:left;color:var(--subtle);font-weight:600;padding:8px 10px;border-bottom:1px solid var(--line);white-space:nowrap}
.tbl td{padding:9px 10px;border-bottom:1px solid #eef2f7;vertical-align:middle}
.tbl tr:hover td{background:#f7faff}
.tbl .wide{width:30%;min-width:200px}
.ellipsis{max-width:340px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.ops{white-space:nowrap}.ops .icon-btn{width:28px;height:28px;background:transparent;border:1px solid var(--line)}
.ops .icon-btn:hover{border-color:#b7caec}
.icon-btn.danger{color:var(--red)}
.icon-btn:disabled{opacity:.4;cursor:not-allowed}
.pager{display:flex;justify-content:flex-end;align-items:center;gap:9px;margin-top:13px}
.pill.sm{height:20px;font-size:11px;padding:0 7px}
.mask{position:fixed;inset:0;background:rgba(15,30,60,.42);display:grid;place-items:center;z-index:2000;padding:20px}
.modal{width:560px;max-width:96vw;max-height:88vh;display:flex;flex-direction:column;background:#fff;border-radius:16px;box-shadow:0 20px 60px rgba(15,30,60,.25)}
.modal.wide{width:780px}
.modal header{display:flex;justify-content:space-between;align-items:center;padding:16px 20px;border-bottom:1px solid var(--line)}
.modal header h3{font-size:16px}
.modal .body{padding:18px 20px;overflow-y:auto}
.modal footer{display:flex;justify-content:flex-end;gap:9px;padding:14px 20px;border-top:1px solid var(--line)}
.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:13px}
.field.full{grid-column:1/-1}
.field label{display:flex;align-items:center;gap:7px}
.textarea.short{min-height:64px}
.opt-row{display:flex;gap:8px;align-items:center;margin-bottom:8px}
.opt-key{width:24px;height:24px;border-radius:7px;background:#eaf1ff;color:var(--primary);display:grid;place-items:center;font-size:12px;font-weight:700;flex:none}
.sub-block{margin-top:16px}
.sub-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:9px;font-size:13px}
.inline-search{display:flex;gap:6px}
.pool{max-height:190px;overflow-y:auto;border:1px solid var(--line);border-radius:11px;padding:6px}
.pool-item{display:flex;gap:9px;align-items:center;padding:7px 9px;border-radius:8px;cursor:pointer;font-size:12px}
.pool-item:hover{background:#f5f8ff}
.pool-item.picked{background:#eaf1ff;outline:1px solid #bfd4ff}
.pool-text{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tbl.inner{border:1px solid var(--line);border-radius:11px;overflow:hidden}
.tiny-input{width:74px;height:30px;padding:0 8px;font-size:12px}
.rule-row{display:flex;gap:8px;align-items:center;margin-bottom:8px;flex-wrap:wrap}
.mini{font-size:11px;color:var(--subtle);white-space:nowrap}
.preview-row{display:flex;gap:11px;align-items:center;margin:10px 0}
.seg{display:inline-flex;border:1px solid var(--line);border-radius:9px;overflow:hidden}
.seg-btn{border:0;background:#fff;height:34px;padding:0 15px;font-size:12.5px;color:#5a6c88;cursor:pointer}
.seg-btn.on{background:var(--primary);color:#fff;font-weight:600}
.check-row{display:flex;gap:18px;align-items:center;flex-wrap:wrap;font-size:12.5px}
.check-row label{display:flex;gap:6px;align-items:center;cursor:pointer}
.inline-interval{gap:7px}
.dual-grid{margin-top:10px}
.ch-on{color:var(--primary);font-weight:600}
.report-meta{display:grid;grid-template-columns:repeat(4,1fr);gap:11px 14px;background:#f7faff;border:1px solid var(--line);border-radius:11px;padding:13px 15px}
.rm-item{display:flex;flex-direction:column;gap:3px;font-size:13px;min-width:0}
.rm-item b{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.qa-list{display:flex;flex-direction:column;gap:10px;max-height:44vh;overflow:auto}
.qa-item{border:1px solid var(--line);border-radius:11px;padding:12px 14px}
.qa-head{display:flex;align-items:center;gap:8px;margin-bottom:8px}
.qa-no{font-size:12.5px;font-weight:700;color:#26364d}
.qa-score{margin-left:auto;display:inline-flex;align-items:center;gap:4px;font-size:12px;color:#40516a}
.qa-content{font-size:12.5px;color:#26364d;line-height:1.6;white-space:pre-wrap;word-break:break-word}
.qa-options{display:flex;flex-direction:column;gap:6px;margin-top:9px}
.qa-opt{display:flex;align-items:flex-start;gap:9px;border:1px solid var(--line);border-radius:9px;padding:7px 10px;font-size:12px;color:#40516a;line-height:1.55}
.qa-opt b{flex:none;color:#8392a7}
.qa-opt>span{flex:1;min-width:0;word-break:break-word}
.qa-opt em{font-style:normal;flex:none;font-size:10px;padding:1px 7px;border-radius:9px;white-space:nowrap;margin-top:1px}
.qa-opt.picked{border-color:#8eb2fa;background:#f2f7ff}
.qa-opt.right{border-color:#16a34a;background:#f0fbf4}
.tag-cand{background:#dbeafe;color:#2563eb}
.tag-right{background:#dcfce7;color:#16a34a}
.qa-answer{display:flex;gap:10px;align-items:flex-start;margin-top:9px}
.qa-answer label{flex:none;width:64px;color:#8392a7;font-size:11.5px;padding-top:7px}
.qa-answer pre{flex:1;min-width:0;margin:0;background:#f7f9fc;border:1px solid #eef2f7;border-radius:9px;padding:8px 11px;font-size:12.5px;line-height:1.6;color:#26364d;font-family:inherit;white-space:pre-wrap;word-break:break-word;max-height:220px;overflow:auto}
.qa-answer pre.blank{color:#9aa7b8}
.qa-std-line{margin-top:8px;font-size:11.5px;color:#8392a7;word-break:break-word}
.comment-box{background:#f7faff;border:1px solid var(--line);border-radius:10px;padding:10px 12px;font-size:12.5px;white-space:pre-wrap;word-break:break-all}
</style>
