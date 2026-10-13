<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  ArrowLeft, Play, Pause, Volume2, Maximize, Download, FileText,
  Clock3, UserRound, BriefcaseBusiness, Timer, CalendarDays, ShieldCheck
} from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { getPlayback } from '@/api/system/conference'

const route = useRoute()
const router = useRouter()
const toast = ref('')

const record = ref({
  id: route.query.id ? String(route.query.id) : '',
  candidate: '',
  position: '',
  date: '',
  mode: '',
  duration: 0,
  interviewers: ''
})

const playerRef = ref(null)
const videoRef = ref(null)
// 真实录制文件地址（/profile/upload/... 相对路径），为空时展示占位
const recUrl = ref('')
// 录制文件加载失败（外链失效 / 文件丢失）标记，触发后降级为占位提示
const loadFailed = ref(false)
const playing = ref(false)
const current = ref(0)
const volume = ref(80)
const rate = ref(1)
const rateOpen = ref(false)
const rates = [0.5, 0.75, 1, 1.25, 1.5, 2]

// 资源相对路径拼接后端基地址（dev 走 /dev-api 代理，生产走同域反代）
function assetUrl(url) {
  if (!url) return ''
  return url.startsWith('http') ? url : import.meta.env.VITE_APP_BASE_API + url
}

// 问答时间线与问答记录：均由后端 t_int_dialogue 实时返回，无数据时为空
const chapters = ref([])

const qa = ref([])

let timerId = null

const percent = computed(() => (record.value.duration > 0 ? (current.value / record.value.duration) * 100 : 0))
const fmt = (value) => {
  const v = Math.max(0, Math.floor(value))
  const m = String(Math.floor(v / 60)).padStart(2, '0')
  const s = String(v % 60).padStart(2, '0')
  return `${m}:${s}`
}

function toggle() {
  const v = videoRef.value
  if (!v || !recUrl.value) return
  if (v.paused) v.play().catch(() => notify('播放失败，请重试'))
  else v.pause()
}

function onTimeUpdate() {
  const v = videoRef.value
  if (!v) return
  current.value = v.currentTime
  if (!Number.isNaN(v.duration) && v.duration > 0) record.value.duration = Math.round(v.duration)
}

function onEnded() {
  playing.value = false
}

// 视频加载/解码失败：标记失败并降级为占位提示（外链失效、文件丢失等）
function onVideoError() {
  loadFailed.value = true
  playing.value = false
}

function seek(event) {
  const rect = event.currentTarget.getBoundingClientRect()
  const ratio = Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width))
  const v = videoRef.value
  if (v && v.duration) v.currentTime = ratio * v.duration
  else current.value = Math.round(ratio * record.value.duration)
}

function jump(seconds) {
  const v = videoRef.value
  if (v && v.duration) v.currentTime = seconds
  current.value = seconds
  notify(`已跳转至 ${fmt(seconds)}`)
}

function setRate(value) {
  rate.value = value
  rateOpen.value = false
  const v = videoRef.value
  if (v) v.playbackRate = value
  notify(`播放速度 ${value}x`)
}

function setVolume() {
  const v = videoRef.value
  if (v) v.volume = volume.value / 100
}

function toggleFullscreen() {
  const node = playerRef.value
  if (!node) return
  if (document.fullscreenElement) document.exitFullscreen()
  else node.requestFullscreen?.()
}

function notify(msg) {
  toast.value = msg
  setTimeout(() => (toast.value = ''), 2000)
}

// 面试模式数值转展示文案（1-纯AI，2-AI+单面试官，3-AI+多面试官，4-无AI纯人工）
function modeLabel(mode) {
  switch (Number(mode)) {
    case 1: return '纯 AI 面试'
    case 2: return 'AI + HR 协同'
    case 3: return 'AI + 多面试官'
    case 4: return '无 AI · 纯人工'
    default: return ''
  }
}

// 拉取回放详情，页面展示字段全部来自后端真实数据
async function initPlayback() {
  const id = route.query.id
  if (!id) return
  try {
    const res = await getPlayback(id)
    const d = res.data
    if (!d) return
    recUrl.value = d.recUrl || ''
    loadFailed.value = false
    record.value.duration = d.durationSec || 0
    record.value.candidate = d.candidateName || ''
    record.value.position = d.positionTitle || ''
    record.value.date = d.interviewDate || ''
    record.value.mode = modeLabel(d.mode)
    if (Array.isArray(d.interviewers) && d.interviewers.length > 0) {
      record.value.interviewers = d.interviewers.map((i) => i.userName).filter(Boolean).join(' · ')
    }
    const date = d.interviewDate || ''
    record.value.id = `REC-${date.replaceAll('-', '')}-${String(d.sessionId).padStart(3, '0')}`
    chapters.value = Array.isArray(d.chapters) ? d.chapters.map((c) => ({
      label: c.title && c.title.length > 16 ? `${c.title.slice(0, 16)}…` : c.title,
      t: c.second
    })) : []
    // 后端不返回评分，用占位符避免 UI 出现空白
    qa.value = Array.isArray(d.qa) ? d.qa.map((q) => ({ t: q.second, q: q.title, score: '—' })) : []
  } catch (e) {
    // 无后端数据时保留 mock
  }
}

onMounted(() => {
  document.addEventListener('click', closeRate)
  initPlayback()
})
onBeforeUnmount(() => {
  document.removeEventListener('click', closeRate)
})

function closeRate(event) {
  if (!event.target.closest('.rate-box')) rateOpen.value = false
}
</script>

<template>
  <div class="console-page">
    <header class="topbar">
      <div class="bar">
        <button class="btn sm" @click="router.push('/enterprise/conference/records')">
          <ArrowLeft :size="15" />返回列表
        </button>
        <div class="head">
          <strong>在线回放</strong>
          <small class="muted">{{ record.id }} · {{ record.candidate }} · {{ record.position }}</small>
        </div>
        <div class="head-actions">
          <button class="btn sm" @click="notify('下载需短信二次验证，请前往录制列表操作')"><Download :size="15" />下载</button>
          <button class="btn sm" @click="notify('已打开面试评估报告')"><FileText :size="15" />评估报告</button>
        </div>
      </div>
    </header>

    <main class="page">
      <div class="layout">
        <section class="player-col">
          <div ref="playerRef" class="player">
            <video
              v-if="recUrl && !loadFailed"
              ref="videoRef"
              class="rec-video"
              :src="assetUrl(recUrl)"
              preload="metadata"
              @error="onVideoError"
              @timeupdate="onTimeUpdate"
              @playing="playing = true"
              @pause="playing = false"
              @ended="onEnded"
            />
            <div v-else class="no-rec">{{ loadFailed ? '录制文件加载失败（可能已过期或外链失效）' : '该场次暂无录制文件' }}</div>
            <span class="badge-rec"><i />录制回放</span>
            <button v-if="recUrl && !loadFailed" class="center-play" :class="{ hidden: playing }" @click="toggle">
              <Play :size="30" />
            </button>

            <div v-if="recUrl && !loadFailed" class="controls">
              <button class="c-btn" @click="toggle">
                <Pause v-if="playing" :size="20" /><Play v-else :size="20" />
              </button>
              <span class="time">{{ fmt(current) }} / {{ fmt(record.duration) }}</span>
              <div class="seek" @click="seek">
                <div class="seek-track">
                  <u :style="{ width: percent + '%' }" />
                  <em v-for="c in chapters" :key="c.t" :style="{ left: (c.t / record.duration * 100) + '%' }" />
                </div>
              </div>
              <div class="rate-box">
                <button class="c-btn rate" @click.stop="rateOpen = !rateOpen">{{ rate }}x</button>
                <div v-if="rateOpen" class="rate-menu">
                  <button v-for="r in rates" :key="r" :class="{ active: r === rate }" @click.stop="setRate(r)">{{ r }}x</button>
                </div>
              </div>
              <div class="volume">
                <Volume2 :size="18" />
                <input v-model.number="volume" type="range" min="0" max="100" @input="setVolume" />
              </div>
              <button class="c-btn" title="全屏" @click="toggleFullscreen"><Maximize :size="19" /></button>
            </div>
          </div>

          <div class="card chapters">
            <h2>问答时间线</h2>
            <div class="chapter-list">
              <button v-for="c in chapters" :key="c.t" class="chapter" :class="{ active: current >= c.t }" @click="jump(c.t)">
                <span class="ts">{{ fmt(c.t) }}</span>
                <span class="label">{{ c.label }}</span>
              </button>
            </div>
          </div>
        </section>

        <aside class="side">
          <section class="card info">
            <h2>面试信息</h2>
            <div class="row"><UserRound :size="15" /><span>候选人</span><b>{{ record.candidate }}</b></div>
            <div class="row"><BriefcaseBusiness :size="15" /><span>岗位</span><b>{{ record.position }}</b></div>
            <div class="row"><CalendarDays :size="15" /><span>面试时间</span><b>{{ record.date }}</b></div>
            <div class="row"><Timer :size="15" /><span>面试时长</span><b>{{ fmt(record.duration) }}</b></div>
            <div class="row"><ShieldCheck :size="15" /><span>面试模式</span><b>{{ record.mode }}</b></div>
            <div class="row"><Clock3 :size="15" /><span>面试官</span><b>{{ record.interviewers }}</b></div>
          </section>

          <section class="card qa">
            <h2>问答记录 <span class="muted tiny">点击跳转</span></h2>
            <div v-for="item in qa" :key="item.t" class="qa-item" @click="jump(item.t)">
              <span class="ts">{{ fmt(item.t) }}</span>
              <p>{{ item.q }}</p>
              <b :class="item.score >= 90 ? 'good' : ''">{{ item.score }}</b>
            </div>
          </section>
        </aside>
      </div>
    </main>

    <ToastMessage :message="toast" />
  </div>
</template>

<style src="../enterprise.css"></style>

<style scoped>
.console-page { min-height: 100vh; background: var(--canvas); }
.topbar { height: 64px; background: #fff; border-bottom: 1px solid var(--line); display: flex; align-items: center; }
.bar { width: min(1320px, calc(100% - 48px)); margin: auto; display: flex; align-items: center; gap: 14px; }
.head strong { display: block; font-size: 16px; }
.head small { font-size: 12px; }
.head-actions { margin-left: auto; display: flex; gap: 8px; }
.page { width: min(1320px, calc(100% - 48px)); margin: auto; padding: 22px 0 40px; }
.layout { display: grid; grid-template-columns: minmax(0, 1fr) 340px; gap: 16px; }

.player { position: relative; aspect-ratio: 16 / 9; border-radius: 16px; overflow: hidden; background: #0b0f18; box-shadow: 0 20px 50px rgba(15, 23, 42, .28); }
.player:fullscreen { border-radius: 0; aspect-ratio: auto; height: 100%; }
.rec-video { width: 100%; height: 100%; object-fit: contain; display: block; background: #0b0f18; }
.no-rec { width: 100%; height: 100%; display: grid; place-items: center; color: #8fa1bd; font-size: 14px; background: #0b0f18; }
.badge-rec {
  position: absolute; left: 14px; top: 14px;
  height: 26px; padding: 0 11px;
  display: inline-flex; align-items: center; gap: 6px;
  border-radius: 999px; background: rgba(9, 14, 24, .62); color: #fff; font-size: 12px;
}
.badge-rec i { width: 7px; height: 7px; border-radius: 50%; background: #ff4d4f; }
.center-play {
  position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%);
  width: 72px; height: 72px; border: 0; border-radius: 50%;
  background: rgba(37, 99, 235, .92); color: #fff;
  display: grid; place-items: center;
  box-shadow: 0 14px 34px rgba(0, 0, 0, .4);
  transition: .2s;
}
.center-play:hover { transform: translate(-50%, -50%) scale(1.06); }
.center-play.hidden { opacity: 0; pointer-events: none; }

.controls {
  position: absolute; left: 0; right: 0; bottom: 0;
  height: 62px; padding: 0 16px;
  display: flex; align-items: center; gap: 12px;
  background: linear-gradient(180deg, rgba(11, 15, 24, 0), rgba(11, 15, 24, .88) 42%);
  color: #fff;
}
.c-btn { width: 36px; height: 36px; border: 0; border-radius: 9px; background: rgba(255, 255, 255, .12); color: #fff; display: grid; place-items: center; }
.c-btn:hover { background: rgba(255, 255, 255, .22); }
.c-btn.rate { width: auto; padding: 0 10px; font-size: 13px; font-weight: 600; }
.time { font-size: 12px; font-variant-numeric: tabular-nums; color: #cfd8e6; }
.seek { flex: 1; height: 22px; display: flex; align-items: center; cursor: pointer; }
.seek-track { position: relative; width: 100%; height: 4px; border-radius: 999px; background: rgba(255, 255, 255, .24); }
.seek-track u { display: block; height: 100%; border-radius: inherit; background: #3b82f6; }
.seek-track em { position: absolute; top: 50%; width: 3px; height: 11px; border-radius: 2px; background: rgba(255, 255, 255, .7); transform: translate(-50%, -50%); }
.rate-box { position: relative; }
.rate-menu {
  position: absolute; bottom: calc(100% + 8px); right: 0;
  min-width: 88px; padding: 6px;
  border-radius: 10px; background: #161c28; border: 1px solid rgba(255, 255, 255, .12);
  display: grid; gap: 2px;
}
.rate-menu button { height: 28px; border: 0; border-radius: 7px; background: transparent; color: #cfd8e6; font-size: 12px; }
.rate-menu button:hover { background: rgba(255, 255, 255, .1); }
.rate-menu button.active { background: var(--primary); color: #fff; }
.volume { display: flex; align-items: center; gap: 7px; color: #cfd8e6; }
.volume input { width: 76px; accent-color: #3b82f6; }

.chapters { margin-top: 16px; padding: 18px 20px; }
.chapters h2 { font-size: 16px; margin-bottom: 12px; }
.chapter-list { display: flex; flex-wrap: wrap; gap: 9px; }
.chapter {
  display: inline-flex; align-items: center; gap: 8px;
  height: 34px; padding: 0 12px;
  border: 1px solid var(--line); border-radius: 9px;
  background: #fff; color: var(--text); font-size: 13px;
}
.chapter .ts { color: var(--muted); font-variant-numeric: tabular-nums; font-size: 12px; }
.chapter:hover { border-color: #b7caec; }
.chapter.active { border-color: var(--primary); background: var(--primary-soft); color: var(--primary-strong); }

.side { display: grid; gap: 16px; align-content: start; }
.info, .qa { padding: 18px 20px; }
.info h2, .qa h2 { font-size: 16px; margin-bottom: 12px; display: flex; align-items: center; justify-content: space-between; }
.row { display: grid; grid-template-columns: 18px 78px 1fr; align-items: center; gap: 8px; padding: 9px 0; border-bottom: 1px dashed var(--line); font-size: 13px; }
.row:last-child { border-bottom: 0; }
.row svg { color: var(--primary); }
.row span { color: var(--muted); }
.row b { font-weight: 600; text-align: right; }
.qa-item {
  display: grid; grid-template-columns: 46px 1fr auto; gap: 8px; align-items: start;
  padding: 10px 0; border-bottom: 1px dashed var(--line);
  cursor: pointer;
}
.qa-item:last-child { border-bottom: 0; }
.qa-item:hover p { color: var(--primary-strong); }
.qa-item .ts { color: var(--muted); font-size: 12px; font-variant-numeric: tabular-nums; padding-top: 1px; }
.qa-item p { margin: 0; font-size: 13px; line-height: 1.55; }
.qa-item b { color: #d76e00; font-size: 13px; }
.qa-item b.good { color: #07865e; }

@media (max-width: 1080px) {
  .layout { grid-template-columns: 1fr; }
  .volume { display: none; }
}
@media (max-width: 760px) {
  .bar, .page { width: calc(100% - 28px); }
  .head small { display: none; }
}
</style>