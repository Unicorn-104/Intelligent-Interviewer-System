import request from '@/utils/request'

// 企业自助注册（无需登录）
export function registerEnterprise(data) {
  return request({
    url: '/register/enterprise',
    method: 'post',
    data,
    headers: {
      isToken: false,
      repeatSubmit: false
    }
  })
}

// 当前账号企业审核状态
export function getAccountStatus() {
  return request({
    url: '/enterprise/account/status',
    method: 'get'
  })
}
