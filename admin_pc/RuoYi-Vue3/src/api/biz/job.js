import request from '@/utils/request'

// 查询岗位列表
export function listJob(query) {
  return request({
    url: '/biz/job/list',
    method: 'get',
    params: query
  })
}

// 审核岗位（通过发布 / 违规下架 / 恢复上架）
export function auditJob(data) {
  return request({
    url: '/biz/job/audit',
    method: 'put',
    data: data
  })
}

// 岗位详情（含 JD）
export function getJobDetail(posId) {
  return request({
    url: '/biz/job/' + posId,
    method: 'get'
  })
}

// 岗位状态变更历史
export function getJobLogs(posId) {
  return request({
    url: '/biz/job/' + posId + '/logs',
    method: 'get'
  })
}
