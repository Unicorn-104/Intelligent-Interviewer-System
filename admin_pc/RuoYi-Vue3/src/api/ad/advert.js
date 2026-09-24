import request from '@/utils/request'

// 查询广告列表
export function listAdvert(query) {
  return request({
    url: '/ad/advert/list',
    method: 'get',
    params: query
  })
}

// 查询广告详情（含素材与投放配置）
export function getAdvert(advertId) {
  return request({
    url: '/ad/advert/' + advertId,
    method: 'get'
  })
}

// 新增广告
export function addAdvert(data) {
  return request({
    url: '/ad/advert',
    method: 'post',
    data: data
  })
}

// 修改广告
export function updateAdvert(data) {
  return request({
    url: '/ad/advert',
    method: 'put',
    data: data
  })
}

// 删除广告
export function delAdvert(advertIds) {
  return request({
    url: '/ad/advert/' + advertIds,
    method: 'delete'
  })
}

// 修改广告状态（暂停 / 恢复投放）
export function changeAdvertStatus(advertId, status) {
  return request({
    url: '/ad/advert/changeStatus',
    method: 'put',
    data: {
      advertId: advertId,
      status: status
    }
  })
}

// 查询广告统计数据（曝光 / 点击趋势）
export function advertStats(advertId) {
  return request({
    url: '/ad/advert/stats/' + advertId,
    method: 'get'
  })
}
