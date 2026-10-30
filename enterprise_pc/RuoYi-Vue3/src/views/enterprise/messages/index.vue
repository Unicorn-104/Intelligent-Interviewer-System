<script setup>
import { ref, computed, nextTick, onBeforeUnmount, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Search, Video, Play, Zap, Smile, Paperclip, Camera, Send, Settings2, FileText, Bell, Copy, MessageSquareText } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import { listSessions, listMessages, sendMessage, readSession, readAll, uploadAttachment, listQuickReplies, saveQuickReply, deleteQuickReply } from '@/api/system/im'
import { candidateAppBase } from '@/utils/appLink'
import { createRoomLink, listCandidatePositions, listInterviewers, listInterviewerNotices, respondInterviewNotice } from '@/api/system/conference'
import { listSurveyTemplates, sendSurvey } from '@/api/survey'
import { listPapers, listSchedules, createSchedule } from '@/api/exam'
import { refreshUnread, totalUnread } from '@/views/enterprise/store/unread'
import { match as pinyinMatch } from 'pinyin-pro'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'

const route = useRoute()
const router = useRouter()
// 顶栏全局搜索带 ?keyword= 进入消息页时，直接筛选会话列表
const keyword = ref(typeof route.query.keyword === 'string' ? route.query.keyword : '')
const input = ref('')
const scroller = ref()
const inputEl = ref()
const fileInput = ref()
const imageInput = ref()
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

// 聊天附件地址：按当前部署的接口前缀拼接；历史消息里若写死了别的端地址
// （如 http://127.0.0.1:5180/dev-api/profile/...），也还原成当前部署可访问的地址
function attachmentUrl(p) {
  if (!p) return ''
  try {
    const api = String(import.meta.env.VITE_APP_BASE_API || '')
    let path = /^https?:\/\//i.test(p) ? new URL(p).pathname : String(p)
    if (api && (path === api || path.startsWith(api + '/'))) path = path.slice(api.length)
    return api + (path.startsWith('/') ? path : '/' + path)
  } catch (e) {
    return ''
  }
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
// 历史消息可能只存了相对路径（早期版本未拼接候选人端地址），渲染时按候选人端地址补全
function linkParts(text) {
  if (!text) return []
  const parts = []
  const re = /(https?:\/\/[^\s]+|\/(?:conference-join|survey-fill)\?[^\s]+)/g
  let last = 0
  let m
  while ((m = re.exec(text))) {
    if (m.index > last) parts.push({ text: text.slice(last, m.index) })
    const raw = m[0]
    // 相对链接补全为完整地址，展示文字也使用完整地址，与满意度调研消息保持一致
    const href = raw.startsWith('/') ? (candidateBase ? candidateBase + raw : '') : raw
    parts.push(href ? { text: href, href } : { text: raw })
    last = m.index + raw.length
  }
  if (last < text.length) parts.push({ text: text.slice(last) })
  return parts
}

// ---------- 岗位卡片消息（type=6，内容为 kind=job_card 的 JSON） ----------
// 求职者端/企业端 App 已按卡片渲染，PC 端此前直接把 JSON 当文本气泡展示，这里补上卡片样式
const EDU_LABEL = { 1: '中专', 2: '大专', 3: '本科', 4: '硕士', 5: '博士' }

function fmtSalary(min, max) {
  const a = Number(min)
  const b = Number(max)
  const valid = v => Number.isFinite(v) && v > 0
  const val = n => (n % 1 === 0 ? n.toFixed(0) : String(n))
  if (!valid(a) && !valid(b)) return '薪资面议'
  if (valid(a) && valid(b)) return `${val(a)}–${val(b)} 元/月`
  return valid(a) ? `${val(a)} 元/月起` : `最高 ${val(b)} 元/月`
}

function parseJobCard(content) {
  if (!content || content.charAt(0) !== '{') return null
  try {
    const raw = JSON.parse(content)
    if (!raw || raw.kind !== 'job_card' || raw.version !== 1) return null
    const positionId = Number(raw.positionId)
    const title = String(raw.title || '').trim()
    if (!(positionId > 0) || !title) return null
    return {
      positionId,
      title,
      salary: fmtSalary(raw.salaryMin, raw.salaryMax),
      meta: [
        String(raw.city || '').trim() || '城市不限',
        String(raw.experience || '').trim() || '经验不限',
        EDU_LABEL[Number(raw.education)] || '学历不限'
      ].join(' · '),
      company: String(raw.company || '').trim() || '企业信息待完善'
    }
  } catch (e) {
    return null
  }
}

function openJob(job) {
  if (job && job.positionId) router.push('/enterprise/jobs/' + job.positionId)
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
  peerPositions.value = []
  peerPositionsReady.value = false
  if (c.system) {
    await loadNotices()
    return
  }
  c.unread = 0
  loading.value = true
  loadPeerPositions()
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
    // 岗位卡片解析失败时保留原文气泡，避免消息丢失
    job: m.type === 6 ? parseJobCard(m.content) : null,
    attachmentUrl: attachmentUrl(m.attachmentUrl),
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
  loadPeerPositions()
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

function pickImage() { imageInput.value?.click() }

async function onFileChange(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  await sendAttachment(file)
}

async function onImageChange(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  await sendAttachment(file)
}

// 图片按 type=2 发送（气泡内直接预览），其他文件按 type=3 发送
async function sendAttachment(file) {
  if (!file || !activeConv.value) return
  try {
    const fd = new FormData()
    fd.append('file', file)
    const up = await uploadAttachment(fd)
    const body = {
      type: /^image\//i.test(file.type || '') ? 2 : 3,
      content: up.originalFilename || file.name,
      attachmentUrl: up.fileName
    }
    if (activeId.value != null) body.sessionId = activeId.value
    else body.peerId = newChat.value.peerId
    await sendMessage(body)
    await afterSend()
  } catch (err) {
    ElMessage.error(err?.message || '附件发送失败')
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

// ---------- 发送笔试：选择试卷，复用有效考试安排（没有则自动创建），把答题链接发到会话 ----------
const examOpen = ref(false)
const examLoading = ref(false)
const examSending = ref(false)
const examPapers = ref([])
const selectedPaperKey = ref(null)

function pad2(n) { return String(n).padStart(2, '0') }
function fmtMinute(d) {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`
}
function toTs(v) {
  if (!v) return null
  const t = new Date(String(v).replace(/-/g, '/').replace('T', ' ')).getTime()
  return isNaN(t) ? null : t
}

async function openExamModal() {
  const peer = peerUserId.value
  if (peer == null) { ElMessage.warning('当前会话缺少对方信息，无法发送笔试'); return }
  selectedPaperKey.value = null
  examPapers.value = []
  examOpen.value = true
  examLoading.value = true
  try {
    if (!peerPositionsReady.value) await loadPeerPositions()
    const papers = []
    for (const pos of peerPositions.value || []) {
      const res = await listPapers(pos.positionId).catch(() => null)
      for (const p of res?.data || []) {
        if (Number(p.status) !== 1) continue
        papers.push({
          ...p,
          positionId: pos.positionId,
          positionTitle: pos.positionTitle || p.positionTitle,
          key: `${pos.positionId}-${p.paperId}`
        })
      }
    }
    examPapers.value = papers
  } finally {
    examLoading.value = false
  }
}

async function sendExamToChat() {
  const peer = peerUserId.value
  const paper = examPapers.value.find(p => p.key === selectedPaperKey.value)
  if (peer == null || !paper) { ElMessage.warning('请选择要发送的试卷'); return }
  if (!candidateBase) { ElMessage.error('未配置候选人端地址，无法生成完整链接'); return }
  examSending.value = true
  try {
    let scheduleId = null
    let deadline = ''
    const sres = await listSchedules({ positionId: paper.positionId, pageNum: 1, pageSize: 50 }).catch(() => null)
    const nowTs = Date.now()
    // 只复用当前正在有效窗口内的安排（已开始且未结束），否则新建，避免发出去的是过期或未开始链接
    const hit = (sres?.rows || []).find(s => {
      if (Number(s.paperId) !== Number(paper.paperId)) return false
      if (Number(s.status) >= 2) return false
      const start = toTs(s.startAt)
      const end = toTs(s.endAt)
      return (start == null || start <= nowTs) && (end == null || end > nowTs)
    })
    if (hit) {
      scheduleId = hit.scheduleId
      deadline = hit.endAt || ''
    } else {
      const now = new Date()
      const end = new Date(now.getTime() + 7 * 24 * 3600 * 1000)
      deadline = fmtMinute(end)
      const res = await createSchedule({
        positionId: paper.positionId,
        paperId: paper.paperId,
        startAt: fmtMinute(now),
        endAt: deadline,
        maxAttempts: 1,
        passThreshold: Math.min(60, Number(paper.totalScore) || 60),
        forceDualCamera: 0,
        submitRule: { autoSubmit: true, allowEarly: true, autosaveInterval: 30 }
      })
      scheduleId = res?.data
    }
    if (!scheduleId) throw new Error('创建考试安排失败')
    const url = `${candidateBase}/agent/exam?scheduleId=${scheduleId}`
    const deadlineText = deadline ? `，考试截止 ${deadline}` : ''
    const body = {
      type: 1,
      content: `【在线笔试】${paper.positionTitle || '应聘岗位'}《${paper.name}》${deadlineText}，请点击链接进入笔试作答：${url}`
    }
    if (activeId.value != null) body.sessionId = activeId.value
    else body.peerId = newChat.value.peerId
    await sendMessage(body)
    examOpen.value = false
    await afterSend()
    ElMessage.success('笔试链接已发送')
  } catch (e) {
    ElMessage.error(e?.message || '发送笔试失败')
  } finally {
    examSending.value = false
  }
}

// ---------- 发起视频面试：生成会议链接 ----------
const linkOpen = ref(false)
const positionsLoading = ref(false)
const generating = ref(false)
const positions = ref([])
const interviewers = ref([])
const selectedInterviewerIds = ref([])
const linkResult = ref(null)
const linkForm = ref({ peerUserId: null, positionId: null, stageId: null, durationMinutes: 45, mode: 2 })
// 生成链接时锁定的阶段名，随邀请文案一起发送
const generatedStageName = ref('')
// 会话对方在各岗位流程中的当前阶段（聊天头部展示）
const peerPositions = ref([])

// 流程阶段类型：1-在线笔试 2-AI技术面试 3-HR综合面试 4-编程实操
const STAGE_TYPE_LABEL = { 1: '在线笔试', 2: 'AI 技术面试', 3: 'HR 综合面试', 4: '编程实操' }
// 阶段类型 → 默认面试方式：AI技术面试默认 AI+单面试官，HR综合面试默认 无AI纯人工，编程实操默认 纯AI
const STAGE_TYPE_MODE = { 2: 2, 3: 4, 4: 1 }
// 当前所选岗位可用的面试阶段（笔试不参与视频面试，直接过滤）
const currentStages = computed(() => ((positions.value.find(p => p.positionId === linkForm.value.positionId) || {}).stages || [])
  .filter(s => Number(s.type) !== 1))
const currentStage = computed(() => currentStages.value.find(s => s.stageId === linkForm.value.stageId) || null)
const peerPositionsReady = ref(false)
const peerStageText = computed(() => {
  if (!peerPositionsReady.value) return ''
  if (!peerPositions.value.length) return '暂未投递简历'
  return peerPositions.value
    .map(p => `${p.positionTitle || '未命名岗位'} · ${p.currentStageName || '未进入流程'}`)
    .join(' / ')
})


// 面试模式与面试官人数严格联动
const MODE_HINT = { 1: '纯AI 无需面试官，本企业成员可凭链接旁听', 2: '需选择 1 位面试官', 3: '需选择至少 2 位面试官', 4: '需选择至少 1 位面试官' }
// 发送链接时固定写明面试方式，候选人端据此进入对应流程
const MODE_LABEL = { 1: '纯AI面试', 2: 'AI+单面试官', 3: 'AI+多面试官', 4: '无AI纯人工' }
const needInterviewers = computed(() => linkForm.value.mode !== 1)

// 当前会话对方用户 ID（新会话态取 newChat）
const peerUserId = computed(() => activeConv.value?.peerId ?? newChat.value?.peerId ?? null)
// 候选人端地址：优先用构建配置，未配置时按当前访问地址同源 + /user 运行时拼接
const candidateBase = candidateAppBase()
// 链接拼接规则：候选人端统一入口页 + token（权威定义，不带其它参数）
const linkUrl = computed(() => (linkResult.value ? candidateBase + '/conference-join?token=' + linkResult.value.token : ''))
// 只有带协议头的绝对地址才能直接点击进入，相对地址一律视为不完整
const linkComplete = computed(() => /^https?:\/\//.test(linkUrl.value))

function openLinkModal() {
  const peer = peerUserId.value
  if (peer == null) { ElMessage.warning('当前会话缺少对方信息，无法发起视频面试'); return }
  linkForm.value = { peerUserId: peer, positionId: null, stageId: null, durationMinutes: 45, mode: 2 }
  generatedStageName.value = ''
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
    if (positions.value.length) {
      linkForm.value.positionId = positions.value[0].positionId
      onPositionChange()
    }
  } catch (e) {
    positions.value = []
    ElMessage.error(e?.message || '加载候选人岗位失败')
  } finally {
    positionsLoading.value = false
  }
}

// 切换岗位：优先定位候选人当前阶段（笔试阶段不参与视频面试）
function onPositionChange() {
  const pos = positions.value.find(p => p.positionId === linkForm.value.positionId) || {}
  const stages = (pos.stages || []).filter(s => Number(s.type) !== 1)
  const matched = stages.find(s => s.stageId === pos.currentStageId)
  linkForm.value.stageId = matched ? matched.stageId : (stages[0]?.stageId ?? null)
  applyStageDefaults()
}

// 按阶段类型带出默认面试方式，时长取流程模板中该阶段配置
function applyStageDefaults() {
  const stage = currentStage.value
  if (!stage) return
  if (stage.duration) linkForm.value.durationMinutes = Number(stage.duration)
  const mode = STAGE_TYPE_MODE[Number(stage.type)]
  if (mode) linkForm.value.mode = mode
  onModeChange()
}

function stageLabel(stage) {
  const type = STAGE_TYPE_LABEL[Number(stage.type)] || '面试'
  return stage.duration ? `${stage.name}（${type} · ${stage.duration}分钟）` : `${stage.name}（${type}）`
}

// 聊天头部展示会话对方全部投递岗位的当前阶段
async function loadPeerPositions() {
  const peer = peerUserId.value
  peerPositionsReady.value = false
  if (peer == null) { peerPositions.value = []; return }
  try {
    const res = await listCandidatePositions(peer)
    peerPositions.value = res.data || []
  } catch (e) {
    peerPositions.value = []
  } finally {
    peerPositionsReady.value = true
  }
}

async function generateLink() {
  if (linkForm.value.positionId == null) { ElMessage.warning('请选择面试岗位'); return }
  if (!validateMode()) return
  generating.value = true
  generatedStageName.value = currentStage.value?.name || ''
  try {
    const res = await createRoomLink({
      peerUserId: linkForm.value.peerUserId,
      positionId: linkForm.value.positionId,
      // 阶段随场次落库，面试安排/流程流转才能读到轮次
      stageId: linkForm.value.stageId,
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
  if (!linkComplete.value) {
    ElMessage.error('未配置候选人端地址，链接不完整无法发送，请在 .env 中设置 VITE_CANDIDATE_APP_URL')
    return
  }
  try {
    const company = linkResult.value.companyName || '公司'
    const position = linkResult.value.positionTitle || '岗位'
    const modeLabel = MODE_LABEL[linkResult.value.mode ?? linkForm.value.mode] || '视频面试'
    const inviteTag = generatedStageName.value ? `·${generatedStageName.value}·${modeLabel}` : `·${modeLabel}`
    // 以普通文本消息发送（type=1），与日常聊天一致，链接在气泡内可点击
    const body = { type: 1, content: `【面试邀请${inviteTag}】${company} ${position} 视频面试，请点击链接进入：${linkUrl.value}` }
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

// ---------- 发送调研问卷：选择问卷模板，生成匿名填写链接并发送到会话 ----------
const surveyOpen = ref(false)
const surveyTemplates = ref([])
const surveyLoading = ref(false)
const surveySending = ref(false)
const selectedSurveyId = ref(null)
const surveyLink = ref('')
const SURVEY_SCENE = { 1: '面试后', 2: '初筛后', 3: '录用后', 4: '淘汰后', 5: '投递简历后' }
function sceneText(v) { return SURVEY_SCENE[Number(v)] || '—' }

async function openSurveyModal() {
  const peer = peerUserId.value
  if (peer == null) { ElMessage.warning('当前会话缺少对方信息，无法发送调研问卷'); return }
  selectedSurveyId.value = null
  surveyLink.value = ''
  surveyOpen.value = true
  surveyLoading.value = true
  try {
    const res = await listSurveyTemplates()
    surveyTemplates.value = res.data || []
  } catch (e) {
    surveyTemplates.value = []
    ElMessage.error(e?.message || '加载问卷模板失败')
  } finally {
    surveyLoading.value = false
  }
}

// 链接拼接规则：候选人端统一入口页 + 匿名令牌
function surveyLinkUrl(token) {
  return candidateBase + '/survey-fill?token=' + token
}

async function sendSurveyToChat() {
  const peer = peerUserId.value
  if (peer == null || selectedSurveyId.value == null) { ElMessage.warning('请选择要发送的调研问卷'); return }
  surveySending.value = true
  try {
    const res = await sendSurvey({ candidateUserId: peer, templateId: selectedSurveyId.value })
    const info = res.data || {}
    surveyLink.value = surveyLinkUrl(info.token)
    const tplName = info.templateName || '调研问卷'
    // 以普通文本消息发送（type=1），与日常聊天一致，链接在气泡内可点击
    const body = { type: 1, content: `【满意度调研】诚邀您填写《${tplName}》：${surveyLink.value}` }
    if (activeId.value != null) body.sessionId = activeId.value
    else body.peerId = newChat.value.peerId
    await sendMessage(body)
    surveyOpen.value = false
    await afterSend()
    ElMessage.success('调研问卷已发送')
  } catch (e) {
    ElMessage.error(e?.message || '发送失败')
  } finally {
    surveySending.value = false
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

// 已在消息页时再次使用顶栏搜索，同步关键词筛选会话
watch(() => route.query.keyword, kw => {
  if (typeof kw === 'string') keyword.value = kw
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
          <div class="chat-head-info"><h2>{{activeConv.name}}<em v-if="peerStageText" class="peer-stage" :title="peerStageText">{{ peerStageText }}</em></h2><p>{{activeConv.summary}}</p></div>
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
              <a v-if="msg.attachmentUrl && !msg.broken" class="bubble img-bubble" :href="msg.attachmentUrl" target="_blank"><img :src="msg.attachmentUrl" :alt="msg.text" @error="msg.broken = true"/></a>
              <span v-else class="bubble img-bubble img-broken">图片无法加载（{{msg.text}}）</span>
              <time v-if="msg.time">{{msg.time}}</time>
            </template>
            <template v-else-if="msg.job">
              <article class="job-bubble" :title="'查看岗位：' + msg.job.title" @click="openJob(msg.job)">
                <h4>{{ msg.job.title }}</h4>
                <p class="jb-salary">{{ msg.job.salary }}</p>
                <p class="jb-meta">{{ msg.job.meta }}</p>
                <p class="jb-meta">{{ msg.job.company }}</p>
                <div class="jb-foot">已分享岗位 · 求职者可查看并投递</div>
              </article>
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
            <button title="发送图片" @click="pickImage"><Camera :size="18"/></button>
            <button title="发送文件" @click="pickFile"><Paperclip :size="18"/></button>
            <button title="发送调研文件" @click="openSurveyModal"><MessageSquareText :size="18"/></button>
            <button title="发送笔试" @click="openExamModal"><FileText :size="18"/></button>
            <button title="查看录制" @click="openRecordings"><Play :size="18"/></button>
            <button class="quick" v-if="templates.length" @click="useTemplate(templates[0].content)"><Zap :size="15"/>快捷回复</button>
            <input ref="imageInput" type="file" accept="image/*" style="display:none" @change="onImageChange" />
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
          <select v-model="linkForm.positionId" :disabled="!positions.length" @change="onPositionChange">
            <option v-if="!positions.length" :value="null">{{ positionsLoading ? '加载中…' : '该联系人暂无投递岗位' }}</option>
            <option v-for="p in positions" :key="p.applicationId" :value="p.positionId">{{ p.positionTitle }}</option>
          </select>
        </label>
        <label class="lf-row">
          <span>面试阶段</span>
          <select v-model="linkForm.stageId" :disabled="!currentStages.length" @change="applyStageDefaults">
            <option v-if="!currentStages.length" :value="null">该岗位未配置流程阶段</option>
            <option v-for="s in currentStages" :key="s.stageId" :value="s.stageId">{{ stageLabel(s) }}</option>
          </select>
        </label>
        <p v-if="currentStage" class="lf-stage-hint">已按阶段「{{ currentStage.name }}」带出面试方式与时长，可按实际情况调整。</p>
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
          <p v-if="!linkComplete" class="lf-link-warn">链接缺少候选人端域名（VITE_CANDIDATE_APP_URL 未配置），无法发送完整链接</p>
          <div class="lf-result-actions">
            <button class="lf-copy" @click="copyLink"><Copy :size="14"/>复制链接</button>
            <button class="lf-send" :disabled="!linkComplete" @click="sendLinkToChat"><Send :size="14"/>发送到会话</button>
          </div>
        </div>
      </div>
    </BaseModal>

    <BaseModal v-if="surveyOpen" title="发送调研问卷" width="480px" @close="surveyOpen=false">
      <div class="survey-form">
        <p class="sf-tip">选择要发送给「{{ activeConv?.name || '当前候选人' }}」的调研问卷，系统将生成匿名填写链接并以消息发送。</p>
        <p v-if="surveyLoading" class="sf-empty">加载中…</p>
        <p v-else-if="!surveyTemplates.length" class="sf-empty">暂无可用的调研问卷，请先在「满意度调研」中创建并启用问卷</p>
        <div v-else class="sf-list">
          <label v-for="t in surveyTemplates" :key="t.templateId" class="sf-item" :class="{ on: selectedSurveyId === t.templateId }">
            <input type="radio" :value="t.templateId" v-model="selectedSurveyId" />
            <div><b>{{ t.name }}</b><small>{{ sceneText(t.triggerScene) }} · {{ (t.questions || []).length }} 道题目</small></div>
          </label>
        </div>
        <div class="sf-foot">
          <button class="btn" @click="surveyOpen=false">取消</button>
          <button class="btn primary" :disabled="surveySending || selectedSurveyId == null" @click="sendSurveyToChat"><Send :size="14"/>{{ surveySending ? '发送中…' : '发送' }}</button>
        </div>
      </div>
    </BaseModal>

    <BaseModal v-if="examOpen" title="发送笔试" width="480px" @close="examOpen=false">
      <div class="survey-form">
        <p class="sf-tip">选择要发送给「{{ activeConv?.name || '当前候选人' }}」的试卷；若该试卷暂无有效考试安排，系统会自动创建一个 7 天内的考试安排。</p>
        <p v-if="examLoading" class="sf-empty">加载中…</p>
        <p v-else-if="!examPapers.length" class="sf-empty">该候选人投递岗位下暂无启用试卷，请先在「在线笔试 → 试卷」中创建并启用</p>
        <div v-else class="sf-list">
          <label v-for="p in examPapers" :key="p.key" class="sf-item" :class="{ on: selectedPaperKey === p.key }">
            <input type="radio" :value="p.key" v-model="selectedPaperKey" />
            <div><b>{{ p.name }}</b><small>{{ p.positionTitle }} · {{ p.durationMin }} 分钟 · {{ p.totalScore }} 分</small></div>
          </label>
        </div>
        <div class="sf-foot">
          <button class="btn" @click="examOpen=false">取消</button>
          <button class="btn primary" :disabled="examSending || !selectedPaperKey" @click="sendExamToChat"><Send :size="14"/>{{ examSending ? '发送中…' : '发送' }}</button>
        </div>
      </div>
    </BaseModal>
  </div>
</template>

<style scoped>
.messages-page{height:calc(100vh - 64px);padding:24px;display:grid;grid-template-columns:292px minmax(540px,1fr) 260px;grid-template-rows:minmax(0,1fr);gap:1px;overflow:hidden}.conversation-panel,.chat-panel,.template-panel{background:white;border:1px solid #e5ebf3}.conversation-panel{border-radius:14px 0 0 14px;overflow:hidden;display:flex;flex-direction:column}.search-row{display:flex;align-items:center;gap:8px;margin:14px;flex:none}.conversation-search{height:38px;flex:1;min-width:0;display:flex;align-items:center;gap:8px;background:#f2f5f9;border-radius:9px;padding:0 11px;color:#8999af}.conversation-search input{width:100%;border:0;outline:0;background:transparent;font-size:11px}.read-all{width:38px;height:38px;flex:none;border:1px solid #e0e7f0;border-radius:9px;background:white;color:#64748b;display:grid;place-items:center;cursor:pointer}.read-all:hover:not(:disabled){border-color:#8eb2fa;color:#2563eb}.read-all:disabled{opacity:.4;cursor:not-allowed}.conversation-list{overflow:auto;flex:1}.conversation-list article{height:77px;border-top:1px solid #e8edf4;display:grid;grid-template-columns:42px 1fr auto;gap:10px;align-items:center;padding:0 14px;position:relative;cursor:pointer}.conversation-list article.active{background:#edf4ff}.conversation-list article>div{min-width:0}.conversation-list h3{font-size:12px}.conversation-list p{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:#7d8ca1;font-size:10px;margin-top:5px}.conversation-list time{position:absolute;right:14px;top:13px;color:#98a5b7;font-size:9px}.conversation-list em{position:absolute;right:14px;bottom:11px;width:19px;height:19px;border-radius:50%;background:#2563eb;color:white;font-style:normal;font-size:9px;display:grid;place-items:center;line-height:1}.empty-list{border-top:1px solid #e8edf4;text-align:center;color:#98a5b7;font-size:10px;padding:24px 0;margin:0}.chat-panel{display:flex;flex-direction:column;min-height:0;overflow:hidden}.chat-head{height:86px;border-bottom:1px solid #e5ebf3;display:flex;align-items:center;gap:10px;padding:0 16px;flex:none}.chat-head-info{flex:1;min-width:0}.chat-head h2{font-size:14px;display:flex;gap:6px;align-items:center}.chat-head p{display:block;color:#7c8ca3;font-size:9px;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.message-stream{flex:1;overflow:auto;background:#f8fafc;padding:18px 18px 10px}.stream-loading{text-align:center;color:#98a5b7;font-size:10px}.message-row{display:flex;flex-direction:column;align-items:flex-start;margin-bottom:17px}.message-row.me{align-items:flex-end}.bubble{max-width:76%;padding:11px 13px;border-radius:5px 13px 13px 13px;background:#eaf1ff;font-size:11px;line-height:1.55;white-space:pre-wrap;word-break:break-word}.message-row.me .bubble{background:white;border:1px solid #dce5f0;border-radius:13px 5px 13px 13px}.bubble-link{color:#2563eb;text-decoration:underline;word-break:break-all;cursor:pointer}.file-bubble{display:flex;align-items:center;gap:7px;text-decoration:none;color:inherit;cursor:pointer}.file-bubble svg{color:#2563eb;flex:none}.file-bubble b{font-weight:500;font-size:11px;max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.file-bubble small{color:#2563eb;font-size:9px}.img-bubble{padding:4px}.img-bubble img{max-width:220px;max-height:180px;border-radius:8px;display:block}.message-row time{color:#9aa7b8;font-size:9px;margin-top:4px}.message-row.system{align-items:center;margin:5px 0 17px}.system-line{color:#95a2b4;font-size:9px;display:flex;align-items:center;width:80%;gap:8px}.system-line:before,.system-line:after{content:'';height:1px;background:#e5ebf3;flex:1}.chat-empty{flex:1;display:grid;place-items:center;color:#98a5b7;font-size:12px}.composer{min-height:86px;border-top:1px solid #e5ebf3;padding:8px 15px;position:relative;flex:none}.composer-tools{height:28px;display:flex;gap:5px;align-items:center}.composer-tools button{border:0;background:none;color:#64748b;padding:4px;cursor:pointer}.composer-tools .quick{margin-left:auto;display:flex;align-items:center;gap:5px;color:#2563eb;font-size:10px}.composer>div:last-child{display:flex;gap:8px;align-items:flex-end}.composer textarea{min-height:36px;max-height:96px;flex:1;border:0;outline:0;border-radius:8px;background:#f0f4f9;padding:9px 11px;font-size:11px;resize:none;font-family:inherit;line-height:1.5}.send{height:36px;border:0;border-radius:8px;background:#2563eb;color:white;padding:0 13px;display:flex;align-items:center;gap:6px;cursor:pointer}.emoji-pop{position:absolute;left:14px;bottom:80px;background:white;border:1px solid #e0e7f0;border-radius:10px;padding:8px;display:grid;grid-template-columns:repeat(8,1fr);gap:2px;box-shadow:0 8px 24px rgba(30,41,59,.14);z-index:5}.emoji-pop button{border:0;background:none;font-size:16px;padding:4px;border-radius:6px;cursor:pointer}.emoji-pop button:hover{background:#f0f4f9}.template-panel{border-radius:0 14px 14px 0;display:flex;flex-direction:column;overflow:hidden}.template-panel header{height:60px;padding:0 14px;border-bottom:1px solid #e5ebf3;display:flex;align-items:center;justify-content:space-between}.template-panel header span{font-size:12px;font-weight:700;display:flex;align-items:center;gap:7px}.template-panel header svg{color:#2563eb}.template-panel header small{color:#9aa7b8;font-size:8px}.template-list{padding:12px;display:flex;flex-direction:column;gap:9px;overflow:auto}.template-list button{border:1px solid #e0e7f0;border-radius:8px;background:white;padding:8px 9px;text-align:left;cursor:pointer}.template-list button:hover{border-color:#8eb2fa;background:#f8fbff}.template-list label{display:block;color:#8392a7;font-size:9px;margin-bottom:4px}.template-list span{font-size:10px;line-height:1.45;color:#40516a}.ai-tip{margin:3px 12px;padding:10px;background:#edf4ff;color:#2563eb;border-radius:9px;display:flex;gap:7px}.ai-tip svg{flex:none}.ai-tip p{font-size:9px;color:#6a7d99;line-height:1.45}.ai-tip b{color:#315b9e;display:block}.manage{height:42px;border:0;border-top:1px solid #e5ebf3;background:white;color:#2563eb;margin-top:auto;display:flex;align-items:center;justify-content:center;gap:6px;font-size:10px;cursor:pointer}
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
.lf-stage-hint{margin:-6px 0 0 76px;color:#9aa7b8;font-size:10px}
.lf-link-warn{margin:6px 0 0;color:#d9534f;font-size:10px}
.peer-stage{font-style:normal;font-weight:400;font-size:10px;color:#9aa7b8;min-width:0;max-width:320px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
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
.survey-form{display:flex;flex-direction:column;gap:12px}
.sf-tip{font-size:12px;color:#5b6b82;line-height:1.6}
.sf-empty{font-size:12px;color:#9aa7b8;text-align:center;padding:18px 0}
.sf-list{display:flex;flex-direction:column;gap:8px;max-height:320px;overflow:auto}
.sf-item{display:flex;align-items:center;gap:10px;border:1px solid #e0e7f0;border-radius:9px;padding:10px 12px;cursor:pointer}
.sf-item.on{border-color:#8eb2fa;background:#f2f7ff}
.sf-item input{accent-color:#2563eb}
.sf-item div{min-width:0}
.sf-item b{display:block;font-size:12px;color:#26364d}
.sf-item small{color:#8392a7;font-size:10px}
.sf-foot{display:flex;justify-content:flex-end;gap:10px;margin-top:4px}
.img-bubble.img-broken{padding:9px 12px;color:#98a5b7;font-size:10px;background:#eef2f7;max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.job-bubble{width:264px;max-width:76%;background:white;border:1px solid #dce5f0;border-radius:13px 5px 13px 13px;padding:12px 13px;cursor:pointer;transition:.18s ease}
.job-bubble:hover{border-color:#8eb2fa;box-shadow:0 6px 18px rgba(37,99,235,.1)}
.job-bubble h4{font-size:13px;font-weight:600;color:#26364d;line-height:1.4}
.jb-salary{margin-top:5px;font-size:12px;font-weight:600;color:#2563eb}
.jb-meta{margin-top:4px;font-size:11px;color:#7d8ca1;line-height:1.5}
.jb-foot{margin-top:9px;padding-top:9px;border-top:1px solid #eef2f7;font-size:11px;color:#07865e}
</style>
