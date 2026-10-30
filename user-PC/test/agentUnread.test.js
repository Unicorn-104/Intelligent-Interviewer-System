import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { computed, nextTick, ref } from 'vue'
import { createUnreadCounter, unreadBadge, unreadCount } from '../src/utils/agentUnread.js'

function deferred() {
  let resolve
  const promise = new Promise(done => { resolve = done })
  return { promise, resolve }
}

function componentScript(file, dependencies, exports) {
  const source = fs.readFileSync(new URL(file, import.meta.url), 'utf8')
    .match(/<script setup>([\s\S]*?)<\/script>/)[1]
    .replace(/^import .*$/gm, '')
    .replaceAll('import.meta.env.VITE_APP_BASE_API', JSON.stringify('/dev-api'))
  return new Function(...Object.keys(dependencies), `${source}\nreturn { ${exports.join(', ')} }`)(...Object.values(dependencies))
}

function messagePage(overrides = {}) {
  const events = []
  const document = { visibilityState: 'visible' }
  const page = componentScript('../src/views/agent/pages/messages.vue', {
    ref, computed, nextTick, unreadCount, unreadBadge,
    onMounted() {}, onBeforeUnmount() {},
    document,
    window: { location: { origin: 'http://app.local' }, dispatchEvent: event => events.push(event.type) },
    location: { search: '' },
    history: { replaceState() {} },
    appHref: value => value,
    setTimeout() {}, clearTimeout() {},
    resolveMessageAttachment: value => value || '',
    messageLinkParts: value => [{ text: value }],
    listImSessions: async () => ({ data: [{ sessionId: 1, peerId: 20, unread: 3 }] }),
    listImMessages: async () => ({ data: [{ messageId: 2, content: '来自 HR 的新消息' }] }),
    markImSessionRead: async () => {},
    ...overrides
  }, ['loadSessions', 'selectSession', 'refreshMessages', 'sessions', 'selectedSessionId', 'activeView'])
  return { page, document, events }
}

test('未读数规范化并将大计数截为 99+，零未读不显示角标', () => {
  assert.equal(unreadCount('12'), 12)
  for (const value of [null, undefined, -1, 1.5, 'NaN', Infinity, '0']) {
    assert.equal(unreadCount(value), 0)
    assert.equal(unreadBadge(value), '')
  }
  assert.equal(unreadBadge(99), '99')
  assert.equal(unreadBadge(100), '99+')
})

test('系统通知为零时仍统计企业 HR 未读，单一接口失败不清掉其他计数', async () => {
  let noticeCount = 0
  let imCount = 5
  let imFailed = false
  const totals = []
  const counter = createUnreadCounter([
    async () => noticeCount,
    async () => { if (imFailed) throw new Error('暂时不可用'); return imCount }
  ], total => totals.push(total))
  await counter.refresh()
  noticeCount = 2
  imFailed = true
  await counter.refresh()
  imFailed = false
  imCount = 0
  await counter.refresh()
  assert.deepEqual(totals, [5, 7, 2])
})

test('旧的未读请求不覆盖已读后的新结果，卸载后不更新角标', async () => {
  const delayed = deferred()
  const totals = []
  let calls = 0
  const counter = createUnreadCounter([() => ++calls === 1 ? delayed.promise : 0], total => totals.push(total))
  const older = counter.refresh()
  await counter.refresh()
  delayed.resolve(8)
  await older
  assert.deepEqual(totals, [0])
  const pending = deferred()
  const stopped = createUnreadCounter([() => pending.promise], total => totals.push(total))
  const loading = stopped.refresh()
  stopped.stop()
  pending.resolve(4)
  await loading
  await stopped.refresh()
  assert.deepEqual(totals, [0])
})

test('实际导航读取 IM 的顶层 count，定时刷新、恢复可见及卸载清理正常', async () => {
  const mounted = []
  const unmounted = []
  const window = new EventTarget()
  const document = new EventTarget()
  document.visibilityState = 'visible'
  let tick
  let cleared = false
  let imCount = 4
  window.setInterval = (callback, interval) => {
    assert.equal(interval, 5000)
    tick = callback
    return 11
  }
  window.clearInterval = timer => { cleared = timer === 11 }
  const topbar = componentScript('../src/components/agent/AgentTopbar.vue', {
    ref, computed, createUnreadCounter, unreadBadge, window, document,
    defineProps() {}, useRouter: () => ({}), useUserStore: () => ({}),
    onMounted: callback => mounted.push(callback),
    onBeforeUnmount: callback => unmounted.push(callback),
    getNoticeUnreadCount: async () => ({ code: 200, data: 0 }),
    getImUnreadCount: async () => ({ code: 200, count: imCount })
  }, ['unreadCount', 'navItems'])
  const flush = () => new Promise(resolve => setImmediate(resolve))
  mounted.forEach(callback => callback())
  await flush()
  assert.equal(topbar.unreadCount.value, 4)
  assert.equal(topbar.navItems.value.find(item => item.key === 'messages').badge, '4')
  imCount = 6
  tick()
  await flush()
  assert.equal(topbar.unreadCount.value, 6)
  document.visibilityState = 'hidden'
  imCount = 8
  tick()
  await flush()
  assert.equal(topbar.unreadCount.value, 6)
  document.visibilityState = 'visible'
  document.dispatchEvent(new Event('visibilitychange'))
  await flush()
  assert.equal(topbar.unreadCount.value, 8)
  imCount = 0
  window.dispatchEvent(new Event('agent-notifications-updated'))
  await flush()
  assert.equal(topbar.unreadCount.value, 0)
  unmounted.forEach(callback => callback())
  assert.equal(cleared, true)
  imCount = 9
  tick()
  window.dispatchEvent(new Event('agent-notifications-updated'))
  await flush()
  assert.equal(topbar.unreadCount.value, 0)
})

test('进入消息页不自动打开首个 HR 会话或清除其未读数', async () => {
  let reads = 0
  const { page } = messagePage({ markImSessionRead: async () => { reads++ } })
  await page.loadSessions()
  assert.equal(page.activeView.value, 'system')
  assert.equal(page.selectedSessionId.value, null)
  assert.equal(page.sessions.value[0].unread, 3)
  assert.equal(reads, 0)
})

test('HR 会话内容加载失败或已读接口失败时不清除红点', async () => {
  let reads = 0
  const failedLoad = messagePage({
    listImMessages: async () => { throw new Error('读取失败') },
    markImSessionRead: async () => { reads++ }
  })
  await failedLoad.page.loadSessions()
  await failedLoad.page.selectSession(failedLoad.page.sessions.value[0], false)
  assert.equal(reads, 0)
  assert.equal(failedLoad.page.sessions.value[0].unread, 3)
  const failedRead = messagePage({ markImSessionRead: async () => { throw new Error('已读失败') } })
  await failedRead.page.loadSessions()
  await failedRead.page.selectSession(failedRead.page.sessions.value[0], false)
  assert.equal(failedRead.page.sessions.value[0].unread, 3)
  assert.deepEqual(failedRead.events, [])
})

test('成功查看 HR 会话后才清除角标并同步顶部未读总数', async () => {
  const { page, events } = messagePage()
  await page.loadSessions()
  await page.selectSession(page.sessions.value[0], false)
  assert.equal(page.sessions.value[0].unread, 0)
  assert.deepEqual(events, ['agent-notifications-updated'])
})

test('后台标签页不标记会话已读，也不轮询清除新消息', async () => {
  let reads = 0
  const { page, document } = messagePage({ markImSessionRead: async () => { reads++ } })
  await page.loadSessions()
  document.visibilityState = 'hidden'
  await page.selectSession(page.sessions.value[0], false)
  await page.refreshMessages()
  assert.equal(reads, 0)
  assert.equal(page.sessions.value[0].unread, 3)
})

test('加载期间切到其他会话，不误清原会话的未读数', async () => {
  const pending = deferred()
  let reads = 0
  const { page } = messagePage({
    listImMessages: () => pending.promise,
    markImSessionRead: async () => { reads++ }
  })
  await page.loadSessions()
  const loading = page.selectSession(page.sessions.value[0], false)
  page.selectedSessionId.value = 2
  pending.resolve({ data: [] })
  await loading
  assert.equal(reads, 0)
  assert.equal(page.sessions.value[0].unread, 3)
})

test('会话未读角标不放在窄屏隐藏的 conversation-meta 内', () => {
  const source = fs.readFileSync(new URL('../src/views/agent/pages/messages.vue', import.meta.url), 'utf8')
  assert.match(source, /<\/span>\s*<span v-if="unreadCount\(session.unread\)" class="unread conversation-unread"/)
  assert.match(source, /\.message-shell \.conversation-unread\{top:2px;right:0;/)
  assert.match(source, /\.message-shell \.conversation-sidebar\{padding:0\}/)
})
