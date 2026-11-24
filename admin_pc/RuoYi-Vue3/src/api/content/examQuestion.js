import request from '@/utils/request'

// 查询考试题库列表（bankType: platform=公共题库，enterprise=企业自定义题库）
export function listExamQuestion(query) {
  return request({
    url: '/content/examQuestion/list',
    method: 'get',
    params: query
  })
}

// 查询企业下拉（企业自定义题库归属选择）
export function listExamCompany() {
  return request({
    url: '/content/examQuestion/companies',
    method: 'get'
  })
}

// 企业题库总览（每个企业的题量与分类分布）
export function getCompanyOverview() {
  return request({
    url: '/content/examQuestion/companyOverview',
    method: 'get'
  })
}

// 分类统计（顶部统计卡）
export function getExamStats(query) {
  return request({
    url: '/content/examQuestion/stats',
    method: 'get',
    params: query
  })
}

// 查询题目详情
export function getExamQuestion(id) {
  return request({
    url: '/content/examQuestion/' + id,
    method: 'get'
  })
}

// 新增题目
export function addExamQuestion(data) {
  return request({
    url: '/content/examQuestion',
    method: 'post',
    data: data
  })
}

// 修改题目
export function updateExamQuestion(data) {
  return request({
    url: '/content/examQuestion',
    method: 'put',
    data: data
  })
}

// 删除题目
export function delExamQuestion(ids) {
  return request({
    url: '/content/examQuestion/' + ids,
    method: 'delete'
  })
}

// 解析上传文件（docx/xlsx/csv/txt/md），返回题目预览
export function parseExamQuestionFiles(formData) {
  return request({
    url: '/content/examQuestion/import/parse',
    method: 'post',
    headers: { 'Content-Type': 'multipart/form-data' },
    data: formData,
    timeout: 120000
  })
}

// AI 校正分类/题型/难度
export function classifyExamQuestions(items) {
  return request({
    url: '/content/examQuestion/import/classify',
    method: 'post',
    data: { items },
    timeout: 180000
  })
}

// 批量入库
export function batchAddExamQuestions(data) {
  return request({
    url: '/content/examQuestion/import/batch',
    method: 'post',
    data: data,
    timeout: 120000
  })
}

// 导入记录（文件导入 / 单条新增）
export function listImportLogs(query) {
  return request({
    url: '/content/examQuestion/import/logs',
    method: 'get',
    params: query
  })
}

// 撤销某一批次导入
export function undoImportBatch(batchId) {
  return request({
    url: '/content/examQuestion/import/logs/' + batchId + '/undo',
    method: 'post'
  })
}
