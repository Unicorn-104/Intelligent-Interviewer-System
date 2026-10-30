<template>
  <div class="room">
    <!-- 答题界面 -->
    <template v-if="stage === 'doing'">
      <header class="topbar">
        <div class="top-title">
          <strong>{{ paper.paperName }}</strong>
          <span>{{ paper.positionTitle }}</span>
        </div>
        <div class="top-clock" :class="{ danger: remainingSec <= 300 }">
          <span class="clock-dot"></span>{{ clockText }}
        </div>
        <div class="top-right">
          <span class="save-state" :class="saveState">{{ saveStateText }}</span>
          <button class="submit-btn" type="button" @click="confirmOpen = true">交 卷</button>
        </div>
      </header>

      <main class="body">
        <section class="paper">
          <div class="q-head">
            <span class="q-no">第 {{ current + 1 }} / {{ questions.length }} 题</span>
            <span class="q-type">{{ typeName(curQuestion.type) }}</span>
            <span class="q-score">{{ curQuestion.score }} 分</span>
          </div>
          <div class="q-content">{{ curQuestion.content }}</div>

          <!-- 单选/判断 -->
          <div v-if="curQuestion.type === 1 || curQuestion.type === 3" class="options">
            <label v-for="(opt, i) in curOptions" :key="i" class="option" :class="{ picked: answers[curQuestion.questionId] === optValue(curQuestion, i) }">
              <input type="radio" :name="'q' + curQuestion.questionId"
                     :value="optValue(curQuestion, i)" v-model="answers[curQuestion.questionId]" @change="markDirty" />
              <span class="opt-key">{{ optKey(i) }}</span><span class="opt-text">{{ opt }}</span>
            </label>
          </div>

          <!-- 多选 -->
          <div v-else-if="curQuestion.type === 2" class="options">
            <label v-for="(opt, i) in curOptions" :key="i" class="option" :class="{ picked: multiPicked(i) }">
              <input type="checkbox" :checked="multiPicked(i)" @change="toggleMulti(i)" />
              <span class="opt-key">{{ optKey(i) }}</span><span class="opt-text">{{ opt }}</span>
            </label>
          </div>

          <!-- 简答/编程 -->
          <div v-else class="written">
            <textarea v-model="answers[curQuestion.questionId]" rows="10"
                      :class="{ mono: curQuestion.type === 5 }"
                      placeholder="请输入你的作答内容..." @input="markDirty"></textarea>
          </div>

          <div class="pager">
            <button type="button" class="page-btn" :disabled="current === 0" @click="current--">上一题</button>
            <button type="button" class="page-btn" :disabled="current === questions.length - 1" @click="current++">下一题</button>
          </div>
        </section>

        <aside class="side">
          <div class="side-title">答题卡</div>
          <div class="grid">
            <button v-for="(q, i) in questions" :key="q.questionId" type="button"
                    class="grid-btn" :class="{ answered: isAnswered(q), active: i === current }"
                    @click="current = i">{{ i + 1 }}</button>
          </div>
          <div class="side-legend">
            <span><i class="dot picked"></i>已作答</span><span><i class="dot"></i>未作答</span>
          </div>
          <div class="side-stat">已答 {{ answeredCount }} / {{ questions.length }} 题</div>

          <div class="monitor">
            <div class="side-title">双机位监考<span v-if="forceDual" class="mon-force">必开</span></div>
            <div class="mon-row">
              <span class="mon-label"><i class="dot-state" :class="mainStateClass"></i>主机位（电脑摄像头）</span>
            </div>
            <video v-show="mainStatus === 'live'" ref="mainVideo" class="mon-video" autoplay muted playsinline></video>
            <div v-if="mainStatus === 'connecting'" class="mon-note">主机位连接中...</div>
            <div v-else-if="mainStatus === 'error'" class="mon-note err">{{ mainError || '主机位连接失败，不影响作答' }}</div>
            <div v-else-if="mainStatus === 'idle'" class="mon-note">主机位未开启</div>
            <div class="mon-row">
              <span class="mon-label"><i class="dot-state" :class="subStateClass"></i>副机位（手机扫码）</span>
              <span class="mon-sub-state">{{ subStateText }}</span>
            </div>
            <div v-if="subUrl" class="mon-qr"><canvas ref="subQr"></canvas><div class="mon-qr-tip">手机扫码加入副机位</div></div>
            <div v-else class="mon-note">二维码生成中...</div>
            <button v-if="mainStatus !== 'live'" class="mon-btn" type="button" @click="startMainCamera">开启主机位摄像头</button>
          </div>
        </aside>
      </main>

      <!-- 交卷确认 -->
      <div v-if="confirmOpen" class="mask" @click.self="confirmOpen = false">
        <div class="dialog">
          <h3>确认交卷？</h3>
          <p v-if="unanswered">还有 <strong>{{ unanswered }}</strong> 题未作答，交卷后无法继续修改。</p>
          <p v-else>全部题目已作答，确认交卷后无法修改。</p>
          <p v-if="!allowEarly" class="warn">本场考试不允许提前交卷，时间用尽后将自动交卷。</p>
          <div class="dialog-actions">
            <button type="button" class="ghost" @click="confirmOpen = false">继续作答</button>
            <button type="button" class="solid" :disabled="!allowEarly || submitting" @click="doSubmit(false)">确认交卷</button>
          </div>
        </div>
      </div>
    </template>

    <!-- 加载 / 已交卷 / 出错 -->
    <div v-else class="center">
      <div v-if="stage === 'loading'" class="center-card">正在进入考试...</div>
      <div v-else-if="stage === 'done'" class="center-card">
        <div class="done-icon">✓</div>
        <h2>{{ autoSubmitted ? '时间用尽，已自动交卷' : '交卷成功' }}</h2>
        <p>你的答卷已提交，成绩与报告将在企业评阅后生成。</p>
        <a :href="appHref('/exam')">返回笔试列表</a>
      </div>
      <div v-else class="center-card error">
        <h2>无法进入考试</h2>
        <p>{{ loadError }}</p>
        <a :href="appHref('/exam')">返回笔试列表</a>
      </div>
    </div>
  </div>
</template>

<script setup>
import { appHref } from '@/utils/agentNavigation'
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { useRoute } from 'vue-router'
import { Room, Track } from 'livekit-client'
import QRCode from 'qrcode'
import { getExamEntry, getExamMonitor, saveExamAnswers, startExam, submitExam } from '@/api/agent/exam'

const route = useRoute()
const scheduleId = String(route.query.scheduleId || '')

const stage = ref('loading') // loading | doing | done | error
const loadError = ref('')
const paper = ref({})
const questions = ref([])
const current = ref(0)
const answers = reactive({})
const recordId = ref(null)
const remainingSec = ref(0)
const saveState = ref('idle') // idle | saving | saved | offline
const dirty = ref(false)
const confirmOpen = ref(false)
const submitting = ref(false)
const autoSubmitted = ref(false)
const allowEarly = ref(true)

// 双机位监考
const mainVideo = ref(null)
const subQr = ref(null)
const mainStatus = ref('idle') // idle | connecting | live | error
const mainError = ref('')
const subInfo = ref({ subStatus: 0, subOnline: false })
const forceDual = ref(false)
const subUrl = ref('')
let lkRoom = null
let subPollTimer = null

let tickTimer = null
let autosaveTimer = null
const onlineHandler = () => { if (dirty.value) flushSave() }

const mainStateClass = computed(() => ({
  idle: 'gray', connecting: 'orange', live: 'green', error: 'red'
}[mainStatus.value]))
const subStateClass = computed(() => subInfo.value.subOnline ? 'green' : 'gray')
const subStateText = computed(() => {
  if (subInfo.value.subOnline) return '副机位在线'
  if (subInfo.value.subStatus === 2) return '副机位已断开'
  return '副机位未加入'
})

const curQuestion = computed(() => questions.value[current.value] || {})
const curOptions = computed(() => {
  const q = curQuestion.value
  if (q.options && q.options.length) return q.options
  return q.type === 3 ? ['对', '错'] : []
})
const clockText = computed(() => {
  const s = Math.max(0, remainingSec.value)
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = s % 60
  const mm = String(m).padStart(2, '0')
  const ss = String(sec).padStart(2, '0')
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`
})
const answeredCount = computed(() => questions.value.filter(isAnswered).length)
const unanswered = computed(() => questions.value.length - answeredCount.value)
const saveStateText = computed(() => ({
  idle: '', saving: '保存中...', saved: '已保存', offline: '网络断开，恢复后自动续传'
}[saveState.value]))

function typeName(t) {
  return { 1: '单选题', 2: '多选题', 3: '判断题', 4: '简答题', 5: '编程题' }[t] || '题目'
}
function optKey(i) {
  return String.fromCharCode(65 + i)
}
function optValue(q, i) {
  // 判断题无选项时以 对/错 作为作答值，其余按选项字母
  if (q.type === 3 && !(q.options && q.options.length)) return i === 0 ? '对' : '错'
  return optKey(i)
}
function isAnswered(q) {
  const v = answers[q.questionId]
  return v !== undefined && v !== null && String(v).trim() !== ''
}
function multiPicked(i) {
  const v = answers[curQuestion.value.questionId] || ''
  return v.includes(optKey(i))
}
function toggleMulti(i) {
  const qid = curQuestion.value.questionId
  const set = new Set((answers[qid] || '').split(''))
  const key = optKey(i)
  if (set.has(key)) set.delete(key)
  else set.add(key)
  answers[qid] = Array.from(set).sort().join('')
  markDirty()
}
function markDirty() {
  dirty.value = true
}

function answersArray() {
  return Object.keys(answers).map(qid => ({ questionId: Number(qid), content: answers[qid] == null ? '' : String(answers[qid]) }))
}

async function flushSave() {
  if (!recordId.value) return
  saveState.value = 'saving'
  try {
    const res = await saveExamAnswers(recordId.value, answersArray())
    const d = res.data || {}
    if (d.timeout || d.submitted) {
      autoSubmitted.value = true
      stage.value = 'done'
      stopTimers()
      teardownMonitor()
      return
    }
    remainingSec.value = d.remainingSec ?? remainingSec.value
    dirty.value = false
    saveState.value = 'saved'
  } catch (e) {
    saveState.value = 'offline'
  }
}

async function doSubmit(auto) {
  if (submitting.value) return
  submitting.value = true
  try {
    const res = await submitExam(recordId.value, answersArray())
    const d = res.data || {}
    autoSubmitted.value = !!(d.auto || auto)
    stage.value = 'done'
    stopTimers()
    teardownMonitor()
  } catch (e) {
    loadError.value = e?.message || '交卷失败，请检查网络后重试'
    if (auto) { stage.value = 'error'; stopTimers() }
  } finally {
    submitting.value = false
    confirmOpen.value = false
  }
}

function stopTimers() {
  if (tickTimer) clearInterval(tickTimer)
  if (autosaveTimer) clearInterval(autosaveTimer)
  if (subPollTimer) clearInterval(subPollTimer)
  tickTimer = null
  autosaveTimer = null
  subPollTimer = null
}

let monitorInfo = null
async function loadMonitor() {
  if (!recordId.value) return
  try {
    const res = await getExamMonitor(recordId.value)
    monitorInfo = res.data || {}
    forceDual.value = Number(monitorInfo.forceDualCamera) === 1
    subInfo.value = monitorInfo.sub || { subStatus: 0, subOnline: false }
    subUrl.value = monitorInfo.subUrl ? new URL(appHref(monitorInfo.subUrl), window.location.origin).href : ''
    await nextTick()
    if (subQr.value && subUrl.value) {
      await QRCode.toCanvas(subQr.value, subUrl.value, { width: 150, margin: 1 })
    }
  } catch (e) { /* 监考信息获取失败不阻断作答 */ }
  if (!subPollTimer) {
    subPollTimer = setInterval(async () => {
      try {
        const res = await getExamMonitor(recordId.value)
        subInfo.value = (res.data || {}).sub || subInfo.value
      } catch (e) { /* 忽略轮询错误 */ }
    }, 10000)
  }
}

async function startMainCamera() {
  if (!monitorInfo || mainStatus.value === 'connecting' || mainStatus.value === 'live') return
  mainStatus.value = 'connecting'
  mainError.value = ''
  try {
    if (!lkRoom) lkRoom = new Room()
    await lkRoom.connect(monitorInfo.url, monitorInfo.token)
    await lkRoom.localParticipant.setCameraEnabled(true)
    const track = lkRoom.localParticipant.getTrackPublication(Track.Source.Camera)?.track
    if (track && mainVideo.value) track.attach(mainVideo.value)
    mainStatus.value = 'live'
  } catch (e) {
    mainStatus.value = 'error'
    mainError.value = e?.message || '摄像头连接失败'
  }
}

function teardownMonitor() {
  if (lkRoom) {
    try { lkRoom.localParticipant.setCameraEnabled(false) } catch (e) { /* ignore */ }
    try { lkRoom.disconnect() } catch (e) { /* ignore */ }
    lkRoom = null
  }
}

async function init() {
  if (!scheduleId) {
    loadError.value = '缺少考试安排参数'
    stage.value = 'error'
    return
  }
  try {
    const res = await startExam(scheduleId)
    const d = res.data || {}
    if (d.submitted) {
      autoSubmitted.value = !!d.auto
      stage.value = 'done'
      return
    }
    recordId.value = d.recordId
    paper.value = d
    questions.value = d.questions || []
    questions.value.forEach(q => { answers[q.questionId] = q.answer || '' })
    remainingSec.value = d.remainingSec || 0
    stage.value = 'doing'

    // 交卷规则：自动保存间隔 / 是否允许提前交卷（兼容新旧键名）
    let rule = {}
    try {
      const entryRes = await getExamEntry(scheduleId)
      rule = (entryRes.data && entryRes.data.submitRule) || {}
    } catch (e) { /* 规则获取失败用默认值 */ }
    const interval = Number(rule.autosaveInterval ?? rule.saveIntervalSec ?? 30)
    allowEarly.value = rule.allowEarly !== false && rule.allowEarlySubmit !== false

    tickTimer = setInterval(() => {
      remainingSec.value--
      if (remainingSec.value <= 0) {
        stopTimers()
        doSubmit(true)
      }
    }, 1000)
    autosaveTimer = setInterval(() => { if (dirty.value) flushSave() }, Math.max(5, interval) * 1000)
    window.addEventListener('online', onlineHandler)
    await loadMonitor()
    // 设备检测阶段已授权摄像头，进入答题后自动恢复主机位，避免监控中断
    startMainCamera()
  } catch (e) {
    loadError.value = e?.message || '进入考试失败'
    stage.value = 'error'
  }
}

onMounted(init)
onBeforeUnmount(() => {
  stopTimers()
  teardownMonitor()
  window.removeEventListener('online', onlineHandler)
  if (stage.value === 'doing' && dirty.value) flushSave()
})
</script>

<style scoped>
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}
.room{min-height:100vh;display:flex;flex-direction:column}
.topbar{height:56px;display:flex;align-items:center;justify-content:space-between;gap:16px;padding:0 22px;border-bottom:1px solid #E6EBF2;background:#fff;position:sticky;top:0;z-index:5}
.top-title{display:flex;flex-direction:column;min-width:0}
.top-title strong{color:#1A3C6E;font-size:14px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
.top-title span{color:#96A3B5;font-size:10px}
.top-clock{display:flex;align-items:center;gap:7px;padding:6px 14px;border-radius:8px;color:#1A3C6E;background:#EDF3FC;font-size:16px;font-weight:800;font-variant-numeric:tabular-nums}
.top-clock.danger{color:#D94B55;background:#FCEDEF}
.clock-dot{width:8px;height:8px;border-radius:50%;background:currentColor}
.top-right{display:flex;align-items:center;gap:14px}
.save-state{color:#20A36F;font-size:11px}
.save-state.offline{color:#D94B55}
.save-state.saving{color:#D88725}
.submit-btn{height:34px;padding:0 18px;border:0;border-radius:7px;color:#fff;background:#2B7FFF;font-size:12px;font-weight:700;cursor:pointer}
.body{flex:1;width:min(1240px,100% - 44px);margin:0 auto;padding:20px 0 40px;display:grid;grid-template-columns:minmax(0,1fr) 260px;gap:18px;align-items:start}
.paper{padding:24px 26px;border:1px solid #E6EBF2;border-radius:12px;background:#fff}
.q-head{display:flex;align-items:center;gap:10px}
.q-no{color:#1A3C6E;font-size:14px;font-weight:800}
.q-type{padding:3px 9px;border-radius:5px;color:#2B7FFF;background:#EAF2FF;font-size:11px}
.q-score{margin-left:auto;color:#D88725;font-size:12px;font-weight:700}
.q-content{margin:16px 0 18px;color:#17233F;font-size:15px;line-height:1.7;white-space:pre-wrap}
.options{display:flex;flex-direction:column;gap:10px}
.option{display:flex;align-items:center;gap:12px;padding:12px 14px;border:1px solid #E2E9F3;border-radius:9px;cursor:pointer;font-size:13px;transition:border-color .15s, background .15s}
.option:hover{border-color:#B9CFEF}
.option.picked{border-color:#2B7FFF;background:#F3F8FF}
.option input{accent-color:#2B7FFF}
.opt-key{width:24px;height:24px;display:grid;place-items:center;border-radius:50%;color:#647894;background:#EEF2F7;font-size:11px;font-weight:800}
.option.picked .opt-key{color:#fff;background:#2B7FFF}
.opt-text{flex:1}
.written textarea{width:100%;padding:12px 14px;border:1px solid #E2E9F3;border-radius:9px;color:#17233F;background:#FBFCFE;font-size:13px;line-height:1.7;resize:vertical}
.written textarea:focus{border-color:#2B7FFF;outline:none}
.written textarea.mono{font-family:Consolas,Menlo,monospace}
.pager{display:flex;justify-content:space-between;margin-top:20px}
.page-btn{height:36px;padding:0 20px;border:1px solid #C8D9F0;border-radius:8px;color:#2B7FFF;background:#fff;font-size:12px;font-weight:700;cursor:pointer}
.page-btn:disabled{color:#A9B5C5;border-color:#E6EBF2;cursor:not-allowed}
.side{position:sticky;top:76px;padding:18px;border:1px solid #E6EBF2;border-radius:12px;background:#fff}
.side-title{color:#1A3C6E;font-size:13px;font-weight:800}
.grid{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:8px;margin-top:12px}
.grid-btn{height:32px;border:1px solid #E2E9F3;border-radius:7px;color:#647894;background:#F8FAFD;font-size:11px;font-weight:700;cursor:pointer}
.grid-btn.answered{border-color:#B7E3CE;color:#20A36F;background:#E9F7F1}
.grid-btn.active{border-color:#2B7FFF;color:#fff;background:#2B7FFF}
.side-legend{display:flex;gap:14px;margin-top:12px;color:#96A3B5;font-size:10px}
.dot{display:inline-block;width:9px;height:9px;margin-right:4px;border-radius:3px;background:#EEF2F7;border:1px solid #E2E9F3}
.dot.picked{background:#E9F7F1;border-color:#B7E3CE}
.side-stat{margin-top:10px;color:#647894;font-size:11px}
.monitor{margin-top:16px;padding-top:14px;border-top:1px solid #EEF2F7}
.monitor .side-title{display:flex;align-items:center;gap:6px}
.mon-force{padding:1px 6px;border-radius:4px;color:#D94B55;background:#FCEDEF;font-size:9px;font-weight:700}
.mon-row{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:10px}
.mon-label{display:flex;align-items:center;gap:6px;color:#53647B;font-size:11px}
.dot-state{width:8px;height:8px;border-radius:50%;background:#C3CEDD}
.dot-state.green{background:#20A36F}
.dot-state.orange{background:#D88725}
.dot-state.red{background:#D94B55}
.dot-state.gray{background:#C3CEDD}
.mon-sub-state{color:#96A3B5;font-size:10px}
.mon-video{width:100%;margin-top:8px;border-radius:8px;background:#0F1722;aspect-ratio:16/9;object-fit:cover}
.mon-note{margin-top:8px;color:#96A3B5;font-size:10px}
.mon-note.err{color:#D94B55}
.mon-qr{display:flex;flex-direction:column;align-items:center;gap:6px;margin-top:10px;padding:10px;border:1px solid #E6EBF2;border-radius:10px;background:#FBFCFE}
.mon-qr canvas{width:150px;height:150px}
.mon-qr-tip{color:#96A3B5;font-size:10px}
.mon-btn{width:100%;height:32px;margin-top:10px;border:1px solid #C8D9F0;border-radius:7px;color:#2B7FFF;background:#fff;font-size:11px;font-weight:700;cursor:pointer}
.mask{position:fixed;inset:0;display:grid;place-items:center;background:rgba(23,35,63,.45);z-index:20}
.dialog{width:min(420px,calc(100% - 40px));padding:24px;border-radius:14px;background:#fff}
.dialog h3{margin:0 0 12px;color:#1A3C6E;font-size:17px}
.dialog p{margin:6px 0;color:#53647B;font-size:13px}
.dialog p strong{color:#D88725}
.warn{color:#D94B55 !important}
.dialog-actions{display:flex;justify-content:flex-end;gap:12px;margin-top:20px}
.ghost{height:36px;padding:0 18px;border:1px solid #D8E1ED;border-radius:8px;color:#647894;background:#fff;font-size:12px;cursor:pointer}
.solid{height:36px;padding:0 18px;border:0;border-radius:8px;color:#fff;background:#2B7FFF;font-size:12px;font-weight:700;cursor:pointer}
.solid:disabled{background:#C3CEDD;cursor:not-allowed}
.center{flex:1;display:grid;place-items:center;padding:60px 20px}
.center-card{max-width:460px;padding:40px 36px;border:1px solid #E6EBF2;border-radius:14px;background:#fff;text-align:center}
.center-card h2{margin:0 0 10px;color:#1A3C6E;font-size:19px}
.center-card p{margin:0 0 18px;color:#647894;font-size:13px}
.center-card a{display:inline-block;padding:9px 20px;border:1px solid #C8D9F0;border-radius:8px;color:#2B7FFF;font-size:12px;font-weight:700;text-decoration:none}
.done-icon{width:56px;height:56px;margin:0 auto 14px;display:grid;place-items:center;border-radius:50%;color:#20A36F;background:#E9F7F1;font-size:26px;font-weight:800}
.center-card.error h2{color:#D94B55}
@media(max-width:960px){.body{grid-template-columns:1fr}.side{position:static}}
</style>
