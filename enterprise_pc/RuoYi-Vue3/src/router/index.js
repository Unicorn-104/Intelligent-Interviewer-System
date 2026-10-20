import { createWebHistory, createRouter } from 'vue-router'
/* Layout */
import Layout from '@/layout'
import EnterpriseLayout from '@/views/enterprise/EnterpriseLayout.vue'

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
    component: () => import('@/views/login'),
    hidden: true
  },
  {
    path: '/register',
    component: () => import('@/views/register'),
    hidden: true
  },
  {
    path: '/401',
    component: () => import('@/views/error/401'),
    hidden: true
  },
  {
    path: '',
    component: EnterpriseLayout,
    hidden: true,
    children: [
      {
        path: '',
        component: () => import('@/views/enterprise/dashboard/index.vue'),
        name: 'EnterpriseRootDashboard',
        meta: { title: '招聘总览' }
      }
    ]
  },
  {
    path: '/user',
    component: Layout,
    hidden: true,
    redirect: 'noredirect',
    children: [
      {
        path: 'profile',
        component: () => import('@/views/system/user/profile/index'),
        name: 'Profile',
        meta: { title: '个人中心', icon: 'user' }
      }
    ]
  },
  {
    path: '/enterprise',
    component: EnterpriseLayout,
    hidden: true,
    redirect: '/enterprise/dashboard',
    children: [
      {
        path: 'dashboard',
        component: () => import('@/views/enterprise/dashboard/index.vue'),
        name: 'EnterpriseDashboard',
        meta: { title: '招聘总览' }
      },
      {
        path: 'jobs',
        component: () => import('@/views/enterprise/jobs/index.vue'),
        name: 'EnterpriseJobs',
        meta: { title: '岗位管理' }
      },
      {
        path: 'jobs/:id',
        component: () => import('@/views/enterprise/jobs/detail.vue'),
        name: 'EnterpriseJobDetail',
        meta: { title: '岗位详情' }
      },
      {
        path: 'jobs/:id/workflow',
        component: () => import('@/views/enterprise/jobs/workflow.vue'),
        name: 'EnterpriseWorkflowConfig',
        meta: { title: '招聘流程配置' }
      },
      {
        path: 'candidates',
        component: () => import('@/views/enterprise/candidates/index.vue'),
        name: 'EnterpriseCandidates',
        meta: { title: '候选人管理' }
      },
      {
        path: 'candidates/:id/process',
        component: () => import('@/views/enterprise/candidates/process.vue'),
        name: 'EnterpriseCandidateProcess',
        meta: { title: '候选人流程' }
      },
      {
        path: 'screening',
        component: () => import('@/views/enterprise/screening/index.vue'),
        name: 'EnterpriseScreening',
        meta: { title: 'AI 初筛' }
      },
      {
        path: 'talent',
        component: () => import('@/views/enterprise/talent/index.vue'),
        name: 'EnterpriseTalent',
        meta: { title: '人才库' }
      },
      {
        path: 'survey',
        component: () => import('@/views/enterprise/survey/index.vue'),
        name: 'EnterpriseSurvey',
        meta: { title: '满意度调研' }
      },
      {
        path: 'conference/active',
        component: () => import('@/views/enterprise/conference/active.vue'),
        name: 'EnterpriseConferenceActive',
        meta: { title: '正在进行的面试' }
      },
      {
        path: 'conference/records',
        component: () => import('@/views/enterprise/conference/records.vue'),
        name: 'EnterpriseConferenceRecords',
        meta: { title: '录制回放与存储管理' }
      },
      {
        path: 'exam',
        component: () => import('@/views/enterprise/exam/index.vue'),
        name: 'EnterpriseExam',
        meta: { title: '在线笔试' }
      },
      {
        path: 'exam/proctor',
        component: () => import('@/views/enterprise/exam/proctor.vue'),
        name: 'EnterpriseExamProctor',
        meta: { title: '监考监控' }
      },
      {
        path: 'exam/proctor/room',
        component: () => import('@/views/enterprise/exam/proctor-room.vue'),
        name: 'EnterpriseExamProctorRoom',
        meta: { title: '监考房间' }
      },
      {
        path: 'interviews',
        component: () => import('@/views/enterprise/interviews/index.vue'),
        name: 'EnterpriseInterviews',
        meta: { title: '面试安排中心' }
      },
      {
        path: 'offer',
        component: () => import('@/views/enterprise/offer/index.vue'),
        name: 'EnterpriseOffer',
        meta: { title: 'Offer 管理' }
      },
      {
        path: 'interviews/:id/evaluation',
        component: () => import('@/views/enterprise/interviews/evaluation.vue'),
        name: 'EnterpriseInterviewEvaluation',
        meta: { title: '面试评估' }
      },
      {
        path: 'messages',
        component: () => import('@/views/enterprise/messages/index.vue'),
        name: 'EnterpriseMessages',
        meta: { title: '消息中心' }
      },
      {
        path: 'profile',
        component: () => import('@/views/enterprise/profile/index.vue'),
        name: 'EnterpriseProfile',
        meta: { title: '个人中心' }
      },
      {
        path: 'settings',
        component: () => import('@/views/enterprise/settings/index.vue'),
        name: 'EnterpriseSettings',
        meta: { title: '系统设置' }
      }
    ]
  },
  // 旧会议页 /enterprise/meeting/ai、/enterprise/meeting/collaborative 已并入会议模块，
  // 旧地址统一引导到「协同面试进行中」，避免旧书签与外部链接 404。
  {
    path: '/enterprise/meeting/ai',
    redirect: (to) => ({ path: '/enterprise/conference/ongoing', query: to.query })
  },
  {
    path: '/enterprise/meeting/collaborative',
    redirect: (to) => ({ path: '/enterprise/conference/ongoing', query: to.query })
  },
  {
    path: '/enterprise/conference/join',
    component: () => import('@/views/enterprise/conference/join.vue'),
    name: 'EnterpriseConferenceJoin',
    hidden: true,
    meta: { title: '面试链接校验' }
  },
  {
    path: '/enterprise/conference/prep',
    component: () => import('@/views/enterprise/conference/prep.vue'),
    name: 'EnterpriseConferencePrep',
    hidden: true,
    meta: { title: '面试准备' }
  },
  {
    path: '/enterprise/conference/waiting',
    component: () => import('@/views/enterprise/conference/waiting.vue'),
    name: 'EnterpriseConferenceWaiting',
    hidden: true,
    meta: { title: '等候室' }
  },
  {
    path: '/enterprise/conference/ongoing',
    component: () => import('@/views/enterprise/conference/ongoing.vue'),
    name: 'EnterpriseConferenceOngoing',
    hidden: true,
    meta: { title: '协同面试进行中' }
  },
  {
    path: '/enterprise/conference/playback',
    component: () => import('@/views/enterprise/conference/playback.vue'),
    name: 'EnterpriseConferencePlayback',
    hidden: true,
    meta: { title: '在线回放' }
  },
  {
    path: "/:pathMatch(.*)*",
    component: () => import('@/views/error/404'),
    hidden: true
  }
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
  // 路由记录本身以 /enterprise 开头，history base 必须保持 '/'，
  // 否则深链会被剥掉 /enterprise/ 前缀后匹配不到而落入 404（vite 资源前缀仍为 /enterprise/）
  history: createWebHistory('/'),
  routes: constantRoutes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    } else {
      return { top: 0 }
    }
  },
});

export default router;
