<script setup>
import { ref } from 'vue'
import { CalendarSync, Sparkles, Clock3, UserRound, ChevronLeft, ChevronRight, CalendarClock, Send, CheckCheck, X, CircleCheck } from '@/views/enterprise/components/icons'
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
const recommendations = ref([
  { applicationId:7001, stageId:'stage-tech', stage:'专业技术面', name:'张雨桐', role:'前端开发工程师', time:'周三 14:00-14:45', interviewer:'陈静', match:96, status:'待确认', tone:'orange', color:'#357b64' },
  { applicationId:7002, stageId:'stage-case', stage:'项目案例深挖', name:'李明轩', role:'后端开发工程师', time:'周四 09:00-09:45', interviewer:'王磊', match:92, status:'待确认', tone:'orange', color:'#735343' },
  { applicationId:7003, stageId:'stage-ai', stage:'AI 结构化预面', name:'王一诺', role:'UI 设计师', time:'周三 10:15-11:00', interviewer:'李薇', match:95, status:'待面试', tone:'blue', color:'#635b9b' },
  { applicationId:7004, stageId:'stage-screen', stage:'HR 初筛沟通', name:'刘子涵', role:'数据分析师', time:'周五 10:00-10:45', interviewer:'赵峰', match:89, status:'进入面试', tone:'green', color:'#4f728f' }
])
function notify(msg){toast.value=msg;setTimeout(()=>toast.value='',2200)}
function confirm(item){reserveApi(api.scheduling.invitations,{applicationId:item.applicationId,interviewerId:2001,templateId:item.stageId,slotId:null,expiresAt:null});item.status='待面试';item.tone='blue';notify(`${item.name} 的${item.stage}已确认`)}
function saveFree(){freeModal.value=false;calendar.value.toggleBlocked();reserveApi(api.scheduling.slots,{positionId:null,startTime:'2026-09-09T09:00:00+08:00',endTime:'2026-09-09T18:00:00+08:00'});notify('空闲时间已更新')}
</script>

<template>
  <div class="page interviews-page">
    <div class="page-heading"><div><h1>面试安排中心</h1><p>9月7日 – 9月13日 · 本周共 24 场面试 · AI 已协调 12 场</p></div><button class="btn"><span class="calendar-logos"><b>O</b><b>飞</b><b>钉</b></span><CalendarSync :size="16"/>同步日历</button></div>
    <div class="schedule-layout">
      <aside class="card recommend-card">
        <div class="section-title"><span><span class="ai"><Sparkles :size="16"/></span>AI 协调结果</span><span class="pill">6 条推荐</span></div>
        <p class="subtitle">根据候选人与面试官空闲时间智能推荐</p>
        <div class="recommend-list">
          <article v-for="item in recommendations" :key="item.name">
            <div class="person"><MiniAvatar :name="item.name" :size="34" :color="item.color"/><div><b>{{ item.name }}</b><small>{{ item.role }}</small></div><span class="pill" :class="item.tone">{{ item.status }}</span></div>
            <div class="slot"><span><Clock3 :size="12"/>{{ item.time }}</span><span><UserRound :size="12"/>{{ item.stage }} · {{ item.interviewer }}</span></div>
            <div class="rec-foot"><span>AI 匹配度 <b>{{ item.match }}%</b></span><div><button class="btn sm">调整</button><button class="btn sm primary" @click="confirm(item)">确认</button></div></div>
          </article>
        </div>
        <button class="all-link">查看全部 6 条推荐 <ChevronRight :size="13"/></button>
      </aside>
      <section class="card calendar-card">
        <div class="calendar-tools"><div class="view-tabs"><button v-for="v in ['日','周','月']" :key="v" :class="{active:activeView===v}" @click="activeView=v">{{v}}</button></div><button class="step"><ChevronLeft :size="15"/></button><button class="today">今天</button><button class="step"><ChevronRight :size="15"/></button><strong>2026年9月7日 – 9月13日</strong><button class="free-btn" @click="freeModal=true"><CalendarClock :size="15"/>设置我的空闲时间</button></div>
        <div class="legend"><span><i class="l1"/>0-3 场</span><span><i class="l2"/>4-6 场</span><span><i class="l3"/>7 场以上</span><span><i class="l0"/>空闲未开放</span><small>点击日期查看当日统计</small></div>
        <CalendarGrid ref="calendar" @day-click="dayModal=true"/>
      </section>
    </div>
    <div class="action-bar"><div><Sparkles :size="16"/><span>AI 协调完成 · 本周 24 场面试，12 场已自动确认，其余待人工处理</span></div><div><button class="btn" @click="notify('已向候选人发送通知')"><Send :size="15"/>通知候选人</button><button class="btn primary" @click="notify('待确认面试已批量确认')"><CheckCheck :size="15"/>批量确认</button></div></div>

    <BaseModal v-if="dayModal" title="当日面试统计" width="410px" @close="dayModal=false"><div class="day-stat"><p>9月9日 周三</p><strong>4<small> 场面试</small></strong><div><span><b>1</b>待确认</span><span><b>2</b>待面试</span><span><b>1</b>进行中</span></div></div><template #footer><button class="btn primary" @click="dayModal=false">知道了</button></template></BaseModal>
    <BaseModal v-if="freeModal" title="设置我的空闲时间" width="500px" @close="freeModal=false"><div class="free-settings"><p>选择本周可参与面试的时段，未选择的时间将在日历中显示为不可用。</p><div v-for="day in ['周一 09/07','周二 09/08','周三 09/09','周四 09/10','周五 09/11']" :key="day"><label><input type="checkbox" checked/>{{day}}</label><input class="input" value="09:00"/><span>至</span><input class="input" value="18:00"/></div></div><template #footer><button class="btn" @click="freeModal=false">取消</button><button class="btn primary" @click="saveFree">保存空闲时间</button></template></BaseModal>
    <ToastMessage :message="toast"/>
  </div>
</template>

<style scoped>
.interviews-page{padding-bottom:92px}.calendar-logos{display:flex;gap:3px}.calendar-logos b{width:17px;height:17px;color:white;background:#1472de;border-radius:4px;display:grid;place-items:center;font-size:8px}.schedule-layout{display:grid;grid-template-columns:325px minmax(700px,1fr);gap:15px}.recommend-card,.calendar-card{height:630px}.recommend-card{padding:17px}.section-title>span:first-child{display:flex;align-items:center;gap:8px}.ai{width:30px;height:30px;border-radius:9px;display:grid;place-items:center;color:#2563eb;background:#eaf1ff}.subtitle{font-size:9px;color:#9aa8ba;margin:5px 0 13px 39px}.recommend-list{display:flex;flex-direction:column;gap:8px}.recommend-list article{padding:10px;border:1px solid #dfe7f1;border-radius:11px}.person{display:flex;align-items:center;gap:8px}.person>div{min-width:0;flex:1}.person b,.person small{display:block}.person b{font-size:12px}.person small{color:#7f8da2;font-size:9px;margin-top:2px}.slot{display:flex;justify-content:space-between;background:#f5f8fc;color:#526782;border-radius:7px;margin:8px 0;padding:5px 7px;font-size:9px}.slot span{display:flex;gap:4px;align-items:center}.rec-foot{display:flex;align-items:center;justify-content:space-between;color:#8c9aae;font-size:9px}.rec-foot>b,.rec-foot>span b{color:#2563eb}.rec-foot>div{display:flex;gap:5px}.all-link{width:100%;height:32px;border:0;background:transparent;color:#2563eb;font-size:10px;display:flex;gap:5px;align-items:center;justify-content:center}.calendar-card{padding:15px}.calendar-tools{height:37px;display:flex;align-items:center;gap:8px}.view-tabs{display:flex;background:#eef2f7;border-radius:8px;padding:3px}.view-tabs button{height:26px;width:34px;border:0;border-radius:6px;background:transparent;color:#64748b;font-size:11px}.view-tabs button.active{background:#2563eb;color:white}.step,.today{height:31px;border:1px solid #dce4ee;background:white;border-radius:7px;display:grid;place-items:center;color:#63738b}.step{width:31px}.today{padding:0 11px;font-size:10px}.calendar-tools strong{font-size:13px}.free-btn{margin-left:auto;border:0;height:31px;padding:0 12px;border-radius:8px;background:#eef4ff;color:#2563eb;display:flex;align-items:center;gap:6px;font-size:11px;font-weight:600}.legend{height:38px;display:flex;align-items:center;gap:14px;color:#8290a5;font-size:9px}.legend span{display:flex;align-items:center;gap:4px}.legend i{width:9px;height:9px;border-radius:3px;background:#d9e9ff}.legend .l2{background:#3d82f6}.legend .l3{background:#2151d8}.legend .l0{background:#e9edf3}.legend small{margin-left:auto}.action-bar{position:fixed;z-index:10;left:244px;right:24px;bottom:18px;height:58px;border:1px solid #e0e7f0;border-radius:13px;background:rgba(255,255,255,.97);box-shadow:0 8px 24px rgba(15,23,42,.08);display:flex;align-items:center;justify-content:space-between;padding:0 18px}.action-bar>div{display:flex;align-items:center;gap:10px;font-size:11px}.action-bar>div:first-child svg{color:#2563eb}.day-stat{text-align:center;padding:5px 10px 15px}.day-stat p{color:#74849b;font-size:12px}.day-stat>strong{display:block;font-size:42px;color:#2563eb;margin:10px}.day-stat>strong small{font-size:12px;color:#74849b}.day-stat>div{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.day-stat span{padding:11px 5px;border-radius:9px;background:#f5f8fc;color:#7a899f;font-size:10px}.day-stat span b{display:block;color:#2563eb;font-size:18px}.free-settings>p{color:#718198;font-size:12px;margin-bottom:15px}.free-settings>div{display:grid;grid-template-columns:1.3fr 1fr auto 1fr;align-items:center;gap:10px;margin:10px 0}.free-settings label{font-size:12px}.free-settings label input{margin-right:8px;accent-color:#2563eb}.free-settings>div>span{font-size:11px;color:#93a0b3}
</style>



