import request from '@/utils/request'

// aiScreen 模块
export function listAiScreen(query) {
  return request({ url: '/biz/aiScreen/list', method: 'get', params: query })
}
export function runAiScreen(data) {
  return request({ url: '/biz/aiScreen/run', method: 'post', data })
}
export function getScreenDetail(id) {
  return request({ url: '/biz/aiScreen/' + id, method: 'get' })
}
export function updateScreenStatus(data) {
  return request({ url: '/biz/aiScreen/status', method: 'put', data })
}
export function cancelAiScreen(id) {
  return request({ url: '/biz/aiScreen/cancel/' + id, method: 'post' })
}
