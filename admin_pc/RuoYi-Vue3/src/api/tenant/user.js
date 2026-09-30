import request from '@/utils/request'

// 查询企业用户列表
export function listTenantUser(query) {
  return request({
    url: '/tenant/user/list',
    method: 'get',
    params: query
  })
}
