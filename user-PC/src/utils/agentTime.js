const beijingFormatter = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'Asia/Shanghai',
  year: 'numeric', month: '2-digit', day: '2-digit',
  hour: '2-digit', minute: '2-digit', hourCycle: 'h23'
})

export function parseMessageDate(value) {
  if (value === null || value === undefined || value === '') return null
  let normalized = value
  if (typeof value === 'string') {
    const text = value.trim()
    const local = text.match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2})(\.\d{1,3})?)?$/)
    if (local) {
      const [, year, month, day, hour, minute, second = '00', fraction = ''] = local
      normalized = `${year}-${month}-${day}T${hour}:${minute}:${second}${fraction}+08:00`
    } else if (/^\d{10}$|^\d{13}$/.test(text)) {
      normalized = Number(text) * (text.length === 10 ? 1000 : 1)
    } else if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:?\d{2})$/i.test(text)) {
      normalized = text
    } else {
      return null
    }
  } else if (typeof value === 'number') {
    normalized = Math.abs(value) < 1e12 ? value * 1000 : value
  } else if (!(value instanceof Date)) {
    return null
  }
  const date = new Date(normalized)
  return Number.isNaN(date.getTime()) ? null : date
}

function beijingParts(value) {
  const date = parseMessageDate(value)
  return date ? Object.fromEntries(beijingFormatter.formatToParts(date).map(part => [part.type, part.value])) : null
}

export function formatMessageTime(value) {
  const parts = beijingParts(value)
  return parts ? `${parts.month}/${parts.day} ${parts.hour}:${parts.minute}` : '--'
}

export function formatShortTime(value, now = new Date()) {
  const parts = beijingParts(value)
  if (!parts) return '--'
  const today = beijingParts(now)
  return today && parts.year === today.year && parts.month === today.month && parts.day === today.day
    ? `${parts.hour}:${parts.minute}`
    : `${parts.month}-${parts.day}`
}
