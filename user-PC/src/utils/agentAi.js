export const aiActions = [
  { value: 'job_recommendation', label: '岗位推荐', prompt: '根据我选定的简历推荐合适的真实在招岗位，并说明匹配点和差距。' },
  { value: 'resume_analysis', label: '简历分析', prompt: '分析我选定简历的优势和不足，给出具体、可执行的修改建议，不要编造经历。' },
  { value: 'interview_preparation', label: '面试准备', prompt: '根据我选择的已投递岗位和该次投递使用的简历，分析面试重点、练习问题并制定准备计划。' },
  { value: 'writing_polish', label: '写作润色', prompt: '请在保留事实、不编造经历的前提下，润色下面这段文字：\n' }
]

export function aiPlainText(value) {
  return String(value ?? '')
    .replace(/\r\n?/g, '\n')
    .replace(/^\s*```[^\n]*\n?/gm, '')
    .replace(/^\s{0,3}#{1,6}\s+/gm, '')
    .replace(/^\s{0,3}>\s?/gm, '')
    .replace(/^\s*([-*_])(?:\s*\1){2,}\s*$/gm, '')
    .replace(/!\[([^\]]*)\]\([^\n)]*\)/g, '$1')
    .replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, '$1（$2）')
    .replace(/\*\*([^*\n]+)\*\*|__([^_\n]+)__/g, '$1$2')
    .replace(/(?<!\w)\*([^*\n]+)\*(?!\w)/g, '$1')
    .replace(/`([^`\n]+)`/g, '$1')
    .replace(/^(\s*)[-*+]\s+/gm, '$1• ')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

export function readAiCards(value) {
  try {
    const cards = typeof value === 'string' ? JSON.parse(value) : value
    return Array.isArray(cards) ? cards.filter(card => card && /^\d+$/.test(String(card.positionId)) && Number(card.positionId) > 0) : []
  } catch {
    return []
  }
}

export function readAiMessage(message) {
  return { ...message, content: String(message.content || ''), cards: readAiCards(message.cardsJson ?? message.cards) }
}

export function aiRunError(code) {
  return ({
    OUTPUT_LIMIT: '回答已达到长度上限，请将问题拆分后重试',
    CONNECTION_FAILED: 'AI 服务连接失败，请稍后重新生成',
    TIMEOUT: 'AI 服务响应超时，请稍后重试；已收到的内容是未完成回答，不代表简历读取失败',
    STEP_LIMIT: '本次查找已达到上限，请明确岗位方向后重试',
    BUSY: 'AI 助手繁忙，请稍后重试'
  })[code] || '本次回答未完成，请稍后重试'
}

export function aiContextPayload(action, resume, application) {
  if (!['chat', ...aiActions.map(item => item.value)].includes(action)) throw new Error('请选择有效的助手功能')
  if (['job_recommendation', 'resume_analysis'].includes(action) && !resume?.id) throw new Error('请先选择一份简历')
  if (action === 'interview_preparation' && !application?.id) throw new Error('请先选择一个已投递岗位')
  const useApplication = application && ['chat', 'interview_preparation'].includes(action)
  return { action, resumeId: useApplication ? application.resumeId : resume?.id || undefined, applicationId: useApplication ? application.id : undefined }
}

export async function consumeAiEvents(body, onEvent) {
  const reader = body.getReader()
  const decoder = new TextDecoder('utf-8')
  let buffer = ''
  let eventId = 0
  let eventType = 'message'
  let eventData = []
  let terminal = false
  const emit = () => {
    if (eventData.length) {
      const data = JSON.parse(eventData.join('\n'))
      if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error('AI 响应格式不正确')
      onEvent({ id: eventId, type: eventType, data })
      if (eventType === 'done' && ['COMPLETED', 'FAILED', 'CANCELLED'].includes(data.status)) terminal = true
    }
    eventId = 0
    eventType = 'message'
    eventData = []
  }
  const consume = line => {
    if (!line) return emit()
    if (line.startsWith(':')) return
    const separator = line.indexOf(':')
    const field = separator < 0 ? line : line.slice(0, separator)
    let value = separator < 0 ? '' : line.slice(separator + 1)
    if (value.startsWith(' ')) value = value.slice(1)
    if (field === 'id') eventId = Number.parseInt(value, 10) || 0
    if (field === 'event') eventType = value
    if (field === 'data') eventData.push(value)
  }
  try {
    while (true) {
      const { value, done } = await reader.read()
      buffer += decoder.decode(value || new Uint8Array(), { stream: !done })
      if (buffer.length + eventData.join('').length > 200000) throw new Error('AI 单条事件过长')
      let separator
      while ((separator = buffer.indexOf('\n')) >= 0) {
        consume(buffer.slice(0, separator).replace(/\r$/, ''))
        buffer = buffer.slice(separator + 1)
        if (terminal) return
      }
      if (done) {
        if (buffer) consume(buffer.replace(/\r$/, ''))
        emit()
        break
      }
    }
  } finally {
    try { await reader.cancel() } catch {}
    reader.releaseLock()
  }
}

export function receiveAiRun(api, id, after, onEvent, signal, options = {}) {
  return new Promise((resolve, reject) => {
    const connection = new AbortController()
    let finished = false
    let pollTimer
    let deadlineTimer
    const finish = (metadata, failure) => {
      if (finished) return
      finished = true
      clearTimeout(pollTimer)
      clearTimeout(deadlineTimer)
      signal?.removeEventListener('abort', abort)
      connection.abort()
      if (failure) reject(failure)
      else resolve(metadata)
    }
    const abort = () => finish(null, new DOMException('读取已中止', 'AbortError'))
    const terminal = metadata => ['COMPLETED', 'FAILED', 'CANCELLED'].includes(metadata?.status)
    const poll = async () => {
      try {
        const response = await api.getAiRun(id)
        if (finished) return
        if (terminal(response.data)) return finish(response.data)
      } catch {}
      if (!finished) pollTimer = setTimeout(poll, options.pollIntervalMs ?? 5000)
    }
    if (signal?.aborted) return abort()
    signal?.addEventListener('abort', abort, { once: true })
    pollTimer = setTimeout(poll, options.pollIntervalMs ?? 5000)
    deadlineTimer = setTimeout(() => finish(null, new Error('实时连接长时间未结束，请恢复回答或停止；不会重复发送问题')), options.connectionTimeoutMs ?? 300000)
    Promise.resolve().then(() => {
      if (finished) return
      return api.streamAiRun(id, after, event => {
        if (finished) return
        onEvent(event)
        if (event.type === 'done' && terminal(event.data)) finish(event.data)
      }, connection.signal)
    }).then(() => finish(null), failure => finish(null, failure))
  })
}
