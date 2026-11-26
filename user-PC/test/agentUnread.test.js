import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { computed, nextTick, reactive, ref } from 'vue'
import { createUnreadCounter, unreadBadge, unreadCount } from '../src/utils/agentUnread.js'
import { messageContentCard, messagePreview } from '../src/utils/agentMessage.js'
import { parseExamInvitation } from '../src/utils/examInvitation.js'
import { mergeMessagePages, mergeMessageSnapshot, messagePageData } from '../src/utils/agentMessagePage.js'

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
    mergeMessagePages, mergeMessageSnapshot, messagePageData,
    ref, computed, nextTick, unreadCount, unreadBadge, messageContentCard, messagePreview,
    parseExamInvitation,
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
    listImMessages: async () => ({ data: { items: [{ messageId: 2, content: '来自 HR 的新消息' }], hasMore: false } }),
    getImMessageSnapshot: async () => ({ data: [] }),
    markImSessionRead: async () => {},
    ...overrides
  }, ['loadSessions', 'selectSession', 'refreshMessages', 'sessions', 'messages', 'selectedSessionId', 'activeView', 'loadMessages', 'loadOlderMessages', 'hasOlderMessages', 'messagesContainer', 'hasPendingMessages', 'messageSyncError', 'selectSystem', 'followLatestMessages'])
  return { page, document, events }
}

function avatarTopbar(store) {
  return componentScript('../src/components/agent/AgentTopbar.vue', {
    ref, computed, createUnreadCounter, unreadBadge,
    defaultAvatar: '/assets/default-avatar.jpg',
    defineProps() {}, useRouter: () => ({}), useRoute: () => ({ fullPath: '/index' }),
    hasCandidateAccessToken: () => true, useUserStore: () => store,
    onMounted() {}, onBeforeUnmount() {}
  }, ['displayAvatar', 'handleAvatarError'])
}

test('顶部头像读取账号资料并响应上传、删除和切换账号，不再显示昵称首字', () => {
  const store = reactive({ avatar: 'https://app.local/dev-api/profile/avatar.png' })
  const topbar = avatarTopbar(store)
  assert.equal(topbar.displayAvatar.value, store.avatar)
  store.avatar = 'https://app.local/dev-api/profile/new-avatar.png'
  assert.equal(topbar.displayAvatar.value, store.avatar)
  store.avatar = ''
  assert.equal(topbar.displayAvatar.value, '/assets/default-avatar.jpg')
  store.avatar = undefined
  assert.equal(topbar.displayAvatar.value, '/assets/default-avatar.jpg')
})

test('顶部头像加载失败回退默认图，更换头像后恢复，旧图片错误不覆盖新头像', () => {
  const store = reactive({ avatar: '/dev-api/profile/missing.png' })
  const topbar = avatarTopbar(store)
  const failed = store.avatar
  topbar.handleAvatarError({ currentTarget: { getAttribute: () => failed } })
  assert.equal(topbar.displayAvatar.value, '/assets/default-avatar.jpg')
  topbar.handleAvatarError({ currentTarget: { getAttribute: () => '/assets/default-avatar.jpg' } })
  assert.equal(topbar.displayAvatar.value, '/assets/default-avatar.jpg')
  store.avatar = '/dev-api/profile/replacement.png'
  topbar.handleAvatarError({ currentTarget: { getAttribute: () => failed } })
  assert.equal(topbar.displayAvatar.value, store.avatar)
})

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
    ref, computed, createUnreadCounter, unreadBadge, window, document, defaultAvatar: '/assets/default-avatar.jpg',
    defineProps() {}, useRouter: () => ({}), useRoute: () => ({ fullPath: '/index' }), hasCandidateAccessToken: () => true, useUserStore: () => ({}),
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

test('游客导航不查询未读数也不启动定时轮询', () => {
  const mounted = []
  let privateRequests = 0
  let timers = 0
  const topbar = componentScript('../src/components/agent/AgentTopbar.vue', {
    ref, computed, createUnreadCounter, unreadBadge, defaultAvatar: '/assets/default-avatar.jpg',
    window: { setInterval: () => { timers++ } }, document: { visibilityState: 'visible' },
    defineProps() {}, useRouter: () => ({}), useRoute: () => ({ fullPath: '/index' }),
    hasCandidateAccessToken: () => false, useUserStore: () => ({}),
    onMounted: callback => mounted.push(callback), onBeforeUnmount() {},
    getNoticeUnreadCount: async () => { privateRequests++ },
    getImUnreadCount: async () => { privateRequests++ }
  }, ['unreadCount', 'navItems'])
  mounted.forEach(callback => callback())
  assert.equal(privateRequests, 0)
  assert.equal(timers, 0)
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

test('加载结构化消息卡片后仍正常标记已读，单条异常格式不阻断其他消息', async () => {
  const { page, events } = messagePage({
    listImMessages: async () => ({ data: { items: [
      { messageId: 1, type: 6, content: '{"kind":"job_card","version":1,"positionId":26,"title":"前端工程师"}' },
      { messageId: 2, type: 5, content: '{broken' },
      { messageId: 3, type: 1, content: '普通文本消息' }
    ], hasMore: false } })
  })
  await page.loadSessions()
  await page.selectSession(page.sessions.value[0], false)
  assert.equal(page.messages.value[0].card.kind, 'job')
  assert.equal(page.messages.value[1].card.kind, 'notice')
  assert.equal(page.messages.value[2].card, null)
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
  pending.resolve({ data: { items: [], hasMore: false } })
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


test('聊天首次仅请求最新页，轮询携带 afterId，空增量不替换数组', async () => {
  const calls = []
  const { page } = messagePage({ listImMessages: async (id, params) => {
    calls.push({ id, params })
    return { data: { items: calls.length === 1 ? [{ messageId: 60, content: '最新消息' }] : [], hasMore: calls.length === 1 } }
  } })
  await page.loadSessions()
  await page.selectSession(page.sessions.value[0], false)
  assert.equal(page.hasOlderMessages.value, true)
  const original = page.messages.value
  await page.refreshMessages()
  assert.deepEqual(calls.map(call => call.params), [{}, { afterId: 60 }])
  assert.equal(page.messages.value, original)
})

test('加载更早消息使用 beforeId，保持阅读位置并去重排序', async () => {
  const calls = []
  const { page } = messagePage({ listImMessages: async (id, params) => {
    calls.push(params)
    return { data: { items: params.beforeId ? [{ messageId: 30, content: '旧消息' }] : [{ messageId: 60, content: '新消息' }], hasMore: !params.beforeId } }
  } })
  await page.loadSessions()
  await page.selectSession(page.sessions.value[0], false)
  const container = { scrollTop: 120, get scrollHeight() { return 500 + page.messages.value.length * 100 } }
  page.messagesContainer.value = container
  await page.loadOlderMessages()
  assert.deepEqual(calls, [{}, { beforeId: 60 }])
  assert.deepEqual(page.messages.value.map(item => item.messageId), [30, 60])
  assert.equal(container.scrollTop, 220)
  assert.equal(page.hasOlderMessages.value, false)
})

test('追赶多页增量，未追完不清角标，失败后保持现有消息可重试', async () => {
  let fail = false
  const { page } = messagePage({ listImMessages: async (id, params) => {
    if (fail) throw new Error('网络中断')
    const next = params.afterId ? Number(params.afterId) + 1 : 1
    return { data: { items: [{ messageId: next, content: '合成消息' }], hasMore: next < 15 } }
  } })
  await page.loadSessions()
  await page.selectSession(page.sessions.value[0], false)
  await page.refreshMessages()
  assert.equal(page.hasPendingMessages.value, true)
  assert.equal(page.sessions.value[0].unread, 3)
  fail = true
  const count = page.messages.value.length
  await page.refreshMessages()
  assert.equal(page.messages.value.length, count)
  assert.match(page.messageSyncError.value, /网络中断/)
  fail = false
  await page.refreshMessages()
  assert.equal(page.messages.value.at(-1).messageId, 15)
  assert.equal(page.sessions.value[0].unread, 0)
})

function rescheduleMessage(messageId, status = 'pending') {
  return { messageId, type: 5, content: JSON.stringify({ kind: 'interview_reschedule', version: 1, status, positionName: '合成岗位', reviewNote: status === 'pending' ? '' : '已审核' }) }
}

test('无新增消息时也刷新旧改期卡片，批准和拒绝重新生成卡片，保留历史及阅读位置', async () => {
  let status = 'pending'
  const snapshots = []
  const { page } = messagePage({
    listImMessages: async (id, params) => ({ data: { items: params.afterId ? [] : [rescheduleMessage(1), { messageId: 60, type: 1, content: '最新消息' }], hasMore: false } }),
    getImMessageSnapshot: async (sessionId, ids) => { snapshots.push({ sessionId, ids }); return { data: [rescheduleMessage(1, status)] } }
  })
  await page.loadSessions()
  await page.selectSession(page.sessions.value[0], false)
  page.messagesContainer.value = { scrollTop: 120, scrollHeight: 500, clientHeight: 100 }
  page.followLatestMessages.value = false
  const latest = page.messages.value[1]
  status = 'approved'
  await page.refreshMessages()
  assert.equal(page.messages.value[0].card.status, '已同意')
  assert.equal(page.messages.value[0].card.fields.find(field => field.label === '处理说明').value, '已审核')
  assert.equal(page.messages.value[1], latest)
  assert.equal(page.messagesContainer.value.scrollTop, 120)
  const unchanged = page.messages.value
  await page.refreshMessages()
  assert.equal(page.messages.value, unchanged)
  status = 'rejected'
  await page.refreshMessages()
  assert.equal(page.messages.value[0].card.status, '未通过')
  assert.deepEqual(snapshots.map(item => item.ids), [[1], [1], [1]])
})

test('新增消息增量与旧卡片状态同步并存，快照缺失仅删除指定卡片，不清空其他历史', async () => {
  let step = 0
  const { page } = messagePage({
    listImMessages: async (id, params) => ({ data: { items: params.afterId ? (++step === 1 ? [{ messageId: 61, type: 1, content: '新增消息' }] : []) : [rescheduleMessage(1), { messageId: 60, type: 1, content: '历史文本' }], hasMore: false } }),
    getImMessageSnapshot: async () => ({ data: step === 1 ? [rescheduleMessage(1, 'approved')] : [] })
  })
  await page.loadSessions()
  await page.selectSession(page.sessions.value[0], false)
  await page.refreshMessages()
  assert.deepEqual(page.messages.value.map(item => item.messageId), [1, 60, 61])
  assert.equal(page.messages.value[0].card.status, '已同意')
  await page.refreshMessages()
  assert.deepEqual(page.messages.value.map(item => item.messageId), [60, 61])
})

test('历史页中的旧改期卡片也同步，超过100条时按批轮换而非重载全量历史', async () => {
  const batches = []
  const { page } = messagePage({
    listImMessages: async (id, params) => ({ data: {
      items: params.beforeId ? Array.from({ length: 104 }, (_, index) => rescheduleMessage(index + 1)) : params.afterId ? [] : [rescheduleMessage(105)],
      hasMore: !params.beforeId && !params.afterId
    } }),
    getImMessageSnapshot: async (sessionId, ids) => { batches.push(ids); return { data: ids.map(id => rescheduleMessage(id, 'approved')) } }
  })
  await page.loadSessions()
  await page.selectSession(page.sessions.value[0], false)
  await page.loadOlderMessages()
  await page.refreshMessages()
  await page.refreshMessages()
  assert.deepEqual(batches.map(ids => ids.length), [100, 5])
  assert.equal(batches[0][0], 1)
  assert.equal(batches[1].at(-1), 105)
  assert.ok(page.messages.value.every(item => item.card.status === '已同意'))
})

test('快照失败保留旧卡片并可重试，切换会话丢弃迟到的状态响应', async () => {
  let fail = true
  const pending = deferred()
  const { page } = messagePage({
    listImMessages: async (id, params) => ({ data: { items: params.afterId ? [] : [rescheduleMessage(id === 1 ? 1 : 9)], hasMore: false } }),
    getImMessageSnapshot: async () => { if (fail) throw new Error('状态同步中断'); return pending.promise }
  })
  await page.loadSessions()
  await page.selectSession(page.sessions.value[0], false)
  await page.refreshMessages()
  assert.equal(page.messages.value[0].card.status, '等待处理')
  assert.match(page.messageSyncError.value, /状态同步中断/)
  fail = false
  const refresh = page.refreshMessages()
  await new Promise(resolve => setImmediate(resolve))
  await page.selectSession({ sessionId: 2 }, false)
  pending.resolve({ data: [rescheduleMessage(1, 'approved')] })
  await refresh
  assert.deepEqual(page.messages.value.map(item => item.messageId), [9])
  assert.equal(page.messages.value[0].card.status, '等待处理')
  assert.equal(page.messageSyncError.value, '')
})

test('快照合并拒绝未请求记录，不引入其他会话消息且保留未变化对象', () => {
  const existing = [{ messageId: 1, content: '旧内容' }, { messageId: 2, content: '普通文本' }]
  assert.equal(mergeMessageSnapshot(existing, [1], [{ ...existing[0] }]), existing)
  assert.throws(() => mergeMessageSnapshot(existing, [1], [{ messageId: 9, content: '其他消息' }]), /状态响应异常/)
  const updated = mergeMessageSnapshot(existing, [1], [{ messageId: 1, content: '已批准', card: { status: '已同意' } }])
  assert.equal(updated[0].card.status, '已同意')
  assert.equal(updated[1], existing[1])
})

test('卡片状态请求失败后下一轮重试同一批次，恢复后显示审批结果且不重复记录', async () => {
  let attempts = 0
  const { page } = messagePage({
    listImMessages: async (id, params) => ({ data: { items: params.afterId ? [] : [rescheduleMessage(1)], hasMore: false } }),
    getImMessageSnapshot: async (id, ids) => {
      assert.deepEqual(ids, [1])
      if (++attempts === 1) throw new Error('临时失败')
      return { data: [rescheduleMessage(1, 'approved')] }
    }
  })
  await page.loadSessions()
  await page.selectSession(page.sessions.value[0], false)
  await page.refreshMessages()
  assert.match(page.messageSyncError.value, /临时失败/)
  await page.refreshMessages()
  assert.equal(attempts, 2)
  assert.equal(page.messages.value.length, 1)
  assert.equal(page.messages.value[0].card.status, '已同意')
  assert.equal(page.messageSyncError.value, '')
})
