import { createWebHistory, createRouter } from 'vue-router'
/* Layout */
import Layout from '@/layout'

const agentPageModules = import.meta.glob('../views/agent/pages/*.vue')
const redirectToAgentLogin = (to) => ({
  path: '/agent/login',
  query: to.query
})
const redirectToAgentRegister = (to) => ({
  path: '/agent/register',
  query: to.query
})

const agentPageDefinitions = [
  ['index', 'AgentIndex', '求职者端工作台'],
  ['login', 'AgentLogin', '求职者端登录'],
  ['register', 'AgentRegister', '求职者端注册'],
  ['jobs', 'AgentJobs', '岗位浏览'],
  ['job-detail', 'AgentJobDetail', '岗位详情'],
  ['job-assistant', 'AgentJobAssistant', '求职助手'],
  ['applications', 'AgentApplications', '投递跟踪'],
  ['application-detail', 'AgentApplicationDetail', '投递详情'],
  ['messages', 'AgentMessages', '消息通知'],
  ['profile-basic', 'AgentProfileBasic', '基础资料'],
  ['profile-resumes', 'AgentProfileResumes', '我的简历'],
  ['profile-security', 'AgentProfileSecurity', '账号安全'],
  ['resume-editor', 'AgentResumeEditor', '简历编辑'],
  ['resume-select', 'AgentResumeSelect', '简历选择'],
  ['mock-interview', 'AgentMockInterview', '模拟面试'],
  ['interview-schedule', 'AgentInterviewSchedule', '面试安排'],
  ['interview-invitation', 'AgentInterviewInvitation', '面试邀请'],
  ['interview-result', 'AgentInterviewResult', '面试结果'],
  ['video-meeting', 'AgentVideoMeeting', '视频面试'],
  ['company-profile', 'AgentCompanyProfile', '企业主页'],
  ['contact-profile', 'AgentContactProfile', '联系人主页'],
  ['exam', 'AgentExam', '在线笔试'],
  ['exam-room', 'AgentExamRoom', '笔试答题'],
  ['conference-entry', 'AgentConferenceEntry', '面试链接校验'],
  ['conference-prep', 'AgentConferencePrep', '会议准备'],
  ['conference-waiting', 'AgentConferenceWaiting', '等候室'],
  ['conference-ai', 'AgentConferenceAi', 'AI 面试进行中'],
  ['conference-ended', 'AgentConferenceEnded', '面试结束'],
  ['conference-reconnect', 'AgentConferenceReconnect', '连接中断'],
  ['conference-aborted', 'AgentConferenceAborted', '面试异常终止']
]

const agentRoutes = [{
  path: '/agent',
  component: () => import('@/views/agent/shell.vue'),
  redirect: '/agent/index',
  children: [
    {
      path: 'profile',
      redirect: '/agent/profile-basic'
    },
    ...agentPageDefinitions.map(([path, name, title]) => ({
      path,
      name,
      component: agentPageModules[`../views/agent/pages/${path}.vue`],
      meta: { title }
    }))
  ]
}]

const legacyAgentRoutes = agentPageDefinitions.map(([path]) => ({
  path: `/${path}.html`,
  redirect: (to) => ({ path: `/agent/${path}`, query: to.query })
}))

// 已下线页面（面试确认 interview-check / 面试房间 interview-room）的旧地址兼容，
// 统一引导到新的视频会议模块，避免旧书签与外部链接 404。
const retiredAgentRoutes = [
  { path: '/agent/interview-check', redirect: (to) => ({ path: '/agent/conference-prep', query: to.query }) },
  { path: '/interview-check.html', redirect: (to) => ({ path: '/agent/conference-prep', query: to.query }) },
  { path: '/agent/interview-room', redirect: (to) => ({ path: '/agent/conference-ai', query: to.query }) },
  { path: '/interview-room.html', redirect: (to) => ({ path: '/agent/conference-ai', query: to.query }) }
]

/**
 * Note: 路由配置项
 *
 * hidden: true                     // 当设置 true 的时候该路由不会再侧边栏出现 如401，login等页面，或者如一些编辑页面/edit/1
 * alwaysShow: true                 // 当你一个路由下面的 children 声明的路由大于1个时，自动会变成嵌套的模式--如组件页面
 *                                  // 只有一个时，会将那个子路由当做根路由显示在侧边栏--如引导页面
 *                                  // 若你想不管路由下面的 children 声明的个数都显示你的根路由
 *                                  // 你可以设置 alwaysShow: true，这样它就会忽略之前定义的规则，一直显示根路由
 * redirect: noRedirect             // 当设置 noRedirect 的时候该路由在面包屑导航中不可被点击
 * name:'router-name'               // 设定路由的名字，一定要填写不然使用<keep-alive>时会出现各种问题
 * query: '{"id": 1, "name": "ry"}' // 访问路由的默认传递参数
 * roles: ['admin', 'common']       // 访问路由的角色权限
 * permissions: ['a:a:a', 'b:b:b']  // 访问路由的菜单权限
 * meta : {
    noCache: true                   // 如果设置为true，则不会被 <keep-alive> 缓存(默认 false)
    title: 'title'                  // 设置该路由在侧边栏和面包屑中展示的名字
    icon: 'svg-name'                // 设置该路由的图标，对应路径src/assets/icons/svg
    breadcrumb: false               // 如果设置为false，则不会在breadcrumb面包屑中显示
    activeMenu: '/system/user'      // 当路由设置了该属性，则会高亮相对应的侧边栏。
  }
 */

// 公共路由
export const constantRoutes = [
  {
    path: '/redirect',
    component: Layout,
    hidden: true,
    children: [
      {
        path: '/redirect/:path(.*)',
        component: () => import('@/views/redirect/index.vue')
      }
    ]
  },
  {
    path: '/login',
    redirect: redirectToAgentLogin,
    hidden: true
  },
  {
    path: '/register',
    redirect: redirectToAgentRegister,
    hidden: true
  },
  {
    path: "/:pathMatch(.*)*",
    component: () => import('@/views/error/404'),
    hidden: true
  },
  {
    path: '/401',
    component: () => import('@/views/error/401'),
    hidden: true
  },
  {
    path: '',
    component: Layout,
    redirect: redirectToAgentLogin,
    children: [
      {
        path: '/index',
        component: () => import('@/views/index'),
        name: 'Index',
        meta: { title: '首页', icon: 'dashboard', affix: true }
      }
    ]
  },
  {
    path: '/lock',
    component: () => import('@/views/lock'),
    hidden: true,
    meta: { title: '锁定屏幕' }
  },
  {
    path: '/user',
    component: Layout,
    hidden: true,
    redirect: 'noredirect',
    children: [
      {
        path: 'profile/:activeTab?',
        component: () => import('@/views/system/user/profile/index'),
        name: 'Profile',
        meta: { title: '个人中心', icon: 'user' }
      }
    ]
  },
  {
    path: '/conference-join',
    component: () => import('@/views/conference-join.vue'),
    hidden: true,
    meta: { title: '面试邀请' }
  },
  {
    path: '/survey-fill',
    component: () => import('@/views/survey-fill.vue'),
    hidden: true,
    meta: { title: '满意度调研' }
  },
  {
    path: '/exam-sub',
    component: () => import('@/views/agent/pages/exam-sub.vue'),
    hidden: true,
    meta: { title: '笔试副机位' }
  },
  ...agentRoutes,
  ...legacyAgentRoutes,
  ...retiredAgentRoutes
]

// 动态路由，基于用户权限动态去加载
export const dynamicRoutes = [
  {
    path: '/system/user-auth',
    component: Layout,
    hidden: true,
    permissions: ['system:user:edit'],
    children: [
      {
        path: 'role/:userId(\\d+)',
        component: () => import('@/views/system/user/authRole'),
        name: 'AuthRole',
        meta: { title: '分配角色', activeMenu: '/system/user' }
      }
    ]
  },
  {
    path: '/system/role-auth',
    component: Layout,
    hidden: true,
    permissions: ['system:role:edit'],
    children: [
      {
        path: 'user/:roleId(\\d+)',
        component: () => import('@/views/system/role/authUser'),
        name: 'AuthUser',
        meta: { title: '分配用户', activeMenu: '/system/role' }
      }
    ]
  },
  {
    path: '/system/dict-data',
    component: Layout,
    hidden: true,
    permissions: ['system:dict:list'],
    children: [
      {
        path: 'index/:dictId(\\d+)',
        component: () => import('@/views/system/dict/data'),
        name: 'Data',
        meta: { title: '字典数据', activeMenu: '/system/dict' }
      }
    ]
  },
  {
    path: '/monitor/job-log',
    component: Layout,
    hidden: true,
    permissions: ['monitor:job:list'],
    children: [
      {
        path: 'index/:jobId(\\d+)',
        component: () => import('@/views/monitor/job/log'),
        name: 'JobLog',
        meta: { title: '调度日志', activeMenu: '/monitor/job' }
      }
    ]
  },
  {
    path: '/tool/gen-edit',
    component: Layout,
    hidden: true,
    permissions: ['tool:gen:edit'],
    children: [
      {
        path: 'index/:tableId(\\d+)',
        component: () => import('@/views/tool/gen/editTable'),
        name: 'GenEdit',
        meta: { title: '修改生成配置', activeMenu: '/tool/gen' }
      }
    ]
  }
]

const router = createRouter({
  // 以构建时的部署子路径为路由基址（生产为 /user/），保证深链与拼接出的路径一致
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: constantRoutes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    }
    return { top: 0 }
  },
})

export default router
