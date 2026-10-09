<template>
  <AgentTopbar active="messages" />
  <main class="message-shell" :class="{ 'system-mode': activeView === 'system' }">
    <aside class="conversation-sidebar">
      <div class="sidebar-head">
        <div class="sidebar-title">消息 <span>共 {{ sessions.length }} 个会话</span></div>
        <label class="search-box">
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
        <template v-if="selectedSession">
          <header class="chat-head">
            <div class="chat-person">
              <span class="mini-avatar">{{ avatarText(selectedSession.peerName) }}</span>
              <div>
                <div class="chat-name">{{ selectedSession.peerName || '联系人' }} <span class="hr-tag">站内联系人</span></div>
                <div class="online-text">消息会话</div>
              </div>
            </div>
          </header>

          <div ref="messagesContainer" class="messages">
            <div v-if="messagesLoading" class="notification-state">正在读取聊天记录...</div>
            <div v-else-if="messagesError" class="notification-state error">
              <span>聊天记录暂时无法读取</span>
              <button class="notification-retry" type="button" @click="loadMessages(selectedSessionId)">重新加载</button>
            </div>
            <template v-else-if="messages.length">
              <div class="time-divider">聊天记录</div>
              <div v-for="message in messages" :key="message.messageId" class="message-row" :class="{ me: message.isMine }">
                <span v-if="!message.isMine" class="bubble-avatar">{{ avatarText(selectedSession.peerName) }}</span>
                <div class="bubble-wrap">
                  <div class="bubble">{{ message.content || '[非文本消息]' }}</div>
                  <div class="bubble-time">{{ formatMessageTime(message.sendTime) }}</div>
                </div>
              </div>
            </template>
            <div v-else class="notification-state">暂无聊天记录</div>
          </div>

          <form class="composer" @submit.prevent="sendMessage">
            <div class="composer-box">
              <input
                v-model="draftMessage"
                type="text"
                maxlength="1000"
                placeholder="输入消息，Enter 发送"
                aria-label="消息内容"
                autocomplete="off"
              />
            </div>
            <button class="send-button" type="submit" :disabled="sending || !draftMessage.trim()">
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m21 3-8.2 18-2.4-7.4L3 11.2Z" /><path d="M10.4 13.6 21 3" /></svg>
              {{ sending ? '发送中' : '发送' }}
            </button>
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

    <aside v-if="activeView === 'chat' && selectedSession" class="detail-sidebar">
      <div class="detail-head">会话详情</div>
      <div class="person-panel">
        <div class="person-card">
          <span class="mini-avatar">{{ avatarText(selectedSession.peerName) }}</span>
          <div>
            <strong>{{ selectedSession.peerName || '联系人' }}</strong>
            <span>消息会话联系人</span>
          </div>
        </div>
        <div class="person-info">
          <div>会话编号：{{ selectedSession.sessionId }}</div>
          <div>最近消息：{{ selectedSession.lastMessage || '暂无消息内容' }}</div>
          <div>更新时间：{{ formatMessageTime(selectedSession.lastMessageAt) }}</div>
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
  <div class="toast" :class="{ show: toastVisible }" role="status" aria-live="polite">{{ toastText }}</div>
</template>

<script setup>
import { computed, nextTick, onMounted, ref } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { getNotice, listNoticeTop, markNoticeRead, markNoticeReadAll } from '@/api/system/notice'
import { listImMessages, listImSessions, markImSessionRead, sendImMessage } from '@/api/system/im'

const sessions = ref([])
const selectedSessionId = ref(null)
const activeView = ref('system')
const searchQuery = ref('')
const sessionsLoading = ref(true)
const sessionsError = ref(false)
const messages = ref([])
const messagesLoading = ref(false)
const messagesError = ref(false)
const draftMessage = ref('')
const sending = ref(false)
const noticeItems = ref([])
const noticesLoading = ref(true)
const noticesError = ref(false)
const activeNotice = ref(null)
const messagesContainer = ref(null)
const toastText = ref('')
const toastVisible = ref(false)
let toastTimer

const selectedSession = computed(() => sessions.value.find(item => item.sessionId === selectedSessionId.value) || null)
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
    const requestedSession = sessions.value.find(item => item.sessionId === requestedId)
    if (requestedSession) {
      await selectSession(requestedSession, false)
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

async function loadMessages(sessionId) {
  if (!sessionId) return
  messagesLoading.value = true
  messagesError.value = false
  try {
    const response = await listImMessages(sessionId)
    messages.value = Array.isArray(response.data) ? response.data : []
    await nextTick()
    if (messagesContainer.value) messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
  } catch (error) {
    messagesError.value = true
    showToast(error?.message || '聊天记录加载失败')
  } finally {
    messagesLoading.value = false
  }
}

async function selectSession(session, updateUrl = true) {
  activeView.value = 'chat'
  selectedSessionId.value = session.sessionId
  messages.value = []
  if (updateUrl) history.replaceState(null, '', `/agent/messages?conversation=${encodeURIComponent(session.sessionId)}`)
  await Promise.all([
    loadMessages(session.sessionId),
    markImSessionRead(session.sessionId).catch(() => {})
  ])
  session.unread = 0
}

function selectSystem(updateUrl = true) {
  activeView.value = 'system'
  selectedSessionId.value = null
  if (updateUrl) history.replaceState(null, '', '/agent/messages?view=system')
}

async function sendMessage() {
  const content = draftMessage.value.trim()
  if (!content || !selectedSession.value || sending.value) return
  sending.value = true
  try {
    await sendImMessage({
      sessionId: selectedSession.value.sessionId,
      type: 1,
      content
    })
    draftMessage.value = ''
    await loadMessages(selectedSession.value.sessionId)
    await loadSessions()
    showToast('消息已发送')
  } catch (error) {
    showToast(error?.message || '消息发送失败')
  } finally {
    sending.value = false
  }
}

async function loadNotices() {
  noticesLoading.value = true
  noticesError.value = false
  try {
    const response = await listNoticeTop({ limit: 50 })
    noticeItems.value = Array.isArray(response.data) ? response.data : []
  } catch (error) {
    noticesError.value = true
    showToast(error?.message || '系统通知加载失败')
  } finally {
    noticesLoading.value = false
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

onMounted(() => {
  loadNotices()
  loadSessions()
})
</script>

<style>
:root{--primary:#1A3C6E;--blue:#2B7FFF;--blue-soft:#EAF2FF;--bg:#F5F7FA;--text:#172B4D;--muted:#6B7A90;--light:#96A3B5;--line:#E6EBF2;--red:#D94B55;--shadow:0 5px 18px rgba(26,60,110,.045)}
*{box-sizing:border-box}button,input{font:inherit}button{cursor:pointer}svg{display:block}
.message-shell{width:min(1380px,calc(100% - 48px));height:calc(100vh - 108px);min-height:650px;margin:18px auto;display:grid;grid-template-columns:290px minmax(0,1fr) 300px;border:1px solid var(--line);border-radius:10px;background:#fff;box-shadow:var(--shadow);overflow:hidden}
.conversation-sidebar{display:flex;min-width:0;flex-direction:column;border-right:1px solid var(--line);background:#fff}.sidebar-head{padding:17px 15px 12px}.sidebar-title{display:flex;align-items:center;gap:7px;color:var(--primary);font-size:17px;font-weight:800}.sidebar-title span{color:var(--light);font-size:10px;font-weight:500}.search-box{position:relative;margin-top:11px}.search-box svg{position:absolute;top:10px;left:11px;width:15px;height:15px;color:#8F9EAF;stroke:currentColor;fill:none;stroke-width:1.8}.search-box input{width:100%;height:36px;padding:0 12px 0 34px;border:1px solid transparent;border-radius:7px;outline:none;color:var(--text);background:#F2F5F9;font-size:11px}.search-box input:focus{border-color:#B9D1F2;background:#fff;box-shadow:0 0 0 3px rgba(43,127,255,.1)}.conversation-list{overflow-y:auto;padding:0 8px 12px;display:flex;min-height:0;flex-direction:column}.conversation-item{position:relative;width:100%;min-height:62px;display:grid;grid-template-columns:38px minmax(0,1fr) auto;align-items:center;gap:9px;padding:9px;border:0;border-radius:8px;color:inherit;background:transparent;text-align:left}.conversation-item:hover,.conversation-item.active{background:#EEF4FD}.conversation-item.is-pinned{order:-1}.conversation-avatar{width:38px;height:38px;display:grid;place-items:center;border-radius:50%;color:var(--primary);background:var(--blue-soft);font-size:11px;font-weight:800}.conversation-avatar.system{color:var(--blue);background:#EDF4FF}.conversation-avatar svg{width:18px;height:18px;stroke:currentColor;fill:none;stroke-width:1.7}.conversation-copy{min-width:0}.conversation-name{overflow:hidden;color:var(--primary);font-size:12px;font-weight:800;text-overflow:ellipsis;white-space:nowrap}.conversation-preview{overflow:hidden;margin-top:3px;color:var(--muted);font-size:10px;text-overflow:ellipsis;white-space:nowrap}.conversation-meta{align-self:start;display:flex;align-items:flex-end;flex-direction:column;gap:3px}.conversation-time{color:var(--light);font-size:9px}.unread{min-width:17px;height:17px;display:grid;place-items:center;border-radius:50%;color:#fff;background:var(--red);font-size:9px}.conversation-state{display:grid;min-height:120px;place-items:center;padding:20px;color:var(--muted);font-size:11px;text-align:center}.conversation-state.error{color:var(--red)}.conversation-state button,.notification-retry{margin-top:8px;padding:6px 12px;border:1px solid #CBD9EA;border-radius:6px;color:var(--primary);background:#fff;font-size:11px}
.content-area{min-width:0;display:flex;flex-direction:column;background:#F7F9FC}.chat-view,.system-view{height:100%;display:flex;min-height:0;flex-direction:column}.chat-head{height:64px;display:flex;align-items:center;padding:0 18px;border-bottom:1px solid var(--line);background:#fff}.chat-person{display:flex;align-items:center;gap:10px}.mini-avatar,.bubble-avatar{display:grid;place-items:center;border-radius:50%;color:var(--primary);background:var(--blue-soft);font-weight:800}.mini-avatar{width:36px;height:36px}.chat-name{color:var(--primary);font-size:14px;font-weight:800}.hr-tag{margin-left:5px;padding:2px 6px;border-radius:4px;color:var(--blue);background:var(--blue-soft);font-size:9px}.online-text{margin-top:2px;color:var(--muted);font-size:9px}.messages{flex:1;overflow-y:auto;min-height:0;padding:18px}.time-divider{margin:0 0 16px;color:var(--light);font-size:9px;text-align:center}.message-row{display:flex;align-items:flex-end;gap:9px;margin:0 0 14px}.message-row.me{justify-content:flex-end}.bubble-avatar{width:32px;height:32px;flex:0 0 auto;font-size:10px}.bubble-wrap{max-width:68%;min-width:0}.bubble{padding:10px 13px;border:1px solid #DEE5EE;border-radius:4px 10px 10px 10px;color:#344A67;background:#fff;font-size:12px;line-height:1.65;overflow-wrap:anywhere}.message-row.me .bubble{border-color:var(--blue);border-radius:10px 4px 10px 10px;color:#fff;background:var(--blue)}.bubble-time{margin-top:4px;color:var(--light);font-size:9px}.message-row.me .bubble-time{text-align:right}.composer{display:flex;align-items:center;gap:10px;padding:14px 16px;border-top:1px solid var(--line);background:#fff}.composer-box{flex:1;display:flex;align-items:center;height:42px;padding:0 12px;border-radius:8px;background:#F2F5F9}.composer input{width:100%;min-width:0;border:0;outline:none;color:var(--text);background:transparent;font-size:11px}.send-button{height:38px;display:flex;align-items:center;gap:6px;padding:0 15px;border:0;border-radius:7px;color:#fff;background:var(--blue);font-size:11px;font-weight:700}.send-button:disabled{cursor:not-allowed;opacity:.45}.send-button svg{width:14px;height:14px;stroke:currentColor;fill:none;stroke-width:1.8}.empty-chat{height:100%;display:grid;place-items:center;align-content:center;gap:8px;color:var(--muted);font-size:12px}.empty-chat strong{color:var(--primary);font-size:16px}.detail-sidebar{border-left:1px solid var(--line);background:#fff}.detail-head{height:64px;display:flex;align-items:center;padding:0 17px;border-bottom:1px solid var(--line);color:var(--primary);font-size:14px;font-weight:800}.person-panel{margin:12px;padding:14px;border-radius:8px;background:#F7F9FC}.person-card{display:flex;align-items:center;gap:10px}.person-card .mini-avatar{width:46px;height:46px}.person-card strong{display:block;color:var(--primary);font-size:13px}.person-card span{display:block;color:var(--muted);font-size:10px}.person-info{margin-top:12px;padding-top:10px;border-top:1px solid var(--line)}.person-info div{margin:7px 0;color:#64758D;font-size:10px;overflow-wrap:anywhere}
.system-view{background:var(--bg)}.system-head{height:64px;display:flex;align-items:center;justify-content:space-between;padding:0 20px;border-bottom:1px solid var(--line);background:#fff}.system-head h1{margin:0;color:var(--primary);font-size:16px}.system-head button{border:0;color:var(--blue);background:transparent;font-size:10px}.system-head button:disabled{cursor:not-allowed;color:var(--light)}.notification-list{overflow-y:auto;min-height:0;padding:14px}.notification-card{display:grid;grid-template-columns:8px minmax(0,1fr) minmax(74px,auto);align-items:start;gap:14px;min-height:86px;margin-bottom:10px;padding:14px 18px;border:1px solid var(--line);border-radius:9px;background:#fff;cursor:pointer}.notification-card:hover,.notification-card:focus-visible{border-color:#B8D1F1;background:#FBFDFF;outline:none}.notice-dot{width:7px;height:7px;margin-top:5px;border-radius:50%;background:#DDE5EF}.notification-card.unread-notice .notice-dot{background:var(--blue)}.notice-title{color:var(--primary);font-size:12px;font-weight:800;line-height:1.45;overflow-wrap:anywhere}.notice-desc{margin-top:4px;color:#64758D;font-size:10px;line-height:1.6;overflow-wrap:anywhere}.notice-tag{grid-column:3;grid-row:1;padding:4px 8px;border-radius:5px;color:var(--blue);background:var(--blue-soft);font-size:9px;text-align:center;white-space:nowrap}.notice-tag.gray{color:#62758E;background:#EEF2F7}.notice-time{grid-column:3;grid-row:2;margin-top:6px;color:var(--light);font-size:10px;text-align:right;white-space:nowrap}.notification-state{display:grid;min-height:180px;place-items:center;align-content:center;gap:10px;padding:30px;color:var(--muted);font-size:12px;text-align:center}.notification-state.error{color:var(--red)}.call-modal{position:fixed;inset:0;z-index:60;display:grid;place-items:center;padding:24px;background:rgba(13,30,52,.48);backdrop-filter:blur(3px)}.call-dialog{width:min(390px,100%);padding:26px;border:1px solid #D9E3EF;border-radius:10px;background:#fff;box-shadow:0 22px 60px rgba(14,35,64,.24);text-align:center}.call-avatar{width:62px;height:62px;margin:0 auto 13px;display:grid;place-items:center;border-radius:50%;color:var(--primary);background:var(--blue-soft);font-size:20px;font-weight:800}.call-dialog h2{margin:0;color:var(--primary);font-size:18px}.call-dialog p{margin:7px 0 0;color:var(--muted);font-size:12px;line-height:1.7}.call-actions{display:flex;gap:10px;margin-top:17px}.call-actions button{height:42px;flex:1;border-radius:7px;font-weight:700}.call-cancel{border:1px solid #CFDAE8;color:var(--primary);background:#fff}.toast{position:fixed;z-index:70;right:24px;bottom:24px;padding:10px 14px;border:1px solid #CDE7DD;border-radius:8px;color:#176B50;background:#F2FBF7;opacity:0;transform:translateY(10px);transition:.18s}.toast.show{opacity:1;transform:translateY(0)}
@media(max-width:1050px){.message-shell{width:calc(100% - 28px);grid-template-columns:250px minmax(0,1fr)}.detail-sidebar{display:none}}@media(max-width:700px){.message-shell{height:calc(100vh - 84px);min-height:580px;margin:10px auto;grid-template-columns:74px minmax(0,1fr)}.sidebar-head{padding:10px 8px}.sidebar-title span,.sidebar-title{font-size:0}.sidebar-title::after{content:"消息";font-size:13px}.search-box{display:none}.conversation-list{padding:0 6px}.conversation-item{grid-template-columns:38px;justify-content:center;padding:8px 5px}.conversation-copy,.conversation-meta{display:none}.unread{position:absolute;margin-left:28px}.system-mode{grid-template-columns:74px minmax(0,1fr)}.notification-card{grid-template-columns:7px minmax(0,1fr);gap:9px}.notice-tag,.notice-time{display:none}.bubble-wrap{max-width:84%}}@media(prefers-reduced-motion:reduce){*,*::before,*::after{transition:none!important}}
</style>
