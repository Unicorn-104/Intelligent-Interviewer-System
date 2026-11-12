import { ElMessageBox } from 'element-plus'
import { hasCandidateAccessToken } from './agentSession'
import { candidateRedirect } from './agentNavigation'

const publicPages = new Set(['/index', '/jobs', '/job-detail'])
let loginPrompt

export function isPublicCandidatePage(path) {
  return publicPages.has(path)
}

export function requestCandidateLogin(target) {
  if (loginPrompt) return loginPrompt
  const redirect = encodeURIComponent(candidateRedirect(target))
  loginPrompt = ElMessageBox.confirm('浏览岗位无需登录，投递、收藏、聊天及查看个人信息需要登录。请选择登录或注册，也可以关闭提示继续浏览。', '登录后继续', {
    confirmButtonText: '去登录',
    cancelButtonText: '去注册',
    distinguishCancelAndClose: true,
    closeOnClickModal: false,
    type: 'info'
  }).then(() => `/login?redirect=${redirect}`, action => action === 'cancel' ? `/register?redirect=${redirect}` : null)
    .finally(() => { loginPrompt = null })
  return loginPrompt
}

export function requireCandidateLogin(target) {
  if (hasCandidateAccessToken()) return true
  requestCandidateLogin(target).then(route => {
    if (route) window.__agentNavigate(route)
  })
  return false
}
