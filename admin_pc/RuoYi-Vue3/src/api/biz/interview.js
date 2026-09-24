import request from '@/utils/request'

// 面试管理
export function listInterview(query) {
  return request({ url: '/biz/interview/list', method: 'get', params: query })
}
export function getInterview(id) {
  return request({ url: '/biz/interview/' + id, method: 'get' })
}
export function terminateInterview(data) {
  return request({ url: '/biz/interview/terminate', method: 'put', data })
}
export function deleteInterview(id) {
  return request({ url: '/biz/interview/' + id, method: 'delete' })
}
