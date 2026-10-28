import request from '@/utils/request'
import { getToken } from '@/utils/auth'

// 会话列表（before 为游标分页，可省略）
export function listSessions(before) {
  return request({
    url: '/enterprise/assistant/sessions',
    method: 'get',
    params: before == null ? {} : { before }
  })
}

// 新建会话
export function createSession() {
  return request({
    url: '/enterprise/assistant/sessions',
    method: 'post'
  })
}

// 会话消息列表（before 为游标分页，可省略）
export function listMessages(sessionId, before) {
  return request({
    url: '/enterprise/assistant/sessions/' + sessionId + '/messages',
    method: 'get',
    params: before == null ? {} : { before }
  })
}

// 发起一次回答（requestId 为客户端生成的 24 位 hex 幂等键）
export function createRun(sessionId, requestId, content) {
  return request({
    url: '/enterprise/assistant/sessions/' + sessionId + '/runs',
    method: 'post',
    data: { requestId, content }
  })
}

// 按幂等键查询请求对应的 run（found=false 表示服务端没有该请求）
export function lookupRequest(sessionId, requestId) {
  return request({
    url: '/enterprise/assistant/sessions/' + sessionId + '/requests/' + requestId,
    method: 'get'
  })
}

// 查询 run 当前状态
export function getRun(runId) {
  return request({
    url: '/enterprise/assistant/runs/' + runId,
    method: 'get'
  })
}

// 取消 run
export function cancelRun(runId) {
  return request({
    url: '/enterprise/assistant/runs/' + runId + '/cancel',
    method: 'post'
  })
}

// 删除会话
export function deleteSession(sessionId) {
  return request({
    url: '/enterprise/assistant/sessions/' + sessionId,
    method: 'delete'
  })
}

// 生成 24 位 hex 幂等键
export function genRequestId() {
  const bytes = new Uint8Array(12)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('')
}

// 解析单个 SSE 帧：只关心 event 为 run 的事件，data 多行按 SSE 规范以 \n 拼接
function parseRunFrame(frame) {
  let event = 'message'
  const dataLines = []
  for (const line of frame.split('\n')) {
    if (line.startsWith(':')) continue
    const idx = line.indexOf(':')
    const field = idx < 0 ? line : line.slice(0, idx)
    let value = idx < 0 ? '' : line.slice(idx + 1)
    if (value.startsWith(' ')) value = value.slice(1)
    if (field === 'event') event = value
    else if (field === 'data') dataLines.push(value)
  }
  if (event !== 'run' || !dataLines.length) return null
  try {
    return JSON.parse(dataLines.join('\n'))
  } catch (e) {
    return null
  }
}

// 订阅 run 的 SSE 事件流。EventSource 无法携带 Authorization 头，
// 改用 fetch + ReadableStream 手写解析；返回 close() 句柄用于取消订阅。
// chunk 可能截断帧或 \\r\\n 行尾，需缓冲剩余文本；\\r 结尾暂不归属，等下一块再判定 CRLF。
export function openRunEvents(runId, { onRun, onError, onClose }) {
  const controller = new AbortController()
  let closed = false
  const close = () => {
    if (closed) return
    closed = true
    controller.abort()
  }
  const url = import.meta.env.VITE_APP_BASE_API + '/enterprise/assistant/runs/' + runId + '/events'
  fetch(url, {
    headers: {
      Authorization: 'Bearer ' + getToken(),
      Accept: 'text/event-stream'
    },
    signal: controller.signal
  }).then(async response => {
    if (!response.ok || !response.body) {
      throw new Error('AI流式连接失败（HTTP ' + response.status + '）')
    }
    const reader = response.body.getReader()
    const decoder = new TextDecoder('utf-8')
    let buffer = ''
    for (;;) {
      const { done, value } = await reader.read()
      if (closed) return
      let raw = buffer + decoder.decode(value, { stream: true })
      // 末尾的 \r 可能是被截断的 \r\n，保留到下一块再统一换行归一
      let tail = ''
      if (raw.endsWith('\r')) {
        tail = '\r'
        raw = raw.slice(0, -1)
      }
      raw = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n')
      buffer = raw + tail
      let sep
      while ((sep = buffer.indexOf('\n\n')) >= 0) {
        const frame = buffer.slice(0, sep)
        buffer = buffer.slice(sep + 2)
        if (!frame) continue
        const run = parseRunFrame(frame)
        if (run) onRun(run)
      }
      if (done) {
        onClose()
        return
      }
    }
  }).catch(err => {
    if (closed || err?.name === 'AbortError') return
    onError(err)
    onClose()
  })
  return close
}
