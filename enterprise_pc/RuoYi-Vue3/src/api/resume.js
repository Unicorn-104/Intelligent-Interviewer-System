import request from '@/utils/request'

// 企业端简历批量导入（PDF，按手机号/邮箱匹配已注册候选人账号）
export function batchImportResumes(formData) {
  return request({
    url: '/enterprise/resumes/batch-import',
    method: 'post',
    data: formData,
    headers: { 'Content-Type': 'multipart/form-data' },
    timeout: 120000
  })
}
