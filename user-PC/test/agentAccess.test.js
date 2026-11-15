import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { candidateRedirect } from '../src/utils/agentNavigation.js'

function accessModule({ signedIn = false, confirm = async () => {} } = {}) {
  const navigations = []
  const source = fs.readFileSync(new URL('../src/utils/agentAccess.js', import.meta.url), 'utf8')
    .replace(/^import .*$/gm, '').replace(/^export /gm, '')
  const access = new Function('ElMessageBox', 'hasCandidateAccessToken', 'candidateRedirect', 'window', `${source}\nreturn { isPublicCandidatePage, requestCandidateLogin, requireCandidateLogin }`)(
    { confirm }, () => signedIn, candidateRedirect, { __agentNavigate: route => navigations.push(route) }
  )
  return { ...access, navigations }
}

function permissionGuard({ signedIn = false, prompt = async () => '/login?redirect=%2Fmessages', getInfo = async () => {} } = {}) {
  let guard
  let reads = 0
  let prompts = 0
  const store = { name: '', roles: ['biz_4'], getInfo: async options => { reads++; await getInfo(options) }, $reset() {} }
  const source = fs.readFileSync(new URL('../src/permission.js', import.meta.url), 'utf8')
    .replace(/^import .*$/gm, '').replaceAll('import.meta.env.VITE_FRONTEND_ONLY', 'false')
  const dependencies = {
    router: { beforeEach: callback => { guard = callback }, afterEach() {} },
    NProgress: { configure() {}, start() {}, done() {} },
    hasCandidateAccessToken: () => signedIn,
    getToken: () => signedIn, removeToken() {}, clearCandidateSession() {},
    isPublicCandidatePage: accessModule().isPublicCandidatePage,
    requestCandidateLogin: async target => { prompts++; return prompt(target) },
    useUserStore: () => store, useSettingsStore: () => ({ setTitle() {} }),
    ElMessage: { error() {} }, isRelogin: { show: false }
  }
  new Function(...Object.keys(dependencies), source)(...Object.values(dependencies))
  return { guard, reads: () => reads, prompts: () => prompts }
}

function destination(path) {
  return { path, fullPath: `${path}?id=26#detail`, meta: { candidate: true } }
}

test('仅首页、岗位列表和详情开放匿名浏览，不放开个人页面与接口地址', () => {
  const access = accessModule()
  for (const path of ['/index', '/jobs', '/job-detail']) assert.equal(access.isPublicCandidatePage(path), true)
  for (const path of ['/messages', '/profile-resumes', '/applications', '/resume-select', '/job-assistant', '/agent/v1/jobs']) assert.equal(access.isPublicCandidatePage(path), false)
})

test('游客进入公开页面不读取身份、不弹登录；受保护页面提示后保留回跳目标', async () => {
  const requested = []
  const access = permissionGuard({ prompt: async target => { requested.push(target); return '/login?redirect=%2Fmessages' } })
  for (const path of ['/index', '/jobs', '/job-detail']) assert.equal(await access.guard(destination(path), { matched: [] }), true)
  assert.equal(access.reads(), 0)
  assert.equal(access.prompts(), 0)
  assert.equal(await access.guard(destination('/messages'), { matched: [{}] }), '/login?redirect=%2Fmessages')
  assert.deepEqual(requested, ['/messages?id=26#detail'])
})

test('关闭提示继续留在原页面，直接打开受保护地址时回首页；登录注册本身不拦截', async () => {
  const access = permissionGuard({ prompt: async () => null })
  assert.equal(await access.guard(destination('/resume-select'), { matched: [{}] }), false)
  assert.deepEqual(await access.guard(destination('/messages'), { matched: [] }), { path: '/index', replace: true })
  for (const path of ['/login', '/register']) assert.equal(await access.guard(destination(path), { matched: [] }), true)
})

test('身份恢复失败清理会话后仍能浏览公开页面，正常求职者保留鉴权流程', async () => {
  const expired = permissionGuard({ signedIn: true, getInfo: async options => { assert.equal(options.silentAuth, true); throw new Error('expired') } })
  assert.equal(await expired.guard(destination('/jobs'), { matched: [] }), true)
  const active = permissionGuard({ signedIn: true, getInfo: async options => { assert.equal(options.silentAuth, false) } })
  assert.equal(await active.guard(destination('/messages'), { matched: [] }), true)
  assert.equal(active.reads(), 1)
})

test('登录提示去重，登录注册保留安全的查询和锚点，关闭不会跳转', async () => {
  let finish
  let count = 0
  const access = accessModule({ confirm: () => { count++; return new Promise(resolve => { finish = resolve }) } })
  const first = access.requestCandidateLogin('/resume-select?job=26#apply')
  const second = access.requestCandidateLogin('/messages')
  assert.equal(first, second)
  assert.equal(count, 1)
  finish()
  assert.equal(await first, '/login?redirect=%2Fresume-select%3Fjob%3D26%23apply')
  const register = accessModule({ confirm: () => Promise.reject('cancel') })
  assert.equal(await register.requestCandidateLogin('/jobs'), '/register?redirect=%2Fjobs')
  const close = accessModule({ confirm: () => Promise.reject('close') })
  assert.equal(await close.requestCandidateLogin('/jobs'), null)
  assert.equal(await accessModule().requestCandidateLogin('https://other.example'), '/login?redirect=%2Findex')
})

test('游客收藏等操作立即中止，只有主动选择登录才导航；已登录直接继续', async () => {
  const access = accessModule()
  assert.equal(access.requireCandidateLogin('/job-detail?id=26'), false)
  await new Promise(resolve => setImmediate(resolve))
  assert.deepEqual(access.navigations, ['/login?redirect=%2Fjob-detail%3Fid%3D26'])
  let prompted = false
  const active = accessModule({ signedIn: true, confirm: async () => { prompted = true } })
  assert.equal(active.requireCandidateLogin('/jobs'), true)
  assert.equal(prompted, false)
})
