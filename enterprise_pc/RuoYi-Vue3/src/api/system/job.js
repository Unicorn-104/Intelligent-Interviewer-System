import request from '@/utils/request'

// 企业端岗位列表（分页/搜索/状态过滤）
export function listJobs(query) {
  return request({
    url: '/system/enterprise/jobs/list',
    method: 'get',
    params: query
  })
}

// 岗位部门选项
export function jobDepartments() {
  return request({
    url: '/system/enterprise/jobs/departments',
    method: 'get'
  })
}

// 切换岗位状态（0下线/1在招/2暂停）
export function changeJobStatus(posId, status) {
  return request({
    url: `/system/enterprise/jobs/${posId}/status/${status}`,
    method: 'put'
  })
}

// 发布新岗位
export function createJob(data) {
  return request({
    url: '/system/enterprise/jobs',
    method: 'post',
    data
  })
}

// 岗位详情聚合
export function jobDetail(posId) {
  return request({
    url: `/system/enterprise/jobs/${posId}`,
    method: 'get'
  })
}

// 岗位流程配置读取
export function getWorkflow(posId) {
  return request({
    url: `/system/enterprise/jobs/${posId}/workflow`,
    method: 'get'
  })
}

// 保存岗位流程配置
export function saveWorkflow(posId, data) {
  return request({
    url: `/system/enterprise/jobs/${posId}/workflow`,
    method: 'put',
    data
  })
}
