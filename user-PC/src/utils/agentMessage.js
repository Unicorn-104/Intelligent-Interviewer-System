export function resolveMessageAttachment(value, apiBase, origin) {
  const raw = String(value || '').trim()
  if (!raw || /[\u0000-\u001f\u007f]/.test(raw)) return ''
  try {
    const url = new URL(raw, origin)
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) return ''
    const profilePath = url.pathname.match(/^\/(?:dev-api\/|prod-api\/)?(profile\/.+)$/)
    if (profilePath) {
      const base = String(apiBase || '').replace(/\/$/, '')
      return new URL(`${base}/${profilePath[1]}${url.search}`, origin).href
    }
    return url.href
  } catch {
    return ''
  }
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
