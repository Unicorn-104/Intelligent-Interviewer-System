<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { Sparkles, Search, FileText, UserRoundCheck, ShieldCheck, AlertTriangle, Lightbulb, Send, X, Check, ChevronRight, Target, Users, SlidersHorizontal, WandSparkles, RotateCcw } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listScreeningTasks, listScreeningResults, getScreeningShortlist, getScreeningReport, getScreeningGreeting, reviewScreeningResult, triggerScreening } from '@/api/screening'

const route = useRoute()
const toast = ref('')
const tasks = ref([])
const activeTaskId = ref(null)
const results = ref([])
const loadingResults = ref(false)
const viewMode = ref('all') // all=全部候选人 / shortlist=推荐短名单
const topN = ref(10)

// 触发初筛弹窗
const triggerOpen = ref(false)
const triggerPositionId = ref('')
const triggerTopN = ref(20)
const triggering = ref(false)
const triggerStep = ref(0)
const triggerSummary = ref(null)
let stepTimer = null

// 复核抽屉
const drawer = ref(null)
const drawerLoading = ref(false)
const report = ref(null)
const reportError = ref('')
const greeting = ref(null)
const adjustScore = ref('')
const reviewing = ref(false)

// 候选人状态映射（t_tal.tal_status）
const statusMap = { 0: { text: '新入库', tone: 'gray' }, 1: { text: '初筛通过', tone: 'green' }, 2: { text: '面试中', tone: 'blue' }, 3: { text: '已淘汰', tone: 'red' }, 4: { text: '已录用', tone: 'purple' }, 5: { text: '待笔试', tone: 'orange' }, 6: { text: '笔试中', tone: 'orange' }, 7: { text: '笔试通过', tone: 'green' }, 8: { text: '笔试未通过', tone: 'red' }, 9: { text: '笔试缺考', tone: 'gray' } }
// 维度权重（UC-05 步骤3）：技能 30% / 项目 30% / 教育 20% / 行业 20%
const dimensions = [
  { key: 'skillMatch', label: '技能标签重合度', weight: '30%' },
  { key: 'projectMatch', label: '项目经验相关性', weight: '30%' },
  { key: 'educationMatch', label: '教育背景匹配度', weight: '20%' },
  { key: 'industryMatch', label: '行业/领域经验', weight: '20%' }
]

const shortRows = ref([])
const activeTask = computed(() => tasks.value.find(t => String(t.taskId) === String(activeTaskId.value)))
const scored = computed(() => results.value.filter(r => r.totalScore != null))
const filteredOut = computed(() => results.value.filter(r => r.totalScore == null))
const displayList = computed(() => viewMode.value === 'all' ? results.value : shortRows.value)

function notify(v) { toast.value = v; setTimeout(() => toast.value = '', 2200) }
function fmtScore(v) { return v == null ? '—' : Number(v).toFixed(1) }
function skillList(row) { return (row.skills || '').split(',').map(s => s.trim()).filter(Boolean) }

async function loadTasks() {
  const res = await listScreeningTasks({ pageNum: 1, pageSize: 100 })
  tasks.value = res.rows || []
  const qid = route.query.taskId
  const prefer = qid && tasks.value.some(t => String(t.taskId) === String(qid)) ? qid : (activeTaskId.value && tasks.value.some(t => String(t.taskId) === String(activeTaskId.value)) ? activeTaskId.value : tasks.value[0]?.taskId)
  if (prefer != null) selectTask(prefer)
}

async function selectTask(taskId) {
  activeTaskId.value = taskId
  loadingResults.value = true
  results.value = []
  shortRows.value = []
  try {
    const res = await listScreeningResults(taskId)
    results.value = res.data || []
    if (viewMode.value === 'shortlist') await loadShortlist()
  } catch (e) {
    notify('筛选结果加载失败')
  } finally {
    loadingResults.value = false
  }
}

async function loadShortlist() {
  if (activeTaskId.value == null) return
  try {
    const res = await getScreeningShortlist(activeTaskId.value, topN.value)
    shortRows.value = res.data || []
  } catch (e) {
    notify('短名单加载失败')
  }
}

async function switchView(mode) {
  viewMode.value = mode
  if (mode === 'shortlist' && activeTaskId.value != null && !shortRows.value.length) await loadShortlist()
}

// ============ 批量初筛触发（同步接口，进度为前端动画步进） ============
function openTrigger() {
  triggerOpen.value = true
  triggerSummary.value = null
  triggerStep.value = 0
  if (!triggerPositionId.value && activeTaskId.value != null) triggerPositionId.value = String(activeTaskId.value)
}

async function runTrigger() {
  if (!triggerPositionId.value) return notify('请选择岗位')
  triggering.value = true
  triggerSummary.value = null
  triggerStep.value = 1
  stepTimer = setInterval(() => { if (triggerStep.value < 3) triggerStep.value++ }, 900)
  try {
    const res = await triggerScreening({ positionId: Number(triggerPositionId.value), topN: Number(triggerTopN.value) || 20 })
    triggerStep.value = 4
    triggerSummary.value = res.data
    topN.value = Number(res.data?.topN) || topN.value
    await loadTasks()
    selectTask(triggerSummary.value.taskId)
    notify(`初筛完成：${res.data.passedCount}/${res.data.candidateCount} 人通过硬性过滤`)
  } catch (e) {
    notify(e?.msg || e?.message || '初筛触发失败')
  } finally {
    clearInterval(stepTimer)
    triggering.value = false
  }
}

// ============ 可解释性报告归一化（grt_match_points JSON 结构容错） ============
function normalizeMatchPoints(raw) {
  const out = { matches: [], gaps: [], verify: [] }
  if (!raw) return out
  const push = (bucket, item) => {
    if (item == null) return
    if (typeof item === 'string') { if (item.trim()) bucket.push(item.trim()); return }
    const text = item.point || item.text || item.content || item.name || item.desc || item.description || JSON.stringify(item)
    const type = String(item.type || item.category || '').toLowerCase()
    if (/gap|risk|差距|风险|不足/.test(type)) out.gaps.push(text)
    else if (/verify|核实|待确认|question/.test(type)) out.verify.push(text)
    else out.matches.push(text)
  }
  if (Array.isArray(raw)) { raw.forEach(i => push(out.matches, i)); return out }
  if (typeof raw === 'object') {
    for (const [k, v] of Object.entries(raw)) {
      const list = Array.isArray(v) ? v : [v]
      const bucket = /gap|risk|差距|风险|不足/.test(k) ? out.gaps : /verify|核实|待确认/.test(k) ? out.verify : /match|匹配|亮点|优势/.test(k) ? out.matches : out.matches
      list.forEach(i => push(bucket, typeof i === 'string' ? i : i))
    }
  }
  return out
}

// ============ 复核抽屉 ============
async function openDrawer(row) {
  drawer.value = row
  report.value = null
  greeting.value = null
  reportError.value = ''
  adjustScore.value = ''
  drawerLoading.value = true
  try {
    const res = await getScreeningReport(row.resultId)
    report.value = res.data
  } catch (e) {
    reportError.value = e?.msg || '暂无 AI 推荐报告'
  }
  try {
    const g = await getScreeningGreeting(row.resultId)
    greeting.value = g.data
  } catch (e) { /* Top 3 之外无招呼语，属正常情况 */ }
  drawerLoading.value = false
}
function closeDrawer() { drawer.value = null }

async function submitReview(approved) {
  if (!drawer.value) return
  reviewing.value = true
  try {
    const body = { approved }
    if (approved && adjustScore.value !== '') body.adjustScore = Number(adjustScore.value)
    const res = await reviewScreeningResult(drawer.value.resultId, body)
    notify(res.data?.message || (approved ? '已确认通过' : '已驳回'))
    closeDrawer()
    if (activeTaskId.value != null) selectTask(activeTaskId.value)
  } catch (e) {
    notify(e?.msg || '复核提交失败')
  } finally {
    reviewing.value = false
  }
}

const points = computed(() => normalizeMatchPoints(report.value?.matchPoints))
const greetingStatus = { 0: '草稿', 1: '已发送', 2: '已回复' }

onMounted(loadTasks)
</script>

<template>
  <div class="page screening-page">
    <div class="page-heading">
      <div><h1>AI 初筛与智能匹配</h1><p>硬性条件过滤 · 多维度加权评分（技能 30% / 项目 30% / 教育 20% / 行业 20%）· 短名单 HR 复核</p></div>
      <div class="heading-actions"><button class="btn primary" @click="openTrigger"><WandSparkles :size="15"/>发起批量初筛</button></div>
    </div>

    <div class="screening-layout">
      <!-- 左：筛选任务（按岗位聚合） -->
      <aside class="card task-card">
        <div class="section-title"><span><span class="title-icon"><Target :size="16"/></span>初筛任务</span><em>{{ tasks.length }}</em></div>
        <div v-if="!tasks.length && !loadingResults" class="empty-tip">暂无初筛任务，请先为岗位投递候选人或发起批量初筛</div>
        <article v-for="t in tasks" :key="t.taskId" class="task-item" :class="{ on: String(activeTaskId) === String(t.taskId) }" @click="selectTask(t.taskId)">
          <div class="task-top"><b>{{ t.positionName }}</b><ChevronRight :size="14"/></div>
          <div class="task-meta"><span><Users :size="12"/>候选人 {{ t.candidateCount }}</span><span><ShieldCheck :size="12"/>初筛通过 {{ t.passedCount }}</span></div>
        </article>
      </aside>

      <!-- 右：评分结果与短名单 -->
      <section class="card result-card">
        <div class="result-head">
          <div class="section-title"><span>{{ activeTask ? activeTask.positionName : '匹配度评分明细' }} <em v-if="activeTask">任务 #{{ activeTask.taskId }}</em></span></div>
          <div class="view-tabs"><button :class="{ active: viewMode === 'all' }" @click="switchView('all')">全部候选人</button><button :class="{ active: viewMode === 'shortlist' }" @click="switchView('shortlist')">推荐短名单</button></div>
        </div>
        <div class="stat-row">
          <div class="stat"><label>候选人池</label><strong>{{ results.length }}</strong></div>
          <div class="stat ok"><label>评分通过</label><strong>{{ scored.length }}</strong></div>
          <div class="stat warn"><label>硬性过滤淘汰</label><strong>{{ filteredOut.length }}</strong></div>
          <div class="stat"><label>短名单 Top</label><strong>{{ viewMode === 'shortlist' ? shortRows.length : Math.min(topN, scored.length) }}</strong></div>
        </div>
        <div v-if="!activeTask" class="empty-tip big">请选择左侧岗位任务查看匹配结果</div>
        <template v-else>
          <div v-if="loadingResults" class="empty-tip big">评分结果加载中…</div>
          <div v-else-if="!results.length" class="empty-tip big">该岗位暂无候选人进入流程</div>
          <template v-else>
            <div class="table-head"><span>候选人</span><span>技能标签</span><span>匹配度</span><span>状态</span><span>操作</span></div>
            <article v-for="(row, i) in displayList" :key="row.resultId" class="result-row">
              <div class="person"><span class="rank" :class="{ top3: i < 3 && viewMode === 'shortlist' }">{{ i + 1 }}</span><MiniAvatar :name="row.name || '候选人'" :size="32" :color="['#635bff', '#1d8cf8', '#2667ff', '#f59e0b', '#0b9c6c'][i % 5]"/><div><b>{{ row.name || '未命名候选人' }}</b><small>{{ row.phone || '—' }}</small></div></div>
              <div class="skill-cell"><span v-for="s in skillList(row).slice(0, 4)" :key="s" class="skill">{{ s }}</span><span v-if="!skillList(row).length" class="skill none">无技能标签</span></div>
              <div class="score-cell"><strong>{{ fmtScore(row.totalScore) }}</strong><i><u :style="{ width: `${Math.min(Number(row.totalScore) || 0, 100)}%` }"/></i><small v-if="row.totalScore == null" class="filtered">未通过硬性过滤</small></div>
              <span class="pill" :class="(statusMap[row.status] || statusMap[0]).tone">{{ (statusMap[row.status] || statusMap[0]).text }}</span>
              <div class="ops"><button @click="openDrawer(row)"><FileText :size="13"/>报告复核</button></div>
            </article>
            <p v-if="viewMode === 'shortlist' && !shortRows.length && !loadingResults" class="empty-tip">暂无短名单，请先发起初筛或调大 Top N</p>
          </template>
        </template>
      </section>
    </div>

    <!-- 复核抽屉：维度明细 + 可解释性 + 招呼语 + 复核操作 -->
    <transition name="drawer">
      <div v-if="drawer" class="drawer-mask" @click="closeDrawer">
        <aside class="drawer" @click.stop>
          <header class="drawer-head">
            <MiniAvatar :name="drawer.name || '候选人'" :size="40" color="#2563eb"/>
            <div class="dh-info"><h3>{{ drawer.name || '未命名候选人' }}</h3><p>{{ drawer.phone || '—' }} · 综合评分 {{ fmtScore(drawer.totalScore) }}</p></div>
            <span class="pill" :class="(statusMap[drawer.status] || statusMap[0]).tone">{{ (statusMap[drawer.status] || statusMap[0]).text }}</span>
            <button class="drawer-close" @click="closeDrawer"><X :size="16"/></button>
          </header>
          <div class="drawer-body">
            <div class="block-title"><Search :size="14"/>维度评分明细</div>
            <div class="dim-grid"><div v-for="d in dimensions" :key="d.key" class="dim"><label>{{ d.label }} <small>{{ d.weight }}</small></label><b v-if="drawer[d.key] != null">{{ fmtScore(drawer[d.key]) }}</b><b v-else class="pending">{{ drawer.totalScore == null ? '已过滤' : '待接入' }}</b><i><u v-if="drawer[d.key] != null" :style="{ width: `${Math.min(Number(drawer[d.key]) || 0, 100)}%` }"/></i></div></div>
            <div class="block-title"><SlidersHorizontal :size="14"/>硬性条件</div>
            <div class="hard-box" :class="{ fail: drawer.totalScore == null }"><Check v-if="drawer.totalScore != null" :size="14"/><AlertTriangle v-else :size="14"/><span>{{ drawer.totalScore != null ? `技能标签与岗位必备项存在重合，综合评分 ${fmtScore(drawer.totalScore)}` : '无任何必备技能重合，已被硬性条件过滤' }}</span></div>
            <div class="block-title"><Lightbulb :size="14"/>可解释性推荐报告</div>
            <div v-if="drawerLoading" class="drawer-loading">报告加载中…</div>
            <div v-else-if="reportError" class="empty-tip">{{ reportError }}（需先触发深度分析）</div>
            <template v-else-if="report">
              <div class="point-group match"><b><Check :size="13"/>匹配点</b><ul><li v-for="(p, i) in points.matches" :key="`m${i}`">{{ p }}</li></ul><p v-if="!points.matches.length" class="no-item">暂无匹配点记录</p></div>
              <div class="point-group gap"><b><AlertTriangle :size="13"/>差距点</b><ul><li v-for="(p, i) in points.gaps" :key="`g${i}`">{{ p }}</li></ul><p v-if="!points.gaps.length" class="no-item">暂无差距点记录</p></div>
              <div class="point-group verify"><b><UserRoundCheck :size="13"/>需核实项</b><ul><li v-for="(p, i) in points.verify" :key="`v${i}`">{{ p }}</li></ul><p v-if="!points.verify.length" class="no-item">暂无需核实项记录</p></div>
            </template>
            <div class="block-title"><Send :size="14"/>个性化招呼语</div>
            <div v-if="greeting" class="greeting-box"><p>{{ greeting.content }}</p><small>{{ greetingStatus[greeting.status] || '草稿' }}<template v-if="greeting.sentAt"> · {{ greeting.sentAt }}</template></small></div>
            <div v-else class="empty-tip">暂无招呼语（仅短名单 Top 3 自动生成）</div>
          </div>
          <footer class="drawer-footer">
            <div class="adjust"><label>调整评分</label><input v-model="adjustScore" class="input" type="number" min="0" max="100" step="0.1" placeholder="可选"/></div>
            <button class="btn danger-ghost" :disabled="reviewing" @click="submitReview(false)"><X :size="14"/>驳回</button>
            <button class="btn primary" :disabled="reviewing" @click="submitReview(true)"><Check :size="14"/>确认通过</button>
          </footer>
        </aside>
      </div>
    </transition>

    <!-- 批量初筛触发弹窗 -->
    <BaseModal v-if="triggerOpen" title="发起批量初筛" width="460px" @close="triggerOpen = false">
      <div class="trigger-form">
        <label class="tf-row"><span>初筛岗位</span><select v-model="triggerPositionId" class="select"><option value="" disabled>请选择岗位</option><option v-for="t in tasks" :key="t.taskId" :value="String(t.taskId)">{{ t.positionName }}（候选人 {{ t.candidateCount }}）</option></select></label>
        <label class="tf-row"><span>短名单数量 Top N</span><input v-model="triggerTopN" class="input" type="number" min="1" max="100"/></label>
        <div v-if="triggering || triggerSummary" class="progress-box">
          <div class="steps">
            <div v-for="(s, i) in ['拉取候选人池', '硬性条件过滤', '多维度加权评分', '生成排序短名单']" :key="s" class="step" :class="{ done: triggerStep > i + 1 || (triggerStep === 4 && triggerSummary), doing: triggerStep === i + 1 && triggerStep < 4 }"><span><Check v-if="triggerStep > i" :size="12"/><RotateCcw v-else-if="triggerStep === i + 1" :size="12" class="spin"/><i v-else/></span>{{ s }}</div>
          </div>
          <div v-if="triggerSummary" class="summary"><b>{{ triggerSummary.candidateCount }}</b> 位候选人 · <b>{{ triggerSummary.passedCount }}</b> 位通过硬性过滤并评分 · 淘汰 <b>{{ triggerSummary.candidateCount - triggerSummary.passedCount }}</b> 位 · 短名单 Top {{ triggerSummary.topN }}</div>
        </div>
      </div>
      <template #footer>
        <button class="btn" @click="triggerOpen = false">{{ triggerSummary ? '关闭' : '取消' }}</button>
        <button class="btn primary" :disabled="triggering" @click="runTrigger"><Sparkles :size="14"/>{{ triggering ? '初筛执行中…' : '开始初筛' }}</button>
      </template>
    </BaseModal>

    <ToastMessage :message="toast"/>
  </div>
</template>

<style scoped>
.screening-page{padding-bottom:25px}
.heading-actions{display:flex;gap:9px}
.screening-layout{display:grid;grid-template-columns:290px minmax(680px,1fr);gap:15px}
.task-card{padding:16px;height:max-content;max-height:720px;overflow-y:auto}
.title-icon{width:29px;height:29px;border-radius:8px;background:#eaf1ff;color:#2563eb;display:inline-grid;place-items:center;margin-right:7px;vertical-align:middle}
.section-title em{font-style:normal;color:#2563eb;background:#edf4ff;border-radius:10px;font-size:10px;padding:3px 7px;margin-left:5px}
.task-item{margin-top:10px;padding:11px 12px;border:1px solid #e2e8f0;border-radius:10px;cursor:pointer;transition:border-color .15s,box-shadow .15s}
.task-item:hover{border-color:#bfdbfe}
.task-item.on{border-color:#2563eb;background:#f5f9ff;box-shadow:0 2px 8px rgba(37,99,235,.08)}
.task-top{display:flex;align-items:center;justify-content:space-between;font-size:12px}
.task-top b{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.task-top svg{color:#94a3b8;flex:none}
.task-item.on .task-top svg{color:#2563eb}
.task-meta{display:flex;gap:12px;margin-top:7px;color:#64748b;font-size:10px}
.task-meta span{display:flex;align-items:center;gap:4px}
.result-card{padding:17px;min-height:640px}
.result-head{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap}
.view-tabs{display:flex;background:#eef2f7;border-radius:8px;padding:3px}
.view-tabs button{height:27px;border:0;border-radius:6px;background:transparent;color:#64748b;font-size:11px;cursor:pointer;padding:0 13px}
.view-tabs button.active{background:#2563eb;color:white}
.stat-row{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:14px 0}
.stat{padding:12px 14px;border-radius:10px;background:#f6f8fb}
.stat label{display:block;font-size:10px;color:#7f8ea3}
.stat strong{display:block;font-size:22px;color:#2563eb;margin-top:4px}
.stat.ok strong{color:#0b9c6c}
.stat.warn strong{color:#ed8506}
.table-head,.result-row{display:grid;grid-template-columns:minmax(170px,1.3fr) minmax(150px,1.2fr) 110px 84px 92px;gap:10px;align-items:center}
.table-head{height:34px;padding:0 10px;background:#f6f8fb;color:#8593a7;font-size:10px;border-radius:7px;margin-top:6px}
.result-row{min-height:64px;padding:9px 10px;border-bottom:1px solid #e8edf4;font-size:11px}
.person{display:flex;align-items:center;gap:8px;min-width:0}
.rank{width:20px;height:20px;border-radius:6px;background:#eef2f7;color:#8a9ab0;display:grid;place-items:center;font-size:10px;flex:none}
.rank.top3{background:#2563eb;color:#fff}
.person b,.person small{display:block}
.person b{font-size:12px}
.person small{color:#7f8ea3;font-size:9px;margin-top:2px}
.skill-cell{display:flex;gap:4px;flex-wrap:wrap}
.skill{font-size:9px;padding:3px 6px;color:#2563eb;background:#edf4ff;border-radius:5px}
.skill.none{color:#94a3b8;background:#f1f5f9}
.score-cell strong{display:block;color:#2563eb;font-size:13px}
.score-cell i{display:block;width:66px;height:5px;background:#e0e7f1;border-radius:5px;margin-top:4px;overflow:hidden}
.score-cell u{display:block;height:100%;background:#3477f5;border-radius:inherit}
.score-cell .filtered{display:block;color:#ed8506;font-size:9px;margin-top:3px}
.ops button{border:0;background:transparent;color:#2563eb;font-size:10px;display:inline-flex;gap:3px;align-items:center;padding:3px 0;cursor:pointer}
.empty-tip{font-size:11px;color:#9aa8ba;padding:14px 0}
.empty-tip.big{text-align:center;padding:60px 0}

/* 抽屉 */
.drawer-mask{position:fixed;inset:0;background:rgba(15,23,42,.3);z-index:100;display:flex;justify-content:flex-end}
.drawer{width:420px;background:#fff;height:100%;display:flex;flex-direction:column;box-shadow:-8px 0 30px rgba(0,0,0,.1)}
.drawer-head{display:flex;align-items:center;gap:11px;padding:16px 18px;border-bottom:1px solid #e2e8f0}
.dh-info{flex:1;min-width:0}
.dh-info h3{font-size:15px;margin:0}
.dh-info p{font-size:10px;color:#64748b;margin:2px 0 0}
.drawer-close{border:0;background:#f1f5f9;width:28px;height:28px;border-radius:6px;cursor:pointer;display:grid;place-items:center;color:#64748b;flex:none}
.drawer-body{flex:1;overflow-y:auto;padding:14px 18px}
.block-title{display:flex;align-items:center;gap:6px;font-size:12px;color:#1e293b;font-weight:600;margin:14px 0 8px}
.block-title svg{color:#2563eb}
.dim-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px}
.dim{padding:10px;border:1px solid #e8edf4;border-radius:9px}
.dim label{display:block;font-size:9px;color:#7f8ea3}
.dim label small{color:#b0bccd;margin-left:3px}
.dim b{display:block;font-size:16px;color:#2563eb;margin-top:4px}
.dim b.pending{font-size:12px;color:#94a3b8;font-weight:400}
.dim i{display:block;height:4px;background:#eef2f7;border-radius:4px;margin-top:6px;overflow:hidden}
.dim u{display:block;height:100%;background:linear-gradient(90deg,#3b82f6,#2563eb);border-radius:2px}
.hard-box{display:flex;gap:7px;align-items:flex-start;padding:10px 12px;border-radius:9px;background:#e4f8ef;color:#0b9c6c;font-size:11px;line-height:1.5}
.hard-box.fail{background:#fff4df;color:#ed8506}
.hard-box svg{flex:none;margin-top:2px}
.drawer-loading{font-size:11px;color:#9aa8ba;padding:10px 0}
.point-group{padding:10px 12px;border-radius:9px;margin-bottom:8px;font-size:11px}
.point-group b{display:flex;align-items:center;gap:5px;font-size:11px}
.point-group ul{margin:6px 0 0;padding-left:0;list-style:none}
.point-group li{padding:4px 0;border-top:1px dashed rgba(15,23,42,.08);line-height:1.5}
.point-group .no-item{font-size:10px;color:#94a3b8;margin-top:5px}
.point-group.match{background:#e4f8ef;color:#0b7a55}
.point-group.gap{background:#fef2f2;color:#b3402f}
.point-group.verify{background:#fff4df;color:#a06410}
.greeting-box{padding:12px;border-radius:9px;background:#edf4ff;font-size:11px;color:#2c4a7c;line-height:1.6}
.greeting-box p{margin:0}
.greeting-box small{display:block;color:#7d93b5;margin-top:7px}
.drawer-footer{padding:13px 18px;border-top:1px solid #e2e8f0;display:flex;gap:8px;align-items:center}
.adjust{display:flex;align-items:center;gap:6px;margin-right:auto;font-size:11px;color:#64748b}
.adjust input{width:76px;height:32px}
.drawer-enter-active,.drawer-leave-active{transition:opacity .2s}
.drawer-enter-active .drawer,.drawer-leave-active .drawer{transition:transform .25s}
.drawer-enter-from,.drawer-leave-to{opacity:0}
.drawer-enter-from .drawer,.drawer-leave-to .drawer{transform:translateX(100%)}

/* 触发弹窗 */
.trigger-form{padding:4px 0}
.tf-row{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:12px 0;font-size:12px;color:#475569}
.tf-row .select,.tf-row .input{height:34px;border:1px solid #dce4ee;border-radius:7px;padding:0 8px;font-size:12px;color:#1e293b;background:#fff;min-width:220px}
.progress-box{margin-top:14px;padding:13px 14px;background:#f6f8fb;border-radius:10px}
.steps{display:flex;flex-direction:column;gap:9px}
.step{display:flex;align-items:center;gap:8px;font-size:11px;color:#94a3b8}
.step>span{width:18px;height:18px;border-radius:50%;background:#e2e8f0;color:#fff;display:grid;place-items:center;flex:none}
.step.doing{color:#2563eb}
.step.doing>span{background:#2563eb}
.step.done{color:#0b9c6c}
.step.done>span{background:#0b9c6c}
.step>span i{width:5px;height:5px;border-radius:50%;background:#cbd5e1;display:block}
.spin{animation:spin 1s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
.summary{margin-top:11px;padding-top:10px;border-top:1px dashed #d8e0ea;font-size:11px;color:#475569;line-height:1.6}
.summary b{color:#2563eb}
</style>
