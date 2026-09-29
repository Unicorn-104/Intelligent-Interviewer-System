import request from '@/utils/request'

// resumeParse 模块
export function listResumeParse(query) {
  return request({ url: '/biz/resumeParse/list', method: 'get', params: query })
}
export function parseResumeFile(data) {
  return request({
    url: '/biz/resumeParse/parse',
    method: 'post',
    data,
    headers: { 'Content-Type': 'multipart/form-data' }
  })
}
export function getParseDetail(id) {
  return request({ url: '/biz/resumeParse/' + id, method: 'get' })
}
export function rescanResume(id) {
  return request({ url: '/biz/resumeParse/rescan/' + id, method: 'put' })
}
export function deleteParsed(id) {
  return request({ url: '/biz/resumeParse/' + id, method: 'delete' })
}
