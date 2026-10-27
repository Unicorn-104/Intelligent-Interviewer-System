import request from '@/utils/request'

// 人才库检索（关键词/岗位方向/标签/归档来源 + 分页）
export function listTalents(query) {
  return request({
    url: '/enterprise/talent/list',
    method: 'get',
    params: query
  })
}

// 人才库筛选项（岗位方向 + 标签）
export function getTalentOptions() {
  return request({
    url: '/enterprise/talent/options',
    method: 'get'
  })
}

// 候选人详情（档案 + 标签 + 简历基础）
export function getTalentDetail(talId) {
  return request({
    url: `/enterprise/talent/${talId}`,
    method: 'get'
  })
}

// 待初筛岗位：各岗位尚未经过 AI 初筛的投递数量
export function listUnscreenedPositions() {
  return request({
    url: '/enterprise/talent/unscreened/positions',
    method: 'get'
  })
}

// 待初筛投递人选（岗位/关键词 + 分页）
export function listUnscreenedApplicants(query) {
  return request({
    url: '/enterprise/talent/unscreened/applicants',
    method: 'get',
    params: query
  })
}

// 对指定岗位的待初筛投递发起 AI 初筛
export function screenUnscreenedApplicants(data) {
  return request({
    url: '/enterprise/talent/unscreened/screen',
    method: 'post',
    data
  })
}

// 简历智能解析结果（结构化字段 + 完整度检查）
export function getTalentResume(talId) {
  return request({
    url: `/enterprise/talent/${talId}/resume`,
    method: 'get'
  })
}

// 主动归档 / 取消归档
export function archiveTalent(talId, archived) {
  return request({
    url: `/enterprise/talent/${talId}/archive`,
    method: 'put',
    data: { archived }
  })
}

// 一键转投递（为候选人创建投递记录）
export function reapplyTalent(talId, positionId) {
  return request({
    url: `/enterprise/talent/${talId}/reapply`,
    method: 'post',
    data: { positionId }
  })
}

// 落选关怀通知（批量写入系统消息）
export function careNotifyTalent(data) {
  return request({
    url: '/enterprise/talent/care-notify',
    method: 'post',
    data
  })
}

// 复用已有面试调度模块的发起邀约接口
export function inviteInterview(data) {
  return request({
    url: '/enterprise/interview/invite',
    method: 'post',
    data
  })
}

// 批量更新候选人流程状态（候选人管理的状态管理）
export function updateTalentStatus(talIds, status) {
  return request({
    url: '/enterprise/talent/status',
    method: 'put',
    data: { talIds, status }
  })
}

// 批量为候选人添加标签（写入 t_tal_tag）
export function batchTalentTags(talIds, tagName) {
  return request({
    url: '/enterprise/talent/tags/batch',
    method: 'post',
    data: { talIds, tagName, source: 1 }
  })
}
