import { computed, ref } from 'vue'
import { aiContextPayload, aiRunError, readAiCards, readAiMessage, receiveAiRun } from '../utils/agentAi.js'

export function useAiAssistant(api, streamOptions = {}) {
  const sessions = ref([])
  const sessionId = ref(null)
  const messages = ref([])
  const draft = ref('')
  const action = ref('chat')
  const resume = ref(null)
  const application = ref(null)
  const loading = ref(false)
  const submitting = ref(false)
  const streaming = ref(false)
  const stopping = ref(false)
  const status = ref('')
  const error = ref('')
  const historyError = ref('')
  const historyLoading = ref(false)
  const historySaving = ref(false)
  const historyHasMore = ref(false)
  const olderLoading = ref(false)
  const hasOlder = ref(false)
  const runId = ref(null)
  const disconnected = ref(false)
  const initialized = ref(false)
  let historyCursor = null
  let messageCursor = null
  let cursor = 0
  let controller = null
  let disposed = false
  let revision = 0
  let pendingRequest = null
  const busy = computed(() => submitting.value || streaming.value || stopping.value || Boolean(runId.value))
  const locked = computed(() => busy.value || loading.value || olderLoading.value || historySaving.value)
  const current = computed(() => sessions.value.find(item => item.id === sessionId.value))
  const pinned = value => value === true || String(value) === '1'
  const sortedSessions = computed(() => [...sessions.value].sort((first, second) => Number(pinned(second.pinned)) - Number(pinned(first.pinned))))

  async function loadHistory(older = false) {
    if (historyLoading.value || disposed || (older && !historyHasMore.value)) return
    historyLoading.value = true
    historyError.value = ''
    try {
      const response = await api.listAiSessions(older ? historyCursor : undefined)
      if (disposed) return
      const page = response.data
      if (!Array.isArray(page?.items)) throw new Error('会话历史响应格式不正确')
      const items = older ? [...sessions.value, ...page.items] : page.items
      sessions.value = [...new Map(items.map(item => [item.id, item])).values()]
      historyCursor = page.nextCursor
      historyHasMore.value = Boolean(page.hasNext && historyCursor)
    } catch (failure) {
      if (!disposed) historyError.value = failure.message || '历史记录加载失败'
    } finally {
      if (!disposed) historyLoading.value = false
    }
  }

  function applyPage(page) {
    if (!Array.isArray(page?.items)) throw new Error('对话记录响应格式不正确')
    messages.value = page.items.map(readAiMessage)
    messageCursor = page.nextCursor
    hasOlder.value = Boolean(page.hasNext && messageCursor)
  }

  async function restoreContext(metadata, epoch) {
    if (!metadata || disposed || epoch !== revision) return
    resume.value = null
    application.value = null
    try {
      const [resumesResponse, applicationResponse] = await Promise.all([
        metadata.resumeId || metadata.applicationId ? api.getResumes() : null,
        metadata.applicationId ? api.getApplication(metadata.applicationId) : null
      ])
      if (disposed || epoch !== revision) return
      const selectedApplication = applicationResponse?.data
      if (metadata.applicationId && (!selectedApplication?.resumeId || (metadata.resumeId && String(selectedApplication.resumeId) !== String(metadata.resumeId)))) throw new Error('历史投递关联的简历已失效，请重新选择简历和岗位')
      const resumeId = metadata.resumeId || selectedApplication?.resumeId
      if (resumeId) {
        if (!Array.isArray(resumesResponse?.data)) throw new Error('简历列表读取失败，请重新选择简历和岗位')
        const selected = resumesResponse.data.find(item => String(item.id) === String(resumeId))
        if (!selected) throw new Error('历史对话使用的简历已删除、停用或无法访问，请重新选择有效简历；历史消息仍可查看')
        resume.value = selected
      }
      application.value = selectedApplication || null
    } catch (failure) {
      if (!disposed && epoch === revision) error.value = failure.message || '上下文恢复失败，请重新选择简历和岗位'
    }
  }

  async function selectSession(id) {
    if (locked.value || disposed) return
    const epoch = ++revision
    loading.value = true
    error.value = ''
    try {
      const response = await api.listAiMessages(id)
      if (disposed || epoch !== revision) return
      applyPage(response.data)
      sessionId.value = id
      draft.value = ''
      action.value = 'chat'
      resume.value = null
      application.value = null
      pendingRequest = null
      const previousRun = response.data.activeRunId || messages.value.at(-1)?.runId
      if (previousRun) {
        try {
          const metadata = await api.getAiRun(previousRun)
          await restoreContext(metadata.data, epoch)
          if (!disposed && epoch === revision && metadata.data?.status === 'FAILED' && !error.value) error.value = aiRunError(metadata.data.errorCode)
        } catch {
          if (!disposed) error.value = '对话已读取，但上下文恢复失败；可以重新选择简历和岗位'
        }
      }
      if (!disposed && response.data.activeRunId) {
        cursor = 0
        runId.value = response.data.activeRunId
        loading.value = false
        await reconnect()
      }
    } catch (failure) {
      if (!disposed && epoch === revision) error.value = failure.message || '对话加载失败'
    } finally {
      if (!disposed && epoch === revision) loading.value = false
    }
  }

  async function initialize() {
    if (initialized.value || loading.value || disposed) return
    loading.value = true
    await loadHistory()
    if (disposed) return
    loading.value = false
    if (historyError.value) {
      error.value = historyError.value
      return
    }
    if (sessions.value.length) await selectSession(sessions.value[0].id)
    initialized.value = !error.value
  }

  function newSession() {
    if (locked.value || disposed) return false
    revision++
    sessionId.value = null
    messages.value = []
    draft.value = ''
    action.value = 'chat'
    resume.value = null
    application.value = null
    error.value = ''
    status.value = ''
    hasOlder.value = false
    disconnected.value = false
    pendingRequest = null
    return true
  }

  async function loadOlder() {
    if (locked.value || !hasOlder.value || !sessionId.value || disposed) return
    const epoch = revision
    olderLoading.value = true
    error.value = ''
    try {
      const response = await api.listAiMessages(sessionId.value, messageCursor)
      if (disposed || epoch !== revision) return
      const page = response.data
      if (!Array.isArray(page?.items)) throw new Error('对话记录响应格式不正确')
      const items = [...page.items.map(readAiMessage), ...messages.value]
      messages.value = [...new Map(items.map(item => [item.id || `${item.runId}-${item.role}`, item])).values()]
      messageCursor = page.nextCursor
      hasOlder.value = Boolean(page.hasNext && messageCursor)
    } catch (failure) {
      if (!disposed) error.value = failure.message || '更早的消息加载失败'
    } finally {
      if (!disposed) olderLoading.value = false
    }
  }

  async function settleRun(metadata) {
    if (disposed) return
    const id = runId.value
    const epoch = revision
    let syncError = ''
    try {
      const response = await api.listAiMessages(sessionId.value)
      if (disposed || epoch !== revision || runId.value !== id) return
      const partial = messages.value.find(item => item.role === 'assistant' && item.runId === id)
      const saved = response.data?.items || []
      if (!saved.some(item => item.role === 'assistant' && item.runId === id) && partial?.content) {
        applyPage(response.data)
        messages.value.push({ ...partial, interrupted: true })
      } else applyPage(response.data)
    } catch {
      if (disposed || epoch !== revision || runId.value !== id) return
      const partial = messages.value.find(item => item.role === 'assistant' && item.runId === id)
      if (partial) partial.interrupted = true
      syncError = '任务已结束，但历史记录同步失败；当前内容可能不完整，请稍后重新打开历史记录'
    }
    error.value = metadata.status === 'FAILED' ? aiRunError(metadata.errorCode) : syncError
    if (metadata.status === 'CANCELLED') status.value = '已停止生成'
    else status.value = ''
    runId.value = null
    disconnected.value = false
    await loadHistory()
  }

  async function reconnect() {
    if (!runId.value || streaming.value || stopping.value || disposed) return
    const id = runId.value
    streaming.value = true
    disconnected.value = false
    error.value = ''
    status.value = cursor ? '正在恢复回答' : '正在准备回答'
    let assistant = messages.value.find(item => item.role === 'assistant' && item.runId === id)
    if (!assistant) {
      messages.value.push({ role: 'assistant', content: '', runId: id, cards: [] })
      assistant = messages.value.at(-1)
    }
    controller = new AbortController()
    try {
      for (let attempt = 0; attempt < 3; attempt++) {
        let terminal = null
        try {
          terminal = await receiveAiRun(api, id, cursor, event => {
            if (disposed || runId.value !== id || (event.id && event.id <= cursor)) return
            cursor = Math.max(cursor, event.id || 0)
            if (event.type === 'delta') {
              assistant.content += event.data.text || ''
              status.value = '正在生成回答'
            }
            if (event.type === 'status') status.value = event.data.text || '正在处理'
            if (event.type === 'cards') assistant.cards = readAiCards(event.data.items)
          }, controller.signal, streamOptions)
        } catch (failure) {
          if (disposed || failure.name === 'AbortError' || stopping.value) return
          if (attempt === 2) throw failure
        }
        if (disposed || stopping.value) return
        const metadata = terminal || (await api.getAiRun(id)).data
        if (metadata?.status && metadata.status !== 'RUNNING') {
          await settleRun(metadata)
          return
        }
        status.value = '连接中断，正在恢复回答'
        await new Promise(resolve => setTimeout(resolve, 500 * (attempt + 1)))
      }
      throw new Error('回答仍在后台处理，请点击“恢复回答”继续接收')
    } catch (failure) {
      if (!disposed) {
        disconnected.value = true
        error.value = failure.message || '实时连接中断，请恢复回答'
      }
    } finally {
      if (!disposed) streaming.value = false
      controller = null
    }
  }

  async function send() {
    const content = draft.value.trim()
    if (!content || locked.value || disposed) return false
    error.value = ''
    let context
    try { context = aiContextPayload(action.value, resume.value, application.value) }
    catch (failure) { error.value = failure.message; return false }
    submitting.value = true
    try {
      if (!sessionId.value) {
        const response = await api.createAiSession()
        if (disposed) return false
        if (!response.data?.id) throw new Error('会话创建失败，请稍后重试')
        sessionId.value = response.data.id
        sessions.value.unshift(response.data)
      }
      const key = JSON.stringify({ sessionId: sessionId.value, content, ...context })
      if (pendingRequest?.key !== key) pendingRequest = { key, requestId: globalThis.crypto.randomUUID() }
      const response = await api.startAiRun(sessionId.value, { requestId: pendingRequest.requestId, content, ...context })
      if (disposed) return false
      if (!response.data?.id) throw new Error('AI 任务创建失败')
      const id = response.data.id
      if (!messages.value.some(item => item.role === 'user' && item.runId === id)) messages.value.push({ role: 'user', content, runId: id, cards: [] })
      draft.value = ''
      action.value = 'chat'
      pendingRequest = null
      cursor = 0
      runId.value = id
      await reconnect()
      return true
    } catch (failure) {
      if (!disposed) error.value = failure.message || '发送失败，可以重试；原问题已保留'
      return false
    } finally {
      if (!disposed) submitting.value = false
    }
  }

  async function stop() {
    if (!runId.value || stopping.value || disposed) return
    stopping.value = true
    error.value = ''
    try {
      await api.cancelAiRun(runId.value)
      if (disposed) return
      controller?.abort()
      await settleRun({ status: 'CANCELLED' })
    } catch (failure) {
      if (!disposed) error.value = failure.message || '停止失败，请重试'
    } finally {
      if (!disposed) stopping.value = false
    }
  }

  async function manageHistory(operation, id, value) {
    if (locked.value || historyLoading.value || disposed) return false
    historySaving.value = true
    historyError.value = ''
    try {
      if (operation === 'rename') {
        const title = String(value || '').trim()
        if (!title || title.length > 80) throw new Error('会话标题需为 1 至 80 字')
        await api.renameAiSession(id, title)
        if (!disposed) sessions.value = sessions.value.map(item => item.id === id ? { ...item, title } : item)
      } else if (operation === 'pin') {
        await api.pinAiSession(id, Boolean(value))
        if (!disposed) sessions.value = sessions.value.map(item => item.id === id ? { ...item, pinned: Boolean(value) } : item)
      } else if (operation === 'delete') {
        await api.deleteAiSession(id)
        if (!disposed) {
          sessions.value = sessions.value.filter(item => item.id !== id)
          if (sessionId.value === id) {
            historySaving.value = false
            newSession()
          }
        }
      } else throw new Error('不支持的历史记录操作')
      return !disposed
    } catch (failure) {
      if (!disposed) historyError.value = failure.message || '历史记录操作失败'
      return false
    } finally {
      if (!disposed) historySaving.value = false
    }
  }

  function selectResume(item) {
    if (locked.value) return
    error.value = ''
    resume.value = item
    application.value = null
    if (action.value === 'interview_preparation') action.value = 'chat'
  }

  async function selectApplication(item) {
    if (locked.value || disposed) return false
    if (!item) {
      application.value = null
      resume.value = null
      error.value = ''
      if (action.value === 'interview_preparation') action.value = 'chat'
      return true
    }
    const epoch = revision
    loading.value = true
    error.value = ''
    try {
      if (!item?.resumeId) throw new Error('该投递缺少关联简历，请选择其他岗位')
      const response = await api.getResumes()
      if (disposed || epoch !== revision) return false
      if (!Array.isArray(response.data)) throw new Error('简历列表读取失败，请稍后重试')
      const selected = response.data.find(entry => String(entry.id) === String(item.resumeId))
      if (!selected) throw new Error('该次投递关联的简历已删除、停用或无法访问，请选择其他投递记录，或单独选择有效简历')
      application.value = item
      resume.value = selected
      return true
    } catch (failure) {
      if (!disposed && epoch === revision) error.value = failure.message || '读取投递简历失败'
      return false
    } finally {
      if (!disposed && epoch === revision) loading.value = false
    }
  }

  function dispose() {
    disposed = true
    revision++
    controller?.abort()
  }

  return { sessions, sortedSessions, sessionId, current, messages, draft, action, resume, application, loading, busy, locked, submitting, streaming, stopping, status, error, historyError, historyLoading, historySaving, historyHasMore, hasOlder, olderLoading, runId, disconnected, initialized, initialize, loadHistory, selectSession, newSession, loadOlder, send, reconnect, stop, manageHistory, selectResume, selectApplication, dispose }
}
