import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { createRouter, createMemoryHistory } from 'vue-router'
import { agentPageDefinitions } from '../src/router/agentPages.js'
import { appHref, candidateRedirect, isCandidatePath, toAppRoute } from '../src/utils/agentNavigation.js'

test('页面链接按部署基路径生成，不重复添加 user 或 agent 前缀', () => {
  for (const base of ['/', '/user/', '/preview/user/']) {
    assert.equal(appHref('/login', base), `${base}login`)
    assert.equal(appHref('/agent/jobs?id=26#detail', base), `${base}jobs?id=26#detail`)
    assert.equal(appHref(`${base}messages?view=system#notice-1`, base), `${base}messages?view=system#notice-1`)
    assert.equal(toAppRoute(`${base}resume-editor?id=10`, base), '/resume-editor?id=10')
  }
  assert.equal(appHref('/', '/user/'), '/user/')
  assert.equal(appHref('/user', '/user/'), '/user/')
})

test('登录回跳保留查询参数和锚点，兼容旧地址但拒绝外部与非页面地址', () => {
  assert.equal(candidateRedirect('/agent/job-detail?id=26#apply', '/user/'), '/job-detail?id=26#apply')
  assert.equal(candidateRedirect('/user/messages?conversation=12', '/user/'), '/messages?conversation=12')
  assert.equal(candidateRedirect('/conference-join?token=synthetic', '/user/'), '/conference-join?token=synthetic')
  for (const target of ['//evil.example/jobs', 'https://evil.example/jobs', 'javascript:alert(1)', '/login', '/register', '/prod-api/profile/test', '/agent/v1/jobs', undefined, {}, '/\\evil.example']) {
    assert.equal(candidateRedirect(target, '/user/'), '/index')
  }
  assert.equal(toAppRoute('https://app.local/user/jobs', '/user/', 'https://app.local'), '/jobs')
  assert.equal(toAppRoute('https://other.local/jobs', '/user/', 'https://app.local'), null)
  assert.equal(isCandidatePath('/user/profile-resumes', '/user/'), true)
  assert.equal(isCandidatePath('/agent/v1/jobs', '/user/'), false)
})

function actualRouter(base) {
  const source = fs.readFileSync(new URL('../src/router/index.js', import.meta.url), 'utf8')
    .replace(/^import .*$/gm, '')
    .replace(/import\.meta\.glob\([^)]*\)/, 'new Proxy({}, { get: () => ({}) })')
    .replace(/\(\) => import\([^)]*\)/g, '{}')
    .replaceAll('import.meta.env.BASE_URL', JSON.stringify(base))
    .replaceAll('export const ', 'const ')
    .replace('export default router', 'return router')
  return new Function('createRouter', 'createWebHistory', 'Layout', 'agentPageDefinitions', 'toAppRoute', source)(
    createRouter, createMemoryHistory, {}, agentPageDefinitions, toAppRoute
  )
}

test('实际路由表以 BASE_URL 为根，页面路由不再带 agent 前缀', async () => {
  for (const base of ['/', '/user/']) {
    const router = actualRouter(base)
    for (const [page, name] of agentPageDefinitions) {
      const resolved = router.resolve(`/${page}?test=1#anchor`)
      assert.equal(resolved.name, name)
      assert.equal(resolved.meta.candidate, true)
      assert.equal(resolved.href, `${base}${page}?test=1#anchor`)
    }
    await router.push('/agent/job-detail?id=26#apply')
    assert.equal(router.currentRoute.value.fullPath, '/job-detail?id=26#apply')
    await router.push('/agent/interview-check?sessionId=1')
    assert.equal(router.currentRoute.value.fullPath, '/conference-prep?sessionId=1')
    await router.push('/login.html?redirect=%2Fjobs')
    assert.equal(router.currentRoute.value.path, '/login')
    assert.equal(router.currentRoute.value.query.redirect, '/jobs')
    await router.push('/')
    assert.equal(router.currentRoute.value.path, '/index')
    await router.push('/index')
    assert.equal(router.currentRoute.value.meta.candidate, true)
  }
})

test('求职页面和公共入口不再硬编码 agent 页面地址或裸站点根链接', () => {
  const files = []
  for (const folder of ['../src/views/agent/pages/', '../src/components/agent/']) {
    const directory = new URL(folder, import.meta.url)
    for (const name of fs.readdirSync(directory)) {
      if (name.endsWith('.vue')) files.push(new URL(name, directory))
    }
  }
  for (const file of ['../src/views/conference-join.vue', '../src/views/survey-fill.vue']) {
    files.push(new URL(file, import.meta.url))
  }
  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8')
    const name = path.basename(file.pathname)
    assert.doesNotMatch(source, /["'`]\/agent\//, `${name} 使用了旧页面前缀`)
    assert.doesNotMatch(source, /(?<!:)href="\/(?!\/)/, `${name} 的原生链接绕过了部署基路径`)
  }
})
