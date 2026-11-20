import router from './router'
import { ElMessage } from 'element-plus'
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import { getToken, removeToken, removeRefreshToken } from '@/utils/auth'
import { isHttp } from '@/utils/validate'
import { isRelogin } from '@/utils/request'
import useUserStore from '@/store/modules/user'
import useSettingsStore from '@/store/modules/settings'
import usePermissionStore from '@/store/modules/permission'
import { getAccountStatus } from '@/api/portal'

NProgress.configure({ showSpinner: false });

// 登录页统一使用 /enterprise/login：该路径位于 vite base(/enterprise/) 之内，刷新时不会被开发服务器拦截
const LOGIN_PATH = '/enterprise/login';
// 未登录可进入的入口页：登录、企业注册
const AUTH_ENTRY_PATHS = [LOGIN_PATH, '/login', '/enterprise/register'];

// 企业端准入角色：超级管理员 + 企业超级管理员(biz_1)/招聘HR(biz_2)/面试官(biz_3)
// 求职者(biz_4)、运营(biz_5)等其他角色禁止进入本端后台
const ENTERPRISE_ROLES = ['admin', 'biz_1', 'biz_2', 'biz_3'];

function isAuthEntry(path) {
  return AUTH_ENTRY_PATHS.indexOf(path) !== -1
}

// 公开岗位门户：游客可直接浏览
function isGuestBrowse(path) {
  return path === '/enterprise/portal' || path.indexOf('/enterprise/portal/') === 0
}

function isPublicPath(path) {
  return isAuthEntry(path) || isGuestBrowse(path)
}

function hasEnterpriseAccess() {
  const roles = useUserStore().roles || []
  return roles.some(r => ENTERPRISE_ROLES.includes(r))
}

// 非企业角色：强制登出并弹回登录页，页面不予渲染
function denyNonEnterprise(next) {
  const userStore = useUserStore()
  userStore.logOut().catch(() => {}).finally(() => {
    // 兜底：即使后端登出接口失败，也确保本地令牌与角色被清除，避免 /login 被守卫弹回造成循环
    removeToken()
    userStore.token = ''
    userStore.roles = []
    userStore.permissions = []
    ElMessage.error('您的账号无企业端访问权限，请前往求职者端登录')
    next({ path: LOGIN_PATH, replace: true })
    NProgress.done()
  })
}

// 拉取用户信息后校验企业审核状态，通过后才生成后台路由
function checkAccountAndProceed(to, next) {
  const userStore = useUserStore()
  const isAdmin = (userStore.roles || []).includes('admin')

  const proceed = () => {
    usePermissionStore().generateRoutes().then(accessRoutes => {
      // 根据roles权限生成可访问的路由表
      accessRoutes.forEach(route => {
        if (!isHttp(route.path)) {
          router.addRoute(route) // 动态添加可访问路由表
        }
      })
      next({ ...to, replace: true }) // hack方法 确保addRoutes已完成
    })
  }

  if (isAdmin) {
    proceed()
    return
  }

  getAccountStatus().then(res => {
    const status = res.data || {}
    if (status.bindingStatus !== 1) {
      // 企业未审核通过（含驳回、待审核、未绑定），进入待审核提示页
      next({ path: '/enterprise/pending', replace: true })
      NProgress.done()
    } else {
      proceed()
    }
  }).catch(() => {
    // 状态接口异常时不阻断既有用户登录
    proceed()
  })
}

router.beforeEach((to, from, next) => {
  NProgress.start()
  if (getToken()) {
    to.meta.title && useSettingsStore().setTitle(to.meta.title)
    /* has token*/
    if (isAuthEntry(to.path)) {
      next({ path: '/enterprise/dashboard' })
      NProgress.done()
    } else if (isGuestBrowse(to.path) || to.path === '/enterprise/pending') {
      // 公开门户与待审核页不依赖企业后台布局与动态路由
      next()
    } else {
      if (useUserStore().roles.length === 0) {
        isRelogin.show = true
        // 判断当前用户是否已拉取完user_info信息
        useUserStore().getInfo().then(() => {
          isRelogin.show = false
          // 非企业角色登录后立即堵回登录页，不渲染任何企业端页面
          if (!hasEnterpriseAccess()) {
            denyNonEnterprise(next)
            return
          }
          checkAccountAndProceed(to, next)
        }).catch(err => {
          // 会话已失效：后端登出无意义，且其自身 401 会再次触发「登录状态已过期」弹窗，
          // 这里直接清空本地访问令牌 + 刷新令牌并回到登录页，避免刷新令牌残留导致反复提示
          const userStore = useUserStore()
          removeToken()
          removeRefreshToken()
          userStore.token = ''
          userStore.roles = []
          userStore.permissions = []
          ElMessage.error(err)
          next({ path: LOGIN_PATH, replace: true })
          NProgress.done()
        })
      } else {
        next()
      }
    }
  } else {
    // 没有token
    if (to.path === '/' || to.path === '/enterprise') {
      // 打开站点默认进入企业端公开门户，而不是先弹登录页
      next('/enterprise/portal')
      NProgress.done()
    } else if (isPublicPath(to.path)) {
      // 在免登录白名单，直接进入
      next()
    } else {
      next(`${LOGIN_PATH}?redirect=${to.fullPath}`) // 否则全部重定向到登录页
      NProgress.done()
    }
  }
})

router.afterEach(() => {
  NProgress.done()
})
