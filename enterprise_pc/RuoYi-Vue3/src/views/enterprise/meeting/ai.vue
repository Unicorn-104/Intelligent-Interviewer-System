<script setup>
import { ref, nextTick } from 'vue'
import { Volume2, MicOff, Bookmark, UserX, PhoneOff, Sparkles, CheckCircle2, Target, MessageSquareText, AudioWaveform, Send } from '@/views/enterprise/components/icons'
import MeetingRail from '@/views/enterprise/components/MeetingRail.vue'
import MeetingHeader from '@/views/enterprise/components/MeetingHeader.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { api, reserveApi } from '@/views/enterprise/api/contract'

const toast=ref('')
const muted=ref(false)
const answer=ref('')
const scroller=ref()
const stage=ref({ id:'stage-ai', name:'AI 结构化预面', mode:'纯 AI', target:'验证技术基础与项目经历', duration:45, status:'进行中', focus:'重点核实大型项目个人贡献' })
const items=ref([
  {type:'ai',text:'第一题：请说明 React 中 setState 更新是同步还是异步，为什么？',time:'0:18'},
  {type:'candidate',text:'React 18 里默认是异步的，因为有自动批处理；其他场景我不太确定。',time:'0:26'},
  {type:'ai',text:'追问：什么场景下会同步更新？React 18 批处理的边界在哪里？',time:'0:15'},
  {type:'candidate',text:'像是 setTimeout 这类场景会同步，但具体边界我没有深入研究过。',time:'0:24'},
  {type:'ai',text:'下一题：useMemo 与 useCallback 的区别与适用场景分别是什么？',time:'0:16'},
  {type:'candidate',text:'useMemo 缓存计算结果，useCallback 缓存函数，传参给子组件时使用。',time:'0:23'},
  {type:'notice',text:'系统提示 · 连续 3 题未达标准，技术栈已由 React 自动切换至 Vue'},
  {type:'ai',active:true,text:'已切换到第二技术栈 Vue。当前提问：Vue 3 中 ref 与 reactive 有什么区别？实际开发中你更倾向用哪个？',time:'0:22'},
  {type:'candidate',text:'ref 能包装基本类型且解构不丢响应性；reactive 只支持对象。我更倾向统一用 ref，代码更直观。',time:'0:41'}
])
function notify(msg){toast.value=msg;setTimeout(()=>toast.value='',2000)}
function send(){if(!answer.value.trim())return;reserveApi(api.sessions.answer,{sessionId:'SES-6001',questionId:5004,answerType:'text',content:answer.value,clientRequestId:`answer-${Date.now()}`});items.value.push({type:'candidate',text:answer.value,time:'刚刚'});answer.value='';nextTick(()=>scroller.value.scrollTop=scroller.value.scrollHeight)}
function finishStage(reason){reserveApi(api.sessions.finish,{sessionId:'SES-6001',endReason:reason,clientRequestId:`finish-${Date.now()}`});stage.value.status='待审核';notify(reason==='completed'?'阶段已结束，等待 HR 审核':'阶段已标记为异常结束')}
</script>

<template>
  <div class="meeting-page"><MeetingRail/><main><MeetingHeader candidate="李思远" :round="stage.name" stack="Vue 3（当前技术主题）"/>
    <div class="ai-layout"><section class="dialog-card card"><header><div><h2>对话流 <span class="pill"><Sparkles :size="12"/>自动追问已开启</span></h2><p>AI 将根据回答质量动态调整问题难度和技术方向</p></div><span>答题进度 4 / 10 <i><b/></i></span></header>
      <div ref="scroller" class="dialog-stream"><div v-for="(item,i) in items" :key="i" :class="['dialog-row',item.type,{active:item.active}]"><div v-if="item.type==='ai'" class="speaker ai"><Sparkles :size="15"/></div><div v-if="item.type==='candidate'" class="speaker person">李</div><div class="msg"><span v-if="item.active" class="current">当前提问</span>{{item.text}}</div><small v-if="item.time"><AudioWaveform :size="13"/>语音转文字 · {{item.time}}</small></div></div>
      <div class="answer-input"><input v-model="answer" @keyup.enter="send" placeholder="模拟输入候选人回答…"/><button @click="send"><Send :size="16"/></button></div>
      <footer><span><i/>{{ stage.mode }} · {{ stage.target }} · 实时转写中</span><div><button class="btn" @click="muted=!muted"><MicOff :size="16"/>{{muted?'取消静音':'静音'}}</button><button class="btn" @click="finishStage('hold')"><Bookmark :size="16"/>阶段暂缓</button><button class="btn danger-ghost" @click="finishStage('aborted')"><UserX :size="16"/>终止阶段</button><button class="btn danger" @click="finishStage('completed')"><PhoneOff :size="16"/>结束阶段</button></div></footer>
    </section>
    <aside class="analysis-card card"><div class="analysis-head"><span><Sparkles :size="17"/></span><div><h2>实时分析</h2><p>基于当前回答动态更新</p></div><em>AI 分析中</em></div>
      <div class="score-main"><div><small>综合表现</small><strong>87<sup>分</sup></strong><span>高于 78% 候选人</span></div><i class="ring">87</i></div>
      <div class="metrics"><div><span><MessageSquareText :size="14"/>逻辑性</span><b>92</b><i><u style="width:92%"/></i></div><div><span><CheckCircle2 :size="14"/>完整性</span><b>84</b><i><u style="width:84%"/></i></div><div><span><Target :size="14"/>关键词命中</span><b>86</b><i><u style="width:86%"/></i></div></div>
      <div class="keyword"><h3>关键词命中 <span>5 / 6</span></h3><div><span>ref</span><span>reactive</span><span>响应性</span><span>解构</span><span>基本类型</span><span class="miss">toRefs</span></div></div>
      <div class="switch-notice"><Sparkles :size="18"/><p><b>技术主题已切换</b>检测到连续 3 题未达标准，已按当前阶段配置切换至 Vue 主题。</p></div>
      <div class="note"><h3>阶段重点</h3><p>{{ stage.focus }}。候选人对 Vue 3 响应式系统理解准确，建议继续考察组合式 API 实战能力。</p></div>
    </aside></div>
  </main><ToastMessage :message="toast"/></div>
</template>

<style scoped>
.meeting-page{min-height:100vh;background:#f4f7fb}.meeting-page>main{margin-left:96px;padding:16px 18px}.ai-layout{height:calc(100vh - 117px);min-height:650px;display:grid;grid-template-columns:minmax(680px,1fr) 330px;gap:14px;margin-top:14px}.dialog-card{display:flex;flex-direction:column;overflow:hidden}.dialog-card>header{height:54px;padding:0 16px;border-bottom:1px solid #e3e9f2;display:flex;align-items:center;justify-content:space-between}.dialog-card h2{font-size:14px;display:flex;align-items:center;gap:8px}.dialog-card h2 .pill{font-weight:500}.dialog-card header p{font-size:9px;color:#91a0b4;margin-top:3px}.dialog-card header>span{font-size:9px;color:#7f8ea3;display:flex;align-items:center;gap:7px}.dialog-card header>span i{width:90px;height:5px;border-radius:5px;background:#dfe6ef}.dialog-card header>span b{display:block;width:40%;height:100%;background:#2563eb;border-radius:inherit}.dialog-stream{flex:1;overflow:auto;background:#f8fafc;padding:14px 18px}.dialog-row{display:grid;grid-template-columns:28px minmax(0,1fr);gap:4px 8px;margin-bottom:13px;align-items:start}.dialog-row.candidate{grid-template-columns:minmax(0,1fr) 28px}.dialog-row.candidate .speaker{grid-column:2}.dialog-row.candidate .msg{grid-column:1;grid-row:1;text-align:left;justify-self:end;background:white;border:1px solid #dce5f0}.dialog-row.candidate small{grid-column:1;text-align:right;justify-self:end}.speaker{width:27px;height:27px;border-radius:8px;display:grid;place-items:center}.speaker.ai{background:#2563eb;color:white}.speaker.person{background:#687a8e;color:white;font-size:11px}.msg{max-width:80%;background:#eaf1ff;border-radius:4px 12px 12px 12px;padding:9px 11px;font-size:11px;line-height:1.5;position:relative}.dialog-row small{grid-column:2;color:#93a1b4;font-size:8px;display:flex;align-items:center;gap:3px}.dialog-row.notice{display:flex;justify-content:center}.notice .msg{background:#eef2f6;color:#7f8da1;border-radius:14px;font-size:9px}.dialog-row.active .msg{border:2px solid #2563eb;background:white}.current{position:absolute;left:-2px;top:-19px;background:#2563eb;color:white;padding:3px 7px;border-radius:6px 6px 0 0;font-size:8px}.answer-input{height:48px;border-top:1px solid #e4eaf2;padding:7px 14px;display:flex;gap:8px}.answer-input input{flex:1;border:0;outline:0;border-radius:8px;background:#f1f4f8;padding:0 10px;font-size:10px}.answer-input button{width:36px;border:0;border-radius:8px;background:#2563eb;color:white;display:grid;place-items:center}.dialog-card>footer{height:63px;border-top:1px solid #e4eaf2;padding:0 14px;display:flex;align-items:center;justify-content:space-between}.dialog-card>footer>span{color:#687991;font-size:9px}.dialog-card>footer>span i{display:inline-block;width:7px;height:7px;border-radius:50%;background:#10b981;margin-right:6px}.dialog-card>footer>div{display:flex;gap:7px}.analysis-card{padding:16px;overflow:auto}.analysis-head{display:flex;align-items:center;gap:9px}.analysis-head>span{width:32px;height:32px;border-radius:9px;display:grid;place-items:center;background:#2563eb;color:white}.analysis-head h2{font-size:14px}.analysis-head p{font-size:8px;color:#92a0b4;margin-top:2px}.analysis-head em{margin-left:auto;font-size:8px;color:#2563eb;background:#edf4ff;padding:4px 7px;border-radius:9px;font-style:normal}.score-main{display:flex;align-items:center;justify-content:space-between;background:linear-gradient(135deg,#eaf2ff,#f2f8ff);border-radius:12px;margin-top:14px;padding:14px}.score-main small,.score-main strong,.score-main span{display:block}.score-main small{color:#687a94;font-size:9px}.score-main strong{font-size:31px;color:#2057d8}.score-main sup{font-size:9px}.score-main span{font-size:8px;color:#5f75a0}.ring{width:58px;height:58px;border:6px solid #b7d2ff;border-top-color:#2563eb;border-right-color:#2563eb;border-radius:50%;display:grid;place-items:center;color:#2563eb;font-size:12px;font-style:normal}.metrics{margin:14px 0}.metrics>div{display:grid;grid-template-columns:1fr 24px;gap:4px;align-items:center;margin:10px 0}.metrics span{display:flex;align-items:center;gap:6px;color:#5e708b;font-size:10px}.metrics span svg{color:#2563eb}.metrics b{font-size:10px;text-align:right}.metrics i{grid-column:1/3;height:5px;border-radius:5px;background:#e3e9f1}.metrics u{display:block;height:100%;background:linear-gradient(90deg,#2563eb,#06b6d4);border-radius:inherit}.keyword h3,.note h3{font-size:11px;margin-bottom:8px}.keyword h3 span{float:right;color:#2563eb}.keyword>div{display:flex;flex-wrap:wrap;gap:5px}.keyword>div span{font-size:9px;padding:4px 7px;border-radius:5px;background:#e8faf4;color:#07835d}.keyword>div .miss{background:#feecec;color:#dc3030;text-decoration:line-through}.switch-notice{margin-top:16px;padding:11px;background:#fff4e3;border:1px solid #fde2b4;border-radius:9px;color:#e67b08;display:flex;gap:7px}.switch-notice svg{flex:none}.switch-notice p{font-size:9px;line-height:1.5;color:#7b6750}.switch-notice b{display:block;color:#c66305}.note{margin-top:15px;padding-top:14px;border-top:1px solid #e5ebf3}.note p{font-size:9px;line-height:1.6;color:#6c7d95}
</style>



