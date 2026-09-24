import request from '@/utils/request'

// 查询企业认证申请列表
export function listVerify(query) {
  return request({
    url: '/member/verify/list',
    method: 'get',
    params: query
  })
}

// 企业认证审核
export function auditVerify(data) {
  return request({
    url: '/member/verify/audit',
    method: 'put',
    data: data
  })
}
