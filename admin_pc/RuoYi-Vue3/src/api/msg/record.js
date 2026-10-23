import request from '@/utils/request'

// 查询消息发送记录列表
export function listRecord(query) {
  return request({
    url: '/msg/record/list',
    method: 'get',
    params: query
  })
}

// 重新触发消息发送
export function resendRecord(recordId) {
  return request({
    url: '/msg/record/resend',
    method: 'post',
    data: {
      recordId: recordId
    }
  })
}

// 发送记录统计：总数 / 成功 / 失败
export function statsRecord(query) {
  return request({
    url: '/msg/record/stats',
    method: 'get',
    params: query
  })
}
