<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  ArrowLeft, ChevronLeft, ChevronRight, FileText, Sparkles, Timer, Mic, MicOff,
  Video, MonitorUp, Copy, MessageSquareText, Settings, PhoneOff, CircleCheck,
  CircleX, Pencil, ArrowUpRight, AlertTriangle, Lightbulb
} from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { getCurrentSession, getSessionContext, getProgress, listCaptions, heartbeat, handleCopilot, finishSession, joinInterviewer, transferPrimary } from '@/api/system/conference'
import { clearPreferredDevice, describeMediaNotice, getPreferredDevice, listMediaDevices, requestMedia, requestMediaWithFallback, savePreferredDevice } from '@/utils/media'
import { createConferenceRtc } from '@/utils/webrtc'
import { createMeetingRecorder } from '@/utils/recorder'
import useUserStore from '@/store/modules/user'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()

const leftOpen = ref(true)
const rightOpen = ref(true)
// 宫格布局：null=宫格（所有画面并排，微信视频风格），非空=聚焦（该 key 的画面放大，其余为缩略条）
const enlargedKey = ref(null)
// 本人摄像头流（响应式，供宫格 tile 绑定 srcObject）
const localStreamRef = ref(null)
// 宫格中每个 tile 的 <video> 元素：key -> element
const tileEls = {}
const SELF_KEY = 'self'
const toast = ref('')
// 远端音视频流：userId -> MediaStream（多面试官时每人一路）
const peerStreams = ref({})
// 参与者列表（候选人 + 其他面试官），主画面可切换
const participants = ref([])
// 主画面当前选中的参与者用户ID
const selectedUserId = ref(null)
// 本人用户ID / 场次主面试官ID / 面试模式 / 本人在场次中的角色
const myUserId = ref(Number(userStore.id) || null)
const primaryInterviewerId = ref(null)
const interviewMode = ref(2)
const sessionRole = ref(null)
// 本人是否已加入本次面试（未加入时不发布本地音视频）
const joined = ref(true)
// 设备申请失败的原因；非空时小窗展示「重新检测」入口
const mediaError = ref('')
// 结束会议二次确认
const showExitConfirm = ref(false)

const MIC_ON = ref(true)
const CAM_ON = ref(true)
const SHARING = ref(false)
const RECORDING = ref(false)
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

// 面试模式展示文案（1-纯AI，2-AI+单面试官，3-AI+多面试官，4-无AI纯人工）
const modeLabel = computed(() => {
  switch (interviewMode.value) {
    case 1: return '纯 AI 面试'
    case 3: return 'AI + 多面试官'
    case 4: return '无 AI · 纯人工'
    default: return 'AI + HR 协同'
  }
})
// 无AI纯人工模式不展示 AI 协同面板
const showAiPanel = computed(() => interviewMode.value !== 4)
// 后到的面试官需手动加入本次面试；观察者只观看、不发布
const showJoinButton = computed(() => sessionRole.value === 'HR' && !joined.value)
// 本人是否为主面试官
const isSelfPrimary = computed(() => String(myUserId.value) === String(primaryInterviewerId.value))

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
// 会议录制器（canvas 合成画面 + 多路音频混音 + 分片上传）
let recorder = null
let joinRecorded = false

// 当前进行中的面试场次（无后端数据时为 null，页面继续用 mock 演示）
const sessionId = ref(null)
// 候选人信息与面试官姓名：进入场次后由接口回填，未取到时保留演示值
const candidate = ref({ name: '王芳', position: '高级前端工程师' })
const interviewerName = ref('林晓雯')

// 宫格统一画面数据：所有远端参与者 + 本人，宫格/聚焦共用同一组 DOM
const tiles = computed(() => {
  const list = participants.value.map((p) => ({
    key: String(p.userId),
    name: p.name,
    roleLabel: p.roleLabel,
    candidate: !!p.candidate,
    primary: !!p.primary,
    self: false,
    stream: peerStreams.value[String(p.userId)] || null
  }))
  list.push({ key: SELF_KEY, name: `我 · ${interviewerName.value}`, roleLabel: '', candidate: false, primary: false, self: true, stream: localStreamRef.value })
  return list
})
// 录制主画面元素：最近一次被放大的远端参与者（selectedUserId）
function mainRecordEl() {
  if (selectedUserId.value == null) return null
  return tileEls[String(selectedUserId.value)] || null
}
// tile <video> 元素注册回调：挂载即绑定流，卸载即移除
function setTileEl(key, el) {
  if (el) {
    tileEls[key] = el
    const t = tiles.value.find((x) => x.key === key)
    if (el.srcObject !== (t && t.stream)) el.srcObject = t ? t.stream : null
  } else {
    delete tileEls[key]
  }
}
// 流变化后同步各 tile 的 srcObject
watch(tiles, () => {
  tiles.value.forEach((t) => {
    const el = tileEls[t.key]
    if (el && el.srcObject !== t.stream) el.srcObject = t.stream
  })
}, { flush: 'post' })
// 点击 tile：放大 / 还原（微信视频风格）；放大远端画面时同步切换录制主画面
function toggleEnlarge(t) {
  if (enlargedKey.value === t.key) {
    enlargedKey.value = null
    return
  }
  enlargedKey.value = t.key
  if (!t.self) selectedUserId.value = Number(t.key)
}

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

// 接入本机摄像头与麦克风：本人画面以宫格 tile 呈现
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
  localStreamRef.value = localVideoStream

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
  if (joined.value) rtc?.attachLocalTracks(videoTrack, audioTrack)
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
    localStreamRef.value = localVideoStream
    setCamId.value = videoTrack.getSettings().deviceId || deviceId
  } else {
    audioTrack = newTrack
    audioTrack.enabled = MIC_ON.value
    // 录制中换麦克风：新轨道补接入混音总线
    recorder && recorder.addStream(new MediaStream([audioTrack]))
    setMicId.value = audioTrack.getSettings().deviceId || deviceId
  }
  // 同步重建合并流，确保 releaseMedia 能停止新轨道（旧轨道已 stop，重复 stop 无副作用）
  stream = rebuildLocalStream()

  if (joined.value) rtc?.attachLocalTracks(videoTrack, audioTrack)
  notify('已切换设备')
}

// 合并当前启用的轨道为一条本地流，供 releaseMedia 统一释放
function rebuildLocalStream() {
  const tracks = [...(videoTrack ? [videoTrack] : []), ...(audioTrack ? [audioTrack] : [])]
  return tracks.length ? new MediaStream(tracks) : null
}

// WebRTC 网状信令连接：拿到场次后建立，各远端流按 userId 分别缓存，主画面按选中项渲染
function startRtc() {
  if (rtc || !sessionId.value) return
  rtc = createConferenceRtc({
    sessionId: sessionId.value,
    onPeerStream: (userId, stream) => {
      peerStreams.value = { ...peerStreams.value, [String(userId)]: stream }
      // 录制中新加入的参与者补接入音频混音
      recorder && recorder.addStream(stream)
    },
    onPeerLeft: (userId) => {
      const next = { ...peerStreams.value }
      delete next[String(userId)]
      peerStreams.value = next
    },
    // 对端连接建立后，若正在录制则把当前录制状态补发给它（覆盖对端刷新/后加入的场景）
    onPeerState: (userId, state) => {
      if (state === 'connected' && RECORDING.value) rtc?.sendControl('recording', { on: true }, userId)
    }
  })
  rtc.start()
  // 媒体采集先于信令就绪时补挂本地轨道（仅已加入时发布）
  if (joined.value && (videoTrack || audioTrack)) rtc.attachLocalTracks(videoTrack, audioTrack)
}

// 宫格 tile 的 srcObject 由 watch(tiles) 统一维护，无需单独绑定主画面

// 应用场次上下文：回填信息、面试官列表、模式与本人在场次中的角色
function applySessionContext(ctx) {
  if (!ctx) return
  if (ctx.candidateName) candidate.value.name = ctx.candidateName
  if (ctx.positionTitle) candidate.value.position = ctx.positionTitle
  // 小窗标注的是「我」，优先展示当前登录面试官本人姓名
  interviewerName.value = userStore.nickName || userStore.name || ctx.interviewerName || interviewerName.value
  if (ctx.mode) interviewMode.value = Number(ctx.mode)
  sessionRole.value = ctx.role || null
  primaryInterviewerId.value = ctx.primaryInterviewerId != null ? Number(ctx.primaryInterviewerId) : null

  const list = []
  if (ctx.candidateUserId != null) {
    list.push({ userId: Number(ctx.candidateUserId), name: ctx.candidateName || '候选人', roleLabel: '候选人', candidate: true, primary: false })
  }
  const interviewers = ctx.interviewers || []
  interviewers.forEach((it) => {
    const uid = Number(it.userId)
    // 本人的画面用本地小窗呈现，不重复放入可切换列表
    if (String(uid) === String(myUserId.value)) return
    list.push({
      userId: uid,
      name: it.userName || '面试官',
      roleLabel: Number(it.isPrimary) === 1 ? '主面试官' : '面试官',
      candidate: false,
      primary: Number(it.isPrimary) === 1
    })
  })
  participants.value = list
  if (selectedUserId.value == null && list.length) selectedUserId.value = list[0].userId

  // 加入状态：主面试官自动加入；其他面试官按服务端记录，未加入需手动点「加入本次面试」；
  // 观察者只观看不发布
  if (sessionRole.value === 'OBSERVER') {
    joined.value = false
  } else if (sessionRole.value === 'HR') {
    if (isSelfPrimary.value) {
      joined.value = true
      recordJoin()
    } else {
      const selfMeta = interviewers.find((x) => String(x.userId) === String(myUserId.value))
      joined.value = !!selfMeta && Number(selfMeta.joinStatus) === 1
    }
  }
  if (joined.value && (videoTrack || audioTrack)) rtc?.attachLocalTracks(videoTrack, audioTrack)
}

// 加入本次面试：标记加入并开始发布本地音视频
async function joinNow(silent) {
  if (joined.value) return
  joined.value = true
  if (!silent) notify('已加入本次面试')
  if (videoTrack || audioTrack) rtc?.attachLocalTracks(videoTrack, audioTrack)
  await recordJoin()
}

// 向服务端登记「已加入」（仅登记一次，避免刷新上下文时循环调用）
async function recordJoin() {
  if (joinRecorded || !sessionId.value) return
  joinRecorded = true
  try {
    await joinInterviewer(sessionId.value)
    await refreshContext()
  } catch (e) {
    // 网络异常时保持已加入的本地状态
  }
}

// 重新拉取场次上下文（面试官列表 / 主面试官可能已变化）
async function refreshContext() {
  if (!sessionId.value) return
  try {
    const res = await getSessionContext(sessionId.value)
    applySessionContext(res.data)
  } catch (e) {
    // 忽略
  }
}

// 移交主持人给其他面试官
async function handoverPrimary(item) {
  if (!sessionId.value) return
  try {
    await transferPrimary(sessionId.value, item.userId)
    notify(`已将主持人移交给 ${item.name}`)
    await refreshContext()
  } catch (e) {
    notify('移交失败，请重试')
  }
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
  localStreamRef.value = null
}

function toggleQuality() {
  if (quality.value === 'hd') {
    quality.value = 'smooth'
    notify('网络波动，已自动降低画质至「流畅」')
  } else {
    quality.value = 'hd'
    notify('网络已恢复，画质恢复至「高清」')
  }
}

// 向房间广播录制状态，使候选人端「录制中」标识与真实录制状态保持一致
function broadcastRecording(on) {
  rtc?.sendControl('recording', { on: !!on })
}

// 开始 / 停止真实录制：合成主画面+小窗，混入双方音频，30 秒分片上传
function toggleRecord() {
  if (recorder && recorder.isRecording()) {
    recorder.stop().then(
      () => notify('录制已停止，文件已保存'),
      () => notify('录制已停止，但上传未完成')
    )
    RECORDING.value = false
    broadcastRecording(false)
    return
  }
  if (!isSelfPrimary.value) {
    notify('仅主面试官可操作录制')
    return
  }
  if (!sessionId.value) {
    notify('未连接到面试场次，无法录制')
    return
  }
  if (!recorder) {
    recorder = createMeetingRecorder({
      getSessionId: () => sessionId.value,
      getMainVideo: () => mainRecordEl(),
      getSelfVideo: () => tileEls[SELF_KEY] || null,
      getPeerStreams: () => peerStreams.value,
      getLocalStream: () => stream,
      onNotify: notify
    })
  }
  if (recorder.start()) {
    RECORDING.value = true
    broadcastRecording(true)
  }
}

// 结束后端场次并离开会议页。
// 结束接口不阻塞离开：接口异常时若卡在此处，又会变成「退不出去」。
function endSessionAndLeave() {
  if (recorder && recorder.isRecording()) {
    // 录制中结束会议：触发末片上传，不阻塞离开（失败仅提示）
    recorder.stop().catch(() => notify('录制上传未完成，最后一段可能缺失'))
    RECORDING.value = false
    broadcastRecording(false)
  }
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

// 拉取场次并同步进度、字幕；后端不可用时静默保留 mock
async function initSession() {
  // 优先使用 URL 携带的 sessionId（等候室跳转时传入），与候选人端保持同一场次；
  // 服务端反查的「当前场次」在多活跃场次环境下可能与对端解析结果不一致，仅作兜底
  const urlSessionId = route.query.sessionId
  if (urlSessionId) {
    sessionId.value = urlSessionId
    startRtc()
  } else {
    try {
      const s = await getCurrentSession()
      if (s.data && s.data.sessionId) {
        sessionId.value = s.data.sessionId
        startRtc()
      }
    } catch (e) {
      // 本地未启动后端时保留 mock 演示
    }
  }
  if (!sessionId.value) return
  // 拉取场次上下文：候选人 / 面试官列表 / 面试模式 / 本人在场次中的角色（主面试官自动加入）
  await refreshContext()
  try {
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
  if (recorder) {
    recorder.destroy()
    recorder = null
  }
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
          <span class="chip mode"><Sparkles v-if="showAiPanel" :size="12" />{{ modeLabel }}</span>
        </div>
      </div>
      <div class="tb-right">
        <button v-if="showJoinButton" class="tb-join" @click="joinNow()">加入本次面试</button>
        <button v-if="showAiPanel" class="tb-icon" :title="rightOpen ? '收起协同面板' : '展开协同面板'" @click="rightOpen = !rightOpen">
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
        <div class="info-row"><span>面试模式</span><b>{{ modeLabel }}</b></div>

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
        <div class="video-stage" :class="[`n${Math.min(tiles.length, 6)}`, { 'is-spot': enlargedKey }]" :style="{ '--spot-rows': Math.max(tiles.length - 1, 1) }">
          <div
            v-for="t in tiles"
            :key="t.key"
            class="tile"
            :class="{ big: enlargedKey === t.key }"
            @click="toggleEnlarge(t)"
          >
            <video
              :ref="(el) => setTileEl(t.key, el)"
              class="tile-video"
              :class="{ mirror: t.self }"
              autoplay
              playsinline
              :muted="t.self"
            />
            <!-- 无流：等待占位 -->
            <div v-if="!t.stream" class="tile-waiting">
              <Video :size="t.self ? 16 : 22" />
              <span>{{ t.self ? (mediaError ? '设备未就绪' : '摄像头已关闭') : `等待 ${t.name} 画面…` }}</span>
              <button v-if="t.self && mediaError" class="tile-retry" @click.stop="openMedia">重新检测</button>
            </div>
            <!-- 本人摄像头关闭但有流时仍显示占位（流含音频轨） -->
            <div v-else-if="t.self && !CAM_ON" class="tile-waiting">
              <Video :size="16" />
              <span>摄像头已关闭</span>
            </div>

            <span class="tile-name"><i v-if="t.stream" />{{ t.name }}<small v-if="t.roleLabel"> · {{ t.roleLabel }}</small></span>

            <div class="tile-tools">
              <button
                v-if="isSelfPrimary && !t.candidate && !t.self"
                class="tile-transfer"
                title="将主持人身份移交给该面试官"
                @click.stop="handoverPrimary({ userId: Number(t.key), name: t.name })"
              >移交</button>
              <span class="tile-zoom">{{ enlargedKey === t.key ? '还原' : '放大' }}</span>
            </div>
          </div>

          <div class="tag-right">
            <span class="tag-quality" :class="quality" @click.stop="toggleQuality">
              {{ quality === 'hd' ? '高清 1080P' : '流畅 480P' }}
            </span>
            <span v-if="RECORDING" class="tag-rec"><i />录制中</span>
          </div>

          <div v-if="quality === 'smooth'" class="net-warning">
            <AlertTriangle :size="14" />网络不佳，已自动降低画质以保持通话稳定
          </div>
        </div>
      </section>

      <aside v-show="rightOpen && showAiPanel" class="right">
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
      <button class="ctl" :class="{ on: !enlargedKey }" @click="enlargedKey = null">
        <Copy :size="20" /><span>宫格视图</span>
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
.tb-join {
  height: 32px; padding: 0 14px;
  border: 0; border-radius: 8px;
  background: var(--primary);
  color: #fff;
  font-size: 13px; font-weight: 600;
}
.tb-join:hover { background: var(--primary-strong); }
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

/* 视频宫格区：默认所有画面并排（微信视频风格），点击放大其一（聚焦模式） */
.video-stage {
  position: relative;
  width: min(100%, calc((100vh - 156px) * 16 / 9));
  aspect-ratio: 16 / 9;
  border-radius: 16px;
  overflow: hidden;
  background: #05070c;
  box-shadow: 0 24px 60px rgba(0, 0, 0, .45);
  display: grid;
  gap: 8px;
  padding: 8px;
  grid-template-columns: repeat(auto-fit, minmax(0, 1fr));
  grid-auto-rows: 1fr;
  grid-auto-flow: dense;
}
/* 2 个画面：左右对半；3-4 个：2×2；更多：自动换行 */
.video-stage.n2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
/* n3 采用 2×2 均匀宫格（第 4 格留空）：每格接近 16:9，画面 contain 后黑边最小 */
.video-stage.n3 { grid-template-columns: repeat(2, minmax(0, 1fr)); grid-template-rows: repeat(2, minmax(0, 1fr)); }
.video-stage.n4 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
.video-stage.n5, .video-stage.n6 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
.video-stage.n5 .tile:first-child, .video-stage.n6 .tile:first-child { grid-column: span 2; grid-row: span 2; }
/* 聚焦模式：放大画面占满左侧，其余缩为右侧竖排小条（微信视频风格） */
.video-stage.is-spot { grid-template-columns: 1fr 168px; grid-template-rows: repeat(var(--spot-rows, 2), minmax(0, 1fr)); }
.video-stage.is-spot .tile.big { grid-column: 1; grid-row: 1 / -1; }
.video-stage.is-spot .tile:not(.big) { grid-column: 2; }
.video-stage.is-spot .tag-right { right: 184px; }

.tile {
  position: relative;
  min-width: 0; min-height: 0;
  border-radius: 12px;
  overflow: hidden;
  background: #0b1220;
  border: 1px solid rgba(255, 255, 255, .06);
  cursor: pointer;
  transition: border-color .15s;
}
.tile:hover { border-color: rgba(255, 255, 255, .3); }
.tile.big { border-color: var(--primary); }
/* contain：完整显示画面不裁切（cover 会把摄像头画面放大裁掉边缘） */
.tile-video { width: 100%; height: 100%; object-fit: contain; display: block; background: #05070c; }
.tile-video.mirror { transform: scaleX(-1); }
.tile-waiting {
  position: absolute; inset: 0;
  display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px;
  color: #8b98ad; font-size: 12px;
  background: radial-gradient(ellipse at center, #0c1424 0%, #05070c 75%);
}
.tile-retry {
  height: 22px; padding: 0 9px;
  border: 1px solid var(--line-strong);
  border-radius: 6px;
  background: rgba(9, 14, 24, .6);
  color: #cfe0ff; font-size: 11px;
}
.tile-retry:hover { border-color: var(--primary); color: #fff; }
.tile-name {
  position: absolute; left: 8px; bottom: 7px;
  display: inline-flex; align-items: center; gap: 5px;
  padding: 3px 9px;
  border-radius: 999px;
  background: rgba(9, 14, 24, .62);
  backdrop-filter: blur(6px);
  font-size: 11px; color: #fff;
  pointer-events: none;
  max-width: calc(100% - 16px);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.tile-name i { width: 6px; height: 6px; border-radius: 50%; background: var(--ok); flex: none; }
.tile-name small { color: #9fb0c8; }
.tile-tools {
  position: absolute; right: 8px; top: 8px;
  display: inline-flex; align-items: center; gap: 6px;
}
.tile-transfer {
  height: 22px; padding: 0 8px;
  border: 1px solid var(--line-strong);
  border-radius: 6px;
  background: rgba(9, 14, 24, .62);
  color: #cfe0ff; font-size: 10px;
}
.tile-transfer:hover { border-color: var(--primary); color: #fff; }
.tile-zoom {
  height: 22px; padding: 0 9px;
  display: inline-flex; align-items: center;
  border-radius: 999px;
  background: rgba(9, 14, 24, .62);
  backdrop-filter: blur(6px);
  font-size: 10px; color: #9fb0c8;
  opacity: 0; transition: opacity .15s;
}
.tile:hover .tile-zoom { opacity: 1; }
.tag-quality, .tag-rec {
  height: 26px; padding: 0 11px;
  display: inline-flex; align-items: center; gap: 6px;
  border-radius: 999px;
  font-size: 12px;
  background: rgba(9, 14, 24, .62);
  backdrop-filter: blur(6px);
  color: #fff;
}
/* 画质与录制角标统一右对齐，避免靠硬编码偏移避让、文字一变宽窄就错位 */
.tag-right {
  position: absolute; top: 16px; right: 16px; z-index: 3;
  display: inline-flex; align-items: center; gap: 8px;
}
.tag-quality { cursor: pointer; color: #a9bdda; }
.tag-quality.smooth { color: var(--warn); }
.tag-rec { color: #ffb3b4; }
.tag-rec i { width: 7px; height: 7px; border-radius: 50%; background: var(--rec); animation: blink 1.1s infinite; }
.net-warning {
  position: absolute; left: 50%; bottom: 14px; transform: translateX(-50%); z-index: 3;
  display: inline-flex; align-items: center; gap: 7px;
  padding: 8px 14px;
  border-radius: 9px;
  background: rgba(250, 173, 20, .16);
  border: 1px solid rgba(250, 173, 20, .4);
  color: #ffd591;
  font-size: 12px;
  white-space: nowrap;
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
  .left { width: 232px; }
}
@media (max-width: 860px) {
  .left { display: none; }
  .video-stage { width: 100%; }
}
</style>