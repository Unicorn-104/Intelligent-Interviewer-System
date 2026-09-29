import request from '@/utils/request'

export function listJobs(params) {
  return request({
    url: '/agent/v1/jobs',
    method: 'get',
    params
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
