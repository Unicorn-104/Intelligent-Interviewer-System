import request from '@/utils/request'

// 查询AI模型列表
export function listModel(query) {
  return request({
    url: '/ai/model/list',
    method: 'get',
    params: query
  })
}

// 模型状态统计
export function statsModel() {
  return request({
    url: '/ai/model/stats',
    method: 'get'
  })
}

// 查询AI模型详细
export function getModel(modelId) {
  return request({
    url: '/ai/model/' + modelId,
    method: 'get'
  })
}

// 新增AI模型
export function addModel(data) {
  return request({
    url: '/ai/model',
    method: 'post',
    data: data
  })
}

// 修改AI模型
export function updateModel(data) {
  return request({
    url: '/ai/model',
    method: 'put',
    data: data
  })
}

// 删除AI模型
export function delModel(modelIds) {
  return request({
    url: '/ai/model/' + modelIds,
    method: 'delete'
  })
}

// 修改模型状态
export function changeModelStatus(modelId, status) {
  return request({
    url: '/ai/model/changeStatus',
    method: 'put',
    data: { modelId, status }
  })
}

// 测试AI模型连接
export function testModel(data) {
  return request({
    url: '/ai/model/test',
    method: 'post',
    data: data
  })
}
