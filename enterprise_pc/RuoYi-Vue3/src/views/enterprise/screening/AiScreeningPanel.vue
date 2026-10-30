<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { Search, FileText, UserRoundCheck, ShieldCheck, AlertTriangle, Lightbulb, Send, X, Check, ChevronRight, Target, Users, SlidersHorizontal } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listScreeningTasks, listScreeningResults, getScreeningReport, getScreeningGreeting, reviewScreeningResult } from '@/api/screening'

const route = useRoute()
const toast = ref('')
const tasks = ref([])
const activeTaskId = ref(null)
const results = ref([])
const loadingResults = ref(false)
const group = ref('passed') // passed=通过初筛 / rejected=未通过初筛

// 复核抽屉
const drawer = ref(null)
const drawerLoading = ref(false)
const report = ref(null)
const reportError = ref('')
const greeting = ref(null)
const adjustScore = ref('')
const reviewing = ref(false)

const PASS_THRESHOLD = 60
// 候选人状态映射（t_tal.tal_status）
const statusMap = { 0: { text: '新入库', tone: 'gray' }, 1: { text: '初筛通过', tone: 'green' }, 2: { text: '面试中', tone: 'blue' }, 3: { text: '已淘汰', tone: 'red' }, 4: { text: '已录用', tone: 'purple' }, 5: { text: '待笔试', tone: 'orange' }, 6: { text: '笔试中', tone: 'orange' }, 7: { text: '笔试通过', tone: 'green' }, 8: { text: '笔试未通过', tone: 'red' }, 9: { text: '笔试缺考', tone: 'gray' } }
// 本岗位投递状态映射（t_app_record.app_status）：候选人可同时投递多个岗位，列表应展示本岗位状态
const appStatusMap = { 0: { text: '待筛选', tone: 'gray' }, 1: { text: '初筛通过', tone: 'green' }, 2: { text: '初筛淘汰', tone: 'red' }, 3: { text: '已约面', tone: 'blue' }, 4: { text: '待笔试', tone: 'orange' }, 5: { text: '笔试中', tone: 'orange' }, 6: { text: '笔试通过', tone: 'green' }, 7: { text: '笔试未通过', tone: 'red' }, 8: { text: '笔试缺考', tone: 'gray' }, 9: { text: '已撤回', tone: 'gray' } }
function rowStatus(row) { return appStatusMap[row.applicationStatus] || statusMap[row.status] || statusMap[0] }
// 与后端 ScreeningAiEvaluator.WEIGHTS 保持一致（合计 100%）
const dimensions = [
  { key: 'skillMatch', label: '技能标签重合度', weight: '25%' },
  { key: 'projectMatch', label: '项目经验相关性', weight: '25%' },
  { key: 'educationMatch', label: '教育背景匹配度', weight: '15%' },
  { key: 'industryMatch', label: '行业/领域经验', weight: '20%' },
  { key: 'researchMatch', label: '科研经历相关性', weight: '10%' },
  { key: 'awardMatch', label: '荣誉奖项相关性', weight: '5%' }
]

const activeTask = computed(() => tasks.value.find(t => String(t.taskId) === String(activeTaskId.value)))
const passedRows = computed(() => results.value.filter(r => isPassed(r)))
// AI 评估失败（无分数）的候选人尚未完成初筛，单独归入待人工评分，不进入未通过初筛
const unanalyzedRows = computed(() => results.value.filter(r => r.totalScore == null))
const rejectedRows = computed(() => results.value.filter(r => r.totalScore != null && !isPassed(r)))
const displayList = computed(() => (group.value === 'passed' ? passedRows.value : group.value === 'pending' ? unanalyzedRows.value : rejectedRows.value))

function isPassed(row) { return row.totalScore != null && Number(row.totalScore) >= (row.threshold || PASS_THRESHOLD) }
function notify(v) { toast.value = v; setTimeout(() => (toast.value = ''), 2200) }
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
  try {
    const res = await listScreeningResults(taskId)
    results.value = res.data || []
  } catch (e) {
    notify('筛选结果加载失败')
  } finally {
    loadingResults.value = false
  }
}

// 可解释性报告归一化（grt_match_points / matchPoints JSON 结构容错）
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
    const body = { approved, positionId: activeTaskId.value }
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

// AI 评估失败的候选人允许 HR 直接人工评分，按分数阈值判定该岗位投递初筛结果
async function submitManualScore() {
  if (!drawer.value) return
  if (adjustScore.value === '' || !Number.isFinite(Number(adjustScore.value))) {
    notify('请先填写人工评分')
    return
  }
  reviewing.value = true
  try {
    const res = await reviewScreeningResult(drawer.value.resultId, { positionId: activeTaskId.value, adjustScore: Number(adjustScore.value) })
    notify(res.data?.message || '已保存人工评分')
    closeDrawer()
    if (activeTaskId.value != null) selectTask(activeTaskId.value)
  } catch (e) {
    notify(e?.msg || '人工评分提交失败')
  } finally {
    reviewing.value = false
  }
}

const points = computed(() => normalizeMatchPoints(report.value?.matchPoints))
// 硬性条件不满足时，务必在差距点中明确缺失的必备技能
const gapPoints = computed(() => {
  const gaps = [...points.value.gaps]
  const missing = drawer.value?.missingSkills || []
  if (missing.length) gaps.unshift(`缺少岗位必备技能：${missing.join('、')}`)
  if (report.value?.dimensions && !gaps.length) {
    const empty = dimensions.filter(d => report.value[d.key] === 0 || report.value[d.key] == null)
    if (empty.length) gaps.push(`${empty.map(d => d.label).join('、')}未在简历中找到可支撑的证据`)
  }
  return gaps
})
const greetingStatus = { 0: '草稿', 1: '已发送', 2: '已回复' }

onMounted(loadTasks)
watch(() => route.query.taskId, (v) => { if (v) loadTasks() })
</script>

<template>
  <div class="ai-panel">
    <div class="screening-layout">
      <!-- 左：初筛任务（按岗位聚合） -->
      <aside class="card task-card">
        <div class="section-title"><span><span class="title-icon"><Target :size="16" /></span>初筛任务</span><em>{{ tasks.length }}</em></div>
        <div v-if="!tasks.length && !loadingResults" class="empty-tip">暂无初筛任务，请先到「投递详情」发起 AI 初筛</div>
        <article v-for="t in tasks" :key="t.taskId" class="task-item" :class="{ on: String(activeTaskId) === String(t.taskId) }" @click="selectTask(t.taskId)">
          <div class="task-top"><b>{{ t.positionName }}</b><ChevronRight :size="14" /></div>
          <div class="task-meta"><span><Users :size="12" />候选人 {{ t.candidateCount }}</span><span><ShieldCheck :size="12" />阈值 {{ PASS_THRESHOLD }} 分</span></div>
        </article>
      </aside>

      <!-- 右：通过/未通过初筛 -->
      <section class="card result-card">
        <div class="result-head">
          <div class="section-title"><span>{{ activeTask ? activeTask.positionName : 'AI 初筛详情' }}</span></div>
          <span class="threshold-tip">通过阈值：综合分 ≥ {{ PASS_THRESHOLD }} 分</span>
        </div>
        <div class="stat-row">
          <div class="stat"><label>候选人池</label><strong>{{ results.length }}</strong></div>
          <div class="stat ok"><label>通过初筛</label><strong>{{ passedRows.length }}</strong></div>
          <div class="stat warn"><label>未通过初筛</label><strong>{{ rejectedRows.length }}</strong></div>
          <div class="stat pending"><label>待人工评分</label><strong>{{ unanalyzedRows.length }}</strong></div>
        </div>
        <div class="view-tabs">
          <button :class="{ active: group === 'passed' }" @click="group = 'passed'">通过初筛（{{ passedRows.length }}）</button>
          <button :class="{ active: group === 'rejected' }" @click="group = 'rejected'">未通过初筛（{{ rejectedRows.length }}）</button>
          <button :class="{ active: group === 'pending' }" @click="group = 'pending'">待人工评分（{{ unanalyzedRows.length }}）</button>
        </div>
        <div v-if="!activeTask" class="empty-tip big">请选择左侧岗位任务查看初筛结果</div>
        <template v-else>
          <div v-if="loadingResults" class="empty-tip big">初筛结果加载中…</div>
          <div v-else-if="!displayList.length" class="empty-tip big">
            {{ group === 'passed' ? '暂无通过初筛的候选人，可到「投递详情」发起 AI 初筛' : '暂无未通过初筛的候选人' }}
          </div>
          <template v-else>
            <div class="table-head"><span>候选人</span><span>技能标签</span><span>综合分</span><span>状态</span><span>操作</span></div>
            <article v-for="(row, i) in displayList" :key="row.resultId" class="result-row">
              <div class="person">
                <span class="rank" :class="{ top3: group === 'passed' && i < 3 }">{{ i + 1 }}</span>
                <MiniAvatar :name="row.name || '候选人'" :size="32" :color="['#635bff', '#1d8cf8', '#2667ff', '#f59e0b', '#0b9c6c'][i % 5]" />
                <div><b>{{ row.name || '未命名候选人' }}</b><small>{{ row.phone || '—' }}</small></div>
              </div>
              <div class="skill-cell"><span v-for="s in skillList(row).slice(0, 4)" :key="s" class="skill">{{ s }}</span><span v-if="!skillList(row).length" class="skill none">无技能标签</span></div>
              <div class="score-cell">
                <strong>{{ fmtScore(row.totalScore) }}</strong>
                <i><u :style="{ width: `${Math.min(Number(row.totalScore) || 0, 100)}%` }" /></i>
                <small v-if="row.totalScore == null" class="filtered">未完成评估</small>
                <small v-else-if="row.adjustedTotalScore != null" class="adjusted">HR 已调整</small>
              </div>
              <span class="pill" :class="rowStatus(row).tone">{{ rowStatus(row).text }}</span>
              <div class="ops"><button @click="openDrawer(row)"><FileText :size="13" />{{ row.totalScore == null ? '人工评分' : '报告复核' }}</button></div>
            </article>
          </template>
        </template>
      </section>
    </div>

    <!-- 复核抽屉：维度明细 + 硬性条件 + 可解释性 + 招呼语 + 复核操作 -->
    <transition name="drawer">
      <div v-if="drawer" class="drawer-mask" @click="closeDrawer">
        <aside class="drawer" @click.stop>
          <header class="drawer-head">
            <MiniAvatar :name="drawer.name || '候选人'" :size="40" color="#2563eb" />
            <div class="dh-info"><h3>{{ drawer.name || '未命名候选人' }}</h3><p>{{ drawer.phone || '—' }} · 综合评分 {{ fmtScore(drawer.totalScore) }}</p></div>
            <span v-if="drawer.totalScore == null" class="pill gray">待人工评分</span>
            <span v-else class="pill" :class="isPassed(drawer) ? 'green' : 'orange'">{{ isPassed(drawer) ? '通过初筛' : '未通过初筛' }}</span>
            <button class="drawer-close" @click="closeDrawer"><X :size="16" /></button>
          </header>
          <div class="drawer-body">
            <div class="block-title"><Search :size="14" />维度评分明细（合计权重 100%）</div>
            <div v-if="drawer.totalScore == null" class="manual-tip">AI 评估未完成（评估失败），暂无维度明细；请直接填写人工评分，达到 {{ PASS_THRESHOLD }} 分即视为通过初筛。</div>
            <div v-else-if="report?.manual" class="manual-tip">当前分数由 HR 人工评分录入，无 AI 维度明细。</div>
            <div v-if="drawer.totalScore != null && !report?.manual" class="dim-grid">
              <div v-for="d in dimensions" :key="d.key" class="dim">
                <label>{{ d.label }} <small>{{ d.weight }}</small></label>
                <b>{{ fmtScore(drawer[d.key]) }}</b>
                <i><u :style="{ width: `${Math.min(Number(drawer[d.key]) || 0, 100)}%` }" /></i>
                <small v-if="drawer[d.key] === 0" class="dim-note">简历未提供相关证据，按 0 分计</small>
              </div>
            </div>
            <div class="block-title"><SlidersHorizontal :size="14" />硬性条件</div>
            <div class="hard-box" :class="{ fail: !drawer.hardFilterPassed || (drawer.missingSkills || []).length }">
              <Check v-if="drawer.hardFilterPassed && !(drawer.missingSkills || []).length" :size="14" /><AlertTriangle v-else :size="14" />
              <span v-if="drawer.hardFilterPassed === false">岗位必备技能无一条重合，已被硬性条件过滤；缺少：{{ (drawer.missingSkills || []).join('、') }}</span>
              <span v-else-if="drawer.totalScore == null">AI 评估未完成，暂无硬性条件结论，可人工评分后判定</span>
              <span v-else-if="(drawer.missingSkills || []).length">岗位必备技能部分匹配，缺少：{{ (drawer.missingSkills || []).join('、') }}</span>
              <span v-else>岗位必备技能已全部满足，按综合评分排序</span>
            </div>
            <div class="block-title"><Lightbulb :size="14" />可解释性推荐报告</div>
            <div v-if="drawerLoading" class="drawer-loading">报告加载中…</div>
            <div v-else-if="reportError" class="empty-tip">{{ reportError }}</div>
            <template v-else-if="report">
              <div class="point-group match"><b><Check :size="13" />匹配点</b><ul><li v-for="(p, i) in points.matches" :key="`m${i}`">{{ p }}</li></ul><p v-if="!points.matches.length" class="no-item">暂无匹配点记录</p></div>
              <div class="point-group gap"><b><AlertTriangle :size="13" />差距点</b><ul><li v-for="(p, i) in gapPoints" :key="`g${i}`">{{ p }}</li></ul><p v-if="!gapPoints.length" class="no-item">暂无差距点记录</p></div>
              <div class="point-group verify"><b><UserRoundCheck :size="13" />需核实项</b><ul><li v-for="(p, i) in points.verify" :key="`v${i}`">{{ p }}</li></ul><p v-if="!points.verify.length" class="no-item">暂无需核实项记录</p></div>
            </template>
            <div class="block-title"><Send :size="14" />个性化招呼语</div>
            <div v-if="greeting" class="greeting-box"><p>{{ greeting.content }}</p><small>{{ greetingStatus[greeting.status] || '草稿' }}<template v-if="greeting.sentAt"> · {{ greeting.sentAt }}</template></small></div>
            <div v-else class="empty-tip">暂无招呼语（仅短名单 Top 3 自动生成）</div>
          </div>
          <footer class="drawer-footer">
            <div class="adjust">
              <label>{{ drawer.totalScore == null ? '人工评分' : '调整综合分' }}</label>
              <input v-model="adjustScore" class="input" type="number" min="0" max="100" step="0.1" :placeholder="drawer.totalScore == null ? '必填' : '可选'" />
              <small>调整到 ≥{{ PASS_THRESHOLD }} 即视为通过初筛</small>
            </div>
            <template v-if="drawer.totalScore == null">
              <button class="btn primary" :disabled="reviewing" @click="submitManualScore"><Check :size="14" />保存人工评分</button>
            </template>
            <template v-else>
              <button class="btn danger-ghost" :disabled="reviewing" @click="submitReview(false)"><X :size="14" />驳回</button>
              <button class="btn primary" :disabled="reviewing" @click="submitReview(true)"><Check :size="14" />确认通过</button>
            </template>
          </footer>
        </aside>
      </div>
    </transition>

    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.screening-layout{display:grid;grid-template-columns:290px minmax(680px,1fr);gap:15px}
.task-card{padding:16px;height:max-content;max-height:calc(100vh - 250px);overflow-y:auto}
.title-icon{width:29px;height:29px;border-radius:8px;background:#eaf1ff;color:#2563eb;display:inline-grid;place-items:center;margin-right:7px;vertical-align:middle}
.section-title{display:flex;align-items:center;font-size:13px;color:#1e293b;font-weight:600}
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
.result-card{padding:17px;min-height:calc(100vh - 250px)}
.result-head{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap}
.threshold-tip{font-size:10px;color:#52657f;background:#f1f5fb;border-radius:999px;padding:4px 10px}
.view-tabs{display:flex;background:#eef2f7;border-radius:8px;padding:3px;margin-top:12px;width:max-content}
.view-tabs button{height:29px;border:0;border-radius:6px;background:transparent;color:#64748b;font-size:11px;cursor:pointer;padding:0 15px}
.view-tabs button.active{background:#2563eb;color:white}
.stat-row{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:14px 0}
.stat{padding:12px 14px;border-radius:10px;background:#f6f8fb}
.stat label{display:block;font-size:10px;color:#7f8ea3}
.stat strong{display:block;font-size:22px;color:#2563eb;margin-top:4px}
.stat.ok strong{color:#0b9c6c}
.stat.warn strong{color:#ed8506}
.stat.pending strong{color:#718096}
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
.score-cell small{display:block;font-size:9px;margin-top:3px}
.score-cell .filtered{color:#ed8506}
.score-cell .adjusted{color:#0b9c6c}
.ops button{border:0;background:transparent;color:#2563eb;font-size:10px;display:inline-flex;gap:3px;align-items:center;padding:3px 0;cursor:pointer}
.empty-tip{font-size:11px;color:#9aa8ba;padding:14px 0}
.empty-tip.big{text-align:center;padding:60px 0}

/* 抽屉 */
.drawer-mask{position:fixed;inset:0;background:rgba(15,23,42,.3);z-index:100;display:flex;justify-content:flex-end}
.drawer{width:460px;background:#fff;height:100%;display:flex;flex-direction:column;box-shadow:-8px 0 30px rgba(0,0,0,.1)}
.drawer-head{display:flex;align-items:center;gap:11px;padding:16px 18px;border-bottom:1px solid #e2e8f0}
.dh-info{flex:1;min-width:0}
.dh-info h3{font-size:15px;margin:0}
.dh-info p{font-size:10px;color:#64748b;margin:2px 0 0}
.drawer-close{border:0;background:#f1f5f9;width:28px;height:28px;border-radius:6px;cursor:pointer;display:grid;place-items:center;color:#64748b;flex:none}
.drawer-body{flex:1;overflow-y:auto;padding:14px 18px}
.block-title{display:flex;align-items:center;gap:6px;font-size:12px;color:#1e293b;font-weight:600;margin:14px 0 8px}
.block-title svg{color:#2563eb}
.manual-tip{padding:9px 11px;border-radius:8px;background:#fff4df;color:#a06410;font-size:10px;line-height:1.6;margin-bottom:8px}
.dim-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px}
.dim{padding:10px;border:1px solid #e8edf4;border-radius:9px}
.dim label{display:block;font-size:9px;color:#7f8ea3}
.dim label small{color:#b0bccd;margin-left:3px}
.dim b{display:block;font-size:16px;color:#2563eb;margin-top:4px}
.dim i{display:block;height:4px;background:#eef2f7;border-radius:4px;margin-top:6px;overflow:hidden}
.dim u{display:block;height:100%;background:linear-gradient(90deg,#3b82f6,#2563eb);border-radius:2px}
.dim-note{display:block;margin-top:5px;font-size:9px;color:#94a3b8;line-height:1.4}
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
.drawer-footer{padding:13px 18px;border-top:1px solid #e2e8f0;display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.adjust{display:flex;align-items:center;gap:6px;margin-right:auto;font-size:11px;color:#64748b}
.adjust input{width:76px;height:32px}
.adjust small{font-size:9px;color:#94a3b8}
.drawer-enter-active,.drawer-leave-active{transition:opacity .2s}
.drawer-enter-active .drawer,.drawer-leave-active .drawer{transition:transform .25s}
.drawer-enter-from,.drawer-leave-to{opacity:0}
.drawer-enter-from .drawer,.drawer-leave-to .drawer{transform:translateX(100%)}
</style>
