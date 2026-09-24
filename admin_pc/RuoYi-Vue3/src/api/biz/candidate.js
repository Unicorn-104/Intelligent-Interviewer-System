import request from '@/utils/request'

// 候选人管理
export function listCandidate(query) {
  return request({ url: '/biz/candidate/list', method: 'get', params: query })
}
export function getCandidate(id) {
  return request({ url: '/biz/candidate/' + id, method: 'get' })
}
export function addCandidate(data) {
  return request({ url: '/biz/candidate', method: 'post', data })
}
export function updateCandidate(data) {
  return request({ url: '/biz/candidate', method: 'put', data })
}
export function delCandidate(ids) {
  return request({ url: '/biz/candidate/' + ids, method: 'delete' })
}
export function updateCandidateStatus(data) {
  return request({ url: '/biz/candidate/status', method: 'put', data })
}
export function addCandidateTag(data) {
  return request({ url: '/biz/candidate/tag', method: 'post', data })
}
export function batchUpdateTag(data) {
  return request({ url: '/biz/candidate/batchTag', method: 'put', data })
}
