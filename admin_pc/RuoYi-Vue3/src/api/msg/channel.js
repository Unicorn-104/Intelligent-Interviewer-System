import request from '@/utils/request'

// 查询通知渠道列表
export function listChannel(query) {
  return request({
    url: '/msg/channel/list',
    method: 'get',
    params: query
  })
}

// 修改通知渠道
export function updateChannel(data) {
  return request({
    url: '/msg/channel',
    method: 'put',
    data: data
  })
}

// 新增通知渠道
export function addChannel(data) {
  return request({
    url: '/msg/channel',
    method: 'post',
    data: data
  })
}

// 删除通知渠道
export function delChannel(channelId) {
  return request({
    url: '/msg/channel/' + channelId,
    method: 'delete'
  })
}

// 启用 / 停用通知渠道
export function toggleChannel(data) {
  return request({
    url: '/msg/channel/toggle',
    method: 'put',
    data: data
  })
}
