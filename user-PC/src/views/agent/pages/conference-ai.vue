<template>
  <div class="ca-page">
    <header class="ca-topbar">
      <div class="ca-tb-left">
        <strong>{{ header.positionTitle }}</strong>
        <span class="ca-chip">第 {{ header.roundNo }} 轮</span>
        <span class="ca-chip mode">AI 面试</span>
      </div>
      <div class="ca-tb-right">
        <span class="ca-timer">{{ clock }}</span>
        <span class="ca-net" :class="netLevel"><i />{{ netLevel === 'ok' ? '网络良好' : '网络波动' }}</span>
        <span class="ca-rec"><i />录制中</span>
      </div>
    </header>

    <div class="ca-banner">
      <span class="ca-banner-dot" />
      面试全程录音录像，仅用于招聘评估与合规存档，请确保环境安静并独立作答
    </div>

    <section class="ca-stage">
      <div ref="stageRef" class="ca-video">
        <div class="ca-ai">
          <div class="ca-orb">
            <span class="ca-ring" />
            <span class="ca-ring delay" />
            <span class="ca-orb-core">AI</span>
          </div>
          <h2>AI 面试官 · 智聘</h2>
          <p>正在聆听你的回答…</p>
        </div>

        <div class="ca-question">
          <div class="ca-q-head">
            <span class="ca-q-index">第 {{ progress.current }} 题 / 共 {{ progress.total }} 题</span>
            <div class="ca-q-bar"><u :style="{ width: (progress.current / progress.total) * 100 + '%' }" /></div>
          </div>
          <p class="ca-q-text">{{ questionText }}</p>
        </div>

        <div class="ca-self" :style="selfStyle" @mousedown.prevent="startDrag">
          <video v-show="camOn" ref="selfVideo" autoplay playsinline muted />
          <div v-if="!camOn" class="ca-self-fallback"><Icon name="video" :size="20" /><span>摄像头未开启</span></div>
          <span class="ca-self-name">我</span>
          <button class="ca-self-hide" title="隐藏我的画面" @mousedown.stop @click.stop="selfVisible = false">×</button>
        </div>
        <button v-if="!selfVisible" class="ca-self-restore" @click="selfVisible = true">显示我的画面</button>

        <div class="ca-captions" :class="{ live: captionOn }">
          <div class="ca-cap-tag">实时字幕</div>
          <div ref="capListRef" class="ca-cap-list">
            <p v-for="(item, index) in captions" :key="index" :class="{ me: item.who === '我' }">
              <b>{{ item.who }}</b>{{ item.text }}
            </p>
          </div>
        </div>
      </div>
    </section>

    <footer class="ca-controls">
      <button class="ca-ctl" :class="{ off: !micOn }" @click="toggleMic">
        <Icon :name="micOn ? 'mic' : 'micOff'" :size="20" /><span>麦克风</span>
      </button>
      <button class="ca-ctl" :class="{ off: !camOn }" @click="toggleCam">
        <Icon name="video" :size="20" /><span>摄像头</span>
      </button>
      <button class="ca-ctl" :class="{ on: captionOn }" @click="captionOn = !captionOn">
        <Icon name="caption" :size="20" /><span>字幕</span>
      </button>
      <button class="ca-ctl" @click="notify('打开会议设置：可切换摄像头、麦克风与字幕语言')">
        <Icon name="settings" :size="20" /><span>设置</span>
      </button>
      <button class="ca-ctl hang" @click="showConfirm = true">
        <Icon name="phoneOff" :size="20" /><span>结束会议</span>
      </button>
    </footer>

    <div v-if="showConfirm" class="ca-mask">
      <section class="ca-modal">
        <h3>确认结束本次面试？</h3>
        <p>结束后将无法继续作答，剩余题目会被记为未完成，并进入评估报告生成流程。</p>
        <div class="ca-modal-actions">
          <button class="ca-cancel" @click="showConfirm = false">取消</button>
          <button class="ca-confirm" @click="endMeeting">确认结束</button>
        </div>
      </section>
    </div>

    <div class="ca-toast" :class="{ show: toast }">{{ toast }}</div>
  </div>
</template>

<script setup>
import { computed, defineComponent, h, onBeforeUnmount, onMounted, nextTick, ref } from 'vue'
import { getCurrentSession, getProgress, listCaptions, heartbeat, finishSession, updateMedia } from '@/api/system/conference'
import { describeMediaNotice, requestMedia } from '@/utils/media'

const PATHS = {
  mic: ['M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z', 'M19 10v2a7 7 0 0 1-14 0v-2', 'M12 19v3', 'M8 22h8'],
  micOff: ['m2 2 20 20', 'M18.89 13.23A7.12 7.12 0 0 0 19 12v-2', 'M5 10v2a7 7 0 0 0 12 5', 'M15 9.34V5a3 3 0 0 0-5.68-1.33', 'M9 9v3a3 3 0 0 0 5.12 2.12', 'M12 19v3', 'M8 22h8'],
  video: ['m22 8-6 4 6 4V8Z', 'M2 6h14v12H2z'],
  caption: ['M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z', 'M16 8H8', 'M13 12H8'],
  settings: ['M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z', 'M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-2.82 1.18V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6h.09A1.65 1.65 0 0 0 11 3V3a2 2 0 1 1 4 0v.09A1.65 1.65 0 0 0 16.9 4.6a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 21.4 9v.09a1.65 1.65 0 0 0 1.51 1z'],
  phoneOff: ['m2 2 20 20', 'M16 14v-1c0-.55.45-1 1-1h3c.55 0 1 .45 1 1v1.5c0 1.38-1.12 2.5-2.5 2.5C10.61 18 6 13.39 6 6.5 6 5.12 7.12 4 8.5 4H10c.55 0 1 .45 1 1v3c0 .55-.45 1-1 1H9']
}

const Icon = defineComponent({
  props: { name: { type: String, required: true }, size: { type: Number, default: 18 } },
  setup(props) {
    return () => h('svg', {
      width: props.size, height: props.size, viewBox: '0 0 24 24',
      fill: 'none', stroke: 'currentColor', 'stroke-width': 1.8,
      'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'aria-hidden': 'true'
    }, PATHS[props.name].map((d) => h('path', { d })))
  }
})

const stageRef = ref(null)
const selfVideo = ref(null)
const capListRef = ref(null)
const selfPos = ref({ x: null, y: null })
const selfVisible = ref(true)

const micOn = ref(true)
const camOn = ref(true)
const captionOn = ref(true)
const netLevel = ref('ok')
const showConfirm = ref(false)
const toast = ref('')
const sessionId = ref(null)
// 面试进度/题面/顶部信息：默认文案用于无后端时演示，接口返回后覆盖
const progress = ref({ current: 3, total: 10 })
const questionText = ref('请结合你在订单中心的经历，说明分布式事务的选型过程，以及最终落地时遇到的补偿与幂等问题是如何解决的？')
const header = ref({ positionTitle: '高级前端工程师', roundNo: 1 })

const seconds = ref(501) // 08:21
const clock = computed(() => {
  const m = String(Math.floor(seconds.value / 60)).padStart(2, '0')
  const s = String(seconds.value % 60).padStart(2, '0')
  return `${m}:${s}`
})

const captions = ref([
  { who: 'AI 面试官', text: '我们开始第 3 题，请结合项目经历说明分布式事务的选型过程。' },
  { who: '我', text: '好的，我们在订单中心使用了 TCC 模式，主要是为了避免 XA 的长事务锁。' },
  { who: 'AI 面试官', text: '明白了，那补偿阶段如果失败，你们是如何保证最终一致性的？' }
])
const captionPool = [
  { who: '我', text: '我们给每个分支事务加了业务唯一号，保证补偿逻辑幂等。' },
  { who: 'AI 面试官', text: '很好，请补充说明防悬挂和空回滚的处理方式。' },
  { who: '我', text: '事务控制表会先落一条记录，补偿时先校验状态再执行。' }
]

const selfStyle = computed(() =>
  selfPos.value.x === null ? { right: '16px', bottom: '16px' } : { left: `${selfPos.value.x}px`, top: `${selfPos.value.y}px` }
)

let videoTrack = null
let audioTrack = null
let timerId = null
let captionId = null
let heartbeatId = null
let captionIndex = 0
let toastTimer = null

function notify(message) {
  toast.value = message
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => (toast.value = ''), 2400)
}

function startDrag(event) {
  const stage = stageRef.value?.getBoundingClientRect()
  const box = event.currentTarget.getBoundingClientRect()
  if (!stage) return
  const offX = event.clientX - box.left
  const offY = event.clientY - box.top
  const move = (ev) => {
    const nx = ev.clientX - stage.left - offX
    const ny = ev.clientY - stage.top - offY
    selfPos.value = {
      x: Math.max(8, Math.min(stage.width - box.width - 8, nx)),
      y: Math.max(8, Math.min(stage.height - box.height - 8, ny))
    }
  }
  const up = () => {
    document.removeEventListener('mousemove', move)
    document.removeEventListener('mouseup', up)
  }
  document.addEventListener('mousemove', move)
  document.addEventListener('mouseup', up)
}

async function openCamera() {
  if (!navigator.mediaDevices?.getUserMedia) {
    camOn.value = false
    notify('当前浏览器不支持摄像头访问，请在 127.0.0.1 或 localhost 下使用最新版浏览器')
    return
  }
  // 摄像头与麦克风分开申请：只屏蔽其中一项时另一项仍可正常采集
  const [camResult, micResult] = await Promise.all([
    requestMedia({ video: true }).then((stream) => ({ stream })).catch((error) => ({ error })),
    audioTrack
      ? Promise.resolve(null)
      : requestMedia({ audio: true }).then((stream) => ({ stream })).catch((error) => ({ error }))
  ])

  if (camResult.error) {
    camOn.value = false
  } else {
    videoTrack = camResult.stream.getVideoTracks()[0] || null
    if (selfVideo.value) selfVideo.value.srcObject = videoTrack ? new MediaStream([videoTrack]) : null
    camOn.value = !!videoTrack
    if (sessionId.value) updateMedia(sessionId.value, { cameraEnabled: true }).catch(() => {})
  }
  if (micResult && !micResult.error) {
    audioTrack = micResult.stream.getAudioTracks()[0] || null
    if (audioTrack) audioTrack.enabled = micOn.value
  }

  // 汇总提示：两者都失败时只弹一条，避免前一条被覆盖
  const failures = []
  if (camResult.error) failures.push({ error: camResult.error, kind: 'camera' })
  if (micResult?.error) failures.push({ error: micResult.error, kind: 'microphone' })
  if (failures.length === 1) {
    notify(await describeMediaNotice(failures[0].error, failures[0].kind))
  } else if (failures.length === 2) {
    notify('未获得摄像头与麦克风权限，请在浏览器地址栏允许访问后重新进入面试')
  }
}

function closeCamera() {
  videoTrack?.stop()
  videoTrack = null
  if (selfVideo.value) selfVideo.value.srcObject = null
  if (sessionId.value) updateMedia(sessionId.value, { cameraEnabled: false }).catch(() => {})
}

function toggleMic() {
  if (!audioTrack) {
    notify('麦克风尚未就绪，请检查浏览器权限')
    return
  }
  micOn.value = !micOn.value
  audioTrack.enabled = micOn.value
  notify(micOn.value ? '麦克风已开启' : '麦克风已静音')
}

async function toggleCam() {
  if (camOn.value) {
    closeCamera()
    camOn.value = false
    notify('摄像头已关闭，面试官将无法看到你的画面')
    return
  }
  await openCamera()
  // 开启失败时 openCamera 已给出具体原因，此处不再覆盖提示
  if (camOn.value) notify('摄像头已开启')
}

async function endMeeting() {
  showConfirm.value = false
  closeCamera()
  if (sessionId.value) {
    try {
      await finishSession(sessionId.value, 'normal')
    } catch (error) {
      // 结束接口失败不阻塞跳转
    }
  }
  window.__agentNavigate('/agent/conference-ended')
}

function scrollCaptions() {
  nextTick(() => {
    const node = capListRef.value
    if (node) node.scrollTop = node.scrollHeight
  })
}

onMounted(() => {
  openCamera()
  timerId = setInterval(() => (seconds.value += 1), 1000)
  captionId = setInterval(() => {
    const next = captionPool[captionIndex % captionPool.length]
    captionIndex += 1
    captions.value.push(next)
    if (captions.value.length > 30) captions.value.shift()
    scrollCaptions()
  }, 8000)
  scrollCaptions()
  initSession()
})

async function initSession() {
  try {
    const res = await getCurrentSession()
    if (res.data && res.data.sessionId) {
      sessionId.value = res.data.sessionId
      if (res.data.positionTitle) header.value.positionTitle = res.data.positionTitle
      if (res.data.roundNo) header.value.roundNo = res.data.roundNo
    }
  } catch (error) {
    // 无后端时保留本地演示
  }
  if (!sessionId.value) return
  try {
    const p = await getProgress(sessionId.value)
    if (p.data) {
      if (p.data.currentQuestionNo) progress.value.current = p.data.currentQuestionNo
      if (p.data.totalQuestionNo) progress.value.total = p.data.totalQuestionNo
      if (p.data.question && p.data.question.topic) questionText.value = p.data.question.topic
    }
  } catch (error) {
    // 拉取进度失败保留 mock
  }
  try {
    const c = await listCaptions(sessionId.value, { afterSequence: 0, limit: 50 })
    if (Array.isArray(c.data) && c.data.length > 0) {
      const roleMap = { 1: 'AI', 2: 'HR', 3: '我' }
      captions.value = c.data.map((item) => ({ who: roleMap[item.role] || 'AI', text: item.content }))
      // 已接入真实字幕，停掉 mock 追加定时器
      clearInterval(captionId)
      captionId = null
      scrollCaptions()
    }
  } catch (error) {
    // 拉取字幕失败保留 mock
  }
  heartbeatId = setInterval(() => heartbeat(sessionId.value).catch(() => {}), 15000)
}

onBeforeUnmount(() => {
  clearInterval(timerId)
  clearInterval(captionId)
  clearInterval(heartbeatId)
  clearTimeout(toastTimer)
  closeCamera()
  audioTrack?.stop()
  audioTrack = null
})
</script>

<style scoped>
.ca-page {
  --p: #1A3C6E;
  --b: #2B7FFF;
  --rec: #FF4D4F;
  --ok: #52C41A;
  --warn: #FAAD14;
  --bg: #141414;
  --panel: #1C1F26;
  --line: rgba(255, 255, 255, .1);
  position: fixed; inset: 0;
  display: flex; flex-direction: column;
  background: var(--bg);
  color: #EDF1F7;
  font: 14px/1.6 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
.ca-page * { box-sizing: border-box; }
.ca-page button { font: inherit; cursor: pointer; }
.ca-page h2, .ca-page h3, .ca-page p { margin: 0; }

.ca-topbar { height: 56px; flex: none; padding: 0 18px; display: flex; align-items: center; justify-content: space-between; background: var(--panel); border-bottom: 1px solid var(--line); }
.ca-tb-left, .ca-tb-right { display: flex; align-items: center; gap: 12px; }
.ca-tb-left strong { font-size: 16px; }
.ca-chip { height: 22px; padding: 0 9px; display: inline-flex; align-items: center; border-radius: 999px; background: rgba(255, 255, 255, .08); color: #97A5BB; font-size: 12px; }
.ca-chip.mode { color: #8FB8FF; background: rgba(43, 127, 255, .18); }
.ca-timer { padding: 0 11px; height: 28px; display: inline-flex; align-items: center; border-radius: 8px; background: rgba(255, 255, 255, .08); font-variant-numeric: tabular-nums; font-weight: 600; }
.ca-net, .ca-rec { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; }
.ca-net i, .ca-rec i { width: 7px; height: 7px; border-radius: 50%; background: currentColor; }
.ca-net { color: var(--ok); }
.ca-net.warn { color: var(--warn); }
.ca-rec { color: var(--rec); }
.ca-rec i { animation: ca-blink 1.1s infinite; }
@keyframes ca-blink { 0%, 100% { opacity: 1; } 50% { opacity: .18; } }

.ca-banner { flex: none; height: 34px; display: flex; align-items: center; justify-content: center; gap: 8px; background: rgba(250, 173, 20, .14); border-bottom: 1px solid rgba(250, 173, 20, .28); color: #FFD591; font-size: 12px; }
.ca-banner-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--rec); }

.ca-stage { flex: 1; min-height: 0; padding: 12px; display: flex; }
.ca-video { position: relative; flex: 1; min-width: 0; border-radius: 14px; overflow: hidden; background: radial-gradient(120% 90% at 50% 20%, #1E2A44 0%, #10141C 62%, #0A0D14 100%); box-shadow: 0 24px 60px rgba(0, 0, 0, .5); }

.ca-ai { position: absolute; left: 50%; top: 44%; transform: translate(-50%, -50%); text-align: center; }
.ca-orb { position: relative; width: 136px; height: 136px; margin: 0 auto; display: grid; place-items: center; }
.ca-orb-core { width: 96px; height: 96px; display: grid; place-items: center; border-radius: 50%; color: #fff; font-size: 24px; font-weight: 800; letter-spacing: 1px; background: linear-gradient(150deg, #2B7FFF, #1A3C6E); box-shadow: 0 0 40px rgba(43, 127, 255, .55); }
.ca-orb-core::after { content: ''; position: absolute; width: 96px; height: 96px; border-radius: 50%; background: linear-gradient(150deg, rgba(43, 127, 255, .5), transparent 70%); animation: ca-spin 6s linear infinite; }
@keyframes ca-spin { to { transform: rotate(360deg); } }
.ca-ring { position: absolute; inset: 8px; border-radius: 50%; border: 1px solid rgba(43, 127, 255, .5); animation: ca-pulse 2.6s ease-out infinite; }
.ca-ring.delay { animation-delay: 1.3s; }
@keyframes ca-pulse { 0% { transform: scale(.86); opacity: .85; } 100% { transform: scale(1.28); opacity: 0; } }
.ca-ai h2 { margin-top: 18px; font-size: 17px; }
.ca-ai p { margin-top: 6px; color: #8394AC; font-size: 13px; }

.ca-question { position: absolute; left: 20px; right: 20px; top: 18px; max-width: 560px; padding: 14px 16px; border-radius: 12px; background: rgba(12, 17, 26, .72); border: 1px solid var(--line); backdrop-filter: blur(8px); }
.ca-q-head { display: flex; align-items: center; gap: 12px; }
.ca-q-index { font-size: 12px; color: #8FB8FF; font-weight: 600; white-space: nowrap; }
.ca-q-bar { flex: 1; height: 5px; border-radius: 999px; background: rgba(255, 255, 255, .14); }
.ca-q-bar u { display: block; height: 100%; border-radius: inherit; background: linear-gradient(90deg, #2B7FFF, #6FA8FF); }
.ca-q-text { margin-top: 10px; font-size: 14px; line-height: 1.7; color: #E4EBF5; }

.ca-self { position: absolute; width: 160px; height: 90px; border-radius: 10px; overflow: hidden; border: 2px solid rgba(255, 255, 255, .8); background: #0B0F16; cursor: move; box-shadow: 0 12px 28px rgba(0, 0, 0, .5); }
.ca-self video { width: 100%; height: 100%; object-fit: cover; display: block; pointer-events: none; }
.ca-self-fallback { position: absolute; inset: 0; display: grid; place-content: center; justify-items: center; gap: 5px; color: #6E7C90; font-size: 11px; }
.ca-self-fallback svg { color: #4A5768; }
.ca-self-name { position: absolute; left: 7px; bottom: 5px; font-size: 10px; color: #fff; text-shadow: 0 1px 3px rgba(0, 0, 0, .8); pointer-events: none; }
.ca-self-hide { position: absolute; right: 5px; top: 4px; width: 20px; height: 20px; border: 0; border-radius: 6px; background: rgba(8, 12, 20, .65); color: #fff; font-size: 15px; line-height: 1; display: grid; place-items: center; }
.ca-self-restore { position: absolute; right: 16px; bottom: 16px; height: 32px; padding: 0 13px; border: 1px solid var(--line); border-radius: 8px; background: rgba(10, 14, 22, .75); color: #CFE0FF; font-size: 12px; }

.ca-captions { position: absolute; left: 0; right: 0; bottom: 0; max-height: 148px; padding: 12px 18px 14px; background: linear-gradient(180deg, rgba(6, 9, 14, 0), rgba(6, 9, 14, .86) 42%); display: flex; flex-direction: column; transition: .2s; }
.ca-captions:not(.live) { opacity: .3; }
.ca-cap-tag { font-size: 11px; color: #7F8CA1; margin-bottom: 6px; }
.ca-cap-list { overflow-y: auto; display: grid; gap: 6px; padding-right: 6px; }
.ca-cap-list p { font-size: 14px; line-height: 1.6; color: #fff; text-shadow: 0 1px 4px rgba(0, 0, 0, .8); }
.ca-cap-list p b { color: #8FB8FF; margin-right: 8px; font-weight: 600; }
.ca-cap-list p.me b { color: #7EE0A0; }
.ca-cap-list::-webkit-scrollbar { width: 5px; }
.ca-cap-list::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, .22); border-radius: 999px; }

.ca-controls { height: 78px; flex: none; display: flex; align-items: center; justify-content: center; gap: 10px; background: var(--panel); border-top: 1px solid var(--line); }
.ca-ctl { position: relative; width: 48px; height: 48px; border: 1px solid var(--line); border-radius: 12px; background: rgba(255, 255, 255, .06); color: #EDF1F7; display: grid; place-items: center; }
.ca-ctl span { position: absolute; bottom: calc(100% + 10px); left: 50%; transform: translateX(-50%); padding: 5px 9px; border-radius: 7px; background: #05080E; border: 1px solid var(--line); color: #EDF1F7; font-size: 11px; white-space: nowrap; opacity: 0; pointer-events: none; transition: .16s; }
.ca-ctl:hover span { opacity: 1; }
.ca-ctl:hover { border-color: var(--b); }
.ca-ctl.off { background: var(--rec); border-color: transparent; }
.ca-ctl.on { background: var(--b); border-color: transparent; }
.ca-ctl.hang { background: var(--rec); border-color: transparent; }
.ca-ctl.hang:hover { background: #FF6B6D; }

.ca-mask { position: fixed; inset: 0; z-index: 60; display: grid; place-items: center; padding: 20px; background: rgba(0, 0, 0, .62); }
.ca-modal { width: min(420px, 100%); padding: 24px; border-radius: 12px; background: #1C2029; border: 1px solid var(--line); box-shadow: 0 24px 60px rgba(0, 0, 0, .5); animation: ca-pop .2s ease; }
@keyframes ca-pop { from { opacity: 0; transform: translateY(8px) scale(.98); } to { opacity: 1; transform: none; } }
.ca-modal h3 { font-size: 17px; }
.ca-modal p { margin-top: 10px; color: #97A5BB; font-size: 13px; line-height: 1.75; }
.ca-modal-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 22px; }
.ca-cancel { height: 40px; padding: 0 20px; border: 1px solid var(--line); border-radius: 9px; background: transparent; color: #B9C4D4; }
.ca-confirm { height: 40px; padding: 0 22px; border: 0; border-radius: 9px; background: var(--rec); color: #fff; font-weight: 700; }

.ca-toast { position: fixed; left: 50%; bottom: 98px; transform: translate(-50%, 8px); z-index: 80; padding: 11px 16px; border-radius: 9px; background: #0B1220; border: 1px solid var(--line); color: #fff; font-size: 13px; opacity: 0; pointer-events: none; transition: .2s; }
.ca-toast.show { opacity: 1; transform: translate(-50%, 0); }

@media (max-width: 900px) {
  .ca-question { left: 14px; right: 14px; top: 14px; }
  .ca-q-text { font-size: 13px; }
  .ca-self { width: 120px; height: 68px; }
}
</style>