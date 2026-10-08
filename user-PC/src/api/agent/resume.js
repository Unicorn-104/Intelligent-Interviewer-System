import request from '@/utils/request'

export function createResume(data) {
  return request({
    url: '/agent/v1/resumes',
    method: 'post',
    data
  })
}

export function getResumes() {
  return request({
    url: '/agent/v1/resumes',
    method: 'get'
  })
}

export function getResume(resumeId) {
  return request({
    url: `/agent/v1/resumes/${resumeId}`,
    method: 'get'
  })
}

export function updateResume(resumeId, data) {
  return request({
    url: `/agent/v1/resumes/${resumeId}`,
    method: 'put',
    data
  })
}

export function uploadResumeFile(resumeId, file) {
  const formData = new FormData()
  formData.append('file', file)
  return request({
    url: `/agent/v1/resumes/${resumeId}/file`,
    method: 'post',
    data: formData
  })
}

export function deleteResume(resumeId) {
  return request({
    url: `/agent/v1/resumes/${resumeId}`,
    method: 'delete'
  })
}
