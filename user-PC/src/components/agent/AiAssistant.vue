<template>
  <Teleport to="body" :disabled="standalone">
    <section v-if="open" class="pc-ai-panel" :class="{ 'is-standalone': standalone }" aria-label="AI 智能助手" @keydown.esc.stop="closePanel">
      <header class="pc-ai-header">
        <span class="pc-ai-avatar" aria-hidden="true">AI</span>
        <div class="pc-ai-heading"><h2>AI 智能助手</h2><p>{{ busy ? (status || '正在处理，请稍候') : '你的专属求职伙伴' }}</p></div>
        <button type="button" class="pc-ai-icon" :disabled="locked" title="新建对话" aria-label="新建 AI 对话" @click="startNew">＋</button>
        <button type="button" class="pc-ai-icon" :class="{ 'is-active': view === 'history' }" title="历史记录" aria-label="AI 历史记录" :aria-pressed="view === 'history'" @click="toggleHistory">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 11a9 9 0 1 1 2.6 7M3 4v7h7M12 7v5l3 2" /></svg>
        </button>
        <button type="button" class="pc-ai-icon" title="关闭助手" aria-label="关闭 AI 助手" @click="closePanel">×</button>
      </header>

      <div v-if="view === 'history'" class="pc-ai-subview">
        <div class="pc-ai-section-title"><div><h3>历史对话</h3><p>与 App 共用本人账户的真实会话记录</p></div><button type="button" class="pc-ai-text-button" @click="backToChat">返回对话</button></div>
        <label class="pc-ai-search"><span>搜索记录</span><input v-model="historyQuery" placeholder="输入会话标题" maxlength="80" /></label>
        <div class="pc-ai-history-tools"><span>{{ filteredHistory.length }} 条已加载记录</span><button type="button" class="pc-ai-text-button" :disabled="historyLoading || historySaving" @click="loadHistory()">刷新</button></div>
        <p v-if="historyError" class="pc-ai-error" role="alert">{{ historyError }}</p>
        <div class="pc-ai-scroll pc-ai-history-list">
          <p v-if="historyLoading && !sessions.length" class="pc-ai-state">正在读取历史记录…</p>
          <p v-else-if="!filteredHistory.length" class="pc-ai-state">{{ historyQuery ? '已加载记录中没有匹配标题，可继续加载更多' : '还没有历史对话，发送第一条消息后会自动保存' }}</p>
          <article v-for="session in filteredHistory" :key="session.id" class="pc-ai-history-item" :class="{ 'is-current': session.id === sessionId }">
            <form v-if="editingId === session.id" class="pc-ai-rename" @submit.prevent="saveTitle(session.id)"><input v-model="editingTitle" maxlength="80" aria-label="新的会话标题" /><button type="submit" :disabled="historySaving || !editingTitle.trim()">保存</button><button type="button" :disabled="historySaving" @click="editingId = null">取消</button></form>
            <template v-else>
              <button type="button" class="pc-ai-history-open" :disabled="locked" @click="openSession(session.id)"><strong>{{ isPinned(session) ? '置顶 · ' : '' }}{{ session.title || '新对话' }}</strong><span>{{ formatMessageTime(session.createdAt) }}{{ session.activeRunId ? ' · 回答进行中' : '' }}{{ session.id === sessionId ? ' · 当前对话' : '' }}</span></button>
              <div class="pc-ai-history-actions"><button type="button" :disabled="locked" @click="rename(session)">重命名</button><button type="button" :disabled="locked" @click="manageHistory('pin', session.id, !isPinned(session))">{{ isPinned(session) ? '取消置顶' : '置顶' }}</button><button type="button" class="is-danger" :disabled="locked" @click="deletingId = session.id">删除</button></div>
            </template>
            <div v-if="deletingId === session.id" class="pc-ai-delete-confirm"><span>确定删除该对话及消息？删除后无法恢复。</span><button type="button" :disabled="locked" @click="removeSession(session.id)">确定删除</button><button type="button" :disabled="historySaving" @click="deletingId = null">取消</button></div>
          </article>
          <button v-if="historyHasMore" type="button" class="pc-ai-load-more" :disabled="historyLoading || historySaving" @click="loadHistory(true)">{{ historyLoading ? '正在加载…' : '加载更多历史记录' }}</button>
        </div>
      </div>

      <div v-else-if="view === 'resumes' || view === 'applications'" class="pc-ai-subview">
        <div class="pc-ai-section-title"><div><h3>{{ view === 'resumes' ? '选择本次使用的简历' : '选择已投递岗位' }}</h3><p>{{ view === 'resumes' ? '读取“我的简历”中的真实简历，不会修改默认简历' : '面试准备会使用该次投递关联的简历，而不是其他版本' }}</p></div><button type="button" class="pc-ai-text-button" @click="cancelPicker">返回</button></div>
        <label class="pc-ai-search"><span>{{ view === 'resumes' ? '搜索简历' : '搜索岗位' }}</span><input v-model="pickerQuery" :placeholder="view === 'resumes' ? '简历名称 / 求职方向' : '岗位名称 / 企业名称'" /></label>
        <p v-if="pickerError" class="pc-ai-error" role="alert">{{ pickerError }}<button type="button" class="pc-ai-text-button" @click="loadPicker()">重试</button></p>
        <div class="pc-ai-scroll pc-ai-options">
          <p v-if="pickerLoading && !pickerItems.length" class="pc-ai-state">正在读取真实数据…</p>
          <div v-else-if="!filteredOptions.length && !pickerError" class="pc-ai-state"><p>{{ pickerQuery ? '已加载数据中没有匹配项' : view === 'resumes' ? '还没有简历，请先创建或上传 PDF 简历' : '还没有投递记录，请先浏览岗位并完成投递' }}</p><a :href="appHref(view === 'resumes' ? '/profile-resumes' : '/jobs')">{{ view === 'resumes' ? '前往我的简历' : '前往岗位浏览' }}</a></div>
          <button v-for="item in filteredOptions" :key="item.id" type="button" class="pc-ai-option" :class="{ 'is-selected': String(view === 'resumes' ? resume?.id : application?.id) === String(item.id) }" :disabled="locked || (view === 'applications' && !item.resumeAvailable)" @click="chooseOption(item)">
            <span class="pc-ai-option-icon" aria-hidden="true">{{ view === 'resumes' ? '简历' : '岗位' }}</span>
            <span class="pc-ai-option-content"><strong>{{ view === 'resumes' ? item.name : item.jobTitle }}</strong><span>{{ view === 'resumes' ? (item.jobDirection || '暂未填写求职方向') : item.companyName }}</span><small>{{ view === 'resumes' ? (item.isDefault ? '默认简历' : '个人简历') : (item.resumeAvailable ? `投递简历：${item.resumeName || '已关联简历'}` : '投递简历已失效或缺失，请选择其他记录') }}</small></span><span aria-hidden="true">›</span>
          </button>
          <button v-if="pickerHasMore" type="button" class="pc-ai-load-more" :disabled="pickerLoading" @click="loadPicker(true)">{{ pickerLoading ? '正在加载…' : '加载更多投递岗位' }}</button>
        </div>
      </div>

      <div v-else class="pc-ai-chat">
        <div class="pc-ai-conversation-label"><span>{{ current?.title || '新对话' }}</span><button type="button" class="pc-ai-text-button" @click="toggleHistory">查看历史</button></div>
        <div ref="messageList" class="pc-ai-scroll pc-ai-messages" @scroll="trackScroll">
          <button v-if="hasOlder" type="button" class="pc-ai-load-more" :disabled="locked" @click="olderMessages">{{ olderLoading ? '正在加载…' : '查看更早的消息' }}</button>
          <p v-if="loading" class="pc-ai-state">正在读取对话…</p>
          <div v-else-if="!messages.length" class="pc-ai-welcome"><span class="pc-ai-welcome-icon">AI</span><h3>你好，我是你的求职 AI 助手</h3><p>选好简历和岗位，让建议更贴合你。</p><div class="pc-ai-capabilities"><span>真实岗位推荐</span><span>简历分析建议</span><span>针对性面试准备</span><span>求职文案润色</span></div><p class="pc-ai-welcome-hint">也可以直接提问，自由聊天无需选择资料。</p></div>
          <article v-for="(message, index) in messages" :key="message.id || `${message.runId}-${message.role}-${index}`" class="pc-ai-message" :class="{ 'is-user': message.role === 'user' }">
            <div class="pc-ai-message-author">{{ message.role === 'user' ? '我' : 'AI 助手' }}</div>
            <div class="pc-ai-bubble">{{ message.role === 'user' ? message.content : aiPlainText(message.content) || (busy ? '正在生成回答…' : '本次未生成回答') }}</div>
            <small v-if="message.interrupted" class="pc-ai-partial-label">未完成的回答，仅供参考</small>
            <div v-if="message.cards?.length" class="pc-ai-job-cards"><a v-for="job in message.cards" :key="job.positionId" :href="appHref(`/job-detail?id=${encodeURIComponent(job.positionId)}`)" class="pc-ai-job-card"><strong>{{ job.title }}</strong><span>{{ job.company }} · {{ job.city || '地点未注明' }}</span><span class="pc-ai-job-salary">{{ salary(job) }}</span><span class="pc-ai-job-link">查看岗位详情 →</span></a></div>
          </article>
        </div>
        <button v-if="!followLatest && messages.length" type="button" class="pc-ai-latest" @click="scrollLatest">回到最新消息 ↓</button>
        <div v-if="error" class="pc-ai-error" role="alert"><span>{{ error }}</span><button v-if="!initialized && !busy" type="button" class="pc-ai-text-button" @click="initialize">重新加载</button><button v-if="disconnected" type="button" class="pc-ai-text-button" :disabled="streaming || stopping" @click="reconnect">恢复回答</button></div>
        <p v-if="busy || status" class="pc-ai-progress" role="status">{{ status || '正在发送，请稍候…' }}</p>
        <footer class="pc-ai-footer">
          <div v-if="resume || application" class="pc-ai-context"><span v-if="resume"><span :title="resume.name">简历：{{ resume.name }}</span><button type="button" :disabled="locked" aria-label="取消所选简历" @click="selectResume(null)">×</button></span><span v-if="application"><span :title="application.jobTitle">岗位：{{ application.jobTitle }}</span><button type="button" :disabled="locked" aria-label="取消所选岗位" @click="selectApplication(null)">×</button></span></div>
          <div class="pc-ai-shortcuts" aria-label="AI 求职功能"><button type="button" :disabled="locked" @click="openPicker('resumes')">选择简历</button><button type="button" :disabled="locked" @click="openPicker('applications')">选择岗位</button><button v-for="item in aiActions" :key="item.value" type="button" :class="{ 'is-active': action === item.value }" :disabled="locked" @click="shortcut(item)">{{ item.label }}</button></div>
          <div v-if="action !== 'chat'" class="pc-ai-mode"><span>当前功能：{{ aiActions.find(item => item.value === action)?.label }}</span><button type="button" :disabled="locked" @click="action = 'chat'">切回自由聊天</button></div>
          <form class="pc-ai-composer" @submit.prevent="sendQuestion"><textarea ref="input" v-model="draft" rows="3" maxlength="4000" :disabled="locked" placeholder="想聊什么，直接输入…（Enter 发送，Shift+Enter 换行）" aria-label="向 AI 助手提问" @keydown="composerKeydown" /><button v-if="runId" type="button" class="pc-ai-send is-stop" :disabled="stopping" aria-label="停止 AI 回答" @click="stop">{{ stopping ? '停止中' : '停止' }}</button><button v-else type="submit" class="pc-ai-send" :disabled="locked || !draft.trim()" aria-label="发送 AI 问题">↑</button></form>
          <div class="pc-ai-disclaimer"><span>内容由 AI 生成，请注意核实 · 纯文本展示</span><span>{{ draft.length }}/4000</span></div>
        </footer>
      </div>
    </section>
    <button v-if="!standalone" ref="launcher" type="button" class="pc-ai-launcher" :aria-expanded="open" :aria-label="open ? '收起 AI 智能助手' : '打开 AI 智能助手'" @click="togglePanel"><span>AI</span><span class="pc-ai-launcher-label">求职助手</span><i v-if="busy" aria-label="回答进行中" /></button>
  </Teleport>
</template>

<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import * as aiApi from '@/api/agent/ai'
import { getResumes } from '@/api/agent/resume'
import { getApplication, listApplications } from '@/api/agent/application'
import { useAiAssistant } from '@/composables/useAiAssistant'
import { aiActions, aiPlainText } from '@/utils/agentAi'
import { appHref } from '@/utils/agentNavigation'
import { formatMessageTime } from '@/utils/agentTime'

const props = defineProps({ standalone: { type: Boolean, default: false } })
const emit = defineEmits(['close'])
const assistant = useAiAssistant({ ...aiApi, getResumes, getApplication })
const { sessions, sortedSessions, sessionId, current, messages, draft, action, resume, application, loading, busy, locked, streaming, stopping, status, error, historyError, historyLoading, historySaving, historyHasMore, hasOlder, olderLoading, runId, disconnected, initialized, initialize, loadHistory, newSession, reconnect, stop, manageHistory, selectResume, selectApplication } = assistant
const open = ref(false)
const view = ref('chat')
const launcher = ref(null)
const input = ref(null)
const messageList = ref(null)
const followLatest = ref(true)
const historyQuery = ref('')
const editingId = ref(null)
const editingTitle = ref('')
const deletingId = ref(null)
const pickerQuery = ref('')
const pickerItems = ref([])
const pickerLoading = ref(false)
const pickerError = ref('')
const pickerHasMore = ref(false)
let pickerPage = 1
let pickerEpoch = 0
let pendingAction = null
let disposed = false
const filteredHistory = computed(() => sortedSessions.value.filter(item => String(item.title || '新对话').toLowerCase().includes(historyQuery.value.trim().toLowerCase())))
const filteredOptions = computed(() => pickerItems.value.filter(item => `${item.name || ''} ${item.jobDirection || ''} ${item.jobTitle || ''} ${item.companyName || ''}`.toLowerCase().includes(pickerQuery.value.trim().toLowerCase())))
const isPinned = session => session.pinned === true || String(session.pinned) === '1'

async function togglePanel() {
  if (open.value) return closePanel()
  open.value = true
  view.value = 'chat'
  followLatest.value = true
  await initialize()
  scrollLatest()
}

function closePanel() {
  if (props.standalone) {
    emit('close')
    return
  }
  open.value = false
  cancelPicker()
  nextTick(() => launcher.value?.focus())
}

function scrollLatest() {
  followLatest.value = true
  nextTick(() => {
    if (messageList.value) messageList.value.scrollTop = messageList.value.scrollHeight
  })
}

function trackScroll() {
  const element = messageList.value
  if (element) followLatest.value = element.scrollHeight - element.clientHeight - element.scrollTop < 80
}

watch(() => `${messages.value.at(-1)?.content || ''}-${messages.value.at(-1)?.cards?.length || 0}-${messages.value.length}`, () => {
  if (followLatest.value) scrollLatest()
})

function backToChat() {
  view.value = 'chat'
  scrollLatest()
}

function toggleHistory() {
  if (view.value === 'history') return backToChat()
  cancelPicker()
  view.value = 'history'
  editingId.value = null
  deletingId.value = null
  loadHistory()
}

function startNew() {
  if (!newSession()) return
  cancelPicker()
  backToChat()
  nextTick(() => input.value?.focus())
}

async function openSession(id) {
  followLatest.value = true
  await assistant.selectSession(id)
  if (sessionId.value === id) backToChat()
}

function rename(session) {
  editingId.value = session.id
  editingTitle.value = session.title || '新对话'
  deletingId.value = null
}

async function saveTitle(id) {
  if (await manageHistory('rename', id, editingTitle.value)) editingId.value = null
}

async function removeSession(id) {
  if (await manageHistory('delete', id)) deletingId.value = null
}

async function openPicker(kind, nextAction = null) {
  if (locked.value) return
  pendingAction = nextAction
  view.value = kind
  pickerQuery.value = ''
  pickerItems.value = []
  pickerHasMore.value = false
  await loadPicker()
}

function cancelPicker() {
  pickerEpoch++
  pendingAction = null
  pickerLoading.value = false
  view.value = 'chat'
}

async function loadPicker(older = false) {
  if (pickerLoading.value || disposed) return
  const kind = view.value
  if (!['resumes', 'applications'].includes(kind)) return
  const epoch = ++pickerEpoch
  pickerLoading.value = true
  pickerError.value = ''
  const page = older ? pickerPage + 1 : 1
  try {
    const [response, resumesResponse] = kind === 'resumes' ? [await getResumes(), null] : await Promise.all([listApplications({ page, size: 20 }), getResumes()])
    if (disposed || epoch !== pickerEpoch) return
    const items = kind === 'resumes' ? response.data : response.data?.items
    if (!Array.isArray(items)) throw new Error('选择列表响应格式不正确')
    if (kind === 'applications' && !Array.isArray(resumesResponse?.data)) throw new Error('简历列表读取失败，请重试')
    const activeIds = new Set((resumesResponse?.data || []).map(item => String(item.id)))
    const rows = older ? [...pickerItems.value, ...items] : items
    pickerItems.value = [...new Map(rows.map(item => [item.id, kind === 'applications' ? { ...item, resumeAvailable: Boolean(item.resumeId && activeIds.has(String(item.resumeId))) } : item])).values()]
    pickerPage = page
    pickerHasMore.value = kind === 'applications' && Boolean(response.data.hasNext)
  } catch (failure) {
    if (!disposed && epoch === pickerEpoch) pickerError.value = failure.message || '读取失败，请稍后重试'
  } finally {
    if (!disposed && epoch === pickerEpoch) pickerLoading.value = false
  }
}

async function chooseOption(item) {
  const epoch = pickerEpoch
  if (view.value === 'resumes') selectResume(item)
  else if (!await selectApplication(item)) {
    pickerError.value = error.value
    return
  }
  if (disposed || epoch !== pickerEpoch) return
  const nextAction = pendingAction
  cancelPicker()
  if (nextAction) applyShortcut(nextAction)
  else backToChat()
}

function applyShortcut(item) {
  action.value = item.value
  if (!draft.value.trim() || aiActions.some(entry => draft.value === entry.prompt)) draft.value = item.prompt
  backToChat()
  nextTick(() => input.value?.focus())
}

function shortcut(item) {
  if (locked.value) return
  if (['job_recommendation', 'resume_analysis'].includes(item.value) && !resume.value) return openPicker('resumes', item)
  if (item.value === 'interview_preparation' && !application.value) return openPicker('applications', item)
  applyShortcut(item)
}

async function sendQuestion() {
  if (locked.value || !draft.value.trim()) return
  if (['job_recommendation', 'resume_analysis'].includes(action.value) && !resume.value) return openPicker('resumes')
  if (action.value === 'interview_preparation' && !application.value) return openPicker('applications')
  scrollLatest()
  await assistant.send()
  if (!disposed) nextTick(() => input.value?.focus())
}

function composerKeydown(event) {
  if (event.key === 'Enter' && !event.shiftKey && !event.isComposing && event.keyCode !== 229) {
    event.preventDefault()
    sendQuestion()
  }
}

async function olderMessages() {
  const element = messageList.value
  const previousHeight = element?.scrollHeight || 0
  const previousTop = element?.scrollTop || 0
  followLatest.value = false
  await assistant.loadOlder()
  await nextTick()
  if (element) element.scrollTop = previousTop + element.scrollHeight - previousHeight
}

function salary(job) {
  if (!job.salaryMin && !job.salaryMax) return '薪资面议'
  const amount = value => Number(value) >= 1000 ? `${Number(value) / 1000}K` : String(value)
  return job.salaryMin && job.salaryMax ? `${amount(job.salaryMin)}–${amount(job.salaryMax)}` : `${amount(job.salaryMin || job.salaryMax)}`
}

onBeforeUnmount(() => {
  disposed = true
  pickerEpoch++
  assistant.dispose()
})

onMounted(() => {
  if (props.standalone) togglePanel()
})
</script>

<style scoped>
.pc-ai-panel,.pc-ai-launcher{--pc-ai-blue:#2b7fff;--pc-ai-line:#e4eaf3;--pc-ai-muted:#75849a;box-sizing:border-box;font-family:Inter,"PingFang SC","Microsoft YaHei",sans-serif;color:#233b59;font-size:14px;line-height:1.6}
.pc-ai-panel *,.pc-ai-launcher *{box-sizing:border-box}
.pc-ai-panel{position:fixed;z-index:1800;right:28px;bottom:92px;display:flex;flex-direction:column;width:min(540px,calc(100vw - 40px));height:min(780px,calc(100dvh - 118px));min-height:280px;overflow:hidden;border:1px solid #dbe5f3;border-radius:20px;background:linear-gradient(165deg,#edf3ff,#fff 48%);box-shadow:0 18px 65px #183a6733}
.pc-ai-panel.is-standalone{position:relative;z-index:1;right:auto;bottom:auto;width:100%;height:100%;min-height:0;box-shadow:0 8px 35px #183a6710}
.pc-ai-panel button,.pc-ai-panel input,.pc-ai-panel textarea,.pc-ai-launcher{font-family:inherit;letter-spacing:normal}
.pc-ai-panel button{cursor:pointer;text-transform:none}
.pc-ai-panel button:disabled{cursor:not-allowed;opacity:.48}
.pc-ai-panel button:focus-visible,.pc-ai-panel input:focus-visible,.pc-ai-panel textarea:focus-visible,.pc-ai-panel a:focus-visible,.pc-ai-launcher:focus-visible{outline:3px solid #2b7fff66;outline-offset:2px}
.pc-ai-header{display:flex;flex:none;align-items:center;gap:10px;padding:18px 18px 14px;border-bottom:1px solid var(--pc-ai-line)}
.pc-ai-avatar,.pc-ai-welcome-icon{display:grid;place-items:center;flex:none;width:40px;height:40px;border-radius:13px;color:#fff;background:linear-gradient(135deg,#2b7fff,#6564eb);font-size:15px;font-weight:700}
.pc-ai-heading{flex:1;min-width:0}.pc-ai-heading h2{margin:0;color:#1e3a60;font-size:18px;font-weight:700;line-height:1.5}.pc-ai-heading p{margin:2px 0 0;color:var(--pc-ai-muted);font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.pc-ai-icon{display:grid;place-items:center;flex:none;width:32px;height:32px;padding:0;border:0;border-radius:9px;background:transparent;color:#45617f;font-size:25px;line-height:1}.pc-ai-icon:hover,.pc-ai-icon.is-active{color:var(--pc-ai-blue);background:#dfeaff}.pc-ai-icon svg{width:21px;height:21px;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}
.pc-ai-chat,.pc-ai-subview{position:relative;display:flex;flex:1;flex-direction:column;min-height:0;overflow:hidden}
.pc-ai-conversation-label{display:flex;flex:none;align-items:center;gap:12px;padding:9px 20px;color:var(--pc-ai-muted);font-size:12px}.pc-ai-conversation-label>span{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.pc-ai-text-button{flex:none;padding:2px 0;border:0;background:transparent;color:var(--pc-ai-blue);font-size:12px;white-space:nowrap}
.pc-ai-scroll{flex:1;min-height:0;overflow-y:auto;overscroll-behavior:contain;scrollbar-width:thin;scrollbar-gutter:stable}
.pc-ai-messages{padding:8px 20px 18px;overflow-anchor:none}.pc-ai-welcome{text-align:center;padding:24px 10px 16px}.pc-ai-welcome-icon{width:54px;height:54px;margin:0 auto 16px;border-radius:17px;font-size:21px}.pc-ai-welcome h3{margin:0 0 8px;font-size:18px}.pc-ai-welcome p{margin:0;color:var(--pc-ai-muted);font-size:13px}.pc-ai-capabilities{display:grid;grid-template-columns:1fr 1fr;gap:9px;margin:22px auto;max-width:340px}.pc-ai-capabilities span{padding:10px 6px;border:1px solid var(--pc-ai-line);border-radius:10px;background:#ffffffb3;font-size:12px}.pc-ai-welcome .pc-ai-welcome-hint{font-size:11px}
.pc-ai-message{margin:0 0 18px}.pc-ai-message-author{margin:0 0 5px;color:var(--pc-ai-muted);font-size:12px}.pc-ai-bubble{width:fit-content;max-width:94%;padding:13px 16px;border:1px solid var(--pc-ai-line);border-radius:4px 15px 15px 15px;background:#fff;color:#263d56;font-size:14px;line-height:1.85;white-space:pre-wrap;overflow-wrap:anywhere;word-break:normal}.pc-ai-message.is-user{display:flex;flex-direction:column;align-items:flex-end}.pc-ai-message.is-user .pc-ai-bubble{border-color:#cddfff;border-radius:15px 4px 15px 15px;background:#e7f0ff;color:#254f86}.pc-ai-partial-label{display:block;margin-top:4px;color:var(--pc-ai-muted);font-size:11px}
.pc-ai-job-cards{display:grid;gap:8px;max-width:94%;margin-top:9px}.pc-ai-job-card{display:flex;flex-direction:column;gap:4px;padding:13px 15px;border:1px solid #d9e6ff;border-radius:12px;background:#f9fbff;color:#526b88;text-decoration:none;font-size:12px;overflow-wrap:anywhere}.pc-ai-job-card:hover{border-color:#85b4ff}.pc-ai-job-card strong{color:#234363;font-size:14px}.pc-ai-job-salary{color:#db7a33}.pc-ai-job-link{color:var(--pc-ai-blue)}
.pc-ai-latest{position:absolute;bottom:265px;left:50%;transform:translateX(-50%);padding:5px 13px;border:1px solid #d6e4fa;border-radius:20px;background:#fff;color:var(--pc-ai-blue);box-shadow:0 2px 8px #27496612;font-size:12px;white-space:nowrap}
.pc-ai-error{display:flex;flex:none;flex-wrap:wrap;align-items:center;gap:8px;margin:0;padding:8px 18px;color:#ad4a37;background:#fff4ef;font-size:12px;overflow-wrap:anywhere}.pc-ai-error>span{min-width:0;flex:1}.pc-ai-progress{flex:none;margin:0;padding:5px 20px;color:#697f9e;font-size:11px}
.pc-ai-footer{flex:none;padding:12px 16px 10px;border-top:1px solid var(--pc-ai-line);background:#ffffffed}.pc-ai-context{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px}.pc-ai-context>span{display:flex;align-items:center;gap:5px;max-width:100%;padding:4px 7px;border:1px solid #d9e5f9;border-radius:6px;background:#f0f5fe;font-size:11px;color:#436385}.pc-ai-context>span>span{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.pc-ai-context button{flex:none;width:18px;height:18px;padding:0;border:0;background:transparent;color:#617e9e;line-height:1;font-size:16px}
.pc-ai-shortcuts{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:7px;margin-bottom:10px}.pc-ai-shortcuts button{min-width:0;padding:7px 4px;border:1px solid #dde5ef;border-radius:8px;background:#fff;color:#526b86;font-size:12px;white-space:nowrap}.pc-ai-shortcuts button:hover,.pc-ai-shortcuts button.is-active{border-color:#9dc4ff;color:var(--pc-ai-blue);background:#f0f6ff}.pc-ai-mode{display:flex;align-items:center;justify-content:space-between;gap:8px;margin:0 0 6px;color:#6684ac;font-size:11px}.pc-ai-mode button{border:0;padding:0;background:transparent;color:var(--pc-ai-blue);font-size:11px}
.pc-ai-composer{display:flex;align-items:flex-end;gap:10px;margin:0;padding:0;background:transparent}.pc-ai-composer textarea{display:block;flex:1;min-width:0;width:0;height:82px;min-height:64px;max-height:140px;resize:vertical;padding:10px 12px;border:1px solid #dce4ef;border-radius:10px;background:#fbfcff;color:#2a4160;font-size:13px;line-height:1.65;box-shadow:none}.pc-ai-composer textarea::placeholder{color:#95a0b0}.pc-ai-send{display:grid;place-items:center;flex:none;width:42px;height:42px;margin-bottom:1px;padding:0;border:0;border-radius:50%;background:var(--pc-ai-blue);color:#fff;font-size:26px;line-height:1}.pc-ai-send.is-stop{font-size:11px;background:#647b99}.pc-ai-disclaimer{display:flex;justify-content:space-between;gap:8px;margin-top:8px;color:#98a3b3;font-size:10px}
.pc-ai-section-title{display:flex;flex:none;align-items:flex-start;gap:12px;padding:18px 20px 12px}.pc-ai-section-title>div{flex:1;min-width:0}.pc-ai-section-title h3{margin:0;font-size:16px}.pc-ai-section-title p{margin:5px 0 0;color:var(--pc-ai-muted);font-size:12px}.pc-ai-search{display:flex;flex:none;align-items:center;gap:10px;margin:0 20px 10px;padding:8px 11px;border:1px solid #dde5ef;border-radius:9px;background:#fff;font-size:12px}.pc-ai-search>span{flex:none;color:var(--pc-ai-muted)}.pc-ai-search input{flex:1;min-width:0;width:0;height:23px;padding:0;border:0;border-radius:0;outline:none;background:transparent;color:#314f72;box-shadow:none;font-size:12px}.pc-ai-history-tools{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:0 20px 10px;font-size:11px;color:var(--pc-ai-muted)}
.pc-ai-history-list,.pc-ai-options{padding:4px 16px 18px}.pc-ai-history-item{margin:0 0 10px;padding:12px;border:1px solid var(--pc-ai-line);border-radius:12px;background:#fff}.pc-ai-history-item.is-current{border-color:#a2c8ff;background:#f6faff}.pc-ai-history-open{display:flex;flex-direction:column;gap:5px;width:100%;padding:0;border:0;background:transparent;text-align:left}.pc-ai-history-open strong{max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#2b496d;font-size:13px;font-weight:600}.pc-ai-history-open>span{color:var(--pc-ai-muted);font-size:11px}.pc-ai-history-actions{display:flex;flex-wrap:wrap;gap:16px;margin-top:10px}.pc-ai-history-actions button,.pc-ai-delete-confirm button,.pc-ai-rename button{padding:0;border:0;background:transparent;color:#627e9f;font-size:11px}.pc-ai-history-actions .is-danger,.pc-ai-delete-confirm button:first-of-type{color:#bc554a}.pc-ai-delete-confirm{display:flex;flex-wrap:wrap;gap:10px;margin-top:10px;padding-top:10px;border-top:1px solid var(--pc-ai-line);font-size:12px}.pc-ai-delete-confirm span{flex-basis:100%;color:#a55d51}.pc-ai-rename{display:flex;align-items:center;gap:10px}.pc-ai-rename input{width:0;min-width:0;flex:1;padding:5px 7px;border:1px solid #d6e2f1;border-radius:5px;background:#fff;color:#304f70;font-size:12px}.pc-ai-rename button{flex:none}
.pc-ai-state{margin:0;padding:24px 10px;color:var(--pc-ai-muted);text-align:center;font-size:13px}.pc-ai-state a{color:var(--pc-ai-blue)}.pc-ai-load-more{display:block;width:100%;margin:0 auto 12px;padding:8px;border:1px solid #dde6f3;border-radius:8px;background:#ffffffb3;color:#647e9c;font-size:12px}.pc-ai-option{display:flex;align-items:center;gap:12px;width:100%;margin-bottom:10px;padding:13px 12px;border:1px solid var(--pc-ai-line);border-radius:12px;background:#fff;color:#627c99;text-align:left}.pc-ai-option:hover,.pc-ai-option.is-selected{border-color:#9ec6ff;background:#f4f8ff}.pc-ai-option-icon{display:grid;place-items:center;flex:none;width:38px;height:43px;border:1px solid #e1e9f6;border-radius:8px;background:#eff5ff;color:#6994cc;font-size:10px}.pc-ai-option-content{display:flex;flex:1;flex-direction:column;gap:3px;min-width:0;overflow-wrap:anywhere}.pc-ai-option-content strong{font-size:13px;color:#2e4b70;font-weight:600}.pc-ai-option-content>span{font-size:12px}.pc-ai-option-content small{font-size:11px;color:#8c9aaf}
.pc-ai-launcher{position:fixed;z-index:1801;right:28px;bottom:24px;display:flex;align-items:center;justify-content:center;gap:8px;height:48px;padding:0 17px;border:1px solid #ffffff99;border-radius:24px;background:linear-gradient(125deg,#2b7fff,#535ce5);box-shadow:0 5px 20px #2b7fff33;color:#fff;cursor:pointer}.pc-ai-launcher>span:first-child{font-size:18px;font-weight:800}.pc-ai-launcher-label{font-size:12px}.pc-ai-launcher i{width:7px;height:7px;border:1px solid #fff;border-radius:50%;background:#91f1c6}
@media(max-width:600px){.pc-ai-panel{right:10px;bottom:78px;width:calc(100vw - 20px);height:calc(100dvh - 94px);border-radius:16px;min-height:0}.pc-ai-header{gap:7px;padding:12px}.pc-ai-heading h2{font-size:16px}.pc-ai-icon{width:29px;height:29px}.pc-ai-messages{padding:8px 12px 14px}.pc-ai-footer{padding:10px 12px}.pc-ai-shortcuts{gap:6px}.pc-ai-shortcuts button{font-size:11px}.pc-ai-bubble{padding:11px 13px;font-size:13px;max-width:96%}.pc-ai-launcher{right:14px;bottom:18px;height:44px}.pc-ai-section-title{padding:15px 14px 12px}.pc-ai-search{margin-right:14px;margin-left:14px}.pc-ai-welcome{padding-top:12px}.pc-ai-welcome h3{font-size:16px}.pc-ai-welcome-icon{width:44px;height:44px;margin-bottom:12px}.pc-ai-capabilities{margin:16px auto}.pc-ai-disclaimer{font-size:9px}}
@media(prefers-reduced-motion:reduce){.pc-ai-panel *{scroll-behavior:auto}}
</style>
