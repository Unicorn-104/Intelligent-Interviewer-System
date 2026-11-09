import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { reactive, ref } from 'vue'
import { candidateAuthError } from '../src/utils/agentLogin.js'

test('登录连接超时、断网与网关异常显示中文，不误报为账号权限或密码错误', () => {
  for (const error of [new Error('timeout of 10000ms exceeded'), { code: 'ECONNABORTED' }, { code: 'ETIMEDOUT' }]) {
    assert.match(candidateAuthError(error), /请求超时/)
    assert.doesNotMatch(candidateAuthError(error), /无权限|密码错误/)
  }
  assert.match(candidateAuthError({ code: 'ERR_NETWORK' }), /无法连接登录服务/)
  for (const status of [502, 503, 504]) assert.match(candidateAuthError({ response: { status } }), /暂不可用/)
  assert.equal(candidateAuthError(new Error('账号或密码错误')), '账号或密码错误')
  assert.equal(candidateAuthError(new Error('账号已停用')), '账号已停用')
  assert.equal(candidateAuthError(null, '验证码发送失败'), '验证码发送失败')
})

function loginPage(overrides = {}) {
  const source = fs.readFileSync(new URL('../src/views/agent/pages/login.vue', import.meta.url), 'utf8')
    .match(/<script setup>([\s\S]*?)<\/script>/)[1].replace(/^import .*$/gm, '')
  const dependencies = {
    reactive, ref, candidateAuthError,
    useRoute: () => ({ query: { mode: 'account' } }),
    useRouter: () => ({ push: async () => {} }),
    useUserStore: () => ({ login: async () => {}, $reset() {} }),
    onMounted() {}, onBeforeUnmount() {},
    clearCandidateSession() {}, resetCandidateSecurityNotice() {}, removeToken() {},
    isValidAccountOrPhone: () => true,
    candidateRedirect: () => '/index',
    ...overrides
  }
  return new Function(...Object.keys(dependencies), `${source}\nreturn { handleSubmit, form, loading, error }`)(...Object.values(dependencies))
}

test('请求超时保留输入并解除按钮忙碌状态，等待期间重复点击只发一次登录请求', async () => {
  let rejectLogin
  let calls = 0
  const page = loginPage({ useUserStore: () => ({ $reset() {}, login: () => { calls++; return new Promise((resolve, reject) => { rejectLogin = reject }) } }) })
  page.form.account = 'isolated-account'
  page.form.password = 'test-only-password'
  page.form.agree = true
  const first = page.handleSubmit()
  assert.equal(page.loading.value, true)
  await page.handleSubmit()
  assert.equal(calls, 1)
  rejectLogin(new Error('timeout of 10000ms exceeded'))
  await first
  assert.equal(page.loading.value, false)
  assert.match(page.error.value, /请求超时/)
  assert.equal(page.form.account, 'isolated-account')
  assert.equal(page.form.password, 'test-only-password')
})
