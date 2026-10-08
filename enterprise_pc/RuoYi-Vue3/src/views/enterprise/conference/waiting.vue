<template>
  <div class="cw-page">
    <header class="cw-topbar">
      <div class="cw-bar">
        <a class="cw-brand" href="/enterprise/dashboard"><span class="cw-mark">智</span>智聘 AI</a>
        <span class="cw-user">面试官 · {{ interview.interviewerName }}</span>
        <button class="cw-quit" @click="quit">退出</button>
      </div>
    </header>

    <main class="cw-main">
      <section class="cw-head">
        <h1>等候室</h1>
        <p>候选人就绪后即可点击「开始面试」，双方将同时进入会议</p>
      </section>

      <section class="cw-info">
        <div class="cw-info-item"><span>应聘岗位</span><b>{{ interview.positionTitle }}</b></div>
        <div class="cw-info-item"><span>候选人</span><b>{{ interview.candidateName }}</b></div>
        <div class="cw-info-item"><span>面试时间</span><b>{{ interview.time }}</b></div>
        <div class="cw-info-item"><span>面试时长</span><b>{{ interview.duration }}</b></div>
      </section>

      <div class="cw-grid">
        <section class="cw-card">
          <div class="cw-card-head">
            <h2>我（面试官）</h2>
            <span class="cw-ready" :class="{ on: selfReady }"><i />{{ selfReady ? '已就绪' : '等待进入' }}</span>
          </div>
          <ul class="cw-checks">
            <li v-for="item in selfChecks" :key="item.key">
              <span>{{ item.label }}</span>
              <b :class="statusClass(item.value)">{{ statusText(item.value) }}</b>
            </li>
          </ul>
        </section>

        <section class="cw-card">
          <div class="cw-card-head">
            <h2>候选人 · {{ peerName }}</h2>
            <span class="cw-ready" :class="{ on: peerReady }"><i />{{ peerReady ? '已就绪' : '等待中' }}</span>
          </div>
          <ul class="cw-checks">
            <li v-for="item in peerChecks" :key="item.key">
              <span>{{ item.label }}</span>
              <b :class="statusClass(item.value)">{{ statusText(item.value) }}</b>
            </li>
          </ul>
          <p v-if="!peerReady" class="cw-wait">正在等待候选人完成设备检测并进入等候室…</p>
        </section>
      </div>
    </main>

    <footer class="cw-footer">
      <div class="cw-hint">
        <strong>{{ peerReady ? '候选人已就绪' : '等待候选人就绪' }}</strong>
        <span>{{ peerReady ? '候选人已进入等候室，可以开始本次面试。' : '候选人进入等候室后「开始面试」按钮将自动可用。' }}</span>
      </div>
      <button class="cw-start" :disabled="!peerReady || starting" @click="start">
        {{ starting ? '正在开始…' : '开始面试' }}
      </button>
    </footer>

    <div class="cw-toast" :class="{ show: toast }">{{ toast }}</div>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getSessionContext, getWaitingRoom, startSession } from '@/api/system/conference'

const route = useRoute()
const router = useRouter()

const sessionId = ref(null)
const room = ref(null)
const starting = ref(false)
const toast = ref('')
const interview = ref({
  positionTitle: '高级前端工程师',
  candidateName: '候选人',
  interviewerName: '面试官',
  time: '待安排',
  duration: '45 分钟'
})
let pollId = null
let toastTimer = null

const selfReady = computed(() => !!room.value?.selfReady)
const peerReady = computed(() => !!room.value?.peerReady)
const peerName = computed(() => room.value?.peerName || interview.value.candidateName)

// 0-未检测，1-正常，2-较差，3-异常
function statusText(value) {
  return { 0: '未检测', 1: '正常', 2: '较差', 3: '异常' }[Number(value)] || '未检测'
}
function statusClass(value) {
  const n = Number(value)
  if (n === 1) return 'ok'
  if (n === 2) return 'warn'
  if (n === 3) return 'bad'
  return ''
}

const selfChecks = computed(() => buildChecks(room.value?.self))
const peerChecks = computed(() => buildChecks(room.value?.peer))

function buildChecks(state) {
  const s = state || {}
  return [
    { key: 'cam', label: '摄像头', value: s.camStatus },
    { key: 'mic', label: '麦克风', value: s.micStatus },
    { key: 'speaker', label: '扬声器', value: s.speakerStatus },
    { key: 'net', label: '网络连接', value: s.netStatus }
  ]
}

function notify(message) {
  toast.value = message
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => (toast.value = ''), 2400)
}

function stopPolling() {
  clearInterval(pollId)
  pollId = null
}

function goOngoing() {
  stopPolling()
  router.replace('/enterprise/conference/ongoing?sessionId=' + sessionId.value)
}

async function poll() {
  try {
    const res = await getWaitingRoom(sessionId.value)
    room.value = res.data
    // 场次已开始（HR 在其它窗口点过开始，或候选人触发）：直接进入会议页
    if (res.data && Number(res.data.sessionStatus) === 1) {
      goOngoing()
    }
  } catch (error) {
    // 轮询失败静默，等待下一次
  }
}

async function start() {
  if (!peerReady.value || starting.value) return
  starting.value = true
  try {
    await startSession(sessionId.value)
    goOngoing()
  } catch (error) {
    starting.value = false
    notify(error?.message || '开始面试失败')
  }
}

function quit() {
  stopPolling()
  router.replace('/enterprise/messages')
}

function formatAppointment(startAt, endAt) {
  if (!startAt) return ''
  const [date, startTime] = startAt.split(' ')
  const parts = (date || '').split('-')
  if (parts.length < 3) return startAt
  const endTime = endAt ? endAt.split(' ')[1] : ''
  return `${parts[1]}月${parts[2]}日 ${startTime}${endTime ? ` - ${endTime}` : ''}`
}

onMounted(async () => {
  sessionId.value = route.query.sessionId || null
  if (!sessionId.value) {
    router.replace('/enterprise/messages')
    return
  }
  try {
    const res = await getSessionContext(sessionId.value)
    if (res.data) {
      const d = res.data
      if (d.positionTitle) interview.value.positionTitle = d.positionTitle
      if (d.candidateName) interview.value.candidateName = d.candidateName
      if (d.interviewerName) interview.value.interviewerName = d.interviewerName
      const time = formatAppointment(d.appointmentStartAt, d.appointmentEndAt)
      if (time) interview.value.time = time
      if (d.durationMinutes) interview.value.duration = `${d.durationMinutes} 分钟`
    }
  } catch (error) {
    // 无后端时保留本地演示
  }
  await poll()
  pollId = setInterval(poll, 3000)
})

onBeforeUnmount(() => {
  stopPolling()
  clearTimeout(toastTimer)
})
</script>

<style scoped>
.cw-page {
  --p: #1A3C6E;
  --b: #2B7FFF;
  --text: #172B4D;
  --muted: #6B7A90;
  --line: #E6EBF2;
  --soft: #EAF2FF;
  --green: #52C41A;
  --warn: #FAAD14;
  --red: #FF4D4F;
  min-height: 100vh;
  padding-bottom: 92px;
  background: #F5F7FA;
  color: var(--text);
  font: 14px/1.6 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
.cw-page * { box-sizing: border-box; }
.cw-page button { font: inherit; cursor: pointer; }
.cw-page h1, .cw-page h2, .cw-page p { margin: 0; }

.cw-topbar { height: 72px; display: flex; align-items: center; background: #fff; border-bottom: 1px solid var(--line); }
.cw-bar, .cw-main, .cw-footer { width: min(1120px, calc(100% - 48px)); margin: auto; }
.cw-bar { display: flex; align-items: center; }
.cw-brand { display: flex; align-items: center; gap: 10px; color: var(--p); font-size: 18px; font-weight: 800; text-decoration: none; }
.cw-mark { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 9px; color: #fff; background: linear-gradient(145deg, #2B7FFF, #1A3C6E); }
.cw-user { margin-left: auto; color: var(--muted); font-size: 12px; }
.cw-quit { margin-left: 16px; height: 32px; padding: 0 14px; border: 1px solid var(--line); border-radius: 8px; background: #fff; color: var(--muted); }
.cw-quit:hover { color: var(--red); border-color: #ffccc7; }

.cw-main { padding: 26px 0 40px; }
.cw-head h1 { font-size: 24px; color: var(--p); }
.cw-head p { margin-top: 6px; color: var(--muted); font-size: 13px; }

.cw-info { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin-top: 16px; padding: 18px 20px; border: 1px solid var(--line); border-radius: 12px; background: #fff; }
.cw-info-item { display: flex; flex-direction: column; gap: 5px; }
.cw-info-item span { color: var(--muted); font-size: 12px; }
.cw-info-item b { font-size: 13px; font-weight: 600; }

.cw-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; margin-top: 16px; }
.cw-card { padding: 22px; border: 1px solid var(--line); border-radius: 12px; background: #fff; box-shadow: 0 6px 20px rgba(26, 60, 110, .05); }
.cw-card-head { display: flex; align-items: center; justify-content: space-between; }
.cw-card-head h2 { font-size: 16px; color: var(--p); }
.cw-ready { display: inline-flex; align-items: center; gap: 6px; padding: 4px 11px; border-radius: 999px; background: #f1f4f9; color: var(--muted); font-size: 12px; }
.cw-ready i { width: 8px; height: 8px; border-radius: 50%; background: var(--warn); }
.cw-ready.on { background: #EDFAE5; color: #3f9e1f; }
.cw-ready.on i { background: var(--green); }

.cw-checks { list-style: none; margin: 14px 0 0; padding: 0; display: grid; gap: 10px; }
.cw-checks li { display: flex; align-items: center; justify-content: space-between; padding: 11px 13px; border: 1px solid var(--line); border-radius: 10px; }
.cw-checks span { color: var(--muted); font-size: 13px; }
.cw-checks b { font-size: 13px; font-weight: 700; color: var(--muted); }
.cw-checks b.ok { color: #3f9e1f; }
.cw-checks b.warn { color: #c98a00; }
.cw-checks b.bad { color: var(--red); }
.cw-wait { margin-top: 14px; padding: 11px 13px; border-radius: 9px; background: #F6F9FD; color: #52647D; font-size: 12px; }

.cw-footer {
  position: fixed; left: 0; right: 0; bottom: 0;
  height: 76px; display: flex; align-items: center; justify-content: space-between; gap: 16px;
  background: #fff; border-top: 1px solid var(--line);
  padding-left: max(24px, calc((100% - 1120px) / 2));
  padding-right: max(24px, calc((100% - 1120px) / 2));
  box-shadow: 0 -6px 22px rgba(26, 60, 110, .06);
}
.cw-hint strong { display: block; font-size: 13px; color: var(--p); }
.cw-hint span { color: var(--muted); font-size: 12px; }
.cw-start { height: 44px; padding: 0 30px; border: 0; border-radius: 10px; color: #fff; font-size: 15px; font-weight: 700; background: linear-gradient(135deg, #2B7FFF, #1A3C6E); box-shadow: 0 8px 20px rgba(43, 127, 255, .28); }
.cw-start:disabled { background: #C9D3DF; box-shadow: none; cursor: not-allowed; }

.cw-toast { position: fixed; left: 50%; bottom: 96px; transform: translate(-50%, 8px); z-index: 80; padding: 11px 16px; border-radius: 9px; background: #122A4E; color: #fff; font-size: 13px; opacity: 0; pointer-events: none; transition: .2s; }
.cw-toast.show { opacity: 1; transform: translate(-50%, 0); }

@media (max-width: 960px) {
  .cw-info { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .cw-grid { grid-template-columns: 1fr; }
  .cw-footer { height: auto; flex-direction: column; align-items: stretch; padding: 14px 20px; gap: 12px; }
  .cw-start { width: 100%; }
  .cw-page { padding-bottom: 160px; }
}
</style>