<script setup>
import { ref, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Sparkles, Plus, Trash2, Send, CirclePause, MessageSquareText } from '@/views/enterprise/components/icons'
import { listSessions, createSession, listMessages, createRun, getRun, cancelRun, deleteSession, genRequestId, openRunEvents } from '@/api/assistant'

const sessions = ref([])
const activeId = ref(null)
const messages = ref([])
const input = ref('')
const loading = ref(false)
const streaming = ref(false)
const progress = ref('')
const scroller = ref()
// 会话列表以浮层抽屉呈现，默认隐藏
const listOpen = ref(false)
// 当前 run 的 SSE 订阅句柄与 id（离开/切换会话或收到终态时关闭）
let sseClose = null
let currentRunId = null

// 错误文案映射：401/404/403 使用固定提示，其余透传原始错误
function showApiError(e) {
  const msg = e?.message || (typeof e === 'string' ? e : '') || ''
  let text = msg || 'AI服务暂不可用，请检查网络后重试'
  if (msg.includes('401') || msg.includes('无效的会话') || msg.includes('会话已过期')) text = '登录已失效，请重新登录后使用AI助手'
  else if (msg.includes('404')) text = 'AI对话不存在，或服务器尚未部署企业助手接口'
  else if (msg.includes('403')) text = '请确认当前账号已绑定企业且具有访问权限'
  ElMessage.error(text)
}

function fmtTime(s) {
  if (!s) return ''
  const d = new Date(String(s).includes('T') ? s : s.replace(/-/g, '/'))
  if (isNaN(d.getTime())) return ''
  const now = new Date()
  const hm = String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0')
  if (d.toDateString() === now.toDateString()) return hm
  const yest = new Date(now.getTime() - 86400000)
  if (d.toDateString() === yest.toDateString()) return '昨天'
  return String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0')
}

function scrollToBottom() {
  nextTick(() => { if (scroller.value) scroller.value.scrollTop = scroller.value.scrollHeight })
}

function closeSse() {
  if (sseClose) { sseClose(); sseClose = null }
}

// ---------- 流式气泡（pending 占位消息，收到终态后落为正式消息） ----------
function setPendingContent(text) {
  const p = messages.value.find(m => m.pending)
  if (p) p.content = text
  else messages.value.push({ id: null, role: 'assistant', pending: true, content: text || '' })
}
function commitPending(runId) {
  const p = messages.value.find(m => m.pending)
  if (p) { p.pending = false; p.id = 'run-' + runId }
}
function removePending() {
  messages.value = messages.value.filter(m => !m.pending)
}

function applyRun(run, sessionId) {
  if (activeId.value !== sessionId) return
  if (run.state === 'R') {
    progress.value = run.progress || ''
    setPendingContent(run.content || '')
    scrollToBottom()
  } else {
    finishRun(run)
  }
}

// 收到 C/F/X 终态：结束订阅，把累积的完整 content 落到消息列表
function finishRun(run) {
  if (!streaming.value) return
  closeSse()
  streaming.value = false
  progress.value = ''
  currentRunId = null
  if (run.content) { setPendingContent(run.content); commitPending(run.id) } else removePending()
  if (run.state === 'X') ElMessage.error(run.error || 'AI回答生成失败，请重试')
  loadSessions()
}

function subscribe(run, sessionId) {
  currentRunId = run.id
  streaming.value = true
  if (run.state === 'R') {
    progress.value = run.progress || ''
    setPendingContent(run.content || '')
    scrollToBottom()
    sseClose = openRunEvents(run.id, {
      onRun: r => applyRun(r, sessionId),
      onError: err => { if (activeId.value === sessionId) showApiError(err) },
      onClose: () => {
        // 流自然结束但未收到终态帧：按当前已收内容收尾，避免气泡永远停在生成中
        if (streaming.value) finishRun({ id: run.id, state: 'F', content: (messages.value.find(m => m.pending) || {}).content || '' })
      }
    })
  } else {
    // POST runs 直接返回终态（如幂等命中已完成请求）
    finishRun(run)
  }
}

// 恢复场景：会话存在 activeRunId 时取当前 run 并订阅其事件流
function resumeRun(runId, sessionId) {
  getRun(runId).then(res => {
    const run = res.data
    if (!run || activeId.value !== sessionId) return
    if (run.state === 'R') subscribe(run, sessionId)
  }).catch(e => { if (activeId.value === sessionId) showApiError(e) })
}

// ---------- 会话与消息加载 ----------
async function loadSessions() {
  try {
    const res = await listSessions()
    sessions.value = (res.data && res.data.items) || []
  } catch (e) {
    showApiError(e)
  }
}

async function loadMessages(sessionId) {
  loading.value = true
  try {
    const res = await listMessages(sessionId)
    const data = res.data || {}
    messages.value = (data.items || []).map(m => ({ id: m.id, role: m.role, content: m.content }))
    scrollToBottom()
    if (data.activeRunId != null) resumeRun(data.activeRunId, sessionId)
  } catch (e) {
    messages.value = []
    showApiError(e)
  } finally {
    loading.value = false
  }
}

async function openSession(s) {
  listOpen.value = false
  if (s.id === activeId.value) return
  closeSse()
  streaming.value = false
  progress.value = ''
  currentRunId = null
  activeId.value = s.id
  await loadMessages(s.id)
}

// 新建对话只清空当前视图，真正落库在首次发送时（避免留下空会话）
function newSession() {
  listOpen.value = false
  closeSse()
  streaming.value = false
  progress.value = ''
  currentRunId = null
  activeId.value = null
  messages.value = []
  input.value = ''
}

async function removeSession(s) {
  try {
    await ElMessageBox.confirm(`删除对话「${s.title || '新对话'}」后聊天记录不可恢复，确定删除？`, '删除对话', { confirmButtonText: '删除', cancelButtonText: '取消', type: 'warning' })
  } catch {
    return
  }
  try {
    await deleteSession(s.id)
    sessions.value = sessions.value.filter(x => x.id !== s.id)
    if (activeId.value === s.id) {
      closeSse()
      streaming.value = false
      progress.value = ''
      currentRunId = null
      activeId.value = null
      messages.value = []
      if (sessions.value.length) await openSession(sessions.value[0])
    }
  } catch (e) {
    showApiError(e)
  }
}

// ---------- 发送与停止 ----------
async function send() {
  const text = input.value.trim()
  if (!text || streaming.value) return
  try {
    let sessionId = activeId.value
    if (sessionId == null) {
      const res = await createSession()
      const s = res.data || {}
      sessions.value.unshift({ id: s.id, title: s.title, updatedAt: s.updatedAt, activeRunId: null })
      activeId.value = s.id
      messages.value = []
      sessionId = s.id
    }
    const requestId = genRequestId()
    input.value = ''
    messages.value.push({ id: 'req-' + requestId, role: 'user', content: text })
    scrollToBottom()
    const res = await createRun(sessionId, requestId, text)
    if (res.data) subscribe(res.data, sessionId)
  } catch (e) {
    showApiError(e)
  }
}

async function stop() {
  if (currentRunId == null) return
  try {
    const res = await cancelRun(currentRunId)
    if (res.data) finishRun(res.data)
  } catch (e) {
    showApiError(e)
  }
}

onMounted(async () => {
  await loadSessions()
  if (sessions.value.length) await openSession(sessions.value[0])
})

onBeforeUnmount(closeSse)
</script>

<template>
  <div class="assistant-page" :class="{ 'list-open': listOpen }">
    <nav v-show="!listOpen" class="side-rail">
      <button class="rail-btn" title="新建对话" @click="newSession"><Plus :size="17"/></button>
      <button class="rail-btn" title="历史对话" @click="listOpen = true"><MessageSquareText :size="17"/></button>
    </nav>

    <aside v-show="listOpen" class="session-panel">
      <div class="sp-head">
        <button class="rail-btn" title="新建对话" @click="newSession"><Plus :size="17"/></button>
        <button class="rail-btn active" title="收起对话列表" @click="listOpen = false"><MessageSquareText :size="17"/></button>
      </div>
      <div class="session-list">
        <article v-for="s in sessions" :key="s.id" :class="{ active: s.id === activeId }" @click="openSession(s)">
          <MessageSquareText :size="15" class="s-icon" />
          <div class="s-info"><h3>{{ s.title || '新对话' }}</h3><time>{{ fmtTime(s.updatedAt) }}</time></div>
          <button class="s-del" title="删除对话" @click.stop="removeSession(s)"><Trash2 :size="14"/></button>
        </article>
        <p v-if="!sessions.length" class="empty-list">暂无对话，点击「新建对话」开始</p>
      </div>
    </aside>

    <section class="chat-panel">
      <header class="chat-head">
        <span class="head-icon"><Sparkles :size="17"/></span>
        <h2>企业 AI 助手</h2>
        <p>岗位描述、简历初筛、面试安排等问题都可以问我</p>
      </header>
      <div ref="scroller" class="message-stream">
        <p v-if="loading" class="stream-loading">加载中…</p>
        <p v-else-if="!messages.length && !streaming" class="stream-loading">开始一段新对话吧</p>
        <div v-for="msg in messages" :key="msg.id || 'pending'" :class="['message-row', msg.role === 'user' ? 'me' : 'other']">
          <span class="bubble">{{ msg.content }}<em v-if="msg.pending && streaming" class="caret"></em></span>
        </div>
        <p v-if="streaming && progress" class="run-progress"><CirclePause :size="13"/>{{ progress }}</p>
      </div>
      <footer class="composer">
        <textarea v-model="input" rows="1" @keydown.enter.exact.prevent="send" placeholder="输入问题，Enter 发送，Shift+Enter 换行…"></textarea>
        <button v-if="streaming" class="stop" @click="stop"><CirclePause :size="15"/>停止生成</button>
        <button v-else class="send" @click="send"><Send :size="15"/>发送</button>
      </footer>
    </section>
  </div>
</template>

<style scoped>
.assistant-page{--pad:16px;height:calc(100vh - 64px);padding:var(--pad);display:grid;grid-template-columns:46px minmax(0,1fr);gap:8px;overflow:hidden;background:#f6f8fc}
.assistant-page.list-open{grid-template-columns:264px minmax(0,1fr)}
.side-rail{display:flex;flex-direction:column;align-items:center;gap:6px;padding-top:4px}
.rail-btn{width:34px;height:34px;border:0;border-radius:9px;background:none;color:#5c6f89;display:grid;place-items:center;cursor:pointer}
.rail-btn:hover{background:#e8eef8;color:#2563eb}
.rail-btn.active{background:#dbe8fd;color:#2563eb}
.chat-panel{display:flex;flex-direction:column;overflow:hidden}
.session-panel{background:white;border:1px solid #e8edf4;border-radius:12px;display:flex;flex-direction:column;overflow:hidden;box-shadow:0 6px 20px rgba(15,34,67,.08)}
.sp-head{padding:10px 10px;flex:none;display:flex;gap:6px}
.sp-head .rail-btn{width:34px;height:34px}
.session-list{flex:1;overflow:auto;padding-bottom:10px}
.session-list article{min-height:64px;border-top:1px solid #e8edf4;display:flex;align-items:center;gap:9px;padding:10px 14px;cursor:pointer;position:relative}
.session-list article:hover{background:#f6f9fd}
.session-list article.active{background:#edf4ff}
.s-icon{color:#8ea3c0;flex:none}
.session-list article.active .s-icon{color:#2563eb}
.s-info{flex:1;min-width:0}
.session-list h3{font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;padding-right:44px}
.session-list time{display:block;color:#98a5b7;font-size:9px;margin-top:5px}
.s-del{position:absolute;right:10px;top:50%;transform:translateY(-50%);width:26px;height:26px;border:0;border-radius:7px;background:none;color:#98a5b7;display:grid;place-items:center;cursor:pointer;opacity:0}
.session-list article:hover .s-del{opacity:1}
.s-del:hover{background:#fdecec;color:#dc2626}
.empty-list{text-align:center;color:#98a5b7;font-size:10px;padding:24px 0;margin:0}
.chat-head{height:64px;flex:none;display:flex;align-items:center;gap:10px;padding:0 18px}
.head-icon{width:34px;height:34px;border-radius:10px;background:#edf4ff;color:#2563eb;display:grid;place-items:center;flex:none}
.chat-head h2{font-size:14px;white-space:nowrap}
.chat-head p{color:#9aa7b8;font-size:10px;margin-left:auto;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.message-stream{flex:1;overflow:auto;padding:6px 18px 10px}
.stream-loading{text-align:center;color:#98a5b7;font-size:10px}
.message-row{display:flex;flex-direction:column;margin-bottom:17px}
.message-row.other{align-items:flex-start}
.message-row.me{align-items:flex-end}
.bubble{max-width:76%;padding:11px 13px;border-radius:5px 13px 13px 13px;background:white;border:1px solid #dce5f0;font-size:12px;line-height:1.6;white-space:pre-wrap;word-break:break-word}
.message-row.me .bubble{background:#2563eb;border-color:#2563eb;color:white;border-radius:13px 5px 13px 13px}
.caret{display:inline-block;width:2px;height:14px;background:#2563eb;margin-left:3px;vertical-align:-2px;animation:blink 1s step-end infinite}
@keyframes blink{50%{opacity:0}}
.run-progress{display:flex;align-items:center;gap:6px;color:#8392a7;font-size:10px;margin:0 0 14px}
.run-progress svg{color:#2563eb}
.composer{flex:none;min-height:74px;padding:12px 15px;display:flex;gap:8px;align-items:flex-end}
.composer textarea{min-height:38px;max-height:110px;flex:1;border:1px solid #e3eaf4;outline:0;border-radius:10px;background:#fff;padding:10px 12px;font-size:12px;resize:none;font-family:inherit;line-height:1.5}
.composer textarea:focus{border-color:#b9cdf0}
.send,.stop{height:38px;border:0;border-radius:8px;padding:0 14px;display:flex;align-items:center;gap:6px;font-size:12px;cursor:pointer;flex:none}
.send{background:#2563eb;color:white}
.send:hover{background:#1d4ed8}
.stop{background:#fdecec;color:#dc2626}
.stop:hover{background:#fbd5d5}
</style>
