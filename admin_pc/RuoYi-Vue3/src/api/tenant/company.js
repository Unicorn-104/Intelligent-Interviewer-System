import request from '@/utils/request'

// 查询企业列表
export function listCompany(query) {
  return request({
    url: '/tenant/company/list',
    method: 'get',
    params: query
  })
}

// 查询企业详情
export function getCompany(companyId) {
  return request({
    url: '/tenant/company/' + companyId,
    method: 'get'
  })
}

// 新增企业
export function addCompany(data) {
  return request({
    url: '/tenant/company',
    method: 'post',
    data: data
  })
}

// 修改企业
export function updateCompany(data) {
  return request({
    url: '/tenant/company',
    method: 'put',
    data: data
  })
}

// 删除企业
export function delCompany(companyIds) {
  return request({
    url: '/tenant/company/' + companyIds,
    method: 'delete'
  })
}

// 修改企业状态（停用/启用）
export function changeCompanyStatus(companyId, status) {
  return request({
    url: '/tenant/company/changeStatus',
    method: 'put',
    data: {
      companyId: companyId,
      status: status
    }
  })
}

// 企业审核状态统计
export function statsCompany() {
  return request({
    url: '/tenant/company/stats',
    method: 'get'
  })
}

// 企业审核
export function auditCompany(data) {
  return request({
    url: '/tenant/company/audit',
    method: 'put',
    data: data
  })
}

// 撤销审核（重置为待审核）
export function revokeCompany(companyId) {
  return request({
    url: '/tenant/company/revoke',
    method: 'put',
    data: { companyId: companyId }
  })
}
