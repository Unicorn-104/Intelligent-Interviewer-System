import request from '@/utils/request'
import { getToken } from '@/utils/auth'

export function listAiSessions(before) {
  return request({
    url: '/app/ai/sessions',
    method: 'get',
    params: before ? { before } : undefined
  })
}

export function createAiSession() {
  return request({
    url: '/app/ai/sessions',
    method: 'post',
    headers: { repeatSubmit: false }
  })
}

export function listAiMessages(sessionId, before) {
  return request({
    url: `/app/ai/sessions/${encodeURIComponent(sessionId)}/messages`,
    method: 'get',
    params: before ? { before } : undefined
  })
}

export function startAiRun(sessionId, data) {
  return request({
    url: `/app/ai/sessions/${encodeURIComponent(sessionId)}/runs`,
    method: 'post',
    data,
    timeout: 45000,
    headers: { repeatSubmit: false }
  })
}

export function cancelAiRun(runId) {
  return request({
    url: `/app/ai/runs/${encodeURIComponent(runId)}/cancel`,
    method: 'post',
    headers: { repeatSubmit: false }
  })
}

export async function streamAiRun(runId, after, onEvent, signal) {
  const baseUrl = import.meta.env.VITE_APP_BASE_API || ''
  const response = await fetch(`${baseUrl}/app/ai/runs/${encodeURIComponent(runId)}/events?after=${after}`, {
    headers: {
      Accept: 'text/event-stream',
      Authorization: `Bearer ${getToken()}`
    },
    signal
  })
  if (!response.ok) {
    throw new Error(`AI 实时连接失败（${response.status}）`)
  }
  if (!response.body) {
    throw new Error('当前浏览器不支持 AI 实时回答')
  }

  const reader = response.body.getReader()
  const decoder = new TextDecoder('utf-8')
  let buffer = ''
  let eventId = 0
  let eventType = 'message'
  let eventData = []

  const emit = () => {
    if (!eventData.length) return
    const data = JSON.parse(eventData.join('\n'))
    onEvent({ id: eventId, type: eventType, data })
    eventId = 0
    eventType = 'message'
    eventData = []
  }

  const consume = (line) => {
    if (line === '') {
      emit()
      return
    }
    if (line.startsWith(':')) return
    const separator = line.indexOf(':')
    const field = separator < 0 ? line : line.slice(0, separator)
    let value = separator < 0 ? '' : line.slice(separator + 1)
    if (value.startsWith(' ')) value = value.slice(1)
    if (field === 'id') eventId = Number.parseInt(value, 10) || 0
    if (field === 'event') eventType = value
    if (field === 'data') eventData.push(value)
  }

  while (true) {
    const { value, done } = await reader.read()
    buffer += decoder.decode(value || new Uint8Array(), { stream: !done })
    const lines = buffer.split(/\r?\n/)
    buffer = lines.pop() || ''
    lines.forEach(consume)
    if (done) {
      if (buffer) consume(buffer)
      emit()
      break
    }
  }
}
