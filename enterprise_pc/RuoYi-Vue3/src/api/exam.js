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

/** 补全空解析（已有解析不覆盖，平台题库也可补全） */
export function fillQuestionAnalysis(questionId, analysis) {
  return request({
    url: `/enterprise/exam/questions/${questionId}/analysis`,
    method: 'put',
    data: { analysis }
  })
}

/** AI 补全答案解析，并校验题目是否正确 */
export function aiExamAnalysis(data) {
  return request({
    url: '/enterprise/exam/questions/ai-analysis',
    method: 'post',
    data,
    timeout: 90000
  })
}

export function getExamAnalysisSettings() {
  return request({ url: '/system/enterprise/settings/integrations', method: 'get' })
}

export function updateExamAnalysisSettings(forceRegenerate) {
  return request({
    url: '/system/enterprise/settings/integrations',
    method: 'put',
    data: { forceRegenerate }
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

/** 启用/禁用试卷（status：1 启用，0 禁用） */
export function updatePaperStatus(paperId, status) {
  return request({
    url: `/enterprise/exam/papers/${paperId}/status`,
    method: 'put',
    data: { status }
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

/** Agent 命题规划：生成知识点覆盖计划（可在前端编辑） */
export function aiPlanPaper(data) {
  return request({
    url: '/enterprise/exam/papers/ai-plan',
    method: 'post',
    data,
    timeout: 120000
  })
}

/** Agent 组卷预览：AI 生成题目或从现有题库抽题（不落库） */
export function aiPreviewPaper(data) {
  return request({
    url: '/enterprise/exam/papers/ai-preview',
    method: 'post',
    data,
    timeout: 600000
  })
}

/** 保存 Agent 组卷结果（题目可编辑；saveToBank=true 时写入企业题库） */
export function aiSavePaper(data) {
  return request({
    url: '/enterprise/exam/papers/ai-save',
    method: 'post',
    data,
    timeout: 60000
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
