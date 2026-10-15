<script setup>
import { ref, computed, nextTick, onBeforeUnmount, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Search, Video, Play, Zap, Smile, Paperclip, Send, Settings2, FileText, Bell, Copy } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import { listSessions, listMessages, sendMessage, readSession, readAll, uploadFile, listQuickReplies, saveQuickReply, deleteQuickReply } from '@/api/system/im'
import { createRoomLink, listCandidatePositions, listInterviewers, listInterviewerNotices, respondInterviewNotice } from '@/api/system/conference'
import { refreshUnread, totalUnread } from '@/views/enterprise/store/unread'
import { match as pinyinMatch } from 'pinyin-pro'
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
let refreshTimer

const conversations = ref([])
const messages = ref([])
const activeId = ref(null)
// 从候选人页"发起对话"进入的新会话（尚无 sessionId，发送首条消息后由后端创建）
const newChat = ref(null)

// 新会话态：peerId 存在且尚未建立会话时构造虚拟会话
const activeConv = computed(() => {
  if (activeId.value === SYSTEM_NOTICE_ID) return noticeConv.value
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

// 会话搜索：中文直接包含匹配；英文关键词额外支持拼音全拼与首字母模糊匹配（如 lina/ln → 李娜，zghr → 张工HR）
function convMatch(text, kw) {
  if (!text) return false
  if (text.includes(kw)) return true
  if (/^[a-zA-Z]+$/.test(kw)) {
    try {
      return !!pinyinMatch(text, kw)
    } catch (e) {
      return false
    }
  }
  return false
}

const filtered = computed(() => {
  const kw = keyword.value.trim()
  const notice = noticeConv.value
  if (!kw) return [notice, ...conversations.value]
  const rest = conversations.value.filter(c => convMatch(c.name, kw) || convMatch(c.summary, kw))
  if (convMatch(notice.name, kw) || convMatch(notice.summary, kw)) return [notice, ...rest]
  return rest
})

// 种子数据里写入的失效外链（DNS 无法解析）会导致浏览器报 ERR_NAME_NOT_RESOLVED，
// 这里直接返回空串，交给 MiniAvatar 降级为首字母头像
const DEAD_AVATAR_HOSTS = ['cdn.recruitai.com']

function resolveUrl(p) {
  if (!p) return ''
  if (p.startsWith('http')) {
    try {
      if (DEAD_AVATAR_HOSTS.includes(new URL(p).host)) return ''
    } catch (e) {
      return ''
    }
    return p
  }
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

// 将文本消息中的 http(s) 链接拆分为可点击片段，普通聊天消息里的链接可直接打开
function linkParts(text) {
  if (!text) return []
  const parts = []
  const re = /https?:\/\/[^\s]+/g
  let last = 0
  let m
  while ((m = re.exec(text))) {
    if (m.index > last) parts.push({ text: text.slice(last, m.index) })
    parts.push({ text: m[0], href: m[0] })
    last = m.index + m[0].length
  }
  if (last < text.length) parts.push({ text: text.slice(last) })
  return parts
}

// ---------- 面试预约通知（固定在消息中心顶部的系统会话） ----------
const SYSTEM_NOTICE_ID = '__notices__'
const NOTICE_MODE_LABEL = { 1: '纯AI', 2: 'AI + 单面试官', 3: 'AI + 多面试官', 4: '无AI纯人工' }
const notices = ref([])
const noticesLoading = ref(false)

const pendingNoticeCount = computed(() => notices.value.filter(n => Number(n.acceptStatus) === 0).length)

// 系统会话：始终置顶，未读数为待确认邀约数
const noticeConv = computed(() => ({
  id: SYSTEM_NOTICE_ID,
  system: true,
  name: '面试预约通知',
  avatar: '',
  summary: notices.value.length ? `共 ${notices.value.length} 条邀约，待确认 ${pendingNoticeCount.value} 条` : '暂无面试邀约',
  time: notices.value.length ? notices.value[0].noticeAt : '',
  unread: pendingNoticeCount.value
}))

function noticeStatusText(s) {
  return Number(s) === 1 ? '已接受' : Number(s) === 2 ? '已拒绝' : '待确认'
}

async function loadNotices() {
  noticesLoading.value = true
  try {
    const res = await listInterviewerNotices()
    notices.value = res.data || []
  } catch (e) {
    notices.value = []
  } finally {
    noticesLoading.value = false
  }
}
loadNotices()

async function respondNotice(n, accept) {
  try {
    await respondInterviewNotice(n.sessionId, accept)
    ElMessage.success(accept ? '已接受面试邀约' : '已拒绝面试邀约')
    await loadNotices()
  } catch (e) {
    ElMessage.error(e?.message || '操作失败')
  }
}

// 接受邀约后可进入等候室（与链接进入一致，走会前准备页）
function enterWaitingRoom(n) {
  router.push({ path: '/enterprise/conference/prep', query: { sessionId: n.sessionId } })
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
  if (c.system) {
    await loadNotices()
    return
  }
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

async function refreshMessages() {
  try {
    await loadConversations()
    if (activeId.value != null && activeId.value !== SYSTEM_NOTICE_ID) {
      await loadMessages(activeId.value)
      await readSession(activeId.value)
    } else {
      await loadNotices()
    }
    refreshUnread()
  } catch {
    // Background refresh must not interrupt the current conversation.
  }
}

// 跳转录制回放页，按当前会话对方（候选人）查看其全部面试录制
function openRecordings() {
  const peer = peerUserId.value
  if (peer == null) { ElMessage.warning('当前会话缺少对方信息，无法查看录制'); return }
  router.push({
    path: '/enterprise/conference/records',
    query: { candidateUserId: peer, candidateName: activeConv.value?.name || '' }
  })
}

// ---------- 发起视频面试：生成会议链接 ----------
const linkOpen = ref(false)
const positionsLoading = ref(false)
const generating = ref(false)
const positions = ref([])
const interviewers = ref([])
const selectedInterviewerIds = ref([])
const linkResult = ref(null)
const linkForm = ref({ peerUserId: null, positionId: null, durationMinutes: 45, mode: 2 })

// 面试模式与面试官人数严格联动
const MODE_HINT = { 1: '纯AI 无需面试官，本企业成员可凭链接旁听', 2: '需选择 1 位面试官', 3: '需选择至少 2 位面试官', 4: '需选择至少 1 位面试官' }
const needInterviewers = computed(() => linkForm.value.mode !== 1)

// 当前会话对方用户 ID（新会话态取 newChat）
const peerUserId = computed(() => activeConv.value?.peerId ?? newChat.value?.peerId ?? null)
// 链接拼接规则：候选人端统一入口页 + token（权威定义，不带其它参数）
const linkUrl = computed(() => (linkResult.value ? import.meta.env.VITE_CANDIDATE_APP_URL + '/conference-join?token=' + linkResult.value.token : ''))

function openLinkModal() {
  const peer = peerUserId.value
  if (peer == null) { ElMessage.warning('当前会话缺少对方信息，无法发起视频面试'); return }
  linkForm.value = { peerUserId: peer, positionId: null, durationMinutes: 45, mode: 2 }
  positions.value = []
  selectedInterviewerIds.value = []
  linkResult.value = null
  linkOpen.value = true
  loadPositions()
  loadInterviewers()
}

async function loadInterviewers() {
  try {
    const res = await listInterviewers()
    interviewers.value = res.data || []
  } catch (e) {
    interviewers.value = []
  }
}

function toggleInterviewer(id) {
  const list = selectedInterviewerIds.value
  const idx = list.indexOf(id)
  // 单面试官模式为单选，多面试官 / 纯人工可多选
  if (linkForm.value.mode === 2) {
    selectedInterviewerIds.value = idx >= 0 ? [] : [id]
    return
  }
  if (idx >= 0) list.splice(idx, 1)
  else list.push(id)
}

function validateMode() {
  const mode = linkForm.value.mode
  const count = selectedInterviewerIds.value.length
  if (mode === 1 && count > 0) { ElMessage.warning('纯AI面试无需选择面试官'); return false }
  if (mode === 2 && count !== 1) { ElMessage.warning('AI + 单面试官模式需选择 1 位面试官'); return false }
  if (mode === 3 && count < 2) { ElMessage.warning('AI + 多面试官模式需选择至少 2 位面试官'); return false }
  if (mode === 4 && count < 1) { ElMessage.warning('无AI纯人工模式需选择至少 1 位面试官'); return false }
  return true
}

// 切换模式时收敛已选面试官，避免残留不符合人数要求的选择
function onModeChange() {
  if (linkForm.value.mode === 1) selectedInterviewerIds.value = []
  else if (linkForm.value.mode === 2 && selectedInterviewerIds.value.length > 1) {
    selectedInterviewerIds.value = selectedInterviewerIds.value.slice(0, 1)
  }
}

async function loadPositions() {
  positionsLoading.value = true
  try {
    const res = await listCandidatePositions(linkForm.value.peerUserId)
    positions.value = res.data || []
    if (positions.value.length) linkForm.value.positionId = positions.value[0].positionId
  } catch (e) {
    positions.value = []
    ElMessage.error(e?.message || '加载候选人岗位失败')
  } finally {
    positionsLoading.value = false
  }
}

async function generateLink() {
  if (linkForm.value.positionId == null) { ElMessage.warning('请选择面试岗位'); return }
  if (!validateMode()) return
  generating.value = true
  try {
    const res = await createRoomLink({
      peerUserId: linkForm.value.peerUserId,
      positionId: linkForm.value.positionId,
      durationMinutes: linkForm.value.durationMinutes,
      mode: linkForm.value.mode,
      interviewerIds: selectedInterviewerIds.value
    })
    linkResult.value = res.data || null
  } catch (e) {
    ElMessage.error(e?.message || '生成链接失败')
  } finally {
    generating.value = false
  }
}

async function copyLink() {
  if (!linkUrl.value) return
  try {
    await navigator.clipboard.writeText(linkUrl.value)
    ElMessage.success('链接已复制')
  } catch (e) {
    ElMessage.warning('复制失败，请手动选择链接复制')
  }
}

async function sendLinkToChat() {
  if (!linkResult.value) return
  try {
    const company = linkResult.value.companyName || '公司'
    const position = linkResult.value.positionTitle || '岗位'
    // 以普通文本消息发送（type=1），与日常聊天一致，链接在气泡内可点击
    const body = { type: 1, content: `【面试邀请】${company} ${position} 视频面试，请点击链接进入：${linkUrl.value}` }
    if (activeId.value != null) body.sessionId = activeId.value
    else body.peerId = newChat.value.peerId
    await sendMessage(body)
    linkOpen.value = false
    await afterSend()
    ElMessage.success('已发送到会话')
  } catch (e) {
    ElMessage.error(e?.message || '发送失败')
  }
}

onMounted(async () => {
  await loadConversations()
  const { peerId, peerName, notices } = route.query
  if (peerId) {
    startChatWith(peerId, peerName || ('用户' + peerId))
  } else if (notices) {
    openConv(noticeConv.value)
  } else if (conversations.value.length) {
    openConv(conversations.value[0])
  } else {
    openConv(noticeConv.value)
  }
  refreshUnread()
  refreshTimer = window.setInterval(refreshMessages, 5000)
})

onBeforeUnmount(() => {
  if (refreshTimer) window.clearInterval(refreshTimer)
})
</script>

<template>
  <div class="messages-page">
    <aside class="conversation-panel">
      <div class="search-row">
        <label class="conversation-search"><Search :size="16"/><input v-model="keyword" placeholder="搜索会话、姓名（支持拼音/首字母）"/></label>
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
          <button v-if="!activeConv.system" class="btn primary" @click="openLinkModal"><Video :size="16"/>发起视频面试</button>
        </header>
        <div v-if="activeConv.system" class="notice-stream">
          <p v-if="noticesLoading" class="stream-loading">加载中…</p>
          <p v-else-if="!notices.length" class="stream-loading">暂无面试预约通知</p>
          <article v-for="n in notices" :key="n.sessionId" class="notice-card">
            <header class="nc-head">
              <span class="nc-badge" :class="'st'+Number(n.acceptStatus)">{{ noticeStatusText(n.acceptStatus) }}</span>
              <em v-if="Number(n.isPrimary)===1" class="nc-primary">主面试官</em>
              <time>{{ n.noticeAt }}</time>
            </header>
            <h3>{{ n.candidateName }} · {{ n.positionTitle }}</h3>
            <p class="nc-line">面试方式：{{ NOTICE_MODE_LABEL[n.mode] || '—' }}</p>
            <p class="nc-line">预约时间：{{ n.appointmentStartAt }} ~ {{ n.appointmentEndAt }}</p>
            <div class="nc-actions">
              <template v-if="Number(n.acceptStatus)===0">
                <button class="nc-accept" @click="respondNotice(n, true)">接受担任本次面试</button>
                <button class="nc-reject" @click="respondNotice(n, false)">拒绝</button>
              </template>
              <button v-else-if="Number(n.acceptStatus)===1" class="nc-enter" @click="enterWaitingRoom(n)">进入等候室</button>
              <span v-else class="nc-rejected">已拒绝本次面试</span>
            </div>
          </article>
        </div>
        <div v-else ref="scroller" class="message-stream">
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
              <span class="bubble"><template v-for="(p, i) in linkParts(msg.text)" :key="i"><a v-if="p.href" class="bubble-link" :href="p.href" target="_blank" rel="noopener noreferrer">{{ p.text }}</a><template v-else>{{ p.text }}</template></template></span>
              <time v-if="msg.time">{{msg.time}}</time>
            </template>
          </div>
          <p v-if="loading" class="stream-loading">加载中…</p>
        </div>
        <footer v-if="!activeConv.system" class="composer">
          <div class="emoji-pop" v-if="emojiOpen">
            <button v-for="e in emojis" :key="e" @click="addEmoji(e)">{{e}}</button>
          </div>
          <div class="composer-tools">
            <button title="表情" @click="emojiOpen=!emojiOpen"><Smile :size="18"/></button>
            <button title="发送文件" @click="pickFile"><Paperclip :size="18"/></button>
            <button class="rec-btn" @click="openRecordings"><Play :size="16"/>查看录制</button>
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

    <BaseModal v-if="linkOpen" title="发起视频面试" width="520px" @close="linkOpen=false">
      <div class="link-form">
        <label class="lf-row">
          <span>面试岗位</span>
          <select v-model="linkForm.positionId" :disabled="!positions.length">
            <option v-if="!positions.length" :value="null">{{ positionsLoading ? '加载中…' : '该联系人暂无投递岗位' }}</option>
            <option v-for="p in positions" :key="p.applicationId" :value="p.positionId">{{ p.positionTitle }}</option>
          </select>
        </label>
        <label class="lf-row">
          <span>面试时长</span>
          <input class="lf-num" type="number" min="15" max="180" step="5" v-model.number="linkForm.durationMinutes" />
          <em>分钟</em>
        </label>
        <label class="lf-row">
          <span>面试模式</span>
          <select v-model.number="linkForm.mode" @change="onModeChange">
            <option :value="2">AI + 单面试官</option>
            <option :value="3">AI + 多面试官</option>
            <option :value="4">无AI纯人工</option>
            <option :value="1">纯AI</option>
          </select>
        </label>
        <div class="lf-row lf-col">
          <span>面试官</span>
          <div class="lf-interviewers">
            <p class="lf-mode-hint">{{ MODE_HINT[linkForm.mode] }}</p>
            <div v-if="needInterviewers" class="lf-iv-list">
              <label v-for="iv in interviewers" :key="iv.userId" class="lf-iv" :class="{on: selectedInterviewerIds.includes(iv.userId)}">
                <input type="checkbox" :checked="selectedInterviewerIds.includes(iv.userId)" @change="toggleInterviewer(iv.userId)" />
                <b>{{ iv.userName }}</b>
                <small v-if="iv.jobTitle || iv.department">{{ iv.jobTitle || iv.department }}</small>
              </label>
              <p v-if="!interviewers.length" class="lf-iv-empty">本企业暂无可用成员</p>
            </div>
            <p v-else class="lf-iv-empty">纯AI 模式无需选择面试官</p>
          </div>
        </div>
        <button class="lf-generate" :disabled="generating || linkForm.positionId == null" @click="generateLink">
          {{ generating ? '生成中…' : '生成链接' }}
        </button>
        <div v-if="linkUrl" class="lf-result">
          <label>面试链接</label>
          <input class="lf-link" :value="linkUrl" readonly />
          <div class="lf-result-actions">
            <button class="lf-copy" @click="copyLink"><Copy :size="14"/>复制链接</button>
            <button class="lf-send" @click="sendLinkToChat"><Send :size="14"/>发送到会话</button>
          </div>
        </div>
      </div>
    </BaseModal>
  </div>
</template>

<style scoped>
.messages-page{height:calc(100vh - 64px);padding:24px;display:grid;grid-template-columns:292px minmax(540px,1fr) 260px;grid-template-rows:minmax(0,1fr);gap:1px;overflow:hidden}.conversation-panel,.chat-panel,.template-panel{background:white;border:1px solid #e5ebf3}.conversation-panel{border-radius:14px 0 0 14px;overflow:hidden;display:flex;flex-direction:column}.search-row{display:flex;align-items:center;gap:8px;margin:14px;flex:none}.conversation-search{height:38px;flex:1;min-width:0;display:flex;align-items:center;gap:8px;background:#f2f5f9;border-radius:9px;padding:0 11px;color:#8999af}.conversation-search input{width:100%;border:0;outline:0;background:transparent;font-size:11px}.read-all{width:38px;height:38px;flex:none;border:1px solid #e0e7f0;border-radius:9px;background:white;color:#64748b;display:grid;place-items:center;cursor:pointer}.read-all:hover:not(:disabled){border-color:#8eb2fa;color:#2563eb}.read-all:disabled{opacity:.4;cursor:not-allowed}.conversation-list{overflow:auto;flex:1}.conversation-list article{height:77px;border-top:1px solid #e8edf4;display:grid;grid-template-columns:42px 1fr auto;gap:10px;align-items:center;padding:0 14px;position:relative;cursor:pointer}.conversation-list article.active{background:#edf4ff}.conversation-list article>div{min-width:0}.conversation-list h3{font-size:12px}.conversation-list p{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:#7d8ca1;font-size:10px;margin-top:5px}.conversation-list time{position:absolute;right:14px;top:13px;color:#98a5b7;font-size:9px}.conversation-list em{position:absolute;right:14px;bottom:11px;width:19px;height:19px;border-radius:50%;background:#2563eb;color:white;font-style:normal;font-size:9px;display:grid;place-items:center;line-height:1}.empty-list{border-top:1px solid #e8edf4;text-align:center;color:#98a5b7;font-size:10px;padding:24px 0;margin:0}.chat-panel{display:flex;flex-direction:column;min-height:0;overflow:hidden}.chat-head{height:86px;border-bottom:1px solid #e5ebf3;display:flex;align-items:center;gap:10px;padding:0 16px;flex:none}.chat-head-info{flex:1;min-width:0}.chat-head h2{font-size:14px;display:flex;gap:6px;align-items:center}.chat-head p{display:block;color:#7c8ca3;font-size:9px;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.message-stream{flex:1;overflow:auto;background:#f8fafc;padding:18px 18px 10px}.stream-loading{text-align:center;color:#98a5b7;font-size:10px}.message-row{display:flex;flex-direction:column;align-items:flex-start;margin-bottom:17px}.message-row.me{align-items:flex-end}.bubble{max-width:76%;padding:11px 13px;border-radius:5px 13px 13px 13px;background:#eaf1ff;font-size:11px;line-height:1.55;white-space:pre-wrap;word-break:break-word}.message-row.me .bubble{background:white;border:1px solid #dce5f0;border-radius:13px 5px 13px 13px}.bubble-link{color:#2563eb;text-decoration:underline;word-break:break-all;cursor:pointer}.file-bubble{display:flex;align-items:center;gap:7px;text-decoration:none;color:inherit;cursor:pointer}.file-bubble svg{color:#2563eb;flex:none}.file-bubble b{font-weight:500;font-size:11px;max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.file-bubble small{color:#2563eb;font-size:9px}.img-bubble{padding:4px}.img-bubble img{max-width:220px;max-height:180px;border-radius:8px;display:block}.message-row time{color:#9aa7b8;font-size:9px;margin-top:4px}.message-row.system{align-items:center;margin:5px 0 17px}.system-line{color:#95a2b4;font-size:9px;display:flex;align-items:center;width:80%;gap:8px}.system-line:before,.system-line:after{content:'';height:1px;background:#e5ebf3;flex:1}.chat-empty{flex:1;display:grid;place-items:center;color:#98a5b7;font-size:12px}.composer{min-height:86px;border-top:1px solid #e5ebf3;padding:8px 15px;position:relative;flex:none}.composer-tools{height:28px;display:flex;gap:5px;align-items:center}.composer-tools button{border:0;background:none;color:#64748b;padding:4px;cursor:pointer}.composer-tools .quick{margin-left:auto;display:flex;align-items:center;gap:5px;color:#2563eb;font-size:10px}.composer-tools .rec-btn{display:flex;align-items:center;gap:4px;color:#2563eb;font-size:10px}.composer-tools .rec-btn:hover{color:#1d4ed8}.composer>div:last-child{display:flex;gap:8px;align-items:flex-end}.composer textarea{min-height:36px;max-height:96px;flex:1;border:0;outline:0;border-radius:8px;background:#f0f4f9;padding:9px 11px;font-size:11px;resize:none;font-family:inherit;line-height:1.5}.send{height:36px;border:0;border-radius:8px;background:#2563eb;color:white;padding:0 13px;display:flex;align-items:center;gap:6px;cursor:pointer}.emoji-pop{position:absolute;left:14px;bottom:80px;background:white;border:1px solid #e0e7f0;border-radius:10px;padding:8px;display:grid;grid-template-columns:repeat(8,1fr);gap:2px;box-shadow:0 8px 24px rgba(30,41,59,.14);z-index:5}.emoji-pop button{border:0;background:none;font-size:16px;padding:4px;border-radius:6px;cursor:pointer}.emoji-pop button:hover{background:#f0f4f9}.template-panel{border-radius:0 14px 14px 0;display:flex;flex-direction:column;overflow:hidden}.template-panel header{height:60px;padding:0 14px;border-bottom:1px solid #e5ebf3;display:flex;align-items:center;justify-content:space-between}.template-panel header span{font-size:12px;font-weight:700;display:flex;align-items:center;gap:7px}.template-panel header svg{color:#2563eb}.template-panel header small{color:#9aa7b8;font-size:8px}.template-list{padding:12px;display:flex;flex-direction:column;gap:9px;overflow:auto}.template-list button{border:1px solid #e0e7f0;border-radius:8px;background:white;padding:8px 9px;text-align:left;cursor:pointer}.template-list button:hover{border-color:#8eb2fa;background:#f8fbff}.template-list label{display:block;color:#8392a7;font-size:9px;margin-bottom:4px}.template-list span{font-size:10px;line-height:1.45;color:#40516a}.ai-tip{margin:3px 12px;padding:10px;background:#edf4ff;color:#2563eb;border-radius:9px;display:flex;gap:7px}.ai-tip svg{flex:none}.ai-tip p{font-size:9px;color:#6a7d99;line-height:1.45}.ai-tip b{color:#315b9e;display:block}.manage{height:42px;border:0;border-top:1px solid #e5ebf3;background:white;color:#2563eb;margin-top:auto;display:flex;align-items:center;justify-content:center;gap:6px;font-size:10px;cursor:pointer}
.tpl-manage{display:flex;flex-direction:column;gap:12px}.tpl-form{display:flex;gap:8px}.tpl-form input{height:34px;border:1px solid #dfe6ef;border-radius:8px;padding:0 10px;font-size:12px;outline:none}.tpl-form input:focus{border-color:#2563eb}.tpl-form .cat{width:140px;flex:none}.tpl-form .cnt{flex:1;min-width:0}.tpl-form .save{height:34px;flex:none;border:0;border-radius:8px;background:#2563eb;color:white;padding:0 14px;font-size:11px;cursor:pointer}.tpl-form .cancel{height:34px;flex:none;border:1px solid #dfe6ef;border-radius:8px;background:white;color:#64748b;padding:0 12px;font-size:11px;cursor:pointer}
.tpl-rows{max-height:340px;overflow:auto;border:1px solid #eef2f7;border-radius:9px}.tpl-row{display:grid;grid-template-columns:96px 1fr 88px;gap:10px;align-items:center;padding:9px 12px;border-bottom:1px solid #f2f5f9;font-size:11px}.tpl-row:last-child{border-bottom:0}.tpl-row.on{background:#f4f8ff}.tpl-row label{color:#8392a7;font-size:10px}.tpl-row span{color:#40516a;line-height:1.45;word-break:break-word}.tpl-row .ops{display:flex;gap:8px;justify-content:flex-end}.tpl-row .ops button{border:0;background:none;color:#2563eb;font-size:10px;cursor:pointer;padding:0}.tpl-row .ops button.del{color:#ef4444}.none{padding:20px;text-align:center;color:#9aa7b9;font-size:11px}
.link-form{display:flex;flex-direction:column;gap:14px}
.lf-row{display:flex;align-items:center;gap:10px;font-size:12px;color:#40516a}
.lf-row>span{width:66px;flex:none;color:#8392a7}
.lf-row select,.lf-num{height:34px;border:1px solid #dfe6ef;border-radius:8px;padding:0 10px;font-size:12px;outline:none;background:#fff;color:#40516a}
.lf-row select{flex:1;min-width:0}
.lf-num{width:120px;flex:none}
.lf-row select:focus,.lf-num:focus{border-color:#2563eb}
.lf-row em{font-style:normal;color:#8392a7;font-size:11px}
.lf-col{align-items:flex-start}
.lf-interviewers{flex:1;min-width:0}
.lf-mode-hint{color:#8392a7;font-size:10px;margin-bottom:6px}
.lf-iv-list{max-height:150px;overflow:auto;border:1px solid #dfe6ef;border-radius:8px;padding:6px}
.lf-iv{display:flex;align-items:center;gap:8px;padding:6px 8px;border-radius:6px;cursor:pointer}
.lf-iv:hover{background:#f4f8ff}
.lf-iv.on{background:#edf4ff}
.lf-iv input{accent-color:#2563eb}
.lf-iv b{font-size:12px;color:#40516a;font-weight:500}
.lf-iv small{color:#9aa7b8;font-size:10px}
.lf-iv-empty{color:#9aa7b8;font-size:10px;padding:8px}
.lf-generate{height:38px;border:0;border-radius:9px;background:#2563eb;color:#fff;font-size:13px;font-weight:600;cursor:pointer}
.lf-generate:disabled{background:#c9d3df;cursor:not-allowed}
.lf-result{display:flex;flex-direction:column;gap:8px;padding:12px;border:1px solid #e6ebf2;border-radius:10px;background:#f8fafc}
.lf-result>label{font-size:11px;color:#8392a7}
.lf-link{height:34px;border:1px solid #dfe6ef;border-radius:8px;padding:0 10px;font-size:11px;color:#40516a;background:#fff;outline:none}
.lf-result-actions{display:flex;gap:10px}
.lf-copy,.lf-send{height:34px;display:flex;align-items:center;justify-content:center;gap:6px;border-radius:8px;font-size:12px;cursor:pointer}
.lf-copy{flex:none;padding:0 14px;border:1px solid #dfe6ef;background:#fff;color:#2563eb}
.lf-send{flex:1;border:0;background:#2563eb;color:#fff}
.notice-stream{flex:1;overflow:auto;background:#f8fafc;padding:18px;display:flex;flex-direction:column;gap:14px}
.notice-card{border:1px solid #e5ebf3;border-radius:12px;background:#fff;padding:14px 16px;display:flex;flex-direction:column;gap:8px}
.notice-card h3{font-size:14px;color:#26364d}
.nc-head{display:flex;align-items:center;gap:8px}
.nc-head time{margin-left:auto;color:#9aa7b8;font-size:10px}
.nc-badge{font-size:10px;padding:2px 8px;border-radius:10px;background:#eef2f7;color:#8392a7}
.nc-badge.st0{background:#fff4e5;color:#d97706}
.nc-badge.st1{background:#e7f7ee;color:#16a34a}
.nc-badge.st2{background:#fdecec;color:#dc2626}
.nc-primary{font-style:normal;font-size:10px;padding:2px 8px;border-radius:10px;background:#edf4ff;color:#2563eb}
.nc-line{font-size:12px;color:#5b6b82;line-height:1.5}
.nc-actions{display:flex;gap:10px;margin-top:4px}
.nc-accept,.nc-reject,.nc-enter{height:34px;border-radius:8px;font-size:12px;cursor:pointer;padding:0 16px}
.nc-accept{flex:1;border:0;background:#2563eb;color:#fff}
.nc-reject{border:1px solid #dfe6ef;background:#fff;color:#64748b;padding:0 18px}
.nc-enter{border:0;background:#16a34a;color:#fff}
.nc-rejected{font-size:12px;color:#9aa7b8}
</style>
