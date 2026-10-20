import request from '@/utils/request'

// 简历库
export function listResume(query) {
  return request({ url: '/biz/resume/list', method: 'get', params: query })
}
export function getResume(id) {
  return request({ url: '/biz/resume/' + id, method: 'get' })
}
export function addResume(data) {
  return request({ url: '/biz/resume', method: 'post', data: data })
}
export function updateResume(data) {
  return request({ url: '/biz/resume', method: 'put', data: data })
}
export function delResume(ids) {
  return request({ url: '/biz/resume/' + ids, method: 'delete' })
}
export function exportResume(id) {
  return request({ url: '/biz/resume/export/' + id, method: 'post' })
}

// 简历解析
export function listResumeParse(query) {
  return request({ url: '/biz/resumeParse/list', method: 'get', params: query })
}
export function parseResumeFile(data) {
  return request({ url: '/biz/resumeParse/parse', method: 'post', data: data, responseType: 'blob' })
}
export function getParseDetail(id) {
  return request({ url: '/biz/resumeParse/' + id, method: 'get' })
}
export function rescanResume(id) {
  return request({ url: '/biz/resumeParse/rescan/' + id, method: 'put' })
}

// AI初筛
export function listAiScreen(query) {
  return request({ url: '/biz/aiScreen/list', method: 'get', params: query })
}
export function runAiScreen(data) {
  return request({ url: '/biz/aiScreen/run', method: 'post', data: data })
}
export function getScreenDetail(id) {
  return request({ url: '/biz/aiScreen/' + id, method: 'get' })
}
export function updateScreenStatus(data) {
  return request({ url: '/biz/aiScreen/status', method: 'put', data: data })
}

// 预约调度
export function listSchedule(query) {
  return request({ url: '/biz/schedule/list', method: 'get', params: query })
}
export function createSchedule(data) {
  return request({ url: '/biz/schedule', method: 'post', data: data })
}
export function updateSchedule(data) {
  return request({ url: '/biz/schedule', method: 'put', data: data })
}
export function cancelSchedule(id) {
  return request({ url: '/biz/schedule/' + id, method: 'delete' })
}
export function rescheduleInterview(data) {
  return request({ url: '/biz/schedule/reschedule', method: 'put', data: data })
}

// 面试评估
export function listInterviewEval(query) {
  return request({ url: '/biz/interviewEval/list', method: 'get', params: query })
}
export function getInterviewEval(id) {
  return request({ url: '/biz/interviewEval/' + id, method: 'get' })
}
export function submitEval(data) {
  return request({ url: '/biz/interviewEval/submit', method: 'post', data: data })
}
export function batchFinalize(data) {
  return request({ url: '/biz/interviewEval/finalize', method: 'post', data: data })
}

// 候选人管理
export function listCandidate(query) {
  return request({ url: '/biz/candidate/list', method: 'get', params: query })
}
export function getCandidate(id) {
  return request({ url: '/biz/candidate/' + id, method: 'get' })
}
export function updateCandidateStatus(data) {
  return request({ url: '/biz/candidate/status', method: 'put', data: data })
}
export function addCandidateTag(data) {
  return request({ url: '/biz/candidate/tag', method: 'post', data: data })
}
export function batchUpdateTag(data) {
  return request({ url: '/biz/candidate/batchTag', method: 'put', data: data })
}
// 候选人状态变更历史
export function getCandidateLogs(id) {
  return request({ url: '/biz/candidate/' + id + '/logs', method: 'get' })
}
// 候选人统计概览
export function getCandidateSummary() {
  return request({ url: '/biz/candidate/summary', method: 'get' })
}
// 批量打标签
export function batchTags(data) {
  return request({ url: '/biz/candidate/batchTags', method: 'put', data: data })
}
