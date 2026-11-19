import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { createRequire } from 'node:module'
import { copyText } from '../src/utils/agentClipboard.js'
import { mergeMessagePages, messagePageData } from '../src/utils/agentMessagePage.js'

const require = createRequire(import.meta.url)
const { parse } = require('@vue/compiler-sfc')
const postcss = require('postcss')

test('剪贴板成功后才返回成功，失败不假报，降级后清理 DOM 和恢复焦点', async () => {
  const copied = []
  await copyText('https://example.invalid/user/job-detail?id=26', { writeText: async value => copied.push(value) }, null)
  assert.equal(copied.length, 1)
  await assert.rejects(copyText('url', null, null), /不支持/)
  let removed = 0
  let focused = 0
  const document = {
    activeElement: { focus() { focused++ } }, body: { appendChild() {} },
    createElement: () => ({ style: {}, setAttribute() {}, select() {}, remove() { removed++ } }),
    execCommand: () => false
  }
  await assert.rejects(copyText('url', { writeText: async () => { throw new Error('denied') } }, document), /复制失败/)
  assert.equal(removed, 1)
  assert.equal(focused, 1)
  document.execCommand = () => true
  await copyText('url', null, document)
  assert.equal(removed, 2)
})

test('消息游标合并按大整数排序去重，后端未更新不静默回退全量接口', () => {
  const rows = mergeMessagePages([{ messageId: '9007199254740993', content: 'old' }], [
    { messageId: '9007199254740994', content: 'new' }, { messageId: '9007199254740993', content: 'updated' }
  ])
  assert.deepEqual(rows.map(row => row.content), ['updated', 'new'])
  assert.throws(() => mergeMessagePages([], [{ messageId: 'invalid' }]), /标识无效/)
  assert.throws(() => messagePageData({ data: [] }), /同步更新后端/)
  assert.throws(() => messagePageData({ data: { items: [], hasMore: true } }), /分页返回异常/)
})

test('求职者页面全局样式都有页面命名空间，不再污染 body 或其他路由', () => {
  const folder = new URL('../src/views/agent/pages/', import.meta.url)
  for (const name of fs.readdirSync(folder).filter(name => name.endsWith('.vue'))) {
    const source = fs.readFileSync(new URL(name, folder), 'utf8')
    const { descriptor, errors } = parse(source)
    assert.deepEqual(errors, [], name)
    for (const style of descriptor.styles) {
      assert.doesNotMatch(style.content, /:global\(|:root/, name)
      const ast = postcss.parse(style.content)
      ast.walkRules(rule => {
        let parent = rule.parent
        while (parent) {
          if (parent.type === 'atrule' && /keyframes$/i.test(parent.name)) return
          parent = parent.parent
        }
        for (const selector of rule.selectors) {
          assert.doesNotMatch(selector, /(^|[ ,>+~])(body|html|#app)(?=[ .#[:>+~]|$)/, name + ': ' + selector)
          if (!style.scoped) assert.ok(selector.includes('candidate-page--' + name.replace('.vue', '')), name + ': ' + selector)
        }
      })
    }
  }
})


function companyPage(overrides = {}, id = '3') {
  const source = fs.readFileSync(new URL('../src/views/agent/pages/company-profile.vue', import.meta.url), 'utf8')
    .match(/<script setup>([\s\S]*?)<\/script>/)[1].replace(/^import .*$/gm, '')
  const dependencies = {
    ref: vue.ref, computed: vue.computed, watch() {}, useRoute: () => ({ query: { id } }),
    getCompany: async () => ({ data: { id: 3, name: '合成企业', website: 'https://example.invalid', followed: false } }),
    setCompanyFollowed: async (companyId, followed) => ({ data: { followed } }), ...overrides
  }
  return new Function(...Object.keys(dependencies), source + ';return {load,company,error,loading,website,toggleFollow,feedback}')( ...Object.values(dependencies))
}

const vue = require('vue')

test('企业资料不使用默认企业 ID，非法入口和错误有明确提示，网站拒绝危险协议', async () => {
  const invalid = companyPage({ getCompany: () => assert.fail('非法 ID 不请求') }, '')
  await invalid.load()
  assert.match(invalid.error.value, /编号无效/)
  assert.equal(invalid.loading.value, false)
  const page = companyPage()
  await page.load()
  assert.equal(page.company.value.name, '合成企业')
  await page.toggleFollow()
  assert.equal(page.company.value.followed, true)
  for (const website of ['javascript:alert(1)', 'data:text/html,example', 'https://name:secret@example.invalid']) {
    page.company.value.website = website
    assert.equal(page.website.value, '')
  }
  const failed = companyPage({ getCompany: async () => { throw new Error('企业已下架') } })
  await failed.load()
  assert.equal(failed.company.value, null)
  assert.match(failed.error.value, /已下架/)
})
