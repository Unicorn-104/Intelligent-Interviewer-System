<template>
  <div class="sub">
    <header class="sub-head">
      <strong>笔试副机位</strong>
      <span v-if="info.candidateName">{{ info.candidateName }} · {{ info.paperName }}</span>
    </header>

    <main class="sub-body">
      <div v-if="state === 'connecting'" class="sub-card">副机位连接中，请允许摄像头权限...</div>
      <div v-else-if="state === 'error'" class="sub-card err">
        <h2>无法加入副机位</h2>
        <p>{{ error }}</p>
        <button type="button" @click="retry">重试</button>
      </div>
      <template v-else-if="state === 'live'">
        <video ref="video" class="sub-video" autoplay muted playsinline></video>
        <div class="sub-status"><i class="dot"></i>副机位已连接，请保持手机置于侧后方拍摄全景</div>
      </template>
    </main>

    <footer class="sub-foot">© 2026 企业级智能招聘面试官 Agent 系统</footer>
  </div>
</template>

<script setup>
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { Room, Track } from 'livekit-client'
import { subJoin, subLeave, subPing } from '@/api/agent/exam'

const route = useRoute()
const recordId = Number(route.query.recordId || 0)
const code = String(route.query.code || '')

const state = ref('connecting')
const error = ref('')
const info = ref({})
const video = ref(null)
let room = null
let pingTimer = null

async function join() {
  state.value = 'connecting'
  error.value = ''
  try {
    if (!recordId || !code) throw new Error('副机位链接不完整')
    const res = await subJoin({ recordId, code })
    const d = res.data || {}
    info.value = d
    room = new Room()
    await room.connect(d.url, d.token)
    await room.localParticipant.setCameraEnabled(true, {
      camera: { facingMode: { ideal: 'environment' } }
    })
    const track = room.localParticipant.getTrackPublication(Track.Source.Camera)?.track
    // 先切到 live 让 video 节点渲染出来，再挂载画面，否则画面框为空
    state.value = 'live'
    await nextTick()
    if (track && video.value) track.attach(video.value)
    pingTimer = setInterval(() => {
      subPing({ recordId, code }).catch(() => { /* 心跳失败下次重试 */ })
    }, 15000)
  } catch (e) {
    state.value = 'error'
    error.value = e?.message || '加入失败，请检查网络与摄像头权限'
  }
}

function leave() {
  if (room) {
    try { room.localParticipant.setCameraEnabled(false) } catch (e) { /* ignore */ }
    try { room.disconnect() } catch (e) { /* ignore */ }
    room = null
  }
  if (pingTimer) clearInterval(pingTimer)
  pingTimer = null
  if (recordId && code) {
    // 页面关闭时尽力上报断开（keepalive 保证请求发出）
    fetch('/dev-api/candidate/exam/sub/leave', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ recordId, code }),
      keepalive: true
    }).catch(() => { /* ignore */ })
  }
}

function retry() { join() }

const hideHandler = () => leave()
onMounted(() => {
  join()
  window.addEventListener('pagehide', hideHandler)
})
onBeforeUnmount(() => {
  window.removeEventListener('pagehide', hideHandler)
  if (state.value === 'live' && pingTimer) {
    subLeave({ recordId, code }).catch(() => { /* ignore */ })
  }
  leave()
})
</script>

<style scoped>
:global(body){margin:0;background:#0F1722;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}
.sub{min-height:100vh;display:flex;flex-direction:column;color:#E6EDF6}
.sub-head{padding:14px 16px;display:flex;flex-direction:column;gap:3px;border-bottom:1px solid #223047}
.sub-head strong{font-size:14px}
.sub-head span{color:#8FA1B8;font-size:11px}
.sub-body{flex:1;display:grid;place-items:center;padding:16px}
.sub-video{width:min(92vw,520px);aspect-ratio:1/1;border-radius:14px;background:#000;object-fit:cover}
.sub-card{max-width:340px;padding:28px 22px;border:1px solid #223047;border-radius:14px;text-align:center;color:#8FA1B8;font-size:13px}
.sub-card.err h2{margin:0 0 8px;color:#FF6B74;font-size:16px}
.sub-card.err p{margin:0 0 16px}
.sub-card.err button{height:34px;padding:0 20px;border:0;border-radius:8px;color:#fff;background:#2B7FFF;font-size:12px;font-weight:700;cursor:pointer}
.sub-status{display:flex;align-items:center;gap:8px;margin-top:14px;color:#3DD68C;font-size:12px}
.dot{width:8px;height:8px;border-radius:50%;background:#3DD68C;animation:blink 1.6s infinite}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.3}}
.sub-foot{padding:12px;text-align:center;color:#4C5B70;font-size:10px}
</style>
