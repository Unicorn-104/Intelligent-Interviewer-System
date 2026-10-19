import request from '@/utils/request'

export function listJobs(params) {
  return request({
    url: '/agent/v1/jobs',
    method: 'get',
    params
  })
}

export function listJobCategories() {
  return request({
    url: '/agent/v1/jobs/categories',
    method: 'get'
  })
}

export function listJobFilterOptions() {
  return request({
    url: '/agent/v1/jobs/filter-options',
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
