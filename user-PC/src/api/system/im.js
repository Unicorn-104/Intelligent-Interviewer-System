import request from '@/utils/request'
import { messageAttachmentUploadName } from '@/utils/agentMessage'

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

export function uploadImAttachment(file) {
  const formData = new FormData()
  formData.append('file', file, messageAttachmentUploadName(file.name))
  return request({
    // 与企业端共用现有上传接口，兼容已部署的后端版本；上传结果再写入 IM 消息。
    url: '/common/upload',
    method: 'post',
    data: formData,
    timeout: 120000
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
