import request from '@/utils/request'

// ==================== AI 初筛与智能匹配（UC-04/05/06） ====================

// 触发岗位 AI 初筛（硬性过滤 + 加权评分，taskId 即岗位ID）
export function triggerScreening(data) {
  return request({
    url: '/enterprise/screening/tasks',
    method: 'post',
    data
  })
}

// 筛选任务列表（按岗位聚合）
export function listScreeningTasks(query) {
  return request({
    url: '/enterprise/screening/tasks',
    method: 'get',
    params: query
  })
}

// 对全部有待初筛投递的岗位发起 AI 初筛
export function screenAllPending() {
  return request({
    url: '/enterprise/screening/screen-all',
    method: 'post'
  })
}

// 历史数据补偿：按已有 AI 分析结果回写待筛选投递的评分与初筛状态
export function syncScreeningApplications() {
  return request({
    url: '/enterprise/screening/sync-applications',
    method: 'post'
  })
}

// 匹配度评分与维度明细（按综合评分降序）
export function listScreeningResults(taskId) {
  return request({
    url: `/enterprise/screening/tasks/${taskId}/results`,
    method: 'get'
  })
}

// 推荐短名单（Top N 降序）
export function getScreeningShortlist(taskId, topN) {
  return request({
    url: `/enterprise/screening/tasks/${taskId}/shortlist`,
    method: 'get',
    params: { topN }
  })
}

// AI 推荐报告（匹配点/差距点/需核实项）
export function getScreeningReport(resultId) {
  return request({
    url: `/enterprise/screening/results/${resultId}/report`,
    method: 'get'
  })
}

// 个性化招呼语（Top 3 自动生成）
export function getScreeningGreeting(resultId) {
  return request({
    url: `/enterprise/screening/results/${resultId}/greeting`,
    method: 'get'
  })
}

// HR 复核：approved=true 确认通过（可选 adjustScore 调整评分），false 驳回
export function reviewScreeningResult(resultId, data) {
  return request({
    url: `/enterprise/screening/results/${resultId}/review`,
    method: 'put',
    data
  })
}
