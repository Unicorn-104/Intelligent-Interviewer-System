import request from '@/utils/request'

// 查询API配额列表
export function listQuota(query) {
  return request({
    url: '/ai/quota/list',
    method: 'get',
    params: query
  })
}

// 调整API配额
export function adjustQuota(data) {
  return request({
    url: '/ai/quota/adjust',
    method: 'put',
    data: data
  })
}

// 查询配额近30天使用明细
export function usageDetail(quotaId) {
  return request({
    url: '/ai/quota/usage/' + quotaId,
    method: 'get'
  })
}
