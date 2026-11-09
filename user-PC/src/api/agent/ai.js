import request from '@/utils/request'
import { getToken } from '@/utils/auth'
import { consumeAiEvents } from '@/utils/agentAi'

export function renameAiSession(sessionId, title) {
  return request({ url: `/app/ai/sessions/${encodeURIComponent(sessionId)}/rename`, method: 'post', data: { title }, headers: { repeatSubmit: false } })
}

export function pinAiSession(sessionId, pinned) {
  return request({ url: `/app/ai/sessions/${encodeURIComponent(sessionId)}/pin`, method: 'post', data: { pinned }, headers: { repeatSubmit: false } })
}

export function deleteAiSession(sessionId) {
  return request({ url: `/app/ai/sessions/${encodeURIComponent(sessionId)}`, method: 'delete' })
}

export function getAiRun(runId) {
  return request({ url: `/app/ai/runs/${encodeURIComponent(runId)}`, method: 'get' })
}

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
  if (!response.headers.get('content-type')?.includes('text/event-stream')) {
    const result = await response.json().catch(() => ({}))
    throw new Error(result.msg || 'AI 实时连接未返回有效事件流，请重新登录或稍后重试')
  }
  await consumeAiEvents(response.body, onEvent)
}
