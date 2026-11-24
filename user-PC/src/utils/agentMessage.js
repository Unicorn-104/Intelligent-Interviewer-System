import { resolveResourceUrl } from './resourceUrl.js'
import { parseMessageDate } from './agentTime.js'

const messageFieldLabels = {
  title: '标题', name: '名称', positionName: '应聘岗位', positionTitle: '应聘岗位',
  company: '企业', companyName: '企业', content: '内容', text: '内容', message: '内容',
  description: '说明', reason: '原因', reviewNote: '处理说明', address: '地点',
  location: '地点', startTime: '开始时间', endTime: '结束时间'
}

function cardText(value) {
  return typeof value === 'string' ? value.trim() : ''
}

function positiveMessageId(value) {
  if (!['string', 'number'].includes(typeof value)) return ''
  const text = String(value ?? '')
  return /^\d+$/.test(text) && Number.isSafeInteger(Number(text)) && Number(text) > 0 ? text : ''
}

function messageNumber(value) {
  return ['string', 'number'].includes(typeof value) ? Number(value) : NaN
}

function messageDateText(value) {
  const date = parseMessageDate(value)
  if (!date) return ''
  return new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Asia/Shanghai', year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hourCycle: 'h23'
  }).format(date)
}

function messageTimeRange(start, end) {
  const startText = messageDateText(start)
  const endText = messageDateText(end)
  if (startText && endText && startText.slice(0, 10) === endText.slice(0, 10)) {
    return `${startText} ～ ${endText.slice(11)}`
  }
  return [startText, endText].filter(Boolean).join(' ～ ')
}

function fallbackMessageCard(raw) {
  const fields = Object.entries(messageFieldLabels).flatMap(([key, label]) => {
    const value = cardText(raw?.[key])
    return value ? [{ label, value }] : []
  })
  return {
    kind: 'notice', label: '消息通知', title: cardText(raw?.title) || '收到一条消息',
    fields: fields.filter(field => field.label !== '标题'),
    description: fields.length ? '' : '此消息格式暂不支持展示，请联系发送方确认具体内容。'
  }
}

export function messageContentCard(message) {
  const content = typeof message?.content === 'string' ? message.content.trim() : ''
  const type = Number(message?.type)
  if ([2, 3].includes(type) || !content) return null
  if (content.startsWith('【面试邀请')) {
    const closing = content.indexOf('】')
    if (closing < 0) return null
    const parts = messageLinkParts(content.slice(closing + 1))
    let action
    for (const part of parts) {
      if (!part.href) continue
      const url = new URL(part.href)
      const tokens = url.searchParams.getAll('token')
      if (['/conference-join', '/agent/conference-entry', '/user/conference-join', '/user/agent/conference-entry'].includes(url.pathname)
        && tokens.length === 1 && /^[a-zA-Z0-9_-]{16,256}$/.test(tokens[0])) {
        action = { to: `/conference-join?token=${encodeURIComponent(tokens[0])}`, label: '查看面试安排' }
        break
      }
    }
    return {
      kind: 'interview', label: '面试邀请', title: content.slice(1, closing).replace(/^面试邀请\s*[·：:]?\s*/, '') || '邀请你参加面试',
      description: parts.filter(part => !part.href).map(part => part.text).join('').trim(), action,
      links: parts.filter(part => part.href && !/token=/i.test(part.href)),
      fields: [], footnote: '请提前确认时间，并完成设备检测'
    }
  }
  let raw = message?.content
  try {
    for (let depth = 0; depth < 2 && typeof raw === 'string'; depth++) raw = JSON.parse(raw)
  } catch {
    return [5, 6].includes(type) ? fallbackMessageCard(null) : null
  }
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  if (raw.kind === 'job_card' && messageNumber(raw.version) === 1) {
    const positionId = positiveMessageId(raw.positionId)
    const title = cardText(raw.title)
    if (!positionId || !title) return fallbackMessageCard(raw)
    const salaryMin = messageNumber(raw.salaryMin)
    const salaryMax = messageNumber(raw.salaryMax)
    const validMin = Number.isFinite(salaryMin) && salaryMin > 0
    const validMax = Number.isFinite(salaryMax) && salaryMax > 0
    const salary = validMin && validMax ? `${salaryMin.toLocaleString('zh-CN')}–${salaryMax.toLocaleString('zh-CN')} 元/月`
      : validMin ? `${salaryMin.toLocaleString('zh-CN')} 元/月起` : validMax ? `最高 ${salaryMax.toLocaleString('zh-CN')} 元/月` : '薪资面议'
    return {
      kind: 'job', label: 'HR 分享的岗位', title, highlight: salary,
      subtitle: cardText(raw.company) || '企业信息待完善', fields: [],
      tags: [cardText(raw.city) || '城市不限', cardText(raw.experience) || '经验不限',
        ({ 1: '中专', 2: '大专', 3: '本科', 4: '硕士', 5: '博士' })[messageNumber(raw.education)] || '学历不限'],
      action: { to: `/job-detail?id=${positionId}`, label: '查看职位详情' },
      footnote: '岗位信息以详情页当前状态为准'
    }
  }
  if (raw.kind === 'interview_reschedule' && messageNumber(raw.version) === 1) {
    const statuses = {
      pending: ['改期申请已提交', '等待处理', 'pending'], approved: ['改期申请已同意', '已同意', 'success'],
      rejected: ['改期申请未通过', '未通过', 'muted'], changed: ['面试时间已更新', '时间已变更', 'success']
    }
    const statusKey = cardText(raw.status)
    const [title, status, tone] = Object.hasOwn(statuses, statusKey)
      ? statuses[statusKey] : ['面试改期通知', '待确认', 'muted']
    const original = messageTimeRange(raw.originalStartTime, raw.originalEndTime)
    const updated = messageTimeRange(raw.newStartTime, raw.newEndTime)
    const fields = [
      { label: '原面试时间', value: original },
      { label: ['approved', 'changed'].includes(raw.status) ? '新面试时间' : '申请调整至', value: updated },
      { label: '改期原因', value: cardText(raw.reason) },
      { label: '处理说明', value: cardText(raw.reviewNote) }
    ].filter(field => field.value)
    return {
      kind: 'reschedule', label: '面试安排', title, status, tone, fields,
      subtitle: cardText(raw.positionName), footnote: '以上时间均为北京时间'
    }
  }
  return fallbackMessageCard(raw)
}

export function messagePreview(value) {
  const card = messageContentCard({ content: value })
  if (card) return `[${card.label}] ${card.kind === 'job' ? card.title : card.subtitle || card.title}`
  return typeof value === 'string' ? value : ''
}

export function resolveMessageAttachment(value, apiBase, origin) {
  return resolveResourceUrl(value, apiBase, origin)
}

export function messageAttachmentPath(value) {
  const raw = String(value || '').trim()
  if (!raw || /[\u0000-\u001f\u007f]/.test(raw)) return ''
  try {
    const url = new URL(raw, 'https://attachment.invalid')
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.hash) return ''
    const profilePath = url.pathname.match(/^\/(?:dev-api\/|prod-api\/)?(profile\/.+)$/)
    return profilePath ? `/${profilePath[1]}` : ''
  } catch {
    return ''
  }
}

export function uploadedMessageAttachmentPath(response) {
  for (const data of [response, response?.data]) {
    for (const value of [data?.fileName, data?.url]) {
      const path = messageAttachmentPath(value)
      if (path) return path
    }
  }
  return ''
}

export function messageAttachmentUploadName(originalName, id = globalThis.crypto.randomUUID()) {
  const extension = String(originalName || '').split('.').pop().toLowerCase()
  return `${id}.${extension}`
}

export function messageAttachmentError(status, payload) {
  const code = Number(payload?.code || status)
  if (code === 401) return '登录状态已过期，请重新登录后打开附件'
  if (code === 403) return '当前账号无权访问该附件，请联系发送方确认'
  if (status === 404 || /No static resource|FileNotFound|文件不存在|资源不存在/i.test(String(payload?.msg || ''))) {
    return '当前后端未找到该附件，请联系发送方重新发送或检查文件存储配置'
  }
  return '附件暂时无法读取，请稍后重试或联系发送方重新发送'
}

export function isImageMessage(message) {
  if (!message.attachmentUrl) return false
  if (Number(message.type) === 2) return true
  if (Number(message.type) !== 3) return false
  try {
    return /\.(?:jpe?g|png|gif|bmp|webp)$/i.test(new URL(message.attachmentUrl, 'https://attachment.invalid').pathname)
  } catch {
    return false
  }
}

export function messageLinkParts(value) {
  const text = String(value || '')
  const parts = []
  const matcher = /https?:\/\/[^\s<>"'\u0000-\u001f，。！？；：、（）【】《》「」]+/gi
  let offset = 0
  for (const match of text.matchAll(matcher)) {
    let candidate = match[0].replace(/[.,!?;:]+$/, '')
    while (candidate.endsWith(')') && candidate.split(')').length > candidate.split('(').length) {
      candidate = candidate.slice(0, -1)
    }
    while (candidate.endsWith(']') && candidate.split(']').length > candidate.split('[').length) {
      candidate = candidate.slice(0, -1)
    }
    try {
      const url = new URL(candidate)
      if (!url.hostname || url.username || url.password) continue
      if (match.index > offset) parts.push({ text: text.slice(offset, match.index) })
      parts.push({ text: candidate, href: url.href })
      offset = match.index + candidate.length
    } catch {}
  }
  if (offset < text.length) parts.push({ text: text.slice(offset) })
  return parts
}

export function insertMessageEmoji(text, emoji, start = text.length, end = start, limit = 1000) {
  const next = `${text.slice(0, start)}${emoji}${text.slice(end)}`
  return next.length <= limit ? { text: next, cursor: start + emoji.length } : null
}
