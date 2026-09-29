import request from '@/utils/request'

// 当前用户所属公司的招聘总览数据
export function getDashboardOverview() {
  return request({
    url: '/system/dashboard/overview',
    method: 'get'
  })
}
