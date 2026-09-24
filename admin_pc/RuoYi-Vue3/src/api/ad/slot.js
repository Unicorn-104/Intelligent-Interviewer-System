import request from '@/utils/request'

// 查询广告位列表
export function listAdSlot(query) {
  return request({
    url: '/ad/slot/list',
    method: 'get',
    params: query
  })
}

// 查询广告位详情（含展示规则配置）
export function getAdSlot(slotId) {
  return request({
    url: '/ad/slot/' + slotId,
    method: 'get'
  })
}

// 新增广告位
export function addAdSlot(data) {
  return request({
    url: '/ad/slot',
    method: 'post',
    data: data
  })
}

// 修改广告位
export function updateAdSlot(data) {
  return request({
    url: '/ad/slot',
    method: 'put',
    data: data
  })
}

// 删除广告位
export function delAdSlot(slotIds) {
  return request({
    url: '/ad/slot/' + slotIds,
    method: 'delete'
  })
}

// 修改广告位启用状态
export function changeAdSlotStatus(slotId, status) {
  return request({
    url: '/ad/slot/changeStatus',
    method: 'put',
    data: {
      slotId: slotId,
      status: status
    }
  })
}
