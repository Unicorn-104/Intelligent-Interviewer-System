import request from '@/utils/request'

// 查询岗位列表
export function listJob(query) {
  return request({
    url: '/biz/job/list',
    method: 'get',
    params: query
  })
}

// 审核岗位（通过发布 / 违规下架）
export function auditJob(data) {
  return request({
    url: '/biz/job/audit',
    method: 'put',
    data: data
  })
}
