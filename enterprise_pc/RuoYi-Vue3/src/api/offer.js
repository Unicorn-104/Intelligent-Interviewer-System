import request from '@/utils/request'

// Offer 列表（状态过滤 + 分页）
export function listOffers(query) {
  return request({
    url: '/enterprise/offer/list',
    method: 'get',
    params: query
  })
}

// Offer 详情（含审批节点）
export function getOffer(offerId) {
  return request({
    url: `/enterprise/offer/${offerId}`,
    method: 'get'
  })
}

// 创建 Offer 草稿
export function createOffer(data) {
  return request({
    url: '/enterprise/offer/create',
    method: 'post',
    data
  })
}

// 发送录用意向书与入职指引邮件（senderType: company-企业邮箱 / personal-个人邮箱）
export function sendOffer(offerId, senderType) {
  return request({
    url: `/enterprise/offer/${offerId}/send`,
    method: 'post',
    data: { senderType }
  })
}

// 企业候选人选项（创建表单用）
export function listCandidateOptions() {
  return request({
    url: '/enterprise/offer/candidate-options',
    method: 'get'
  })
}

// 邮箱与发信设置回显（企业邮箱 + 个人 SMTP 配置，授权码仅掩码）
export function getMailProfile() {
  return request({
    url: '/enterprise/offer/mail-profile',
    method: 'get'
  })
}

// 保存个人 SMTP 发信配置（password 留空或为掩码时后端保留原值）
export function saveMailProfile(data) {
  return request({
    url: '/enterprise/offer/mail-profile',
    method: 'post',
    data
  })
}
