<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowLeft, Camera, Video, ShieldCheck, Clock3, RotateCw } from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listOngoingExams, getExamProctorToken } from '@/api/exam'
import { Room, RoomEvent, Track } from 'livekit-client'

const router = useRouter()
const toast = ref('')
function notify(m) { toast.value = m; setTimeout(() => { toast.value = '' }, 2400) }

const list = ref([])
const loading = ref(false)
const selected = ref(null)
const connecting = ref(false)
const mainOnline = ref(false)
const subOnline = ref(false)
const mainVideo = ref(null)
const subVideo = ref(null)

let room = null
let pollTimer = null

async function loadList() {
  loading.value = true
  try {
    const res = await listOngoingExams()
    list.value = res.data || []
    if (selected.value) {
      const cur = list.value.find(r => String(r.recordId) === String(selected.value.recordId))
      if (cur) selected.value = cur
    }
  } catch (e) {
    notify('加载监考列表失败')
  } finally {
    loading.value = false
  }
}

function fmt(t) { return t ? String(t).replace('T', ' ').slice(5, 16) : '--' }

async function openProctor(row) {
  if (selected.value && String(selected.value.recordId) === String(row.recordId)) return
  await teardown()
  selected.value = row
  mainOnline.value = false
  subOnline.value = false
  connecting.value = true
  try {
    const res = await getExamProctorToken(row.recordId)
    const info = res.data || {}
    room = new Room()
    room.on(RoomEvent.TrackSubscribed, onTrack)
    room.on(RoomEvent.TrackUnsubscribed, onTrackOff)
    room.on(RoomEvent.ParticipantConnected, syncPresence)
    room.on(RoomEvent.ParticipantDisconnected, syncPresence)
    await room.connect(info.url, info.token)
    syncPresence()
    connecting.value = false
  } catch (e) {
    connecting.value = false
    notify('监考连接失败：' + (e?.message || '请检查 LiveKit 服务'))
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

async function closeProctor() {
  await teardown()
  selected.value = null
}

onMounted(() => {
  loadList()
  pollTimer = setInterval(loadList, 8000)
})
onBeforeUnmount(() => {
  if (pollTimer) clearInterval(pollTimer)
  teardown()
})
</script>

<template>
  <div class="page proctor-page">
    <div class="page-heading">
      <div>
        <h1><ShieldCheck :size="20" /> 双机位监考</h1>
        <p>实时查看考生主机位（电脑摄像头）与副机位（手机扫码）两路画面</p>
      </div>
      <div class="head-ops">
        <button class="btn" @click="loadList"><RotateCw :size="15" />刷新</button>
        <button class="btn" @click="router.back()"><ArrowLeft :size="15" />返回</button>
      </div>
    </div>

    <div class="split">
      <!-- 左：进行中列表 -->
      <section class="card panel list-panel">
        <div class="panel-title">进行中的考试 <span class="count">{{ list.length }}</span></div>
        <div v-if="loading && !list.length" class="empty">正在加载...</div>
        <div v-else-if="!list.length" class="empty">当前没有进行中的笔试</div>
        <ul v-else class="cand-list">
          <li v-for="row in list" :key="row.recordId"
              :class="['cand-item', { on: selected && String(selected.recordId) === String(row.recordId) }]"
              @click="openProctor(row)">
            <div class="cand-top">
              <strong>{{ row.candidateName }}</strong>
              <span :class="['pill', 'sm', row.subOnline ? 'green' : 'gray']">
                副机位{{ row.subOnline ? '在线' : '未接入' }}
              </span>
            </div>
            <div class="cand-sub">{{ row.positionTitle }} · {{ row.paperName }}</div>
            <div class="cand-time"><Clock3 :size="12" />{{ fmt(row.startAt) }} 开考 · {{ fmt(row.deadlineAt) }} 截止</div>
            <div v-if="Number(row.forceDualCamera) === 1" class="cand-force">本场要求双机位</div>
          </li>
        </ul>
      </section>

      <!-- 右：双画面 -->
      <section class="card panel view-panel">
        <div v-if="!selected" class="empty big">
          <Video :size="30" />
          <p>从左侧选择考生查看双机位画面</p>
        </div>
        <template v-else>
          <div class="view-head">
            <div>
              <strong>{{ selected.candidateName }}</strong>
              <span>{{ selected.positionTitle }}</span>
            </div>
            <button class="btn slim" @click="closeProctor">关闭监考</button>
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
      </section>
    </div>

    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.proctor-page{padding-bottom:30px}
.page-heading{display:flex;justify-content:space-between;align-items:flex-end;gap:16px;margin-bottom:18px}
.page-heading h1{font-size:22px;display:flex;align-items:center;gap:8px}
.page-heading p{font-size:12px;color:var(--muted);margin-top:5px}
.head-ops{display:flex;gap:8px}
.split{display:grid;grid-template-columns:320px minmax(0,1fr);gap:16px;align-items:start}
.panel{padding:16px}
.panel-title{font-size:14px;font-weight:700;color:var(--primary);margin-bottom:12px}
.panel-title .count{margin-left:6px;padding:1px 8px;border-radius:10px;background:#eef3fa;color:var(--subtle);font-size:11px}
.empty{padding:26px 12px;text-align:center;color:var(--subtle);font-size:13px}
.empty.big{padding:70px 12px;display:flex;flex-direction:column;align-items:center;gap:12px}
.empty.big p{margin:0}
.cand-list{list-style:none;margin:0;padding:0}
.cand-item{padding:11px 12px;border:1px solid var(--line);border-radius:11px;margin-bottom:9px;cursor:pointer;transition:border-color .15s,background .15s}
.cand-item:hover{border-color:#b7caec}
.cand-item.on{border-color:var(--primary);background:#f3f8ff}
.cand-top{display:flex;justify-content:space-between;align-items:center;gap:8px}
.cand-top strong{font-size:14px;color:#1a3c6e}
.cand-sub{margin-top:5px;color:var(--muted);font-size:11.5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.cand-time{display:flex;align-items:center;gap:5px;margin-top:5px;color:var(--subtle);font-size:11px}
.cand-force{margin-top:5px;color:var(--red);font-size:10.5px;font-weight:600}
.view-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:14px}
.view-head>div{display:flex;flex-direction:column;gap:3px}
.view-head strong{font-size:16px;color:#1a3c6e}
.view-head span{font-size:11.5px;color:var(--muted)}
.btn.slim{height:30px;padding:0 13px;font-size:12px}
.tiles{display:grid;grid-template-columns:1fr 1fr;gap:14px}
.tile{margin:0;position:relative;border:1px solid var(--line);border-radius:13px;overflow:hidden;background:#0f1722}
.tile-video{width:100%;aspect-ratio:16/9;object-fit:cover;display:block;background:#0f1722}
.tile-mask{position:absolute;inset:0 0 34px 0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;color:#8fa1b8;background:#0f1722;font-size:12px}
.tile figcaption{height:34px;display:flex;align-items:center;gap:7px;padding:0 12px;color:#c7d3e3;background:#16202e;font-size:12px}
.dot{width:8px;height:8px;border-radius:50%;background:#5a6c88}
.dot.on{background:#3dd68c;box-shadow:0 0 0 3px rgba(61,214,140,.2)}
.view-tip{margin:14px 0 0;color:var(--subtle);font-size:11.5px;line-height:1.6}
@media(max-width:1080px){.split{grid-template-columns:1fr}.tiles{grid-template-columns:1fr}}
</style>
