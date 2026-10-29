<template>
  <AgentTopbar active="messages" />
  <main class="message-shell" :class="{ 'system-mode': activeView === 'system' }">
    <aside class="conversation-sidebar">
      <div class="sidebar-head">
        <div class="sidebar-title">消息 <span>共 {{ sessions.length }} 个会话</span></div>
        <label class="conversation-search">
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="m16 16 4 4" /></svg>
          <input v-model="searchQuery" type="search" placeholder="搜索会话" aria-label="搜索会话" />
        </label>
      </div>

      <div class="conversation-list">
        <div v-if="sessionsLoading" class="conversation-state">正在读取会话...</div>
        <div v-else-if="sessionsError" class="conversation-state error">
          <span>会话暂时无法读取</span>
          <button type="button" @click="loadSessions">重新加载</button>
        </div>
        <template v-else>
          <button
            v-if="showSystemConversation"
            class="conversation-item is-pinned"
            :class="{ active: activeView === 'system' }"
            type="button"
            @click="selectSystem"
          >
            <span class="conversation-avatar system">
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" /></svg>
            </span>
            <span class="conversation-copy">
              <span class="conversation-name">系统通知</span>
              <span class="conversation-preview">{{ systemPreview }}</span>
            </span>
            <span class="conversation-meta">
              <span class="conversation-time">{{ formatShortTime(noticeItems[0]?.createTime) }}</span>
              <span v-if="systemUnreadCount" class="unread">{{ systemUnreadCount }}</span>
            </span>
          </button>

          <button
            v-for="session in filteredSessions"
            :key="session.sessionId"
            class="conversation-item"
            :class="{ active: activeView === 'chat' && selectedSessionId === session.sessionId }"
            type="button"
            @click="selectSession(session)"
          >
            <span class="conversation-avatar">{{ avatarText(session.peerName) }}</span>
            <span class="conversation-copy">
              <span class="conversation-name">{{ session.peerName || '联系人' }}</span>
              <span class="conversation-preview">{{ session.lastMessage || '暂无消息内容' }}</span>
            </span>
            <span class="conversation-meta">
              <span class="conversation-time">{{ formatShortTime(session.lastMessageAt) }}</span>
              <span v-if="session.unread" class="unread">{{ session.unread }}</span>
            </span>
          </button>

          <div v-if="!filteredSessions.length && !showSystemConversation" class="conversation-state">
            暂无消息会话
          </div>
        </template>
      </div>
    </aside>

    <section class="content-area">
      <div v-if="activeView === 'chat'" class="chat-view">
        <template v-if="activeConversation">
          <header class="chat-head">
            <div class="chat-person">
              <span class="mini-avatar">{{ avatarText(activeConversation.peerName) }}</span>
              <div class="notice-copy">
                <div class="chat-name">{{ activeConversation.peerName || '联系人' }} <span class="hr-tag">站内联系人</span></div>
                <div class="online-text">消息会话</div>
              </div>
            </div>
          </header>

          <div ref="messagesContainer" class="messages" @scroll="updateMessageScroll">
            <div v-if="messagesLoading" class="notification-state">正在读取聊天记录...</div>
            <div v-else-if="messagesError" class="notification-state error">
              <span>聊天记录暂时无法读取</span>
               <button class="notification-retry" type="button" @click="selectedSessionId && loadMessages(selectedSessionId)">重新加载</button>
            </div>
            <template v-else-if="messages.length">
              <div class="time-divider">聊天记录</div>
              <div v-for="message in messages" :key="message.messageId" class="message-row" :class="{ me: message.isMine }">
                 <span v-if="!message.isMine" class="bubble-avatar">{{ avatarText(activeConversation.peerName) }}</span>
                  <div class="bubble-wrap">
                   <div class="bubble">
                     <template v-if="isImageMessage(message)">
                       <template v-if="!message.attachmentUnavailable">
                         <button class="attachment-image-button" type="button" :aria-label="`查看图片 ${message.content || ''}`" @click="previewAttachment(message)">
                           <img class="attachment-image" :src="message.attachmentUrl" :alt="message.content || '聊天图片'" @load="handleMessageImageLoad" @error="markAttachmentUnavailable(message)" />
                         </button>
                         <button class="attachment-name" type="button" @click="previewAttachment(message)">{{ message.content || '查看图片' }}</button>
                       </template>
                       <div v-else class="attachment-unavailable">图片暂时无法加载 <button type="button" @click="message.attachmentUnavailable = false">重新加载</button></div>
                     </template>
                     <button v-else-if="message.type === 3 && message.attachmentUrl" class="attachment-file" type="button" @click="openAttachment(message)">
                       <span class="attachment-file-icon" aria-hidden="true">↧</span>
                       <span class="attachment-file-copy"><strong>{{ message.content || '文件附件' }}</strong><small>点击打开或下载</small></span>
                     </button>
                     <span v-else class="message-text"><template v-for="(part, index) in message.linkParts" :key="index"><a v-if="part.href" class="message-link" :href="part.href" target="_blank" rel="noopener noreferrer">{{ part.text }}</a><template v-else>{{ part.text }}</template></template></span>
                   </div>
                   <div class="bubble-time">{{ formatMessageTime(message.sendTime) }}</div>
                 </div>
              </div>
            </template>
             <div v-else class="notification-state">{{ newConversation ? '输入消息，开始联系该企业 HR' : '暂无聊天记录' }}</div>
          </div>

          <form class="composer" @submit.prevent="sendMessage">
            <input ref="imageInput" class="attachment-input" type="file" accept="image/jpeg,image/png,image/gif,image/bmp" @change="handleAttachmentChange($event, true)" />
            <input ref="fileInput" class="attachment-input" type="file" accept=".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.zip" @change="handleAttachmentChange($event, false)" />
            <div class="composer-tools">
              <div class="composer-tool-list">
                <div ref="emojiPicker" class="message-emoji-picker" @keydown.esc.stop="emojiOpen = false">
                  <button class="composer-tool" type="button" :disabled="sending" title="发送表情" aria-controls="message-emoji-panel" :aria-expanded="emojiOpen" @click="emojiOpen = !emojiOpen">
                    <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M8 14s1 3 4 3 4-3 4-3M8 8v2M16 8v2"/></svg>
                    <span>表情</span>
                  </button>
                  <div v-if="emojiOpen" id="message-emoji-panel" class="message-emoji-panel" role="group" aria-label="选择表情">
                    <button v-for="emoji in messageEmojis" :key="emoji.value" type="button" :title="emoji.label" :aria-label="emoji.label" :disabled="sending" @click="addEmoji(emoji.value)">{{ emoji.value }}</button>
                  </div>
                </div>
                <button class="composer-tool" type="button" :disabled="sending" title="发送图片" @click="imageInput?.click()">
                  <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8" cy="9" r="1.5"/><path d="m4 17 5-5 3 3 2-2 6 6"/></svg>
                  <span>图片</span>
                </button>
                <button class="composer-tool" type="button" :disabled="sending" title="发送文件" @click="fileInput?.click()">
                  <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m14 3 5 5v12a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z"/><path d="M14 3v5h5M8 13h8M8 17h6"/></svg>
                  <span>附件</span>
                </button>
              </div>
              <span class="composer-hint">支持图片、PDF、Office、TXT、ZIP，单个不超过 10MB</span>
            </div>
            <div class="composer-main">
              <div class="composer-box">
                <input
                  ref="messageInput"
                  v-model="draftMessage"
                  type="text"
                  :disabled="sending"
                  maxlength="1000"
                  placeholder="输入消息，Enter 发送…"
                  aria-label="消息内容"
                  autocomplete="off"
                />
              </div>
              <button class="send-button" type="submit" :disabled="sending || !draftMessage.trim()">
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m21 3-8.2 18-2.4-7.4L3 11.2Z" /><path d="M10.4 13.6 21 3" /></svg>
                {{ sending ? '发送中' : '发送' }}
              </button>
            </div>
          </form>
        </template>
        <div v-else class="empty-chat">
          <strong>暂无可用会话</strong>
          <span>当数据库中产生消息会话后，会显示在这里</span>
        </div>
      </div>

      <div v-else class="system-view">
        <header class="system-head">
          <h1>系统通知</h1>
          <button type="button" :disabled="!systemUnreadCount" @click="markAllNoticesRead">全部标为已读</button>
        </header>
        <div class="notification-list">
          <div v-if="noticesLoading" class="notification-state">正在读取系统通知...</div>
          <div v-else-if="noticesError" class="notification-state error">
            <span>系统通知暂时无法读取</span>
            <button class="notification-retry" type="button" @click="loadNotices">重新加载</button>
          </div>
          <template v-else-if="noticeItems.length">
            <article
              v-for="item in noticeItems"
              :id="`notice-${item.noticeId}`"
              :key="item.noticeId"
              class="notification-card"
              :class="{ 'unread-notice': !item.isRead }"
              role="button"
              tabindex="0"
              @click="openNotice(item)"
              @keydown.enter="openNotice(item)"
              @keydown.space.prevent="openNotice(item)"
            >
              <span class="notice-dot"></span>
              <div>
                <div class="notice-title">{{ item.noticeTitle || '系统通知' }}</div>
                <div class="notice-desc">{{ plainText(item.noticeContent) || item.noticeTitle || '暂无通知内容' }}</div>
              </div>
              <span class="notice-tag" :class="{ gray: item.noticeType !== '1' }">{{ item.noticeType === '1' ? '通知' : '公告' }}</span>
              <span class="notice-time">{{ formatShortTime(item.createTime) }}　›</span>
            </article>
          </template>
          <div v-else class="notification-state">暂无系统通知</div>
        </div>
      </div>
    </section>

    <aside v-if="activeView === 'chat' && activeConversation" class="detail-sidebar">
      <div class="detail-head">会话详情</div>
      <div class="person-panel">
        <div class="person-card">
          <span class="mini-avatar">{{ avatarText(activeConversation.peerName) }}</span>
          <div>
            <strong>{{ activeConversation.peerName || '联系人' }}</strong>
            <span>消息会话联系人</span>
          </div>
        </div>
        <div class="person-info">
          <div>会话编号：{{ activeConversation.sessionId || '发送首条消息后创建' }}</div>
          <div>最近消息：{{ activeConversation.lastMessage || '暂无消息内容' }}</div>
          <div>更新时间：{{ formatMessageTime(activeConversation.lastMessageAt) }}</div>
        </div>
      </div>
    </aside>
  </main>

  <div v-if="activeNotice" class="call-modal" role="presentation" @click.self="activeNotice = null">
    <div class="call-dialog" role="dialog" aria-modal="true" aria-labelledby="noticeDetailTitle">
      <div class="call-avatar">!</div>
      <h2 id="noticeDetailTitle">{{ activeNotice.noticeTitle || '系统通知' }}</h2>
      <p>{{ plainText(activeNotice.noticeContent) || '暂无通知内容' }}</p>
      <div class="call-actions">
        <button class="call-cancel" type="button" @click="activeNotice = null">关闭</button>
      </div>
    </div>
  </div>

  <section v-if="aiOpen" class="ai-assistant-panel" aria-label="AI 智能助手">
    <header class="ai-assistant-head">
      <div class="ai-assistant-brand">
        <span class="ai-assistant-icon">AI</span>
        <div>
          <strong>AI 智能助手</strong>
          <span>{{ aiSending ? (aiStatus || '正在回答') : '基于真实账户数据回答' }}</span>
        </div>
      </div>
      <div class="ai-assistant-actions">
        <button type="button" title="新建会话" aria-label="新建会话" @click="newAiSession">＋</button>
        <button type="button" title="关闭助手" aria-label="关闭助手" @click="aiOpen = false">×</button>
      </div>
    </header>
    <div v-if="aiSessions.length" class="ai-session-switcher">
      <label for="ai-session-select">会话</label>
      <select id="ai-session-select" :value="aiSessionId || ''" :disabled="aiSending" @change="changeAiSession">
        <option value="">新建会话</option>
        <option v-for="session in aiSessions" :key="session.id" :value="session.id">{{ session.title || '新对话' }}</option>
      </select>
    </div>
    <div ref="aiMessagesContainer" class="ai-assistant-messages">
      <div v-if="aiLoading" class="ai-assistant-state">正在读取 AI 会话...</div>
      <div v-else-if="aiError && !aiMessages.length" class="ai-assistant-state ai-error">
        <span>{{ aiError }}</span>
        <button type="button" @click="loadAiAssistant(true)">重新加载</button>
      </div>
      <template v-else-if="aiMessages.length">
        <div v-for="(message, index) in aiMessages" :key="`${message.runId || 'local'}-${index}`" class="ai-message" :class="message.role === 'user' ? 'is-user' : 'is-assistant'">
          <span class="ai-message-avatar">{{ message.role === 'user' ? '我' : 'AI' }}</span>
          <div class="ai-message-bubble">{{ message.content || (aiSending && index === aiMessages.length - 1 ? '正在生成回答…' : '暂无回答内容') }}</div>
        </div>
      </template>
      <div v-else class="ai-assistant-welcome">
        <strong>你好，我是求职 AI 助手</strong>
        <span>可以帮你分析简历、查询投递进度、推荐岗位或解答求职问题。</span>
      </div>
    </div>
    <p v-if="aiError && aiMessages.length" class="ai-assistant-error">{{ aiError }}</p>
    <form class="ai-assistant-composer" @submit.prevent="sendAiMessage">
      <input v-model="aiDraft" maxlength="4000" :disabled="aiSending || aiLoading" placeholder="输入你的求职问题" aria-label="输入 AI 问题" />
      <button v-if="aiSending" type="button" title="停止生成" aria-label="停止生成" @click="stopAiMessage">■</button>
      <button v-else type="submit" title="发送问题" aria-label="发送问题" :disabled="aiLoading || !aiDraft.trim()">↑</button>
    </form>
  </section>
  <button class="ai-assistant-fab" type="button" :aria-expanded="aiOpen" aria-label="打开 AI 智能助手" @click="toggleAiAssistant">
    <span>AI</span>
  </button>
  <div class="toast" :class="{ show: toastVisible }" role="status" aria-live="polite">{{ toastText }}</div>
  <Teleport to="body">
    <div v-if="previewImage" class="message-image-preview" role="dialog" aria-modal="true" aria-label="聊天图片预览" @click.self="closeImagePreview" @keydown.esc="closeImagePreview" @keydown.tab.prevent="previewCloseButton?.focus()">
      <button ref="previewCloseButton" class="message-image-preview-close" type="button" aria-label="关闭图片预览" @click="closeImagePreview">×</button>
      <img :src="previewImage.attachmentUrl" :alt="previewImage.content || '聊天图片'" />
    </div>
  </Teleport>
</template>

<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { getNotice, listNoticeTop, markNoticeRead, markNoticeReadAll } from '@/api/system/notice'
import { listImMessages, listImSessions, markImSessionRead, sendImMessage, uploadImAttachment } from '@/api/system/im'
import { cancelAiRun, createAiSession, listAiMessages, listAiSessions, startAiRun, streamAiRun } from '@/api/agent/ai'
import { getToken } from '@/utils/auth'
import { insertMessageEmoji, isImageMessage, messageAttachmentError, messageAttachmentPath, messageLinkParts, resolveMessageAttachment, uploadedMessageAttachmentPath } from '@/utils/agentMessage'

const sessions = ref([])
const selectedSessionId = ref(null)
const activeView = ref('system')
const searchQuery = ref('')
const sessionsLoading = ref(true)
const sessionsError = ref(false)
const messages = ref([])
const messagesLoading = ref(false)
const messagesError = ref(false)
const newConversation = ref(null)
const draftMessage = ref('')
const sending = ref(false)
const imageInput = ref(null)
const fileInput = ref(null)
const messageInput = ref(null)
const emojiPicker = ref(null)
const emojiOpen = ref(false)
const previewImage = ref(null)
const previewCloseButton = ref(null)
const messageEmojis = [
  { value: '😀', label: '开心' }, { value: '😊', label: '微笑' },
  { value: '😂', label: '笑哭' }, { value: '😄', label: '大笑' },
  { value: '😉', label: '眨眼' }, { value: '🤔', label: '思考' },
  { value: '😅', label: '不好意思' }, { value: '🥳', label: '庆祝' },
  { value: '👍', label: '赞' }, { value: '👌', label: '好的' },
  { value: '🙏', label: '感谢' }, { value: '🤝', label: '握手' },
  { value: '👏', label: '鼓掌' }, { value: '💪', label: '加油' },
  { value: '👋', label: '你好' }, { value: '❤️', label: '爱心' },
  { value: '🎉', label: '祝贺' }, { value: '🌹', label: '鲜花' },
  { value: '✅', label: '确认' }, { value: '💼', label: '工作' },
  { value: '📄', label: '简历' }, { value: '📅', label: '日程' },
  { value: '☕', label: '咖啡' }, { value: '🚀', label: '出发' }
]
let previewReturnTarget = null
const noticeItems = ref([])
const noticesLoading = ref(true)
const noticesError = ref(false)
const activeNotice = ref(null)
const messagesContainer = ref(null)
const followLatestMessages = ref(true)
const toastText = ref('')
const toastVisible = ref(false)
const aiOpen = ref(false)
const aiInitialized = ref(false)
const aiSessions = ref([])
const aiSessionId = ref(null)
const aiMessages = ref([])
const aiDraft = ref('')
const aiLoading = ref(false)
const aiSending = ref(false)
const aiStatus = ref('')
const aiError = ref('')
const aiRunId = ref(null)
const aiMessagesContainer = ref(null)
let aiAbortController = null
let toastTimer
let refreshTimer
let refreshInFlight = false

const selectedSession = computed(() => sessions.value.find(item => item.sessionId === selectedSessionId.value) || null)
const activeConversation = computed(() => selectedSession.value || newConversation.value)
const filteredSessions = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()
  if (!query) return sessions.value
  return sessions.value.filter(item => `${item.peerName || ''} ${item.lastMessage || ''}`.toLowerCase().includes(query))
})
const systemUnreadCount = computed(() => noticeItems.value.filter(item => !item.isRead).length)
const systemPreview = computed(() => systemUnreadCount.value ? `你有 ${systemUnreadCount.value} 条新的系统通知` : '暂无未读系统通知')
const showSystemConversation = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()
  return !query || '系统通知'.includes(query) || systemPreview.value.includes(query)
})

function avatarText(value) {
  const text = String(value || '联系人').trim()
  return text.slice(0, 1).toUpperCase()
}

function parseDate(value) {
  if (!value) return null
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? null : date
}

function formatShortTime(value) {
  const date = parseDate(value)
  if (!date) return '--'
  const now = new Date()
  if (date.toDateString() === now.toDateString()) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false })
  }
  return `${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

function formatMessageTime(value) {
  const date = parseDate(value)
  return date ? date.toLocaleString([], { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false }) : '--'
}

function plainText(value) {
  if (!value) return ''
  const holder = document.createElement('div')
  holder.innerHTML = value
  return (holder.textContent || holder.innerText || '').replace(/\s+/g, ' ').trim()
}

function showToast(text) {
  toastText.value = text
  toastVisible.value = true
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { toastVisible.value = false }, 2200)
}

async function loadSessions() {
  sessionsLoading.value = true
  sessionsError.value = false
  try {
    const response = await listImSessions()
    sessions.value = Array.isArray(response.data) ? response.data : []
    const params = new URLSearchParams(location.search)
    const requestedId = Number(params.get('conversation'))
    const requestedPeerId = Number(params.get('peerId'))
    const requestedSession = sessions.value.find(item => item.sessionId === requestedId)
    const requestedPeer = sessions.value.find(item => String(item.peerId) === String(requestedPeerId))
    if (requestedSession) {
      await selectSession(requestedSession, false)
    } else if (requestedPeerId > 0) {
      if (requestedPeer) {
        await selectSession(requestedPeer, false)
      } else {
        startNewConversation(requestedPeerId, params.get('peerName') || '企业 HR', false)
      }
    } else if (params.get('view') === 'system' || !sessions.value.length) {
      selectSystem(false)
    } else {
      await selectSession(sessions.value[0], false)
    }
  } catch (error) {
    sessionsError.value = true
    showToast(error?.message || '会话加载失败')
  } finally {
    sessionsLoading.value = false
  }
}

function startNewConversation(peerId, peerName = '企业 HR', updateUrl = true) {
  activeView.value = 'chat'
  selectedSessionId.value = null
  newConversation.value = { peerId, peerName }
  messages.value = []
  messagesError.value = false
  if (updateUrl) {
    history.replaceState(null, '', `/agent/messages?peerId=${encodeURIComponent(peerId)}&peerName=${encodeURIComponent(peerName)}`)
  }
}

async function loadMessages(sessionId, { silent = false } = {}) {
  if (!sessionId) return
  const shouldFollowLatest = !silent || followLatestMessages.value
  if (!silent) followLatestMessages.value = true
  if (!silent && !messages.value.length) messagesLoading.value = true
  messagesError.value = false
  try {
    const response = await listImMessages(sessionId)
    if (selectedSessionId.value !== sessionId) return
    const previousMessages = new Map(messages.value.map(message => [message.messageId, message]))
    messages.value = Array.isArray(response.data)
      ? response.data.map(message => {
        const url = attachmentUrl(message.attachmentUrl)
        const previous = previousMessages.get(message.messageId)
        return {
          ...message,
          type: Number(message.type),
          attachmentUrl: url,
          attachmentUnavailable: previous?.attachmentUrl === url && previous.attachmentUnavailable,
          linkParts: messageLinkParts(message.content || '[非文本消息]')
        }
      })
      : []
  } catch (error) {
    if (!silent) {
      messagesError.value = true
      showToast(error?.message || '聊天记录加载失败')
    }
  } finally {
    if (!silent) messagesLoading.value = false
    await nextTick()
    if (selectedSessionId.value === sessionId && shouldFollowLatest && messagesContainer.value) {
      followLatestMessages.value = true
      messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
    }
  }
}

function updateMessageScroll() {
  const container = messagesContainer.value
  if (container) followLatestMessages.value = container.scrollHeight - container.scrollTop - container.clientHeight < 64
}

function handleMessageImageLoad() {
  if (followLatestMessages.value && messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
  }
}

async function selectSession(session, updateUrl = true) {
  emojiOpen.value = false
  previewImage.value = null
  activeView.value = 'chat'
  selectedSessionId.value = session.sessionId
  newConversation.value = null
  messages.value = []
  if (updateUrl) history.replaceState(null, '', `/agent/messages?conversation=${encodeURIComponent(session.sessionId)}`)
  await Promise.all([
    loadMessages(session.sessionId),
    markImSessionRead(session.sessionId).catch(() => {})
  ])
  session.unread = 0
}

function selectSystem(updateUrl = true) {
  emojiOpen.value = false
  previewImage.value = null
  activeView.value = 'system'
  selectedSessionId.value = null
  newConversation.value = null
  if (updateUrl) history.replaceState(null, '', '/agent/messages?view=system')
}

async function sendMessage() {
  const content = draftMessage.value.trim()
  if (!content || !activeConversation.value || sending.value) return
  sending.value = true
  try {
    const body = { type: 1, content }
    if (selectedSession.value) body.sessionId = selectedSession.value.sessionId
    else body.peerId = newConversation.value.peerId
    const response = await sendImMessage(body)
    draftMessage.value = ''
    emojiOpen.value = false
    const sessionsResponse = await listImSessions()
    sessions.value = Array.isArray(sessionsResponse.data) ? sessionsResponse.data : []
    if (!selectedSession.value) {
      const createdSessionId = Number(response?.sessionId ?? response?.data?.sessionId)
      const createdSession = sessions.value.find(item => item.sessionId === createdSessionId || String(item.peerId) === String(newConversation.value.peerId))
      if (createdSession) await selectSession(createdSession, false)
    } else {
      await loadMessages(selectedSession.value.sessionId)
    }
    showToast('消息已发送')
  } catch (error) {
    showToast(error?.message || '消息发送失败')
  } finally {
    sending.value = false
  }
}

function attachmentUrl(value) {
  return resolveMessageAttachment(value, import.meta.env.VITE_APP_BASE_API, window.location.origin)
}

async function addEmoji(emoji) {
  if (sending.value) return
  const input = messageInput.value
  const next = insertMessageEmoji(draftMessage.value, emoji, input?.selectionStart ?? draftMessage.value.length, input?.selectionEnd ?? draftMessage.value.length)
  if (!next) {
    showToast('消息不能超过 1000 个字符')
    return
  }
  draftMessage.value = next.text
  emojiOpen.value = false
  await nextTick()
  input?.focus()
  input?.setSelectionRange(next.cursor, next.cursor)
}

function closeEmojiPicker(event) {
  if (!emojiPicker.value?.contains(event.target)) emojiOpen.value = false
}

function markAttachmentUnavailable(message) {
  message.attachmentUnavailable = true
}

async function previewAttachment(message) {
  previewReturnTarget = document.activeElement
  previewImage.value = message
  await nextTick()
  previewCloseButton.value?.focus()
}

function closeImagePreview() {
  previewImage.value = null
  previewReturnTarget?.focus()
  previewReturnTarget = null
}

async function openAttachment(message) {
  const url = attachmentUrl(message.attachmentUrl)
  if (!url || message.attachmentUnavailable) {
    showToast('附件已失效，请重新上传')
    return
  }
  try {
    const parsedUrl = new URL(url, window.location.origin)
    if (parsedUrl.origin !== window.location.origin) {
      window.open(url, '_blank', 'noopener,noreferrer')
      return
    }
    const token = getToken()
    const headers = token && messageAttachmentPath(url) ? { Authorization: `Bearer ${token}` } : {}
    const response = await fetch(url, { credentials: 'include', headers })
    const blob = await response.blob()
    const contentType = response.headers.get('content-type') || ''
    if (!response.ok || /(?:application\/json|text\/html)/i.test(contentType)) {
      let payload
      try {
        payload = JSON.parse(await blob.text())
      } catch (_) {}
      throw new Error(messageAttachmentError(response.status, payload))
    }
    const objectUrl = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = objectUrl
    link.target = '_blank'
    if (message.type === 3) link.download = message.content || '聊天附件'
    document.body.appendChild(link)
    link.click()
    link.remove()
    window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60000)
  } catch (error) {
    showToast(error?.message || '附件打开失败，请稍后重试')
  }
}

function resetAttachmentInput(event) {
  if (event?.target) event.target.value = ''
}

function isAllowedAttachment(file, isImage) {
  const extension = String(file.name || '').split('.').pop().toLowerCase()
  const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp']
  const fileExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip']
  return (isImage ? imageExtensions : fileExtensions).includes(extension)
}

async function handleAttachmentChange(event, isImage) {
  const file = event?.target?.files?.[0]
  resetAttachmentInput(event)
  if (!file || sending.value || !activeConversation.value) return
  const maxSize = 10 * 1024 * 1024
  if (file.size <= 0 || file.size > maxSize) {
    showToast('附件不能为空且不能超过 10MB')
    return
  }
  if (!isAllowedAttachment(file, isImage) || (isImage && file.type && !file.type.startsWith('image/'))) {
    showToast(isImage ? '请选择 JPG、PNG、GIF 或 BMP 图片' : '请选择 PDF、Office、TXT 或 ZIP 文件')
    return
  }
  sending.value = true
  try {
    const uploadResponse = await uploadImAttachment(file)
    const url = uploadedMessageAttachmentPath(uploadResponse)
    if (!url) throw new Error('上传接口未返回可用的附件路径，消息未发送，请联系管理员检查上传接口')
    const body = {
      type: isImage ? 2 : 3,
      content: file.name,
      attachmentUrl: url
    }
    if (selectedSession.value) body.sessionId = selectedSession.value.sessionId
    else body.peerId = newConversation.value.peerId
    const response = await sendImMessage(body)
    const sessionsResponse = await listImSessions()
    sessions.value = Array.isArray(sessionsResponse.data) ? sessionsResponse.data : []
    if (!selectedSession.value) {
      const createdSessionId = Number(response?.sessionId ?? response?.data?.sessionId)
      const createdSession = sessions.value.find(item => item.sessionId === createdSessionId || String(item.peerId) === String(newConversation.value.peerId))
      if (createdSession) await selectSession(createdSession, false)
    } else {
      await loadMessages(selectedSession.value.sessionId)
    }
    showToast(isImage ? '图片已发送' : '文件已发送')
  } catch (error) {
    showToast(error?.message || '附件发送失败')
  } finally {
    sending.value = false
  }
}

async function loadNotices({ silent = false } = {}) {
  if (!silent) noticesLoading.value = true
  noticesError.value = false
  try {
    const response = await listNoticeTop({ limit: 50 })
    noticeItems.value = Array.isArray(response.data) ? response.data : []
  } catch (error) {
    if (!silent) {
      noticesError.value = true
      showToast(error?.message || '系统通知加载失败')
    }
  } finally {
    if (!silent) noticesLoading.value = false
  }
}

async function openNotice(item) {
  if (!item.isRead) {
    try {
      await markNoticeRead(item.noticeId)
      item.isRead = true
      window.dispatchEvent(new CustomEvent('agent-notifications-updated'))
    } catch (error) {
      showToast(error?.message || '通知已读状态更新失败')
      return
    }
  }
  try {
    const response = await getNotice(item.noticeId)
    activeNotice.value = { ...item, ...(response.data || {}) }
  } catch {
    activeNotice.value = item
  }
}

async function markAllNoticesRead() {
  const ids = noticeItems.value.filter(item => !item.isRead).map(item => item.noticeId)
  if (!ids.length) return
  try {
    await markNoticeReadAll(ids.join(','))
    noticeItems.value.forEach(item => { item.isRead = true })
    window.dispatchEvent(new CustomEvent('agent-notifications-updated'))
    showToast('已将全部系统通知标记为已读')
  } catch (error) {
    showToast(error?.message || '全部已读操作失败')
  }
}

async function refreshMessages() {
  if (refreshInFlight) return
  refreshInFlight = true
  try {
    const response = await listImSessions()
    sessions.value = Array.isArray(response.data) ? response.data : []
    if (activeView.value === 'chat' && selectedSessionId.value) {
      const current = sessions.value.find(item => item.sessionId === selectedSessionId.value)
      const shouldMarkRead = Boolean(current?.unread)
      if (current) current.unread = 0
      await loadMessages(selectedSessionId.value, { silent: true })
      if (shouldMarkRead) await markImSessionRead(selectedSessionId.value)
    } else if (activeView.value !== 'chat') {
      await loadNotices({ silent: true })
    }
  } catch {
    // Background refresh must not interrupt the current conversation.
  } finally {
    refreshInFlight = false
  }
}

function scrollAiMessages() {
  nextTick(() => {
    if (aiMessagesContainer.value) aiMessagesContainer.value.scrollTop = aiMessagesContainer.value.scrollHeight
  })
}

async function loadAiMessages(sessionId, resume = true) {
  if (!sessionId) {
    aiMessages.value = []
    return
  }
  const response = await listAiMessages(sessionId)
  const data = response.data || {}
  aiMessages.value = Array.isArray(data.items) ? data.items.map(item => ({
    role: item.role,
    content: item.content || '',
    runId: item.runId,
    runStatus: item.runStatus
  })) : []
  scrollAiMessages()
  if (resume && data.activeRunId && !aiSending.value) await consumeAiRun(data.activeRunId)
}

async function loadAiAssistant(force = false) {
  if (aiLoading.value || (aiInitialized.value && !force)) return
  aiLoading.value = true
  aiError.value = ''
  try {
    const response = await listAiSessions()
    const data = response.data || {}
    aiSessions.value = Array.isArray(data.items) ? data.items : []
    if (!aiSessionId.value || !aiSessions.value.some(item => item.id === aiSessionId.value)) {
      aiSessionId.value = aiSessions.value[0]?.id || null
    }
    await loadAiMessages(aiSessionId.value)
    aiInitialized.value = true
  } catch (error) {
    aiError.value = error?.message || 'AI 会话加载失败'
  } finally {
    aiLoading.value = false
  }
}

function toggleAiAssistant() {
  aiOpen.value = !aiOpen.value
  if (aiOpen.value) loadAiAssistant()
}

function newAiSession() {
  if (aiSending.value) return
  aiSessionId.value = null
  aiMessages.value = []
  aiDraft.value = ''
  aiError.value = ''
  aiStatus.value = ''
  scrollAiMessages()
}

async function changeAiSession(event) {
  if (aiSending.value) return
  aiSessionId.value = event.target.value || null
  aiError.value = ''
  try {
    await loadAiMessages(aiSessionId.value)
  } catch (error) {
    aiError.value = error?.message || 'AI 对话加载失败'
  }
}

function newAiRequestId() {
  if (window.crypto?.randomUUID) return window.crypto.randomUUID()
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`
}

async function consumeAiRun(runId) {
  aiRunId.value = runId
  aiSending.value = true
  aiError.value = ''
  aiStatus.value = '正在准备回答'
  aiAbortController = new AbortController()
  if (!aiMessages.value.length || aiMessages.value.at(-1)?.role !== 'assistant') {
    aiMessages.value.push({ role: 'assistant', content: '', runId })
  }
  const assistant = aiMessages.value.at(-1)
  try {
    await streamAiRun(runId, 0, event => {
      if (event.type === 'status') aiStatus.value = event.data?.text || '正在处理'
      if (event.type === 'delta' && assistant) assistant.content += event.data?.text || ''
      if (event.type === 'done') aiStatus.value = event.data?.status === 'COMPLETED' ? '' : '回答未完成'
      scrollAiMessages()
    }, aiAbortController.signal)
  } catch (error) {
    if (error?.name !== 'AbortError') aiError.value = error?.message || 'AI 实时回答连接失败'
  } finally {
    aiAbortController = null
    if (aiRunId.value === runId) {
      aiRunId.value = null
      aiSending.value = false
      aiStatus.value = ''
      if (aiSessionId.value) {
        try {
          await loadAiMessages(aiSessionId.value, false)
        } catch (error) {
          if (!aiError.value) aiError.value = error?.message || 'AI 回答刷新失败'
        }
      }
    }
  }
}

async function sendAiMessage() {
  const content = aiDraft.value.trim()
  if (!content || aiLoading.value || aiSending.value) return
  aiError.value = ''
  try {
    if (!aiSessionId.value) {
      const created = await createAiSession()
      aiSessionId.value = created.data?.id || null
      if (!aiSessionId.value) throw new Error('AI 会话创建失败')
      aiSessions.value = [{ ...created.data, title: created.data.title || '新对话' }, ...aiSessions.value]
    }
    aiMessages.value.push({ role: 'user', content })
    aiMessages.value.push({ role: 'assistant', content: '' })
    aiDraft.value = ''
    scrollAiMessages()
    const response = await startAiRun(aiSessionId.value, {
      content,
      requestId: newAiRequestId(),
      action: 'chat'
    })
    const runId = response.data?.id
    if (!runId) throw new Error('AI 任务创建失败')
    await consumeAiRun(runId)
    const refreshed = await listAiSessions()
    aiSessions.value = Array.isArray(refreshed.data?.items) ? refreshed.data.items : aiSessions.value
  } catch (error) {
    if (aiMessages.value.at(-1)?.role === 'assistant' && !aiMessages.value.at(-1).content) aiMessages.value.pop()
    aiError.value = error?.message || 'AI 消息发送失败'
  }
}

async function stopAiMessage() {
  const runId = aiRunId.value
  if (!runId) return
  aiAbortController?.abort()
  try {
    await cancelAiRun(runId)
  } catch (error) {
    aiError.value = error?.message || '停止 AI 回答失败'
  }
}

onMounted(() => {
  document.addEventListener('pointerdown', closeEmojiPicker)
  loadNotices()
  loadSessions()
  refreshTimer = window.setInterval(refreshMessages, 5000)
})

onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', closeEmojiPicker)
  if (refreshTimer) window.clearInterval(refreshTimer)
  aiAbortController?.abort()
  clearTimeout(toastTimer)
})
</script>

<style>
.message-shell .message-text{white-space:pre-wrap;overflow-wrap:anywhere}
.message-shell .bubble .attachment-image-button{max-width:100%}
.message-shell .attachment-image,.message-shell .attachment-name{max-width:100%}
.message-shell .attachment-file{min-width:0;max-width:100%;width:220px}
.message-shell .message-link{color:#1761bd;text-decoration:underline;text-underline-offset:3px;overflow-wrap:anywhere}
.message-shell .message-link:hover{color:#0d438a}
.message-shell .me .message-link,.message-shell .me .message-link:hover{color:#fff}
.message-shell .message-emoji-picker{position:relative;flex:0 0 auto}
.message-shell .message-emoji-panel{position:absolute;bottom:calc(100% + 8px);left:0;z-index:10;display:grid;grid-template-columns:repeat(6,32px);gap:4px;padding:10px;border:1px solid #d8e3ef;border-radius:10px;background:#fff;box-shadow:0 6px 24px rgba(26,60,110,.16)}
.message-shell .message-emoji-panel button{display:grid;width:32px;height:32px;place-items:center;padding:0;border:0;border-radius:6px;background:transparent;font-family:'Segoe UI Emoji','Apple Color Emoji',sans-serif;font-size:22px;line-height:1}
.message-shell .message-emoji-panel button:hover,.message-shell .message-emoji-panel button:focus-visible{background:#eaf2ff;outline:2px solid #afc9ec}
.message-shell .attachment-unavailable button{padding:2px 5px;border:0;color:#1761bd;background:transparent;text-decoration:underline}
.message-image-preview{position:fixed;inset:0;z-index:3000;display:flex;align-items:center;justify-content:center;padding:56px 20px;background:rgba(13,23,39,.85)}
.message-image-preview img{display:block;max-width:100%;max-height:100%;object-fit:contain}
.message-image-preview-close{position:absolute;top:12px;right:16px;display:grid;width:36px;height:36px;place-items:center;padding:0;border:1px solid #fff;border-radius:50%;color:#fff;background:#263445;font-size:25px;cursor:pointer}
.message-shell{--primary:#1A3C6E;--blue:#2B7FFF;--blue-soft:#EAF2FF;--bg:#F5F7FA;--text:#172B4D;--muted:#6B7A90;--light:#96A3B5;--line:#E6EBF2;--red:#D94B55;--shadow:0 5px 18px rgba(26,60,110,.045)}
.attachment-input{display:none}.attachment-actions{display:flex;align-items:center;gap:6px}.attachment-button{height:34px;padding:0 9px;border:1px solid #D8E3EF;border-radius:7px;color:var(--muted);background:#fff;font-size:10px}.attachment-button:hover:not(:disabled){border-color:#AFC9EC;color:var(--blue);background:var(--blue-soft)}.attachment-button:disabled{cursor:not-allowed;opacity:.5}.bubble .attachment-image-button{display:block;max-width:220px;padding:0;border:0;border-radius:7px;background:transparent;overflow:hidden}.attachment-image{display:block;max-width:220px;max-height:180px;border-radius:7px;object-fit:contain;background:#F2F5F9}.attachment-name{display:block;max-width:220px;margin-top:6px;padding:0;border:0;color:inherit;background:transparent;font-size:10px;text-align:left;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.attachment-name:hover{color:var(--blue)}.attachment-unavailable{display:block;max-width:220px;padding:18px 12px;border:1px dashed #D5DEE9;border-radius:7px;color:var(--muted);font-size:10px}.attachment-file{display:flex;align-items:center;gap:9px;min-width:180px;max-width:260px;padding:0;border:0;color:inherit;background:transparent;text-align:left;text-decoration:none}.attachment-file:hover .attachment-file-copy strong{text-decoration:underline}.attachment-file-icon{display:grid;width:28px;height:28px;place-items:center;flex:0 0 auto;border-radius:7px;background:rgba(255,255,255,.2);font-size:18px;font-weight:800}.attachment-file-copy{min-width:0}.attachment-file-copy strong,.attachment-file-copy small{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.attachment-file-copy strong{font-size:11px}.attachment-file-copy small{margin-top:3px;opacity:.72;font-size:9px}.me .attachment-file-icon{color:#fff;background:rgba(255,255,255,.2)}
.message-shell,.message-shell *{box-sizing:border-box}.message-shell button,.message-shell input{font:inherit}.message-shell button{cursor:pointer}.message-shell svg{display:block}
.message-shell{width:min(1380px,calc(100% - 48px));height:calc(100vh - 108px);min-height:650px;margin:18px auto;display:grid;grid-template-columns:290px minmax(0,1fr) 300px;border:1px solid var(--line);border-radius:10px;background:#fff;box-shadow:var(--shadow);overflow:hidden}
.conversation-sidebar{display:flex;min-width:0;flex-direction:column;border-right:1px solid var(--line);background:#fff}.sidebar-head{padding:17px 15px 12px}.sidebar-title{display:flex;align-items:center;gap:7px;color:var(--primary);font-size:17px;font-weight:800}.sidebar-title span{color:var(--light);font-size:10px;font-weight:500}.search-box{position:relative;margin-top:11px}.search-box svg{position:absolute;top:10px;left:11px;width:15px;height:15px;color:#8F9EAF;stroke:currentColor;fill:none;stroke-width:1.8}.search-box input{width:100%;height:36px;padding:0 12px 0 34px;border:1px solid transparent;border-radius:7px;outline:none;color:var(--text);background:#F2F5F9;font-size:11px}.search-box input:focus{border-color:#B9D1F2;background:#fff;box-shadow:0 0 0 3px rgba(43,127,255,.1)}.conversation-list{overflow-x:hidden;overflow-y:auto;padding:0 8px 12px;display:flex;min-height:0;flex-direction:column}.conversation-item{position:relative;width:100%;min-width:0;min-height:62px;display:grid;grid-template-columns:38px minmax(0,1fr) auto;align-items:center;gap:9px;padding:9px;border:0;border-radius:8px;color:inherit;background:transparent;text-align:left}.conversation-item:hover,.conversation-item.active{background:#EEF4FD}.conversation-item.is-pinned{order:-1}.conversation-avatar{width:38px;height:38px;display:grid;place-items:center;border-radius:50%;color:var(--primary);background:var(--blue-soft);font-size:11px;font-weight:800}.conversation-avatar.system{color:var(--blue);background:#EDF4FF}.conversation-item:not(.is-pinned) .conversation-avatar{color:#fff;background:#4B4F56}.conversation-avatar svg{width:18px;height:18px;stroke:currentColor;fill:none;stroke-width:1.7}.conversation-copy{min-width:0;max-width:100%;overflow:hidden}.conversation-name{min-width:0;overflow:hidden;color:var(--primary);font-size:12px;font-weight:800;text-overflow:ellipsis;white-space:nowrap}.conversation-preview{min-width:0;max-width:100%;overflow:hidden;margin-top:3px;color:var(--muted);font-size:10px;text-overflow:ellipsis;white-space:nowrap}.conversation-meta{align-self:start;display:flex;align-items:flex-end;flex-direction:column;gap:3px}.conversation-time{color:var(--light);font-size:9px}.unread{min-width:18px;height:18px;display:inline-flex;align-items:center;justify-content:center;flex:0 0 auto;padding:0 5px;overflow:visible;border-radius:999px;color:#fff;background:var(--red);font-size:10px;font-weight:700;line-height:1;font-variant-numeric:tabular-nums;white-space:nowrap}.conversation-state{display:grid;min-height:120px;place-items:center;padding:20px;color:var(--muted);font-size:11px;text-align:center}.conversation-state.error{color:var(--red)}.conversation-state button,.notification-retry{margin-top:8px;padding:6px 12px;border:1px solid #CBD9EA;border-radius:6px;color:var(--primary);background:#fff;font-size:11px}
.content-area{min-width:0;min-height:0;display:flex;flex-direction:column;overflow:hidden;background:#F7F9FC}.chat-view,.system-view{height:100%;display:flex;min-height:0;flex-direction:column}.chat-head{height:64px;display:flex;align-items:center;padding:0 18px;border-bottom:1px solid var(--line);background:#fff}.chat-person{display:flex;align-items:center;gap:10px}.mini-avatar,.bubble-avatar{display:grid;place-items:center;border-radius:50%;color:var(--primary);background:var(--blue-soft);font-weight:800}.mini-avatar{width:36px;height:36px}.chat-name{color:var(--primary);font-size:14px;font-weight:800}.hr-tag{margin-left:5px;padding:2px 6px;border-radius:4px;color:var(--blue);background:var(--blue-soft);font-size:9px}.online-text{margin-top:2px;color:var(--muted);font-size:9px}.messages{flex:1;min-width:0;min-height:0;overflow-y:auto;overscroll-behavior:contain;scrollbar-gutter:stable;padding:18px}.time-divider{margin:0 0 16px;color:var(--light);font-size:9px;text-align:center}.message-row{display:flex;align-items:flex-end;gap:9px;margin:0 0 14px}.message-row.me{justify-content:flex-end}.bubble-avatar{width:32px;height:32px;flex:0 0 auto;font-size:10px}.bubble-wrap{max-width:68%;min-width:0}.bubble{padding:10px 13px;border:1px solid #DEE5EE;border-radius:4px 10px 10px 10px;color:#344A67;background:#fff;font-size:12px;line-height:1.65;overflow-wrap:anywhere}.message-row.me .bubble{border-color:var(--blue);border-radius:10px 4px 10px 10px;color:#fff;background:var(--blue)}.bubble-time{margin-top:4px;color:var(--light);font-size:9px}.message-row.me .bubble-time{text-align:right}.composer{display:flex;align-items:center;gap:10px;padding:14px 16px;border-top:1px solid var(--line);background:#fff}.composer-box{flex:1;display:flex;align-items:center;height:42px;padding:0 12px;border-radius:8px;background:#F2F5F9}.composer input{width:100%;min-width:0;border:0;outline:none;color:var(--text);background:transparent;font-size:11px}.send-button{height:38px;display:flex;align-items:center;gap:6px;padding:0 15px;border:0;border-radius:7px;color:#fff;background:var(--blue);font-size:11px;font-weight:700}.send-button:disabled{cursor:not-allowed;opacity:.45}.send-button svg{width:14px;height:14px;stroke:currentColor;fill:none;stroke-width:1.8}.empty-chat{height:100%;display:grid;place-items:center;align-content:center;gap:8px;color:var(--muted);font-size:12px}.empty-chat strong{color:var(--primary);font-size:16px}.detail-sidebar{border-left:1px solid var(--line);background:#fff}.detail-head{height:64px;display:flex;align-items:center;padding:0 17px;border-bottom:1px solid var(--line);color:var(--primary);font-size:14px;font-weight:800}.person-panel{margin:12px;padding:14px;border-radius:8px;background:#F7F9FC}.person-card{display:flex;align-items:center;gap:10px}.person-card .mini-avatar{width:46px;height:46px}.person-card strong{display:block;color:var(--primary);font-size:13px}.person-card span{display:block;color:var(--muted);font-size:10px}.person-info{margin-top:12px;padding-top:10px;border-top:1px solid var(--line)}.person-info div{margin:7px 0;color:#64758D;font-size:10px;overflow-wrap:anywhere}
.system-view{background:var(--bg)}.system-head{height:64px;display:flex;align-items:center;justify-content:space-between;padding:0 20px;border-bottom:1px solid var(--line);background:#fff}.system-head h1{margin:0;color:var(--primary);font-size:16px}.system-head button{border:0;color:var(--blue);background:transparent;font-size:10px}.system-head button:disabled{cursor:not-allowed;color:var(--light)}.notification-list{overflow-y:auto;min-height:0;padding:14px}.notification-card{display:grid;grid-template-columns:8px minmax(0,1fr) auto;align-items:start;gap:14px;min-height:86px;margin-bottom:10px;padding:14px 18px;border:1px solid var(--line);border-radius:9px;background:#fff;cursor:pointer}.notification-card:hover,.notification-card:focus-visible{border-color:#B8D1F1;background:#FBFDFF;outline:none}.message-shell .notice-dot{position:static;width:7px;height:7px;margin-top:5px;border:0;border-radius:50%;background:#DDE5EF}.notification-card.unread-notice .notice-dot{background:var(--blue)}.notice-copy{grid-column:2;min-width:0;width:100%}.message-shell .notice-title{margin:0;color:var(--primary);font-size:12px;font-weight:800;line-height:1.45;writing-mode:horizontal-tb;text-orientation:mixed;white-space:normal;overflow-wrap:anywhere;word-break:break-word}.message-shell .notice-desc{margin-top:4px;color:#64758D;font-size:10px;line-height:1.6;writing-mode:horizontal-tb;text-orientation:mixed;white-space:normal;overflow-wrap:anywhere;word-break:break-word}.notice-tag{grid-column:3;grid-row:1;padding:4px 8px;border-radius:5px;color:var(--blue);background:var(--blue-soft);font-size:9px;text-align:center;white-space:nowrap}.notice-tag.gray{color:#62758E;background:#EEF2F7}.notice-time{grid-column:3;grid-row:2;margin-top:6px;color:var(--light);font-size:10px;text-align:right;white-space:nowrap}.notification-state{display:grid;min-height:180px;place-items:center;align-content:center;gap:10px;padding:30px;color:var(--muted);font-size:12px;text-align:center}.notification-state.error{color:var(--red)}.call-modal{position:fixed;inset:0;z-index:60;display:grid;place-items:center;padding:24px;background:rgba(13,30,52,.48);backdrop-filter:blur(3px)}.call-dialog{width:min(390px,100%);padding:26px;border:1px solid #D9E3EF;border-radius:10px;background:#fff;box-shadow:0 22px 60px rgba(14,35,64,.24);text-align:center}.call-avatar{width:62px;height:62px;margin:0 auto 13px;display:grid;place-items:center;border-radius:50%;color:var(--primary);background:var(--blue-soft);font-size:20px;font-weight:800}.call-dialog h2{margin:0;color:var(--primary);font-size:18px}.call-dialog p{margin:7px 0 0;color:var(--muted);font-size:12px;line-height:1.7}.call-actions{display:flex;gap:10px;margin-top:17px}.call-actions button{height:42px;flex:1;border-radius:7px;font-weight:700}.call-cancel{border:1px solid #CFDAE8;color:var(--primary);background:#fff}.toast{position:fixed;z-index:70;right:24px;bottom:24px;padding:10px 14px;border:1px solid #CDE7DD;border-radius:8px;color:#176B50;background:#F2FBF7;opacity:0;transform:translateY(10px);transition:.18s}.toast.show{opacity:1;transform:translateY(0)}
@media(max-width:1050px){.message-shell{width:calc(100% - 28px);grid-template-columns:250px minmax(0,1fr)}.detail-sidebar{display:none}}@media(max-width:700px){.message-shell{height:calc(100vh - 84px);min-height:580px;margin:10px auto;grid-template-columns:74px minmax(0,1fr)}.sidebar-head{padding:10px 8px}.sidebar-title span,.sidebar-title{font-size:0}.sidebar-title::after{content:"消息";font-size:13px}.search-box{display:none}.conversation-list{padding:0 6px}.conversation-item{grid-template-columns:38px;justify-content:center;padding:8px 5px}.conversation-copy,.conversation-meta{display:none}.unread{position:absolute;margin-left:28px}.system-mode{grid-template-columns:74px minmax(0,1fr)}.notification-card{grid-template-columns:7px minmax(0,1fr);gap:9px}.notice-tag,.notice-time{display:none}.bubble-wrap{max-width:84%}}@media(prefers-reduced-motion:reduce){*,*::before,*::after{transition:none!important}}
.conversation-search{position:relative;display:block;width:100%;height:36px;margin-top:11px}.conversation-search svg{position:absolute;top:10px;left:11px;width:15px;height:15px;color:#8F9EAF;stroke:currentColor;fill:none;stroke-width:1.8;pointer-events:none}.conversation-search input{display:block;width:100%;height:36px;padding:0 12px 0 34px;border:1px solid transparent;border-radius:7px;outline:none;color:var(--text);background:#F2F5F9;font-size:11px;line-height:36px}.conversation-search input:focus{border-color:#B9D1F2;background:#fff;box-shadow:0 0 0 3px rgba(43,127,255,.1)}
@media(max-width:700px){.conversation-search{display:none}}
.ai-assistant-fab{position:fixed;right:24px;bottom:24px;z-index:75;width:52px;height:52px;border:0;border-radius:50%;color:#fff;background:linear-gradient(145deg,#2B7FFF,#1A3C6E);box-shadow:0 10px 24px rgba(26,60,110,.25);font-size:13px;font-weight:800}.ai-assistant-fab:hover{transform:translateY(-2px);box-shadow:0 13px 28px rgba(26,60,110,.3)}.ai-assistant-panel{position:fixed;right:24px;bottom:88px;z-index:74;display:flex;width:min(380px,calc(100vw - 32px));height:min(560px,calc(100vh - 120px));min-height:360px;flex-direction:column;overflow:hidden;border:1px solid #D8E4F2;border-radius:14px;background:#fff;box-shadow:0 18px 48px rgba(21,49,87,.2)}.ai-assistant-head{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:13px 14px;border-bottom:1px solid var(--line);background:linear-gradient(135deg,#F4F8FF,#fff)}.ai-assistant-brand{display:flex;align-items:center;gap:9px;min-width:0}.ai-assistant-icon{display:grid;width:32px;height:32px;place-items:center;flex:0 0 auto;border-radius:10px;color:#fff;background:var(--blue);font-size:10px;font-weight:800}.ai-assistant-brand strong,.ai-assistant-brand span{display:block}.ai-assistant-brand strong{color:var(--primary);font-size:13px}.ai-assistant-brand span{margin-top:2px;overflow:hidden;color:var(--muted);font-size:9px;text-overflow:ellipsis;white-space:nowrap}.ai-assistant-actions{display:flex;gap:4px}.ai-assistant-actions button{width:26px;height:26px;padding:0;border:0;border-radius:6px;color:var(--muted);background:transparent;font-size:18px;line-height:1}.ai-assistant-actions button:hover{color:var(--blue);background:var(--blue-soft)}.ai-session-switcher{display:flex;align-items:center;gap:8px;padding:8px 12px;border-bottom:1px solid #EEF2F7;background:#FBFCFE}.ai-session-switcher label{color:var(--light);font-size:10px}.ai-session-switcher select{min-width:0;flex:1;padding:5px 7px;border:1px solid #DCE6F1;border-radius:6px;outline:none;color:var(--primary);background:#fff;font-size:10px}.ai-assistant-messages{min-height:0;flex:1;overflow-y:auto;padding:14px;background:#F7F9FC}.ai-assistant-state,.ai-assistant-welcome{display:grid;place-items:center;gap:7px;min-height:160px;padding:22px;color:var(--muted);font-size:11px;line-height:1.7;text-align:center}.ai-assistant-state button{padding:5px 9px;border:1px solid #C9D9EB;border-radius:6px;color:var(--blue);background:#fff;font-size:10px}.ai-error,.ai-assistant-error{color:var(--red)}.ai-assistant-welcome strong{color:var(--primary);font-size:13px}.ai-message{display:flex;align-items:flex-start;gap:7px;margin-bottom:12px}.ai-message.is-user{flex-direction:row-reverse}.ai-message-avatar{display:grid;width:24px;height:24px;place-items:center;flex:0 0 auto;border-radius:50%;color:#fff;background:var(--blue);font-size:8px;font-weight:800}.is-user .ai-message-avatar{background:#7894BE}.ai-message-bubble{max-width:78%;padding:8px 10px;border:1px solid #DDE5EF;border-radius:5px 10px 10px 10px;color:#3D526E;background:#fff;font-size:11px;line-height:1.65;white-space:pre-wrap;overflow-wrap:anywhere}.is-user .ai-message-bubble{border-color:var(--blue);border-radius:10px 5px 10px 10px;color:#fff;background:var(--blue)}.ai-assistant-error{margin:0;padding:7px 12px;background:#FFF5F5;font-size:10px}.ai-assistant-composer{display:flex;align-items:center;gap:7px;padding:10px;border-top:1px solid var(--line);background:#fff}.ai-assistant-composer input{min-width:0;height:34px;flex:1;padding:0 10px;border:1px solid #D8E3EF;border-radius:7px;outline:none;color:var(--text);background:#F8FAFD;font-size:11px}.ai-assistant-composer input:focus{border-color:#AFC9EC;background:#fff}.ai-assistant-composer button{display:grid;width:34px;height:34px;place-items:center;padding:0;border:0;border-radius:7px;color:#fff;background:var(--blue);font-size:15px;font-weight:800}.ai-assistant-composer button:disabled{cursor:not-allowed;opacity:.45}.ai-assistant-composer button[type=button]{background:#6D7F99;font-size:10px}@media(max-width:700px){.ai-assistant-fab{right:16px;bottom:16px}.ai-assistant-panel{right:16px;bottom:78px;width:calc(100vw - 32px);height:min(560px,calc(100vh - 100px))}}
</style>

<style>
.ai-assistant-panel{--primary:#1A3C6E;--blue:#2B7FFF;--blue-soft:#EAF2FF;--muted:#6B7A90;--light:#96A3B5;--line:#E6EBF2;--red:#D94B55}
.person-card .mini-avatar{display:grid;place-items:center;flex:0 0 auto;overflow:hidden;color:var(--primary);background:var(--blue-soft);font-size:14px;line-height:1}
.composer{align-items:stretch;flex-direction:column;gap:9px;padding:10px 16px 13px}.composer-tools{display:flex;align-items:center;justify-content:space-between;gap:12px;min-height:28px}.composer-tool-list{display:flex;align-items:center;gap:7px}.composer-tool{display:inline-flex;align-items:center;gap:5px;height:28px;padding:0 7px;border:0;border-radius:6px;color:#60738D;background:transparent;font-size:10px}.composer-tool:hover:not(:disabled){color:var(--blue);background:var(--blue-soft)}.composer-tool:disabled{cursor:not-allowed;opacity:.45}.composer-tool svg{width:17px;height:17px;stroke:currentColor;fill:none;stroke-width:1.8}.composer-hint{overflow:hidden;color:var(--light);font-size:9px;text-overflow:ellipsis;white-space:nowrap}.composer-main{display:flex;align-items:center;gap:10px}.composer-main .composer-box{min-width:0}.composer-main .send-button{flex:0 0 auto;min-width:92px;justify-content:center}.attachment-actions{display:none}
@media(max-width:700px){.composer{padding:9px 10px 11px}.composer-hint{display:none}.composer-main{gap:7px}.composer-main .send-button{min-width:72px;padding:0 10px}.composer-tool{padding:0 5px}}
</style>
