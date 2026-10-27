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

// 评估报告详情（五维评分 + 评语 + 回放链接）
export function getInterviewReview(sessionId) {
  return request({
    url: `/enterprise/review/${sessionId}`,
    method: 'get'
  })
}

// HR 终审确认通过（recommendation：1-强烈推荐，2-推荐，3-待定，4-不推荐）
export function confirmInterviewReview(sessionId, data) {
  return request({
    url: `/enterprise/review/${sessionId}/confirm`,
    method: 'put',
    data
  })
}

// HR 调整五维评分后确认通过（重算综合分，状态记为已调整）
export function adjustInterviewReview(sessionId, data) {
  return request({
    url: `/enterprise/review/${sessionId}/adjust`,
    method: 'put',
    data
  })
}

// 非终面通过后按级联规则创建下一轮预约
export function cascadeInterviewReview(sessionId) {
  return request({
    url: `/enterprise/review/${sessionId}/cascade`,
    method: 'post'
  })
}

// 面试官某周空闲时段（默认本周）
export function listInterviewerSlots(weekStart) {
  return request({
    url: '/enterprise/interviewer-slots',
    method: 'get',
    params: { weekStart }
  })
}

// 整周覆盖保存面试官空闲时段
export function saveInterviewerSlots(weekStart, slots) {
  return request({
    url: '/enterprise/interviewer-slots',
    method: 'post',
    data: { weekStart, slots }
  })
}

// HR 终审驳回淘汰（候选人归档人才库并发送感谢信）
export function rejectInterviewReview(sessionId, data) {
  return request({
    url: `/enterprise/review/${sessionId}/reject`,
    method: 'put',
    data
  })
}
