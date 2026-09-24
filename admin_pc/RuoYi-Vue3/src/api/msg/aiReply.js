import request from '@/utils/request'

export function getAiConfig() {
  return request({ url: '/msg/aiConfig', method: 'get' })
}
export function updateAiConfig(data) {
  return request({ url: '/msg/aiConfig', method: 'put', data: data })
}
export function listAiRecord(query) {
  return request({ url: '/msg/aiRecord/list', method: 'get', params: query })
}
export function listAiKnowledge() {
  return request({ url: '/msg/aiKnowledge/list', method: 'get' })
}
export function addAiKnowledge(data) {
  return request({ url: '/msg/aiKnowledge', method: 'post', data: data })
}
export function delAiKnowledge(id) {
  return request({ url: '/msg/aiKnowledge/' + id, method: 'delete' })
}
export function updateAiKnowledge(data) {
  return request({ url: '/msg/aiKnowledge', method: 'put', data: data })
}
