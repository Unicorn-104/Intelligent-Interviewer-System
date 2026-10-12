<script setup>
import { ref, computed } from 'vue'
import { CalendarSync, Sparkles, Clock3, UserRound, ChevronLeft, ChevronRight, CalendarClock, Send, CheckCheck, X, MapPin, Link2, FileText, History, Bell, AlertTriangle } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import CalendarGrid from '@/views/enterprise/components/CalendarGrid.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { api, reserveApi } from '@/views/enterprise/api/contract'

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
const dates = [7,8,9,10,11,12,13]
const dayNames = ['周一','周二','周三','周四','周五','周六','周日']

const recommendations = computed(() => {
  const list = calendar.value?.schedule || []
  return list
    .filter(s => s.status !== 'cancelled')
    .slice()
    .sort((a,b) => a.day - b.day || a.startMin - b.startMin)
})
const waitingList = computed(() => {
  const list = calendar.value?.schedule || []
  return list.filter(s => s.status === 'cancelled')
})

function notify(msg){toast.value=msg;setTimeout(()=>toast.value='',2200)}

function cancelInterview(){
  if(!drawer.value) return
  drawer.value.status = 'cancelled'
  drawer.value.notify = 'unsent'
  notify('面试已取消，已移至等待安排')
  drawer.value = null
}
function confirmInterview(){
  if(!drawer.value) return
  drawer.value.status = 'confirmed'
  drawer.value.notify = 'sent'
  notify('面试已确认，通知已发送')
  drawer.value = null
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
  const list = calendar.value?.schedule || []
  const newEnd = newStartMin + newDur
  for(const s of list){
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

function saveAdjust(){
  const newStartMin = (adjHour.value-9)*60 + adjMin.value
  const newEndMin = newStartMin + adjDur.value
  if(newEndMin > 540){ notify('结束时间超过18:00'); return }
  const result = checkConflict(newStartMin, adjDur.value, drawer.value)
  if(result && result.type === 'error'){
    conflictMsg.value = result.msg
    conflictType.value = 'error'
    return
  }
  if(result && result.type === 'warning' && !forceSave.value){
    conflictMsg.value = result.msg
    conflictType.value = 'warning'
    return
  }
  conflictMsg.value = ''
  const s = 9*60 + newStartMin
  const e = s + adjDur.value
  const fmt = m => String(Math.floor(m/60)).padStart(2,'0')+':'+String(m%60).padStart(2,'0')
  drawer.value.startMin = newStartMin
  drawer.value.durMin = adjDur.value
  drawer.value.time = fmt(s)+'-'+fmt(e)
  adjustModal.value = false
  forceSave.value = false
  notify('面试时间已调整')
}
function confirm(item){reserveApi(api.scheduling.invitations,{applicationId:item.applicationId,interviewerId:2001,templateId:item.stageId,slotId:null,expiresAt:null});item.status='待面试';item.tone='confirmed';notify(`${item.name} 的${item.stage}已确认`)}
function saveFree(){freeModal.value=false;calendar.value.toggleBlocked();reserveApi(api.scheduling.slots,{positionId:null,startTime:'2026-09-09T09:00:00+08:00',endTime:'2026-09-09T18:00:00+08:00'});notify('空闲时间已更新')}

// 状态 → 中文标签
const statusText = { pending:'待确认', confirmed:'已确认', completed:'已完成', conflict:'冲突', cancelled:'已取消' }
</script>

<template>
  <div class="page interviews-page">
    <div class="page-heading"><div><h1>面试安排中心</h1><p>9月7日 – 9月13日 · 本周共 19 场面试 · AI 已协调推荐</p></div><button class="btn"><span class="calendar-logos"><b>O</b><b>飞</b><b>钉</b></span><CalendarSync :size="16"/>同步日历</button></div>
    <div class="schedule-layout">
      <!-- 左侧候选人面板 320px -->
      <aside class="card recommend-card">
        <div class="section-title"><span><span class="ai"><Sparkles :size="16"/></span>AI 协调结果</span><span class="pill">6 条推荐</span></div>
        <p class="subtitle">根据候选人与面试官空闲时间智能推荐</p>
        <div class="recommend-list">
          <article v-for="item in recommendations" :key="item.id" class="rec-item" @click="drawer=item">
            <div class="rec-top">
              <MiniAvatar :name="item.candidate" :size="36" color="#635b9b"/>
              <div class="rec-main">
                <div class="rec-name-row"><b>{{ item.candidate }}</b><span class="pill" :class="item.status">{{ statusText[item.status] }}</span></div>
                <small>{{ item.position }}</small>
              </div>
            </div>
            <div class="rec-slot"><Clock3 :size="11"/>{{ dayNames[item.day] }} {{ item.time }} · {{ item.stage }} · {{ item.interviewer }}</div>
            <div class="rec-foot">
              <div class="match-bar"><span>AI 匹配 {{ 90 + (item.id % 8) }}%</span><i><em :style="{width:(90 + item.id % 8)+'%'}"/></i></div>
              <div class="rec-btns"><button class="btn sm ghost-primary" @click.stop="openAdjust(item)">调整</button><button class="btn sm primary" @click.stop="drawer=item">详情</button></div>
            </div>
          </article>
        </div>
        <!-- 等待安排 -->
        <div v-if="waitingList.length" class="waiting-section">
          <div class="waiting-title">等待安排（{{ waitingList.length }}）</div>
          <div v-for="item in waitingList" :key="item.id" class="rec-item waiting-item">
            <div class="rec-top">
              <MiniAvatar :name="item.candidate" :size="30" color="#94a3b8"/>
              <div class="rec-main">
                <b style="font-size:12px">{{ item.candidate }}</b>
                <small>{{ item.position }} · {{ item.interviewer }}</small>
              </div>
            </div>
          </div>
        </div>
        <button class="all-link">查看全部推荐 <ChevronRight :size="13"/></button>
      </aside>

      <!-- 中间日历 -->
      <section class="card calendar-card">
        <div class="calendar-tools">
          <div class="view-tabs"><button v-for="v in ['日','周','月']" :key="v" :class="{active:activeView===v}" @click="activeView=v">{{v}}</button></div>
          <button class="step"><ChevronLeft :size="15"/></button>
          <button class="today">今天</button>
          <button class="step"><ChevronRight :size="15"/></button>
          <strong>2026年9月7日 – 9月13日</strong>
          <button class="free-btn" @click="freeModal=true"><CalendarClock :size="15"/>设置我的空闲时间</button>
        </div>
        <!-- 状态图例（替代旧场次图例） -->
        <div class="legend">
          <span><i class="lg pending"/>待确认</span>
          <span><i class="lg confirmed"/>已确认</span>
          <span><i class="lg completed"/>已完成</span>
          <span><i class="lg conflict"/>冲突</span>
          <span><i class="lg cancelled"/>已取消</span>
          <small>点击面试块查看详情</small>
        </div>
        <CalendarGrid ref="calendar" @day-click="dayModal=true" @block-click="drawer=$event"/>
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
                <p>{{ drawer.position }} · {{ drawer.stage }}</p>
              </div>
              <span class="pill" :class="drawer.status">{{ statusText[drawer.status] }}</span>
              <button class="drawer-close" @click="drawer=null"><X :size="16"/></button>
            </div>
          </header>
          <div class="drawer-body">
            <div class="detail-row"><Clock3 :size="14"/><div><label>面试时间</label><b>{{ dayNames[drawer.day] }} 9月{{ dates[drawer.day] }}日 {{ drawer.time }}</b></div></div>
            <div class="detail-row"><UserRound :size="14"/><div><label>面试官</label><b>{{ drawer.interviewer }}</b></div></div>
            <div class="detail-row"><MapPin :size="14"/><div><label>面试地点</label><b>会议室 A-302</b></div></div>
            <div class="detail-row"><Link2 :size="14"/><div><label>会议链接</label><b class="link">zoom.us/j/884-221-903</b></div></div>
            <div class="detail-row"><FileText :size="14"/><div><label>简历摘要</label><b>5年前端经验，主导过SaaS产品架构，精通Vue3+TypeScript</b></div></div>
            <div class="detail-row"><Sparkles :size="14"/><div><label>AI 推荐理由</label><b>与面试官陈静历史合作评分高，时间窗口匹配度96%</b></div></div>
            <div class="detail-row">
              <Bell :size="14"/>
              <div>
                <label>通知状态</label>
                <b :class="'notify-'+drawer.notify">
                  <AlertTriangle v-if="drawer.notify==='failed'"/>
                  {{ drawer.notify==='sent'?'已送达': drawer.notify==='failed'?'发送失败：候选人邮箱无效': drawer.notify==='unsent'?'未发送':'发送中' }}
                </b>
              </div>
            </div>
            <div class="detail-row"><History :size="14"/><div><label>操作记录</label><b>09:00 AI推荐 · 09:05 调度员分配</b></div></div>
          </div>
          <footer class="drawer-footer">
            <button class="btn danger-ghost" @click="cancelInterview">取消面试</button>
            <button class="btn" @click="openAdjust()">调整时间</button>
            <button class="btn primary" @click="confirmInterview">确认并通知</button>
          </footer>
        </aside>
      </div>
    </transition>

    <div class="action-bar"><div><Sparkles :size="16"/><span>AI 协调完成 · 本周 19 场面试，7 场待确认，其余已锁定</span></div><div><button class="btn" @click="notify('已向候选人发送通知')"><Send :size="15"/>通知候选人</button><button class="btn primary" @click="notify('待确认面试已批量确认')"><CheckCheck :size="15"/>批量确认</button></div></div>

    <BaseModal v-if="dayModal" title="当日面试统计" width="410px" @close="dayModal=false"><div class="day-stat"><p>9月9日 周三</p><strong>5<small> 场面试</small></strong><div><span><b>2</b>待确认</span><span><b>2</b>已确认</span><span><b>1</b>冲突</span></div></div><template #footer><button class="btn primary" @click="dayModal=false">知道了</button></template></BaseModal>
    <BaseModal v-if="freeModal" title="设置我的空闲时间" width="500px" @close="freeModal=false"><div class="free-settings"><p>选择本周可参与面试的时段，未选择的时间将在日历中显示为不可用。</p><div v-for="day in ['周一 09/07','周二 09/08','周三 09/09','周四 09/10','周五 09/11']" :key="day"><label><input type="checkbox" checked/>{{day}}</label><input class="input" value="09:00"/><span>至</span><input class="input" value="18:00"/></div></div><template #footer><button class="btn" @click="freeModal=false">取消</button><button class="btn primary" @click="saveFree">保存空闲时间</button></template></BaseModal>

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
.interviews-page{padding-bottom:92px}
.calendar-logos{display:flex;gap:3px}
.calendar-logos b{width:17px;height:17px;color:white;background:#1472de;border-radius:4px;display:grid;place-items:center;font-size:8px}
.schedule-layout{display:grid;grid-template-columns:320px minmax(700px,1fr);gap:15px}
.recommend-card,.calendar-card{height:630px}
.recommend-card{padding:16px;display:flex;flex-direction:column}
.section-title>span:first-child{display:flex;align-items:center;gap:8px}
.ai{width:30px;height:30px;border-radius:9px;display:grid;place-items:center;color:#2563eb;background:#eaf1ff}
.subtitle{font-size:10px;color:#9aa8ba;margin:5px 0 12px 38px}
.recommend-list{display:flex;flex-direction:column;gap:10px;overflow-y:auto;flex:1;padding-right:2px}

/* 候选人卡片 88-96px */
.rec-item{padding:10px 12px;border:1px solid #e2e8f0;border-radius:10px;transition:border-color .15s,box-shadow .15s}
.rec-item:hover{border-color:#bfdbfe;box-shadow:0 2px 8px rgba(37,99,235,.06)}
.rec-top{display:flex;align-items:center;gap:10px}
.rec-main{flex:1;min-width:0}
.rec-name-row{display:flex;align-items:center;justify-content:space-between}
.rec-name-row b{font-size:13px}
.rec-main small{display:block;color:#64748b;font-size:10px;margin-top:1px}
.rec-slot{display:flex;align-items:center;gap:5px;color:#64748b;font-size:10px;margin:8px 0 6px}
.rec-foot{display:flex;align-items:center;justify-content:space-between}
.match-bar{flex:1}
.match-bar>span{font-size:9px;color:#64748b}
.match-bar i{display:block;height:4px;background:#e2e8f0;border-radius:2px;margin-top:3px;overflow:hidden}
.match-bar em{display:block;height:100%;background:linear-gradient(90deg,#3b82f6,#2563eb);border-radius:2px}
.rec-btns{display:flex;gap:6px;align-items:center}

/* 状态pill颜色 */
.pill.pending{background:#fef3c7;color:#92400e}
.pill.confirmed{background:#dbeafe;color:#1e40af}
.pill.completed{background:#e2e8f0;color:#64748b}
.pill.conflict{background:#fee2e2;color:#991b1b}
.pill.cancelled{background:#f1f5f9;color:#94a3b8;text-decoration:line-through}

.all-link{width:100%;height:32px;border:0;background:transparent;color:#2563eb;font-size:11px;display:flex;gap:5px;align-items:center;justify-content:center;margin-top:8px}
.waiting-section{margin-top:12px;border-top:1px dashed #e2e8f0;padding-top:10px}
.waiting-title{font-size:11px;color:#94a3b8;margin-bottom:8px}
.waiting-item{opacity:.6}

.calendar-card{padding:15px;display:flex;flex-direction:column}
.calendar-tools{height:37px;display:flex;align-items:center;gap:8px;flex-shrink:0}
.view-tabs{display:flex;background:#eef2f7;border-radius:8px;padding:3px}
.view-tabs button{height:26px;width:34px;border:0;border-radius:6px;background:transparent;color:#64748b;font-size:11px;cursor:pointer}
.view-tabs button.active{background:#2563eb;color:white}
.step,.today{height:31px;border:1px solid #dce4ee;background:white;border-radius:7px;display:grid;place-items:center;color:#63738b;cursor:pointer}
.step{width:31px}
.today{padding:0 11px;font-size:11px}
.calendar-tools strong{font-size:13px}
.free-btn{margin-left:auto;border:0;height:31px;padding:0 12px;border-radius:8px;background:#eef4ff;color:#2563eb;display:flex;align-items:center;gap:6px;font-size:11px;font-weight:600;cursor:pointer}

/* 状态图例 */
.legend{height:32px;display:flex;align-items:center;gap:14px;color:#64748b;font-size:10px;flex-shrink:0}
.legend span{display:flex;align-items:center;gap:5px}
.legend .lg{width:10px;height:10px;border-radius:3px;display:inline-block}
.legend .lg.pending{background:#f59e0b}
.legend .lg.confirmed{background:#2563eb}
.legend .lg.completed{background:#94a3b8}
.legend .lg.conflict{background:#fff;border:1.5px solid #dc2626}
.legend .lg.cancelled{background:#f1f5f9;border:1px solid #cbd5e1}
.legend small{margin-left:auto;color:#94a3b8;font-size:9px}

/* 底部操作栏 */
.action-bar{position:fixed;z-index:10;left:244px;right:24px;bottom:18px;height:58px;border:1px solid #e2e8f0;border-radius:13px;background:rgba(255,255,255,.97);box-shadow:0 8px 24px rgba(15,23,42,.08);display:flex;align-items:center;justify-content:space-between;padding:0 18px}
.action-bar>div{display:flex;align-items:center;gap:10px;font-size:11px;color:#475569}
.action-bar>div:first-child svg{color:#2563eb}

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
