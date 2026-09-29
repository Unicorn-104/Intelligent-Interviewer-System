import request from '@/utils/request'

// ==================== 通知模板 ====================

export function listTemplates() {
  return request({ url: '/system/enterprise/settings/templates', method: 'get' })
}

export function addTemplate(data) {
  return request({ url: '/system/enterprise/settings/templates', method: 'post', data })
}

export function updateTemplate(id, data) {
  return request({ url: '/system/enterprise/settings/templates/' + id, method: 'put', data })
}

export function delTemplate(id) {
  return request({ url: '/system/enterprise/settings/templates/' + id, method: 'delete' })
}

// ==================== 组织架构 ====================

export function deptOverview() {
  return request({ url: '/system/enterprise/settings/depts', method: 'get' })
}

export function addDept(data) {
  return request({ url: '/system/enterprise/settings/depts', method: 'post', data })
}

export function updateDept(id, data) {
  return request({ url: '/system/enterprise/settings/depts/' + id, method: 'put', data })
}

export function delDept(id) {
  return request({ url: '/system/enterprise/settings/depts/' + id, method: 'delete' })
}

// ==================== 面试集成 ====================

export function listIntegrations() {
  return request({ url: '/system/enterprise/settings/integrations', method: 'get' })
}

export function saveIntegration(provider, data) {
  return request({ url: '/system/enterprise/settings/integrations/' + provider, method: 'put', data })
}

// ==================== 用户权限 ====================

export function listMembers() {
  return request({ url: '/system/enterprise/settings/members', method: 'get' })
}

export function changeMemberRole(userId, roleId) {
  return request({ url: '/system/enterprise/settings/members/' + userId + '/role', method: 'put', data: { roleId } })
}

export function changeMemberStatus(userId, enabled) {
  return request({ url: '/system/enterprise/settings/members/' + userId + '/status', method: 'put', data: { enabled } })
}

export function inviteMember(data) {
  return request({ url: '/system/enterprise/settings/members/invite', method: 'post', data })
}

// ==================== 数据管理 ====================

export function dataOverview() {
  return request({ url: '/system/enterprise/data/overview', method: 'get' })
}

export function exportResumes() {
  return request({ url: '/system/enterprise/data/export', method: 'post' })
}

export function backupNow() {
  return request({ url: '/system/enterprise/data/backup', method: 'post' })
}

export function cleanupPreview() {
  return request({ url: '/system/enterprise/data/cleanup', method: 'get' })
}

export function cleanupExecute(talIds) {
  return request({ url: '/system/enterprise/data/cleanup', method: 'post', data: { talIds } })
}
