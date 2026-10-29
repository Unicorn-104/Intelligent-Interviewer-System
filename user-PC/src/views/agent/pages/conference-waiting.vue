<template>
  <div class="cw-page">
    <header class="cw-topbar">
      <div class="cw-bar">
        <a class="cw-brand" :href="appHref('/index')"><span class="cw-mark">智</span>智聘 AI</a>
        <span class="cw-user">求职者</span>
      </div>
    </header>

    <main class="cw-main">
      <section class="cw-card">
        <div class="cw-pulse"><span class="cw-ring" /><span class="cw-core" /></div>
        <h1>已进入等候室</h1>
        <p class="cw-sub">请保持设备与网络正常，面试官点击「开始面试」后将自动进入会议。</p>

        <div class="cw-peer" :class="peerReady ? 'ok' : ''">
          <span class="cw-light" :class="peerReady ? 'ok' : ''" />
          <div>
            <strong>{{ peerName || '面试官' }}</strong>
            <small>{{ peerReady ? '已就绪' : '尚未进入等候室' }}</small>
          </div>
        </div>

        <p class="cw-hint">{{ started ? '面试已开始，正在进入会议…' : '等待面试官开始面试…' }}</p>
      </section>
    </main>
  </div>
</template>

<script setup>
import { appHref } from '@/utils/agentNavigation'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getWaitingRoom } from '@/api/system/conference'

const route = useRoute()
const router = useRouter()
const sessionId = ref('')
const peerReady = ref(false)
const peerName = ref('')
const sessionStatus = ref(null)
let timer = null
let stopped = false

const started = computed(() => Number(sessionStatus.value) === 1)

async function poll() {
  if (stopped) return
  try {
    const res = await getWaitingRoom(sessionId.value)
    const data = res?.data
    if (!data) return
    peerReady.value = data.peerReady === true
    peerName.value = data.peerName || ''
    sessionStatus.value = data.sessionStatus
    if (Number(data.sessionStatus) === 1) {
      stopPolling()
      router.replace('/conference-ai?sessionId=' + sessionId.value)
    }
  } catch (error) {
    // 单次轮询失败保留上一次状态，等待下次轮询
  }
}

function stopPolling() {
  stopped = true
  clearInterval(timer)
  timer = null
}

onMounted(() => {
  sessionId.value = route.query.sessionId || ''
  if (!sessionId.value) {
    router.replace('/index')
    return
  }
  poll()
  timer = setInterval(poll, 3000)
})

onBeforeUnmount(stopPolling)
</script>

<style scoped>
.cw-page {
  --p: #1A3C6E;
  --b: #2B7FFF;
  --bg: #F5F7FA;
  --text: #172B4D;
  --muted: #6B7A90;
  --line: #E6EBF2;
  --green: #52C41A;
  min-height: 100vh;
  background: var(--bg);
  color: var(--text);
  font: 14px/1.6 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
.cw-page * { box-sizing: border-box; }
.cw-page h1 { margin: 0; }

.cw-topbar { height: 72px; display: flex; align-items: center; background: #fff; border-bottom: 1px solid var(--line); }
.cw-bar { width: min(1120px, calc(100% - 48px)); margin: auto; display: flex; align-items: center; }
.cw-brand { display: flex; align-items: center; gap: 10px; color: var(--p); font-size: 18px; font-weight: 800; text-decoration: none; }
.cw-mark { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 9px; color: #fff; background: linear-gradient(145deg, #2B7FFF, #1A3C6E); }
.cw-user { margin-left: auto; color: var(--muted); font-size: 12px; }

.cw-main { display: grid; place-items: center; padding: 56px 24px; }
.cw-card { width: min(520px, 100%); padding: 36px 32px; border: 1px solid var(--line); border-radius: 14px; background: #fff; box-shadow: 0 12px 34px rgba(26, 60, 110, .08); text-align: center; }

.cw-pulse { position: relative; width: 88px; height: 88px; margin: 0 auto; display: grid; place-items: center; }
.cw-core { width: 58px; height: 58px; border-radius: 50%; background: linear-gradient(145deg, #2B7FFF, #1A3C6E); box-shadow: 0 8px 20px rgba(43, 127, 255, .3); }
.cw-ring { position: absolute; inset: 4px; border-radius: 50%; border: 2px solid rgba(43, 127, 255, .4); animation: cw-pulse 2s ease-out infinite; }
@keyframes cw-pulse { 0% { transform: scale(.8); opacity: .8; } 100% { transform: scale(1.25); opacity: 0; } }

.cw-card h1 { margin-top: 18px; font-size: 22px; color: var(--p); }
.cw-sub { margin-top: 8px; color: var(--muted); font-size: 13px; }

.cw-peer { display: grid; grid-template-columns: 12px 1fr; align-items: center; gap: 12px; margin-top: 24px; padding: 14px 16px; border: 1px solid var(--line); border-radius: 10px; text-align: left; }
.cw-peer.ok { border-color: #d3f0c5; background: #fcfffa; }
.cw-light { width: 12px; height: 12px; border-radius: 50%; background: #FAAD14; box-shadow: 0 0 0 4px rgba(250, 173, 20, .16); }
.cw-light.ok { background: var(--green); box-shadow: 0 0 0 4px rgba(82, 196, 26, .16); }
.cw-peer strong { display: block; font-size: 14px; }
.cw-peer small { display: block; margin-top: 2px; color: var(--muted); font-size: 12px; }

.cw-hint { margin-top: 20px; color: var(--b); font-size: 13px; font-weight: 600; }
</style>
