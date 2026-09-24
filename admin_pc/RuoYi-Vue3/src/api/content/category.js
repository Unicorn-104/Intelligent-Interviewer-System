import request from '@/utils/request'

// 查询职位分类列表（不分页，直接返回全部数据）
export function listCategory(query) {
  return request({
    url: '/content/category/list',
    method: 'get',
    params: query
  })
}

// 查询职位分类详细
export function getCategory(categoryId) {
  return request({
    url: '/content/category/' + categoryId,
    method: 'get'
  })
}

// 新增职位分类
export function addCategory(data) {
  return request({
    url: '/content/category',
    method: 'post',
    data: data
  })
}

// 修改职位分类
export function updateCategory(data) {
  return request({
    url: '/content/category',
    method: 'put',
    data: data
  })
}

// 删除职位分类
export function delCategory(categoryIds) {
  return request({
    url: '/content/category/' + categoryIds,
    method: 'delete'
  })
}
