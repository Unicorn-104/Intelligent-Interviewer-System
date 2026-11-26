const TITLE = /^【笔试邀请(?:·([^】]*))?】/
const URL_MATCH = /https?:\/\/[^\s<>"】]+|\/exam\?[^\s<>"】]+/

/**
 * 解析企业 HR 发送的笔试邀请文本。
 * 只返回合法的 scheduleId，页面用本地 /exam 路由打开，不直接信任消息中的域名。
 */
export function parseExamInvitation(content) {
  if (typeof content !== 'string') return null
  const text = content.trim()
  const tag = TITLE.exec(text)
  if (!tag) return null
  const urlMatch = URL_MATCH.exec(text)
  if (!urlMatch) return null
  let target
  try {
    target = new URL(urlMatch[0], 'http://local')
  } catch {
    return null
  }
  if (!target.pathname.replace(/\/+$/, '').endsWith('/exam')) return null
  const rawId = target.searchParams.get('scheduleId') || ''
  if (!/^\d+$/.test(rawId)) return null
  const scheduleId = Number(rawId)
  if (!Number.isSafeInteger(scheduleId) || scheduleId <= 0) return null
  const paperName = (tag[1] || '').trim() || '在线笔试'
  const detail =
    text
      .slice(tag[0].length, urlMatch.index)
      .trim()
      .replace(/[：:\s]*请点击链接进入[：:]?\s*$/, '')
      .replace(/[，,。；;\s：:]+$/, '')
      .trim() || '请查看笔试安排并进入考试'
  return { scheduleId, paperName, detail }
}
