<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  ArrowLeft, ChevronLeft, ChevronRight, FileText, Timer, Mic, MicOff,
  Video, MonitorUp, Copy, MessageSquareText, Settings, PhoneOff,
  ArrowUpRight, AlertTriangle, Lightbulb, CirclePause
} from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import { getCurrentSession, getSessionContext, getProgress, listCaptions, getQuestionHints, feedbackQuestionHint, heartbeat, finishSession, joinInterviewer, transferPrimary, getLiveKitToken, startRecording, stopRecording, takeover } from '@/api/system/conference'
import { getTalentResume } from '@/api/talent'
import { clearPreferredDevice, describeMediaNotice, getPreferredDevice, listMediaDevices, savePreferredDevice } from '@/utils/media'
import { useRealtimeAsr } from './useRealtimeAsr'
import { Room, RoomEvent, Track } from 'livekit-client'
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

// 面试进度 / 面试问题参考提示 / 实时字幕：全部来自后端真实数据，无数据时展示空态
const progress = ref({ done: 0, total: 0, remain: '--:--' })
const questionHints = ref([])
const captions = ref([])

// HR 打断接管：接管期间 AI 暂停出题，由面试官主导提问
const takeoverActive = ref(false)
const takeoverReason = ref('')
const takeoverVisible = ref(false)
const takeoverInput = ref('')
const takeoverLoading = ref(false)

// 提示偏好：采纳 / 忽略会累计到后端，后续同类提示按偏好重新排序
function hintScore(q) {
  return (q.usedCount || 0) - (q.ignoredCount || 0) * 2
}
async function feedbackHint(q, action) {
  if (!sessionId.value) return
  try {
    await feedbackQuestionHint(sessionId.value, { hintKey: q.topic, action })
    if (action === 'adopt') q.usedCount = (q.usedCount || 0) + 1
    else q.ignoredCount = (q.ignoredCount || 0) + 1
    questionHints.value = questionHints.value.slice().sort((a, b) => hintScore(b) - hintScore(a))
    notify(action === 'adopt' ? '已记录采纳，后续优先展示同类提示' : '已记录忽略，后续同类提示将靠后展示')
  } catch (e) {
    notify(e && e.message ? e.message : '反馈失败')
  }
}

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
let heartbeatId = null
let rttId = null
let progressId = null
// LiveKit 房间连接（媒体层：发布本地轨道 + 订阅远端轨道）
let room = null
const lkConnected = ref(false)
// 远端轨道缓存：userId -> { video?: MediaStreamTrack, audio?: MediaStreamTrack }
const remoteTracks = {}
let joinRecorded = false

// 当前进行中的面试场次（未取到时为 null）
const sessionId = ref(null)
// 字幕增量游标：取已拉取到的最大 dlg_id，供轮询与 WS 稳定句去重
let captionSeq = 0
let captionPollId = null
// 实时字幕：仅 AI 面试（模式 1-3）启用，模式 4 由后端返回不可用并展示降级提示
const asr = useRealtimeAsr({
  getSessionId: () => sessionId.value,
  getMicEnabled: () => MIC_ON.value && joined.value && sessionRole.value !== 'OBSERVER',
  // 直接复用 LiveKit 已发布的麦克风轨，避免二次占用设备
  getMicTrack: () => room?.localParticipant.getTrackPublication(Track.Source.Microphone)?.track?.mediaStreamTrack || null,
  onFinal: (item) => appendCaptions([{ sequence: item.sequence, role: item.role, content: item.text }])
})
// 供模板直接读取的顶层 ref（模板仅自动解包顶层 ref）
const asrStatus = asr.status
// 候选人信息与面试官姓名 / 面试轮次：进入场次后由接口回填，未取到时展示空态
const candidate = ref({ name: '', position: '' })
const interviewerName = ref('')
const roundNo = ref(null)
const totalRounds = ref(0)

// 面试详情真实数据：候选人头像 / 当前流程状态 / 岗位 JD 与技能标签 / 候选人流程记录
const candidateAvatar = ref('')
const candidateStatus = ref(null)
const positionJd = ref(null)
const positionSkills = ref([])
const flowHistory = ref([])

// 会议中查看候选人简历（人才库简历接口，按当前企业隔离）
const candidateId = ref(null)
const resumeVisible = ref(false)
const resumeLoading = ref(false)
const resumeError = ref('')
const resume = ref(null)

// 候选人流程状态文案（与 t_tal.tal_status 取值一致）
const CANDIDATE_STATUS_LABEL = {
  0: '新入库', 1: '初筛通过', 2: '面试中', 3: '已淘汰', 4: '已录用',
  5: '待笔试', 6: '笔试中', 7: '笔试通过', 8: '笔试未通过', 9: '笔试缺考'
}
// 当前阶段：候选人的真实流程状态，未取到时展示占位
const stageLabel = computed(() => {
  const v = candidateStatus.value
  return v == null ? '—' : (CANDIDATE_STATUS_LABEL[v] || '—')
})
// 岗位摘要：取 JD 画像中的岗位职责，无数据时为空（前端展示空态）
const positionSummary = computed(() => {
  const jd = positionJd.value
  if (!jd || typeof jd !== 'object') return ''
  const resp = jd.responsibilities
  return Array.isArray(resp) && resp.length ? resp.join('；') : ''
})

// 屏幕共享：仅展示对方共享的屏幕；本人共享时仍看正常宫格（自己的屏幕在本机可见，无需覆盖主画面）
const sharing = ref(false)
const remoteScreen = ref(null)
const screenEl = ref(null)
const activeScreenStream = computed(() => (remoteScreen.value && remoteScreen.value.stream) || null)
const screenLabel = computed(() => (remoteScreen.value ? `${remoteScreen.value.name} 正在共享屏幕` : ''))
watch(activeScreenStream, (stream) => {
  if (screenEl.value && screenEl.value.srcObject !== stream) screenEl.value.srcObject = stream || null
}, { flush: 'post' })

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
  // 观察者不发布本地流，宫格中不出现本人 tile
  if (sessionRole.value !== 'OBSERVER') {
    list.push({ key: SELF_KEY, name: interviewerName.value ? `我 · ${interviewerName.value}` : '我', roleLabel: '', candidate: false, primary: false, self: true, stream: localStreamRef.value })
  }
  return list
})
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
// 点击 tile：放大 / 还原（微信视频风格）
function toggleEnlarge(t) {
  if (enlargedKey.value === t.key) {
    enlargedKey.value = null
    return
  }
  enlargedKey.value = t.key
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

// 字幕角色文案：1-AI，2-HR，3-候选人
function captionWho(role) {
  return role === 1 ? 'AI' : role === 2 ? 'HR' : '候选人'
}

// 追加字幕并按 dlg_id 去重，仅保留最近 12 条
function appendCaptions(list) {
  if (!Array.isArray(list) || !list.length) return
  const next = captions.value.slice()
  list.forEach((item) => {
    const seq = Number(item.sequence) || 0
    if (seq && seq <= captionSeq) return
    if (seq) captionSeq = seq
    next.push({ who: captionWho(Number(item.role)), text: item.content })
  })
  captions.value = next.slice(-12)
}

// 对方发言通过增量接口轮询获取（WS 只回推本人的稳定句）
async function pollCaptions() {
  if (!sessionId.value) return
  try {
    const res = await listCaptions(sessionId.value, { afterSequence: captionSeq, limit: 50 })
    appendCaptions(res.data)
  } catch (e) {
    // 轮询异常时等待下一次
  }
}

// 按字幕开关与麦克风状态同步识别流（模式 4 / 未配置时后端返回 enabled=false）
async function syncAsr() {
  if (!sessionId.value) return
  await asr.refresh()
  if (CAPTION_ON.value && asr.status.value.enabled) await asr.start()
  else asr.stop()
}

async function toggleCaption() {
  CAPTION_ON.value = !CAPTION_ON.value
  await syncAsr()
}

// 切换音频设备后按新设备重建识别流采集
async function restartAsr() {
  if (!CAPTION_ON.value || !sessionId.value) return
  await asr.refresh()
  if (asr.status.value.enabled) await asr.restart()
}

// 无字幕时的占位文案：字幕不可用时展示具体降级原因
const captionEmptyText = computed(() => asr.status.value.reason || '暂无字幕')

// 连接 LiveKit 房间：向后端换取入会令牌后直连信令服务器，远端轨道到达即回填宫格
async function connectLiveKit() {
  if (!sessionId.value || room) return
  let info = null
  try {
    const res = await getLiveKitToken(sessionId.value)
    info = res.data
  } catch (e) {
    notify('获取视频会议令牌失败，请刷新重试')
    return
  }
  if (!info || !info.url || !info.token) return
  room = new Room()
  room.on(RoomEvent.TrackSubscribed, onRemoteTrack)
  room.on(RoomEvent.TrackUnsubscribed, offRemoteTrack)
  room.on(RoomEvent.ParticipantDisconnected, onPeerLeft)
  room.on(RoomEvent.LocalTrackUnpublished, (publication) => {
    if (publication.source === Track.Source.ScreenShare) {
      sharing.value = false
    }
  })
  room.on(RoomEvent.Disconnected, () => {
    lkConnected.value = false
    sharing.value = false
    remoteScreen.value = null
  })
  try {
    await room.connect(info.url, info.token)
    lkConnected.value = true
    // 已加入的发布者（主面试官 / 已手动加入的 HR）立即采集并发布本地音视频
    if (joined.value && sessionRole.value !== 'OBSERVER') await openMedia()
  } catch (e) {
    room = null
    notify('视频会议连接失败，请检查网络后刷新重试')
  }
}

// 令牌 identity 形如 u{userId}，据此把远端参与者映射到宫格 tile
function userIdFromIdentity(identity) {
  const m = /^u(\d+)$/.exec(identity || '')
  return m ? Number(m[1]) : null
}

function onRemoteTrack(track, publication, participant) {
  if (publication && publication.source === Track.Source.ScreenShare) {
    remoteScreen.value = { name: participant.name || '对方', identity: participant.identity, stream: new MediaStream([track.mediaStreamTrack]) }
    return
  }
  const uid = userIdFromIdentity(participant.identity)
  if (!uid || String(uid) === String(myUserId.value)) return
  const kind = track.kind === Track.Kind.Video ? 'video' : track.kind === Track.Kind.Audio ? 'audio' : null
  if (!kind) return
  const bag = remoteTracks[uid] || (remoteTracks[uid] = {})
  bag[kind] = track.mediaStreamTrack
  setPeerStream(uid, bag)
}

function offRemoteTrack(track, publication, participant) {
  if (publication && publication.source === Track.Source.ScreenShare) {
    remoteScreen.value = null
    return
  }
  const uid = userIdFromIdentity(participant.identity)
  if (!uid || !remoteTracks[uid]) return
  const kind = track.kind === Track.Kind.Video ? 'video' : track.kind === Track.Kind.Audio ? 'audio' : null
  if (kind && remoteTracks[uid][kind] === track.mediaStreamTrack) delete remoteTracks[uid][kind]
  setPeerStream(uid, remoteTracks[uid])
}

function onPeerLeft(participant) {
  if (remoteScreen.value && remoteScreen.value.identity === participant.identity) remoteScreen.value = null
  const uid = userIdFromIdentity(participant.identity)
  if (!uid) return
  delete remoteTracks[uid]
  const next = { ...peerStreams.value }
  delete next[String(uid)]
  peerStreams.value = next
}

// 同一参与者的音视频轨合并为一条 MediaStream 写入 peerStreams
function setPeerStream(uid, bag) {
  const tracks = [bag.video, bag.audio].filter(Boolean)
  const next = { ...peerStreams.value }
  if (tracks.length) next[String(uid)] = new MediaStream(tracks)
  else delete next[String(uid)]
  peerStreams.value = next
}

// 开启一路本地轨道：优先使用偏好设备，不可用时回退系统默认；返回错误（null 表示成功）
async function enableTrack(setter, kind) {
  const deviceId = getPreferredDevice(kind)
  if (deviceId) {
    try {
      await setter(true, { deviceId: { exact: deviceId } })
      return null
    } catch (e) {
      // 偏好设备失效，回退默认设备
    }
  }
  try {
    await setter(true)
    return null
  } catch (e) {
    return e
  }
}

// 本地摄像头画面回填到本人 tile 预览
function syncLocalPreview() {
  const track = room?.localParticipant.getTrackPublication(Track.Source.Camera)?.track
  localStreamRef.value = track ? new MediaStream([track.mediaStreamTrack]) : null
}

// 采集并发布本地音视频到 LiveKit 房间：观察者不发布
// 摄像头与麦克风分头开启，任一失败不影响另一项；失败原因写入 mediaError 供 UI 展示
async function openMedia() {
  if (!room || !lkConnected.value) return
  if (sessionRole.value === 'OBSERVER') return
  const camErr = await enableTrack((on, opts) => room.localParticipant.setCameraEnabled(on, opts), 'video')
  const micErr = await enableTrack((on, opts) => room.localParticipant.setMicrophoneEnabled(on, opts), 'audio')
  syncLocalPreview()
  // 开关状态与真实轨道保持一致，避免「显示已开启但没有画面/没有声音」
  CAM_ON.value = !camErr
  MIC_ON.value = !micErr
  const failures = []
  if (camErr) failures.push({ error: camErr, kind: 'camera' })
  if (micErr) failures.push({ error: micErr, kind: 'microphone' })
  if (failures.length === 1) {
    mediaError.value = await describeMediaNotice(failures[0].error, failures[0].kind)
  } else if (failures.length === 2) {
    mediaError.value = '未获得摄像头与麦克风权限，请在浏览器地址栏允许访问后重新检测'
  } else {
    mediaError.value = ''
  }
  if (mediaError.value) notify(mediaError.value)
  // 麦克风就绪后按需启动实时字幕识别流
  await syncAsr()
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
  const camTrack = room?.localParticipant.getTrackPublication(Track.Source.Camera)?.track
  const micTrack = room?.localParticipant.getTrackPublication(Track.Source.Microphone)?.track
  setCamId.value = (camTrack && camTrack.mediaStreamTrack.getSettings().deviceId) || getPreferredDevice('video')
  setMicId.value = (micTrack && micTrack.mediaStreamTrack.getSettings().deviceId) || getPreferredDevice('audio')
  showSettings.value = true
}

// 切换设备：通过 LiveKit restartTrack 换采集设备，成功后画面与发布同步更新
async function applyDevice(kind) {
  const isVideo = kind === 'video'
  const deviceId = isVideo ? setCamId.value : setMicId.value
  const source = isVideo ? Track.Source.Camera : Track.Source.Microphone
  const track = room?.localParticipant.getTrackPublication(source)?.track
  if (!track) {
    // 采集未开启时只记录偏好，下次开启时生效
    if (deviceId) savePreferredDevice(kind, deviceId)
    else clearPreferredDevice(kind)
    notify('已保存设备偏好，下次开启时生效')
    if (!isVideo) await restartAsr()
    return
  }
  try {
    await track.restartTrack(deviceId ? { deviceId: { exact: deviceId } } : {})
  } catch (error) {
    // 切换失败：保留原设备与画面，只提示原因
    notify(await describeMediaNotice(error, isVideo ? 'camera' : 'microphone'))
    return
  }
  if (deviceId) savePreferredDevice(kind, deviceId)
  else clearPreferredDevice(kind)
  if (isVideo) {
    setCamId.value = track.mediaStreamTrack.getSettings().deviceId || deviceId
    syncLocalPreview()
  } else {
    setMicId.value = track.mediaStreamTrack.getSettings().deviceId || deviceId
  }
  notify('已切换设备')
  // 字幕识别流按新音频设备重新采集
  if (!isVideo) await restartAsr()
}

// 宫格 tile 的 srcObject 由 watch(tiles) 统一维护，无需单独绑定主画面

// 岗位 JD（pos_jd_json）兼容字符串 / 对象两种形态，解析失败按无数据处理
function parseJd(raw) {
  if (!raw) return null
  if (typeof raw === 'object') return raw
  try {
    return JSON.parse(raw)
  } catch (e) {
    return null
  }
}

// 应用场次上下文：回填信息、面试官列表、模式与本人在场次中的角色
function applySessionContext(ctx) {
  if (!ctx) return
  if (ctx.candidateName) candidate.value.name = ctx.candidateName
  if (ctx.positionTitle) candidate.value.position = ctx.positionTitle
  candidateId.value = ctx.candidateId != null ? Number(ctx.candidateId) : null
  if (ctx.roundNo != null) roundNo.value = Number(ctx.roundNo)
  if (ctx.totalRounds != null) totalRounds.value = Number(ctx.totalRounds)
  // 候选人头像为后端相对路径，拼接接口基址后交由 MiniAvatar 渲染（为空则降级首字母）
  candidateAvatar.value = ctx.candidateAvatar ? import.meta.env.VITE_APP_BASE_API + ctx.candidateAvatar : ''
  candidateStatus.value = ctx.candidateStatus != null ? Number(ctx.candidateStatus) : null
  positionJd.value = parseJd(ctx.positionJd)
  positionSkills.value = Array.isArray(ctx.positionSkills) ? ctx.positionSkills : []
  flowHistory.value = Array.isArray(ctx.flowHistory) ? ctx.flowHistory : []
  // 小窗标注的是「我」，优先展示当前登录面试官本人姓名
  interviewerName.value = userStore.nickName || userStore.name || ctx.interviewerName || ''
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
}

// 加入本次面试：标记加入并开始发布本地音视频
async function joinNow(silent) {
  if (joined.value) return
  joined.value = true
  if (!silent) notify('已加入本次面试')
  await recordJoin()
  await openMedia()
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

async function toggleMic() {
  if (!room || !lkConnected.value) return
  // 设备未就绪时，点击按钮即重试采集发布
  if (!room.localParticipant.getTrackPublication(Track.Source.Microphone)) {
    await openMedia()
    return
  }
  const on = !MIC_ON.value
  await room.localParticipant.setMicrophoneEnabled(on)
  MIC_ON.value = on
  notify(on ? '麦克风已开启' : '麦克风已静音')
  // 静音不产生有效语音，关闭识别流；重新开启时再恢复
  await syncAsr()
}

async function toggleCam() {
  if (!room || !lkConnected.value) return
  // 设备未就绪时，点击按钮即重试采集发布
  if (!room.localParticipant.getTrackPublication(Track.Source.Camera)) {
    await openMedia()
    return
  }
  const on = !CAM_ON.value
  await room.localParticipant.setCameraEnabled(on)
  CAM_ON.value = on
  syncLocalPreview()
  notify(on ? '摄像头已开启' : '摄像头已关闭')
}

// 屏幕共享：发布/停止均由 LiveKit 管理，观察者无发布权限
async function toggleScreenShare() {
  if (!room || !lkConnected.value) {
    notify('会议未连接，暂不能共享屏幕')
    return
  }
  if (sessionRole.value === 'OBSERVER') {
    notify('当前角色无屏幕共享权限')
    return
  }
  // 以 LiveKit 实际发布状态为准：停止共享会触发 LocalTrackUnpublished，不能再手动取反
  const next = !sharing.value
  try {
    await room.localParticipant.setScreenShareEnabled(next)
    const pub = room.localParticipant.getTrackPublication(Track.Source.ScreenShare)
    sharing.value = !!(pub && pub.track)
    notify(next ? '已开始共享屏幕' : '已停止共享屏幕')
  } catch (e) {
    const pub = room && room.localParticipant.getTrackPublication(Track.Source.ScreenShare)
    sharing.value = !!(pub && pub.track)
    notify(next ? '屏幕共享未开启' : '停止共享失败，请重试')
  }
}

// 断开 LiveKit 房间并清空画面引用
function disconnectRoom() {
  if (room) {
    room.removeAllListeners()
    room.disconnect().catch(() => {})
    room = null
  }
  lkConnected.value = false
  Object.keys(remoteTracks).forEach((k) => delete remoteTracks[k])
  peerStreams.value = {}
  localStreamRef.value = null
  sharing.value = false
  remoteScreen.value = null
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

// 开始 / 停止录制：服务端 LiveKit Egress 房间合成录制，主面试官独占操作。
// 录制状态以服务端返回为准，避免「按钮显示录制中但服务端未录」的不一致。
async function toggleRecord() {
  if (!sessionId.value) {
    notify('尚未进入面试场次，无法录制')
    return
  }
  try {
    if (RECORDING.value) {
      await stopRecording(sessionId.value)
      RECORDING.value = false
      notify('录制已停止，处理完成后可在录制列表查看')
    } else {
      await startRecording(sessionId.value)
      RECORDING.value = true
      notify('已开始录制')
    }
  } catch (e) {
    notify(e && e.message ? e.message : '录制操作失败')
  }
}

// 结束后端场次并离开会议页。
// 结束接口不阻塞离开：接口异常时若卡在此处，又会变成「退不出去」。
function endSessionAndLeave() {
  if (sessionId.value) {
    finishSession(sessionId.value, 'normal').catch(() => {})
  }
  disconnectRoom()
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

// 会议中查看候选人简历：按场次关联的候选人ID读取人才库简历，接口按当前企业隔离
async function openResume() {
  if (!candidateId.value) {
    notify('当前场次未关联候选人简历')
    return
  }
  resumeVisible.value = true
  resumeLoading.value = true
  resumeError.value = ''
  resume.value = null
  try {
    const r = await getTalentResume(candidateId.value)
    resume.value = r.data || null
    if (!resume.value) resumeError.value = '该候选人暂无简历信息'
  } catch (e) {
    resumeError.value = e && e.message ? e.message : '简历加载失败'
  } finally {
    resumeLoading.value = false
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

// 拉取进度与接管状态：接口异常时保留上一次数据，不清空已展示内容
async function refreshProgress() {
  if (!sessionId.value) return
  try {
    const p = await getProgress(sessionId.value)
    if (!p.data) return
    progress.value.total = p.data.totalQuestionNo || 0
    progress.value.done = p.data.answeredCount ?? 0
    progress.value.remain = p.data.remainingSeconds != null ? fmtClock(p.data.remainingSeconds) : '--:--'
    takeoverActive.value = Number(p.data.takeover) === 1
    takeoverReason.value = p.data.takeoverReason || ''
  } catch (e) {
    // 后端未就绪时保留上一次数据
  }
}

// HR 打断接管：接管期间 AI 暂停出题，由面试官主导提问
function openTakeover() {
  takeoverInput.value = takeoverReason.value || ''
  takeoverVisible.value = true
}

async function confirmTakeover() {
  if (!sessionId.value) return
  takeoverLoading.value = true
  try {
    const r = await takeover(sessionId.value, { action: 'start', reason: takeoverInput.value.trim() })
    takeoverActive.value = true
    takeoverReason.value = (r.data && r.data.reason) || takeoverInput.value.trim()
    takeoverVisible.value = false
    notify('已接管本次面试，AI 暂停出题')
  } catch (e) {
    notify(e && e.message ? e.message : '接管失败')
  } finally {
    takeoverLoading.value = false
  }
}

async function endTakeover() {
  if (!sessionId.value) return
  try {
    await takeover(sessionId.value, { action: 'end', reason: '' })
    takeoverActive.value = false
    takeoverReason.value = ''
    notify('已结束接管，AI 恢复出题')
  } catch (e) {
    notify(e && e.message ? e.message : '结束接管失败')
  }
}

// 拉取场次并同步进度、字幕、AI 提词；后端未就绪时保持空态
async function initSession() {
  // 优先使用 URL 携带的 sessionId（等候室跳转时传入），与候选人端保持同一场次；
  // 服务端反查的「当前场次」在多活跃场次环境下可能与对端解析结果不一致，仅作兜底
  const urlSessionId = route.query.sessionId
  if (urlSessionId) {
    sessionId.value = urlSessionId
  } else {
    try {
      const s = await getCurrentSession()
      if (s.data && s.data.sessionId) {
        sessionId.value = s.data.sessionId
      }
    } catch (e) {
      // 后端未就绪时保持空态
    }
  }
  if (!sessionId.value) return
  // 拉取场次上下文：候选人 / 面试官列表 / 面试模式 / 本人在场次中的角色（主面试官自动加入）
  await refreshContext()
  await refreshProgress()
  // 进度与接管状态随场次变化，定时刷新以同步另一位面试官的操作
  if (!progressId) progressId = setInterval(refreshProgress, 5000)
  try {
    const c = await listCaptions(sessionId.value, { afterSequence: 0, limit: 50 })
    appendCaptions(c.data)
  } catch (e) {
    // 后端未就绪时保持空态
  }
  try {
    const r = await getQuestionHints(sessionId.value)
    questionHints.value = Array.isArray(r.data) ? r.data : []
  } catch (e) {
    // 无面试问题提示时展示空态
  }
  // 心跳保活：仅在确认存在真实场次后才需要
  heartbeatId = setInterval(() => heartbeat(sessionId.value).catch(() => {}), 15000)
  // 字幕轮询获取对方发言；本人发言由 WS 稳定句即时回推
  if (!captionPollId) captionPollId = setInterval(pollCaptions, 1500)
  // 先拉字幕可用状态（模式 4 / 未配置时展示降级原因），识别流待麦克风就绪后再启动
  await asr.refresh()
}

onMounted(async () => {
  timerId = setInterval(() => (seconds.value += 1), 1000)
  // 延迟探测与场次无关，独立启动，避免被 initSession 的异常吞掉
  refreshRtt()
  rttId = setInterval(refreshRtt, 2000)
  // 先解析场次与角色，再换取 LiveKit 令牌入会（入会成功后按角色发布本地流）
  await initSession()
  connectLiveKit()
})

onBeforeUnmount(() => {
  clearInterval(timerId)
  clearInterval(heartbeatId)
  clearInterval(rttId)
  clearInterval(progressId)
  clearInterval(captionPollId)
  asr.stop()
  disconnectRoom()
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
          <strong>{{ candidate.position || '面试进行中' }}</strong>
          <span v-if="totalRounds > 0" class="chip">第 {{ roundNo || 1 }} 轮 / 共 {{ totalRounds }} 轮</span>
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
            <MiniAvatar :name="candidate.name || '候选人'" :size="46" color="#4f7cff" :src="candidateAvatar" />
            <i class="cand-online" title="在线" />
          </div>
          <div>
            <strong>{{ candidate.name || '候选人' }}</strong>
            <p>{{ candidate.position || '—' }}</p>
          </div>
        </div>

        <div class="info-row"><span>应聘岗位</span><b>{{ candidate.position || '—' }}</b></div>
        <div class="info-row"><span>当前阶段</span><b>{{ stageLabel }}</b></div>
        <div class="info-row"><span>面试模式</span><b>{{ modeLabel }}</b></div>

        <button class="resume" @click="openResume">
          <FileText :size="16" />查看候选人简历<ArrowUpRight :size="15" />
        </button>

        <h3 class="panel-title">流程时间线</h3>
        <ol v-if="flowHistory.length" class="timeline">
          <li
            v-for="(item, index) in flowHistory"
            :key="index"
            :class="{ done: index < flowHistory.length - 1, active: index === flowHistory.length - 1 }"
          >
            <i /><div><b>{{ item.reason || '流程更新' }}</b><small>{{ item.at }}</small></div>
          </li>
        </ol>
        <p v-else class="empty">暂无流程记录</p>
      </aside>

      <section class="stage">
        <div class="video-stage" :class="[`n${Math.min(tiles.length, 6)}`, { 'is-spot': enlargedKey }]" :style="{ '--spot-rows': Math.max(tiles.length - 1, 1) }">
          <!-- 屏幕共享画面覆盖宫格，由 LiveKit 原生 ScreenShare 轨驱动 -->
          <div v-if="activeScreenStream" class="screen-share">
            <video ref="screenEl" autoplay playsinline muted />
            <span class="screen-share-tag"><MonitorUp :size="14" />{{ screenLabel }}</span>
          </div>

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
              <span>{{ t.self ? (mediaError ? '设备未就绪' : (!lkConnected ? '连接中…' : '摄像头已关闭')) : `等待 ${t.name} 画面…` }}</span>
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
          <div class="bar"><u :style="{ width: (progress.total ? progress.done / progress.total * 100 : 0) + '%' }" /></div>
          <div class="progress-bottom">
            <span>剩余时间</span>
            <b>{{ progress.remain }}</b>
          </div>
        </div>

        <section class="block takeover-card" :class="{ on: takeoverActive }">
          <h3><CirclePause :size="14" />人工接管</h3>
          <template v-if="takeoverActive">
            <p class="tk-status">已接管面试，AI 暂停出题</p>
            <p v-if="takeoverReason" class="tk-reason">接管原因：{{ takeoverReason }}</p>
            <button v-if="sessionRole !== 'OBSERVER'" class="tk-btn" @click="endTakeover">结束接管，交还 AI</button>
          </template>
          <template v-else>
            <p class="empty">AI 正在按题纲出题，可随时打断并接管提问</p>
            <button v-if="sessionRole !== 'OBSERVER'" class="tk-btn" @click="openTakeover">打断并接管</button>
          </template>
        </section>

        <section class="block">
          <h3>岗位摘要</h3>
          <p v-if="positionSummary" class="summary">{{ positionSummary }}</p>
          <div v-if="positionSkills.length" class="chips">
            <span v-for="item in positionSkills" :key="item.name">{{ item.name }}</span>
          </div>
          <p v-if="!positionSummary && !positionSkills.length" class="empty">暂无岗位描述</p>
        </section>

        <section class="block">
          <h3><Lightbulb :size="14" />面试问题参考提示</h3>
          <ol v-if="questionHints.length" class="q-hints">
            <li v-for="(q, i) in questionHints" :key="i">
              <b>{{ q.topic }}</b>
              <p v-if="q.hint">{{ q.hint }}</p>
              <div v-if="sessionRole !== 'OBSERVER'" class="q-actions">
                <button class="q-act" :class="{ on: q.usedCount > 0 }" @click="feedbackHint(q, 'adopt')">采纳</button>
                <button class="q-act" :class="{ off: q.ignoredCount > 0 }" @click="feedbackHint(q, 'ignore')">忽略</button>
              </div>
            </li>
          </ol>
          <p v-else class="empty">暂无面试问题提示</p>
        </section>

        <section class="block captions">
          <h3><MessageSquareText :size="14" />实时字幕</h3>
          <div class="caption-list">
            <div v-for="(item, index) in captions" :key="index" class="caption" :class="{ ai: item.who === 'AI' }">
              <span>{{ item.who }}</span>
              <p>{{ item.text }}</p>
            </div>
            <p v-if="!captions.length" class="empty">{{ captionEmptyText }}</p>
          </div>
        </section>
      </aside>
    </div>

    <footer class="controls">
      <!-- 观察者仅订阅观看，无发布权限，隐藏麦克风/摄像头开关 -->
      <button v-if="sessionRole !== 'OBSERVER'" class="ctl" :class="{ off: !MIC_ON }" @click="toggleMic">
        <MicOff v-if="!MIC_ON" :size="20" /><Mic v-else :size="20" /><span>麦克风</span>
      </button>
      <button v-if="sessionRole !== 'OBSERVER'" class="ctl" :class="{ off: !CAM_ON }" @click="toggleCam">
        <Video :size="20" /><span>摄像头</span>
      </button>
      <button
        v-if="sessionRole !== 'OBSERVER'"
        class="ctl"
        :class="{ on: sharing }"
        @click="toggleScreenShare"
      >
        <MonitorUp :size="20" /><span>{{ sharing ? '停止共享' : '屏幕共享' }}</span>
      </button>
      <button v-else class="ctl disabled" title="当前角色无屏幕共享权限" disabled>
        <MonitorUp :size="20" /><span>屏幕共享</span>
      </button>
      <button class="ctl rec-btn" :class="{ on: RECORDING }" @click="toggleRecord">
        <span class="dot-icon" /><span>录制</span>
      </button>
      <button class="ctl" :class="{ on: !enlargedKey }" @click="enlargedKey = null">
        <Copy :size="20" /><span>宫格视图</span>
      </button>
      <button class="ctl" :class="{ on: CAPTION_ON && asrStatus.enabled }" :disabled="!asrStatus.enabled" :title="asrStatus.enabled ? '实时字幕' : (asrStatus.reason || '实时字幕不可用')" @click="toggleCaption">
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

    <BaseModal v-if="takeoverVisible" title="打断并接管面试" width="440px" @close="takeoverVisible = false">
      <p class="tk-tip">接管后 AI 将暂停出题，由你主导提问；可随时结束接管交还 AI。</p>
      <textarea
        v-model="takeoverInput"
        class="tk-input"
        rows="3"
        maxlength="200"
        placeholder="接管原因（选填，最多 200 字）"
      />
      <template #footer>
        <div class="tk-actions">
          <button class="conf-cancel" @click="takeoverVisible = false">取消</button>
          <button class="conf-confirm" :disabled="takeoverLoading" @click="confirmTakeover">
            {{ takeoverLoading ? '处理中…' : '确认接管' }}
          </button>
        </div>
      </template>
    </BaseModal>

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

    <BaseModal v-if="resumeVisible" title="候选人简历" width="640px" @close="resumeVisible = false">
      <p v-if="resumeLoading" class="rs-tip">简历加载中…</p>
      <p v-else-if="resumeError" class="rs-tip">{{ resumeError }}</p>
      <div v-else-if="resume" class="rs">
        <div class="rs-head">
          <strong>{{ resume.name || candidate.name || '候选人' }}</strong>
          <span v-if="resume.jobDirection" class="rs-tag">{{ resume.jobDirection }}</span>
          <span class="rs-integrity">完整度 {{ resume.integrity ?? 0 }}%</span>
        </div>
        <div class="rs-meta">
          <span>手机：{{ resume.phone || '未填写' }}</span>
          <span>邮箱：{{ resume.email || '未填写' }}</span>
        </div>

        <section v-if="resume.educationList && resume.educationList.length" class="rs-sec">
          <h4>教育经历</h4>
          <div v-for="(e, i) in resume.educationList" :key="'edu' + i" class="rs-item">
            <b>{{ [e.school, e.major].filter(Boolean).join(' · ') || '—' }}</b>
            <small>{{ [e.degree, e.startDate, e.endDate].filter(Boolean).join(' / ') }}</small>
          </div>
        </section>

        <section v-if="resume.workList && resume.workList.length" class="rs-sec">
          <h4>工作经历</h4>
          <div v-for="(w, i) in resume.workList" :key="'work' + i" class="rs-item">
            <b>{{ [w.company, w.position].filter(Boolean).join(' · ') || '—' }}</b>
            <small>{{ [w.startDate, w.endDate].filter(Boolean).join(' - ') }}</small>
            <p v-if="w.summary">{{ w.summary }}</p>
          </div>
        </section>

        <section v-if="resume.projectList && resume.projectList.length" class="rs-sec">
          <h4>项目经历</h4>
          <div v-for="(p, i) in resume.projectList" :key="'prj' + i" class="rs-item">
            <b>{{ [p.name, p.role].filter(Boolean).join(' · ') || '—' }}</b>
            <small v-if="p.techStack">{{ p.techStack }}</small>
            <p v-if="p.summary">{{ p.summary }}</p>
          </div>
        </section>

        <section v-if="resume.skills && resume.skills.length" class="rs-sec">
          <h4>技能标签</h4>
          <div class="rs-skills">
            <span v-for="(s, i) in resume.skills" :key="'skl' + i">{{ s.name }}<i v-if="s.level"> · {{ s.level }}</i></span>
          </div>
        </section>

        <p v-if="resume.missingFields && resume.missingFields.length" class="rs-missing">
          缺失字段：{{ resume.missingFields.join('、') }}
        </p>
      </div>
    </BaseModal>

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

/* 屏幕共享画面：覆盖整个宫格区域，含黑边完整显示 */
.screen-share {
  position: absolute;
  inset: 0;
  z-index: 5;
  background: #05070c;
  border-radius: 16px;
  overflow: hidden;
}
.screen-share video { width: 100%; height: 100%; object-fit: contain; display: block; }
.screen-share-tag {
  position: absolute;
  top: 12px; left: 12px;
  display: inline-flex; align-items: center; gap: 6px;
  height: 26px; padding: 0 10px;
  border-radius: 999px;
  background: rgba(9, 14, 24, .72);
  border: 1px solid rgba(255, 255, 255, .12);
  color: #cfe0ff; font-size: 12px;
}

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
.q-hints { margin: 9px 0 0; padding-left: 16px; display: grid; gap: 10px; }
.q-hints li { font-size: 12px; line-height: 1.6; color: #c3ccdb; }
.q-hints b { display: block; color: #9dbcff; font-weight: 600; }
.q-hints p { margin: 3px 0 0; color: var(--muted); line-height: 1.65; }
.q-actions { display: flex; gap: 8px; margin-top: 6px; }
.q-act {
  height: 24px; padding: 0 9px;
  border: 1px solid var(--line-strong); border-radius: 6px;
  background: transparent; color: var(--muted); font-size: 11px;
}
.q-act:hover { border-color: var(--primary); color: #9dbcff; }
.q-act.on { border-color: rgba(82, 196, 26, .5); color: #7ee787; }
.q-act.off { border-color: rgba(255, 77, 79, .4); color: #ff9c9e; }
.empty { margin: 9px 0 0; font-size: 12px; color: var(--muted); }

/* HR 打断接管 */
.takeover-card.on { padding: 10px 12px; border-radius: 11px; background: rgba(250, 173, 20, .12); border: 1px solid rgba(250, 173, 20, .32); }
.tk-status { margin: 9px 0 0; font-size: 12px; color: #ffd591; font-weight: 600; }
.tk-reason { margin: 4px 0 0; font-size: 12px; line-height: 1.6; color: #c3ccdb; }
.tk-btn {
  margin-top: 10px; height: 30px; padding: 0 12px;
  border: 1px solid var(--line-strong); border-radius: 8px;
  background: transparent; color: var(--text); font-size: 12px;
}
.tk-btn:hover { border-color: var(--primary); color: #9dbcff; }
.tk-tip { margin: 0 0 10px; font-size: 13px; line-height: 1.6; color: #6f7f99; }
.tk-input {
  width: 100%; padding: 9px 11px; resize: vertical;
  border: 1px solid #d8e0ec; border-radius: 9px;
  font: inherit; font-size: 13px; color: #16233b;
}
.tk-input:focus { outline: none; border-color: #4f7cff; }
.tk-actions { display: flex; gap: 10px; }
.tk-actions .conf-confirm:disabled { opacity: .6; cursor: not-allowed; }

/* 会议中查看简历弹窗 */
.rs-tip { margin: 0; font-size: 13px; color: #6f7f99; }
.rs-head { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.rs-head strong { font-size: 18px; color: #16233b; }
.rs-tag { padding: 2px 8px; border-radius: 6px; background: #eef3ff; color: #2563eb; font-size: 12px; }
.rs-integrity { margin-left: auto; font-size: 12px; color: #6f7f99; }
.rs-meta { display: flex; gap: 18px; flex-wrap: wrap; margin-top: 8px; font-size: 13px; color: #46536b; }
.rs-sec { margin-top: 18px; }
.rs-sec h4 { margin: 0 0 8px; font-size: 13px; color: #16233b; }
.rs-item { padding: 10px 12px; border: 1px solid #e7ebf3; border-radius: 9px; }
.rs-item + .rs-item { margin-top: 8px; }
.rs-item b { display: block; font-size: 13px; color: #16233b; }
.rs-item small { display: block; margin-top: 3px; font-size: 12px; color: #808da4; }
.rs-item p { margin: 6px 0 0; font-size: 12px; line-height: 1.7; color: #46536b; white-space: pre-wrap; }
.rs-skills { display: flex; flex-wrap: wrap; gap: 8px; }
.rs-skills span { padding: 4px 10px; border-radius: 7px; background: #eef3ff; color: #2563eb; font-size: 12px; }
.rs-skills i { font-style: normal; color: #6f7f99; }
.rs-missing { margin: 16px 0 0; font-size: 12px; color: #b26a00; }
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