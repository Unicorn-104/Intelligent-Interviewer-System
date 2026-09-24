import request from '@/utils/request'

// 查询面试题库列表
export function listQuestion(query) {
  return request({
    url: '/content/question/list',
    method: 'get',
    params: query
  })
}

// 查询面试题详细（含选项 options 与解析 analysis）
export function getQuestion(questionId) {
  return request({
    url: '/content/question/' + questionId,
    method: 'get'
  })
}

// 新增面试题
export function addQuestion(data) {
  return request({
    url: '/content/question',
    method: 'post',
    data: data
  })
}

// 修改面试题
export function updateQuestion(data) {
  return request({
    url: '/content/question',
    method: 'put',
    data: data
  })
}

// 删除面试题
export function delQuestion(questionIds) {
  return request({
    url: '/content/question/' + questionIds,
    method: 'delete'
  })
}
