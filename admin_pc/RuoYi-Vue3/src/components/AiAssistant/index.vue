<template>
  <div v-if="hasToken && !isLoginPage">
    <div class="ai-fab" :style="fabStyle" @mousedown="onDragStart" @click="onFabClick" title="AI 助手">
      <el-icon :size="22" color="#fff"><ChatDotRound /></el-icon>
    </div>

    <el-drawer v-model="open" :size="drawerSize" :with-header="false" :close-on-press-escape="true" class="ai-drawer">
      <div class="ai-panel" @click="onDocClick">
        <div class="ai-header">
          <div class="ai-header-left">
            <div class="ai-avatar ai-avatar-bot">AI</div>
            <div>
              <div class="ai-title">后台助手</div>
              <div class="ai-sub"><span class="dot"></span>{{ modelLabel }}</div>
            </div>
          </div>
          <div class="ai-header-actions">
            <el-tooltip content="新对话" placement="bottom">
              <el-icon @click="newSession" :size="16"><Plus /></el-icon>
            </el-tooltip>
            <div class="ai-menu-wrap">
              <span class="ai-icon-btn" title="历史会话" @click="toggleMenu('hist')">
                <el-icon :size="16"><Clock /></el-icon>
                <span v-if="sessionCount" class="ai-badge">{{ sessionCount }}</span>
              </span>
              <div v-if="histOpen" class="ai-menu">
                <div v-if="!sessions.length" class="ai-menu-empty">暂无历史会话</div>
                <div v-for="s in sessions" :key="s.id" class="ai-menu-item" @click="switchSession(s.id)">
                  <div class="session-item" :class="{ 'session-active': s.id === currentId }">
                    <div class="session-main">
                      <span class="session-title">{{ s.title || '新对话' }}</span>
                      <span class="session-meta">{{ formatTime(s.updatedAt || s.id) }} · {{ (s.msgs || []).length }} 条</span>
                    </div>
                    <el-icon class="session-del" @click.stop="deleteSession(s.id)"><Close /></el-icon>
                  </div>
                </div>
              </div>
            </div>
            <div class="ai-menu-wrap">
              <span class="ai-icon-btn" title="导出对话" @click="toggleMenu('exp')">
                <el-icon :size="16"><Download /></el-icon>
              </span>
              <div v-if="expOpen" class="ai-menu">
                <div class="ai-menu-item" @click="onExport('current')">导出当前对话</div>
                <div class="ai-menu-item" @click="onExport('all')">导出全部历史</div>
              </div>
            </div>
            <el-tooltip content="导入知识库文档或文件夹" placement="bottom">
              <el-icon @click="kbDialogVisible = true" :size="16"><UploadFilled /></el-icon>
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
              <p>查业务数据、找功能入口、起草改动；点左下「+」上传附件，可提取题库、录入企业信息。</p>
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
                <div v-if="!m.content && m.role === 'assistant' && loading && i === messages.length - 1" class="ai-typing-dots"><span></span><span></span><span></span></div>
                <div v-else-if="!m.content && m.role === 'assistant'" class="ai-bubble ai-bubble-empty">（这条回复没有内容）</div>
                <div v-else class="ai-bubble" v-html="renderMd(m.content)"></div>
                <div v-if="m.pending && m.pending.length" class="ai-pending">
                  <div v-for="c in m.pending" :key="c.id" class="ai-pending-card">
                    <div class="ai-pending-head">
                      <span class="ai-pending-title">{{ c.title }}</span>
                      <span class="ai-pending-tag" :class="'kind-' + c.kind">{{ kindLabel(c.kind) }}</span>
                    </div>
                    <div class="ai-pending-sum">{{ c.summary }}</div>
                    <div v-if="c.result" class="ai-pending-res">{{ c.result }}</div>
                    <div class="ai-pending-ops">
                      <el-button
                        v-if="!c.done"
                        size="small"
                        type="primary"
                        :loading="c.loading"
                        @click="applyPending(m, c)"
                        >确认执行</el-button
                      >
                      <el-button v-if="!c.done" size="small" :disabled="c.loading" @click="discardPending(m, c)"
                        >取消</el-button
                      >
                      <span v-if="c.done" class="ai-pending-done">已提交</span>
                    </div>
                  </div>
                </div>
                <div v-if="m.content" class="ai-actions">
                  <span @click="copyText(m.content)"
                    ><el-icon :size="12"><DocumentCopy /></el-icon>复制</span
                  >
                  <span v-if="m.role === 'assistant'" @click="speak(m.content)" :class="{ 'speaking-on': speaking && !loading }"
                    ><el-icon :size="12"><Microphone /></el-icon>{{ speaking && !loading ? '停止朗读' : '朗读' }}</span
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

          <div class="ai-composer">
            <el-input
              v-model="input"
              class="ai-composer-text"
              placeholder="输入问题，Enter 发送，Shift+Enter 换行"
              type="textarea"
              :autosize="{ minRows: 1, maxRows: 4 }"
              :disabled="loading"
              resize="none"
              @keydown.enter.exact.prevent="send()"
            />
            <div class="ai-composer-bar">
              <el-popover v-model:visible="attachMenuVisible" placement="top-start" :width="150" trigger="click">
                <template #reference>
                  <button class="ai-plus" :disabled="loading" title="添加附件">+</button>
                </template>
                <div class="attach-menu">
                  <div class="attach-menu-item" @click="pickChatFiles">选择文件</div>
                  <div class="attach-menu-item" @click="pickChatFolder">选择文件夹</div>
                  <div class="attach-menu-item" @click="attachMenuVisible = false; kbDialogVisible = true">导入知识库</div>
                </div>
              </el-popover>
              <div class="ai-attach-chips">
                <span v-for="(a, i) in chatAttachments" :key="a.name + i" class="attach-chip">
                  <el-icon :size="12"><Document /></el-icon>
                  <span class="chip-name">{{ a.name }}</span>
                  <el-icon class="chip-del" @click="removeChatAttachment(i)"><Close /></el-icon>
                </span>
                <span v-if="attachParsing" class="attach-chip attach-parsing">解析中…</span>
              </div>
              <button v-if="!loading" class="ai-composer-send" @click="send()">
                <el-icon :size="15"><Top /></el-icon>
              </button>
              <button v-else class="ai-composer-send ai-stop" @click="stop"><span class="stop-square"></span></button>
            </div>
          </div>
          <div class="ai-foot">查数据直接答 · 写题库需你点卡片确认</div>
        </div>
      </div>
    </el-drawer>

    <el-dialog v-model="kbDialogVisible" title="导入知识库" width="440px" append-to-body :close-on-click-modal="false">
      <div class="kb-actions">
        <el-button size="small" @click="pickKbFiles">选择文件</el-button>
        <el-button size="small" @click="pickKbFolder">选择文件夹</el-button>
        <el-button size="small" text :disabled="!kbFiles.length" @click="clearKbFiles">清空</el-button>
      </div>
      <div class="kb-tip">支持 txt / md / csv / json / pdf / docx / xlsx 等，单文件不超过 10MB</div>
      <div v-if="kbFiles.length" class="kb-list">
        <div v-for="(f, i) in kbFiles" :key="f.name + '_' + f.size" class="kb-item">
          <span class="kb-name">{{ f.name }}</span>
          <span class="kb-size">{{ fmtSize(f.size) }}</span>
          <el-icon class="kb-del" @click="removeKbFile(i)"><Close /></el-icon>
        </div>
      </div>
      <div v-else class="kb-empty">尚未选择文件</div>
      <div class="kb-cat">
        <span>分类</span>
        <el-input v-model="kbCategory" size="small" placeholder="操作手册" style="width: 200px" />
      </div>
      <template #footer>
        <el-button size="small" @click="kbDialogVisible = false">取消</el-button>
        <el-button size="small" type="primary" :loading="kbUploading" @click="submitKb">开始导入</el-button>
      </template>
    </el-dialog>

    <input ref="kbFileInput" type="file" multiple hidden
      accept=".txt,.md,.markdown,.csv,.json,.xml,.yml,.yaml,.sql,.log,.java,.py,.js,.ts,.html,.css,.pdf,.docx,.xlsx"
      @change="onKbPick" />
    <input ref="kbDirInput" type="file" webkitdirectory multiple hidden @change="onKbPick" />
    <input ref="chatFileInput" type="file" multiple hidden
      accept=".txt,.md,.markdown,.csv,.json,.xml,.yml,.yaml,.sql,.log,.java,.py,.js,.ts,.html,.css,.pdf,.docx,.xlsx"
      @change="onChatPick" />
    <input ref="chatDirInput" type="file" webkitdirectory multiple hidden @change="onChatPick" />
  </div>
</template>

<script setup name="AiAssistant">
/* global AbortController, TextDecoder, SpeechSynthesisUtterance */
import { ref, computed, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  ChatDotRound,
  DocumentCopy,
  Document,
  RefreshRight,
  Position,
  Download,
  Delete,
  Close,
  Loading,
  Microphone,
  Plus,
  Clock,
  Top,
  UploadFilled
} from '@element-plus/icons-vue'
import { getToken } from '@/utils/auth'
import { ElMessage } from 'element-plus'

const router = useRouter()
/** 与全局请求一致：dev 为 /dev-api，生产为 /prod-api */
const BASE_API = import.meta.env.VITE_APP_BASE_API || '/prod-api'
const open = ref(false)
const isLoginPage = computed(
  () => router.currentRoute.value.path === '/login' || router.currentRoute.value.path.startsWith('/login')
)
const input = ref('')
const loading = ref(false)
const toolTip = ref('')
const sessions = ref([])
const currentId = ref(null)
const histOpen = ref(false)
const expOpen = ref(false)
function toggleMenu(which) {
  if (which === 'hist') {
    histOpen.value = !histOpen.value
    expOpen.value = false
  } else {
    expOpen.value = !expOpen.value
    histOpen.value = false
  }
}
// 点击面板其它区域时收起历史/导出菜单。
// 注意：el-drawer 根节点带 @click.stop，抽屉内的点击不会冒泡到 document，因此监听挂在 .ai-panel 上
function onDocClick(e) {
  if (e.target && e.target.closest && e.target.closest('.ai-menu-wrap')) return
  histOpen.value = false
  expOpen.value = false
}
const listRef = ref(null)
const kbDialogVisible = ref(false)
const kbFiles = ref([])
const kbCategory = ref('操作手册')
const kbUploading = ref(false)
const kbFileInput = ref(null)
const kbDirInput = ref(null)
const chatAttachments = ref([])
const attachParsing = ref(false)
const attachMenuVisible = ref(false)
const chatFileInput = ref(null)
const chatDirInput = ref(null)
const KB_EXT = ['txt', 'md', 'markdown', 'csv', 'json', 'xml', 'yml', 'yaml', 'sql', 'log',
  'java', 'py', 'js', 'ts', 'html', 'css', 'pdf', 'docx', 'xlsx']
let abortCtrl = null

const messages = computed(() => {
  const s = sessions.value.find((x) => x.id === currentId.value)
  return s ? s.msgs : []
})
/** 仅统计有消息的会话，空会话不显示角标 */
const sessionCount = computed(() => sessions.value.filter((x) => (x.msgs || []).length).length)

const HISTORY_KEY = 'ai-assistant-sessions-v2'
const quickQuestions = ['平台现在有多少岗位和候选人？', '待审核的企业和岗位有哪些？', '最近有没有登录失败的异常？', 'Offer 即将到期的有几个？', 'AI 调用量今天用了多少？', '把附件里的题目提取到题库', '把附件里的公司信息录入系统']

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

function formatTime(ts) {
  if (!ts) return ''
  const d = new Date(ts)
  const now = new Date()
  const pad = (n) => String(n).padStart(2, '0')
  if (d.toDateString() === now.toDateString()) return `${pad(d.getHours())}:${pad(d.getMinutes())}`
  if (d.getFullYear() === now.getFullYear()) return `${d.getMonth() + 1}月${d.getDate()}日`
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

function persistHistory() {
  try {
    // 最新会话在数组头部，保留最近 20 个非空会话；只存必要字段，降低配额压力
    const trimmed = sessions.value
      .filter((s) => (s.msgs || []).length)
      .slice(0, 20)
      .map((s) => ({
      id: s.id,
      title: s.title || '新对话',
      updatedAt: s.updatedAt || s.id,
      msgs: (s.msgs || []).map((m) => ({
        role: m.role,
        content: m.content || '',
        tool: m.tool || '',
        route: m.route || '',
        pending: m.pending || []
      }))
    }))
    localStorage.setItem(HISTORY_KEY, JSON.stringify(trimmed))
  } catch {
    /* ignore */
  }
}

const modelLabel = ref('在线 · 读取中…')
async function loadProviderInfo() {
  const token = getToken()
  if (!token) return
  try {
    const resp = await fetch(`${BASE_API}/ai/assistant/provider`, {
      headers: { Authorization: 'Bearer ' + token }
    })
    const j = await resp.json()
    const d = j && j.data
    if (d && d.enabled) modelLabel.value = '在线 · ' + (d.model || d.name || '模型')
    else modelLabel.value = '未启用模型'
  } catch {
    modelLabel.value = '在线'
  }
}
watch(open, (v) => {
  if (v) loadProviderInfo()
})

function newSession() {
  const cur = sessions.value.find((x) => x.id === currentId.value)
  if (cur && (!cur.msgs || cur.msgs.length === 0)) {
    cur.updatedAt = Date.now()
    currentId.value = cur.id
    persistHistory()
    return
  }
  const s = { id: Date.now(), title: '新对话', updatedAt: Date.now(), msgs: [] }
  sessions.value.unshift(s)
  currentId.value = s.id
  persistHistory()
}

function switchSession(id) {
  currentId.value = id
  histOpen.value = false
}

function deleteSession(id) {
  sessions.value = sessions.value.filter((x) => x.id !== id)
  if (currentId.value === id) {
    if (sessions.value.length) currentId.value = sessions.value[0].id
    else {
      const s = { id: Date.now(), title: '新对话', updatedAt: Date.now(), msgs: [] }
      sessions.value.push(s)
      currentId.value = s.id
    }
  }
  persistHistory()
}

function clearAll() {
  const s = sessions.value.find((x) => x.id === currentId.value)
  if (s) {
    s.msgs = []
    s.updatedAt = Date.now()
  }
  persistHistory()
}

function pickKbFiles() {
  if (kbFileInput.value) kbFileInput.value.click()
}

function pickKbFolder() {
  if (kbDirInput.value) kbDirInput.value.click()
}

function clearKbFiles() {
  kbFiles.value = []
}

function removeKbFile(i) {
  kbFiles.value.splice(i, 1)
}

/** 多选文件或整个文件夹：过滤格式与大小，按 name+size 去重 */
function onKbPick(e) {
  const picked = Array.from(e.target.files || [])
  let rejected = 0
  picked.forEach((f) => {
    const ext = (f.name.split('.').pop() || '').toLowerCase()
    if (!KB_EXT.includes(ext) || f.size > 10 * 1024 * 1024) {
      rejected++
      return
    }
    if (kbFiles.value.some((x) => x.name === f.name && x.size === f.size)) return
    kbFiles.value.push(f)
  })
  if (rejected) ElMessage.warning(`已过滤 ${rejected} 个不支持或超过 10MB 的文件`)
  e.target.value = ''
}

function fmtSize(n) {
  return n >= 1048576 ? (n / 1048576).toFixed(1) + ' MB' : Math.max(1, Math.round(n / 1024)) + ' KB'
}

async function submitKb() {
  if (!kbFiles.value.length) {
    ElMessage.warning('请先选择文件或文件夹')
    return
  }
  kbUploading.value = true
  try {
    const fd = new FormData()
    kbFiles.value.forEach((f) => fd.append('files', f, f.webkitRelativePath || f.name))
    const resp = await fetch(`${BASE_API}/ai/kb/upload-batch?category=${encodeURIComponent(kbCategory.value || '未分类')}`, {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + getToken() },
      body: fd
    })
    const j = await resp.json()
    if (j.code !== 200) throw new Error(j.msg || '导入失败')
    const d = j.data || {}
    const failedTip = d.failed ? `，失败 ${d.failed} 个` : ''
    ElMessage.success(`导入完成：${d.success || 0} 个文件、${d.chunks || 0} 段${failedTip}`)
    const firstError = (d.files || []).find((x) => x.error)
    if (firstError) ElMessage.warning(`${firstError.name}：${firstError.error}`)
    kbFiles.value = []
    kbDialogVisible.value = false
  } catch (err) {
    ElMessage.error('导入失败：' + (err.message || '网络异常'))
  } finally {
    kbUploading.value = false
  }
}

/** 输入框「+」：选择随本次对话使用的附件 */
function pickChatFiles() {
  attachMenuVisible.value = false
  if (chatFileInput.value) chatFileInput.value.click()
}

function pickChatFolder() {
  attachMenuVisible.value = false
  if (chatDirInput.value) chatDirInput.value.click()
}

function removeChatAttachment(i) {
  chatAttachments.value.splice(i, 1)
}

/** 选中文件后交给后端解析成文本，仅用于本次对话，不写入知识库 */
async function onChatPick(e) {
  const picked = Array.from(e.target.files || [])
  e.target.value = ''
  if (!picked.length) return
  const valid = picked.filter((f) => {
    const ext = (f.name.split('.').pop() || '').toLowerCase()
    return KB_EXT.includes(ext) && f.size <= 10 * 1024 * 1024
  })
  if (!valid.length) {
    ElMessage.warning('没有可解析的文件（格式不支持或超过 10MB）')
    return
  }
  if (valid.length < picked.length) {
    ElMessage.warning(`已过滤 ${picked.length - valid.length} 个不支持或超限的文件`)
  }
  attachParsing.value = true
  try {
    const fd = new FormData()
    valid.forEach((f) => fd.append('files', f, f.webkitRelativePath || f.name))
    const resp = await fetch(`${BASE_API}/ai/kb/parse`, {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + getToken() },
      body: fd
    })
    const j = await resp.json()
    if (j.code !== 200) throw new Error(j.msg || '解析失败')
    const list = (j.data && j.data.files) || []
    list.forEach((x) => {
      if (x.error) {
        ElMessage.warning(`${x.name}：${x.error}`)
        return
      }
      if (chatAttachments.value.some((a) => a.name === x.name)) return
      chatAttachments.value.push({ name: x.name, text: x.text })
    })
  } catch (err) {
    ElMessage.error('附件解析失败：' + (err.message || '网络异常'))
  } finally {
    attachParsing.value = false
  }
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

const speaking = ref(false)
function speak(text) {
  if (!('speechSynthesis' in window)) {
    ElMessage.warning('浏览器不支持语音朗读')
    return
  }
  if (speaking.value) {
    window.speechSynthesis.cancel()
    speaking.value = false
    return
  }
  window.speechSynthesis.cancel()
  const u = new SpeechSynthesisUtterance(text.replace(/[#*`>_\[\]()]/g, ''))
  u.lang = 'zh-CN'
  u.rate = 1.1
  u.onend = () => (speaking.value = false)
  u.onerror = () => (speaking.value = false)
  speaking.value = true
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

function buildSessionMd(s, roleLevel = '##') {
  let md = `# ${s.title || 'AI 助手对话'}\n\n> 会话时间：${new Date(s.updatedAt || s.id).toLocaleString()} · 导出时间：${new Date().toLocaleString()}\n\n`
  ;(s.msgs || []).forEach((m) => {
    md += `${roleLevel} ${m.role === 'user' ? '我' : '助手'}\n\n${m.content || '（无文本）'}\n\n`
    ;(m.pending || []).forEach((c) => {
      md += `- 待确认「${c.title || ''}」：${c.summary || ''}${c.result ? '｜结果：' + c.result : ''}\n`
    })
    if (m.pending && m.pending.length) md += '\n'
  })
  return md
}

function downloadMd(name, content) {
  const blob = new Blob([content], { type: 'text/markdown;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = name
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 3000)
  ElMessage.success(`已导出 ${name}`)
}

function timeStamp() {
  const d = new Date()
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}`
}

function safeName(title) {
  return (title || '未命名').replace(/[\\/:*?"<>|]/g, '_').slice(0, 30)
}

function exportCurrent() {
  const s = sessions.value.find((x) => x.id === currentId.value)
  if (!s || !(s.msgs || []).length) {
    ElMessage.warning('当前会话没有可导出的内容')
    return
  }
  downloadMd(`AI助手对话-${safeName(s.title)}-${timeStamp()}.md`, buildSessionMd(s))
}

function exportAll() {
  const valid = sessions.value.filter((s) => (s.msgs || []).length)
  if (!valid.length) {
    ElMessage.warning('还没有可导出的历史会话')
    return
  }
  let md = `# 后台助手会话导出\n\n> 共 ${valid.length} 个会话 · 导出时间：${new Date().toLocaleString()}\n\n`
  valid.forEach((s, i) => {
    md += `---\n\n## ${i + 1}. ${s.title || '会话'}\n\n` + buildSessionMd(s, '###').replace(/^# .+\n\n/, '')
  })
  downloadMd(`AI助手会话导出-${timeStamp()}.md`, md)
}

function onExport(cmd) {
  expOpen.value = false
  if (cmd === 'all') exportAll()
  else exportCurrent()
}

// Markdown 渲染（表格/标题/加粗/行内code/代码块/有序无序列表/链接）
function renderMd(src) {
  if (!src) return '<span class="ai-cursor"></span>'
  src = String(src)
    .replace(/<tool_call[\s\S]*?<\/tool_call>/gi, '')
    .replace(/<[^>]*(?:invoke|parameter|calls)[^>]*>/gi, '')
    .replace(/\n{3,}/g, '\n\n')
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
  const toList = (tag, mark, m) => {
    const re = new RegExp(`<${mark}>[\\s\\S]*?</${mark}>`, 'g')
    const items = (m.match(re) || [])
      .map((x) => `<li>${x.replace(new RegExp(`</?${mark}>`, 'g'), '')}</li>`)
      .join('')
    return `<${tag}>${items}</${tag}>`
  }
  // 有序列表（先处理，用临时标记避免和无序列表混淆）
  s = s.replace(/^\d+\. (.*)$/gm, '<olist>$1</olist>')
  s = s.replace(/(?:<olist>[\s\S]*?<\/olist>\n?)+/g, (m) => toList('ol', 'olist', m))
  // 无序列表
  s = s.replace(/^[-•] (.*)$/gm, '<ulist>$1</ulist>')
  s = s.replace(/(?:<ulist>[\s\S]*?<\/ulist>\n?)+/g, (m) => toList('ul', 'ulist', m))
  // 换行：块级元素前后不重复产生 <br/>，连续空行只保留一个段间距
  s = s.replace(/(<\/(?:h3|h4|ul|ol|table|pre)>)\n+/g, '$1')
  s = s.replace(/\n+(?=<(?:h3|h4|ul|ol|table|pre)>)/g, '')
  s = s.replace(/\n{2,}/g, '<br/><br/>')
  s = s.replace(/\n/g, '<br/>')
  s += '<span class="ai-cursor"></span>'
  return s
}

async function send(preset) {
  const text = (preset || input.value).trim()
  if (!text) { ElMessage.warning('请输入问题'); return }
  if (loading.value) return
  input.value = ''
  if (!currentId.value || !sessions.value.find((x) => x.id === currentId.value)) {
    newSession()
  }
  const s = sessions.value.find((x) => x.id === currentId.value)
  if (s.msgs.length === 0) s.title = text.length > 18 ? text.slice(0, 18) + '…' : text
  s.updatedAt = Date.now()
  s.msgs.push({ role: 'user', content: text })
  persistHistory()
  const aiMsg = { role: 'assistant', content: '', route: null, tool: '', pending: [] }
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
    const resp = await fetch(`${BASE_API}/ai/assistant/chat/stream`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + getToken() },
      body: JSON.stringify({
        message: text,
        history: hist,
        attachments: chatAttachments.value.map((a) => ({ name: a.name, text: a.text }))
      }),
      signal: abortCtrl.signal
    })
    const reader = resp.body.getReader()
    const decoder = new TextDecoder('utf-8')
    let buf = ''
    let expectTool = false
    let expectAnswer = false
    let expectPending = false
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      buf += decoder.decode(value, { stream: true })
      const lines = buf.split('\n')
      buf = lines.pop()
      for (const line of lines) {
        if (line.startsWith('event:')) {
          const evName = line.slice(6).trim()
          expectTool = evName === 'tool'
          expectAnswer = evName === 'answer'
          expectPending = evName === 'pending'
          continue
        }
        if (!line.startsWith('data:')) continue
        const d = line.slice(5).trim()
        if (!d || d === '[DONE]') continue
        if (expectPending) {
          try {
            aiMsg.pending = JSON.parse(d)
          } catch (e) {
            /* 解析失败忽略，不影响正文 */
          }
          expectPending = false
          continue
        }
        if (expectAnswer) {
          try {
            aiMsg.content += JSON.parse(d).text || ''
          } catch (e) {
            /* 解析失败忽略 */
          }
          expectAnswer = false
          await scrollBottom()
          continue
        }
        if (expectTool) {
          aiMsg.tool = d
          toolTip.value = d
          expectTool = false
        } else {
          if (aiMsg.tool) aiMsg.tool = ''
          let seg = d
          try {
            const j = JSON.parse(d)
            if (typeof j === 'string') seg = j
            else if (j && j.error) seg = '（' + j.error + '）'
            else seg = ''
          } catch (e) {
            /* 非 JSON 的旧格式按原文追加 */
          }
          aiMsg.content += seg
          await scrollBottom()
        }
      }
    }
    chatAttachments.value = []
    const m = aiMsg.content.match(/\[\[route:([^\]]+)\]\]/)
    if (m) {
      aiMsg.route = m[1].trim()
      aiMsg.content = aiMsg.content.replace(/\[\[route:[^\]]+\]\]/, '').trim()
    }
    if (!aiMsg.content && !(aiMsg.pending || []).length) {
      aiMsg.content = '（未收到模型回复：请检查「模型配置」中是否已启用模型，或稍后重试。）'
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

function kindLabel(kind) {
  if (kind === 'create') return '建题'
  if (kind === 'classify') return '改分类/题型'
  if (kind === 'update') return '修改题目'
  if (kind === 'delete') return '删除题目'
  if (kind === 'undo') return '撤销批次'
  if (kind === 'create_companies') return '录入企业'
  if (kind === 'create_positions') return '录入岗位'
  return '待确认'
}

/** 用户点"确认执行"：真正落库，权限由后端 content:question:add 校验。 */
async function applyPending(msg, card) {
  if (card.loading || card.done) return
  card.loading = true
  try {
    const resp = await fetch(`${BASE_API}/ai/assistant/pending/apply`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + getToken() },
      body: JSON.stringify({ id: card.id })
    })
    const payload = await resp.json()
    if (!payload || payload.code !== 200) {
      card.result = '执行失败：' + ((payload && payload.msg) || '接口异常')
      return
    }
    const d = payload.data || {}
    card.done = true
    if (d.kind === 'create') {
      card.result = `已入库 ${d.inserted} 题${d.failed ? '，失败 ' + d.failed + ' 题' : ''}，批次 #${d.batchId}`
    } else if (d.kind === 'classify') {
      card.result = `已更新 ${d.updated} 题`
    } else if (d.kind === 'update') {
      card.result = `已修改 ${d.updated} 题${d.skipped ? '，跳过 ' + d.skipped + ' 题' : ''}`
    } else if (d.kind === 'delete') {
      card.result = `已删除 ${d.deleted || 0} 题${d.referenced ? '，被引用保留 ' + d.referenced + ' 题' : ''}${d.missing ? '，已不存在 ' + d.missing + ' 题' : ''}`
    } else if (d.kind === 'create_companies') {
      const skipped = Array.isArray(d.skipped) ? d.skipped.length : 0
      const errors = Array.isArray(d.errors) ? d.errors.length : 0
      card.result = `已录入 ${d.inserted || 0} 家企业${skipped ? '，跳过同名 ' + skipped + ' 家' : ''}${errors ? '，失败 ' + errors + ' 家' : ''}`
    } else if (d.kind === 'create_positions') {
      const skipped = Array.isArray(d.skipped) ? d.skipped.length : 0
      const errors = Array.isArray(d.errors) ? d.errors.length : 0
      card.result = `已创建 ${d.inserted || 0} 个岗位（未上架）${skipped ? '，跳过已存在 ' + skipped + ' 个' : ''}${errors ? '，失败 ' + errors + ' 个：' + (d.errors[0] || '') : ''}`
    } else if (d.kind === 'undo') {
      card.result = `已撤销：删除 ${d.deleted || 0} 题${d.skipped ? '，保留 ' + d.skipped + ' 题' : ''}`
    } else {
      card.result = '已提交'
    }
  } catch (e) {
    card.result = '请求失败：' + (e.message || '网络错误')
  } finally {
    card.loading = false
  }
}

/** 用户点"取消"：作废草稿，不落库。 */
async function discardPending(msg, card) {
  if (card.loading) return
  try {
    await fetch(`${BASE_API}/ai/assistant/pending/discard`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + getToken() },
      body: JSON.stringify({ id: card.id })
    })
  } catch (e) {
    /* 取消失败不影响界面状态 */
  }
  card.done = true
  card.result = '已取消，未写入'
}

function focusInput() {
  nextTick(() => {
    const el = document.querySelector('.ai-composer textarea')
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
  loadProviderInfo()
  try {
    const savedPos = JSON.parse(localStorage.getItem(POS_KEY))
    if (savedPos && typeof savedPos.x === 'number') {
      fabPos.value = savedPos
      applyPos()
    }
    const savedSessions = JSON.parse(localStorage.getItem(HISTORY_KEY))
    const valid = Array.isArray(savedSessions)
      ? savedSessions
          .filter((s) => s && s.id && Array.isArray(s.msgs) && s.msgs.length > 0)
          .map((s) => ({
            id: s.id,
            title: s.title || '新对话',
            updatedAt: s.updatedAt || s.id,
            msgs: (Array.isArray(s.msgs) ? s.msgs : []).filter(
              (m) => m && (m.role === 'user' || m.content || (m.pending && m.pending.length))
            )
          }))
      : []
    if (valid.length) {
      sessions.value = valid.slice(0, 20)
      currentId.value = valid[0].id
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

.kb-actions {
  display: flex;
  gap: 8px;
}
.kb-tip {
  margin: 8px 0 6px;
  font-size: 12px;
  color: #8a8f99;
}
.kb-list {
  max-height: 200px;
  overflow-y: auto;
  border: 1px solid #eef0f5;
  border-radius: 8px;
}
.kb-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 10px;
  font-size: 12.5px;
  border-bottom: 1px solid #f4f5f7;
}
.kb-item:last-child {
  border-bottom: none;
}
.kb-name {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.kb-size {
  font-size: 12px;
  color: #8a8f99;
}
.kb-del {
  color: #c0c4cc;
  cursor: pointer;
}
.kb-del:hover {
  color: #f56c6c;
}
.kb-empty {
  padding: 20px;
  text-align: center;
  font-size: 12.5px;
  color: #a8adb8;
  border: 1px dashed #e5e7eb;
  border-radius: 8px;
}
.kb-cat {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 12px;
  font-size: 12.5px;
  color: #4b5563;
}
.ai-bubble {
  padding: 9px 13px;
  border-radius: 12px;
  font-size: 13.5px;
  line-height: 1.65;
  word-break: break-word;
}
.ai-bubble :deep(h3),
.ai-bubble :deep(h4) {
  margin: 10px 0 4px;
  font-size: 13.5px;
  line-height: 1.5;
  font-weight: 600;
  color: #1f2329;
}
.ai-bubble :deep(ul),
.ai-bubble :deep(ol) {
  margin: 4px 0 6px;
  padding-left: 18px;
}
.ai-bubble :deep(li) {
  margin: 1px 0;
  line-height: 1.6;
}
.ai-bubble :deep(table) {
  width: 100%;
  margin: 6px 0;
  border-collapse: collapse;
  font-size: 12.5px;
}
.ai-bubble :deep(table th),
.ai-bubble :deep(table td) {
  padding: 4px 8px;
  border: 1px solid #e5e7eb;
  text-align: left;
}
.ai-bubble :deep(table th) {
  background: #f7f8fa;
  font-weight: 600;
}
.ai-bubble :deep(pre) {
  margin: 6px 0;
  padding: 8px 10px;
  overflow-x: auto;
  background: #f6f7f9;
  border-radius: 6px;
  font-size: 12px;
  line-height: 1.5;
}
.ai-bubble :deep(code) {
  font-family: ui-monospace, Menlo, Consolas, monospace;
  font-size: 12.5px;
}
.ai-bubble :deep(a) {
  color: #3b82f6;
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
.ai-actions span.speaking-on {
  color: #ef4444;
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

.ai-composer {
  margin: 0 14px;
  padding: 8px 10px 8px 12px;
  background: #fff;
  border: 1px solid #e3e6ec;
  border-radius: 14px;
  transition: border-color 0.18s, box-shadow 0.18s;
}
.ai-composer:focus-within {
  border-color: #4f6ef7;
  box-shadow: 0 0 0 3px rgba(79, 110, 247, 0.08);
}
.ai-composer-text .el-textarea__inner {
  padding: 0;
  border: none;
  box-shadow: none;
  font-size: 13.5px;
  line-height: 1.6;
  background: transparent;
  resize: none;
}
.ai-composer-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 6px;
}
.ai-plus {
  width: 24px;
  height: 24px;
  padding: 0;
  border: 1px solid #e3e6ec;
  border-radius: 50%;
  background: #fff;
  color: #5c6472;
  font-size: 16px;
  line-height: 1;
  cursor: pointer;
  flex-shrink: 0;
}
.ai-plus:hover:not(:disabled) {
  border-color: #4f6ef7;
  color: #4f6ef7;
}
.ai-plus:disabled {
  color: #c0c4cc;
  cursor: not-allowed;
}
.ai-attach-chips {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.attach-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  max-width: 190px;
  padding: 2px 8px;
  border-radius: 10px;
  background: #eff3ff;
  color: #3b5bdb;
  font-size: 12px;
}
.attach-chip .chip-name {
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.attach-chip .chip-del {
  cursor: pointer;
  color: #8fa3e8;
}
.attach-chip .chip-del:hover {
  color: #ef4444;
}
.attach-parsing {
  color: #8a8f99;
  background: #f5f6f8;
}
.ai-composer-send {
  width: 30px;
  height: 30px;
  padding: 0;
  border: none;
  border-radius: 50%;
  background: #2563eb;
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
}
.ai-composer-send:hover {
  background: #1d4ed8;
}
.ai-composer-send.ai-stop {
  background: #ef4444;
}
.attach-menu {
  padding: 4px 0;
}
.attach-menu-item {
  padding: 8px 14px;
  font-size: 13px;
  color: #1f2329;
  cursor: pointer;
}
.attach-menu-item:hover {
  background: #f4f6fb;
  color: #4f6ef7;
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

/* 待确认动作卡片：写操作必须在这里点确认才落库 */
.ai-pending {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: 8px;
  max-width: 520px;
}

.ai-pending-card {
  border: 1px solid #e2e8f0;
  border-left: 3px solid #1f4e79;
  border-radius: 8px;
  background: #fff;
  padding: 10px 12px;
}

.ai-pending-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.ai-pending-title {
  font-size: 13px;
  font-weight: 600;
  color: #1f4e79;
}

.ai-pending-tag {
  font-size: 10.5px;
  padding: 1px 7px;
  border-radius: 10px;
  white-space: nowrap;
  color: #2f7a6b;
  background: #e8f5f1;
  border: 1px solid #bfe3da;
}

.ai-pending-tag.kind-undo {
  color: #b45309;
  background: #fdf4e7;
  border-color: #f3d8ae;
}

.ai-pending-tag.kind-delete {
  color: #b91c1c;
  background: #fdecec;
  border-color: #f3c2c2;
}

.ai-pending-sum {
  margin-top: 6px;
  font-size: 12px;
  line-height: 1.65;
  color: #4b5563;
  white-space: pre-wrap;
  word-break: break-word;
}

.ai-pending-res {
  margin-top: 6px;
  font-size: 12px;
  color: #2f7a6b;
  background: #f5fbf9;
  border-radius: 6px;
  padding: 5px 8px;
}

.ai-pending-ops {
  margin-top: 8px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.ai-pending-done {
  font-size: 12px;
  color: #9ca3af;
}

/* ---- 简约主题覆盖：小字号、去渐变、紧凑留白 ---- */
.ai-panel {
  background: #fff;
}
.ai-header {
  padding: 9px 14px;
  border-bottom: 1px solid #f0f1f3;
}
.ai-header-left {
  gap: 8px;
}
.ai-avatar-bot {
  background: #e8f0fe;
  color: #2563eb;
  font-size: 11px;
}
.ai-title {
  font-size: 14px;
  font-weight: 600;
  color: #0f172a;
}
.ai-sub {
  font-size: 10.5px;
  color: #9aa1ac;
}
.ai-sub .dot {
  width: 5px;
  height: 5px;
  background: #16a34a;
}
.ai-header-actions {
  gap: 10px;
  align-items: center;
  color: #8a919c;
}
.ai-icon-btn {
  position: relative;
  display: inline-flex;
  align-items: center;
  cursor: pointer;
}
.ai-badge {
  position: absolute;
  top: -6px;
  right: -8px;
  min-width: 14px;
  height: 14px;
  padding: 0 3px;
  border-radius: 7px;
  background: #2563eb;
  color: #fff;
  font-weight: 600;
  font-size: 9px;
  line-height: 14px;
  text-align: center;
}
.ai-header-actions .el-icon:hover {
  color: #2563eb;
}
.ai-menu-wrap {
  position: relative;
  display: inline-flex;
}
.ai-menu {
  position: absolute;
  top: calc(100% + 6px);
  right: 0;
  min-width: 208px;
  max-width: 268px;
  max-height: 300px;
  overflow-y: auto;
  padding: 4px;
  background: #fff;
  border: 1px solid #eef0f3;
  border-radius: 8px;
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.12);
  z-index: 30;
}
.ai-menu-item {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 8px;
  border-radius: 6px;
  font-size: 12.5px;
  line-height: 1.5;
  color: #1f2329;
  cursor: pointer;
  white-space: nowrap;
}
.ai-menu-item:hover {
  background: #f4f5f7;
}
.ai-menu-empty {
  padding: 10px 8px;
  font-size: 12px;
  color: #a0a6b0;
  text-align: center;
}
.session-item {
  width: 200px;
  gap: 8px;
  padding: 2px 0;
}
.session-main {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-width: 0;
}
.session-title {
  font-size: 12.5px;
  color: #1f2329;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.session-meta {
  margin-top: 1px;
  font-size: 10.5px;
  color: #a0a6b0;
}
.session-item.session-active .session-title {
  color: #2563eb;
  font-weight: 600;
}
.ai-msg-list {
  padding: 12px 14px 6px;
}
.ai-row {
  margin-bottom: 13px;
  gap: 7px;
}
.ai-avatar {
  width: 24px;
  height: 24px;
  font-size: 10px;
}
.ai-avatar-user {
  background: #eef2f7;
  color: #4b5563;
}
.ai-col {
  max-width: 82%;
}
.ai-bubble {
  padding: 7px 10px;
  border-radius: 10px;
  font-size: 12.5px;
  line-height: 1.6;
}
.ai-row.assistant .ai-bubble {
  background: #f6f7f9;
  border: none;
  color: #1f2329;
}
.ai-row.user .ai-bubble {
  background: #e8f0fe;
  color: #1e3a8a;
}
.ai-bubble :deep(code) {
  background: rgba(37, 99, 235, 0.08);
  color: #2563eb;
}
.ai-bubble :deep(a) {
  color: #2563eb;
}
.ai-tool-card {
  background: #f1f3f5;
  color: #4b5563;
  font-size: 11.5px;
}
.ai-actions span:hover {
  color: #2563eb;
}
.ai-go {
  color: #2563eb;
  font-size: 12px;
}
.ai-empty-avatar {
  width: 40px;
  height: 40px;
  background: #e8f0fe;
  color: #2563eb;
  font-size: 12px;
}
.ai-empty h3 {
  font-size: 14.5px;
}
.ai-empty p {
  font-size: 12px;
  margin-bottom: 12px;
}
.ai-chip {
  font-size: 11.5px;
  padding: 5px 10px;
  border-radius: 13px;
  color: #35507a;
  border-color: #dbe6fb;
  background: #f7faff;
}
.ai-chip:hover {
  border-color: #2563eb;
  background: #f3f7ff;
  color: #2563eb;
}
.ai-fab {
  background: linear-gradient(135deg, #3b82f6, #2563eb);
  box-shadow: 0 5px 16px rgba(37, 99, 235, 0.32);
}
.ai-fab:hover {
  box-shadow: 0 8px 22px rgba(37, 99, 235, 0.4);
}
.ai-row.assistant .ai-bubble.ai-bubble-empty {
  color: #9aa1ac;
  font-size: 12px;
}
.ai-typing-dots {
  background: #f6f7f9;
  border: none;
  padding: 9px 12px;
}
.ai-cursor {
  background: #2563eb;
}
.ai-composer {
  margin: 0 12px;
  padding: 7px 9px 7px 11px;
  border-color: #e5e7eb;
  border-radius: 12px;
}
.ai-composer:focus-within {
  border-color: #2563eb;
  box-shadow: 0 0 0 2px rgba(37, 99, 235, 0.08);
}
.ai-composer-text .el-textarea__inner {
  font-size: 13px;
}
.ai-foot {
  font-size: 10px;
  color: #b4bac4;
  padding: 5px;
}
.ai-pending {
  max-width: 100%;
}
.ai-pending-tag {
  font-size: 10px;
}
.ai-pending-title {
  font-size: 12.5px;
}
</style>
