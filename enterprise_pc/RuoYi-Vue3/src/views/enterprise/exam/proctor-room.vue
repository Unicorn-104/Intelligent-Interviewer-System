<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, Camera, Video, ShieldCheck, RotateCw } from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listOngoingExams, getExamProctorToken } from '@/api/exam'
import { Room, RoomEvent, Track } from 'livekit-client'

const route = useRoute()
const router = useRouter()
const toast = ref('')
function notify(m) { toast.value = m; setTimeout(() => { toast.value = '' }, 2400) }

const recordId = computed(() => String(route.query.recordId || ''))
const exam = ref(null)
const connecting = ref(false)
const notFound = ref(false)
const mainOnline = ref(false)
const subOnline = ref(false)
const mainVideo = ref(null)
const subVideo = ref(null)

let room = null
let pollTimer = null

function fmt(t) { return t ? String(t).replace('T', ' ').slice(5, 16) : '--' }

async function loadExam() {
  try {
    const res = await listOngoingExams()
    const cur = (res.data || []).find(r => String(r.recordId) === recordId.value)
    if (cur) {
      exam.value = cur
      notFound.value = false
    } else if (!exam.value) {
      notFound.value = true
    }
  } catch (e) {
    notify('考试信息加载失败')
  }
}

async function connect() {
  if (!recordId.value || room) return
  connecting.value = true
  try {
    const res = await getExamProctorToken(recordId.value)
    const info = res.data || {}
    room = new Room()
    room.on(RoomEvent.TrackSubscribed, onTrack)
    room.on(RoomEvent.TrackUnsubscribed, onTrackOff)
    room.on(RoomEvent.ParticipantConnected, syncPresence)
    room.on(RoomEvent.ParticipantDisconnected, syncPresence)
    await room.connect(info.url, info.token)
    syncPresence()
  } catch (e) {
    notify('监考连接失败：' + (e?.message || '请检查 LiveKit 服务'))
  } finally {
    connecting.value = false
  }
}

function kindOf(identity) {
  if (!identity) return null
  if (identity.startsWith('exam-main-')) return 'main'
  if (identity.startsWith('exam-sub-')) return 'sub'
  return null
}

function onTrack(track, publication, participant) {
  const slot = kindOf(participant.identity)
  if (!slot || track.kind !== Track.Kind.Video) return
  const el = slot === 'main' ? mainVideo.value : subVideo.value
  if (el) track.attach(el)
  if (slot === 'main') mainOnline.value = true
  else subOnline.value = true
}

function onTrackOff(track, publication, participant) {
  const slot = kindOf(participant.identity)
  if (slot === 'main') mainOnline.value = false
  else if (slot === 'sub') subOnline.value = false
}

// 依据房间内已有发布者同步在线状态（处理进入前已发布的情况）
function syncPresence() {
  if (!room) return
  let m = false
  let s = false
  room.remoteParticipants.forEach(p => {
    const slot = kindOf(p.identity)
    const hasVideo = p.getTrackPublication && Array.from(p.trackPublications.values())
      .some(pub => pub.source === Track.Source.Camera && pub.track)
    if (slot === 'main' && hasVideo) m = true
    if (slot === 'sub' && hasVideo) s = true
  })
  mainOnline.value = m
  subOnline.value = s
}

async function teardown() {
  if (room) {
    room.removeAllListeners?.()
    try { await room.disconnect() } catch (e) { /* ignore */ }
    room = null
  }
  mainOnline.value = false
  subOnline.value = false
}

onMounted(async () => {
  await loadExam()
  if (!notFound.value) connect()
  // 轮询考试状态：场次结束后提示并返回列表
  pollTimer = setInterval(async () => {
    const before = !!exam.value
    await loadExam()
    if (before && !exam.value && !notFound.value) {
      notFound.value = true
      await teardown()
      notify('本场考试已结束')
    }
  }, 8000)
})
onBeforeUnmount(() => {
  if (pollTimer) clearInterval(pollTimer)
  teardown()
})
</script>

<template>
  <div class="page room-page">
    <div class="page-heading">
      <div>
        <h1><ShieldCheck :size="20" /> 监考 room · {{ exam?.candidateName || (notFound ? '考试不存在' : '加载中') }}</h1>
        <p>实时查看考生主机位（电脑摄像头）与副机位（手机扫码）两路画面</p>
      </div>
      <div class="head-ops">
        <button class="btn" @click="loadExam"><RotateCw :size="15" />刷新</button>
        <button class="btn" @click="router.push('/enterprise/exam/proctor')"><ArrowLeft :size="15" />返回列表</button>
      </div>
    </div>

    <div v-if="notFound" class="card empty-card">
      <Video :size="30" />
      <p>该考试不在进行中列表（可能已交卷或结束）</p>
      <button class="btn primary" @click="router.push('/enterprise/exam/proctor')">返回监考列表</button>
    </div>
    <template v-else-if="exam">
      <div class="detail-grid">
        <div><label>考生</label><b>{{ exam.candidateName }}</b></div>
        <div><label>应聘岗位</label><b>{{ exam.positionTitle }}</b></div>
        <div><label>考试试卷</label><b>{{ exam.paperName || '--' }}</b></div>
        <div><label>开考时间</label><b>{{ fmt(exam.startAt) }}</b></div>
        <div><label>截止时间</label><b>{{ fmt(exam.deadlineAt) }}</b></div>
        <div><label>双机位要求</label><b :class="Number(exam.forceDualCamera) === 1 ? 'danger' : ''">{{ Number(exam.forceDualCamera) === 1 ? '强制开启' : '不强制' }}</b></div>
      </div>
      <div class="tiles">
        <figure class="tile">
          <video ref="mainVideo" class="tile-video" autoplay muted playsinline></video>
          <div v-if="!mainOnline" class="tile-mask">
            <Camera :size="22" />
            <span>{{ connecting ? '连接中...' : '主机位未接入' }}</span>
          </div>
          <figcaption><i :class="['dot', mainOnline ? 'on' : '']"></i>主机位 · 电脑摄像头</figcaption>
        </figure>
        <figure class="tile">
          <video ref="subVideo" class="tile-video" autoplay muted playsinline></video>
          <div v-if="!subOnline" class="tile-mask">
            <Video :size="22" />
            <span>{{ connecting ? '连接中...' : '副机位未接入' }}</span>
          </div>
          <figcaption><i :class="['dot', subOnline ? 'on' : '']"></i>副机位 · 手机扫码</figcaption>
        </figure>
      </div>
      <p class="view-tip">副机位需考生用手机扫描答题页二维码加入；两路画面均为实时直播，断网时显示未接入。</p>
    </template>
    <div v-else class="card empty-card">加载中...</div>

    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.room-page{padding-bottom:30px}
.page-heading{display:flex;justify-content:space-between;align-items:flex-end;gap:16px;margin-bottom:18px}
.page-heading h1{font-size:22px;display:flex;align-items:center;gap:8px}
.page-heading p{font-size:12px;color:var(--muted);margin-top:5px}
.head-ops{display:flex;gap:8px}
.empty-card{padding:70px 20px;text-align:center;color:var(--subtle);font-size:13px;display:flex;flex-direction:column;align-items:center;gap:14px}
.empty-card p{margin:0}
.detail-grid{display:grid;grid-template-columns:repeat(6,1fr);gap:10px;margin-bottom:16px}
.detail-grid>div{background:var(--card,#fff);border:1px solid var(--line);border-radius:11px;padding:11px 13px;display:flex;flex-direction:column;gap:4px}
.detail-grid label{font-size:10.5px;color:var(--subtle)}
.detail-grid b{font-size:13px;color:#1a3c6e;font-weight:600}
.detail-grid b.danger{color:var(--red)}
.tiles{display:grid;grid-template-columns:1fr 1fr;gap:16px}
.tile{margin:0;position:relative;border:1px solid var(--line);border-radius:14px;overflow:hidden;background:#0f1722}
.tile-video{width:100%;aspect-ratio:16/9;object-fit:cover;display:block;background:#0f1722}
.tile-mask{position:absolute;inset:0 0 38px 0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;color:#8fa1b8;background:#0f1722;font-size:12px}
.tile figcaption{height:38px;display:flex;align-items:center;gap:7px;padding:0 13px;color:#c7d3e3;background:#16202e;font-size:12px}
.dot{width:8px;height:8px;border-radius:50%;background:#5a6c88}
.dot.on{background:#3dd68c;box-shadow:0 0 0 3px rgba(61,214,140,.2)}
.view-tip{margin:14px 0 0;color:var(--subtle);font-size:11.5px;line-height:1.6}
@media(max-width:1100px){.detail-grid{grid-template-columns:repeat(3,1fr)}}
@media(max-width:900px){.tiles{grid-template-columns:1fr}}
</style>
