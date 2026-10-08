<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  ArrowLeft, ChevronLeft, ChevronRight, FileText, Sparkles, Timer, Mic, MicOff,
  Video, MonitorUp, Copy, MessageSquareText, Settings, PhoneOff, CircleCheck,
  CircleX, Pencil, ArrowUpRight, AlertTriangle, GripVertical, Lightbulb, X
} from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { getCurrentSession, getProgress, listCaptions, heartbeat, handleCopilot, finishSession } from '@/api/system/conference'
import { clearPreferredDevice, describeMediaNotice, getPreferredDevice, listMediaDevices, requestMedia, requestMediaWithFallback, savePreferredDevice } from '@/utils/media'
import { createConferenceRtc } from '@/utils/webrtc'

const router = useRouter()

const leftOpen = ref(true)
const rightOpen = ref(true)
const selfVisible = ref(true)
const selfRef = ref(null)
const selfVideo = ref(null)
const peerVideo = ref(null)
const frameRef = ref(null)
const selfPos = ref({ x: null, y: null })
const toast = ref('')
// 候选人远端音视频流（WebRTC 到达后渲染到主画面）
const peerStream = ref(null)
// 设备申请失败的原因；非空时小窗展示「重新检测」入口
const mediaError = ref('')
// 结束会议二次确认
const showExitConfirm = ref(false)

const MIC_ON = ref(true)
const CAM_ON = ref(true)
const SHARING = ref(false)
const RECORDING = ref(true)
const PIP = ref(false)
const CAPTION_ON = ref(true)
const quality = ref('hd') // hd | smooth

// 进入会议后从 00:00 开始计时
const seconds = ref(0)
const clock = computed(() => fmtClock(seconds.value))

// 本机到服务器的实测时延（ms），未测到时为 null
const rtt = ref(null)
// 延迟分级：150ms 内良好、400ms 内波动、更高较差
const netLevel = computed(() => {
  const v = rtt.value
  if (v == null || v < 150) return 'ok'
  return v < 400 ? 'warn' : 'bad'
})

const progress = ref({ done: 3, total: 10, remain: '32:15' })

const tips = ref([
  { id: 1, text: '请说明你负责的系统中，分布式事务是如何选型与落地的？', adopted: false }
])

const captions = ref([
  { who: 'HR', text: '我们接着上一个项目聊，你在订单中心里为什么最终选择了 TCC 而不是 XA？' },
  { who: '候选人', text: 'XA 在跨库场景下锁持有时间过长，高峰期会出现连接池打满，所以选了 TCC。' },
  { who: 'AI', text: '已识别关键词：分布式事务 / TCC / 连接池；建议追问补偿与幂等设计。' }
])
const captionPool = [
  { who: '候选人', text: '我们把每个分支事务都做成幂等的，靠业务唯一号去重。' },
  { who: 'HR', text: '那如果补偿阶段也失败了，你们怎么保证最终一致？' },
  { who: 'AI', text: '建议关注点：补偿重试策略、悬挂与空回滚的处理。' }
]

const acceptedPoints = [
  '说明 TCC 的 Try / Confirm / Cancel 三阶段职责边界',
  '结合业务唯一号说明幂等与防悬挂的实现方式',
  '给出线上踩坑案例并量化影响范围'
]

const selfStyle = computed(() =>
  selfPos.value.x === null
    ? { right: '14px', bottom: '14px' }
    : { left: `${selfPos.value.x}px`, top: `${selfPos.value.y}px` }
)

let timerId = null
let captionId = null
let captionIndex = 0
let heartbeatId = null
let rttId = null
let stream = null
let videoTrack = null
let audioTrack = null
let localVideoStream = null
let rtc = null

// 当前进行中的面试场次（无后端数据时为 null，页面继续用 mock 演示）
const sessionId = ref(null)
// 候选人信息与面试官姓名：进入场次后由接口回填，未取到时保留演示值
const candidate = ref({ name: '王芳', position: '高级前端工程师' })
const interviewerName = ref('林晓雯')

function notify(msg) {
  toast.value = msg
  setTimeout(() => (toast.value = ''), 2000)
}

function fmtClock(total) {
  const v = Math.max(0, Math.floor(total || 0))
  const m = String(Math.floor(v / 60)).padStart(2, '0')
  const s = String(v % 60).padStart(2, '0')
  return `${m}:${s}`
}

function startDrag(event) {
  const frame = frameRef.value?.getBoundingClientRect()
  const box = selfRef.value?.getBoundingClientRect()
  if (!frame || !box) return
  const offX = event.clientX - box.left
  const offY = event.clientY - box.top
  const move = (ev) => {
    const nx = ev.clientX - frame.left - offX
    const ny = ev.clientY - frame.top - offY
    // 边距与未拖拽时的 right/bottom 14px 保持一致，避免拖前拖后边距不等
    selfPos.value = {
      x: Math.max(14, Math.min(frame.width - box.width - 14, nx)),
      y: Math.max(14, Math.min(frame.height - box.height - 14, ny))
    }
  }
  const up = () => {
    document.removeEventListener('mousemove', move)
    document.removeEventListener('mouseup', up)
  }
  document.addEventListener('mousemove', move)
  document.addEventListener('mouseup', up)
}

// 接入本机摄像头与麦克风：HR 自己的小窗绑定真实画面
// 摄像头与麦克风分开申请，任一失败不影响另一项；失败原因写入 mediaError 供 UI 展示
async function openMedia() {
  if (!navigator.mediaDevices?.getUserMedia) {
    releaseMedia()
    CAM_ON.value = false
    MIC_ON.value = false
    mediaError.value = '当前浏览器不支持摄像头访问，请改用 localhost:10081 或 127.0.0.1:10081 打开'
    notify(mediaError.value)
    return
  }
  // 重试前先释放上一轮残留，避免同一设备仍被自己占用导致再次失败
  releaseMedia()

  // 优先使用上次选定的设备（如外接摄像头），不可用时回退系统默认
  const [camResult, micResult] = await Promise.all([
    requestMediaWithFallback('video', getPreferredDevice('video')),
    requestMediaWithFallback('audio', getPreferredDevice('audio'))
  ])

  videoTrack = camResult.error ? null : (camResult.stream.getVideoTracks()[0] || null)
  audioTrack = micResult.error ? null : (micResult.stream.getAudioTracks()[0] || null)
  localVideoStream = videoTrack ? new MediaStream([videoTrack]) : null
  const tracks = [...(videoTrack ? [videoTrack] : []), ...(audioTrack ? [audioTrack] : [])]
  stream = tracks.length ? new MediaStream(tracks) : null

  // 开关状态与真实轨道保持一致，避免「显示已开启但没有画面/没有声音」
  CAM_ON.value = !!videoTrack
  MIC_ON.value = !!audioTrack
  if (audioTrack) audioTrack.enabled = true
  if (selfVideo.value) selfVideo.value.srcObject = localVideoStream

  // 汇总提示：两者都失败时只弹一条，避免前一条被覆盖
  const failures = []
  if (camResult.error) failures.push({ error: camResult.error, kind: 'camera' })
  if (micResult.error) failures.push({ error: micResult.error, kind: 'microphone' })
  if (failures.length === 1) {
    mediaError.value = await describeMediaNotice(failures[0].error, failures[0].kind)
  } else if (failures.length === 2) {
    mediaError.value = '未获得摄像头与麦克风权限，请在浏览器地址栏允许访问后重新检测'
  } else {
    mediaError.value = ''
  }
  if (mediaError.value) notify(mediaError.value)
  rtc?.attachLocalTracks(videoTrack, audioTrack)
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
    // 采集未开启时只记录偏好，下次开启时生效
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
    videoTrack.enabled = CAM_ON.value
    localVideoStream = new MediaStream([videoTrack])
    if (selfVideo.value) selfVideo.value.srcObject = localVideoStream
    setCamId.value = videoTrack.getSettings().deviceId || deviceId
  } else {
    audioTrack = newTrack
    audioTrack.enabled = MIC_ON.value
    setMicId.value = audioTrack.getSettings().deviceId || deviceId
  }
  // 同步重建合并流，确保 releaseMedia 能停止新轨道（旧轨道已 stop，重复 stop 无副作用）
  stream = rebuildLocalStream()

  rtc?.attachLocalTracks(videoTrack, audioTrack)
  notify('已切换设备')
}

// 合并当前启用的轨道为一条本地流，供 releaseMedia 统一释放
function rebuildLocalStream() {
  const tracks = [...(videoTrack ? [videoTrack] : []), ...(audioTrack ? [audioTrack] : [])]
  return tracks.length ? new MediaStream(tracks) : null
}

// WebRTC 信令连接：拿到场次后建立，候选人远端流到达后渲染到主画面
function startRtc() {
  if (rtc || !sessionId.value) return
  rtc = createConferenceRtc({
    sessionId: sessionId.value,
    onPeerStream: (s) => {
      peerStream.value = s
      nextTick(() => {
        if (peerVideo.value) peerVideo.value.srcObject = s
      })
    },
    onPeerLeft: () => {
      peerStream.value = null
      if (peerVideo.value) peerVideo.value.srcObject = null
    }
  })
  rtc.start()
  // 媒体采集先于信令就绪时补挂本地轨道
  if (videoTrack || audioTrack) rtc.attachLocalTracks(videoTrack, audioTrack)
}

function toggleMic() {
  // 设备未就绪时，点击按钮即重试申请
  if (!audioTrack) {
    openMedia()
    return
  }
  MIC_ON.value = !MIC_ON.value
  audioTrack.enabled = MIC_ON.value
  notify(MIC_ON.value ? '麦克风已开启' : '麦克风已静音')
}

async function toggleCam() {
  // 设备未就绪时，点击按钮即重试申请
  if (!videoTrack) {
    await openMedia()
    return
  }
  CAM_ON.value = !CAM_ON.value
  videoTrack.enabled = CAM_ON.value
  notify(CAM_ON.value ? '摄像头已开启' : '摄像头已关闭')
}

function releaseMedia() {
  rtc?.detachLocalTracks()
  stream?.getTracks().forEach((track) => track.stop())
  stream = null
  videoTrack = null
  audioTrack = null
  localVideoStream = null
  if (selfVideo.value) selfVideo.value.srcObject = null
}

// 小窗隐藏后重新显示时 video 元素会被重建，需重新绑定画面
watch(selfVisible, (visible) => {
  if (visible && selfVideo.value) selfVideo.value.srcObject = localVideoStream
}, { flush: 'post' })

function toggleQuality() {
  if (quality.value === 'hd') {
    quality.value = 'smooth'
    notify('网络波动，已自动降低画质至「流畅」')
  } else {
    quality.value = 'hd'
    notify('网络已恢复，画质恢复至「高清」')
  }
}

function toggleRecord() {
  RECORDING.value = !RECORDING.value
  notify(RECORDING.value ? '已开始录制' : '已暂停录制')
}

// 结束后端场次并离开会议页。
// 结束接口不阻塞离开：接口异常时若卡在此处，又会变成「退不出去」。
function endSessionAndLeave() {
  if (sessionId.value) {
    finishSession(sessionId.value, 'normal').catch(() => {})
  }
  rtc?.destroy()
  rtc = null
  releaseMedia()
  router.push('/enterprise/messages')
}

// 顶栏「退出」：直接结束并离开
function leaveNow() {
  endSessionAndLeave()
}

// 底部「结束会议」：二次确认后结束并离开
function confirmLeave() {
  showExitConfirm.value = false
  endSessionAndLeave()
}

function adoptTip() {
  tips.value[0].adopted = true
  notify('建议问题已采纳，将同步至面试官提词器')
  if (sessionId.value && typeof tips.value[0].id === 'number') {
    handleCopilot(sessionId.value, tips.value[0].id, { action: 'adopt' }).catch(() => {})
  }
}

function ignoreTip() {
  tips.value[0].adopted = false
  notify('已忽略该建议问题')
  if (sessionId.value && typeof tips.value[0].id === 'number') {
    handleCopilot(sessionId.value, tips.value[0].id, { action: 'ignore' }).catch(() => {})
  }
}

// 实时延迟探测：每次重新测一次同后端请求的往返时延，数值随网络波动变化。
// 用裸 fetch 而非 axios —— 绕开全局拦截器（避免每 2 秒弹一次错误提示），
// 且不依赖面试场次，因此没有场次时同样能测出延迟。
// 浏览器估算值（navigator.connection.rtt）在桌面端是固定分级值、不会波动，
// 只作为请求失败时的兜底。
async function refreshRtt() {
  const started = performance.now()
  try {
    const res = await fetch(`${import.meta.env.VITE_APP_BASE_API}/`, { method: 'GET', cache: 'no-store' })
    // 必须读掉响应体，否则 Chrome 会在流被回收时中断连接并报 net::ERR_ABORTED
    await res.text()
    rtt.value = Math.round(performance.now() - started)
  } catch (e) {
    const estimated = navigator.connection?.rtt
    rtt.value = estimated > 0 ? estimated : null
  }
}

// 拉取当前场次并同步进度、字幕；后端不可用时静默保留 mock
async function initSession() {
  try {
    const s = await getCurrentSession()
    if (!s.data || !s.data.sessionId) return
    sessionId.value = s.data.sessionId
    startRtc()
    // 回填候选人 / 面试官信息，替换页面上的演示值
    if (s.data.candidateName) candidate.value.name = s.data.candidateName
    if (s.data.positionTitle) candidate.value.position = s.data.positionTitle
    if (s.data.interviewerName) interviewerName.value = s.data.interviewerName

    const p = await getProgress(sessionId.value)
    if (p.data) {
      progress.value.total = p.data.totalQuestionNo || progress.value.total
      progress.value.done = p.data.answeredCount ?? progress.value.done
      if (p.data.remainingSeconds != null) progress.value.remain = fmtClock(p.data.remainingSeconds)
      if (p.data.question && p.data.question.topic) tips.value[0].text = p.data.question.topic
    }

    const c = await listCaptions(sessionId.value, { afterSequence: 0, limit: 50 })
    if (Array.isArray(c.data) && c.data.length > 0) {
      captions.value = c.data.slice(-12).map((item) => ({
        who: item.role === 1 ? 'AI' : item.role === 2 ? 'HR' : '候选人',
        text: item.content
      }))
      // 已有真实字幕，停掉本地模拟字幕，避免与 mock 混播
      clearInterval(captionId)
      captionId = null
    }

    // 心跳保活：仅在确认存在真实场次后才需要
    heartbeatId = setInterval(() => heartbeat(sessionId.value).catch(() => {}), 15000)
  } catch (e) {
    // 本地未启动后端 / 无种子数据时保留 mock 演示
  }
}

onMounted(() => {
  openMedia()
  timerId = setInterval(() => (seconds.value += 1), 1000)
  captionId = setInterval(() => {
    const next = captionPool[captionIndex % captionPool.length]
    captionIndex += 1
    captions.value.push(next)
    if (captions.value.length > 12) captions.value.shift()
  }, 7000)
  // 延迟探测与场次无关，独立启动，避免被 initSession 的异常吞掉
  refreshRtt()
  rttId = setInterval(refreshRtt, 2000)
  initSession()
})

onBeforeUnmount(() => {
  clearInterval(timerId)
  clearInterval(captionId)
  clearInterval(heartbeatId)
  clearInterval(rttId)
  rtc?.destroy()
  rtc = null
  releaseMedia()
})
</script>

<template>
  <div class="conf-page" :class="{ 'left-off': !leftOpen }">
    <header class="topbar">
      <div class="tb-left">
        <button class="tb-exit" @click="leaveNow"><ArrowLeft :size="15" />退出</button>
        <button class="tb-icon" :title="leftOpen ? '收起候选人信息' : '展开候选人信息'" @click="leftOpen = !leftOpen">
          <ChevronLeft v-if="leftOpen" :size="17" />
          <ChevronRight v-else :size="17" />
        </button>
        <div class="tb-title">
          <strong>高级前端工程师</strong>
          <span class="chip">第 1 轮 / 共 2 轮</span>
          <span class="chip mode"><Sparkles :size="12" />AI + HR 协同</span>
        </div>
      </div>
      <div class="tb-right">
        <button class="tb-icon" :title="rightOpen ? '收起协同面板' : '展开协同面板'" @click="rightOpen = !rightOpen">
          <ChevronRight v-if="rightOpen" :size="17" />
          <ChevronLeft v-else :size="17" />
        </button>
        <span class="timer"><Timer :size="14" />{{ clock }}</span>
        <span class="net" :class="netLevel"><i />{{ rtt == null ? '延迟 --' : `延迟 ${rtt}ms` }}</span>
        <span v-if="RECORDING" class="rec"><i />录制中</span>
      </div>
    </header>

    <div class="body">
      <aside v-show="leftOpen" class="left">
        <div class="cand">
          <div class="cand-avatar-wrap">
            <img class="cand-avatar" src="https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=200&q=80" alt="候选人头像" />
            <i class="cand-online" title="在线" />
          </div>
          <div>
            <strong>{{ candidate.name }}</strong>
            <p>{{ candidate.position }}</p>
          </div>
        </div>

        <div class="info-row"><span>应聘岗位</span><b>{{ candidate.position }}</b></div>
        <div class="info-row"><span>当前阶段</span><b>专业技术面</b></div>
        <div class="info-row"><span>面试模式</span><b>AI + HR 协同</b></div>

        <button class="resume" @click="notify('已打开候选人简历详情')">
          <FileText :size="16" />查看候选人简历<ArrowUpRight :size="15" />
        </button>

        <h3 class="panel-title">流程时间线</h3>
        <ol class="timeline">
          <li class="done"><i /><div><b>简历筛选</b><small>05-28 已通过</small></div></li>
          <li class="done"><i /><div><b>笔试测评</b><small>06-03 得分 88</small></div></li>
          <li class="active"><i /><div><b>专业技术面（第 1 轮）</b><small>进行中 · {{ clock }}</small></div></li>
          <li><i /><div><b>综合面（第 2 轮）</b><small>待安排</small></div></li>
          <li><i /><div><b>Offer 沟通</b><small>未开始</small></div></li>
        </ol>
      </aside>

      <section class="stage">
        <div ref="frameRef" class="main-video">
          <video v-show="peerStream" ref="peerVideo" class="peer-video" autoplay playsinline />
          <div v-if="!peerStream" class="peer-waiting"><Video :size="26" /><span>等待候选人画面…</span></div>

          <span class="tag-main"><i />候选人 · {{ candidate.name }}</span>
          <div class="tag-right">
            <span class="tag-quality" :class="quality" @click="toggleQuality">
              {{ quality === 'hd' ? '高清 1080P' : '流畅 480P' }}
            </span>
            <span v-if="RECORDING" class="tag-rec"><i />录制中</span>
          </div>

          <div
            v-if="!selfVisible"
            class="self-restore"
            @click="selfVisible = true"
          >
            <Video :size="15" />显示我的画面
          </div>

          <div
            v-else
            ref="selfRef"
            class="self-win"
            :style="selfStyle"
            @mousedown.prevent="startDrag"
          >
            <video v-show="CAM_ON" ref="selfVideo" autoplay playsinline muted />
            <div v-if="!CAM_ON" class="self-fallback">
              <Video :size="16" />
              <span>{{ mediaError ? '设备未就绪' : '摄像头已关闭' }}</span>
              <button v-if="mediaError" class="self-retry" @mousedown.stop @click.stop="openMedia">重新检测</button>
            </div>
            <span class="self-name"><GripVertical :size="11" />我 · {{ interviewerName }}</span>
            <button class="self-hide" title="隐藏我的画面" @mousedown.stop @click.stop="selfVisible = false">
              <X :size="13" />
            </button>
          </div>

          <div v-if="quality === 'smooth'" class="net-warning">
            <AlertTriangle :size="14" />网络不佳，已自动降低画质以保持通话稳定
          </div>
        </div>
      </section>

      <aside v-show="rightOpen" class="right">
        <div class="right-head">
          <h2>AI 实时协同</h2>
        </div>

        <div class="progress-card">
          <div class="progress-top">
            <span>面试进度</span>
            <b>{{ progress.done }}/{{ progress.total }}</b>
          </div>
          <div class="bar"><u :style="{ width: progress.done / progress.total * 100 + '%' }" /></div>
          <div class="progress-bottom">
            <span>剩余时间</span>
            <b>{{ progress.remain }}</b>
          </div>
        </div>

        <section class="block">
          <h3>岗位摘要</h3>
          <p class="summary">负责企业级中后台前端架构设计，主导性能优化与组件体系建设，需具备复杂状态管理与跨端项目经验。</p>
          <div class="chips">
            <span>Vue 3</span><span>TypeScript</span><span>性能优化</span><span>组件库</span>
          </div>
        </section>

        <section class="block">
          <h3><Sparkles :size="14" />实时提词器</h3>
          <div v-for="tip in tips" :key="tip.id" class="tip" :class="{ adopted: tip.adopted }">
            <p>{{ tip.text }}</p>
            <div class="tip-actions">
              <button class="ok" @click="adoptTip"><CircleCheck :size="14" />采纳</button>
              <button @click="notify('进入建议问题编辑')"><Pencil :size="13" />编辑</button>
              <button class="no" @click="ignoreTip"><CircleX :size="14" />忽略</button>
            </div>
          </div>
        </section>

        <section class="block">
          <h3><Lightbulb :size="14" />参考答案 / 评分要点</h3>
          <ol class="points">
            <li><b>① 分布式事务</b>：能区分 2PC / XA 与柔性事务的适用边界</li>
            <li><b>② TCC / Saga</b>：说清 Try-Confirm-Cancel 与补偿链路的差异与取舍</li>
            <li><b>③ 落地踩坑</b>：结合幂等、防悬挂、空回滚给出真实线上案例</li>
          </ol>
        </section>

        <section class="block captions">
          <h3><MessageSquareText :size="14" />实时字幕</h3>
          <div class="caption-list">
            <div v-for="(item, index) in captions" :key="index" class="caption" :class="{ ai: item.who === 'AI' }">
              <span>{{ item.who }}</span>
              <p>{{ item.text }}</p>
            </div>
          </div>
        </section>
      </aside>
    </div>

    <footer class="controls">
      <button class="ctl" :class="{ off: !MIC_ON }" @click="toggleMic">
        <MicOff v-if="!MIC_ON" :size="20" /><Mic v-else :size="20" /><span>麦克风</span>
      </button>
      <button class="ctl" :class="{ off: !CAM_ON }" @click="toggleCam">
        <Video :size="20" /><span>摄像头</span>
      </button>
      <button class="ctl disabled" title="当前角色无屏幕共享权限" disabled>
        <MonitorUp :size="20" /><span>屏幕共享</span>
      </button>
      <button class="ctl rec-btn" :class="{ on: RECORDING }" @click="toggleRecord">
        <span class="dot-icon" /><span>录制</span>
      </button>
      <button class="ctl" :class="{ on: PIP }" @click="PIP = !PIP">
        <Copy :size="20" /><span>画中画</span>
      </button>
      <button class="ctl" :class="{ on: CAPTION_ON }" @click="CAPTION_ON = !CAPTION_ON">
        <MessageSquareText :size="20" /><span>字幕</span>
      </button>
      <button class="ctl" @click="openSettings">
        <Settings :size="20" /><span>设置</span>
      </button>
      <button class="ctl hang" @click="showExitConfirm = true">
        <PhoneOff :size="20" /><span>结束会议</span>
      </button>
    </footer>

    <div v-if="showExitConfirm" class="conf-mask" @click.self="showExitConfirm = false">
      <section class="conf-modal">
        <h3>确认结束本次面试？</h3>
        <p>结束后将离开会议页面，剩余题目会被记为未完成，并进入评估报告生成流程。</p>
        <div class="conf-modal-actions">
          <button class="conf-cancel" @click="showExitConfirm = false">取消</button>
          <button class="conf-confirm" @click="confirmLeave">确认结束</button>
        </div>
      </section>
    </div>

    <div v-if="showSettings" class="conf-mask" @click.self="showSettings = false">
      <section class="conf-modal">
        <h3>会议设置</h3>
        <p>切换采集设备后画面与声音立即生效（如使用外接摄像头，请在列表中选择对应设备）。</p>
        <div class="set-field">
          <label>摄像头</label>
          <select v-model="setCamId" @change="applyDevice('video')">
            <option value="">系统默认</option>
            <option v-for="item in cameraDevices" :key="item.deviceId" :value="item.deviceId">{{ item.label }}</option>
          </select>
        </div>
        <div class="set-field">
          <label>麦克风</label>
          <select v-model="setMicId" @change="applyDevice('audio')">
            <option value="">系统默认</option>
            <option v-for="item in microphoneDevices" :key="item.deviceId" :value="item.deviceId">{{ item.label }}</option>
          </select>
        </div>
        <div class="conf-modal-actions">
          <button class="conf-cancel" @click="showSettings = false">完成</button>
        </div>
      </section>
    </div>

    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.conf-page {
  --primary: #2563eb;
  --primary-strong: #1d4ed8;
  --primary-soft: rgba(37, 99, 235, .16);
  --rec: #ff4d4f;
  --ok: #52c41a;
  --warn: #faad14;
  --bg: #0f131c;
  --panel: #171d29;
  --panel-2: #1e2534;
  --line: rgba(255, 255, 255, .08);
  --line-strong: rgba(255, 255, 255, .16);
  --text: #e9eef7;
  --muted: #8a97ac;
  --subtle: #5f6c80;
  position: fixed;
  inset: 0;
  display: flex;
  flex-direction: column;
  background: var(--bg);
  color: var(--text);
  font-family: 'DM Sans', 'Noto Sans SC', 'Microsoft YaHei', sans-serif;
  font-size: 14px;
}
.conf-page * { box-sizing: border-box; }
.conf-page button { font: inherit; cursor: pointer; }

/* 顶部栏 */
.topbar {
  height: 56px;
  flex: none;
  padding: 0 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: var(--panel);
  border-bottom: 1px solid var(--line);
}
.tb-left, .tb-right { display: flex; align-items: center; gap: 12px; }
.tb-icon {
  width: 32px; height: 32px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: transparent;
  color: var(--muted);
  display: grid; place-items: center;
}
.tb-icon:hover { color: var(--text); border-color: var(--line-strong); }
.tb-exit {
  height: 32px; padding: 0 12px;
  display: inline-flex; align-items: center; gap: 6px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: transparent;
  color: var(--muted);
  font-size: 13px;
}
.tb-exit:hover { color: var(--text); border-color: var(--line-strong); }
.tb-title { display: flex; align-items: center; gap: 10px; }
.tb-title strong { font-size: 16px; letter-spacing: .2px; }
.chip {
  height: 22px; padding: 0 9px;
  display: inline-flex; align-items: center; gap: 5px;
  border-radius: 999px;
  background: var(--panel-2);
  color: var(--muted);
  font-size: 12px;
}
.chip.mode { color: #93b4ff; background: var(--primary-soft); }
.timer {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 0 11px; height: 28px;
  border-radius: 8px;
  background: var(--panel-2);
  font-variant-numeric: tabular-nums;
  font-weight: 600;
}
.net, .rec {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 12px; color: var(--muted);
}
.net i, .rec i { width: 7px; height: 7px; border-radius: 50%; background: currentColor; }
.net { color: var(--ok); }
.net.warn { color: var(--warn); }
.net.bad { color: var(--rec); }
.rec { color: var(--rec); }
.rec i { animation: blink 1.1s infinite; }
@keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: .18; } }

/* 主体三栏 */
.body { flex: 1; min-height: 0; display: flex; gap: 12px; padding: 12px; }
.left {
  width: 264px; flex: none;
  padding: 16px;
  border-radius: 14px;
  background: var(--panel);
  border: 1px solid var(--line);
  overflow: auto;
}
.right {
  width: 320px; flex: none;
  padding: 14px;
  border-radius: 14px;
  background: var(--panel);
  border: 1px solid var(--line);
  display: flex; flex-direction: column;
  overflow: auto;
}
.stage { flex: 1; min-width: 0; display: flex; align-items: center; justify-content: center; }

/* 左侧信息栏 */
.cand { display: flex; align-items: center; gap: 10px; padding-bottom: 16px; border-bottom: 1px solid var(--line); }
/* 头像容器用于承载右下角在线点，避免在线标识被挤成独立元素 */
.cand-avatar-wrap { position: relative; flex: none; }
.cand-avatar { width: 46px; height: 46px; border-radius: 12px; object-fit: cover; display: block; }
.cand-online {
  position: absolute; right: -1px; bottom: -1px;
  width: 12px; height: 12px;
  border-radius: 50%;
  background: var(--ok);
  border: 2px solid var(--panel);
}
.cand strong { font-size: 15px; }
.cand p { margin: 3px 0 0; color: var(--muted); font-size: 11px; }
/* 左栏间距节奏：同组 12px、跨组 16px、标题到内容 10px */
.info-row { display: flex; justify-content: space-between; margin-top: 12px; font-size: 12px; }
.info-row span { color: var(--muted); }
.info-row b { font-weight: 600; }
.resume {
  width: 100%; height: 36px; margin-top: 16px;
  display: flex; align-items: center; gap: 8px;
  padding: 0 12px;
  border: 1px solid var(--line-strong);
  border-radius: 9px;
  background: transparent;
  color: var(--text);
}
.resume svg:last-child { margin-left: auto; color: var(--muted); }
.resume:hover { border-color: var(--primary); color: #9dbcff; }
.panel-title { margin: 16px 0 10px; font-size: 12px; color: var(--muted); font-weight: 600; }
.timeline { list-style: none; margin: 0; padding: 0; }
.timeline li { position: relative; padding: 0 0 18px 22px; }
.timeline li:last-child { padding-bottom: 0; }
.timeline li:before {
  content: ''; position: absolute; left: 4px; top: 14px; bottom: 0;
  width: 1px; background: var(--line-strong);
}
.timeline li:last-child:before { display: none; }
.timeline i {
  position: absolute; left: 0; top: 4px;
  width: 9px; height: 9px; border-radius: 50%;
  background: var(--panel-2); border: 1px solid var(--line-strong);
}
.timeline b { display: block; font-size: 12px; font-weight: 600; }
.timeline small { color: var(--subtle); font-size: 11px; }
.timeline .done i { background: var(--ok); border-color: var(--ok); }
.timeline .active i { background: var(--primary); border-color: var(--primary); box-shadow: 0 0 0 3px var(--primary-soft); }
.timeline .active b { color: #9dbcff; }

/* 主视频区（16:9） */
.main-video {
  position: relative;
  width: min(100%, calc((100vh - 156px) * 16 / 9));
  aspect-ratio: 16 / 9;
  border-radius: 16px;
  overflow: hidden;
  background: #05070c;
  box-shadow: 0 24px 60px rgba(0, 0, 0, .45);
}
.peer-video { width: 100%; height: 100%; object-fit: cover; display: block; background: #05070c; }
.peer-waiting {
  position: absolute; inset: 0;
  display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 10px;
  color: #8b98ad; font-size: 14px;
  background: radial-gradient(ellipse at center, #0c1424 0%, #05070c 70%);
}
.tag-main, .tag-quality, .tag-rec {
  height: 26px; padding: 0 11px;
  display: inline-flex; align-items: center; gap: 6px;
  border-radius: 999px;
  font-size: 12px;
  background: rgba(9, 14, 24, .62);
  backdrop-filter: blur(6px);
  color: #fff;
}
.tag-main { position: absolute; left: 14px; top: 14px; }
.tag-main i { width: 7px; height: 7px; border-radius: 50%; background: var(--ok); }
/* 画质与录制角标统一右对齐，避免靠硬编码偏移避让、文字一变宽窄就错位 */
.tag-right {
  position: absolute; top: 14px; right: 14px;
  display: inline-flex; align-items: center; gap: 8px;
}
.tag-quality { cursor: pointer; color: #a9bdda; }
.tag-quality.smooth { color: var(--warn); }
.tag-rec { color: #ffb3b4; }
.tag-rec i { width: 7px; height: 7px; border-radius: 50%; background: var(--rec); animation: blink 1.1s infinite; }
.net-warning {
  position: absolute; left: 50%; bottom: 14px; transform: translateX(-50%);
  display: inline-flex; align-items: center; gap: 7px;
  padding: 8px 14px;
  border-radius: 9px;
  background: rgba(250, 173, 20, .16);
  border: 1px solid rgba(250, 173, 20, .4);
  color: #ffd591;
  font-size: 12px;
  white-space: nowrap;
}

/* 自己小窗 */
.self-win {
  position: absolute;
  width: 160px; height: 90px;
  border-radius: 10px;
  overflow: hidden;
  border: 2px solid rgba(255, 255, 255, .85);
  box-shadow: 0 10px 26px rgba(0, 0, 0, .45);
  cursor: move;
}
.self-win video { width: 100%; height: 100%; object-fit: cover; display: block; pointer-events: none; transform: scaleX(-1); }
.self-fallback {
  position: absolute; inset: 0;
  display: grid; place-content: center; justify-items: center; gap: 5px;
  background: #1a2230; color: var(--muted); font-size: 10px;
  pointer-events: none;
}
.self-retry {
  pointer-events: auto;
  height: 20px; padding: 0 8px;
  border: 1px solid var(--line-strong);
  border-radius: 6px;
  background: rgba(9, 14, 24, .6);
  color: #cfe0ff;
  font-size: 10px;
}
.self-retry:hover { border-color: var(--primary); color: #fff; }
.self-name {
  position: absolute; left: 6px; bottom: 5px;
  display: inline-flex; align-items: center; gap: 3px;
  font-size: 10px; color: #fff;
  text-shadow: 0 1px 3px rgba(0, 0, 0, .7);
  pointer-events: none;
}
.self-hide {
  position: absolute; right: 5px; top: 5px;
  width: 20px; height: 20px;
  border: 0; border-radius: 6px;
  background: rgba(9, 14, 24, .6);
  color: #fff;
  display: grid; place-items: center;
}
.self-restore {
  position: absolute; right: 14px; bottom: 14px;
  display: inline-flex; align-items: center; gap: 7px;
  padding: 7px 12px;
  border-radius: 9px;
  background: rgba(9, 14, 24, .7);
  color: #cfe0ff;
  font-size: 12px;
  cursor: pointer;
}

/* 右侧侧边栏 */
.right-head { display: flex; align-items: center; justify-content: space-between; }
.right-head h2 { font-size: 15px; }
.progress-card { margin-top: 12px; padding: 12px; border-radius: 11px; background: var(--primary-soft); }
.progress-top, .progress-bottom { display: flex; align-items: center; justify-content: space-between; font-size: 12px; }
.progress-top b { font-size: 17px; color: #9dbcff; }
.progress-bottom { margin-top: 9px; color: var(--muted); }
.progress-bottom b { color: var(--text); }
.bar { height: 6px; margin-top: 8px; border-radius: 999px; background: rgba(255, 255, 255, .12); }
.bar u { display: block; height: 100%; border-radius: inherit; background: var(--primary); }
.block { margin-top: 18px; }
.block h3 { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--muted); font-weight: 600; }
.summary { margin: 9px 0 0; font-size: 12px; line-height: 1.7; color: #c3ccdb; }
.chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
.chips span {
  padding: 3px 8px; border-radius: 6px;
  background: var(--panel-2); color: var(--muted); font-size: 11px;
}
.tip { margin-top: 9px; padding: 11px; border-radius: 10px; background: var(--panel-2); border: 1px solid var(--line); }
.tip.adopted { border-color: rgba(82, 196, 26, .45); }
.tip p { margin: 0; font-size: 12px; line-height: 1.65; }
.tip-actions { display: flex; gap: 7px; margin-top: 10px; }
.tip-actions button {
  height: 26px; padding: 0 9px;
  display: inline-flex; align-items: center; gap: 4px;
  border: 1px solid var(--line-strong);
  border-radius: 7px;
  background: transparent; color: var(--muted); font-size: 11px;
}
.tip-actions .ok { color: #7ee0a0; border-color: rgba(82, 196, 26, .4); }
.tip-actions .no { color: #ff9c9d; border-color: rgba(255, 77, 79, .35); }
.points { margin: 9px 0 0; padding-left: 16px; }
.points li { font-size: 12px; line-height: 1.7; color: #c3ccdb; }
.points b { color: #9dbcff; font-weight: 600; }
.captions { flex: 1; min-height: 0; display: flex; flex-direction: column; }
.caption-list { margin-top: 9px; overflow: auto; display: grid; gap: 8px; }
.caption { display: grid; grid-template-columns: 44px 1fr; gap: 7px; font-size: 12px; }
.caption span { color: var(--muted); font-size: 11px; padding-top: 2px; }
.caption p { margin: 0; line-height: 1.6; color: #c3ccdb; }
.caption.ai p { color: #9dbcff; }

/* 底部控制栏 */
.controls {
  height: 76px; flex: none;
  display: flex; align-items: center; justify-content: center; gap: 10px;
  border-top: 1px solid var(--line);
  background: var(--panel);
}
.ctl {
  position: relative;
  width: 48px; height: 48px;
  border: 1px solid var(--line);
  border-radius: 12px;
  background: var(--panel-2);
  color: var(--text);
  display: grid; place-items: center;
}
.ctl span:last-child {
  position: absolute; bottom: calc(100% + 9px); left: 50%;
  transform: translateX(-50%);
  padding: 5px 9px;
  border-radius: 7px;
  background: #0b0f18;
  border: 1px solid var(--line-strong);
  color: var(--text);
  font-size: 11px;
  white-space: nowrap;
  opacity: 0; pointer-events: none;
  transition: .16s;
}
.ctl:hover span:last-child { opacity: 1; }
.ctl:hover { border-color: var(--primary); }
.ctl.off { background: var(--rec); border-color: transparent; color: #fff; }
.ctl.on { background: var(--primary); border-color: transparent; color: #fff; }
.ctl.disabled { opacity: .38; cursor: not-allowed; }
.ctl.disabled:hover { border-color: var(--line); }
.ctl.hang { background: var(--rec); border-color: transparent; color: #fff; }
.ctl.hang:hover { background: #ff6b6d; }
.dot-icon { width: 14px; height: 14px; border-radius: 50%; background: var(--rec); border: 2px solid #fff; }
.rec-btn.on { background: rgba(255, 77, 79, .18); border-color: rgba(255, 77, 79, .5); }
.rec-btn.on .dot-icon { animation: blink 1.4s infinite; }

/* 结束会议二次确认弹窗 */
.conf-mask {
  position: fixed; inset: 0; z-index: 90;
  display: grid; place-items: center;
  padding: 20px;
  background: rgba(5, 8, 15, .6);
  backdrop-filter: blur(2px);
}
.conf-modal {
  width: min(400px, 100%);
  padding: 22px;
  border-radius: 14px;
  background: var(--panel-2);
  border: 1px solid var(--line-strong);
  box-shadow: 0 24px 60px rgba(0, 0, 0, .5);
}
.conf-modal h3 { margin: 0; font-size: 16px; color: var(--text); }
.conf-modal p { margin: 10px 0 0; font-size: 13px; line-height: 1.7; color: var(--muted); }
.conf-modal-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px; }
.conf-cancel, .conf-confirm { height: 36px; padding: 0 18px; border-radius: 9px; font-size: 13px; font-weight: 600; }
.conf-cancel { border: 1px solid var(--line-strong); background: transparent; color: var(--muted); }
.conf-cancel:hover { color: var(--text); border-color: var(--line-strong); }
.conf-confirm { border: 0; color: #fff; background: var(--rec); }
.conf-confirm:hover { background: #ff6b6d; }

/* 会议设置弹窗 */
.set-field { margin-top: 14px; display: grid; gap: 6px; }
.set-field label { font-size: 12px; color: var(--muted); }
.set-field select {
  height: 36px; padding: 0 10px;
  border-radius: 9px;
  border: 1px solid var(--line-strong);
  background: var(--panel);
  color: var(--text);
  font-size: 13px;
  font-family: inherit;
  outline: none;
}
.set-field select:focus { border-color: var(--primary); }

@media (max-width: 1280px) { .right { width: 288px; } }
@media (max-width: 1120px) {
  .right { display: none; }
  .left { width: 232px; }
}
@media (max-width: 860px) {
  .left { display: none; }
  .main-video { width: 100%; }
}
</style>