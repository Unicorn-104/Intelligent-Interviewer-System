import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { computed, ref } from 'vue'

function deferred() {
  let resolve
  let reject
  const promise = new Promise((done, fail) => { resolve = done; reject = fail })
  return { promise, resolve, reject }
}

function homePage(overrides = {}) {
  const source = fs.readFileSync(new URL('../src/views/agent/pages/index.vue', import.meta.url), 'utf8')
    .match(/<script setup>([\s\S]*?)<\/script>/)[1].replace(/^import .*$/gm, '')
  const requests = []
  const navigations = []
  const unmounted = []
  const dependencies = {
    computed, ref, onMounted() {}, onUnmounted: callback => unmounted.push(callback),
    useUserStore: () => ({ nickName: '测试用户' }),
    localStorage: { getItem: () => null },
    window: { __agentNavigate: path => navigations.push(path), clearInterval() {} },
    getResumes: async () => ({ data: [{ id: 1, name: '前端简历' }, { id: 2, name: '后端简历', isDefault: true }] }),
    listJobs: async params => { requests.push(params); return { data: { items: [{ id: params.resumeId, matchScore: 80 }] } } },
    ...overrides
  }
  const page = new Function(...Object.keys(dependencies), `${source}\nreturn { loadRecommendationResumes, changeRecommendationResume, loadJobs, resumes, selectedResumeId, selectedResume, recommendationHint, resumesLoading, resumesError, jobs, loading, errorMessage, sort, keyword, openJob, applyJob }`)(...Object.values(dependencies))
  return { page, requests, navigations, unmounted }
}

test('首页先读取本人简历，自动选择默认简历并携带 ID 请求真实岗位接口', async () => {
  const { page, requests } = homePage()
  await page.loadJobs()
  assert.equal(requests.length, 0)
  await page.loadRecommendationResumes()
  assert.equal(page.selectedResumeId.value, '2')
  assert.equal(requests[0].resumeId, 2)
  assert.equal(requests[0].sort, 'match')
  assert.match(page.recommendationHint.value, /后端简历/)
})

test('切换简历重新按匹配度请求，搜索、排序和刷新保留所选简历，不修改默认简历', async () => {
  const { page, requests } = homePage()
  await page.loadRecommendationResumes()
  page.selectedResumeId.value = '1'
  page.sort.value = 'salary'
  await page.changeRecommendationResume()
  assert.equal(requests.at(-1).resumeId, 1)
  assert.equal(requests.at(-1).sort, 'match')
  page.sort.value = 'latest'
  page.keyword.value = 'Vue'
  await page.loadJobs()
  await page.loadRecommendationResumes()
  assert.equal(page.selectedResumeId.value, '1')
  assert.equal(requests.at(-1).keyword, 'Vue')
  assert.equal(requests.at(-1).sort, 'latest')
  assert.equal(page.resumes.value[1].isDefault, true)
})

test('快速切换时旧简历的结果或错误不能覆盖新推荐和加载状态', async () => {
  const pending = deferred()
  let calls = 0
  const { page } = homePage({ listJobs: async params => {
    calls++
    if (calls === 2) return pending.promise
    return { data: { items: [{ id: params.resumeId }] } }
  } })
  await page.loadRecommendationResumes()
  page.selectedResumeId.value = '1'
  const first = page.changeRecommendationResume()
  page.selectedResumeId.value = '2'
  await page.changeRecommendationResume()
  pending.reject(new Error('旧简历请求失败'))
  await first
  assert.deepEqual(page.jobs.value.map(job => job.id), [2])
  assert.equal(page.errorMessage.value, '')
  assert.equal(page.loading.value, false)
})

test('无简历时显示普通岗位且不指定简历；简历接口失败时不伪装成默认推荐', async () => {
  const empty = homePage({ getResumes: async () => ({ data: [] }) })
  await empty.page.loadRecommendationResumes()
  assert.equal(empty.page.selectedResumeId.value, '')
  assert.equal(empty.requests[0].resumeId, undefined)
  const failed = homePage({ getResumes: async () => { throw new Error('读取失败') } })
  await failed.page.loadRecommendationResumes()
  assert.equal(failed.page.resumesError.value, '读取失败')
  assert.equal(failed.requests.length, 0)
})

test('刷新后已删除的简历不继续推荐，自动选择仍有效的简历', async () => {
  let deleted = false
  const { page, requests } = homePage({ getResumes: async () => ({ data: deleted
    ? [{ id: 1, name: '保留的简历' }]
    : [{ id: 2, name: '将删除的简历', isDefault: true }] }) })
  await page.loadRecommendationResumes()
  deleted = true
  await page.loadRecommendationResumes()
  assert.equal(page.selectedResumeId.value, '1')
  assert.equal(requests.at(-1).resumeId, 1)
})

test('卸载后忽略简历与岗位的迟到响应，推荐简历只在本人列表内选择', async () => {
  const pending = deferred()
  const { page, unmounted, requests } = homePage({ getResumes: () => pending.promise })
  const loading = page.loadRecommendationResumes()
  unmounted.forEach(callback => callback())
  pending.resolve({ data: [{ id: 2 }] })
  await loading
  assert.equal(requests.length, 0)
})

test('进入岗位详情或投递页携带推荐简历，已投递岗位仍打开投递记录', async () => {
  const { page, navigations } = homePage()
  await page.loadRecommendationResumes()
  page.openJob(10)
  page.applyJob({ id: 10 })
  page.applyJob({ id: 10, appliedFlag: true, applicationId: 30 })
  assert.deepEqual(navigations, ['/job-detail?id=10&resumeId=2', '/resume-select?job=10&resumeId=2', '/application-detail?id=30'])
})

test('投递页仅预选本人有效简历，未知或他人 ID 回退到可投递简历', async () => {
  const source = fs.readFileSync(new URL('../src/views/agent/pages/resume-select.vue', import.meta.url), 'utf8')
    .match(/<script setup>([\s\S]*?)<\/script>/)[1].replace(/^import .*$/gm, '')
  for (const requested of ['1', '999']) {
    const dependencies = {
      computed, ref, onMounted() {}, useRoute: () => ({ query: { job: '10', resumeId: requested } }),
      getJob: async () => ({ data: { id: 10, title: '测试岗位' } }),
      getResumeOptions: async () => ({ data: [{ id: 1 }, { id: 2, isDefault: true }] }),
      document: {}
    }
    const page = new Function(...Object.keys(dependencies), `${source}\nreturn { loadData, selectedResumeId }`)(...Object.values(dependencies))
    await page.loadData()
    assert.equal(page.selectedResumeId.value, requested === '1' ? 1 : 2)
  }
})
