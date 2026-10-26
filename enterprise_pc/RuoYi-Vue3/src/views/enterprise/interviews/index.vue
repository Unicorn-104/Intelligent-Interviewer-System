<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { CalendarSync, Sparkles, Clock3, UserRound, ChevronLeft, ChevronRight, CalendarClock, X, Link2, FileText } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import CalendarGrid from '@/views/enterprise/components/CalendarGrid.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listInterviews, rescheduleInterview, remindInterview, updateInterviewStatus, listInterviewerSlots, saveInterviewerSlots } from '@/api/interview'

const router = useRouter()
const calendar = ref()
const dayModal = ref(false)
const freeModal = ref(false)
const toast = ref('')
const activeView = ref('周')
const drawer = ref(null) // 当前打开详情的面试块
const adjustModal = ref(false)
const adjHour = ref(9)
const adjMin = ref(0)
const adjDur = ref(45)
const conflictMsg = ref('')
const conflictType = ref('')
const forceSave = ref(false)

const dayNames = ['周一','周二','周三','周四','周五','周六','周日']
// apt_status：0-待确认，1-已确认，2-已取消，3-已完成
const STATUS_MAP = { 0:'pending', 1:'confirmed', 2:'cancelled', 3:'completed' }
const statusText = { pending:'待确认', confirmed:'已确认', completed:'已完成', conflict:'冲突', cancelled:'已取消' }

const all = ref([])
const weekStart = ref(mondayOf(new Date()))
const dayIndex = ref(-1)

function startOfDay(d){ const x = new Date(d); x.setHours(0,0,0,0); return x }
function mondayOf(d){ const x = startOfDay(d); const wd = (x.getDay()+6)%7; x.setDate(x.getDate()-wd); return x }
function parseDT(s){
  if(!s) return null
  const [date,time] = String(s).split(' ')
  const [y,m,dd] = String(date).split('-').map(Number)
  const [hh,mm] = String(time || '00:00').split(':').map(Number)
  const d = new Date(y, m-1, dd, hh, mm)
  return isNaN(d.getTime()) ? null : d
}
function fmtHM(d){ return String(d.getHours()).padStart(2,'0')+':'+String(d.getMinutes()).padStart(2,'0') }

// 当前展示周内的真实面试块（用 ref 保存，拖拽时可实时移动；数据/周切换时重建）
const blocks = ref([])
function rebuildBlocks(){
  const ws = weekStart.value.getTime()
  const out = []
  for(const a of all.value){
    const start = parseDT(a.startTime)
    if(!start) continue
    const dayIdx = Math.round((startOfDay(start).getTime() - ws) / 86400000)
    if(dayIdx < 0 || dayIdx > 6) continue
    const end = parseDT(a.endTime)
    const durMin = end ? Math.max(15, Math.round((end - start) / 60000)) : 45
    const raw = start.getHours()*60 + start.getMinutes() - 540
    const startMin = Math.max(0, Math.min(540 - durMin, raw))
    out.push({
      id: a.appointmentId, appointmentId: a.appointmentId,
      day: dayIdx, dayName: dayNames[dayIdx],
      dateLabel: (start.getMonth()+1) + '月' + start.getDate() + '日',
      date: start, startMin, durMin,
      candidate: a.candidateName || '未知候选人',
      position: a.positionTitle || '—',
      interviewer: a.interviewerName || '待定',
      status: STATUS_MAP[a.status] || 'pending',
      meetingUrl: a.meetingUrl || '',
      sessionId: a.sessionId || null,
      hrStatus: a.hrStatus == null ? null : Number(a.hrStatus),
      time: fmtHM(start) + '-' + fmtHM(end || new Date(start.getTime() + durMin*60000))
    })
  }
  blocks.value = out
}
watch([all, weekStart], rebuildBlocks)

const weekDates = computed(() => Array.from({ length: 7 }, (_, i) => {
  const d = new Date(weekStart.value); d.setDate(d.getDate() + i); return d.getDate()
}))
const todayIndex = computed(() => {
  const i = Math.round((startOfDay(new Date()).getTime() - weekStart.value.getTime()) / 86400000)
  return (i >= 0 && i <= 6) ? i : -1
})
const weekLabel = computed(() => {
  const s = weekStart.value, e = new Date(s); e.setDate(e.getDate() + 6)
  return `${s.getFullYear()}年${s.getMonth()+1}月${s.getDate()}日 – ${e.getMonth()+1}月${e.getDate()}日`
})

// 同一时间段只保留一场面试（取最早的一场作为日历代表），其余归入「等待安排」
const slotLayout = computed(() => {
  const visible = [], waiting = []
  for(let d = 0; d < 7; d++){
    const day = blocks.value
      .filter(b => b.day === d && b.status !== 'cancelled' && !b.pending)
      .sort((a,b) => a.startMin - b.startMin || a.id - b.id)
    let repEnd = -1
    for(const b of day){
      if(b.startMin < repEnd){ waiting.push(b) }
      else { visible.push(b); repEnd = b.startMin + b.durMin }
    }
  }
  // 待调整的场次始终留在日历上，避免被去重挤出后「消失」
  blocks.value.filter(b => b.pending && b.status !== 'cancelled').forEach(b => visible.push(b))
  return { visible, waiting }
})
const visibleBlocks = computed(() => slotLayout.value.visible)
const recommendations = computed(() => visibleBlocks.value.slice().sort((a,b) => a.day - b.day || a.startMin - b.startMin))
const waitingList = computed(() => [...blocks.value.filter(s => s.status === 'cancelled'), ...slotLayout.value.waiting])

const dayStats = computed(() => {
  const list = visibleBlocks.value.filter(b => b.day === dayIndex.value)
  const c = { total: list.length, pending:0, confirmed:0, cancelled:0, completed:0 }
  list.forEach(b => { if(c[b.status] !== undefined) c[b.status]++ })
  return c
})
const dayLabel = computed(() => {
  if(dayIndex.value < 0) return ''
  const d = new Date(weekStart.value); d.setDate(d.getDate() + dayIndex.value)
  return `${d.getMonth()+1}月${d.getDate()}日 ${dayNames[dayIndex.value]}`
})
// 空闲时间设置：展示当前周的周一~周五日期
const weekOptions = computed(() => Array.from({ length: 5 }, (_, i) => {
  const d = new Date(weekStart.value); d.setDate(d.getDate() + i)
  const pad = n => String(n).padStart(2,'0')
  return `${dayNames[i]} ${pad(d.getMonth()+1)}/${pad(d.getDate())}`
}))

function notify(msg){ toast.value = msg; setTimeout(() => toast.value = '', 2200) }

async function load(){
  try{
    const res = await listInterviews({ pageNum: 1, pageSize: 200 })
    all.value = res.rows || []
  }catch(e){ all.value = [] }
}
function shiftWeek(delta){ const d = new Date(weekStart.value); d.setDate(d.getDate() + delta*7); weekStart.value = d }
function goToday(){ weekStart.value = mondayOf(new Date()) }
function openDay(i){ dayIndex.value = i; dayModal.value = true }

// 已结束场次进入 HR 终审评估页
function openEvaluation(){
  if(!drawer.value?.sessionId) return
  const sessionId = drawer.value.sessionId
  drawer.value = null
  router.push(`/enterprise/interviews/${sessionId}/evaluation`)
}

// 确认/取消面试安排：真实落库（apt_status 1-已确认 / 2-已取消），刷新后仍保留
async function confirmInterview(){
  if(!drawer.value) return
  const id = drawer.value.appointmentId
  try{
    await updateInterviewStatus(id, 1)
    drawer.value = null
    notify('已确认该面试安排')
    await load()
  }catch(e){ /* 拦截器已提示 */ }
}
async function cancelInterview(){
  if(!drawer.value) return
  const id = drawer.value.appointmentId
  try{
    await updateInterviewStatus(id, 2)
    drawer.value = null
    notify('已取消该面试安排')
    await load()
  }catch(e){ /* 拦截器已提示 */ }
}

function openAdjust(item){
  const target = item && item.startMin !== undefined ? item : drawer.value
  if(!target){ notify('请先选择面试'); return }
  drawer.value = target
  const startMin = target.startMin || 0
  adjHour.value = Math.floor(startMin/60) + 9
  adjMin.value = startMin % 60
  adjDur.value = target.durMin || 45
  conflictMsg.value = ''
  conflictType.value = ''
  forceSave.value = false
  adjustModal.value = true
}

function checkConflict(newStartMin, newDur, self){
  const newEnd = newStartMin + newDur
  for(const s of blocks.value){
    if(s.id === self.id) continue
    if(s.day !== self.day) continue
    const sEnd = s.startMin + s.durMin
    if(newStartMin < sEnd && s.startMin < newEnd){
      return { type:'error', msg:`与 ${s.candidate} 的面试时间重叠（${s.time}）` }
    }
    const gap1 = s.startMin - newEnd
    const gap2 = newStartMin - sEnd
    if(gap1 > 0 && gap1 < 15) return { type:'warning', msg:`与 ${s.candidate} 的面试仅间隔 ${gap1} 分钟（建议≥15分钟）` }
    if(gap2 > 0 && gap2 < 15) return { type:'warning', msg:`与 ${s.candidate} 的面试仅间隔 ${gap2} 分钟（建议≥15分钟）` }
  }
  return null
}

async function saveAdjust(){
  const newStartMin = (adjHour.value-9)*60 + adjMin.value
  if(newStartMin + adjDur.value > 540){ notify('结束时间超过18:00'); return }
  const result = checkConflict(newStartMin, adjDur.value, drawer.value)
  if(result && result.type === 'error'){ conflictMsg.value = result.msg; conflictType.value = 'error'; return }
  if(result && result.type === 'warning' && !forceSave.value){ conflictMsg.value = result.msg; conflictType.value = 'warning'; return }
  // 真实改期：按当前展示周 + 目标星期拼装 yyyy-MM-dd HH:mm:ss
  const d = new Date(weekStart.value); d.setDate(d.getDate() + drawer.value.day)
  const pad = n => String(n).padStart(2,'0')
  const newStartTime = `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(adjHour.value)}:${pad(adjMin.value)}:00`
  try{
    await rescheduleInterview(drawer.value.appointmentId, newStartTime)
    adjustModal.value = false
    forceSave.value = false
    const name = drawer.value.candidate
    drawer.value = null
    notify(`${name} 的面试时间已调整`)
    await load()
  }catch(e){ /* 拦截器已提示 */ }
}

// 空闲时间：读取/保存到 t_sch_slot（按当前展示周）
const freeSlots = ref(dayNames.map(() => ({ enabled: false, start: '09:00', end: '18:00' })))
const freeSaving = ref(false)

function pad2(n) { return String(n).padStart(2, '0') }
function dateStrOf(dayIdx) {
  const d = new Date(weekStart.value)
  d.setDate(d.getDate() + dayIdx)
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
}
const weekDayLabels = computed(() => dayNames.map((label, i) => {
  const d = new Date(weekStart.value); d.setDate(d.getDate() + i)
  return `${label} ${d.getMonth() + 1}/${d.getDate()}`
}))

async function openFreeModal() {
  freeSlots.value = dayNames.map(() => ({ enabled: false, start: '09:00', end: '18:00' }))
  freeModal.value = true
  try {
    const res = await listInterviewerSlots(dateStrOf(0))
    const rows = res.data || []
    for (const row of rows) {
      const start = String(row.startTime || '')
      const end = String(row.endTime || '')
      const dayIdx = dayNames.findIndex((_, i) => start.startsWith(dateStrOf(i)))
      if (dayIdx < 0) continue
      const item = freeSlots.value[dayIdx]
      item.enabled = true
      item.start = start.slice(11, 16) || item.start
      item.end = end.slice(11, 16) || item.end
    }
  } catch (e) { /* 拦截器已提示 */ }
}

async function saveFree() {
  const slots = []
  freeSlots.value.forEach((item, i) => {
    if (!item.enabled) return
    if (item.start >= item.end) { notify(`第 ${i + 1} 天的结束时间需晚于开始时间`); return }
    slots.push({ startTime: `${dateStrOf(i)} ${item.start}:00`, endTime: `${dateStrOf(i)} ${item.end}:00` })
  })
  freeSaving.value = true
  try {
    const res = await saveInterviewerSlots(dateStrOf(0), slots)
    freeModal.value = false
    notify(res.data?.message || '空闲时间已保存')
  } catch (e) { /* 拦截器已提示 */ } finally {
    freeSaving.value = false
  }
}

// === 拖拽调整：拖动时实时移动并把该块标记为「待调整」（紫色），确认后统一落库并通知，不再每次弹窗 ===
function clockLabel(item, startMin){
  const s = 540 + startMin, e = s + (item.durMin || 45)
  const fmt = m => String(Math.floor(m/60)).padStart(2,'0') + ':' + String(m%60).padStart(2,'0')
  return fmt(s) + '-' + fmt(e)
}
const pendingList = computed(() => blocks.value.filter(b => b.pending))

// 拖动开始：记录原位并标记为待调整，使其不被日历「同一时段只留一场」的去重挤出（避免拖拽后消失）
function onDragStart(item){
  if(item._fromDay === undefined){ item._fromDay = item.day; item._fromStartMin = item.startMin }
  item.pending = true
}
function onDragEnd({ item, moved }){
  if(!moved){ item.pending = false; item._fromDay = undefined; item._fromStartMin = undefined }
}
function cancelPending(){
  pendingList.value.forEach(b => {
    if(b._fromDay !== undefined) b.day = b._fromDay
    if(b._fromStartMin !== undefined) b.startMin = b._fromStartMin
    b.dayName = dayNames[b.day]
    b.time = clockLabel(b, b.startMin)
    b.pending = false
    b._fromDay = undefined
    b._fromStartMin = undefined
  })
  notify('已放弃未确认的时间调整')
}
async function confirmPending(){
  const list = pendingList.value.slice()
  if(!list.length) return
  let ok = 0, fail = 0
  for(const item of list){
    const pad = n => String(n).padStart(2,'0')
    const d = new Date(weekStart.value); d.setDate(d.getDate() + item.day)
    const total = 540 + item.startMin
    const newStartTime = `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(Math.floor(total/60))}:${pad(total%60)}:00`
    try{
      await rescheduleInterview(item.appointmentId, newStartTime)
      await updateInterviewStatus(item.appointmentId, 1) // 改期后确认为「已确认」
      await remindInterview(item.appointmentId)
      ok++
    }catch(e){ fail++ }
  }
  await load()
  notify(fail ? `已确认 ${ok} 项，${fail} 项冲突未改` : `已确认调整 ${ok} 项面试时间`)
}

onMounted(load)
</script>

<template>
  <div class="page interviews-page">
    <div class="page-heading"><div><h1>面试安排中心</h1><p>{{ weekLabel }} · 本周共 {{ blocks.length }} 场面试</p></div><button class="btn"><span class="calendar-logos"><b>O</b><b>飞</b><b>钉</b></span><CalendarSync :size="16"/>同步日历</button></div>
    <div class="schedule-layout">
      <!-- 左侧候选人面板 320px -->
      <aside class="card recommend-card">
        <div class="section-title"><span><span class="ai"><Sparkles :size="16"/></span>已排面试</span><span class="pill">{{ recommendations.length }} 场</span></div>
        <p class="subtitle">日历中已安排的本周场次（同一时段仅保留一场）</p>
        <div class="recommend-list">
          <article v-for="item in recommendations" :key="item.id" class="rec-item" @click="drawer=item">
            <div class="rec-top">
              <MiniAvatar :name="item.candidate" :size="36" color="#635b9b"/>
              <div class="rec-main">
                <div class="rec-name-row"><b>{{ item.candidate }}</b><span class="pill" :class="item.pending ? 'adjusting' : item.status">{{ item.pending ? '待调整' : statusText[item.status] }}</span></div>
                <small>{{ item.position }}</small>
              </div>
            </div>
            <div class="rec-slot"><Clock3 :size="11"/>{{ item.dayName }} {{ item.time }} · {{ item.interviewer }}</div>
            <div class="rec-foot">
              <div class="rec-btns"><button class="btn sm ghost-primary" @click.stop="openAdjust(item)">调整</button><button class="btn sm primary" @click.stop="drawer=item">详情</button></div>
            </div>
          </article>

          <!-- 等待安排：时段冲突被挤出日历的场次，可调整/查看详情 -->
          <div v-if="waitingList.length" class="waiting-section">
            <div class="waiting-title">等待安排（{{ waitingList.length }}）</div>
            <article v-for="item in waitingList" :key="item.id" class="rec-item" :class="{ 'is-cancelled': item.status === 'cancelled' }" @click="drawer=item">
              <div class="rec-top">
                <MiniAvatar :name="item.candidate" :size="36" :color="item.status === 'cancelled' ? '#94a3b8' : '#635b9b'"/>
                <div class="rec-main">
                  <div class="rec-name-row"><b>{{ item.candidate }}</b><span class="pill" :class="item.status">{{ statusText[item.status] }}</span></div>
                  <small>{{ item.position }}</small>
                </div>
              </div>
              <div class="rec-slot"><Clock3 :size="11"/>{{ item.dayName }} {{ item.time }} · {{ item.interviewer }}</div>
              <div class="rec-foot" v-if="item.status !== 'cancelled'">
                <div class="rec-btns"><button class="btn sm ghost-primary" @click.stop="openAdjust(item)">调整</button><button class="btn sm primary" @click.stop="drawer=item">详情</button></div>
              </div>
            </article>
          </div>
        </div>
        <button class="all-link">查看全部面试安排 <ChevronRight :size="13"/></button>
      </aside>

      <!-- 中间日历 -->
      <section class="card calendar-card">
        <div class="calendar-tools">
          <div class="view-tabs"><button v-for="v in ['日','周','月']" :key="v" :class="{active:activeView===v}" @click="activeView=v">{{v}}</button></div>
          <button class="step" @click="shiftWeek(-1)"><ChevronLeft :size="15"/></button>
          <button class="today" @click="goToday">今天</button>
          <button class="step" @click="shiftWeek(1)"><ChevronRight :size="15"/></button>
          <strong>{{ weekLabel }}</strong>
          <div class="cal-right">
            <button v-if="pendingList.length" class="pending-cancel" @click="cancelPending">取消</button>
            <button v-if="pendingList.length" class="pending-confirm" @click="confirmPending">确认调整（{{ pendingList.length }}）</button>
            <button class="free-btn" @click="openFreeModal"><CalendarClock :size="15"/>设置我的空闲时间</button>
          </div>
        </div>
        <!-- 状态图例（替代旧场次图例） -->
        <div class="legend">
          <span><i class="lg pending"/>待确认</span>
          <span><i class="lg confirmed"/>已确认</span>
          <span><i class="lg completed"/>已完成</span>
          <span><i class="lg conflict"/>冲突</span>
          <span><i class="lg cancelled"/>已取消</span>
          <span><i class="lg adjusting"/>待调整</span>
          <small>拖动面试块改时间，紫色为待确认调整</small>
        </div>
        <CalendarGrid ref="calendar" :items="visibleBlocks" :week-dates="weekDates" :today-index="todayIndex" @day-click="openDay" @block-click="drawer=$event" @drag-start="onDragStart" @drag-end="onDragEnd"/>
      </section>
    </div>

    <!-- 右侧详情抽屉 360px（覆盖式） -->
    <transition name="drawer">
      <div v-if="drawer" class="drawer-mask" @click="drawer=null">
        <aside class="drawer" @click.stop>
          <header>
            <div class="drawer-head">
              <MiniAvatar :name="drawer.candidate" :size="40" color="#635b9b"/>
              <div>
                <h3>{{ drawer.candidate }}</h3>
                <p>{{ drawer.position }}</p>
              </div>
              <span class="pill" :class="drawer.status">{{ statusText[drawer.status] }}</span>
              <span v-if="drawer.hrStatus" class="pill green">已终审</span>
              <button class="drawer-close" @click="drawer=null"><X :size="16"/></button>
            </div>
          </header>
          <div class="drawer-body">
            <div class="detail-row"><Clock3 :size="14"/><div><label>面试时间</label><b>{{ drawer.dayName }} {{ drawer.dateLabel }} {{ drawer.time }}</b></div></div>
            <div class="detail-row"><UserRound :size="14"/><div><label>面试官</label><b>{{ drawer.interviewer }}</b></div></div>
            <div class="detail-row"><Clock3 :size="14"/><div><label>面试方式</label><b>{{ drawer.meetingUrl ? '视频面试' : '线下面试' }}</b></div></div>
            <div class="detail-row"><Link2 :size="14"/><div><label>会议链接</label><b v-if="drawer.meetingUrl" class="link">{{ drawer.meetingUrl }}</b><b v-else>暂无</b></div></div>
            <div class="detail-row"><FileText :size="14"/><div><label>面试评估</label><button v-if="drawer.sessionId && drawer.status === 'completed'" class="eval-link" @click="openEvaluation">查看评估报告</button><b v-else>面试结束后可查看</b></div></div>
          </div>
          <footer class="drawer-footer">
            <button class="btn danger-ghost" @click="cancelInterview">取消面试</button>
            <button class="btn" @click="openAdjust()">调整时间</button>
            <button class="btn primary" @click="confirmInterview">确认并通知</button>
          </footer>
        </aside>
      </div>
    </transition>

    <BaseModal v-if="dayModal" title="当日面试统计" width="410px" @close="dayModal=false"><div class="day-stat"><p>{{ dayLabel }}</p><strong>{{ dayStats.total }}<small> 场面试</small></strong><div><span><b>{{ dayStats.pending }}</b>待确认</span><span><b>{{ dayStats.confirmed }}</b>已确认</span><span><b>{{ dayStats.completed }}</b>已完成</span></div></div><template #footer><button class="btn primary" @click="dayModal=false">知道了</button></template></BaseModal>
    <BaseModal v-if="freeModal" title="设置我的空闲时间" width="500px" @close="freeModal=false"><div class="free-settings"><p>选择本周可参与面试的时段，保存后写入面试官日程；取消勾选提交即清空该天空闲时间。</p><div v-for="(item, i) in freeSlots" :key="i" class="free-row"><label><input v-model="item.enabled" type="checkbox"/>{{ weekDayLabels[i] }}</label><input v-model="item.start" class="input" type="time" :disabled="!item.enabled"/><span>至</span><input v-model="item.end" class="input" type="time" :disabled="!item.enabled"/></div></div><template #footer><button class="btn" @click="freeModal=false">取消</button><button class="btn primary" :disabled="freeSaving" @click="saveFree">{{ freeSaving ? '保存中…' : '保存空闲时间' }}</button></template></BaseModal>

    <BaseModal v-if="adjustModal" title="调整面试时间" width="380px" @close="adjustModal=false">
      <div class="adjust-form">
        <div class="adj-row">
          <label>开始时间</label>
          <div class="adj-time">
            <select v-model.number="adjHour">
              <option v-for="h in 9" :key="h" :value="h+9">{{ String(h+9).padStart(2,'0') }}:00</option>
            </select>
            <span>:</span>
            <select v-model.number="adjMin">
              <option :value="0">00</option><option :value="15">15</option><option :value="30">30</option><option :value="45">45</option>
            </select>
          </div>
        </div>
        <div class="adj-row">
          <label>面试时长</label>
          <select v-model.number="adjDur">
            <option :value="30">30 分钟</option>
            <option :value="45">45 分钟</option>
            <option :value="60">60 分钟</option>
          </select>
        </div>
        <div class="adj-preview">预计结束：{{ String(Math.floor((adjHour*60+adjMin+adjDur)/60)).padStart(2,'0') }}:{{ String((adjHour*60+adjMin+adjDur)%60).padStart(2,'0') }}</div>
        <div v-if="conflictType==='error'" class="adj-conflict">⚠ {{ conflictMsg }}</div>
        <div v-if="conflictType==='warning'" class="adj-warning">⚠ {{ conflictMsg }}</div>
      </div>
      <template #footer>
        <button class="btn" @click="adjustModal=false">取消</button>
        <button v-if="conflictType==='warning'" class="btn" @click="forceSave=true;saveAdjust()">仍要保存</button>
        <button class="btn primary" @click="saveAdjust()">确认调整</button>
      </template>
    </BaseModal>
    <ToastMessage :message="toast"/>
  </div>
</template>

<style scoped>
.interviews-page{display:flex;flex-direction:column;height:calc(100vh - 64px);overflow:hidden}
.calendar-logos{display:flex;gap:3px}
.calendar-logos b{width:17px;height:17px;color:white;background:#1472de;border-radius:4px;display:grid;place-items:center;font-size:8px}
.schedule-layout{display:grid;grid-template-columns:320px minmax(0,1fr);gap:15px;flex:1;min-height:0}
.recommend-card,.calendar-card{height:100%}
.recommend-card{padding:16px;display:flex;flex-direction:column;overflow:hidden;min-height:0}
.section-title>span:first-child{display:flex;align-items:center;gap:8px}
.ai{width:30px;height:30px;border-radius:9px;display:grid;place-items:center;color:#2563eb;background:#eaf1ff}
.subtitle{font-size:10px;color:#9aa8ba;margin:5px 0 12px 38px;flex-shrink:0}
.recommend-list{display:flex;flex-direction:column;gap:10px;overflow-y:auto;flex:1;min-height:0;padding-right:2px}

/* 候选人卡片 88-96px */
.rec-item{padding:10px 12px;border:1px solid #e2e8f0;border-radius:10px;transition:border-color .15s,box-shadow .15s;flex-shrink:0;cursor:pointer}
.rec-item:hover{border-color:#bfdbfe;box-shadow:0 2px 8px rgba(37,99,235,.06)}
.rec-top{display:flex;align-items:center;gap:10px}
.rec-main{flex:1;min-width:0}
.rec-name-row{display:flex;align-items:center;justify-content:space-between}
.rec-name-row b{font-size:13px}
.rec-main small{display:block;color:#64748b;font-size:10px;margin-top:1px}
.rec-slot{display:flex;align-items:center;gap:5px;color:#64748b;font-size:10px;margin:8px 0 6px}
.rec-foot{display:flex;align-items:center;justify-content:flex-end}
.rec-btns{display:flex;gap:6px;align-items:center}

/* 状态pill颜色 */
.pill.pending{background:#fef3c7;color:#92400e}
.pill.confirmed{background:#dbeafe;color:#1e40af}
.pill.completed{background:#e2e8f0;color:#64748b}
.pill.conflict{background:#fee2e2;color:#991b1b}
.pill.cancelled{background:#f1f5f9;color:#94a3b8;text-decoration:line-through}
.pill.adjusting{background:#ede9fe;color:#6d28d9}

.all-link{width:100%;height:32px;border:0;background:transparent;color:#2563eb;font-size:11px;display:flex;gap:5px;align-items:center;justify-content:center;margin-top:8px;flex-shrink:0}
.waiting-section{display:flex;flex-direction:column;gap:10px;margin-top:2px;border-top:1px dashed #e2e8f0;padding-top:12px;flex-shrink:0}
.waiting-title{font-size:11px;color:#94a3b8;margin-bottom:2px}
.rec-item.is-cancelled{opacity:.6;background:#f8fafc}

.calendar-card{padding:15px;display:flex;flex-direction:column}
.calendar-tools{height:37px;display:flex;align-items:center;gap:8px;flex-shrink:0}
.view-tabs{display:flex;background:#eef2f7;border-radius:8px;padding:3px}
.view-tabs button{height:26px;width:34px;border:0;border-radius:6px;background:transparent;color:#64748b;font-size:11px;cursor:pointer}
.view-tabs button.active{background:#2563eb;color:white}
.step,.today{height:31px;border:1px solid #dce4ee;background:white;border-radius:7px;display:grid;place-items:center;color:#63738b;cursor:pointer}
.step{width:31px}
.today{padding:0 11px;font-size:11px}
.calendar-tools strong{font-size:13px}
.cal-right{margin-left:auto;display:flex;align-items:center;gap:8px}
.free-btn{border:0;height:31px;padding:0 12px;border-radius:8px;background:#eef4ff;color:#2563eb;display:flex;align-items:center;gap:6px;font-size:11px;font-weight:600;cursor:pointer}
.pending-confirm{height:31px;padding:0 12px;border:0;border-radius:8px;background:#7c3aed;color:#fff;display:flex;align-items:center;gap:6px;font-size:11px;font-weight:600;cursor:pointer}
.pending-cancel{height:31px;padding:0 12px;border:1px solid #dce4ee;border-radius:8px;background:#fff;color:#63738b;font-size:11px;cursor:pointer}

/* 状态图例 */
.legend{height:32px;display:flex;align-items:center;gap:14px;color:#64748b;font-size:10px;flex-shrink:0}
.legend span{display:flex;align-items:center;gap:5px}
.legend .lg{width:10px;height:10px;border-radius:3px;display:inline-block}
.legend .lg.pending{background:#f59e0b}
.legend .lg.confirmed{background:#2563eb}
.legend .lg.completed{background:#94a3b8}
.legend .lg.conflict{background:#fff;border:1.5px solid #dc2626}
.legend .lg.cancelled{background:#f1f5f9;border:1px solid #cbd5e1}
.legend .lg.adjusting{background:#ede9fe;border:1.5px dashed #7c3aed}
.legend small{margin-left:auto;color:#94a3b8;font-size:9px}

/* 详情抽屉 */
.drawer-mask{position:fixed;inset:0;background:rgba(15,23,42,.3);z-index:100;display:flex;justify-content:flex-end}
.drawer{width:360px;background:#fff;height:100%;display:flex;flex-direction:column;box-shadow:-8px 0 30px rgba(0,0,0,.1)}
.drawer-head{display:flex;align-items:center;gap:12px;padding:18px 20px;border-bottom:1px solid #e2e8f0}
.drawer-head h3{font-size:16px;margin:0}
.drawer-head p{font-size:11px;color:#64748b;margin:2px 0 0}
.drawer-head .pill{margin-left:auto}
.drawer-close{border:0;background:#f1f5f9;width:28px;height:28px;border-radius:6px;cursor:pointer;display:grid;place-items:center;color:#64748b}
.drawer-body{flex:1;overflow-y:auto;padding:16px 20px}
.detail-row{display:flex;gap:12px;padding:10px 0;border-bottom:1px solid #f1f5f9;color:#64748b}
.detail-row>svg{flex-shrink:0;margin-top:2px}
.detail-row label{display:block;font-size:10px;color:#94a3b8;margin-bottom:2px}
.detail-row b{font-size:12px;color:#1e293b;font-weight:500;line-height:1.4}
.detail-row b.link{color:#2563eb}
.detail-row b.notify-failed{color:#dc2626;display:flex;align-items:center;gap:4px}
.detail-row .eval-link{border:0;background:transparent;padding:0;color:#2563eb;font-size:12px;font-weight:500;cursor:pointer;text-decoration:underline}
.drawer-footer{padding:14px 20px;border-top:1px solid #e2e8f0;display:flex;gap:8px}
.drawer-footer .btn{flex:1;white-space:nowrap;font-size:12px;padding:8px 4px}

/* 抽屉动画 */
.drawer-enter-active,.drawer-leave-active{transition:opacity .2s}
.drawer-enter-active .drawer,.drawer-leave-active .drawer{transition:transform .25s}
.drawer-enter-from,.drawer-leave-to{opacity:0}
.drawer-enter-from .drawer,.drawer-leave-to .drawer{transform:translateX(100%)}

/* 弹窗 */
.day-stat{text-align:center;padding:5px 10px 15px}
.day-stat p{color:#74849b;font-size:12px}
.day-stat>strong{display:block;font-size:42px;color:#2563eb;margin:10px}
.day-stat>strong small{font-size:12px;color:#74849b}
.day-stat>div{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
.day-stat span{padding:11px 5px;border-radius:9px;background:#f5f8fc;color:#7a899f;font-size:10px}
.day-stat span b{display:block;color:#2563eb;font-size:18px}
.free-settings>p{color:#718198;font-size:12px;margin-bottom:15px}
.free-settings>div{display:grid;grid-template-columns:1.3fr 1fr auto 1fr;align-items:center;gap:10px;margin:10px 0}
.free-settings label{font-size:12px}
.free-settings label input{margin-right:8px;accent-color:#2563eb}
.free-settings>div>span{font-size:11px;color:#93a0b3}

/* 调整时间弹窗 */
.adjust-form{padding:5px 0}
.adj-row{display:flex;align-items:center;justify-content:space-between;margin:14px 0}
.adj-row label{font-size:13px;color:#475569}
.adj-row select{height:34px;border:1px solid #dce4ee;border-radius:7px;padding:0 8px;font-size:13px;color:#1e293b;background:#fff}
.adj-time{display:flex;align-items:center;gap:6px}
.adj-time span{color:#94a3b8;font-size:14px}
.adj-preview{margin-top:16px;padding:10px 12px;background:#f0f5ff;border-radius:8px;font-size:12px;color:#2563eb;text-align:center}
.adj-conflict{margin-top:10px;padding:10px 12px;background:#fef2f2;border:1px solid #fecaca;border-radius:8px;font-size:12px;color:#dc2626;text-align:center}
.adj-warning{margin-top:10px;padding:10px 12px;background:#fffbeb;border:1px solid #fde68a;border-radius:8px;font-size:12px;color:#92400e;text-align:center}
</style>
