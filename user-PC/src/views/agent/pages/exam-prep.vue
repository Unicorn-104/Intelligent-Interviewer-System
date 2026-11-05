<template>
  <div class="prep">
    <header class="prep-head">
      <div>
        <h1>笔试设备检测</h1>
        <p v-if="entry">{{ entry.paperName }} · {{ entry.positionTitle }}<span v-if="forceDual"> · 本场考试要求双机位监考</span></p>
      </div>
      <span class="status-pill" :class="allPassed ? 'green' : 'orange'">{{ allPassed ? '检测通过' : '检测中' }}</span>
    </header>

    <main class="prep-body">
      <div v-if="loading" class="center-card">正在加载考试信息...</div>
      <div v-else-if="loadError" class="center-card err">
        <h2>无法进入设备检测</h2>
        <p>{{ loadError }}</p>
        <a :href="appHref('/exam')">返回笔试列表</a>
      </div>
      <template v-else>
        <div class="prep-grid">
          <article class="cam-card">
            <div class="cam-title"><span>主机位（电脑摄像头）</span><i class="dot" :class="mainStatus === 'live' ? 'ok' : 'gray'"></i></div>
            <div class="cam-frame">
              <video v-show="mainStatus === 'live'" ref="mainVideo" class="cam-video" autoplay muted playsinline></video>
              <div v-if="mainStatus !== 'live'" class="cam-mask">
                <span v-if="mainStatus === 'connecting'">摄像头连接中…</span>
                <span v-else-if="mainStatus === 'error'">{{ mainError || '主机位连接失败' }}</span>
                <span v-else>等待开启摄像头</span>
              </div>
            </div>
            <button v-if="mainStatus !== 'live'" class="cam-btn" type="button" @click="startMainCamera">开启主机位摄像头</button>
            <p class="cam-tip">正对屏幕，保持面部清晰可见</p>
          </article>

          <article class="cam-card">
            <div class="cam-title"><span>副机位（手机扫码）</span><i class="dot" :class="subOnline ? 'ok' : 'gray'"></i></div>
            <div class="cam-frame">
              <video v-show="subVideoLive" ref="subVideo" class="cam-video" autoplay muted playsinline></video>
              <div v-if="!subVideoLive" class="cam-mask">
                <canvas v-show="subUrl" ref="subQr"></canvas>
                <span v-if="subUrl">手机扫码后，画面会实时显示在这里</span>
                <span v-else>二维码生成中…</span>
              </div>
            </div>
            <p class="cam-tip">手机置于侧后方 45°，需拍到电脑屏幕与本人双手</p>
          </article>
        </div>

        <ul class="check-list">
          <li :class="{ ok: mainStatus === 'live' }"><i>{{ mainStatus === 'live' ? '✓' : '·' }}</i>主机位画面已开启</li>
          <li :class="{ ok: subOnline }"><i>{{ subOnline ? '✓' : '·' }}</i>副机位手机已连接{{ forceDual ? '（本场必开）' : '（可选）' }}</li>
        </ul>

        <div class="prep-actions">
          <button class="primary-btn" type="button" :disabled="!canStart || starting" @click="begin">
            {{ starting ? '正在开始…' : canStart ? '开始作答（开始计时）' : startBlockedText }}
          </button>
          <a class="ghost-link" :href="appHref('/exam')">返回笔试列表</a>
        </div>
        <p class="prep-note">点击“开始作答”后才开始计时，此处调整设备不会占用答题时间。</p>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Room, RoomEvent, Track } from 'livekit-client'
import QRCode from 'qrcode'
import { getExamEntry, getExamMonitor, prepareExam, startExam } from '@/api/agent/exam'
import { appHref } from '@/utils/agentNavigation'
import { userAppUrl } from '@/utils/appLink'

const route = useRoute()
const router = useRouter()
const scheduleId = String(route.query.scheduleId || '')

const loading = ref(true)
const loadError = ref('')
const entry = ref(null)
const recordId = ref(null)
const monitorInfo = ref({})
const forceDual = ref(false)
const mainStatus = ref('idle') // idle | connecting | live | error
const mainError = ref('')
const subVideoLive = ref(false)
const subInfo = ref({ subStatus: 0, subOnline: false })
const subUrl = ref('')
const starting = ref(false)

const mainVideo = ref(null)
const subVideo = ref(null)
const subQr = ref(null)

let room = null
let pollTimer = null

const subOnline = computed(() => subVideoLive.value || !!subInfo.value.subOnline)
const canStart = computed(() => mainStatus.value === 'live' && (!forceDual.value || subOnline.value))
const allPassed = computed(() => canStart.value)
const startBlockedText = computed(() => {
  if (mainStatus.value !== 'live') return '请先开启主机位摄像头'
  return '请先完成副机位扫码'
})

async function load() {
  try {
    const entryRes = await getExamEntry(scheduleId)
    entry.value = entryRes.data
    const prepRes = await prepareExam(scheduleId)
    recordId.value = prepRes.data?.recordId
    if (!recordId.value) throw new Error('考试记录创建失败')
    await loadMonitor()
  } catch (e) {
    loadError.value = e?.msg || e?.message || '设备检测加载失败'
  } finally {
    loading.value = false
  }
  if (loadError.value) return
  await nextTick()
  startMainCamera()
}

async function loadMonitor() {
  const res = await getExamMonitor(recordId.value)
  monitorInfo.value = res.data || {}
  forceDual.value = Number(monitorInfo.value.forceDualCamera) === 1
  subInfo.value = monitorInfo.value.sub || { subStatus: 0, subOnline: false }
  // 副机位地址按当前部署位置拼接，兼容 /user/ 子路径
  subUrl.value = userAppUrl(monitorInfo.value.subUrl || '')
  await nextTick()
  if (subQr.value && subUrl.value) {
    await QRCode.toCanvas(subQr.value, subUrl.value, { width: 150, margin: 1 })
  }
  if (!pollTimer) {
    // 手机端心跳每 15s 上报一次，这里 5s 轮询一次连接状态
    pollTimer = setInterval(async () => {
      try {
        const r = await getExamMonitor(recordId.value)
        subInfo.value = (r.data || {}).sub || subInfo.value
      } catch (e) { /* 轮询失败忽略 */ }
    }, 5000)
  }
}

function bindRemoteTracks() {
  // 手机副机位发布摄像头后，把远端画面挂到准备界面的副机位框内
  room.on(RoomEvent.TrackSubscribed, (track) => {
    if (track.kind === Track.Kind.Video) {
      if (subVideo.value) track.attach(subVideo.value)
      subVideoLive.value = true
    }
  })
  room.on(RoomEvent.TrackUnsubscribed, (track) => {
    track.detach()
    subVideoLive.value = false
  })
  room.on(RoomEvent.ParticipantDisconnected, () => {
    subVideoLive.value = false
  })
}

async function startMainCamera() {
  if (!monitorInfo.value.url || !monitorInfo.value.token || mainStatus.value === 'connecting' || mainStatus.value === 'live') return
  mainStatus.value = 'connecting'
  mainError.value = ''
  try {
    room = new Room()
    bindRemoteTracks()
    await room.connect(monitorInfo.value.url, monitorInfo.value.token)
    await room.localParticipant.setCameraEnabled(true)
    const track = room.localParticipant.getTrackPublication(Track.Source.Camera)?.track
    if (track && mainVideo.value) track.attach(mainVideo.value)
    mainStatus.value = 'live'
  } catch (e) {
    mainStatus.value = 'error'
    mainError.value = e?.message || '摄像头连接失败'
  }
}

async function begin() {
  if (!canStart.value || starting.value) return
  starting.value = true
  try {
    await startExam(scheduleId)
    router.push({ path: '/exam-room', query: { scheduleId } })
  } catch (e) {
    loadError.value = e?.msg || e?.message || '开始考试失败，请重试'
    starting.value = false
  }
}

function teardown() {
  if (pollTimer) clearInterval(pollTimer)
  pollTimer = null
  if (room) {
    try { room.localParticipant.setCameraEnabled(false) } catch (e) { /* ignore */ }
    try { room.disconnect() } catch (e) { /* ignore */ }
    room = null
  }
}

onMounted(load)
onBeforeUnmount(teardown)
</script>

<style scoped>
:global(body){margin:0;background:#F5F7FB;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}
.prep{min-height:100vh;display:flex;flex-direction:column;color:#1F2A37}
.prep-head{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;padding:22px 28px;background:#fff;border-bottom:1px solid #E6EBF2}
.prep-head h1{margin:0;font-size:20px}
.prep-head p{margin:6px 0 0;color:#728096;font-size:12px}
.status-pill{padding:4px 12px;border-radius:999px;font-size:11px;font-weight:700}
.status-pill.green{color:#15803D;background:#E7F8EE}
.status-pill.orange{color:#B45309;background:#FFF4E5}
.prep-body{flex:1;width:100%;max-width:900px;margin:0 auto;padding:22px 20px 40px}
.center-card{padding:40px;text-align:center;color:#728096;font-size:13px;background:#fff;border-radius:14px}
.center-card.err h2{margin:0 0 8px;color:#E5484D;font-size:16px}
.prep-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}
@media(max-width:720px){.prep-grid{grid-template-columns:1fr}}
.cam-card{background:#fff;border:1px solid #E6EBF2;border-radius:14px;padding:14px}
.cam-title{display:flex;align-items:center;justify-content:space-between;font-size:13px;font-weight:700}
.dot{width:9px;height:9px;border-radius:50%;background:#C8D3E2}
.dot.ok{background:#22C55E}
.cam-frame{position:relative;margin-top:10px;width:100%;aspect-ratio:1/1;background:#0F1722;border-radius:12px;overflow:hidden;display:grid;place-items:center}
.cam-video{width:100%;height:100%;object-fit:cover}
.cam-mask{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;color:#8FA1B8;font-size:12px;text-align:center;padding:0 18px}
.cam-mask canvas{width:150px;height:150px;border-radius:8px;background:#fff}
.cam-btn{margin-top:10px;width:100%;height:36px;border:0;border-radius:9px;background:#2B7FFF;color:#fff;font-size:12px;font-weight:700;cursor:pointer}
.cam-tip{margin:9px 0 0;color:#8A97AB;font-size:11px;line-height:1.5}
.check-list{list-style:none;display:flex;gap:22px;margin:18px 0 0;padding:0;color:#8A97AB;font-size:12px;flex-wrap:wrap}
.check-list li{display:flex;align-items:center;gap:6px}
.check-list li i{width:16px;height:16px;display:grid;place-items:center;border-radius:50%;background:#EEF2F7;color:#8A97AB;font-style:normal;font-size:11px}
.check-list li.ok{color:#15803D}
.check-list li.ok i{background:#E7F8EE;color:#15803D}
.prep-actions{display:flex;align-items:center;gap:16px;margin-top:22px}
.primary-btn{height:42px;padding:0 26px;border:0;border-radius:10px;background:#2B7FFF;color:#fff;font-size:13px;font-weight:700;cursor:pointer}
.primary-btn:disabled{background:#C8D9F0;cursor:not-allowed}
.ghost-link{color:#728096;font-size:12px}
.prep-note{margin:12px 0 0;color:#8A97AB;font-size:11px}
</style>
