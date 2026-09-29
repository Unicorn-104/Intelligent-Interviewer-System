<script setup>
import { ref, computed, nextTick, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Search, Video, Zap, Smile, Paperclip, Send, Settings2, FileText, Bell } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import { listSessions, listMessages, sendMessage, readSession, readAll, uploadFile, listQuickReplies, saveQuickReply, deleteQuickReply } from '@/api/system/im'
import { refreshUnread, totalUnread } from '@/views/enterprise/store/unread'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'

const route = useRoute()
const router = useRouter()
const keyword = ref('')
const input = ref('')
const scroller = ref()
const inputEl = ref()
const fileInput = ref()
const emojiOpen = ref(false)
const loading = ref(false)

const conversations = ref([])
const messages = ref([])
const activeId = ref(null)
// 从候选人页"发起对话"进入的新会话（尚无 sessionId，发送首条消息后由后端创建）
const newChat = ref(null)

// 新会话态：peerId 存在且尚未建立会话时构造虚拟会话
const activeConv = computed(() => {
  if (activeId.value != null) return conversations.value.find(c => c.id === activeId.value) || null
  if (newChat.value) return { id: null, name: newChat.value.peerName, summary: '', avatar: '', unread: 0 }
  return null
})

// 快捷回复模板：从后端 t_im_quick_reply 加载，元素为 {id,category,content}
const templates = ref([])
async function loadTemplates() {
  const res = await listQuickReplies()
  templates.value = res.data || []
}
loadTemplates()

// 管理模板弹窗
const manageOpen = ref(false)
const editing = ref(null)
const eform = ref({ category: '', content: '' })
function openManage() { editing.value = null; eform.value = { category: '', content: '' }; manageOpen.value = true }
function startEdit(t) { editing.value = t.id; eform.value = { category: t.category, content: t.content } }
function startNew() { editing.value = null; eform.value = { category: '', content: '' } }
async function submitTpl() {
  if (!eform.value.category.trim() || !eform.value.content.trim()) { ElMessage.warning('分类与内容不能为空'); return }
  await saveQuickReply({ id: editing.value, category: eform.value.category.trim(), content: eform.value.content.trim() })
  ElMessage.success(editing.value ? '已更新' : '已新增')
  editing.value = null; eform.value = { category: '', content: '' }
  loadTemplates()
}
async function removeTpl(t) {
  if (!confirm(`确定删除该模板？\n${t.content}`)) return
  await deleteQuickReply(t.id)
  ElMessage.success('已删除')
  loadTemplates()
}

const emojis = ['😀','😄','😊','😉','👍','🙏','👌','','🤝','','❤️','😅','🤔','👏','🙌','✅','☕','']

const filtered = computed(() => {
  const kw = keyword.value.trim()
  if (!kw) return conversations.value
  return conversations.value.filter(c => c.name?.includes(kw) || c.summary?.includes(kw))
})

function resolveUrl(p) {
  if (!p) return ''
  if (p.startsWith('http')) return p
  return import.meta.env.VITE_APP_BASE_API + p
}

// yyyy-MM-dd HH:mm:ss -> 今天显示 HH:mm，昨天显示 昨天 HH:mm，其余 MM-DD
function fmtTime(s) {
  if (!s) return ''
  const d = new Date(s.replace(/-/g, '/'))
  const now = new Date()
  const hm = String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0')
  if (d.toDateString() === now.toDateString()) return hm
  const yest = new Date(now.getTime() - 86400000)
  if (d.toDateString() === yest.toDateString()) return '昨天 ' + hm
  return String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0')
}

function scrollToBottom() {
  nextTick(() => { if (scroller.value) scroller.value.scrollTop = scroller.value.scrollHeight })
}

async function loadConversations() {
  try {
    const res = await listSessions()
    conversations.value = (res.data || []).map(s => ({
      id: s.sessionId,
      peerId: s.peerId,
      name: s.peerName || ('用户' + s.peerId),
      avatar: resolveUrl(s.peerAvatar),
      summary: s.lastMessage || '',
      time: fmtTime(s.lastMessageAt),
      unread: s.unread || 0
    }))
  } catch (e) {
    ElMessage.error(e?.message || '加载会话失败')
  }
}

async function openConv(c) {
  newChat.value = null
  activeId.value = c.id
  c.unread = 0
  loading.value = true
  try {
    await loadMessages(c.id)
    scrollToBottom()
    await readSession(c.id)
    refreshUnread()
  } catch (e) {
    ElMessage.error(e?.message || '加载消息失败')
  } finally {
    loading.value = false
  }
}

async function loadMessages(sessionId) {
  const res = await listMessages(sessionId)
  messages.value = (res.data || []).map(m => ({
    id: m.messageId,
    mine: !!m.isMine,
    type: m.type,
    text: m.content,
    attachmentUrl: resolveUrl(m.attachmentUrl),
    time: fmtTime(m.sendTime)
  }))
}

// 候选人页"发起对话"进入：已有会话直接打开，否则进入新会话态（空聊天框）
function startChatWith(peerId, peerName) {
  const existing = conversations.value.find(c => String(c.peerId) === String(peerId))
  if (existing) { openConv(existing); return }
  activeId.value = null
  messages.value = []
  newChat.value = { peerId, peerName }
  scrollToBottom()
}

async function send() {
  const text = input.value.trim()
  if (!text || !activeConv.value) return
  try {
    const body = { type: 1, content: text }
    if (activeId.value != null) body.sessionId = activeId.value
    else body.peerId = newChat.value.peerId
    await sendMessage(body)
    input.value = ''
    emojiOpen.value = false
    await afterSend()
  } catch (e) {
    ElMessage.error(e?.message || '发送失败')
  }
}

async function pickFile() { fileInput.value?.click() }

async function onFileChange(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file || !activeConv.value) return
  try {
    const fd = new FormData()
    fd.append('file', file)
    const up = await uploadFile(fd)
    const body = {
      type: 3,
      content: up.originalFilename || file.name,
      attachmentUrl: up.fileName
    }
    if (activeId.value != null) body.sessionId = activeId.value
    else body.peerId = newChat.value.peerId
    await sendMessage(body)
    await afterSend()
  } catch (err) {
    ElMessage.error(err?.message || '文件发送失败')
  }
}

// 发送后刷新：新会话态下激活后端创建的会话，否则重拉当前会话消息
async function afterSend() {
  if (activeId.value == null && newChat.value) {
    await loadConversations()
    const created = conversations.value.find(c => String(c.peerId) === String(newChat.value.peerId))
    if (created) { activeId.value = created.id; newChat.value = null; created.unread = 0; await loadMessages(created.id) }
  } else {
    await loadMessages(activeId.value)
    await loadConversations()
  }
  scrollToBottom()
  refreshUnread()
}

function addEmoji(e) { input.value += e; inputEl.value?.focus() }

function useTemplate(text) {
  input.value = text
  nextTick(() => { inputEl.value?.focus(); inputEl.value?.setSelectionRange(text.length, text.length) })
}

async function markRead() {
  conversations.value.forEach(c => { c.unread = 0 })
  await readAll()
  refreshUnread()
}

onMounted(async () => {
  await loadConversations()
  const { peerId, peerName } = route.query
  if (peerId) {
    startChatWith(peerId, peerName || ('用户' + peerId))
  } else if (conversations.value.length) {
    openConv(conversations.value[0])
  }
  refreshUnread()
})
</script>

<template>
  <div class="messages-page">
    <aside class="conversation-panel">
      <div class="search-row">
        <label class="conversation-search"><Search :size="16"/><input v-model="keyword" placeholder="搜索会话、姓名或关键词"/></label>
        <button class="read-all" :disabled="!totalUnread" title="全部已读" @click="markRead"><Bell :size="15"/></button>
      </div>
      <div class="conversation-list">
        <article v-for="item in filtered" :key="item.id" :class="{active:activeId===item.id}" @click="openConv(item)">
          <MiniAvatar :name="item.name" :size="40" color="#356f65" :src="item.avatar"/>
          <div><h3>{{item.name}}</h3><p>{{item.summary || '暂无消息'}}</p></div><time>{{item.time}}</time><em v-if="item.unread">{{item.unread}}</em>
        </article>
        <p v-if="!filtered.length" class="empty-list">没有匹配的会话</p>
      </div>
    </aside>

    <section class="chat-panel">
      <template v-if="activeConv">
        <header class="chat-head">
          <MiniAvatar :name="activeConv.name" :size="40" color="#356f65" :src="activeConv.avatar"/>
          <div class="chat-head-info"><h2>{{activeConv.name}}</h2><p>{{activeConv.summary}}</p></div>
          <button class="btn primary" @click="router.push('/enterprise/meeting/ai')"><Video :size="16"/>进入会议</button>
        </header>
        <div ref="scroller" class="message-stream">
          <div v-for="msg in messages" :key="msg.id" :class="['message-row', msg.type===5?'system':(msg.mine?'me':'other')]">
            <template v-if="msg.type===5"><span class="system-line">{{msg.text}}</span></template>
            <template v-else-if="msg.type===3">
              <a class="bubble file-bubble" :href="msg.attachmentUrl" target="_blank" download><FileText :size="14"/><b>{{msg.text}}</b><small>查看</small></a>
              <time v-if="msg.time">{{msg.time}}</time>
            </template>
            <template v-else-if="msg.type===2">
              <a class="bubble img-bubble" :href="msg.attachmentUrl" target="_blank"><img :src="msg.attachmentUrl" :alt="msg.text"/></a>
              <time v-if="msg.time">{{msg.time}}</time>
            </template>
            <template v-else>
              <span class="bubble">{{msg.text}}</span>
              <time v-if="msg.time">{{msg.time}}</time>
            </template>
          </div>
          <p v-if="loading" class="stream-loading">加载中…</p>
        </div>
        <footer class="composer">
          <div class="emoji-pop" v-if="emojiOpen">
            <button v-for="e in emojis" :key="e" @click="addEmoji(e)">{{e}}</button>
          </div>
          <div class="composer-tools">
            <button title="表情" @click="emojiOpen=!emojiOpen"><Smile :size="18"/></button>
            <button title="发送文件" @click="pickFile"><Paperclip :size="18"/></button>
            <button class="quick" v-if="templates.length" @click="useTemplate(templates[0].content)"><Zap :size="15"/>快捷回复</button>
            <input ref="fileInput" type="file" style="display:none" @change="onFileChange" />
          </div>
          <div>
            <textarea ref="inputEl" v-model="input" rows="1" @keydown.enter.exact.prevent="send" placeholder="输入消息，Enter 发送，Shift+Enter 换行…"></textarea>
            <button class="send" @click="send"><Send :size="17"/>发送</button>
          </div>
        </footer>
      </template>
      <div v-else class="chat-empty"><p>{{ loading ? '加载中…' : '暂无会话，请在候选人详情页发起沟通' }}</p></div>
    </section>

    <aside class="template-panel"><header><span><Zap :size="17"/>快捷回复模板</span><small>AI 智能推荐</small></header><div class="template-list"><button v-for="item in templates" :key="item.id" @click="useTemplate(item.content)"><label>{{item.category}}</label><span>{{item.content}}</span></button></div><div class="ai-tip"><Zap :size="16"/><p><b>AI 提示</b>可结合会话上下文微调话术，高频内容可加入模板库。</p></div><button class="manage" @click="openManage"><Settings2 :size="15"/>管理模板</button></aside>

    <BaseModal v-if="manageOpen" title="管理快捷回复模板" width="640px" @close="manageOpen=false">
      <div class="tpl-manage">
        <div class="tpl-form">
          <input v-model="eform.category" class="cat" placeholder="分类，如：面试安排" maxlength="30"/>
          <input v-model="eform.content" class="cnt" placeholder="回复内容" maxlength="500" @keydown.enter.prevent="submitTpl"/>
          <button class="save" @click="submitTpl">{{editing?'保存修改':'新增'}}</button>
          <button v-if="editing" class="cancel" @click="startNew()">取消编辑</button>
        </div>
        <div class="tpl-rows">
          <div v-for="t in templates" :key="t.id" class="tpl-row" :class="{on:editing===t.id}">
            <label>{{t.category}}</label>
            <span>{{t.content}}</span>
            <div class="ops"><button @click="startEdit(t)">编辑</button><button class="del" @click="removeTpl(t)">删除</button></div>
          </div>
          <p v-if="!templates.length" class="none">暂无模板，请在上方新增</p>
        </div>
      </div>
    </BaseModal>
  </div>
</template>

<style scoped>
.messages-page{height:calc(100vh - 64px);padding:24px;display:grid;grid-template-columns:292px minmax(540px,1fr) 260px;gap:1px}.conversation-panel,.chat-panel,.template-panel{background:white;border:1px solid #e5ebf3}.conversation-panel{border-radius:14px 0 0 14px;overflow:hidden;display:flex;flex-direction:column}.search-row{display:flex;align-items:center;gap:8px;margin:14px;flex:none}.conversation-search{height:38px;flex:1;min-width:0;display:flex;align-items:center;gap:8px;background:#f2f5f9;border-radius:9px;padding:0 11px;color:#8999af}.conversation-search input{width:100%;border:0;outline:0;background:transparent;font-size:11px}.read-all{width:38px;height:38px;flex:none;border:1px solid #e0e7f0;border-radius:9px;background:white;color:#64748b;display:grid;place-items:center;cursor:pointer}.read-all:hover:not(:disabled){border-color:#8eb2fa;color:#2563eb}.read-all:disabled{opacity:.4;cursor:not-allowed}.conversation-list{overflow:auto;flex:1}.conversation-list article{height:77px;border-top:1px solid #e8edf4;display:grid;grid-template-columns:42px 1fr auto;gap:10px;align-items:center;padding:0 14px;position:relative;cursor:pointer}.conversation-list article.active{background:#edf4ff}.conversation-list article>div{min-width:0}.conversation-list h3{font-size:12px}.conversation-list p{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:#7d8ca1;font-size:10px;margin-top:5px}.conversation-list time{position:absolute;right:14px;top:13px;color:#98a5b7;font-size:9px}.conversation-list em{position:absolute;right:14px;bottom:11px;width:19px;height:19px;border-radius:50%;background:#2563eb;color:white;font-style:normal;font-size:9px;display:grid;place-items:center;line-height:1}.empty-list{border-top:1px solid #e8edf4;text-align:center;color:#98a5b7;font-size:10px;padding:24px 0;margin:0}.chat-panel{display:flex;flex-direction:column}.chat-head{height:86px;border-bottom:1px solid #e5ebf3;display:flex;align-items:center;gap:10px;padding:0 16px;flex:none}.chat-head-info{flex:1;min-width:0}.chat-head h2{font-size:14px;display:flex;gap:6px;align-items:center}.chat-head p{display:block;color:#7c8ca3;font-size:9px;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.message-stream{flex:1;overflow:auto;background:#f8fafc;padding:18px 18px 10px}.stream-loading{text-align:center;color:#98a5b7;font-size:10px}.message-row{display:flex;flex-direction:column;align-items:flex-start;margin-bottom:17px}.message-row.me{align-items:flex-end}.bubble{max-width:76%;padding:11px 13px;border-radius:5px 13px 13px 13px;background:#eaf1ff;font-size:11px;line-height:1.55;white-space:pre-wrap;word-break:break-word}.message-row.me .bubble{background:white;border:1px solid #dce5f0;border-radius:13px 5px 13px 13px}.file-bubble{display:flex;align-items:center;gap:7px;text-decoration:none;color:inherit;cursor:pointer}.file-bubble svg{color:#2563eb;flex:none}.file-bubble b{font-weight:500;font-size:11px;max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.file-bubble small{color:#2563eb;font-size:9px}.img-bubble{padding:4px}.img-bubble img{max-width:220px;max-height:180px;border-radius:8px;display:block}.message-row time{color:#9aa7b8;font-size:9px;margin-top:4px}.message-row.system{align-items:center;margin:5px 0 17px}.system-line{color:#95a2b4;font-size:9px;display:flex;align-items:center;width:80%;gap:8px}.system-line:before,.system-line:after{content:'';height:1px;background:#e5ebf3;flex:1}.chat-empty{flex:1;display:grid;place-items:center;color:#98a5b7;font-size:12px}.composer{min-height:86px;border-top:1px solid #e5ebf3;padding:8px 15px;position:relative;flex:none}.composer-tools{height:28px;display:flex;gap:5px;align-items:center}.composer-tools button{border:0;background:none;color:#64748b;padding:4px;cursor:pointer}.composer-tools .quick{margin-left:auto;display:flex;align-items:center;gap:5px;color:#2563eb;font-size:10px}.composer>div:last-child{display:flex;gap:8px;align-items:flex-end}.composer textarea{min-height:36px;max-height:96px;flex:1;border:0;outline:0;border-radius:8px;background:#f0f4f9;padding:9px 11px;font-size:11px;resize:none;font-family:inherit;line-height:1.5}.send{height:36px;border:0;border-radius:8px;background:#2563eb;color:white;padding:0 13px;display:flex;align-items:center;gap:6px;cursor:pointer}.emoji-pop{position:absolute;left:14px;bottom:80px;background:white;border:1px solid #e0e7f0;border-radius:10px;padding:8px;display:grid;grid-template-columns:repeat(8,1fr);gap:2px;box-shadow:0 8px 24px rgba(30,41,59,.14);z-index:5}.emoji-pop button{border:0;background:none;font-size:16px;padding:4px;border-radius:6px;cursor:pointer}.emoji-pop button:hover{background:#f0f4f9}.template-panel{border-radius:0 14px 14px 0;display:flex;flex-direction:column;overflow:hidden}.template-panel header{height:60px;padding:0 14px;border-bottom:1px solid #e5ebf3;display:flex;align-items:center;justify-content:space-between}.template-panel header span{font-size:12px;font-weight:700;display:flex;align-items:center;gap:7px}.template-panel header svg{color:#2563eb}.template-panel header small{color:#9aa7b8;font-size:8px}.template-list{padding:12px;display:flex;flex-direction:column;gap:9px;overflow:auto}.template-list button{border:1px solid #e0e7f0;border-radius:8px;background:white;padding:8px 9px;text-align:left;cursor:pointer}.template-list button:hover{border-color:#8eb2fa;background:#f8fbff}.template-list label{display:block;color:#8392a7;font-size:9px;margin-bottom:4px}.template-list span{font-size:10px;line-height:1.45;color:#40516a}.ai-tip{margin:3px 12px;padding:10px;background:#edf4ff;color:#2563eb;border-radius:9px;display:flex;gap:7px}.ai-tip svg{flex:none}.ai-tip p{font-size:9px;color:#6a7d99;line-height:1.45}.ai-tip b{color:#315b9e;display:block}.manage{height:42px;border:0;border-top:1px solid #e5ebf3;background:white;color:#2563eb;margin-top:auto;display:flex;align-items:center;justify-content:center;gap:6px;font-size:10px;cursor:pointer}
.tpl-manage{display:flex;flex-direction:column;gap:12px}.tpl-form{display:flex;gap:8px}.tpl-form input{height:34px;border:1px solid #dfe6ef;border-radius:8px;padding:0 10px;font-size:12px;outline:none}.tpl-form input:focus{border-color:#2563eb}.tpl-form .cat{width:140px;flex:none}.tpl-form .cnt{flex:1;min-width:0}.tpl-form .save{height:34px;flex:none;border:0;border-radius:8px;background:#2563eb;color:white;padding:0 14px;font-size:11px;cursor:pointer}.tpl-form .cancel{height:34px;flex:none;border:1px solid #dfe6ef;border-radius:8px;background:white;color:#64748b;padding:0 12px;font-size:11px;cursor:pointer}
.tpl-rows{max-height:340px;overflow:auto;border:1px solid #eef2f7;border-radius:9px}.tpl-row{display:grid;grid-template-columns:96px 1fr 88px;gap:10px;align-items:center;padding:9px 12px;border-bottom:1px solid #f2f5f9;font-size:11px}.tpl-row:last-child{border-bottom:0}.tpl-row.on{background:#f4f8ff}.tpl-row label{color:#8392a7;font-size:10px}.tpl-row span{color:#40516a;line-height:1.45;word-break:break-word}.tpl-row .ops{display:flex;gap:8px;justify-content:flex-end}.tpl-row .ops button{border:0;background:none;color:#2563eb;font-size:10px;cursor:pointer;padding:0}.tpl-row .ops button.del{color:#ef4444}.none{padding:20px;text-align:center;color:#9aa7b9;font-size:11px}
</style>
