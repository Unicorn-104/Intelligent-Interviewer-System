const CANDIDATE_SESSION_KEY = 'candidateSession'

function getStorage() {
  if (typeof window === 'undefined') return null
  return window.localStorage
}

export function getCandidateSession() {
  const storage = getStorage()
  if (!storage) return null

  try {
    const session = JSON.parse(storage.getItem(CANDIDATE_SESSION_KEY) || 'null')
    return session && typeof session === 'object' ? session : null
  } catch {
    return null
  }
}

export function setCandidateSession(session) {
  const storage = getStorage()
  if (!storage) return
  storage.setItem(CANDIDATE_SESSION_KEY, JSON.stringify(session))
}

export function clearCandidateSession() {
  const storage = getStorage()
  if (!storage) return
  storage.removeItem(CANDIDATE_SESSION_KEY)
}

/**
 * 生产环境只认可后端签发的 accessToken。
 * 演示环境由 VITE_FRONTEND_ONLY 路由分支直接放行，因此不会依赖本函数。
 */
export function hasCandidateAccessToken() {
  return Boolean(getCandidateSession()?.accessToken)
}
