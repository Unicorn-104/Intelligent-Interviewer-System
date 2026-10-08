import Cookies from 'js-cookie'

// 候选人端与企业管理端同域（localhost）联调时，Cookie 按主机名共享、不区分端口，
// 两端若同名 Token 会互相覆盖导致身份串号，故候选人端使用独立键名。
const TokenKey = 'Candidate-Token'

export function getToken() {
  return Cookies.get(TokenKey)
}

export function setToken(token) {
  return Cookies.set(TokenKey, token)
}

export function removeToken() {
  return Cookies.remove(TokenKey)
}
