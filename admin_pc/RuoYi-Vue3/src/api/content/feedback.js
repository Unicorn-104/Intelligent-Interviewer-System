import request from '@/utils/request'

// 查询反馈工单列表
export function listFeedback(query) {
  return request({
    url: '/content/feedback/list',
    method: 'get',
    params: query
  })
}

// 处理反馈工单（更新处理状态与回复内容）
export function handleFeedback(data) {
  return request({
    url: '/content/feedback/handle',
    method: 'put',
    data: data
  })
}
