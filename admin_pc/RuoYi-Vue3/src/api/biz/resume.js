import request from '@/utils/request'

// resume 模块
export function listResume(query) {
  return request({ url: '/biz/resume/list', method: 'get', params: query })
}
export function getResumeSummary() {
  return request({ url: '/biz/resume/summary', method: 'get' })
}
export function getResume(id) {
  return request({ url: '/biz/resume/' + id, method: 'get' })
}
export function addResume(data) {
  return request({ url: '/biz/resume', method: 'post', data })
}
export function updateResume(data) {
  return request({ url: '/biz/resume', method: 'put', data })
}
export function delResume(ids) {
  return request({ url: '/biz/resume/' + ids, method: 'delete' })
}
export function exportResume(id) {
  return request({ url: '/biz/resume/export/' + id, method: 'post' })
}
export function downloadResume(id) {
  return request({ url: '/biz/resume/download/' + id, method: 'get', responseType: 'blob' })
}
