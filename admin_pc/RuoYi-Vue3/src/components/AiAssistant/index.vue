<template>
  <div v-if="hasToken && !isLoginPage">
    <div class="ai-fab" :style="fabStyle" @mousedown="onDragStart" @click="onFabClick" title="AI 助手">
      <el-icon :size="22" color="#fff"><ChatDotRound /></el-icon>
    </div>

    <el-drawer v-model="open" :size="drawerSize" :with-header="false" :close-on-press-escape="true" class="ai-drawer">
      <div class="ai-panel">
        <div class="ai-header">
          <div class="ai-header-left">
            <div class="ai-avatar ai-avatar-bot">AI</div>
            <div>
              <div class="ai-title">后台助手</div>
              <div class="ai-sub"><span class="dot"></span>在线 · 豆包大模型</div>
            </div>
          </div>
          <div class="ai-header-actions">
            <el-tooltip content="新对话" placement="bottom">
              <el-icon @click="newSession" :size="16"><Plus /></el-icon>
            </el-tooltip>
            <el-dropdown trigger="click" @command="switchSession">
              <el-tooltip content="历史会话" placement="bottom">
                <el-icon :size="16"><Clock /></el-icon>
              </el-tooltip>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item v-for="s in sessions" :key="s.id" :command="s.id">
                    <div class="session-item">
                      <span>{{ s.title }}</span>
                      <el-icon class="session-del" @click.stop="deleteSession(s.id)"><Close /></el-icon>
                    </div>
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
            <el-tooltip content="导出对话" placement="bottom">
              <el-icon @click="exportMd" :size="16"><Download /></el-icon>
            </el-tooltip>
            <el-tooltip content="清空对话" placement="bottom">
              <el-icon @click="clearAll" :size="16"><Delete /></el-icon>
            </el-tooltip>
            <el-icon @click="open = false" :size="18"><Close /></el-icon>
          </div>
        </div>

        <div class="ai-body">
          <div class="ai-msg-list" ref="listRef">
            <div v-if="messages.length === 0" class="ai-empty">
              <div class="ai-empty-avatar">AI</div>
              <h3>你好，我是后台助手</h3>
              <p>业务数据统计、模块入口、操作指引、登录异常排查，问我就行。</p>
              <div class="ai-quick">
                <div v-for="q in quickQuestions" :key="q" class="ai-chip" @click="quickAsk(q)">
                  {{ q }}
                </div>
              </div>
            </div>

            <div v-for="(m, i) in messages" :key="i" class="ai-row" :class="m.role">
              <div class="ai-avatar" :class="m.role === 'user' ? 'ai-avatar-user' : 'ai-avatar-bot'">
                {{ m.role === 'user' ? '我' : 'AI' }}
              </div>
              <div class="ai-col">
                <div v-if="m.tool" class="ai-tool-card">
                  <el-icon :size="12"><Loading /></el-icon>
                  <span>{{ m.tool }}</span>
                </div>
                <div v-if="!m.content && m.role==='assistant'" class="ai-typing-dots"><span></span><span></span><span></span></div>
                <div v-else class="ai-bubble" v-html="renderMd(m.content)"></div>
                <div v-if="m.content" class="ai-actions">
                  <span @click="copyText(m.content)"
                    ><el-icon :size="12"><DocumentCopy /></el-icon>复制</span
                  >
                  <span v-if="m.role === 'assistant'" @click="speak(m.content)"
                    ><el-icon :size="12"><Microphone /></el-icon>朗读</span
                  >
                  <span v-if="m.role === 'assistant'" @click="retry(i)"
                    ><el-icon :size="12"><RefreshRight /></el-icon>重试</span
                  >
                  <span @click="removeMsg(i)"
                    ><el-icon :size="12"><Close /></el-icon>删除</span
                  >
                </div>
                <div v-if="m.route && ROUTE_WHITELIST.includes(m.route)" class="ai-go" @click="goRoute(m.route)">
                  <el-icon :size="13"><Position /></el-icon> 前往该页面
                </div>
              </div>
            </div>
          </div>

          <div class="ai-input">
            <el-input
              v-model="input"
              placeholder="输入问题，Enter 发送，Shift+Enter 换行"
              type="textarea"
              :autosize="{ minRows: 1, maxRows: 4 }"
              :disabled="loading"
              resize="none"
              @keydown.enter.exact.prevent="send()"
            />
            <button v-if="!loading" class="ai-send" @click="send()">
              <el-icon :size="16"><Promotion /></el-icon>
            </button>
            <button v-else class="ai-send ai-stop" @click="stop"><span class="stop-square"></span></button>
          </div>
          <div class="ai-foot">只读查询 · 不会修改业务数据</div>
        </div>
      </div>
    </el-drawer>
  </div>
</template>

<script setup name="AiAssistant">
/* global AbortController, TextDecoder, SpeechSynthesisUtterance */
import { ref, computed, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import {
  ChatDotRound,
  DocumentCopy,
  RefreshRight,
  Position,
  Download,
  Delete,
  Close,
  Loading,
  Promotion,
  Microphone,
  Plus,
  Clock
} from '@element-plus/icons-vue'
import { getToken } from '@/utils/auth'
import { ElMessage } from 'element-plus'

const router = useRouter()
const open = ref(false)
const isLoginPage = computed(
  () => router.currentRoute.value.path === '/login' || router.currentRoute.value.path.startsWith('/login')
)
const input = ref('')
const loading = ref(false)
const toolTip = ref('')
const sessions = ref([])
const currentId = ref(null)
const listRef = ref(null)
let abortCtrl = null

const messages = computed(() => {
  const s = sessions.value.find((x) => x.id === currentId.value)
  return s ? s.msgs : []
})

const HISTORY_KEY = 'ai-assistant-sessions-v2'
const quickQuestions = ['平台现在有多少岗位和候选人？', '企业入驻审核在哪里？', '最近有没有登录失败的异常？']

const drawerSize = computed(() => (window.innerWidth < 768 ? '100%' : '440px'))

// ---- 悬浮按钮拖拽 ----
const FAB_SIZE = 52
const POS_KEY = 'ai-assistant-fab-pos'
const fabPos = ref(null)
let dragState = null
const fabStyle = ref({})

function clamp(v, min, max) {
  return Math.max(min, Math.min(max, v))
}
function applyPos() {
  if (!fabPos.value) return
  fabStyle.value = { left: fabPos.value.x + 'px', top: fabPos.value.y + 'px', right: 'auto', bottom: 'auto' }
}
function onDragStart(e) {
  const rect = e.currentTarget.getBoundingClientRect()
  dragState = { startX: e.clientX, startY: e.clientY, baseLeft: rect.left, baseTop: rect.top, moved: false }
  window.addEventListener('mousemove', onDragMove)
  window.addEventListener('mouseup', onDragEnd)
}
function onDragMove(e) {
  if (!dragState) return
  const dx = e.clientX - dragState.startX
  const dy = e.clientY - dragState.startY
  if (Math.abs(dx) > 4 || Math.abs(dy) > 4) dragState.moved = true
  if (!dragState.moved) return
  const x = clamp(dragState.baseLeft + dx, 0, window.innerWidth - FAB_SIZE)
  const y = clamp(dragState.baseTop + dy, 0, window.innerHeight - FAB_SIZE)
  fabPos.value = { x, y }
  applyPos()
}
function onDragEnd() {
  window.removeEventListener('mousemove', onDragMove)
  window.removeEventListener('mouseup', onDragEnd)
  if (dragState && dragState.moved && fabPos.value) {
    localStorage.setItem(POS_KEY, JSON.stringify(fabPos.value))
  }
  dragState = null
}
function onFabClick() {
  if (dragState && dragState.moved) return
  open.value = true
}
// ---- 拖拽结束 ----

function hasToken() {
  return !!getToken()
}

function persistHistory() {
  try {
    const trimmed = sessions.value.slice(-10)
    localStorage.setItem(HISTORY_KEY, JSON.stringify(trimmed))
  } catch {
    /* ignore */
  }
}

function newSession() {
  const s = { id: Date.now(), title: '新对话', msgs: [] }
  sessions.value.unshift(s)
  currentId.value = s.id
  persistHistory()
}

function switchSession(id) {
  currentId.value = id
}

function deleteSession(id) {
  sessions.value = sessions.value.filter((x) => x.id !== id)
  if (currentId.value === id) {
    if (sessions.value.length) currentId.value = sessions.value[0].id
    else {
      const s = { id: Date.now(), title: '新对话', msgs: [] }
      sessions.value.push(s)
      currentId.value = s.id
    }
  }
  persistHistory()
}

function clearAll() {
  const s = sessions.value.find((x) => x.id === currentId.value)
  if (s) s.msgs = []
  persistHistory()
}

function stop() {
  if (abortCtrl) abortCtrl.abort()
  loading.value = false
  toolTip.value = ''
}

function quickAsk(q) {
  input.value = q
  send()
}

function copyText(text) {
  navigator.clipboard.writeText(text).then(() => ElMessage.success('已复制'))
}

function removeMsg(i) {
  // 删除该条及其后面紧邻的AI回复
  const m = messages.value[i]
  messages.value.splice(i, 1)
  if (m.role === 'user' && messages.value[i] && messages.value[i].role === 'assistant') {
    messages.value.splice(i, 1)
  }
  persistHistory()
}

function speak(text) {
  if (!('speechSynthesis' in window)) {
    ElMessage.warning('浏览器不支持语音朗读')
    return
  }
  window.speechSynthesis.cancel()
  const u = new SpeechSynthesisUtterance(text.replace(/[#*`>_\[\]()]/g, ''))
  u.lang = 'zh-CN'
  u.rate = 1.1
  window.speechSynthesis.speak(u)
}

function onKey(e) {
  // Alt+X 唤起/收起
  if (e.altKey && (e.key === 'x' || e.key === 'X')) {
    e.preventDefault()
    open.value = !open.value
  }
}

function retry(i) {
  const m = messages.value[i]
  if (!m || m.role !== 'assistant') return
  // 找到上一条 user 消息重发
  let j = i - 1
  while (j >= 0 && messages.value[j].role !== 'user') j--
  if (j < 0) return
  const q = messages.value[j].content
  messages.value.splice(j)
  send(q)
}

function exportMd() {
  let md = '# AI 助手对话\n\n'
  messages.value.forEach((m) => {
    md += `## ${m.role === 'user' ? '我' : '助手'}\n\n${m.content}\n\n`
  })
  const blob = new Blob([md], { type: 'text/markdown;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = 'ai-chat.md'
  a.click()
  URL.revokeObjectURL(a.href)
}

// Markdown 渲染（表格/标题/加粗/行内code/代码块/有序无序列表/链接）
function renderMd(src) {
  if (!src) return '<span class="ai-cursor"></span>'
  let s = src.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  // 代码块
  s = s.replace(/```(\w*)\n([\s\S]*?)```/g, '<pre><code>$2</code></pre>')
  // 表格
  s = s.replace(/^\|(.+)\|\n\|([\s:|-]+)\|\n((?:\|.+\|\n?)+)/gm, (m, head, sep, body) => {
    const cols = head
      .split('|')
      .map((c) => c.trim())
      .filter(Boolean)
    const rows = body
      .trim()
      .split('\n')
      .map((r) =>
        r
          .split('|')
          .map((c) => c.trim())
          .filter(Boolean)
      )
    let t = '<table><thead><tr>'
    cols.forEach((c) => (t += `<th>${c}</th>`))
    t += '</tr></thead><tbody>'
    rows.forEach((r) => {
      t += '<tr>'
      r.forEach((c) => (t += `<td>${c}</td>`))
      t += '</tr>'
    })
    t += '</tbody></table>'
    return t
  })
  // 标题
  s = s.replace(/^### (.*)$/gm, '<h4>$1</h4>')
  s = s.replace(/^## (.*)$/gm, '<h3>$1</h3>')
  // 粗体
  s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
  // 行内 code
  s = s.replace(/`([^`]+)`/g, '<code>$1</code>')
  // 链接
  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank">$1</a>')
  // 无序列表
  s = s.replace(/^[-•] (.*)$/gm, '<li>$1</li>')
  s = s.replace(/(?:<li>[\s\S]*?<\/li>)+/g, (m) => `<ul>${m}</ul>`)
  // 有序列表
  s = s.replace(/^\d+\. (.*)$/gm, '<li>$1</li>')
  // 换行
  s = s.replace(/\n/g, '<br/>')
  s += '<span class="ai-cursor"></span>'
  return s
}

async function send(preset) {
  const text = (preset || input.value).trim()
  if (!text || loading.value) return
  input.value = ''
  if (!currentId.value || !sessions.value.find((x) => x.id === currentId.value)) {
    newSession()
  }
  const s = sessions.value.find((x) => x.id === currentId.value)
  if (s.msgs.length === 0) s.title = text.slice(0, 12)
  s.msgs.push({ role: 'user', content: text })
  const aiMsg = { role: 'assistant', content: '', route: null, tool: '' }
  s.msgs.push(aiMsg)
  loading.value = true
  toolTip.value = ''
  await scrollBottom()
  try {
    const hist = s.msgs
      .slice(0, -1)
      .slice(-10)
      .map((m) => ({ role: m.role, content: m.content }))
    abortCtrl = new AbortController()
    const resp = await fetch('http://127.0.0.1:8080/ai/assistant/chat/stream', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + getToken() },
      body: JSON.stringify({ message: text, history: hist }),
      signal: abortCtrl.signal
    })
    const reader = resp.body.getReader()
    const decoder = new TextDecoder('utf-8')
    let buf = ''
    let expectTool = false
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      buf += decoder.decode(value, { stream: true })
      const lines = buf.split('\n')
      buf = lines.pop()
      for (const line of lines) {
        if (line.startsWith('event:')) {
          expectTool = line.trim().endsWith('tool')
          continue
        }
        if (!line.startsWith('data:')) continue
        const d = line.slice(5).trim()
        if (!d || d === '[DONE]') continue
        if (expectTool) {
          aiMsg.tool = d
          toolTip.value = d
          expectTool = false
        } else {
          if (aiMsg.tool) aiMsg.tool = ''
          aiMsg.content += d
          await scrollBottom()
        }
      }
    }
    const m = aiMsg.content.match(/\[\[route:([^\]]+)\]\]/)
    if (m) {
      aiMsg.route = m[1].trim()
      aiMsg.content = aiMsg.content.replace(/\[\[route:[^\]]+\]\]/, '').trim()
    }
    persistHistory()
  } catch (e) {
    if (e.name !== 'AbortError') {
      aiMsg.content = aiMsg.content || ('请求失败：' + (e.message || '网络错误') + '，点下方"重试"。')
    }
  } finally {
    loading.value = false
    toolTip.value = ''
    abortCtrl = null
    await scrollBottom()
    focusInput()
  }
}

function focusInput() {
  nextTick(() => {
    const el = document.querySelector('.ai-input textarea')
    if (el) el.focus()
  })
}

const ROUTE_WHITELIST = ['/dashboard','/company/company/list','/company/user','/business/list','/business/verify','/recruit/job','/recruit/candidate','/recruit/resume','/recruit/interview','/recruit/exam','/msg/template','/msg/record','/msg/channel','/msg/sent','/ai/provider-list','/ai/agent','/ai/quota','/system/role','/system/menu','/monitor/online','/monitor/job','/monitor/cache','/monitor/operlog','/monitor/logininfor','/content/advert','/content/question','/content/feedback']

function goRoute(path) {
  if (!ROUTE_WHITELIST.includes(path)) {
    ElMessage.warning('该页面路由不存在，请从左侧菜单进入')
    return
  }
  open.value = false
  router.push(path)
}

async function scrollBottom() {
  await nextTick()
  if (listRef.value) listRef.value.scrollTop = listRef.value.scrollHeight
}

onMounted(() => {
  window.addEventListener('keydown', onKey)
  try {
    const savedPos = JSON.parse(localStorage.getItem(POS_KEY))
    if (savedPos && typeof savedPos.x === 'number') {
      fabPos.value = savedPos
      applyPos()
    }
    const savedSessions = JSON.parse(localStorage.getItem(HISTORY_KEY))
    if (Array.isArray(savedSessions) && savedSessions.length) {
      sessions.value = savedSessions
      currentId.value = savedSessions[0].id
    } else {
      newSession()
    }
  } catch {
    /* ignore */
  }
})
onBeforeUnmount(() => {
  window.removeEventListener('mousemove', onDragMove)
  window.removeEventListener('mouseup', onDragEnd)
  window.removeEventListener('keydown', onKey)
  if ('speechSynthesis' in window) window.speechSynthesis.cancel()
})
</script>

<style scoped>
.session-item { display: flex; justify-content: space-between; align-items: center; width: 180px; }
.session-del { color: #999; cursor: pointer; }
.session-del:hover { color: #f56c6c; }
.ai-fab {
  position: fixed;
  right: 24px;
  bottom: 88px;
  width: 52px;
  height: 52px;
  border-radius: 50%;
  background: linear-gradient(135deg, #4f6ef7, #7c3aed);
  box-shadow: 0 6px 20px rgba(79, 110, 247, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: grab;
  z-index: 2000;
  user-select: none;
  transition: transform 0.2s;
}
.ai-fab:hover {
  transform: scale(1.08);
}
.ai-fab:active {
  cursor: grabbing;
}

.ai-panel {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: #f7f8fc;
  animation: slideIn 0.2s ease-out;
}
@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateX(20px);
  }
  to {
    opacity: 1;
    transform: none;
  }
}

.ai-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 18px;
  background: #fff;
  border-bottom: 1px solid #eef0f5;
}
.ai-header-left {
  display: flex;
  align-items: center;
  gap: 10px;
}
.ai-title {
  font-size: 15px;
  font-weight: 600;
  color: #1f2329;
}
.ai-sub {
  font-size: 11px;
  color: #909399;
  margin-top: 1px;
}
.ai-sub .dot {
  display: inline-block;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #22c55e;
  margin-right: 4px;
  vertical-align: middle;
}
.ai-header-actions {
  display: flex;
  gap: 14px;
  color: #909399;
  cursor: pointer;
}
.ai-header-actions .el-icon:hover {
  color: #4f6ef7;
}

.ai-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.ai-msg-list {
  flex: 1;
  overflow-y: auto;
  padding: 16px 16px 8px;
}

.ai-empty {
  text-align: center;
  padding: 30px 10px;
}
.ai-empty-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  margin: 0 auto 12px;
  background: linear-gradient(135deg, #4f6ef7, #7c3aed);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
}
.ai-empty h3 {
  margin: 0 0 6px;
  font-size: 16px;
  color: #1f2329;
}
.ai-empty p {
  color: #909399;
  font-size: 13px;
  margin: 0 0 16px;
}
.ai-quick {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  justify-content: center;
}
.ai-chip {
  font-size: 12px;
  color: #4f6ef7;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  padding: 6px 12px;
  cursor: pointer;
  transition: all 0.15s;
}
.ai-chip:hover {
  border-color: #4f6ef7;
  background: #eef2ff;
}

.ai-row {
  display: flex;
  margin-bottom: 16px;
  gap: 8px;
}
.ai-row.user {
  flex-direction: row-reverse;
}

.ai-avatar {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 600;
}
.ai-avatar-bot {
  background: linear-gradient(135deg, #4f6ef7, #7c3aed);
  color: #fff;
}
.ai-avatar-user {
  background: #e2e8f0;
  color: #475569;
}

.ai-col {
  max-width: 78%;
  display: flex;
  flex-direction: column;
}

.ai-bubble {
  padding: 9px 13px;
  border-radius: 12px;
  font-size: 13.5px;
  line-height: 1.65;
  word-break: break-word;
}
.ai-row.assistant .ai-bubble {
  background: #fff;
  color: #1f2329;
  border: 1px solid #eef0f5;
  border-top-left-radius: 4px;
}
.ai-row.user .ai-bubble {
  background: linear-gradient(135deg, #4f6ef7, #6366f1);
  color: #fff;
  border-top-right-radius: 4px;
}

.ai-tool-card {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 12px;
  color: #6366f1;
  background: #eef2ff;
  padding: 4px 10px;
  border-radius: 8px;
  margin-bottom: 6px;
  width: fit-content;
}

.ai-actions {
  display: flex;
  gap: 10px;
  margin-top: 4px;
  font-size: 11px;
  color: #b0b7c3;
}
.ai-actions span {
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 3px;
}
.ai-actions span:hover {
  color: #4f6ef7;
}

.ai-go {
  margin-top: 6px;
  font-size: 12.5px;
  color: #4f6ef7;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.ai-go:hover {
  text-decoration: underline;
}

.ai-typing {
  display: inline-flex;
  gap: 4px;
  align-items: center;
  background: #fff !important;
}
.ai-typing span {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #c0c4cc;
  animation: blink 1.2s infinite;
}
.ai-typing span:nth-child(2) {
  animation-delay: 0.2s;
}
.ai-typing span:nth-child(3) {
  animation-delay: 0.4s;
}
@keyframes blink {
  0%,
  80%,
  100% {
    opacity: 0.3;
  }
  40% {
    opacity: 1;
  }
}

.ai-typing-dots {
  display: inline-flex;
  gap: 4px;
  padding: 10px 14px;
  background: #fff;
  border: 1px solid #eef0f5;
  border-radius: 12px;
  border-top-left-radius: 4px;
}
.ai-typing-dots span {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #c0c4cc;
  animation: blink 1.2s infinite;
}
.ai-typing-dots span:nth-child(2) { animation-delay: 0.2s; }
.ai-typing-dots span:nth-child(3) { animation-delay: 0.4s; }

.ai-cursor {
  display: inline-block;
  width: 2px;
  height: 13px;
  background: #4f6ef7;
  vertical-align: middle;
  margin-left: 2px;
  animation: blink 1s infinite;
}

.ai-bubble :deep(pre) {
  background: #1e293b;
  color: #e2e8f0;
  padding: 10px;
  border-radius: 8px;
  overflow-x: auto;
  margin: 6px 0;
  font-size: 12px;
}
.ai-bubble :deep(code) {
  background: rgba(79, 110, 247, 0.1);
  color: #4f6ef7;
  padding: 1px 5px;
  border-radius: 4px;
  font-size: 12.5px;
}
.ai-bubble :deep(pre code) {
  background: transparent;
  color: inherit;
  padding: 0;
}
.ai-bubble :deep(ul) {
  margin: 4px 0;
  padding-left: 18px;
}
.ai-bubble :deep(table) {
  border-collapse: collapse;
  margin: 6px 0;
  width: 100%;
  font-size: 12.5px;
}
.ai-bubble :deep(th),
.ai-bubble :deep(td) {
  border: 1px solid #e2e8f0;
  padding: 5px 8px;
  text-align: left;
}
.ai-bubble :deep(th) {
  background: #f1f5f9;
}
.ai-bubble :deep(a) {
  color: #4f6ef7;
}
.ai-bubble :deep(h3),
.ai-bubble :deep(h4) {
  margin: 6px 0 3px;
}

.ai-input {
  display: flex;
  gap: 8px;
  align-items: flex-end;
  padding: 10px 14px;
  background: #fff;
  border-top: 1px solid #eef0f5;
}
.ai-send {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: none;
  cursor: pointer;
  background: linear-gradient(135deg, #4f6ef7, #7c3aed);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.ai-stop {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: none;
  cursor: pointer;
  background: #ef4444;
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.stop-square {
  width: 12px;
  height: 12px;
  background: #fff;
  border-radius: 2px;
}
.ai-foot {
  text-align: center;
  font-size: 10px;
  color: #c0c4cc;
  padding: 6px;
  background: #fff;
}
</style>
