<template>
  <div class="ca-page">
    <header class="ca-topbar">
      <div class="ca-tb-left">
        <strong>{{ header.positionTitle }}</strong>
        <span class="ca-chip">第 {{ header.roundNo }} 轮</span>
        <span class="ca-chip mode">{{ modeLabel }}</span>
      </div>
      <div class="ca-tb-right">
        <span class="ca-timer">{{ clock }}</span>
        <span class="ca-net" :class="netLevel"><i />{{ netLevel === 'ok' ? '网络良好' : '网络波动' }}</span>
        <span v-if="recording" class="ca-rec"><i />录制中</span>
      </div>
    </header>

    <div class="ca-banner">
      <span class="ca-banner-dot" />
      面试全程录音录像，仅用于招聘评估与合规存档，请确保环境安静并独立作答
    </div>

    <section class="ca-stage">
      <div ref="stageRef" class="ca-video">
        <!-- 面试官宫格：多位面试官画面并排占据主区，本人画面仍以小窗独立呈现 -->
        <div class="ca-grid" :class="`g${Math.min(interviewers.length || 1, 6)}`">
          <div v-for="p in interviewers" :key="p.userId" class="ca-tile">
            <video
              v-show="tileStream(p.userId)"
              :ref="(el) => setTileEl(p.userId, el)"
              class="ca-tile-video"
              autoplay
              playsinline
            />
            <div v-if="!tileStream(p.userId)" class="ca-tile-waiting">
              <Icon name="video" :size="26" />
              <span>等待 {{ p.name }} 画面…</span>
            </div>
            <span v-if="tileStream(p.userId)" class="ca-tile-tag"><i />{{ p.name }} · {{ p.roleLabel }}</span>
          </div>
          <div v-if="!interviewers.length" class="ca-grid-empty">
            <Icon name="video" :size="30" />
            <span>等待面试官进入…</span>
          </div>
        </div>

        <!-- AI 画中画：无AI 纯人工模式隐藏 -->
        <div
          v-if="showAiPanel"
          ref="aiRef"
          class="ca-ai-pip"
          :style="aiStyle"
          @mousedown.prevent="startDragAi"
        >
          <div class="ca-orb">
            <span class="ca-ring" />
            <span class="ca-ring delay" />
            <span class="ca-orb-core">AI</span>
          </div>
          <div class="ca-ai-pip-meta"><b>AI 面试官</b><small>正在聆听…</small></div>
        </div>

        <!-- 当前题目：无AI 模式隐藏 -->
        <div v-if="showAiPanel" class="ca-question">
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

        <div v-if="sharing" class="ca-share-tip"><Icon name="share" :size="14" />正在向面试官共享屏幕</div>

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
      <button class="ca-ctl" :class="{ on: sharing }" @click="toggleShare">
        <Icon name="share" :size="20" /><span>{{ sharing ? '停止共享' : '共享屏幕' }}</span>
      </button>
      <button class="ca-ctl" @click="openSettings">
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

    <div v-if="showSettings" class="ca-mask" @click.self="showSettings = false">
      <section class="ca-modal">
        <h3>会议设置</h3>
        <p style="margin-top: 6px">切换采集设备后画面与声音立即生效（如使用外接摄像头，请在列表中选择对应设备）。</p>
        <div class="ca-set-field">
          <label>摄像头</label>
          <select v-model="setCamId" @change="applyDevice('video')">
            <option value="">系统默认</option>
            <option v-for="item in cameraDevices" :key="item.deviceId" :value="item.deviceId">{{ item.label }}</option>
          </select>
        </div>
        <div class="ca-set-field">
          <label>麦克风</label>
          <select v-model="setMicId" @change="applyDevice('audio')">
            <option value="">系统默认</option>
            <option v-for="item in microphoneDevices" :key="item.deviceId" :value="item.deviceId">{{ item.label }}</option>
          </select>
        </div>
        <div class="ca-modal-actions">
          <button class="ca-cancel" @click="showSettings = false">完成</button>
        </div>
      </section>
    </div>

    <div class="ca-toast" :class="{ show: toast }">{{ toast }}</div>
  </div>
</template>

<script setup>
import { computed, defineComponent, h, onBeforeUnmount, onMounted, nextTick, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { getCurrentSession, getSessionContext, getProgress, listCaptions, heartbeat, finishSession, updateMedia } from '@/api/system/conference'
import { clearPreferredDevice, describeMediaNotice, getPreferredDevice, listMediaDevices, requestMedia, requestMediaWithFallback, savePreferredDevice } from '@/utils/media'
import { createConferenceRtc } from '@/utils/webrtc'

const PATHS = {
  mic: ['M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z', 'M19 10v2a7 7 0 0 1-14 0v-2', 'M12 19v3', 'M8 22h8'],
  micOff: ['m2 2 20 20', 'M18.89 13.23A7.12 7.12 0 0 0 19 12v-2', 'M5 10v2a7 7 0 0 0 12 5', 'M15 9.34V5a3 3 0 0 0-5.68-1.33', 'M9 9v3a3 3 0 0 0 5.12 2.12', 'M12 19v3', 'M8 22h8'],
  video: ['m22 8-6 4 6 4V8Z', 'M2 6h14v12H2z'],
  caption: ['M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z', 'M16 8H8', 'M13 12H8'],
  settings: ['M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z', 'M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-2.82 1.18V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6h.09A1.65 1.65 0 0 0 11 3V3a2 2 0 1 1 4 0v.09A1.65 1.65 0 0 0 16.9 4.6a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 21.4 9v.09a1.65 1.65 0 0 0 1.51 1z'],
  share: ['M4 4h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z', 'M8 21h8', 'M12 17v4', 'M12 13V8', 'm9 11 3-3 3 3'],
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

const route = useRoute()
const stageRef = ref(null)
const selfVideo = ref(null)
const capListRef = ref(null)
const selfPos = ref({ x: null, y: null })
const selfVisible = ref(true)
// AI 画中画位置（拖动调整，默认右下角偏上，避开自画面小窗与字幕条）
const aiRef = ref(null)
const aiPos = ref({ x: null, y: null })
// 远端音视频流：userId -> MediaStream（多面试官时每人一路）
const peerStreams = ref({})
// 面试官列表（宫格中每位各占一格）
const interviewers = ref([])
// 面试模式（1-纯AI，2-AI+单面试官，3-AI+多面试官，4-无AI纯人工）
const interviewMode = ref(2)
// 企业端是否正在录制（由面试官通过信令同步，未收到即为未录制）
const recording = ref(false)

const micOn = ref(true)
const camOn = ref(true)
const captionOn = ref(true)
// 是否正在向面试官共享屏幕
const sharing = ref(false)
const netLevel = ref('ok')
const showConfirm = ref(false)
const toast = ref('')
const sessionId = ref(null)
// 面试进度/题面/顶部信息：默认文案用于无后端时演示，接口返回后覆盖
const progress = ref({ current: 3, total: 10 })
const questionText = ref('请结合你在订单中心的经历，说明分布式事务的选型过程，以及最终落地时遇到的补偿与幂等问题是如何解决的？')
const header = ref({ positionTitle: '高级前端工程师', roundNo: 1 })

const seconds = ref(0) // 从进入会议起计时
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

// AI 画中画位置
const aiStyle = computed(() =>
  aiPos.value.x === null ? { right: '16px', bottom: '160px' } : { left: `${aiPos.value.x}px`, top: `${aiPos.value.y}px` }
)
// 面试模式展示文案（1-纯AI，2-AI+单面试官，3-AI+多面试官，4-无AI纯人工）
const modeLabel = computed(() => {
  switch (interviewMode.value) {
    case 1: return '纯 AI 面试'
    case 3: return 'AI + 多面试官'
    case 4: return '纯人工面试'
    default: return 'AI + HR 面试'
  }
})
// 无AI纯人工模式不展示 AI 面板与 AI 出题
const showAiPanel = computed(() => interviewMode.value !== 4)
// 宫格中每位面试官的 <video>：userId -> element，流到达后同步 srcObject
const tileEls = {}
function tileStream(userId) {
  return peerStreams.value[String(userId)] || null
}
function setTileEl(userId, el) {
  const key = String(userId)
  if (el) {
    tileEls[key] = el
    const s = tileStream(userId)
    if (el.srcObject !== s) el.srcObject = s
  } else {
    delete tileEls[key]
  }
}
watch(peerStreams, () => {
  interviewers.value.forEach((p) => {
    const el = tileEls[String(p.userId)]
    const s = tileStream(p.userId)
    if (el && el.srcObject !== s) el.srcObject = s
  })
}, { flush: 'post' })

let videoTrack = null
let audioTrack = null
let screenTrack = null
let timerId = null
let captionId = null
let heartbeatId = null
let captionIndex = 0
let toastTimer = null
let rtc = null

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

// 拖动 AI 画中画，调整其在主画面中的位置
function startDragAi(event) {
  const stage = stageRef.value?.getBoundingClientRect()
  const box = aiRef.value?.getBoundingClientRect()
  if (!stage || !box) return
  const offX = event.clientX - box.left
  const offY = event.clientY - box.top
  const move = (ev) => {
    const nx = ev.clientX - stage.left - offX
    const ny = ev.clientY - stage.top - offY
    aiPos.value = {
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
  // 已有轨道时不重复申请（关闭摄像头只置 enabled，WebRTC sender 依赖轨道持续存在）
  // 优先使用准备页/设置中选定的设备（如外接摄像头），不可用时回退系统默认
  const prefVideo = getPreferredDevice('video')
  const prefAudio = getPreferredDevice('audio')
  const [camResult, micResult] = await Promise.all([
    videoTrack ? Promise.resolve(null) : requestMediaWithFallback('video', prefVideo),
    audioTrack ? Promise.resolve(null) : requestMediaWithFallback('audio', prefAudio)
  ])

  if (videoTrack) {
    videoTrack.enabled = true
    if (selfVideo.value) selfVideo.value.srcObject = new MediaStream([videoTrack])
    camOn.value = true
    if (sessionId.value) updateMedia(sessionId.value, { cameraEnabled: true }).catch(() => {})
  } else if (camResult.error) {
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
  const fellBack =
    (prefVideo && camResult && !camResult.error && camResult.fallback) ||
    (prefAudio && micResult && !micResult.error && micResult.fallback)
  if (fellBack) notify('偏好的设备不可用，已切换到系统默认设备')

  // 汇总提示：两者都失败时只弹一条，避免前一条被覆盖
  const failures = []
  if (camResult?.error) failures.push({ error: camResult.error, kind: 'camera' })
  if (micResult?.error) failures.push({ error: micResult.error, kind: 'microphone' })
  if (failures.length === 1) {
    notify(await describeMediaNotice(failures[0].error, failures[0].kind))
  } else if (failures.length === 2) {
    notify('未获得摄像头与麦克风权限，请在浏览器地址栏允许访问后重新进入面试')
  }
  rtc?.attachLocalTracks(videoTrack, audioTrack)
}

// WebRTC 网状信令连接：拿到场次后建立，各面试官远端流按 userId 分别缓存，主画面按选中项渲染
function startRtc() {
  if (rtc || !sessionId.value) return
  rtc = createConferenceRtc({
    sessionId: sessionId.value,
    onPeerStream: (userId, s) => {
      peerStreams.value = { ...peerStreams.value, [String(userId)]: s }
    },
    onPeerLeft: (userId) => {
      const next = { ...peerStreams.value }
      delete next[String(userId)]
      peerStreams.value = next
    },
    // 面试官广播的录制状态：企业端未开录制时为 false，候选人端据此展示「录制中」标识
    onControl: (type, payload) => {
      if (type === 'recording') recording.value = !!payload.on
    }
  })
  rtc.start()
  // 媒体采集先于信令就绪时补挂本地轨道
  if (videoTrack || audioTrack) rtc.attachLocalTracks(videoTrack, audioTrack)
}

// 应用场次上下文：回填顶部信息、面试官列表与面试模式
function applySessionContext(ctx) {
  if (!ctx) return
  if (ctx.positionTitle) header.value.positionTitle = ctx.positionTitle
  if (ctx.roundNo) header.value.roundNo = ctx.roundNo
  if (ctx.mode) interviewMode.value = Number(ctx.mode)
  interviewers.value = (ctx.interviewers || []).map((it) => ({
    userId: Number(it.userId),
    name: it.userName || '面试官',
    roleLabel: Number(it.isPrimary) === 1 ? '主面试官' : '面试官'
  }))
}

// 重新拉取场次上下文（面试官列表可能变化）
async function refreshContext() {
  if (!sessionId.value) return
  try {
    const res = await getSessionContext(sessionId.value)
    applySessionContext(res.data)
  } catch (e) {
    // 忽略
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

// 屏幕共享：把发往面试官的视频轨临时替换为屏幕轨（音频轨保持不变），
// 停止共享或用户在系统弹窗点「停止共享」时再换回摄像头画面
async function toggleShare() {
  if (sharing.value) {
    stopShare()
    return
  }
  if (!navigator.mediaDevices?.getDisplayMedia) {
    notify('当前浏览器不支持屏幕共享')
    return
  }
  let result = null
  try {
    result = await navigator.mediaDevices.getDisplayMedia({ video: true })
  } catch (error) {
    // 用户取消选择共享内容不算错误，不弹提示
    if (error && error.name !== 'NotAllowedError') notify('屏幕共享未开启')
    return
  }
  screenTrack = result.getVideoTracks()[0] || null
  if (!screenTrack) return
  sharing.value = true
  rtc?.attachLocalTracks(screenTrack, audioTrack)
  // 用户通过浏览器自带的「停止共享」按钮结束时要同步收尾
  screenTrack.onended = stopShare
  notify('已开始共享屏幕')
}

function stopShare() {
  if (!sharing.value && !screenTrack) return
  sharing.value = false
  if (screenTrack) {
    screenTrack.onended = null
    screenTrack.stop()
    screenTrack = null
  }
  // 恢复发送摄像头画面；摄像头已关闭时移除视频轨，避免对端停留在最后一帧
  if (videoTrack) rtc?.attachLocalTracks(videoTrack, audioTrack)
  else rtc?.attachLocalTracks(null, audioTrack)
  notify('已停止共享屏幕')
}

async function endMeeting() {
  showConfirm.value = false
  stopShare()
  closeCamera()
  if (sessionId.value) {
    try {
      await finishSession(sessionId.value, 'normal')
    } catch (error) {
      // 结束接口失败不阻塞跳转
    }
  }
  rtc?.destroy()
  rtc = null
  window.__agentNavigate('/agent/conference-ended')
}

function scrollCaptions() {
  nextTick(() => {
    const node = capListRef.value
    if (node) node.scrollTop = node.scrollHeight
  })
}

// 会议设置：真实切换摄像头/麦克风（外接设备即在此选择）
const showSettings = ref(false)
const cameraDevices = ref([])
const microphoneDevices = ref([])
const setCamId = ref('')
const setMicId = ref('')

async function openSettings() {
  cameraDevices.value = await listMediaDevices('video')
  microphoneDevices.value = await listMediaDevices('audio')
  setCamId.value = (videoTrack && videoTrack.getSettings().deviceId) || getPreferredDevice('video')
  setMicId.value = (audioTrack && audioTrack.getSettings().deviceId) || getPreferredDevice('audio')
  showSettings.value = true
}

// 切换设备：先采集新设备、成功后再停旧轨道。
// 下拉切换的一定是另一台物理设备，两者可短暂共存；而「先停旧轨道再开新设备」
// 在 Windows 上常因硬件尚未完全释放而失败，且失败后连原画面都会一起丢掉。
async function applyDevice(kind) {
  const isVideo = kind === 'video'
  const deviceId = isVideo ? setCamId.value : setMicId.value
  const oldTrack = isVideo ? videoTrack : audioTrack
  if (!oldTrack) {
    // 摄像头已关闭时只记录偏好，下次开启时生效
    if (deviceId) savePreferredDevice(kind, deviceId)
    else clearPreferredDevice(kind)
    notify('已保存设备偏好，下次开启时生效')
    return
  }
  const res = await requestMedia({ [kind]: deviceId ? { deviceId: { exact: deviceId } } : true })
    .then((stream) => ({ stream }))
    .catch((error) => ({ error }))
  const newTrack = res.stream ? (isVideo ? res.stream.getVideoTracks()[0] : res.stream.getAudioTracks()[0]) : null
  if (!newTrack) {
    // 采集失败：保留原设备与画面，只提示原因
    notify(await describeMediaNotice(res.error, isVideo ? 'camera' : 'microphone'))
    return
  }
  // 新设备就绪后再写偏好并释放旧轨道
  if (deviceId) savePreferredDevice(kind, deviceId)
  else clearPreferredDevice(kind)
  oldTrack.stop()
  if (isVideo) {
    videoTrack = newTrack
    videoTrack.enabled = camOn.value
    if (selfVideo.value) selfVideo.value.srcObject = new MediaStream([videoTrack])
    setCamId.value = videoTrack.getSettings().deviceId || deviceId
  } else {
    audioTrack = newTrack
    audioTrack.enabled = micOn.value
    setMicId.value = audioTrack.getSettings().deviceId || deviceId
  }
  rtc?.attachLocalTracks(videoTrack, audioTrack)
  notify('已切换设备')
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
  // 优先使用 URL 携带的 sessionId（等候室跳转时传入），与 HR 端保持同一场次；
  // 服务端反查的「当前场次」在多活跃场次环境下可能与对端解析结果不一致，仅作兜底
  const urlSessionId = route.query.sessionId
  if (urlSessionId) {
    sessionId.value = urlSessionId
    startRtc()
  } else {
    try {
      const res = await getCurrentSession()
      if (res.data && res.data.sessionId) {
        sessionId.value = res.data.sessionId
        startRtc()
      }
    } catch (error) {
      // 无后端时保留本地演示
    }
  }
  if (!sessionId.value) return
  // 拉取场次上下文：顶部信息 / 面试官列表 / 面试模式
  await refreshContext()
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
  if (screenTrack) {
    screenTrack.onended = null
    screenTrack.stop()
    screenTrack = null
  }
  rtc?.destroy()
  rtc = null
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

/* 面试官宫格：多位面试官画面并排占据主区；格子保持 16:9 并整体垂直居中，避免出现大面积黑边 */
.ca-grid { position: absolute; inset: 0; padding: 8px; display: grid; gap: 8px; align-content: center; }
.ca-grid.g1 { grid-template-columns: 1fr; }
.ca-grid.g2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
.ca-grid.g3 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
.ca-grid.g4 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
.ca-grid.g5, .ca-grid.g6 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
/* contain：完整显示画面不裁切（cover 会把摄像头画面放大裁掉边缘） */
.ca-tile { position: relative; min-width: 0; aspect-ratio: 16 / 9; border-radius: 12px; overflow: hidden; background: #05070c; border: 1px solid var(--line); }
.ca-tile-video { width: 100%; height: 100%; object-fit: contain; display: block; background: #05070c; }
.ca-tile-waiting { position: absolute; inset: 0; display: grid; place-content: center; justify-items: center; gap: 10px; color: #6E7C90; font-size: 13px; }
.ca-tile-waiting svg { color: #4A5768; }
.ca-grid-empty { grid-column: 1 / -1; display: grid; place-content: center; justify-items: center; gap: 10px; color: #6E7C90; font-size: 13px; }
.ca-grid-empty svg { color: #4A5768; }
.ca-tile-tag { position: absolute; left: 10px; bottom: 8px; display: inline-flex; align-items: center; gap: 6px; height: 24px; padding: 0 10px; border-radius: 999px; background: rgba(6, 9, 14, .62); backdrop-filter: blur(6px); color: #fff; font-size: 12px; }
.ca-tile-tag i { width: 7px; height: 7px; border-radius: 50%; background: var(--ok); }

/* AI 画中画：无AI 纯人工模式隐藏 */
.ca-ai-pip { position: absolute; width: 150px; padding: 12px; border-radius: 12px; background: rgba(12, 17, 26, .74); border: 1px solid var(--line); backdrop-filter: blur(8px); text-align: center; cursor: move; }
.ca-ai-pip .ca-orb { width: 84px; height: 84px; }
.ca-ai-pip .ca-orb-core { width: 58px; height: 58px; font-size: 15px; }
.ca-ai-pip .ca-orb-core::after { width: 58px; height: 58px; }
.ca-ai-pip .ca-ring { inset: 6px; }
.ca-ai-pip-meta { margin-top: 8px; }
.ca-ai-pip-meta b { display: block; font-size: 12px; }
.ca-ai-pip-meta small { display: block; margin-top: 2px; color: #8394AC; font-size: 11px; }
.ca-orb { position: relative; width: 136px; height: 136px; margin: 0 auto; display: grid; place-items: center; }
.ca-orb-core { width: 96px; height: 96px; display: grid; place-items: center; border-radius: 50%; color: #fff; font-size: 24px; font-weight: 800; letter-spacing: 1px; background: linear-gradient(150deg, #2B7FFF, #1A3C6E); box-shadow: 0 0 40px rgba(43, 127, 255, .55); }
.ca-orb-core::after { content: ''; position: absolute; width: 96px; height: 96px; border-radius: 50%; background: linear-gradient(150deg, rgba(43, 127, 255, .5), transparent 70%); animation: ca-spin 6s linear infinite; }
@keyframes ca-spin { to { transform: rotate(360deg); } }
.ca-ring { position: absolute; inset: 8px; border-radius: 50%; border: 1px solid rgba(43, 127, 255, .5); animation: ca-pulse 2.6s ease-out infinite; }
.ca-ring.delay { animation-delay: 1.3s; }
@keyframes ca-pulse { 0% { transform: scale(.86); opacity: .85; } 100% { transform: scale(1.28); opacity: 0; } }

/* 当前题目：右上角浮动，避开左侧面试官列表 */
.ca-question { position: absolute; right: 18px; top: 16px; width: min(520px, 56%); padding: 14px 16px; border-radius: 12px; background: rgba(12, 17, 26, .72); border: 1px solid var(--line); backdrop-filter: blur(8px); }
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
.ca-share-tip { position: absolute; left: 50%; top: 12px; transform: translateX(-50%); z-index: 6; display: inline-flex; align-items: center; gap: 6px; height: 26px; padding: 0 11px; border-radius: 999px; background: rgba(43, 127, 255, .92); color: #fff; font-size: 12px; }

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

.ca-set-field { margin-top: 14px; display: grid; gap: 6px; }
.ca-set-field label { font-size: 12px; color: #97A5BB; }
.ca-set-field select {
  height: 36px; padding: 0 10px; border-radius: 9px;
  border: 1px solid var(--line); background: #12151C; color: #EDF1F7;
  font-size: 13px; font-family: inherit; outline: none;
}
.ca-set-field select:focus { border-color: var(--b); }

@media (max-width: 900px) {
  .ca-question { right: 14px; width: 68%; top: 14px; }
  .ca-q-text { font-size: 13px; }
  .ca-self { width: 120px; height: 68px; }
  .ca-ai-pip { width: 128px; padding: 10px; }
}
</style>