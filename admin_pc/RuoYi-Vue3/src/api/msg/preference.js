import request from '@/utils/request'

export function listPreference(query) {
  return request({ url: '/msg/preference/list', method: 'get', params: query })
}
export function getPreference(id) {
  return request({ url: '/msg/preference/' + id, method: 'get' })
}
export function updatePreference(data) {
  return request({ url: '/msg/preference', method: 'put', data: data })
}
export function toggleChannel(data) {
  return request({ url: '/msg/preference/toggleChannel', method: 'put', data: data })
}
export function toggleType(data) {
  return request({ url: '/msg/preference/toggleType', method: 'put', data: data })
}
