import request from '@/utils/request'

// 问卷模板列表：all=true 返回含停用模板的完整列表（配置页用），否则仅启用模板
export function listSurveyTemplates(all) {
  return request({ url: '/enterprise/survey/templates', method: 'get', params: { all } })
}

// 新增本企业问卷模板
export function createSurveyTemplate(data) {
  return request({ url: '/enterprise/survey/templates', method: 'post', data })
}

// 修改本企业问卷模板（含触发场景与启停用）
export function updateSurveyTemplate(templateId, data) {
  return request({ url: '/enterprise/survey/templates/' + templateId, method: 'put', data })
}

// 启停用本企业问卷模板
export function updateSurveyTemplateStatus(templateId, status) {
  return request({ url: `/enterprise/survey/templates/${templateId}/status`, method: 'put', data: { status } })
}

// 删除本企业问卷模板
export function deleteSurveyTemplate(templateId) {
  return request({ url: '/enterprise/survey/templates/' + templateId, method: 'delete' })
}

// 调研结果汇总：均分、评分分布、发送与回收统计、回收明细
export function getSurveyResults(params) {
  return request({ url: '/enterprise/survey/results', method: 'get', params })
}

// 向候选人发送调研问卷，返回匿名链接令牌与发送信息
export function sendSurvey(data) {
  return request({ url: '/enterprise/survey/send', method: 'post', data })
}
