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

// 导入岗位文件：上传 JD 文档并解析为岗位草稿（单文件，AI 解析耗时较长需放宽超时）
export function parseJdDocument(file) {
  const data = new FormData()
  data.append('file', file)
  return request({
    url: '/enterprise/jd/parse-document',
    method: 'post',
    headers: { 'Content-Type': 'multipart/form-data', repeatSubmit: false },
    data,
    timeout: 120000
  })
}

// 覆盖更新岗位内容（导入解析确认命中重复岗位时使用，不改动岗位状态与流程模板）
export function updateJob(posId, data) {
  return request({
    url: `/system/enterprise/jobs/${posId}`,
    method: 'put',
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

// 删除草稿岗位（仅草稿状态可删除）
export function deleteDraftJob(posId) {
  return request({
    url: `/system/enterprise/jobs/${posId}`,
    method: 'delete'
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
