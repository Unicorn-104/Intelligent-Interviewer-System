import request from '@/utils/request'

// 查询客服配置
export function getServiceConfig() {
  return request({
    url: '/content/service/config',
    method: 'get'
  })
}

// 修改客服配置
export function updateServiceConfig(data) {
  return request({
    url: '/content/service/config',
    method: 'put',
    data: data
  })
}
