import request from '@/utils/request'

export function createResume(data) {
  return request({
    url: '/agent/v1/resumes',
    method: 'post',
    data
  })
}
