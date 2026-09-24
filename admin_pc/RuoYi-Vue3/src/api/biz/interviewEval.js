import request from '@/utils/request'

// interviewEval 模块
export function listInterviewEval(query) {
  return request({ url: '/biz/interviewEval/list', method: 'get', params: query })
}
export function getInterviewEval(id) {
  return request({ url: '/biz/interviewEval/' + id, method: 'get' })
}
export function submitEval(data) {
  return request({ url: '/biz/interviewEval/submit', method: 'post', data })
}
export function batchFinalize(data) {
  return request({ url: '/biz/interviewEval/finalize', method: 'post', data })
}
export function deleteEval(id) {
  return request({ url: '/biz/interviewEval/' + id, method: 'delete' })
}
