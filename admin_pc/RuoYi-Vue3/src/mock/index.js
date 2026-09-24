// Mock 适配器：拦截 axios 请求，返回演示数据
// 通过 .env 中 VITE_APP_USE_MOCK 控制开关，接入真实后端时置为 false 即可
import * as db from './db'
const { ok, paginate } = db
import * as biz from './business'
import * as pf from './platform'

export const useMock = String(import.meta.env.VITE_APP_USE_MOCK).toLowerCase() === 'true'

// ---------- 工具 ----------
function parseUrl(raw) {
  const qIdx = (raw || '').indexOf('?')
  let path = qIdx === -1 ? raw : raw.slice(0, qIdx)
  if (path.startsWith('/api/v1')) path = path.slice('/api/v1'.length) || '/'
  const aliases = {
    '/auth/login': '/login',
    '/auth/register': '/register',
    '/me': '/getInfo',
    '/auth/logout': '/logout',
    '/auth/captcha': '/captchaImage',
    '/auth/unlock': '/unlockscreen'
  }
  path = aliases[path] || path
  const query = {}
  if (qIdx !== -1) {
    new URLSearchParams(raw.slice(qIdx + 1)).forEach((v, k) => {
      query[k === 'page' ? 'page' : k] = v
    })
  }
  return { path, query }
}

function parseBody(config) {
  let body = {}
  try {
    body = typeof config.data === 'string' ? JSON.parse(config.data) : config.data || {}
  } catch (e) {
    body = {}
  }
  return body
}

function filterRows(rows, query, fieldMap) {
  return rows.filter((row) => {
    for (const qk in fieldMap) {
      const target = fieldMap[qk]
      const qv = query[qk]
      if (qv === undefined || qv === null || qv === '') continue
      if (target.includes('%')) {
        if (!String(row[target.replace('%', '')] || '').includes(qv)) return false
      } else if (String(row[target]) !== String(qv)) {
        return false
      }
    }
    return true
  })
}

function blobResponse() {
  return new Blob(['AI招聘管理系统演示数据导出\r\n(此文件由前端演示模式生成)'], { type: 'text/plain' })
}

// ---------- 菜单 ----------
function buildMenu() {
  const C = (name, path, component, title, icon) => ({
    name,
    path,
    hidden: false,
    component,
    meta: { title, icon, noCache: false, link: null }
  })
  const M = (name, path, title, icon, children) => ({
    name,
    path,
    hidden: false,
    redirect: 'noRedirect',
    component: 'Layout',
    alwaysShow: true,
    meta: { title, icon, noCache: false, link: null },
    children
  })
  return ok({
    data: [
      M('Tenant', '/tenant', '租户管理', 'peoples', [
        C('Company', 'company', 'tenant/company/index', '企业管理', 'build'),
        C('Package', 'package', 'tenant/package/index', '套餐管理', 'money')
      ]),
      M('Member', '/member', '用户中心', 'user', [
        C('MemberUser', 'user', 'member/user/index', 'C端用户', 'peoples'),
        C('MemberVerify', 'verify', 'member/verify/index', '企业认证审核', 'validCode')
      ]),
      M('System', '/system', '系统管理', 'system', [
        C('User', 'user', 'system/user/index', '运营账号', 'user'),
        C('Role', 'role', 'system/role/index', '角色分配', 'peoples'),
        C('Menu', 'menu', 'system/menu/index', '菜单配置', 'tree-table'),
        C('Dept', 'dept', 'system/dept/index', '部门管理', 'tree'),
        C('Post', 'post', 'system/post/index', '岗位管理', 'post'),
        C('Dict', 'dict', 'system/dict/index', '数据字典', 'dict'),
        C('Config', 'config', 'system/config/index', '参数设置', 'edit'),
        C('Notice', 'notice', 'system/notice/index', '公告管理', 'message'),
        C('Privacy', 'privacy', 'system/privacy/index', '隐私设置', 'lock'),
        C('ThemeMaintenance', 'theme', 'system/theme/index', '界面维护', 'component'),
        C('Maintenance', 'maintenance', 'system/maintenance/index', '系统维护', 'server')
      ]),
      M('Ai', '/ai', 'AI 配置', 'skill', [
        C('AiModel', 'model', 'ai/model/index', '模型管理', 'component'),
        C('AiQuota', 'quota', 'ai/quota/index', 'API 配额', 'chart'),
        C('AiPrompt', 'prompt', 'ai/prompt/index', '提示词模板', 'edit'),
        C('Scorecard', 'scorecard', 'ai/scorecard/index', '评估评分卡', 'star'),
        C('Cascade', 'cascade', 'ai/cascade/index', '级联规则', 'cascader')
      ]),
      M('Content', '/content', '内容管理', 'form', [
        C('Category', 'category', 'content/category/index', '职位分类', 'tree'),
        C('Question', 'question', 'content/question/index', '面试题库', 'education'),
        C('ContentNotice', 'notice', 'system/notice/index', '公告管理', 'message'),
        C('HelpDoc', 'help', 'content/help/index', '帮助文章', 'documentation'),
        C('Feedback', 'feedback', 'content/feedback/index', '反馈工单', 'email'),
        C('Service', 'service', 'content/service/index', '客服配置', 'phone'),
        {
          name: 'Ad',
          path: 'ad',
          hidden: false,
          redirect: 'noRedirect',
          component: 'ParentView',
          alwaysShow: true,
          meta: { title: '广告管理', icon: 'shopping', noCache: false, link: null },
          children: [
            C('AdSlot', 'slot', 'ad/slot/index', '广告位管理', 'component'),
            C('Advert', 'list', 'ad/advert/index', '广告列表', 'list')
          ]
        }
      ]),
      M('Message', '/msg', '消息管理', 'message', [
        C('MsgTemplate', 'template', 'msg/template/index', '消息模板', 'form'),
        C('MsgChannel', 'channel', 'msg/channel/index', '渠道配置', 'component'),
        C('MsgRecord', 'record', 'msg/record/index', '发送记录', 'log'),
        C('MsgPreference', 'preference', 'msg/preference/index', '通知偏好', 'list'),
        C('MsgAiReply', 'aiReply', 'msg/aiReply/index', 'AI应答', 'edit')
      ]),
      M('Biz', '/biz', '业务管理', 'component', [
        C('Resume', 'resume', 'biz/resume/index', '简历库管理', 'documentation'),
        C('ResumeParse', 'resumeParse', 'biz/resumeParse/index', '简历解析', 'form'),
        C('AiScreen', 'aiScreen', 'biz/aiScreen/index', 'AI初筛', 'edit'),
        C('Schedule', 'schedule', 'biz/schedule/index', '智能预约', 'time'),
        C('InterviewEval', 'interviewEval', 'biz/interviewEval/index', '面试评估', 'star'),
        C('Candidate', 'candidate', 'biz/candidate/index', '候选人管理', 'peoples')
      ]),
      M('Supervise', '/supervise', '业务监管', 'search', [
        C('JobAudit', 'job', 'biz/job/index', '岗位审核', 'job'),
        C('InterviewMonitor', 'interview', 'biz/interview/index', '面试监控', 'online'),
        C('ExamConfig', 'exam', 'biz/exam/index', '考核环境', 'code')
      ]),
      M('LogAudit', '/log', '日志审计', 'log', [
        C('Operlog', 'operlog', 'monitor/operlog/index', '操作日志', 'form'),
        C('Logininfor', 'logininfor', 'monitor/logininfor/index', '登录日志', 'logininfor')
      ]),
      M('Monitor', '/monitor', '系统监控', 'monitor', [
        C('Online', 'online', 'monitor/online/index', '在线用户', 'online'),
        C('Cache', 'cache', 'monitor/cache/index', '缓存监控', 'redis'),
        C('Server', 'server', 'monitor/server/index', '服务状态', 'server'),
        C('Job', 'job', 'monitor/job/index', '定时任务', 'job')
      ]),
      M('Tool', '/tool', '系统工具', 'tool', [
        C('Gen', 'gen', 'tool/gen/index', '代码生成', 'code'),
        C('Build', 'build', 'tool/build/index', '表单构建', 'build')
      ])
    ]
  })
}

// ---------- 业务 CRUD 生成器 ----------
function crud(base, rows, idKey, opts = {}) {
  const listFields = opts.listFields || {}
  return [
    {
      test: new RegExp('^' + base + '/list$'),
      m: 'get',
      h: (path, query) => ok(paginate(filterRows(rows, query, listFields), query), '查询成功')
    },
    {
      test: new RegExp('^' + base + '/(\\d+)$'),
      m: 'get',
      h: (path) => {
        const id = Number(path.match(new RegExp('^' + base + '/(\\d+)$'))[1])
        const row = rows.find((r) => r[idKey] === id)
        return ok({ data: row })
      }
    },
    {
      test: new RegExp('^' + base + '$'),
      m: 'post',
      h: (path, query, body) => {
        body[idKey] = db.nextId(rows, idKey)
        rows.push(body)
        return ok()
      }
    },
    {
      test: new RegExp('^' + base + '$'),
      m: 'put',
      h: (path, query, body) => {
        const i = rows.findIndex((r) => r[idKey] === body[idKey])
        if (i > -1) rows.splice(i, 1, Object.assign(rows[i], body))
        return ok()
      }
    },
    {
      test: new RegExp('^' + base + '/([\\d,]+)$'),
      m: 'delete',
      h: (path) => {
        const ids = path
          .match(new RegExp('^' + base + '/([\\d,]+)$'))[1]
          .split(',')
          .map(Number)
        for (const id of ids) {
          const i = rows.findIndex((r) => r[idKey] === id)
          if (i > -1) rows.splice(i, 1)
        }
        return ok()
      }
    }
  ]
}

const routes = []
function route(test, m, h) {
  routes.push({ test, m, h })
}

// ---------- 登录与用户 ----------
route(/^\/login$/, 'post', () => ok({ token: 'mock-token-ai-recruit-' + Date.now() }, '登录成功'))
route(/^\/logout$/, 'post', () => ok({}, '退出成功'))
route(/^\/captchaImage$/, 'get', () => ok({ captchaEnabled: false, uuid: 'mock-uuid' }))
route(/^\/getInfo$/, 'get', () =>
  ok({
    permissions: ['*:*:*'],
    roles: ['admin'],
    isDefaultModifyPwd: false,
    isPasswordExpired: false,
    pwdChrtype: 'sys_user_pwd_level_high',
    user: {
      userId: 1,
      userName: 'admin',
      nickName: '超级管理员',
      avatar: '',
      deptId: 100,
      phonenumber: '15888888888',
      email: 'admin@aihire.com',
      sex: '0',
      remark: '平台最高权限'
    }
  })
)
route(/^\/unlockscreen$/, 'post', () => ok())
route(/^\/getRouters$/, 'get', buildMenu)

// ---------- 仪表盘 ----------
// ---------- 用户中心 ----------
route(/^\/member\/user\/(\d+)$/, 'get', (p) =>
  ok({ data: pf.memberDetail(Number(p.match(/^\/member\/user\/(\d+)$/)[1])) })
)
route(/^\/member\/user\/status$/, 'put', (p, q, b) => {
  const u = pf.memberUsers.find((x) => x.userId === Number(b.userId))
  if (u) u.status = b.status
  return ok()
})
route(/^\/member\/user\/cancelAudit$/, 'put', (p, q, b) => {
  const u = pf.memberUsers.find((x) => x.userId === Number(b.userId))
  if (u) {
    if (b.pass === true || b.pass === '1') {
      u.status = '3'
      u.cancelRemark = '注销审核通过'
    } else {
      u.status = '0'
      u.cancelRemark = '注销驳回：' + (b.reason || '')
    }
  }
  return ok()
})
crud('/member/user', pf.memberUsers, 'userId', {
  listFields: { userName: '%userName', phone: 'phone', status: 'status', identity: 'identity' }
})
route(/^\/member\/verify\/audit$/, 'put', (p, q, b) => {
  const v = pf.verifyApps.find((x) => x.verifyId === Number(b.verifyId))
  if (v) {
    v.status = b.status
    v.reason = b.reason || ''
    v.auditTime = '2026-09-07 10:00:00'
    v.auditor = 'admin'
  }
  return ok()
})
crud('/member/verify', pf.verifyApps, 'verifyId', {
  listFields: { status: 'status', companyName: '%companyName', userName: '%userName' }
})

// ---------- 消息管理 ----------
route(/^\/msg\/channel\/toggle$/, 'put', (p, q, b) => {
  const c = pf.msgChannels.find((x) => x.channelId === Number(b.channelId))
  if (c) c.status = c.status === '0' ? '1' : '0'
  return ok()
})
crud('/msg/channel', pf.msgChannels, 'channelId', {})
route(/^\/msg\/record\/resend$/, 'post', (p, q, b) => {
  const r = pf.msgRecords.find((x) => x.recordId === Number(b.recordId))
  if (r) {
    r.status = '0'
    r.failReason = ''
    r.sendTime = '2026-09-07 10:05:00'
  }
  return ok({}, '已重新触发发送')
})
crud('/msg/template', pf.msgTemplates, 'templateId', {
  listFields: { templateName: '%templateName', channel: 'channel', msgType: 'msgType', status: 'status' }
})
crud('/msg/record', pf.msgRecords, 'recordId', {
  listFields: { channel: 'channel', status: 'status', receiver: '%receiver' }
})

// ---------- 帮助与反馈 ----------
route(/^\/content\/feedback\/handle$/, 'put', (p, q, b) => {
  const f = pf.feedbacks.find((x) => x.feedbackId === Number(b.feedbackId))
  if (f) {
    f.status = b.status
    f.reply = b.reply || ''
    f.handler = 'admin'
    f.handleTime = '2026-09-07 10:08:00'
  }
  return ok()
})
crud('/content/feedback', pf.feedbacks, 'feedbackId', {
  listFields: { type: 'type', status: 'status', userName: '%userName' }
})
route(/^\/content\/service\/config$/, 'get', () => ok({ data: pf.serviceConfig }))
route(/^\/content\/service\/config$/, 'put', (p, q, b) => {
  Object.assign(pf.serviceConfig, b)
  return ok()
})
crud('/content/help', pf.helpArticles, 'articleId', {
  listFields: { title: '%title', categoryName: '%categoryName', status: 'status' }
})

// ---------- AI 评估配置 ----------
crud('/ai/scorecard', pf.scorecards, 'cardId', {
  listFields: { cardName: '%cardName', jobDirection: '%jobDirection', status: 'status' }
})
crud('/ai/cascade', pf.cascadeRules, 'ruleId', { listFields: { ruleName: '%ruleName', status: 'status' } })

// ---------- 业务监管 ----------
route(/^\/biz\/job\/audit$/, 'put', (p, q, b) => {
  const j = pf.platformJobs.find((x) => x.jobId === Number(b.jobId))
  if (j) {
    j.status = b.status
    j.reason = b.reason || ''
    j.auditTime = '2026-09-07 10:12:00'
  }
  return ok()
})
crud('/biz/job', pf.platformJobs, 'jobId', {
  listFields: { jobName: '%jobName', companyName: '%companyName', status: 'status', riskLevel: 'riskLevel' }
})
route(/^\/biz\/interview\/terminate$/, 'put', (p, q, b) => {
  const it = pf.interviews.find((x) => x.interviewId === Number(b.interviewId))
  if (it) {
    it.status = '3'
    it.terminateReason = b.reason || '平台强制结束'
  }
  return ok()
})
route(/^\/biz\/interview\/(\d+)$/, 'get', (p) =>
  ok({ data: pf.interviewDetail(Number(p.match(/^\/biz\/interview\/(\d+)$/)[1])) })
)
crud('/biz/interview', pf.interviews, 'interviewId', {
  listFields: { status: 'status', mode: 'mode', candidate: '%candidate' }
})
route(/^\/biz\/exam\/config$/, 'get', () => ok({ data: pf.examConfig }))
route(/^\/biz\/exam\/config$/, 'put', (p, q, b) => {
  Object.assign(pf.examConfig, b)
  return ok()
})
crud('/biz/exam/record', pf.examRecords, 'recordId', {
  listFields: { candidate: '%candidate', status: 'status', language: 'language' }
})

route(/^\/dashboard\/stats$/, 'get', () => ok({ data: biz.dashboardStats }))
route(/^\/dashboard\/trend$/, 'get', () => ok({ data: biz.dashboardTrend() }))
route(/^\/dashboard\/packageDist$/, 'get', () => ok({ data: biz.packageDist }))
route(/^\/dashboard\/apiTop$/, 'get', () => ok({ data: biz.apiTop }))
route(/^\/dashboard\/recentLogs$/, 'get', () => ok({ data: biz.recentLogs }))
route(/^\/dashboard\/recruitmentOverview$/, 'get', () => ok({ data: biz.recruitmentOverview }))

// ---------- 租户管理 ----------
route(/^\/tenant\/company\/list$/, 'get', (p, q) => {
  const filtered = biz.companies.filter(
    (c) =>
      (!q.companyName || c.companyName.includes(q.companyName)) &&
      (!q.contactName || c.contactName.includes(q.contactName)) &&
      (!q.packageType || c.packageType === q.packageType) &&
      (!q.status || c.status === q.status)
  )
  return ok(paginate(filtered, q), '查询成功')
})
route(/^\/tenant\/company\/(\d+)$/, 'get', (p) => biz.companyDetail(p.match(/^\/tenant\/company\/(\d+)$/)[1]))
route(/^\/tenant\/company$/, 'post', (p, q, b) => {
  b.companyId = db.nextId(biz.companies, 'companyId')
  b.candidateCount = 0
  b.apiUsed = 0
  biz.companies.push(b)
  return ok()
})
route(/^\/tenant\/company$/, 'put', (p, q, b) => {
  const i = biz.companies.findIndex((c) => c.companyId === b.companyId)
  if (i > -1) biz.companies.splice(i, 1, Object.assign(biz.companies[i], b))
  return ok()
})
route(/^\/tenant\/company\/changeStatus$/, 'put', (p, q, b) => {
  const c = biz.companies.find((c) => c.companyId === Number(b.companyId))
  if (c) c.status = b.status
  return ok()
})
route(/^\/tenant\/company\/([\d,]+)$/, 'delete', (p) => {
  const ids = p
    .match(/^\/tenant\/company\/([\d,]+)$/)[1]
    .split(',')
    .map(Number)
  for (const id of ids) {
    const i = biz.companies.findIndex((c) => c.companyId === id)
    if (i > -1) biz.companies.splice(i, 1)
  }
  return ok()
})
routes.push(...crud('/tenant/package', biz.packages, 'packageId'))

// ---------- AI 配置 ----------
routes.push(...crud('/ai/model', biz.models, 'modelId'))
route(/^\/ai\/model\/test$/, 'post', () => ok({ data: { success: true, latency: 326 } }))
routes.push(...crud('/ai/quota', biz.quotas, 'quotaId'))
route(/^\/ai\/quota\/adjust$/, 'put', (p, q, b) => {
  const row = biz.quotas.find((x) => x.quotaId === Number(b.quotaId))
  if (row) row.monthlyQuota = Number(b.newQuota)
  return ok()
})
route(/^\/ai\/quota\/usage\/(\d+)$/, 'get', (p) => biz.quotaUsage(p.match(/^\/ai\/quota\/usage\/(\d+)$/)[1]))
routes.push(...crud('/ai/prompt', biz.prompts, 'promptId'))
route(/^\/ai\/prompt\/publish$/, 'put', (p, q, b) => {
  const row = biz.prompts.find((x) => x.promptId === Number(b.promptId))
  if (row) {
    row.status = '1'
    row.version = 'v' + (parseFloat(row.version.replace('v', '')) + 0.1).toFixed(1)
  }
  return ok()
})
route(/^\/ai\/prompt\/versions\/(\d+)$/, 'get', (p) =>
  biz.promptVersions(p.match(/^\/ai\/prompt\/versions\/(\d+)$/)[1])
)

// ---------- 内容管理 ----------
route(/^\/content\/category\/list$/, 'get', () =>
  ok({ rows: biz.categories, total: biz.categories.length }, '查询成功')
)
routes.push(...crud('/content/category', biz.categories, 'categoryId'))
routes.push(...crud('/content/question', biz.questions, 'questionId'))

// ---------- 广告管理 ----------
route(/^\/ad\/slot\/(\d+)$/, 'get', (p) => biz.adSlotDetail(p.match(/^\/ad\/slot\/(\d+)$/)[1]))
routes.push(...crud('/ad/slot', biz.adSlots, 'slotId'))
route(/^\/ad\/slot\/changeStatus$/, 'put', (p, q, b) => {
  const s = biz.adSlots.find((x) => x.slotId === Number(b.slotId))
  if (s) s.status = b.status
  return ok()
})
route(/^\/ad\/advert\/stats\/(\d+)$/, 'get', (p) => biz.advertStats(p.match(/^\/ad\/advert\/stats\/(\d+)$/)[1]))
route(/^\/ad\/advert\/(\d+)$/, 'get', (p) => biz.advertDetail(p.match(/^\/ad\/advert\/(\d+)$/)[1]))
routes.push(...crud('/ad/advert', biz.adverts, 'advertId'))
route(/^\/ad\/advert\/changeStatus$/, 'put', (p, q, b) => {
  const a = biz.adverts.find((x) => x.advertId === Number(b.advertId))
  if (a) a.status = b.status
  return ok()
})

// ---------- 系统管理（若依原生） ----------
route(/^\/system\/user\/list$/, 'get', (p, q) => {
  const filtered = db.users.filter(
    (u) =>
      (!q.userName || u.userName.includes(q.userName)) &&
      (!q.phonenumber || u.phonenumber.includes(q.phonenumber)) &&
      (!q.status || u.status === q.status) &&
      (!q.deptId || u.deptId === Number(q.deptId))
  )
  return ok(paginate(filtered, q), '查询成功')
})
route(/^\/system\/user\/deptTree$/, 'get', () => ok({ data: buildTree(db.depts) }))
route(/^\/system\/user\/deptTree\/(\d+)$/, 'get', () => ok({ data: buildTree(db.depts) }))
route(/^\/system\/user\/configKey\/sys\.user\.initPassword$/, 'get', () =>
  ok({ msg: '123456', configKey: 'sys.user.initPassword', configValue: '123456' })
)
route(/^\/system\/user\/$/, 'get', () =>
  ok({
    data: db.users.find((u) => u.userId === 1),
    postIds: [],
    roleIds: [],
    posts: [
      { postId: 1, postName: '运营经理' },
      { postId: 2, postName: '技术经理' }
    ],
    roles: db.roles
  })
)
route(/^\/system\/user\/(\d+)$/, 'get', (p) => {
  const id = Number(p.match(/^\/system\/user\/(\d+)$/)[1])
  return ok({
    data: db.users.find((u) => u.userId === id),
    postIds: [],
    roleIds: [1],
    posts: [
      { postId: 1, postName: '运营经理' },
      { postId: 2, postName: '技术经理' }
    ],
    roles: db.roles
  })
})
route(/^\/system\/user\/profile$/, 'get', () => ok({ data: db.users[0], roleGroup: '超级管理员', postGroup: '管理员' }))
route(/^\/system\/user\/profile\/updatePwd$/, 'put', () => ok())
route(/^\/system\/user\/registerUser$/, 'post', () => ok())
route(/^\/system\/user\/authRole\/(\d+)$/, 'get', () => ok({ data: db.users[0], roles: db.roles }))
route(/^\/system\/user\/authRole$/, 'put', () => ok())
route(/^\/system\/user$/, 'post', (p, q, b) => {
  b.userId = db.nextId(db.users, 'userId')
  db.users.push(Object.assign({ dept: { deptName: '运营部' }, createTime: '2026-09-04 12:00:00' }, b))
  return ok()
})
route(/^\/system\/user$/, 'put', (p, q, b) => {
  const i = db.users.findIndex((u) => u.userId === b.userId)
  if (i > -1) db.users.splice(i, 1, Object.assign(db.users[i], b))
  return ok()
})
route(/^\/system\/user\/resetPwd$/, 'put', () => ok())
route(/^\/system\/user\/changeStatus$/, 'put', (p, q, b) => {
  const u = db.users.find((u) => u.userId === Number(b.userId))
  if (u) u.status = b.status
  return ok()
})
route(/^\/system\/user\/([\d,]+)$/, 'delete', (p) => {
  const ids = p
    .match(/^\/system\/user\/([\d,]+)$/)[1]
    .split(',')
    .map(Number)
  for (const id of ids) {
    if (id === 1) continue
    const i = db.users.findIndex((u) => u.userId === id)
    if (i > -1) db.users.splice(i, 1)
  }
  return ok()
})

route(/^\/system\/role\/list$/, 'get', (p, q) =>
  ok(paginate(filterRows(db.roles, q, { roleName: '%roleName', roleKey: '%roleKey', status: 'status' }), q), '查询成功')
)
route(/^\/system\/role\/deptTree\/(\d+)$/, 'get', () => ok({ checkedKeys: [101], depts: buildTree(db.depts) }))
route(/^\/system\/role\/deptTree$/, 'get', () => ok({ data: buildTree(db.depts) }))
route(/^\/system\/role\/optionselect$/, 'get', () => ok({ data: db.roles }))
route(/^\/system\/role\/authUser\/selectedList$/, 'get', () => ok({ rows: db.users.slice(0, 3), total: 3 }))
route(/^\/system\/role\/authUser\/unselectedList$/, 'get', () =>
  ok({ rows: db.users.slice(3), total: db.users.length - 3 })
)
route(/^\/system\/role\/authUser\/cancel(All)?$/, 'put', () => ok())
route(/^\/system\/role\/authUser\/selectAll$/, 'put', () => ok())
route(/^\/system\/role\/dataScope$/, 'put', () => ok())
route(/^\/system\/role\/changeStatus$/, 'put', (p, q, b) => {
  const r = db.roles.find((r) => r.roleId === Number(b.roleId))
  if (r) r.status = b.status
  return ok()
})
route(/^\/system\/role\/(\d+)$/, 'get', (p) => {
  const id = Number(p.match(/^\/system\/role\/(\d+)$/)[1])
  return ok({ data: db.roles.find((r) => r.roleId === id), menuIds: [100, 101, 102, 103, 104, 105] })
})
route(/^\/system\/role$/, 'post', (p, q, b) => {
  b.roleId = db.nextId(db.roles, 'roleId')
  db.roles.push(b)
  return ok()
})
route(/^\/system\/role$/, 'put', (p, q, b) => {
  const i = db.roles.findIndex((r) => r.roleId === b.roleId)
  if (i > -1) db.roles.splice(i, 1, Object.assign(db.roles[i], b))
  return ok()
})
route(/^\/system\/role\/([\d,]+)$/, 'delete', (p) => {
  const ids = p
    .match(/^\/system\/role\/([\d,]+)$/)[1]
    .split(',')
    .map(Number)
  for (const id of ids) {
    if (id === 1) continue
    const i = db.roles.findIndex((r) => r.roleId === id)
    if (i > -1) db.roles.splice(i, 1)
  }
  return ok()
})

route(/^\/system\/menu\/list$/, 'get', (p, q) => {
  const filtered = db.menus
    .filter((m) => !q.menuName || m.menuName.includes(q.menuName))
    .filter((m) => !q.status || m.status === q.status)
  return ok({ data: filtered, msg: '查询成功' })
})
route(/^\/system\/menu\/treeselect$/, 'get', () => ok({ data: buildTreeSelect(db.menus) }))
route(/^\/system\/menu\/roleMenuTreeselect\/(\d+)$/, 'get', () =>
  ok({ checkedKeys: [100, 101, 102], menus: buildTreeSelect(db.menus) })
)
route(/^\/system\/menu$/, 'post', (p, q, b) => {
  b.menuId = db.nextId(db.menus, 'menuId')
  db.menus.push(b)
  return ok()
})
route(/^\/system\/menu$/, 'put', (p, q, b) => {
  const i = db.menus.findIndex((m) => m.menuId === b.menuId)
  if (i > -1) db.menus.splice(i, 1, Object.assign(db.menus[i], b))
  return ok()
})
route(/^\/system\/menu\/([\d,]+)$/, 'delete', (p) => {
  const ids = p
    .match(/^\/system\/menu\/([\d,]+)$/)[1]
    .split(',')
    .map(Number)
  for (const id of ids) {
    const i = db.menus.findIndex((m) => m.menuId === id)
    if (i > -1) db.menus.splice(i, 1)
  }
  return ok()
})

route(/^\/system\/dict\/type\/list$/, 'get', (p, q) =>
  ok(
    paginate(filterRows(db.dictTypes, q, { dictName: '%dictName', dictType: '%dictType', status: 'status' }), q),
    '查询成功'
  )
)
route(/^\/system\/dict\/type\/optionselect$/, 'get', () => ok({ data: db.dictTypes }))
route(/^\/system\/dict\/data\/list$/, 'get', (p, q) => {
  const type = q.dictType
  const rows = type ? db.dictDatas[type] || [] : Object.values(db.dictDatas).flat()
  return ok(paginate(rows, q), '查询成功')
})
route(/^\/system\/dict\/data\/type\/([\w-]+)$/, 'get', (p) => {
  const type = p.match(/^\/system\/dict\/data\/type\/([\w-]+)$/)[1]
  return ok({ data: db.dictDatas[type] || [] })
})
route(/^\/system\/dict\/data\/([\d,]+)$/, 'delete', () => ok())
route(/^\/system\/dict\/type\/([\d,]+)$/, 'delete', () => ok())
route(/^\/system\/dict\/type\/refreshCache$/, 'delete', () => ok())
route(/^\/system\/dict\/data\/edit$/, 'put', () => ok())
route(/^\/system\/dict\/type$/, 'put', () => ok())
route(/^\/system\/dict\/type$/, 'post', () => ok())
route(/^\/system\/dict\/data$/, 'post', () => ok())
route(/^\/system\/dict\/data$/, 'put', () => ok())

route(/^\/system\/post\/list$/, 'get', () =>
  ok(
    paginate(
      [
        { postId: 1, postCode: 'ops', postName: '运营经理', postSort: 1, status: '0' },
        { postId: 2, postCode: 'tech', postName: '技术经理', postSort: 2, status: '0' }
      ],
      {}
    ),
    '查询成功'
  )
)
route(/^\/system\/post\/optionselect$/, 'get', () =>
  ok({
    data: [
      { postId: 1, postCode: 'ops', postName: '运营经理' },
      { postId: 2, postCode: 'tech', postName: '技术经理' }
    ]
  })
)
route(/^\/system\/dept\/list$/, 'get', (p, q) => {
  const filtered = db.depts.filter((d) => !q.deptName || d.deptName.includes(q.deptName))
  return ok({ data: filtered, msg: '查询成功' })
})
route(/^\/system\/notice\/list$/, 'get', (p, q) =>
  ok(
    paginate(
      filterRows(db.notices, q, { noticeTitle: '%noticeTitle', createBy: '%createBy', noticeType: 'noticeType' }),
      q
    ),
    '查询成功'
  )
)
route(/^\/system\/notice\/(\d+)$/, 'get', (p) =>
  ok({ data: db.notices.find((n) => n.noticeId === Number(p.match(/^\/system\/notice\/(\d+)$/)[1])) })
)
route(/^\/system\/notice$/, 'post', (p, q, b) => {
  b.noticeId = db.nextId(db.notices, 'noticeId')
  db.notices.push(b)
  return ok()
})
route(/^\/system\/notice$/, 'put', (p, q, b) => {
  const i = db.notices.findIndex((n) => n.noticeId === b.noticeId)
  if (i > -1) db.notices.splice(i, 1, Object.assign(db.notices[i], b))
  return ok()
})
route(/^\/system\/notice\/([\d,]+)$/, 'delete', (p) => {
  const ids = p
    .match(/^\/system\/notice\/([\d,]+)$/)[1]
    .split(',')
    .map(Number)
  for (const id of ids) {
    const i = db.notices.findIndex((n) => n.noticeId === id)
    if (i > -1) db.notices.splice(i, 1)
  }
  return ok()
})
route(/^\/system\/config\/configKey\/(.+)$/, 'get', () => ok({ msg: '123456', configValue: '123456' }))

// ---------- 系统监控 ----------
route(/^\/monitor\/online\/list$/, 'get', (p, q) =>
  ok(paginate(filterRows(db.onlineUsers, q, { userName: '%userName', ipaddr: '%ipaddr' }), q), '查询成功')
)
route(/^\/monitor\/online\/[\w-]+$/, 'delete', () => ok())
route(/^\/monitor\/server$/, 'get', () => ok({ data: db.serverInfo, msg: '获取成功' }))
route(/^\/monitor\/job\/list$/, 'get', (p, q) =>
  ok(paginate(filterRows(db.jobs, q, { jobName: '%jobName', jobGroup: 'jobGroup', status: 'status' }), q), '查询成功')
)
route(/^\/monitor\/job\/(\d+)$/, 'get', (p) =>
  ok({ data: db.jobs.find((j) => j.jobId === Number(p.match(/^\/monitor\/job\/(\d+)$/)[1])) })
)
route(/^\/monitor\/job\/changeStatus$/, 'put', (p, q, b) => {
  const j = db.jobs.find((j) => j.jobId === Number(b.jobId))
  if (j) j.status = b.status
  return ok()
})
route(/^\/monitor\/job\/run$/, 'put', () => ok())
route(/^\/monitor\/jobLog\/list$/, 'get', () =>
  ok(
    paginate(
      [
        {
          jobLogId: 1,
          jobName: '每日配额重置',
          jobGroup: 'DEFAULT',
          invokeTarget: 'quotaTask.reset',
          jobMessage: '重置 128 家企业配额完成',
          status: '0',
          createTime: '2026-09-04 00:00:03'
        }
      ],
      {}
    ),
    '查询成功'
  )
)
route(/^\/monitor\/operlog\/list$/, 'get', (p, q) => {
  const filtered = db.operLogs.filter(
    (l) =>
      (!q.title || l.title.includes(q.title)) &&
      (!q.operName || l.operName.includes(q.operName)) &&
      (!q.businessType || l.businessType === q.businessType) &&
      (!q.status || l.status === q.status)
  )
  return ok(paginate(filtered, q), '查询成功')
})
route(/^\/monitor\/operlog\/clean$/, 'delete', () => ok())
route(/^\/monitor\/operlog\/([\d,]+)$/, 'delete', () => ok())
route(/^\/monitor\/logininfor\/list$/, 'get', (p, q) => {
  const filtered = db.logininforLogs.filter(
    (l) =>
      (!q.userName || l.userName.includes(q.userName)) &&
      (!q.ipaddr || l.ipaddr.includes(q.ipaddr)) &&
      (!q.status || l.status === q.status)
  )
  return ok(paginate(filtered, q), '查询成功')
})
route(/^\/monitor\/logininfor\/clean$/, 'delete', () => ok())
route(/^\/monitor\/logininfor\/([\d,]+)$/, 'delete', () => ok())

// ---------- 通知偏好 ----------
const prefData = []
for (let i = 1; i <= 20; i++) {
  prefData.push({
    prefId: i,
    userId: Math.floor(Math.random() * 50) + 1,
    userName: `用户${i}`,
    channel: ['email', 'sms', 'app', 'wechat'][i % 4],
    weeklyReport: i % 3 !== 0,
    interviewRemind: i % 2 === 0,
    resultNotify: true,
    marketingEmail: i % 5 !== 0,
    status: '0',
    updateTime: '2026-09-0' + ((i % 9) + 1) + ' 10:00:00'
  })
}
route(/^\/msg\/preference\/list$/, 'get', (p, q) => ok(paginate(prefData, q), '查询成功'))
route(/^\/msg\/preference\/(\d+)$/, 'get', (p) =>
  ok({ data: prefData.find((x) => x.prefId === Number(p.match(/^\/msg\/preference\/(\d+)$/)[1])) })
)
route(/^\/msg\/preference$/, 'put', (p, q, b) => {
  const i = prefData.findIndex((x) => x.prefId === b.prefId)
  if (i > -1) Object.assign(prefData[i], b)
  return ok()
})
route(/^\/msg\/preference\/toggle$/, 'put', (p, q, b) => {
  const p2 = prefData.find((x) => x.prefId === b.prefId)
  if (p2) p2[b.field] = b.value
  return ok()
})
route(/^\/msg\/preference\/batch$/, 'put', () => ok())

// ---------- AI应答 ----------
const aiConfig = {
  aiEnabled: true,
  aiResponseRate: 85,
  aiReplyPrefix: '【AI助手】',
  aiWorkingHours: '00:00-23:59',
  maxWaitTime: 30
}
const aiRecords = []
for (let i = 1; i <= 15; i++) {
  aiRecords.push({
    recordId: i,
    conversationId: 'conv-' + String(i).padStart(4, '0'),
    userId: Math.floor(Math.random() * 50) + 1,
    userName: `候选人${i}`,
    question: '请问贵公司的面试流程是怎样的？',
    aiAnswer: '您好，我们的面试流程包括初试、复试和终试三个阶段...',
    userSatisfaction: i % 3 === 0 ? 2 : 5,
    escalateToHuman: i % 5 === 0,
    createTime: '2026-09-0' + ((i % 9) + 1) + ' ' + String(8 + (i % 12)).padStart(2, '0') + ':00:00'
  })
}
const aiKnowledge = []
for (let i = 1; i <= 10; i++) {
  aiKnowledge.push({
    knowledgeId: i,
    question: [
      '面试流程是怎样的？',
      '薪资范围多少？',
      '工作时间是什么？',
      '五险一金缴纳比例？',
      '是否双休？',
      '晋升机制如何？',
      '远程办公政策？',
      '试用期多长？',
      '培训体系怎样？',
      '加班是否有补贴？'
    ][i - 1],
    answer: '公司严格按照国家法律规定为员工缴纳五险一金...',
    category: ['HR政策', '薪酬福利', '工作流程', '职业发展'][i % 4],
    viewCount: Math.floor(Math.random() * 200) + 10,
    status: i % 7 === 0 ? '0' : '1'
  })
}
route(/^\/msg\/aiConfig$/, 'get', () => ok({ data: aiConfig }))
route(/^\/msg\/aiConfig$/, 'put', (p, q, b) => {
  Object.assign(aiConfig, b)
  return ok()
})
route(/^\/msg\/aiRecord\/list$/, 'get', (p, q) => ok(paginate(aiRecords, q), '查询成功'))
route(/^\/msg\/aiKnowledge\/list$/, 'get', (p, q) => ok(paginate(aiKnowledge, q), '查询成功'))
route(/^\/msg\/aiKnowledge$/, 'post', (p, q, b) => {
  b.knowledgeId = db.nextId(aiKnowledge, 'knowledgeId')
  aiKnowledge.push(b)
  return ok()
})
route(/^\/msg\/aiKnowledge$/, 'put', (p, q, b) => {
  const i = aiKnowledge.findIndex((x) => x.knowledgeId === b.knowledgeId)
  if (i > -1) aiKnowledge.splice(i, 1, Object.assign(aiKnowledge[i], b))
  return ok()
})
route(/^\/msg\/aiKnowledge\/([\d,]+)$/, 'delete', (p) => {
  const ids = p
    .match(/^\/msg\/aiKnowledge\/([\d,]+)$/)[1]
    .split(',')
    .map(Number)
  for (const id of ids) {
    const i = aiKnowledge.findIndex((x) => x.knowledgeId === id)
    if (i > -1) aiKnowledge.splice(i, 1)
  }
  return ok()
})

// ---------- 隐私设置 ----------
const privacyData = {
  resumeVisibility: '1',
  contactVisibility: '0',
  searchPermission: '1',
  profileVisible: '1',
  allowDirectMessage: '1',
  showOnlineStatus: '1'
}
const exportDataList = []
for (let i = 1; i <= 8; i++) {
  exportDataList.push({
    exportId: i,
    userId: Math.floor(Math.random() * 50) + 1,
    dataType: ['简历数据', '面试记录', '评估报告', '岗位信息', '全部数据'][i % 5],
    status: i % 3 === 0 ? '0' : '1',
    createTime: '2026-09-0' + ((i % 9) + 1) + ' 10:00:00',
    downloadUrl: i % 3 !== 0 ? '' : '/download/export-' + i + '.zip'
  })
}
route(/^\/system\/privacy$/, 'get', () => ok({ data: privacyData }))
route(/^\/system\/privacy$/, 'put', (p, q, b) => {
  Object.assign(privacyData, b)
  return ok()
})
route(/^\/system\/data\/export$/, 'get', (p, q) => ok(paginate(exportDataList, q), '查询成功'))
route(/^\/system\/data\/export\/run$/, 'post', () => ok())
route(/^\/system\/data\/export\/([\d,]+)$/, 'delete', (p) => ok())

// ---------- 界面与系统维护 ----------
const themeConfig = {
  themeMode: 'light',
  primaryColor: '#136BFD',
  language: 'zh-CN',
  sidebarWidth: 200,
  tableRowHeight: 'medium',
  logoType: 'both'
}
const sysStatus = {
  cpuUsage: 45,
  memoryUsage: 68,
  diskUsage: 52,
  totalCandidates: 1286,
  totalJobs: 342,
  todayInterviews: 18
}
const operLogExtended = []
for (let i = 1; i <= 10; i++) {
  operLogExtended.push({
    logId: i,
    title: ['修改隐私设置', '导出简历数据', '删除广告', '重启服务', '刷新缓存'][i % 5],
    businessType: i % 3 === 0 ? '2' : '3',
    operName: 'admin',
    operUrl: '/system/privacy',
    operIp: '192.168.1.' + (10 + i),
    operLocation: '内网IP',
    operTime: '2026-09-0' + ((i % 9) + 1) + ' 10:00:00',
    costTime: (Math.random() * 500 + 50).toFixed(2)
  })
}
const cronJobs = []
for (let i = 1; i <= 6; i++) {
  cronJobs.push({
    jobId: i,
    jobName: ['每日配额重置', '每周报表生成', '候选人过期处理', '面试自动提醒', '数据备份任务', '日志清理'][i - 1],
    invokeTarget: `cronTask${i}.reset`,
    cronExpression: ['0 0 0 * * ?', '0 0 9 ? * MON', '0 0 2 * * ?', '*/30 * * * * ?', '0 0 1 * * ?', '0 0 3 * * ?'][
      i - 1
    ],
    status: i % 5 === 0 ? '0' : '1',
    misfirePolicy: '1',
    createTime: '2026-09-01 10:00:00'
  })
}
route(/^\/system\/theme$/, 'get', () => ok({ data: themeConfig }))
route(/^\/system\/theme$/, 'put', (p, q, b) => {
  Object.assign(themeConfig, b)
  return ok()
})
route(/^\/system\/maintenance\/status$/, 'get', () => ok({ data: sysStatus }))
route(/^\/system\/maintenance\/cache$/, 'delete', () => ok())
route(/^\/system\/maintenance\/error$/, 'post', () => ok())
route(/^\/system\/maintenance\/operlog$/, 'get', (p, q) => ok(paginate(operLogExtended, q), '查询成功'))
route(/^\/system\/maintenance\/cron$/, 'get', (p, q) => ok(paginate(cronJobs, q), '查询成功'))
route(/^\/system\/maintenance\/cron\/changeStatus$/, 'put', (p, q, b) => {
  const j = cronJobs.find((x) => x.jobId === b.jobId)
  if (j) j.status = b.status
  return ok()
})
route(/^\/system\/maintenance\/cron\/run$/, 'put', (p, q, b) => {
  const j = cronJobs.find((x) => x.jobId === b.jobId)
  if (j) j.lastRunTime = '2026-09-08 10:00:00'
  return ok()
})

// ---------- 简历库管理 ----------
const resumeList = []
for (let i = 1; i <= 30; i++) {
  resumeList.push({
    resumeId: i,
    userId: Math.floor(Math.random() * 50) + 1,
    userName: `候选人${i}`,
    resumeTitle: ['高级前端工程师', '产品经理', 'Java开发工程师', 'UI设计师', '数据分析师'][i % 5],
    experience: Math.floor(Math.random() * 10) + '年经验',
    completeness: [95, 88, 72, 100, 60][i % 5],
    status: ['completed', 'incomplete', 'reviewing'][i % 3],
    uploadTime: '2026-09-0' + ((i % 9) + 1) + ' 10:00:00',
    tags: i % 3 === 0 ? ['优质', '急招'] : i % 2 === 0 ? ['优质'] : []
  })
}
route(/^\/biz\/resume\/list$/, 'get', (p, q) => ok(paginate(resumeList, q), '查询成功'))
route(/^\/biz\/resume\/(\d+)$/, 'get', (p) =>
  ok({ data: resumeList.find((x) => x.resumeId === Number(p.match(/^\/biz\/resume\/(\d+)$/)[1])) })
)
route(/^\/biz\/resume$/, 'post', (p, q, b) => {
  b.resumeId = db.nextId(resumeList, 'resumeId')
  resumeList.push(b)
  return ok()
})
route(/^\/biz\/resume$/, 'put', (p, q, b) => {
  const i = resumeList.findIndex((x) => x.resumeId === b.resumeId)
  if (i > -1) resumeList.splice(i, 1, Object.assign(resumeList[i], b))
  return ok()
})
route(/^\/biz\/resume\/([\d,]+)$/, 'delete', (p) => ok())

// ---------- 简历解析 ----------
const parseRecords = []
for (let i = 1; i <= 15; i++) {
  parseRecords.push({
    parseId: i,
    resumeId: i,
    userName: `候选人${i}`,
    fileName: `resume_${i}.pdf`,
    parseStatus: i % 4 === 0 ? '2' : i % 3 === 0 ? '1' : '0',
    parseRate: [95, 88, 72, 100, 60][i % 5],
    fieldsExtracted: Math.floor(Math.random() * 15) + 5,
    createTime: '2026-09-0' + ((i % 9) + 1) + ' 10:00:00',
    parsedFields: {
      name: `候选人${i}`,
      phone: `138${String(Math.floor(Math.random() * 100000000)).padStart(8, '0')}`,
      email: `user${i}@email.com`,
      education: ['本科', '硕士', '博士'][i % 3],
      experience: `${Math.floor(Math.random() * 10) + 1}年`
    }
  })
}
route(/^\/biz\/resumeParse\/list$/, 'get', (p, q) => ok(paginate(parseRecords, q), '查询成功'))
route(/^\/biz\/resumeParse\/file$/, 'post', () => ok({ data: { parseId: db.nextId(parseRecords, 'parseId') } }))
route(/^\/biz\/resumeParse\/rescan$/, 'post', (p, q, b) => {
  const pid = b.parseId || Number(p.split('/').pop())
  if (pid) {
    const r = parseRecords.find((x) => x.parseId === pid)
    if (r) r.parseStatus = '0'
  }
  return ok({ parseId: db.nextId(parseRecords, 'parseId') })
})
route(/^\/biz\/resumeParse\/[0-9]+\/rescan$/, 'post', (p) => {
  const id = Number(p.split('/')[4])
  const r = parseRecords.find((x) => x.parseId === id)
  if (r) r.parseStatus = '0'
  return ok()
})
route(/^\/biz\/resumeParse\/(\d+)$/, 'get', (p) =>
  ok({ data: parseRecords.find((x) => x.parseId === Number(p.match(/^\/biz\/resumeParse\/(\d+)$/)[1])) })
)

// ---------- AI初筛 ----------
const screenData = []
for (let i = 1; i <= 20; i++) {
  screenData.push({
    screenId: i,
    resumeId: i,
    userName: `候选人${i}`,
    matchScore: Math.floor(Math.random() * 40) + 60,
    dimensionScores: JSON.stringify({
      skills: Math.floor(Math.random() * 30) + 70,
      experience: Math.floor(Math.random() * 30) + 65,
      education: Math.floor(Math.random() * 30) + 75
    }),
    highlights: ['技能匹配', '经验丰富', '学历优秀'][i % 3],
    gaps: ['行业经验不足', '缺少某个技术栈'],
    status: i % 3 === 0 ? '0' : i % 2 === 0 ? '1' : '2',
    createTime: '2026-09-0' + ((i % 9) + 1) + ' 10:00:00'
  })
}
route(/^\/biz\/aiScreen\/list$/, 'get', (p, q) => ok(paginate(screenData, q), '查询成功'))
route(/^\/biz\/aiScreen\/run$/, 'post', () => ok())
route(/^\/biz\/aiScreen\/(\d+)$/, 'get', (p) =>
  ok({ data: screenData.find((x) => x.screenId === Number(p.match(/^\/biz\/aiScreen\/(\d+)$/)[1])) })
)
route(/^\/biz\/aiScreen\/changeStatus$/, 'put', (p, q, b) => {
  const s = screenData.find((x) => x.screenId === b.screenId)
  if (s) s.status = b.status
  return ok()
})
route(/^\/biz\/aiScreen\/status$/, 'put', (p, q, b) => {
  const s = screenData.find((x) => x.screenId === b.screenId)
  if (s) s.status = b.status
  return ok()
})
route(/^\/biz\/aiScreen\/batchRun$/, 'post', () => ok())

// ---------- 智能预约调度 ----------
const scheduleData = []
for (let i = 1; i <= 20; i++) {
  scheduleData.push({
    scheduleId: i,
    candidateId: i,
    candidate: `候选人${i}`,
    jobId: Math.floor(Math.random() * 10) + 1,
    jobName: ['前端开发', '后端开发', '产品经理', 'UI设计'][i % 4],
    mode: i % 3 === 0 ? 'video' : 'phone',
    status: ['pending', 'confirmed', 'completed', 'cancelled'][i % 4],
    scheduledTime: '2026-09-' + String(10 + (i % 20)).padStart(2, '0') + ' 14:00:00',
    interviewer: `面试官${(i % 5) + 1}`,
    createTime: '2026-09-0' + ((i % 9) + 1) + ' 10:00:00'
  })
}
route(/^\/biz\/schedule\/list$/, 'get', (p, q) => ok(paginate(scheduleData, q), '查询成功'))
route(/^\/biz\/schedule\/(\d+)$/, 'get', (p) =>
  ok({ data: scheduleData.find((x) => x.scheduleId === Number(p.match(/^\/biz\/schedule\/(\d+)$/)[1])) })
)
route(/^\/biz\/schedule$/, 'post', (p, q, b) => {
  b.scheduleId = db.nextId(scheduleData, 'scheduleId')
  scheduleData.push(b)
  return ok()
})
route(/^\/biz\/schedule$/, 'put', (p, q, b) => {
  const i = scheduleData.findIndex((x) => x.scheduleId === b.scheduleId)
  if (i > -1) scheduleData.splice(i, 1, Object.assign(scheduleData[i], b))
  return ok()
})
route(/^\/biz\/schedule\/cancel$/, 'put', (p, q, b) => {
  const ids = String(b.scheduleIds || b.ids || b.scheduleId || '')
    .split(',')
    .map(Number)
    .filter(Boolean)
  for (const id of ids) {
    const s = scheduleData.find((x) => x.scheduleId === id)
    if (s) s.status = 'cancelled'
  }
  return ok()
})
route(/^\/biz\/schedule\/batchCancel$/, 'put', () => ok())
route(/^\/biz\/schedule\/reschedule$/, 'put', (p, q, b) => {
  const s = scheduleData.find((x) => x.scheduleId === b.scheduleId)
  if (s) {
    s.status = 'pending'
    s.scheduledTime = b.newTime
  }
  return ok()
})

// ---------- 面试评估 ----------
const evalData = []
for (let i = 1; i <= 15; i++) {
  evalData.push({
    evalId: i,
    interviewId: i,
    candidate: `候选人${i}`,
    jobId: Math.floor(Math.random() * 10) + 1,
    dimensionScores: JSON.stringify({
      professional: Math.floor(Math.random() * 30) + 70,
      communication: Math.floor(Math.random() * 30) + 65,
      cultureFit: Math.floor(Math.random() * 30) + 75,
      potential: Math.floor(Math.random() * 30) + 60
    }),
    overallScore: Math.floor(Math.random() * 30) + 70,
    evaluation: ['整体表现优秀，建议进入下一轮', '技能达标但沟通一般', '综合素质较高，可培养'][i % 3],
    result: ['pass', 'conditional_pass', 'fail'][i % 3],
    status: i % 4 === 0 ? '0' : i % 3 === 0 ? '1' : '2',
    finalizeTime: i % 5 === 0 ? '' : '2026-09-0' + ((i % 9) + 1) + ' 16:00:00',
    createTime: '2026-09-0' + ((i % 9) + 1) + ' 10:00:00'
  })
}
route(/^\/biz\/interviewEval\/list$/, 'get', (p, q) => ok(paginate(evalData, q), '查询成功'))
route(/^\/biz\/interviewEval\/(\d+)$/, 'get', (p) =>
  ok({ data: evalData.find((x) => x.evalId === Number(p.match(/^\/biz\/interviewEval\/(\d+)$/)[1])) })
)
route(/^\/biz\/interviewEval$/, 'post', (p, q, b) => {
  b.evalId = db.nextId(evalData, 'evalId')
  evalData.push(b)
  return ok()
})
route(/^\/biz\/interviewEval$/, 'put', (p, q, b) => {
  const i = evalData.findIndex((x) => x.evalId === b.evalId)
  if (i > -1) evalData.splice(i, 1, Object.assign(evalData[i], b))
  return ok()
})
route(/^\/biz\/interviewEval\/submit$/, 'post', (p, q, b) => {
  const ids = String(b.evalIds || b.evalId || '')
    .split(',')
    .map(Number)
    .filter((v) => !isNaN(v))
  for (const id of ids) {
    const e = evalData.find((x) => x.evalId === id)
    if (e) {
      e.result = b.result || e.result
      e.status = '2'
      e.finalizeTime = '2026-09-08 10:00:00'
    }
  }
  return ok()
})
route(/^\/biz\/interviewEval\/changeStatus$/, 'put', (p, q, b) => {
  const e = evalData.find((x) => x.evalId === b.evalId)
  if (e) e.status = b.status
  return ok()
})
route(/^\/biz\/interviewEval\/batchFinalize$/, 'post', () => ok())

// ---------- 候选人管理 ----------
const candidateData = []
for (let i = 1; i <= 25; i++) {
  candidateData.push({
    candidateId: i,
    userId: i,
    userName: `候选人${i}`,
    status: ['active', 'interviewing', 'offer', 'hired', 'rejected'][i % 5],
    tags: i % 3 === 0 ? ['优质', '急招'] : i % 2 === 0 ? ['VIP'] : [],
    currentStage: ['简历筛选', '初试', '复试', '终试', 'Offer审批'][i % 5],
    applyTime: '2026-09-0' + ((i % 9) + 1) + ' 10:00:00',
    latestUpdate: '2026-09-0' + ((i % 9) + 1) + ' 14:00:00'
  })
}
route(/^\/biz\/candidate\/list$/, 'get', (p, q) => ok(paginate(candidateData, q), '查询成功'))
route(/^\/biz\/candidate\/(\d+)$/, 'get', (p) =>
  ok({ data: candidateData.find((x) => x.candidateId === Number(p.match(/^\/biz\/candidate\/(\d+)$/)[1])) })
)
route(/^\/biz\/candidate\/updateStatus$/, 'put', (p, q, b) => {
  const c = candidateData.find((x) => x.candidateId === b.candidateId)
  if (c) c.status = b.status
  return ok()
})
route(/^\/biz\/candidate\/status$/, 'put', (p, q, b) => {
  const c = candidateData.find((x) => x.candidateId === b.candidateId)
  if (c) c.status = b.status
  return ok()
})
route(/^\/biz\/candidate\/tag$/, 'put', (p, q, b) => {
  const c = candidateData.find((x) => x.candidateId === b.candidateId)
  if (c) c.tags = b.tags || []
  return ok()
})
route(/^\/biz\/candidate\/batchTag$/, 'put', () => ok())
route(/^\/biz\/candidate\/[0-9,]+$/, 'delete', (p) => {
  const ids = p.split('/').pop().split(',').map(Number)
  for (const id of ids) {
    const idx = candidateData.findIndex((x) => x.candidateId === id)
    if (idx > -1) candidateData.splice(idx, 1)
  }
  return ok()
})
export default function mockAdapter(config) {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      const method = (config.method || 'get').toLowerCase()
      const { path, query } = parseUrl(config.url)
      // 命中导出类接口：返回 Blob
      if (/\/export$/.test(path) || /\/importTemplate$/.test(path)) {
        return resolve({
          data: blobResponse(),
          status: 200,
          statusText: 'OK',
          headers: {},
          config,
          request: { responseType: config.responseType || '' }
        })
      }
      for (const r of routes) {
        if (r.m !== method) continue
        if (typeof r.test === 'string' ? r.test === path : r.test.test(path)) {
          const body = parseBody(config)
          try {
            const data = r.h(path, query, body)
            return resolve({
              data,
              status: 200,
              statusText: 'OK',
              headers: {},
              config,
              request: { responseType: config.responseType || '' }
            })
          } catch (e) {
            return reject(e)
          }
        }
      }
      // 兜底：未匹配的写操作直接成功，未匹配的查询返回空列表
      if (['post', 'put', 'delete'].includes(method)) {
        return resolve({
          data: ok(),
          status: 200,
          statusText: 'OK',
          headers: {},
          config,
          request: { responseType: config.responseType || '' }
        })
      }
      return resolve({
        data: ok({ rows: [], total: 0, page: 1, pageSize: 10 }, '查询成功'),
        status: 200,
        statusText: 'OK',
        headers: {},
        config,
        request: { responseType: config.responseType || '' }
      })
    }, 120)
  })
}

// ---------- 树构建 ----------
function buildTree(rows, idKey = 'deptId', parentKey = 'parentId') {
  const map = {}
  const roots = []
  rows.forEach((r) => {
    map[r[idKey]] = Object.assign({}, r, { label: r.deptName, children: [] })
  })
  rows.forEach((r) => {
    const node = map[r[idKey]]
    if (r[parentKey] && map[r[parentKey]]) {
      map[r[parentKey]].children.push(node)
    } else {
      roots.push(node)
    }
  })
  const clean = (nodes) =>
    nodes.map((n) => {
      if (!n.children.length) delete n.children
      else clean(n.children)
      return n
    })
  return clean(roots)
}

function buildTreeSelect(menus) {
  const map = {}
  const roots = []
  menus.forEach((m) => {
    map[m.menuId] = { id: m.menuId, label: m.menuName, children: [] }
  })
  menus.forEach((m) => {
    if (m.parentId && map[m.parentId]) map[m.parentId].children.push(map[m.menuId])
    else roots.push(map[m.menuId])
  })
  const clean = (nodes) =>
    nodes.map((n) => {
      if (!n.children.length) delete n.children
      else clean(n.children)
      return n
    })
  return clean(roots)
}
