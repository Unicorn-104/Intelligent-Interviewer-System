import router from './router'
import { ElMessage } from 'element-plus'
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import { getToken } from '@/utils/auth'
import { removeToken } from '@/utils/auth'
import { isHttp, isPathMatch } from '@/utils/validate'
import { isRelogin } from '@/utils/request'
import useUserStore from '@/store/modules/user'
import useLockStore from '@/store/modules/lock'
import useSettingsStore from '@/store/modules/settings'
import usePermissionStore from '@/store/modules/permission'
import { clearCandidateSession, hasCandidateAccessToken } from '@/utils/agentSession'

NProgress.configure({ showSpinner: false })

const whiteList = ['/login', '/register']
const agentPublicRoutes = ['/agent/login', '/agent/register']

const isWhiteList = (path) => {
  return whiteList.some(pattern => isPathMatch(pattern, path))
}

router.beforeEach(async (to, from) => {
  NProgress.start()
  if (to.path === '/conference-join') {
    NProgress.done()
    return true
  }
  if (import.meta.env.VITE_FRONTEND_ONLY === 'true') {
    if (to.path === '/' || to.path === '/index' || to.path === '/login') {
      NProgress.done()
      return { path: '/agent/login', query: to.query, replace: true }
    }
    NProgress.done()
    return true
  }
  if (to.path.startsWith('/agent/')) {
    to.meta.title && useSettingsStore().setTitle(to.meta.title)
    if (agentPublicRoutes.includes(to.path)) {
      // 登录/注册页必须始终可进入，避免浏览器残留的过期 token 触发 getInfo 弹窗。
      if (hasCandidateAccessToken()) {
        removeToken()
        clearCandidateSession()
        useUserStore().$reset()
        isRelogin.show = false
      }
      NProgress.done()
      return true
    }
    if (hasCandidateAccessToken()) {
      const userStore = useUserStore()
      if (!userStore.name) {
        try {
          await userStore.getInfo()
        } catch {
          removeToken()
          clearCandidateSession()
          userStore.$reset()
          ElMessage.error('登录状态已失效，请重新登录')
          NProgress.done()
          return { path: '/agent/login', query: { redirect: to.fullPath }, replace: true }
        }
      }
      return true
    }
    NProgress.done()
    return { path: '/agent/login', query: { redirect: to.fullPath }, replace: true }
  }
  if (getToken()) {
    to.meta.title && useSettingsStore().setTitle(to.meta.title)
    const isLock = useLockStore().isLock
    if (to.path === '/login') {
      NProgress.done()
      return { path: '/agent/index', replace: true }
    }
    if (to.path === '/register') {
      NProgress.done()
      return { path: '/agent/index', replace: true }
    }
    if (isWhiteList(to.path)) {
      return true
    }
    if (isLock && to.path !== '/lock') {
      NProgress.done()
      return { path: '/lock' }
    }
    if (!isLock && to.path === '/lock') {
      NProgress.done()
      return { path: '/' }
    }
    if (useUserStore().roles.length === 0) {
      isRelogin.show = true
      try {
        // 拉取user_info信息
        await useUserStore().getInfo()
        isRelogin.show = false
        // 根据roles权限生成可访问的路由
        const accessRoutes = await usePermissionStore().generateRoutes()
        accessRoutes.forEach(route => {
          if (!isHttp(route.path)) {
            router.addRoute(route)
          }
        })
        // 重新导航到目标路由，确保动态路由已注册
        return { ...to, replace: true }
      } catch (err) {
        // 后端不可用或会话失效时只清理本地令牌，避免再次请求 logout 形成错误循环。
        removeToken()
        useUserStore().$reset()
        ElMessage.error('登录服务暂不可用，请检查后端服务和数据库')
        return { path: '/' }
      }
    }
    return true
  } else {
    // 没有token
    if (isWhiteList(to.path)) {
      // 在免登录白名单，直接进入
      return true
    }
    NProgress.done()
    return {
      path: '/agent/login',
      query: { redirect: to.fullPath },
      replace: true
    }
  }
})

router.afterEach(() => {
  NProgress.done()
})
