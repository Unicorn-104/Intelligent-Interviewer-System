import request from '@/utils/request'

export function createApplication(data) {
  return request({
    url: '/agent/v1/applications',
    method: 'post',
    data
  })
}

export function listApplications(params) {
  return request({
    url: '/agent/v1/applications',
    method: 'get',
    params
  })
}

export function getApplication(applicationId) {
  return request({
    url: `/agent/v1/applications/${applicationId}`,
    method: 'get'
  })
}
