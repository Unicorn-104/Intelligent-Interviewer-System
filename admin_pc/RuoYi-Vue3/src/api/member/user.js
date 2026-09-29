import request from '@/utils/request'

// 查询C端用户列表
export function listUser(query) {
  return request({
    url: '/member/user/list',
    method: 'get',
    params: query
  })
}

// 查询C端用户详情（含登录设备、登录记录）
export function getUser(userId) {
  return request({
    url: '/member/user/' + userId,
    method: 'get'
  })
}

// 修改账号状态（封禁/解封）
export function changeStatus(data) {
  return request({
    url: '/member/user/status',
    method: 'put',
    data: data
  })
}

// 注销审核
export function auditCancel(data) {
  return request({
    url: '/member/user/cancelAudit',
    method: 'put',
    data: data
  })
}

// 强制下线
export function logoutForce(userId) {
  return request({
    url: '/member/user/logout/' + userId,
    method: 'post'
  })
}
