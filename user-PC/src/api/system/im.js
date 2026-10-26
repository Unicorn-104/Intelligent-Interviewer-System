import request from '@/utils/request'

export function listImSessions() {
  return request({
    url: '/system/im/sessions',
    method: 'get'
  })
}

export function listImMessages(sessionId) {
  return request({
    url: `/system/im/sessions/${sessionId}/messages`,
    method: 'get'
  })
}

export function sendImMessage(data) {
  return request({
    url: '/system/im/messages',
    method: 'post',
    data
  })
}

export function markImSessionRead(sessionId) {
  return request({
    url: `/system/im/sessions/${sessionId}/read`,
    method: 'put',
    headers: { repeatSubmit: false }
  })
}

export function getImUnreadCount() {
  return request({
    url: '/system/im/unread-count',
    method: 'get'
  })
}
