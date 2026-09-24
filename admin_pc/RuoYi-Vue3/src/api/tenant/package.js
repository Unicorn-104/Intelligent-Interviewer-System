import request from '@/utils/request'

// 查询套餐列表
export function listPackage(query) {
  return request({
    url: '/tenant/package/list',
    method: 'get',
    params: query
  })
}

// 查询套餐详情
export function getPackage(packageId) {
  return request({
    url: '/tenant/package/' + packageId,
    method: 'get'
  })
}

// 新增套餐
export function addPackage(data) {
  return request({
    url: '/tenant/package',
    method: 'post',
    data: data
  })
}

// 修改套餐
export function updatePackage(data) {
  return request({
    url: '/tenant/package',
    method: 'put',
    data: data
  })
}

// 删除套餐
export function delPackage(packageIds) {
  return request({
    url: '/tenant/package/' + packageIds,
    method: 'delete'
  })
}
