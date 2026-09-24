import request from '@/utils/request'

// 查询评估评分卡列表
export function listScorecard(query) {
  return request({
    url: '/ai/scorecard/list',
    method: 'get',
    params: query
  })
}

// 查询评估评分卡详情（含评分维度）
export function getScorecard(cardId) {
  return request({
    url: '/ai/scorecard/' + cardId,
    method: 'get'
  })
}

// 新增评估评分卡
export function addScorecard(data) {
  return request({
    url: '/ai/scorecard',
    method: 'post',
    data: data
  })
}

// 修改评估评分卡
export function updateScorecard(data) {
  return request({
    url: '/ai/scorecard',
    method: 'put',
    data: data
  })
}

// 删除评估评分卡
export function delScorecard(cardIds) {
  return request({
    url: '/ai/scorecard/' + cardIds,
    method: 'delete'
  })
}
