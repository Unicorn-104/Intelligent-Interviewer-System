import request from '@/utils/request'

export function listJobs(params) {
  return request({
    url: '/system/enterprise/jobs',
    method: 'get',
    params
  })
}

export function listJobCategories() {
  return request({
    url: '/system/enterprise/jobs/categories',
    method: 'get'
  })
}

export function getJob(jobId) {
  return request({
    url: `/agent/v1/jobs/${jobId}`,
    method: 'get'
  })
}

export function getResumeOptions(jobId) {
  return request({
    url: `/agent/v1/jobs/${jobId}/resume-options`,
    method: 'get'
  })
}
