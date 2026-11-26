import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { computed, effectScope, nextTick, ref, watch } from 'vue'
import { clampFloatingPosition } from '../src/composables/useFloatingAssistant.js'
import { useAiAssistant } from '../src/composables/useAiAssistant.js'
import { aiActions, aiPlainText } from '../src/utils/agentAi.js'

function floating(saved = null, disabled = false, screen = { width: 1000, height: 800 }) {
  const mounted = []
  const unmounted = []
  const window = new EventTarget()
  window.innerWidth = screen.width
  window.innerHeight = screen.height
  const data = new Map(saved ? [['candidate-ai-floating-position:v1', saved]] : [])
  window.sessionStorage = { getItem: key => data.get(key), setItem: (key, value) => data.set(key, value) }
  const makeElement = bounds => ({ offsetWidth: bounds.width, getBoundingClientRect: () => bounds })
  const launcher = ref(makeElement({ left: 840, top: 728, width: 132, height: 48 }))
  const panel = ref(makeElement({ left: 432, top: 12, width: 540, height: 680 }))
  const source = fs.readFileSync(new URL('../src/composables/useFloatingAssistant.js', import.meta.url), 'utf8').replace(/^import .*$/gm, '').replace(/^export /gm, '')
  const dependencies = { computed, nextTick, ref, watch, window, onMounted: callback => mounted.push(callback), onBeforeUnmount: callback => unmounted.push(callback), globalThis: {} }
  const setup = new Function(...Object.keys(dependencies), source + ';return useFloatingAssistant')(...Object.values(dependencies))
  const controller = setup(launcher, panel, () => !disabled)
  mounted.forEach(callback => callback())
  const handle = { captured: false, setPointerCapture() { this.captured = true }, hasPointerCapture() { return this.captured }, releasePointerCapture() { this.captured = false } }
  const event = (overrides = {}) => ({ pointerId: 1, isPrimary: true, button: 0, clientX: 850, clientY: 740, currentTarget: handle, target: { closest: () => null }, ...overrides })
  return { controller, window, data, event, handle, unmount: () => unmounted.forEach(callback => callback()) }
}

test('悬浮位置限制在可见区域，窗口缩小后不会拖出屏幕', () => {
  assert.deepEqual(clampFloatingPosition({ x: -500, y: 3000 }, { width: 132, height: 48 }, { width: 390, height: 700 }), { x: 8, y: 644 })
  assert.deepEqual(clampFloatingPosition({ x: 999, y: 999 }, { width: 540, height: 780 }, { width: 320, height: 200 }), { x: 8, y: 8 })
})

test('拖动按钮使用指针捕获，抑制拖动后的误点击，位置只保存布局不保存对话', () => {
  const { controller, event, handle, data, unmount } = floating()
  controller.startDrag(event(), 'launcher')
  controller.moveDrag(event({ clientX: 150, clientY: 160 }))
  assert.equal(controller.dragging.value, true)
  assert.equal(handle.captured, true)
  assert.equal(controller.launcherStyle.value.left, '140px')
  controller.endDrag(event())
  assert.equal(handle.captured, false)
  assert.equal(controller.acceptClick({ detail: 1 }), false)
  assert.equal(controller.acceptClick({ detail: 0 }), true)
  const saved = JSON.parse(data.get('candidate-ai-floating-position:v1'))
  assert.deepEqual(Object.keys(saved).sort(), ['launcher', 'panel'])
  assert.ok(saved.launcher.x >= 0 && saved.launcher.x <= 1)
  unmount()
})

test('轻触不算拖动，右键及非主指针不移动，窗口按钮不启动标题栏拖动', () => {
  const { controller, event, unmount } = floating()
  const initial = controller.launcherStyle.value.left
  controller.startDrag(event({ button: 2 }), 'launcher')
  controller.startDrag(event({ isPrimary: false }), 'launcher')
  controller.moveDrag(event({ clientX: 10 }))
  assert.equal(controller.launcherStyle.value.left, initial)
  controller.startDrag(event(), 'launcher')
  controller.moveDrag(event({ clientX: 852, clientY: 742 }))
  controller.endDrag(event())
  assert.equal(controller.acceptClick({ detail: 1 }), true)
  controller.startDrag(event({ target: { closest: () => ({}) } }), 'panel')
  controller.moveDrag(event({ clientX: 0 }))
  assert.equal(controller.dragging.value, false)
  unmount()
})

test('标题栏拖动、键盘移动及屏幕缩放保持可达，卸载后解除捕获', () => {
  const { controller, event, handle, window, data, unmount } = floating()
  controller.startDrag(event(), 'panel')
  controller.moveDrag(event({ clientX: 50, clientY: 30 }))
  controller.endDrag(event())
  assert.equal(controller.panelStyle.value.left, '8px')
  assert.equal(controller.panelStyle.value.top, '8px')
  assert.equal(controller.acceptClick({ detail: 1 }), true)
  let prevented = false
  controller.moveWithKeyboard({ key: 'ArrowRight', shiftKey: false, target: handle, currentTarget: handle, preventDefault() { prevented = true } }, 'panel')
  assert.equal(prevented, true)
  assert.equal(controller.panelStyle.value.left, '28px')
  window.innerWidth = 390
  window.innerHeight = 300
  window.dispatchEvent(new Event('resize'))
  assert.equal(controller.launcherStyle.value.left, '250px')
  assert.equal(controller.launcherStyle.value.top, '244px')
  const restored = floating(data.get('candidate-ai-floating-position:v1'), false, { width: 390, height: 300 })
  assert.deepEqual(restored.controller.launcherStyle.value, controller.launcherStyle.value)
  restored.unmount()
  controller.startDrag(event(), 'launcher')
  unmount()
  assert.equal(handle.captured, false)
})

test('布局按比例恢复，损坏缓存不阻断助手，内嵌模式不启用拖动', () => {
  const restored = floating(JSON.stringify({ launcher: { x: 0.5, y: 0.5 }, panel: { x: 0.5, y: 0.5 } }))
  assert.equal(restored.controller.launcherStyle.value.left, '434px')
  assert.equal(restored.controller.launcherStyle.value.top, '376px')
  restored.unmount()
  const invalid = floating('{broken')
  assert.equal(invalid.controller.launcherStyle.value.left, '840px')
  invalid.unmount()
  const embedded = floating(null, true)
  assert.deepEqual(embedded.controller.launcherStyle.value, {})
  embedded.controller.startDrag(embedded.event(), 'launcher')
  assert.equal(embedded.handle.captured, false)
  embedded.unmount()
})

test('助手只在应用根节点挂载一次，独立页面共享入口，不按路由销毁对话', () => {
  const app = fs.readFileSync(new URL('../src/App.vue', import.meta.url), 'utf8')
  assert.equal((app.match(/<AiAssistant\b/g) || []).length, 1)
  assert.match(app, /:key="assistantIdentity"/)
  assert.doesNotMatch(app, /:key=".*(?:route|fullPath)/)
  for (const file of ['messages', 'job-assistant', 'mock-interview']) {
    const source = fs.readFileSync(new URL(`../src/views/agent/pages/${file}.vue`, import.meta.url), 'utf8')
    assert.doesNotMatch(source, /<AiAssistant\b/, file)
  }
  const component = fs.readFileSync(new URL('../src/components/agent/AiAssistant.vue', import.meta.url), 'utf8')
  assert.match(component, /if \(!hasCandidateAccessToken\(\)\)/)
  assert.match(component, /await requestCandidateLogin\(route.fullPath\)/)
  assert.match(component, /router.push\(target\)/)
})

function assistantPage(signedIn = true, loginTarget = null, overrides = {}) {
  const scope = effectScope()
  const unmounted = []
  const navigations = []
  let prompts = 0
  let requests = 0
  const source = fs.readFileSync(new URL('../src/components/agent/AiAssistant.vue', import.meta.url), 'utf8')
    .match(/<script setup>([\s\S]*?)<\/script>/)[1].replace(/^import .*$/gm, '')
  const dependencies = {
    computed, nextTick, ref, watch, useAiAssistant, aiActions, aiPlainText,
    defineProps: () => ({ standalone: false, initialAction: 'chat' }), defineEmits: () => () => {},
    onMounted() {}, onBeforeUnmount: callback => unmounted.push(callback),
    useRoute: () => ({ path: '/mock-interview', fullPath: '/mock-interview' }),
    useRouter: () => ({ push: target => navigations.push(target) }),
    hasCandidateAccessToken: () => signedIn,
    requestCandidateLogin: async () => { prompts++; return loginTarget },
    useFloatingAssistant: () => ({ acceptClick: () => true }),
    window: new EventTarget(), getResumes() {}, getApplication() {},
    aiApi: { listAiSessions: async () => { requests++; return { data: { items: [], hasNext: false } } } },
    ...overrides
  }
  const page = scope.run(() => new Function(...Object.keys(dependencies), source + ';return {openPanel,closePanel,openForRoute,open,draft,resume,action,openPicker,loadPicker,cancelPicker,view,pickerItems,pickerLoading,pickerError,pickerHasMore}')(...Object.values(dependencies)))
  return { page, navigations, prompts: () => prompts, requests: () => requests, stop() { unmounted.forEach(callback => callback()); scope.stop() } }
}

test('全站挂载不会请求 AI，展开才初始化，收起重开不丢问题或重复读取历史', async () => {
  const fixture = assistantPage()
  assert.equal(fixture.requests(), 0)
  await fixture.page.openPanel()
  assert.equal(fixture.page.open.value, true)
  assert.equal(fixture.requests(), 1)
  fixture.page.draft.value = '未发送问题'
  fixture.page.closePanel()
  assert.equal(fixture.page.open.value, false)
  await fixture.page.openPanel()
  assert.equal(fixture.page.draft.value, '未发送问题')
  assert.equal(fixture.requests(), 1)
  fixture.stop()
})

test('游客主动打开才提示登录，独立公开页也用路由跳转，不查询他人会话', async () => {
  const fixture = assistantPage(false, '/login?redirect=%2Fmock-interview')
  fixture.page.openForRoute()
  assert.equal(fixture.prompts(), 0)
  await fixture.page.openPanel()
  assert.equal(fixture.prompts(), 1)
  assert.equal(fixture.page.open.value, false)
  assert.equal(fixture.requests(), 0)
  assert.deepEqual(fixture.navigations, ['/login?redirect=%2Fmock-interview'])
  fixture.stop()
  const closed = assistantPage(false)
  await closed.page.openPanel()
  assert.deepEqual(closed.navigations, [])
  assert.equal(closed.requests(), 0)
  closed.stop()
})

function pendingRequest() {
  let resolve
  let reject
  const promise = new Promise((done, fail) => { resolve = done; reject = fail })
  return { promise, resolve, reject }
}

test('跨页重开后岗位选择立即发起新请求，迟到简历成功及 finally 不覆盖岗位列表或解除其加载态', async () => {
  const oldResumes = pendingRequest()
  const applications = pendingRequest()
  let resumeCalls = 0
  const fixture = assistantPage(true, null, {
    getResumes: () => ++resumeCalls === 1 ? oldResumes.promise : Promise.resolve({ data: [{ id: 7, name: '投递简历' }] }),
    listApplications: () => applications.promise
  })
  try {
    await fixture.page.openPanel()
    const old = fixture.page.openPicker('resumes', aiActions[1])
    assert.equal(fixture.page.pickerLoading.value, true)
    await fixture.page.openPanel()
    const current = fixture.page.openPicker('applications', aiActions[2])
    assert.equal(resumeCalls, 2)
    oldResumes.resolve({ data: [{ id: 99, name: '过期简历' }] })
    await old
    assert.equal(fixture.page.view.value, 'applications')
    assert.equal(fixture.page.pickerLoading.value, true)
    assert.deepEqual(fixture.page.pickerItems.value, [])
    applications.resolve({ data: { items: [{ id: 20, resumeId: 7, jobTitle: '岗位' }], hasNext: true } })
    await current
    assert.deepEqual(fixture.page.pickerItems.value.map(item => [item.id, item.resumeAvailable]), [[20, true]])
    assert.equal(fixture.page.pickerHasMore.value, true)
    assert.equal(fixture.page.pickerError.value, '')
  } finally { fixture.stop() }
})

test('切换选择类型立即使旧请求失效，迟到错误不污染新列表；关闭后不回填', async () => {
  const oldResumes = pendingRequest()
  let calls = 0
  const fixture = assistantPage(true, null, {
    getResumes: () => ++calls === 1 ? oldResumes.promise : Promise.resolve({ data: [{ id: 7 }] }),
    listApplications: async () => ({ data: { items: [{ id: 20, resumeId: 7 }], hasNext: false } })
  })
  try {
    const old = fixture.page.openPicker('resumes')
    await fixture.page.openPicker('applications')
    oldResumes.reject(new Error('过期简历请求失败'))
    await old
    assert.equal(fixture.page.pickerError.value, '')
    assert.equal(fixture.page.pickerLoading.value, false)
    assert.equal(fixture.page.pickerItems.value[0].id, 20)
    const late = pendingRequest()
    const closed = assistantPage(true, null, { getResumes: () => late.promise })
    try {
      const loading = closed.page.openPicker('resumes')
      closed.page.closePanel()
      late.resolve({ data: [{ id: 99 }] })
      await loading
      assert.equal(closed.page.view.value, 'chat')
      assert.deepEqual(closed.page.pickerItems.value, [])
    } finally { closed.stop() }
  } finally { fixture.stop() }
})
