import request from '@/utils/request'

// 查询消息模板列表
export function listTemplate(query) {
  return request({
    url: '/msg/template/list',
    method: 'get',
    params: query
  })
}

// 查询消息模板详情
export function getTemplate(templateId) {
  return request({
    url: '/msg/template/' + templateId,
    method: 'get'
  })
}

// 新增消息模板
export function addTemplate(data) {
  return request({
    url: '/msg/template',
    method: 'post',
    data: data
  })
}

// 修改消息模板
export function updateTemplate(data) {
  return request({
    url: '/msg/template',
    method: 'put',
    data: data
  })
}

// 删除消息模板
export function delTemplate(templateIds) {
  return request({
    url: '/msg/template/' + templateIds,
    method: 'delete'
  })
}
