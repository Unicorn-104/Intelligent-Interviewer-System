import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { computed, reactive, ref } from 'vue'
import { loadSavedJobItems, normalizeSavedJobIds, sortSavedJobItems } from '../src/utils/agentSavedJobs.js'

function jobsPage(overrides = {}) {
  const script = fs.readFileSync(new URL('../src/views/agent/pages/jobs.vue', import.meta.url), 'utf8')
    .match(/<script setup>([\s\S]*?)<\/script>/)[1].replace(/^import .*$/gm, '')
  const storage = new Map([['zhipin-ai-saved-jobs', '[1,2,999]']])
  const dependencies = {
    ref, computed, reactive, loadSavedJobItems, normalizeSavedJobIds, sortSavedJobItems,
    onMounted() {}, onBeforeUnmount() {},
    localStorage: { getItem: key => storage.get(key) || null, setItem: (key, value) => storage.set(key, value) },
    window: {}, setTimeout() {}, clearTimeout() {},
    listJobs: async query => ({ data: { items: query.jobIds ? [{ id: 1 }, { id: 2 }] : [{ id: 1 }], total: query.jobIds ? 2 : 1, hasNext: false } }),
    ...overrides
  }
  const page = new Function(...Object.keys(dependencies), `${script}\nreturn { loadJobs, jobs, savedJobs, savedOnly, savedJobCount, visibleJobs, toggleSaved, syncSavedJobs, errorMessage, keyword, filters, hotTags, selectHotTag, clearFilter, activeFilterLabels }`)(...Object.values(dependencies))
  return { page, storage }
}

test('收藏 ID 去重并排除空值、对象、非正数及超出数据库范围的值', () => {
  assert.deepEqual(normalizeSavedJobIds([1, '1', ' 2 ', '002', null, {}, -1, 0, 'NaN', '', '9223372036854775808']), ['1', '2'])
  assert.deepEqual(normalizeSavedJobIds('not-array'), [])
})

test('杭州快捷入口使用工作城市约束，普通列表和收藏列表不走公司名称关键词匹配', async () => {
  const calls = []
  const { page } = jobsPage({ listJobs: async query => {
    calls.push(query)
    return { data: { items: [], total: 0, hasNext: false } }
  } })
  page.keyword.value = 'React'
  page.filters.city = '广州'
  page.filters.education = '本科'
  await page.selectHotTag(page.hotTags.find(tag => tag.label === '杭州'))
  assert.equal(page.keyword.value, '')
  assert.equal(page.filters.city, '杭州')
  assert.equal(calls.length, 2)
  assert.ok(calls.every(query => query.city === '杭州' && query.keyword === undefined && query.education === 3))
  assert.ok(calls.some(query => query.jobIds))
  assert.ok(page.activeFilterLabels.value.some(item => item.key === 'city' && item.label === '杭州'))
  page.clearFilter('city')
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(page.filters.city, '')
  assert.ok(calls.slice(2).every(query => query.city === undefined))
})

test('职位和技能快捷词仍使用关键词搜索，并保留已选择的工作城市', async () => {
  const calls = []
  const { page } = jobsPage({ listJobs: async query => {
    calls.push(query)
    return { data: { items: [], total: 0, hasNext: false } }
  } })
  page.filters.city = '杭州'
  for (const tag of page.hotTags.filter(tag => tag.keyword)) {
    await page.selectHotTag(tag)
    assert.equal(page.keyword.value, tag.keyword)
    assert.ok(calls.slice(-2).every(query => query.keyword === tag.keyword && query.city === '杭州'))
  }
})

test('后端实际收藏列表排除失效 ID，不删除原始收藏记录', async () => {
  const ids = ['1', '2', '999']
  const items = await loadSavedJobItems(async query => {
    assert.equal(query.jobIds, '1,2,999')
    return { data: { items: [{ id: 1 }, { id: 2 }, { id: 88 }], total: 2, hasNext: false } }
  }, ids)
  assert.equal(items.length, 2)
  assert.deepEqual(ids, ['1', '2', '999'])
  assert.ok(!items.some(item => item.id === 88))
})

test('收藏查询携带相同筛选条件并完整读取后续页，不受普通列表前 50 条限制', async () => {
  const calls = []
  const items = await loadSavedJobItems(async query => {
    calls.push(query)
    return { data: { items: query.page === 1 ? Array.from({ length: 100 }, (_, index) => ({ id: index + 1 })) : [{ id: 101 }], total: 101, hasNext: query.page === 1 } }
  }, Array.from({ length: 101 }, (_, index) => String(index + 1)), { city: '杭州', salaryMin: 10000, sort: 'latest' })
  assert.equal(items.length, 101)
  assert.equal(calls.length, 2)
  assert.equal(calls[1].page, 2)
  assert.equal(calls[1].city, '杭州')
  assert.equal(calls[1].salaryMin, 10000)
})

test('超过 200 个收藏时分批查询，合并后统一排序', async () => {
  const calls = []
  const items = await loadSavedJobItems(async query => {
    const ids = query.jobIds.split(',')
    calls.push(ids)
    return { data: { items: ids.map(id => ({ id, matchScore: Number(id) })), hasNext: false } }
  }, Array.from({ length: 205 }, (_, index) => String(index + 1)), { sort: 'match' })
  assert.equal(calls.length, 2)
  assert.equal(calls[0].length, 200)
  assert.equal(items.length, 205)
  assert.equal(items[0].id, '205')
})

test('空收藏不请求全部岗位，接口失败不伪装为零收藏', async () => {
  assert.deepEqual(await loadSavedJobItems(() => assert.fail('空收藏不应请求'), []), [])
  await assert.rejects(loadSavedJobItems(async () => { throw new Error('unavailable') }, ['1']), /unavailable/)
  await assert.rejects(loadSavedJobItems(async () => ({ data: { total: 101, items: [], hasNext: true } }), ['1']), /分页数据异常/)
})

test('收藏计数与收藏列表来自同一结果，含普通列表尚未加载的岗位', async () => {
  const { page } = jobsPage()
  assert.equal(page.savedJobCount.value, null)
  await page.loadJobs()
  assert.equal(page.jobs.value.length, 1)
  assert.equal(page.savedJobCount.value, 2)
  page.savedOnly.value = true
  assert.equal(page.visibleJobs.value.length, 2)
  page.toggleSaved(1)
  assert.equal(page.savedJobCount.value, 1)
  assert.deepEqual(page.visibleJobs.value.map(job => job.id), [2])
  page.toggleSaved(1)
  assert.equal(page.savedJobCount.value, 2)
  assert.equal(page.visibleJobs.value.length, 2)
})

test('筛选后只统计满足条件的收藏，清除筛选可恢复，不能删除其他条件下的收藏', async () => {
  const { page, storage } = jobsPage({ listJobs: async query => ({ data: { items: query.city ? [{ id: 1 }] : [{ id: 1 }, { id: 2 }], total: query.city ? 1 : 2, hasNext: false } }) })
  page.filters.city = '杭州'
  await page.loadJobs()
  assert.equal(page.savedJobCount.value, 1)
  assert.equal(storage.get('zhipin-ai-saved-jobs'), '[1,2,999]')
  page.filters.city = ''
  await page.loadJobs()
  assert.equal(page.savedJobCount.value, 2)
})

test('收藏接口出错显示未知数量及错误，不显示与实际不符的零', async () => {
  const { page } = jobsPage({ listJobs: async query => { if (query.jobIds) throw new Error('收藏暂时不可用'); return { data: { items: [] } } } })
  await page.loadJobs()
  assert.equal(page.savedJobCount.value, null)
  assert.match(page.errorMessage.value, /收藏暂时不可用/)
})

test('跨标签页或返回前台后同步本地收藏变更', async () => {
  const { page, storage } = jobsPage()
  await page.loadJobs()
  storage.set('zhipin-ai-saved-jobs', '[2]')
  page.syncSavedJobs()
  await new Promise(resolve => setImmediate(resolve))
  assert.deepEqual([...page.savedJobs.value], ['2'])
  assert.equal(page.savedJobCount.value, 1)
})

test('较早的岗位请求不能覆盖新筛选结果和收藏数量', async () => {
  let resolveOld
  const oldResponse = new Promise(resolve => { resolveOld = resolve })
  const { page } = jobsPage({ listJobs: async query => query.city === '杭州' ? oldResponse : { data: { items: [{ id: 2 }], total: 1, hasNext: false } } })
  page.filters.city = '杭州'
  const oldLoad = page.loadJobs()
  page.filters.city = '广州'
  await page.loadJobs()
  resolveOld({ data: { items: [{ id: 1 }, { id: 2 }], total: 2, hasNext: false } })
  await oldLoad
  assert.deepEqual(page.jobs.value.map(job => job.id), [2])
  assert.equal(page.savedJobCount.value, 1)
})
