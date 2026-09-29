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

// 快捷回复模板列表
export function listQuickReplies() {
  return request({
    url: '/system/im/quick-replies',
    method: 'get'
  })
}

// 保存快捷回复模板（id 为空则新增）
export function saveQuickReply(data) {
  return request({
    url: '/system/im/quick-replies',
    method: 'post',
    data: data
  })
}

// 删除快捷回复模板
export function deleteQuickReply(id) {
  return request({
    url: '/system/im/quick-replies/' + id,
    method: 'delete'
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
