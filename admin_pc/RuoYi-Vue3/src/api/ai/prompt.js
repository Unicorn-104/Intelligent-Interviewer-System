import request from '@/utils/request'

// 查询提示词模板列表
export function listPrompt(query) {
  return request({
    url: '/ai/prompt/list',
    method: 'get',
    params: query
  })
}

// 查询提示词模板详细
export function getPrompt(promptId) {
  return request({
    url: '/ai/prompt/' + promptId,
    method: 'get'
  })
}

// 新增提示词模板
export function addPrompt(data) {
  return request({
    url: '/ai/prompt',
    method: 'post',
    data: data
  })
}

// 修改提示词模板
export function updatePrompt(data) {
  return request({
    url: '/ai/prompt',
    method: 'put',
    data: data
  })
}

// 发布提示词模板
export function publishPrompt(promptId) {
  return request({
    url: '/ai/prompt/publish',
    method: 'put',
    data: { promptId: promptId }
  })
}

// 查询提示词模板版本历史
export function listVersions(promptId) {
  return request({
    url: '/ai/prompt/versions/' + promptId,
    method: 'get'
  })
}
