import request from '@/utils/request'

// ==================== 题库 ====================

export function listQuestions(query) {
  return request({
    url: '/enterprise/exam/questions',
    method: 'get',
    params: query
  })
}

export function getQuestion(questionId) {
  return request({
    url: `/enterprise/exam/questions/${questionId}`,
    method: 'get'
  })
}

export function createQuestion(data) {
  return request({
    url: '/enterprise/exam/questions',
    method: 'post',
    data
  })
}

export function updateQuestion(questionId, data) {
  return request({
    url: `/enterprise/exam/questions/${questionId}`,
    method: 'put',
    data
  })
}

export function deleteQuestion(questionId) {
  return request({
    url: `/enterprise/exam/questions/${questionId}`,
    method: 'delete'
  })
}

// ==================== 试卷 ====================

export function listPapers(positionId) {
  return request({
    url: '/enterprise/exam/papers',
    method: 'get',
    params: { positionId }
  })
}

export function getPaper(paperId) {
  return request({
    url: `/enterprise/exam/papers/${paperId}`,
    method: 'get'
  })
}

export function createPaper(data) {
  return request({
    url: '/enterprise/exam/papers',
    method: 'post',
    data
  })
}

export function updatePaper(paperId, data) {
  return request({
    url: `/enterprise/exam/papers/${paperId}`,
    method: 'put',
    data
  })
}

export function deletePaper(paperId) {
  return request({
    url: `/enterprise/exam/papers/${paperId}`,
    method: 'delete'
  })
}

export function drawPreview(rule) {
  return request({
    url: '/enterprise/exam/papers/draw-preview',
    method: 'post',
    data: rule
  })
}

// ==================== 考试安排 ====================

export function listSchedules(query) {
  return request({
    url: '/enterprise/exam/schedules',
    method: 'get',
    params: query
  })
}

export function getSchedule(scheduleId) {
  return request({
    url: `/enterprise/exam/schedules/${scheduleId}`,
    method: 'get'
  })
}

export function createSchedule(data) {
  return request({
    url: '/enterprise/exam/schedules',
    method: 'post',
    data
  })
}

export function updateSchedule(scheduleId, data) {
  return request({
    url: `/enterprise/exam/schedules/${scheduleId}`,
    method: 'put',
    data
  })
}

export function cancelSchedule(scheduleId) {
  return request({
    url: `/enterprise/exam/schedules/${scheduleId}/cancel`,
    method: 'post'
  })
}

// ==================== 笔试通知 ====================

export function saveNotifyConfig(scheduleId, data) {
  return request({
    url: `/enterprise/exam/schedules/${scheduleId}/notify-config`,
    method: 'put',
    data
  })
}

export function listNotifyTargets(scheduleId) {
  return request({
    url: `/enterprise/exam/schedules/${scheduleId}/notify-targets`,
    method: 'get'
  })
}

export function sendExamNotify(scheduleId, data) {
  return request({
    url: `/enterprise/exam/schedules/${scheduleId}/notify`,
    method: 'post',
    data
  })
}

// ==================== 双机位监考 ====================

export function listOngoingExams() {
  return request({
    url: '/enterprise/exam/monitor/ongoing',
    method: 'get'
  })
}

export function getExamProctorToken(recordId) {
  return request({
    url: `/enterprise/exam/monitor/record/${recordId}/token`,
    method: 'get'
  })
}

// ==================== 成绩报告与判分 ====================

export function listExamResults(query) {
  return request({
    url: '/enterprise/exam/results',
    method: 'get',
    params: query
  })
}

export function getExamResult(recordId) {
  return request({
    url: `/enterprise/exam/results/${recordId}`,
    method: 'get'
  })
}

export function gradeSubjective(recordId, data) {
  return request({
    url: `/enterprise/exam/results/${recordId}/subjective`,
    method: 'put',
    data
  })
}
