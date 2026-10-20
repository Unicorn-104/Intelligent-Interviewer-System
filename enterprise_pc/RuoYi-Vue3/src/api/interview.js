import request from '@/utils/request'

// 面试安排列表（企业隔离，支持状态与时间范围过滤）
export function listInterviews(query) {
  return request({
    url: '/enterprise/interview/list',
    method: 'get',
    params: query
  })
}

// 面试改期（原时段释放回退可用池，新时段占用）
export function rescheduleInterview(appointmentId, newStartTime) {
  return request({
    url: `/enterprise/interview/${appointmentId}/reschedule`,
    method: 'put',
    data: { newStartTime }
  })
}

// 通知候选人（发送面试提醒消息）
export function remindInterview(appointmentId) {
  return request({
    url: `/enterprise/interview/${appointmentId}/remind`,
    method: 'post'
  })
}

// 确认/取消面试安排（status：1-已确认，2-已取消）
export function updateInterviewStatus(appointmentId, status) {
  return request({
    url: `/enterprise/interview/${appointmentId}/status`,
    method: 'put',
    data: { status }
  })
}
