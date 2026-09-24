import request from '@/utils/request'

// 当前用户的会话列表
export function listSessions() {
  return request({
    url: '/system/im/sessions',
    method: 'get'
  })
}

// 指定会话的消息列表
export function listMessages(sessionId) {
  return request({
    url: '/system/im/sessions/' + sessionId + '/messages',
    method: 'get'
  })
}

// 发送消息（sessionId 为空时按 peerId 查找或创建会话）
export function sendMessage(data) {
  return request({
    url: '/system/im/messages',
    method: 'post',
    data: data
  })
}

// 清空指定会话未读数
export function readSession(sessionId) {
  return request({
    url: '/system/im/sessions/' + sessionId + '/read',
    method: 'put'
  })
}

// 清空全部会话未读数
export function readAll() {
  return request({
    url: '/system/im/read-all',
    method: 'put'
  })
}

// 当前用户未读总数
export function unreadCount() {
  return request({
    url: '/system/im/unread-count',
    method: 'get'
  })
}

// 通用文件上传（发送文件/图片消息前先上传）
export function uploadFile(data) {
  return request({
    url: '/common/upload',
    method: 'post',
    data: data,
    headers: { 'Content-Type': 'multipart/form-data' }
  })
}
