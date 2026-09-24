import request from '@/utils/request'

// 查询帮助文章列表
export function listHelp(query) {
  return request({
    url: '/content/help/list',
    method: 'get',
    params: query
  })
}

// 查询帮助文章详细
export function getHelp(articleId) {
  return request({
    url: '/content/help/' + articleId,
    method: 'get'
  })
}

// 新增帮助文章
export function addHelp(data) {
  return request({
    url: '/content/help',
    method: 'post',
    data: data
  })
}

// 修改帮助文章
export function updateHelp(data) {
  return request({
    url: '/content/help',
    method: 'put',
    data: data
  })
}

// 删除帮助文章
export function delHelp(articleIds) {
  return request({
    url: '/content/help/' + articleIds,
    method: 'delete'
  })
}
