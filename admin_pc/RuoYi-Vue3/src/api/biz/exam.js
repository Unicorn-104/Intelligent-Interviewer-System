import request from '@/utils/request'

// 查询考核环境配置
export function getExamConfig() {
  return request({
    url: '/biz/exam/config',
    method: 'get'
  })
}

// 保存考核环境配置
export function updateExamConfig(data) {
  return request({
    url: '/biz/exam/config',
    method: 'put',
    data: data
  })
}

// 查询考核记录列表
export function listExamRecord(query) {
  return request({
    url: '/biz/exam/record/list',
    method: 'get',
    params: query
  })
}
