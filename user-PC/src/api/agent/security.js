import request from '@/utils/request'

export function getAppSecurity() {
  return request({
    url: '/app/security',
    method: 'get'
  })
}

export function updateAppSecurityPhone(data) {
  return request({
    url: '/app/security/phone',
    method: 'put',
    data
  })
}

export function updateAppSecurityEmail(data) {
  return request({
    url: '/app/security/email',
    method: 'put',
    data
  })
}
