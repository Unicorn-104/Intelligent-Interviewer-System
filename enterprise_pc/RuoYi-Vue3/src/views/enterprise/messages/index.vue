<script setup>
import { ref, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { Search, Video, Zap, Smile, Paperclip, Send, Settings2, Bell, CalendarDays } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import { api, reserveApi } from '@/views/enterprise/api/contract'

const router = useRouter()
const activeFilter = ref('全部')
const activeIndex = ref(0)
const input = ref('')
const scroller = ref()
const conversations = [
  { name:'张敏', tag:'面试提醒', summary:'好的，那我把作品集链接也提前...', time:'09:32', unread:2, color:'#356f65' },
  { name:'李强', tag:'候选人', summary:'好的，我 15:45 会准时进入会...', time:'09:12', unread:2, color:'#725445' },
  { name:'系统通知', tag:'系统通知', summary:'李强已通过终审，Offer 流程待...', time:'昨天 18:24', icon:'bell' },
  { name:'王芳', tag:'候选人', summary:'简历已更新，麻烦您再看一下', time:'昨天 17:40', unread:1, color:'#665070' },
  { name:'面试提醒', tag:'面试提醒', summary:'王一诺 · UI设计师 · AI 结构化预面...', time:'昨天 16:02', unread:1, icon:'calendar' },
  { name:'陈晨', tag:'候选人', summary:'好的，那下周一上午 10:00 见', time:'昨天 15:20', color:'#8d6a28' }
]
const messages = ref([
  { type:'system', text:'面试邀请已发送 · 今天 09:15' },
  { type:'other', text:'张敏你好，AI 结构化预面已安排在今天 14:00，请提前 15 分钟进入。', time:'09:16' },
  { type:'me', text:'您好！收到啦，14:00 我可以准时参加，谢谢您～', time:'09:18' },
  { type:'other', text:'好的，请用电脑进入会议，AI 面试官会先进行提问。', time:'09:20' },
  { type:'me', text:'想确认下，AI 结构化预面需要准备作品集吗？', time:'09:25' },
  { type:'system', text:'面试提醒 · 距离 AI 结构化预面开始还有 3 小时 52 分钟' },
  { type:'me', text:'好的，那我把作品集链接也提前准备好，谢谢～', time:'09:32' }
])
const templates = [
  ['面试安排','您好，您的 AI 结构化预面已安排于明天 14:00，请提前 15 分钟进入会议。'],
  ['面试安排','您好，面试时间如需调整，您看本周五 10:30 是否方便？'],
  ['进度反馈','您已通过初筛，HR 将在 1 个工作日内联系您确认下一步安排。'],
  ['进度反馈','您的当前阶段评估已完成，后续安排请留意系统通知。'],
  ['通用话术','您好，请问现在方便进行简短电话沟通吗？']
]
function send(){if(!input.value.trim())return;reserveApi(api.messaging.messages,{conversationId:'CONV-1001',type:'text',content:input.value,clientRequestId:`msg-${Date.now()}`});messages.value.push({type:'other',text:input.value,time:'刚刚'});input.value='';nextTick(()=>{scroller.value.scrollTop=scroller.value.scrollHeight})}
function useTemplate(text){input.value=text}
function markRead(){reserveApi(api.messaging.notifications,{status:1,type:'interview',page:1,pageSize:20});reserveApi({method:'PATCH',path:'/api/v1/notification/read-all',body:[]});}
</script>

<template>
  <div class="messages-page">
    <aside class="conversation-panel">
      <label class="conversation-search"><Search :size="16"/><input placeholder="搜索会话、姓名或关键词"/></label>
      <div class="filter-tabs"><button v-for="item in ['全部','候选人','系统通知','面试提醒']" :key="item" :class="{active:activeFilter===item}" @click="activeFilter=item">{{item}}</button></div>
      <div class="conversation-list">
        <article v-for="(item,index) in conversations.filter(x=>activeFilter==='全部'||x.tag===activeFilter)" :key="item.name" :class="{active:activeIndex===index}" @click="activeIndex=index">
          <MiniAvatar v-if="!item.icon" :name="item.name" :size="40" :color="item.color"/><span v-else class="sys-icon"><Bell v-if="item.icon==='bell'" :size="18"/><CalendarDays v-else :size="18"/></span>
          <div><h3>{{item.name}} <span>{{item.tag}}</span></h3><p>{{item.summary}}</p></div><time>{{item.time}}</time><em v-if="item.unread">{{item.unread}}</em>
        </article>
      </div>
    </aside>

    <section class="chat-panel">
      <header class="chat-head"><MiniAvatar name="张敏" :size="40" color="#356f65"/><div><h2>张敏 <span class="pill">面试提醒</span></h2><p>UI/UX 设计师 · 设计中心 · 深圳 · 在招 3 人</p><small>AI 结构化预面 · 今天 14:00-14:45 · 面试官 李薇</small></div><button class="btn" @click="markRead"><Bell :size="15"/>全部已读</button><button class="btn primary" @click="router.push('/enterprise/meeting/ai')"><Video :size="16"/>进入会议</button></header>
      <div ref="scroller" class="message-stream"><div v-for="(msg,index) in messages" :key="index" :class="['message-row',msg.type]"><span v-if="msg.type!=='system'" class="bubble">{{msg.text}}</span><span v-else class="system-line">{{msg.text}}</span><time v-if="msg.time">{{msg.time}}</time></div></div>
      <footer class="composer"><div class="composer-tools"><button><Smile :size="18"/></button><button><Paperclip :size="18"/></button><button class="quick" @click="input=templates[0][1]"><Zap :size="15"/>快捷回复</button></div><div><input v-model="input" @keyup.enter="send" placeholder="输入消息，Enter 发送…"/><button class="send" @click="send"><Send :size="17"/>发送</button></div></footer>
    </section>

    <aside class="template-panel"><header><span><Zap :size="17"/>快捷回复模板</span><small>AI 智能推荐</small></header><div class="template-list"><button v-for="item in templates" :key="item[1]" @click="useTemplate(item[1])"><label>{{item[0]}}</label><span>{{item[1]}}</span></button></div><div class="ai-tip"><Zap :size="16"/><p><b>AI 提示</b>可结合会话上下文微调话术，高频内容可加入模板库。</p></div><button class="manage"><Settings2 :size="15"/>管理模板</button></aside>
  </div>
</template>

<style scoped>
.messages-page{height:calc(100vh - 64px);padding:24px;display:grid;grid-template-columns:292px minmax(540px,1fr) 260px;gap:1px}.conversation-panel,.chat-panel,.template-panel{background:white;border:1px solid #e5ebf3}.conversation-panel{border-radius:14px 0 0 14px;overflow:hidden}.conversation-search{height:38px;margin:14px;display:flex;align-items:center;gap:8px;background:#f2f5f9;border-radius:9px;padding:0 11px;color:#8999af}.conversation-search input{width:100%;border:0;outline:0;background:transparent;font-size:11px}.filter-tabs{display:flex;gap:5px;padding:0 14px 13px}.filter-tabs button{height:29px;padding:0 10px;border:0;border-radius:7px;background:#f1f4f8;color:#53657f;font-size:10px}.filter-tabs button.active{background:#2563eb;color:white}.conversation-list article{height:77px;border-top:1px solid #e8edf4;display:grid;grid-template-columns:42px 1fr auto;gap:10px;align-items:center;padding:0 14px;position:relative;cursor:pointer}.conversation-list article.active{background:#edf4ff}.conversation-list article>div{min-width:0}.conversation-list h3{font-size:12px}.conversation-list h3 span{font-size:8px;color:#275ec4;background:#e7efff;border-radius:4px;padding:2px 4px;margin-left:4px}.conversation-list p{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:#7d8ca1;font-size:10px;margin-top:5px}.conversation-list time{position:absolute;right:14px;top:13px;color:#98a5b7;font-size:9px}.conversation-list em{position:absolute;right:14px;bottom:11px;width:19px;height:19px;border-radius:50%;background:#2563eb;color:white;font-style:normal;font-size:9px;display:grid;place-items:center}.sys-icon{width:40px;height:40px;border-radius:11px;background:#edf4ff;color:#2563eb;display:grid;place-items:center}.chat-panel{display:flex;flex-direction:column}.chat-head{height:86px;border-bottom:1px solid #e5ebf3;display:flex;align-items:center;gap:10px;padding:0 16px}.chat-head>div{flex:1}.chat-head h2{font-size:14px;display:flex;gap:6px;align-items:center}.chat-head p,.chat-head small{display:block;color:#7c8ca3;font-size:9px;margin-top:4px}.message-stream{flex:1;overflow:auto;background:#f8fafc;padding:18px 18px 10px}.message-row{display:flex;flex-direction:column;align-items:flex-start;margin-bottom:17px}.message-row.me{align-items:flex-end}.bubble{max-width:76%;padding:11px 13px;border-radius:5px 13px 13px 13px;background:#eaf1ff;font-size:11px;line-height:1.55}.message-row.me .bubble{background:white;border:1px solid #dce5f0;border-radius:13px 5px 13px 13px}.message-row time{color:#9aa7b8;font-size:9px;margin-top:4px}.message-row.system{align-items:center;margin:5px 0 17px}.system-line{color:#95a2b4;font-size:9px;display:flex;align-items:center;width:80%;gap:8px}.system-line:before,.system-line:after{content:'';height:1px;background:#e5ebf3;flex:1}.composer{min-height:86px;border-top:1px solid #e5ebf3;padding:8px 15px}.composer-tools{height:28px;display:flex;gap:5px;align-items:center}.composer-tools button{border:0;background:none;color:#64748b;padding:4px}.composer-tools .quick{margin-left:auto;display:flex;align-items:center;gap:5px;color:#2563eb;font-size:10px}.composer>div:last-child{display:flex;gap:8px}.composer input{height:36px;flex:1;border:0;outline:0;border-radius:8px;background:#f0f4f9;padding:0 11px;font-size:11px}.send{height:36px;border:0;border-radius:8px;background:#2563eb;color:white;padding:0 13px;display:flex;align-items:center;gap:6px}.template-panel{border-radius:0 14px 14px 0;display:flex;flex-direction:column;overflow:hidden}.template-panel header{height:60px;padding:0 14px;border-bottom:1px solid #e5ebf3;display:flex;align-items:center;justify-content:space-between}.template-panel header span{font-size:12px;font-weight:700;display:flex;align-items:center;gap:7px}.template-panel header svg{color:#2563eb}.template-panel header small{color:#9aa7b8;font-size:8px}.template-list{padding:12px;display:flex;flex-direction:column;gap:9px}.template-list button{border:1px solid #e0e7f0;border-radius:8px;background:white;padding:8px 9px;text-align:left}.template-list button:hover{border-color:#8eb2fa;background:#f8fbff}.template-list label{display:block;color:#8392a7;font-size:9px;margin-bottom:4px}.template-list span{font-size:10px;line-height:1.45;color:#40516a}.ai-tip{margin:3px 12px;padding:10px;background:#edf4ff;color:#2563eb;border-radius:9px;display:flex;gap:7px}.ai-tip svg{flex:none}.ai-tip p{font-size:9px;color:#6a7d99;line-height:1.45}.ai-tip b{color:#315b9e;display:block}.manage{height:42px;border:0;border-top:1px solid #e5ebf3;background:white;color:#2563eb;margin-top:auto;display:flex;align-items:center;justify-content:center;gap:6px;font-size:10px}
</style>



