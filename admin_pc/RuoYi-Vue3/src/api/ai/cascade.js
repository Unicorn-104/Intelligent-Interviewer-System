import request from '@/utils/request'

// 查询级联规则列表
export function listCascade(query) {
  return request({
    url: '/ai/cascade/list',
    method: 'get',
    params: query
  })
}

// 查询级联规则详情
export function getCascade(ruleId) {
  return request({
    url: '/ai/cascade/' + ruleId,
    method: 'get'
  })
}

// 新增级联规则
export function addCascade(data) {
  return request({
    url: '/ai/cascade',
    method: 'post',
    data: data
  })
}

// 修改级联规则
export function updateCascade(data) {
  return request({
    url: '/ai/cascade',
    method: 'put',
    data: data
  })
}

// 删除级联规则
export function delCascade(ruleIds) {
  return request({
    url: '/ai/cascade/' + ruleIds,
    method: 'delete'
  })
}
