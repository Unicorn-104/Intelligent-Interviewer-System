import request from '@/utils/request'

// schedule 模块
export function listSchedule(query) {
  return request({ url: '/biz/schedule/list', method: 'get', params: query })
}
export function createSchedule(data) {
  return request({ url: '/biz/schedule', method: 'post', data })
}
export function updateSchedule(data) {
  return request({ url: '/biz/schedule', method: 'put', data })
}
export function cancelSchedule(id) {
  return request({ url: '/biz/schedule/' + id, method: 'delete' })
}
export function rescheduleInterview(data) {
  return request({ url: '/biz/schedule/reschedule', method: 'put', data })
}
export function enterInterview(id) {
  return request({ url: '/biz/schedule/enter/' + id, method: 'post' })
}
