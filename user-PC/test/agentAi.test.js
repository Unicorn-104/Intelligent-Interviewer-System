import test from 'node:test'
import assert from 'node:assert/strict'
import { aiActions, aiContextPayload, aiPlainText, aiRunError, consumeAiEvents, readAiCards, receiveAiRun } from '../src/utils/agentAi.js'
import { useAiAssistant } from '../src/composables/useAiAssistant.js'

function deferred() {
  let resolve
  let reject
  const promise = new Promise((done, fail) => { resolve = done; reject = fail })
  return { promise, resolve, reject }
}

function setup(overrides = {}, streamOptions = {}) {
  const calls = []
  let saved = []
  const api = {
    listAiSessions: async before => ({ data: { items: before ? [{ id: 'older', title: '旧对话' }] : [{ id: 'session', title: '求职咨询' }], hasNext: !before, nextCursor: before ? null : 'cursor' } }),
    createAiSession: async () => ({ data: { id: 'created', title: '新对话' } }),
    listAiMessages: async () => ({ data: { items: saved, hasNext: false } }),
    getAiRun: async () => ({ data: { status: 'COMPLETED' } }),
    startAiRun: async (id, payload) => {
      calls.push({ id, payload })
      saved = [{ id: 1, role: 'user', content: payload.content, runId: 'run' }, { id: 2, role: 'assistant', content: '基于真实简历的建议', runId: 'run', cardsJson: '[{"positionId":8,"title":"前端工程师"}]' }]
      return { data: { id: 'run' } }
    },
    streamAiRun: async (id, after, emit) => { emit({ id: 1, type: 'delta', data: { text: '基于真实简历的建议' } }); emit({ id: 2, type: 'done', data: { status: 'COMPLETED' } }) },
    cancelAiRun: async () => {},
    renameAiSession: async (id, title) => { calls.push({ operation: 'rename', id, title }) },
    pinAiSession: async (id, pinned) => { calls.push({ operation: 'pin', id, pinned }) },
    deleteAiSession: async id => { calls.push({ operation: 'delete', id }) },
    getResumes: async () => ({ data: [{ id: 7, name: '前端求职简历' }] }),
    getApplication: async id => ({ data: { id, jobTitle: '前端工程师', resumeId: 7, resumeName: '投递时简历' } }),
    ...overrides
  }
  return { assistant: useAiAssistant(api, streamOptions), calls, api }
}

test('超时提示说明服务响应慢，避免误导为简历读取失败', () => {
  assert.match(aiRunError('TIMEOUT'), /AI 服务响应超时/)
  assert.match(aiRunError('TIMEOUT'), /未完成回答/)
  assert.match(aiRunError('TIMEOUT'), /不代表简历读取失败/)
})

test('四个快捷功能使用后端定义的真实 action，简历与岗位上下文不串用', () => {
  assert.deepEqual(aiActions.map(item => item.value), ['job_recommendation', 'resume_analysis', 'interview_preparation', 'writing_polish'])
  const resume = { id: 7 }
  const application = { id: 26, resumeId: 8 }
  assert.deepEqual(aiContextPayload('resume_analysis', resume, application), { action: 'resume_analysis', resumeId: 7, applicationId: undefined })
  assert.deepEqual(aiContextPayload('interview_preparation', resume, application), { action: 'interview_preparation', resumeId: 8, applicationId: 26 })
  assert.throws(() => aiContextPayload('job_recommendation', null, null), /选择.*简历/)
  assert.throws(() => aiContextPayload('interview_preparation', resume, null), /已投递岗位/)
  assert.equal(aiContextPayload('writing_polish', null, null).resumeId, undefined)
})

test('回答清除常见 Markdown 标记但不渲染 HTML，保留换行、编号、代码标识和链接地址', () => {
  const output = aiPlainText('## 简历建议\n**技能**\n- 使用 `user_id`\n1. [面试链接](https://example.com/interview)\n```text\n<script>alert(1)</script>\n```')
  assert.equal(output, '简历建议\n技能\n• 使用 user_id\n1. 面试链接（https://example.com/interview）\n<script>alert(1)</script>')
  assert.equal(aiPlainText('C++ / C# / user_id / __init__'), 'C++ / C# / user_id / init')
  assert.deepEqual(readAiCards('invalid'), [])
  assert.deepEqual(readAiCards('[{"positionId":"javascript:1"},{"positionId":8}]'), [{ positionId: 8 }])
})

test('事件流正确处理 UTF-8 多字节、任意分块与 CRLF，保留事件游标', async () => {
  const bytes = new TextEncoder().encode(': heartbeat\r\nid: 12\r\nevent: delta\r\ndata: {"text":"你好，求职者"}\r\n\r\nid: 13\nevent: done\ndata: {"status":"COMPLETED"}\n\n')
  const body = new ReadableStream({ start(controller) { for (const byte of bytes) controller.enqueue(new Uint8Array([byte])); controller.close() } })
  const events = []
  await consumeAiEvents(body, event => events.push(event))
  assert.equal(events.length, 2)
  assert.equal(events[0].data.text, '你好，求职者')
  assert.equal(events[0].id, 12)
  assert.equal(events[1].type, 'done')
  assert.equal(body.locked, false)
})

test('事件流拒绝损坏的 JSON 并释放读取锁', async () => {
  const body = new ReadableStream({ start(controller) { controller.enqueue(new TextEncoder().encode('data: not-json\n\n')); controller.close() } })
  await assert.rejects(consumeAiEvents(body, () => {}))
  assert.equal(body.locked, false)
})

test('接收 done 后立即结束读取，不等待服务端关闭连接', async () => {
  let cancelled = false
  const body = new ReadableStream({
    start(controller) { controller.enqueue(new TextEncoder().encode('id: 1\nevent: done\ndata: {"status":"COMPLETED"}\n\n')) },
    cancel() { cancelled = true }
  })
  const events = []
  await consumeAiEvents(body, event => events.push(event))
  assert.equal(events.length, 1)
  assert.equal(cancelled, true)
  assert.equal(body.locked, false)
})

test('传输层发出 done 后不关闭，控制器仍收尾解锁且不重复发起模型任务', async () => {
  let aborted = false
  const { assistant, calls } = setup({ streamAiRun: async (id, after, emit, signal) => {
    signal.addEventListener('abort', () => { aborted = true }, { once: true })
    emit({ id: 1, type: 'delta', data: { text: 'synthetic answer' } })
    assert.equal(assistant.status.value, '正在生成回答')
    emit({ id: 2, type: 'done', data: { status: 'COMPLETED' } })
    await new Promise(() => {})
  } })
  assistant.draft.value = '分析简历'
  await assistant.send()
  assert.equal(assistant.busy.value, false)
  assert.equal(assistant.status.value, '')
  assert.equal(aborted, true)
  assert.equal(calls.length, 1)
})

test('连接一直打开但丢失 done 时，通过任务状态恢复完整回答并解锁', async () => {
  let aborted = false
  let polls = 0
  const { assistant, calls } = setup({
    getAiRun: async () => { polls++; return { data: { status: 'COMPLETED' } } },
    streamAiRun: async (id, after, emit, signal) => {
      signal.addEventListener('abort', () => { aborted = true }, { once: true })
      emit({ id: 1, type: 'delta', data: { text: '一半回答' } })
      await new Promise(() => {})
    }
  }, { pollIntervalMs: 5 })
  assistant.draft.value = '分析简历'
  await assistant.send()
  assert.equal(polls, 1)
  assert.equal(aborted, true)
  assert.equal(assistant.runId.value, null)
  assert.equal(assistant.busy.value, false)
  assert.equal(assistant.messages.value.at(-1).content, '基于真实简历的建议')
  assert.equal(calls.length, 1)
})

test('任务已失败但连接不结束时显示真实错误，保留半段回答且解除忙碌', async () => {
  const { assistant } = setup({
    getAiRun: async () => ({ data: { status: 'FAILED', errorCode: 'TIMEOUT' } }),
    listAiMessages: async () => ({ data: { items: [{ role: 'user', content: '分析简历', runId: 'run' }] } }),
    streamAiRun: async (id, after, emit) => {
      emit({ id: 1, type: 'delta', data: { text: '未完成内容' } })
      await new Promise(() => {})
    }
  }, { pollIntervalMs: 5 })
  assistant.draft.value = '分析简历'
  await assistant.send()
  assert.equal(assistant.busy.value, false)
  assert.match(assistant.error.value, /超时/)
  assert.equal(assistant.messages.value.at(-1).content, '未完成内容')
  assert.equal(assistant.messages.value.at(-1).interrupted, true)
})

test('状态暂时读取失败可继续核对，取消读取后不再轮询', async () => {
  let polls = 0
  let aborted = false
  const result = await receiveAiRun({
    getAiRun: async () => {
      polls++
      if (polls === 1) throw new Error('synthetic network failure')
      return { data: { status: 'COMPLETED' } }
    },
    streamAiRun: async (id, after, emit, signal) => {
      signal.addEventListener('abort', () => { aborted = true }, { once: true })
      await new Promise(() => {})
    }
  }, 'run', 0, () => {}, new AbortController().signal, { pollIntervalMs: 5 })
  assert.equal(result.status, 'COMPLETED')
  assert.equal(aborted, true)
  await new Promise(resolve => setTimeout(resolve, 15))
  assert.equal(polls, 2)
})

test('已收到结束状态但历史同步失败时仍解锁，不无限显示正在生成', async () => {
  const { assistant } = setup({
    listAiMessages: async () => { throw new Error('synthetic history failure') },
    streamAiRun: async (id, after, emit) => {
      emit({ id: 1, type: 'delta', data: { text: '当前内容' } })
      emit({ id: 2, type: 'done', data: { status: 'COMPLETED' } })
    }
  })
  assistant.draft.value = '分析简历'
  await assistant.send()
  assert.equal(assistant.busy.value, false)
  assert.equal(assistant.runId.value, null)
  assert.equal(assistant.status.value, '')
  assert.equal(assistant.disconnected.value, false)
  assert.match(assistant.error.value, /历史记录同步失败/)
  assert.equal(assistant.messages.value.at(-1).content, '当前内容')
  assert.equal(assistant.messages.value.at(-1).interrupted, true)
})

test('卸载时立即中止保持打开的连接，清理状态轮询且不取消服务端任务', async () => {
  const controller = new AbortController()
  let polls = 0
  let aborted = false
  const receiving = receiveAiRun({
    getAiRun: async () => { polls++; return { data: { status: 'RUNNING' } } },
    streamAiRun: async (id, after, emit, signal) => {
      signal.addEventListener('abort', () => { aborted = true }, { once: true })
      controller.abort()
      await new Promise(() => {})
    }
  }, 'run', 0, () => {}, controller.signal, { pollIntervalMs: 5 })
  await assert.rejects(receiving, failure => failure.name === 'AbortError')
  await new Promise(resolve => setTimeout(resolve, 15))
  assert.equal(aborted, true)
  assert.equal(polls, 0)
})

test('状态和流都失联时有等待上限，不伪造完成或重复提交', async () => {
  const controller = new AbortController()
  await assert.rejects(receiveAiRun({
    getAiRun: async () => { throw new Error('synthetic disconnect') },
    streamAiRun: () => new Promise(() => {})
  }, 'run', 0, () => {}, controller.signal, { pollIntervalMs: 5, connectionTimeoutMs: 20 }), /恢复回答或停止/)
})

test('岗位推荐与简历分析发送所选简历，历史回答恢复后可展示真实岗位卡片', async () => {
  const { assistant, calls } = setup()
  assistant.selectResume({ id: 7, name: '前端简历' })
  assistant.action.value = 'job_recommendation'
  assistant.draft.value = '推荐合适岗位'
  assert.equal(await assistant.send(), true)
  assert.equal(calls[0].payload.action, 'job_recommendation')
  assert.equal(calls[0].payload.resumeId, 7)
  assert.equal(calls[0].payload.applicationId, undefined)
  assert.equal(assistant.messages.value.at(-1).cards[0].positionId, 8)
  assert.equal(assistant.busy.value, false)
  assert.equal(assistant.action.value, 'chat')
})

test('面试准备自动使用投递关联简历；重新选择简历会清除旧岗位，防止错误分析', async () => {
  const { assistant, calls } = setup()
  assistant.selectResume({ id: 1, name: '其他简历' })
  await assistant.selectApplication({ id: 26, resumeId: 7, resumeName: '投递时简历', jobTitle: '前端工程师' })
  assert.equal(assistant.resume.value.id, 7)
  assistant.action.value = 'interview_preparation'
  assistant.draft.value = '帮我准备面试'
  await assistant.send()
  assert.equal(calls[0].payload.resumeId, 7)
  assert.equal(calls[0].payload.applicationId, 26)
  assistant.action.value = 'interview_preparation'
  assistant.selectResume({ id: 9, name: '后端简历' })
  assert.equal(assistant.application.value, null)
  assert.equal(assistant.action.value, 'chat')
})

test('投递简历失效时不伪造上下文，不自动换用其他简历', async () => {
  const { assistant, calls } = setup()
  assert.equal(await assistant.selectApplication({ id: 26, resumeId: 38, resumeName: '已删除的简历' }), false)
  assert.equal(assistant.application.value, null)
  assert.equal(assistant.resume.value, null)
  assert.match(assistant.error.value, /投递关联的简历已删除/)
  assert.equal(calls.length, 0)
  assistant.selectResume({ id: 7, name: '有效简历' })
  assert.equal(assistant.error.value, '')
})

test('选择投递读取简历失败不会覆盖现有上下文，并允许重试', async () => {
  const { assistant } = setup({ getResumes: async () => { throw new Error('简历接口不可用') } })
  assistant.selectResume({ id: 9, name: '原简历' })
  assert.equal(await assistant.selectApplication({ id: 26, resumeId: 7 }), false)
  assert.equal(assistant.resume.value.id, 9)
  assert.equal(assistant.application.value, null)
  assert.equal(assistant.locked.value, false)
  assert.match(assistant.error.value, /简历接口不可用/)
})

test('校验投递简历期间锁定发送，卸载后不接受迟到结果', async () => {
  const pending = deferred()
  const { assistant, calls } = setup({ getResumes: () => pending.promise })
  const selection = assistant.selectApplication({ id: 26, resumeId: 7 })
  assistant.draft.value = '分析简历'
  assert.equal(assistant.locked.value, true)
  assert.equal(await assistant.send(), false)
  assistant.dispose()
  pending.resolve({ data: [{ id: 7, name: '有效简历' }] })
  assert.equal(await selection, false)
  assert.equal(assistant.resume.value, null)
  assert.equal(calls.length, 0)
})

test('取消所选岗位清除投递上下文，不误报缺少简历', async () => {
  const { assistant } = setup()
  await assistant.selectApplication({ id: 26, resumeId: 7 })
  assistant.action.value = 'interview_preparation'
  assert.equal(await assistant.selectApplication(null), true)
  assert.equal(assistant.application.value, null)
  assert.equal(assistant.resume.value, null)
  assert.equal(assistant.action.value, 'chat')
  assert.equal(assistant.error.value, '')
})

test('缺少简历不会创建空会话；自由聊天和写作润色无需简历', async () => {
  const { assistant, calls } = setup()
  assistant.action.value = 'resume_analysis'
  assistant.draft.value = '分析简历'
  assert.equal(await assistant.send(), false)
  assert.equal(calls.length, 0)
  assert.equal(assistant.sessionId.value, null)
  assistant.action.value = 'writing_polish'
  assistant.draft.value = '请润色这段自我介绍'
  await assistant.send()
  assert.equal(calls[0].payload.action, 'writing_polish')
  assert.equal(calls[0].payload.resumeId, undefined)
})

test('创建会话到发送完成全程防重复点击；进行中禁止切换会话和上下文', async () => {
  const pending = deferred()
  const { assistant, calls } = setup({ createAiSession: () => pending.promise })
  assistant.draft.value = '你好'
  const first = assistant.send()
  assert.equal(assistant.busy.value, true)
  assert.equal(await assistant.send(), false)
  assert.equal(assistant.newSession(), false)
  assistant.selectResume({ id: 99 })
  assert.equal(assistant.resume.value, null)
  pending.resolve({ data: { id: 'created' } })
  await first
  assert.equal(calls.length, 1)
})

test('任务创建失败保留原问题，重试同一问题复用 requestId 防止重复提交', async () => {
  const requests = []
  const { assistant } = setup({ startAiRun: async (id, payload) => { requests.push(payload); throw new Error('请求超时') } })
  assistant.draft.value = '请给出建议'
  await assistant.send()
  assert.equal(assistant.draft.value, '请给出建议')
  assert.equal(assistant.busy.value, false)
  await assistant.send()
  assert.equal(requests[0].requestId, requests[1].requestId)
  assert.equal(assistant.messages.value.length, 0)
})

test('实时断线按事件游标恢复且过滤重复事件，不重复拼接回答', async () => {
  const afters = []
  const { assistant } = setup({
    getAiRun: async () => ({ data: { status: 'RUNNING' } }),
    listAiMessages: async () => ({ data: { items: [{ role: 'user', runId: 'run', content: '你好' }] } }),
    streamAiRun: async (id, after, emit) => {
      afters.push(after)
      emit({ id: 1, type: 'delta', data: { text: '第一段' } })
      if (!after) throw new Error('断线')
      emit({ id: 2, type: 'delta', data: { text: '第二段' } })
      emit({ id: 3, type: 'done', data: { status: 'CANCELLED' } })
    }
  })
  assistant.draft.value = '你好'
  await assistant.send()
  assert.deepEqual(afters, [0, 1])
  assert.equal(assistant.messages.value.at(-1).content, '第一段第二段')
  assert.equal(assistant.messages.value.at(-1).interrupted, true)
})

test('失败任务显示服务端错误原因，不伪造成功回答', async () => {
  const { assistant } = setup({ streamAiRun: async (id, after, emit) => { emit({ id: 1, type: 'done', data: { status: 'FAILED', errorCode: 'TIMEOUT' } }) } })
  assistant.draft.value = '你好'
  await assistant.send()
  assert.match(assistant.error.value, /超时/)
  assert.equal(assistant.busy.value, false)
})

test('历史分页、重命名、置顶、删除均调用后端；删除当前会话后清空上下文', async () => {
  const { assistant, calls } = setup()
  await assistant.initialize()
  assert.equal(assistant.sessionId.value, 'session')
  await assistant.loadHistory(true)
  assert.equal(assistant.sessions.value.length, 2)
  await assistant.manageHistory('rename', 'older', '面试准备记录')
  await assistant.manageHistory('pin', 'older', true)
  assert.equal(assistant.sortedSessions.value[0].title, '面试准备记录')
  await assistant.manageHistory('delete', 'session')
  assert.equal(assistant.sessionId.value, null)
  assert.equal(assistant.messages.value.length, 0)
  assert.equal(calls.filter(item => item.operation).length, 3)
  assert.equal(await assistant.manageHistory('rename', 'older', ' '), false)
  assert.match(assistant.historyError.value, /标题/)
})

test('历史消息按游标向前读取，去重且保留顺序', async () => {
  const cursors = []
  const { assistant } = setup({ listAiMessages: async (id, before) => {
    cursors.push(before)
    return { data: before ? { items: [{ id: 1, role: 'user', content: '更早消息' }, { id: 2, role: 'assistant', content: '之前消息' }], hasNext: false } : { items: [{ id: 2, role: 'assistant', content: '之前消息' }, { id: 3, role: 'user', content: '最近消息' }], hasNext: true, nextCursor: 2 } }
  } })
  await assistant.initialize()
  await assistant.loadOlder()
  assert.deepEqual(cursors, [undefined, 2])
  assert.deepEqual(assistant.messages.value.map(item => item.id), [1, 2, 3])
})

test('重新打开历史会话恢复该次选定简历和投递岗位', async () => {
  const { assistant } = setup({ listAiMessages: async () => ({ data: { items: [{ id: 1, role: 'assistant', content: '历史建议', runId: 'old-run' }] } }), getAiRun: async () => ({ data: { status: 'COMPLETED', resumeId: 7, applicationId: 26 } }) })
  await assistant.initialize()
  assert.equal(assistant.resume.value.name, '前端求职简历')
  assert.equal(assistant.application.value.jobTitle, '前端工程师')
})

test('历史投递关联简历已删除时保留消息，清除失效上下文并提示重新选择', async () => {
  const { assistant } = setup({
    listAiMessages: async () => ({ data: { items: [{ id: 1, role: 'assistant', content: '历史建议', runId: 'old-run' }] } }),
    getAiRun: async () => ({ data: { status: 'FAILED', errorCode: 'UNAVAILABLE', resumeId: 38, applicationId: 26 } }),
    getApplication: async () => ({ data: { id: 26, resumeId: 38 } })
  })
  await assistant.initialize()
  assert.equal(assistant.messages.value[0].content, '历史建议')
  assert.equal(assistant.resume.value, null)
  assert.equal(assistant.application.value, null)
  assert.match(assistant.error.value, /简历已删除/)
  assistant.draft.value = '先聊求职方向'
  assert.equal(await assistant.send(), true)
})

test('历史简历接口失败不保留虚假的已选择简历', async () => {
  const { assistant } = setup({
    listAiMessages: async () => ({ data: { items: [{ id: 1, runId: 'old-run' }] } }),
    getAiRun: async () => ({ data: { status: 'COMPLETED', resumeId: 7, applicationId: 26 } }),
    getResumes: async () => { throw new Error('简历读取失败') }
  })
  await assistant.initialize()
  assert.equal(assistant.resume.value, null)
  assert.equal(assistant.application.value, null)
  assert.match(assistant.error.value, /简历读取失败/)
})

test('页面卸载后迟到的历史请求不会更新状态或启动新任务', async () => {
  const pending = deferred()
  const { assistant } = setup({ listAiSessions: () => pending.promise })
  const loading = assistant.initialize()
  assistant.dispose()
  pending.resolve({ data: { items: [{ id: 'late' }] } })
  await loading
  assert.equal(assistant.sessions.value.length, 0)
  assert.equal(await assistant.send(), false)
})

test('首次读取历史期间锁定新建和发送，避免迟到的旧会话覆盖用户新操作', async () => {
  const pending = deferred()
  const { assistant } = setup({ listAiSessions: () => pending.promise })
  const initializing = assistant.initialize()
  assert.equal(assistant.locked.value, true)
  assert.equal(assistant.newSession(), false)
  assistant.draft.value = '不会抢先发送'
  assert.equal(await assistant.send(), false)
  pending.resolve({ data: { items: [], hasNext: false } })
  await initializing
  assert.equal(assistant.locked.value, false)
  assert.equal(assistant.initialized.value, true)
})

test('停止生成调用后端取消，并保留未完成的文本；关闭页面不会误取消后台任务', async () => {
  const started = deferred()
  const cancelled = []
  const { assistant } = setup({
    cancelAiRun: async id => { cancelled.push(id) },
    listAiMessages: async () => ({ data: { items: [{ id: 1, role: 'user', content: '原问题', runId: 'run' }] } }),
    streamAiRun: (id, after, emit, signal) => new Promise((resolve, reject) => {
      emit({ id: 1, type: 'delta', data: { text: '未完成的建议' } })
      started.resolve()
      signal.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')), { once: true })
    })
  })
  assistant.draft.value = '原问题'
  const sending = assistant.send()
  await started.promise
  await assistant.stop()
  await sending
  assert.deepEqual(cancelled, ['run'])
  assert.equal(assistant.busy.value, false)
  assert.equal(assistant.messages.value.at(-1).content, '未完成的建议')
  assert.equal(assistant.messages.value.at(-1).interrupted, true)
  assistant.dispose()
  assert.deepEqual(cancelled, ['run'])
})

test('历史中的进行中任务自动恢复，断线彻底失败仍保留任务以便继续或停止', async () => {
  const { assistant } = setup({
    listAiMessages: async () => ({ data: { items: [{ id: 1, role: 'user', content: '原问题', runId: 'restored-run' }], activeRunId: 'restored-run' } }),
    getAiRun: async () => ({ data: { status: 'RUNNING', resumeId: 7 } }),
    streamAiRun: async () => { throw new Error('网络断开') }
  })
  await assistant.initialize()
  assert.equal(assistant.runId.value, 'restored-run')
  assert.equal(assistant.disconnected.value, true)
  assert.equal(assistant.busy.value, true)
  assert.equal(assistant.resume.value.id, 7)
  assert.match(assistant.error.value, /网络断开/)
  assistant.dispose()
})
