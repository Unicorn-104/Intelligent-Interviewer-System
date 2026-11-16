import request from '@/utils/request'

// 发送上下文：投递状态、阶段与通过情况、笔试前置、在途面试预约
export function getSendContext(query) {
  return request({
    url: '/enterprise/send/context',
    method: 'get',
    params: query
  })
}

// 多轮面试批量排期
export function inviteInterviewStages(data) {
  return request({
    url: '/enterprise/interview/invite/stages',
    method: 'post',
    data
  })
}
