import request from '@/utils/request'

const AUTH_REQUEST_TIMEOUT = 30000

// 登录方法
export function login(username, password, code, uuid) {
  const data = {
    username,
    password,
    code,
    uuid
  }
  return request({
    url: '/login',
    timeout: AUTH_REQUEST_TIMEOUT,
    headers: {
      isToken: false,
      repeatSubmit: false
    },
    method: 'post',
    data: data
  })
}

// 账号密码登录
export function loginByAccountPassword(account, password) {
  return request({
    url: '/login',
    timeout: AUTH_REQUEST_TIMEOUT,
    headers: {
      isToken: false,
      repeatSubmit: false
    },
    method: 'post',
    data: {
      account,
      password,
      loginType: 'account_password'
    }
  })
}

// 手机短信验证码登录
export function loginBySms(phone, smsCode) {
  return request({
    url: '/login',
    timeout: AUTH_REQUEST_TIMEOUT,
    headers: {
      isToken: false,
      repeatSubmit: false
    },
    method: 'post',
    data: {
      phone,
      smsCode,
      loginType: 'sms'
    }
  })
}

// 注册方法
export function register(data) {
  return request({
    url: '/register',
    headers: {
      isToken: false
    },
    method: 'post',
    data: data
  })
}

// 发送手机短信验证码
export function sendSmsCode(phone, scene) {
  return request({
    url: '/sms/code',
    headers: {
      isToken: scene !== 'bind_phone',
      repeatSubmit: false
    },
    method: 'post',
    data: {
      phone,
      scene
    }
  })
}

// 获取用户详细信息
export function getInfo(options = {}) {
  return request({
    url: '/getInfo',
    timeout: AUTH_REQUEST_TIMEOUT,
    silentAuth: options.silentAuth === true,
    method: 'get'
  })
}

// 解锁屏幕
export function unlockScreen(password) {
  return request({
    url: '/unlockscreen',
    method: 'post',
    data: { password }
  })
}

// 退出方法
export function logout() {
  return request({
    url: '/logout',
    method: 'post'
  })
}

// 获取验证码
export function getCodeImg() {
  return request({
    url: '/captchaImage',
    headers: {
      isToken: false
    },
    method: 'get',
    timeout: 20000
  })
}
