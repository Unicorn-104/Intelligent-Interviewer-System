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

NProgress.configure({ showSpinner: false });

const whiteList = ['/login', '/register'];

// 企业端准入角色：超级管理员 + 企业超级管理员(biz_1)/招聘HR(biz_2)/面试官(biz_3)
// 求职者(biz_4)、运营(biz_5)等其他角色禁止进入本端任何页面
const ENTERPRISE_ROLES = ['admin', 'biz_1', 'biz_2', 'biz_3'];

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
    next({ path: '/login', replace: true })
    NProgress.done()
  })
}

router.beforeEach((to, from, next) => {
  NProgress.start()
  if (getToken()) {
    to.meta.title && useSettingsStore().setTitle(to.meta.title)
    /* has token*/
    if (to.path === '/login') {
      next({ path: '/' })
      NProgress.done()
    } else if (whiteList.indexOf(to.path) !== -1) {
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
          usePermissionStore().generateRoutes().then(accessRoutes => {
            // 根据roles权限生成可访问的路由表
            accessRoutes.forEach(route => {
              if (!isHttp(route.path)) {
                router.addRoute(route) // 动态添加可访问路由表
              }
            })
            next({ ...to, replace: true }) // hack方法 确保addRoutes已完成
          })
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
          next({ path: '/login', replace: true })
          NProgress.done()
        })
      } else {
        next()
      }
    }
  } else {
    // 没有token
    if (whiteList.indexOf(to.path) !== -1) {
      // 在免登录白名单，直接进入
      next()
    } else {
      next(`/login?redirect=${to.fullPath}`) // 否则全部重定向到登录页
      NProgress.done()
    }
  }
})

router.afterEach(() => {
  NProgress.done()
})
