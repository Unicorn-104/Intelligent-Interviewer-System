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
    if (!session || typeof session !== 'object') return null
    if (session.expiresAt && Date.now() > Number(session.expiresAt)) {
      clearCandidateSession()
      return null
    }
    return session
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

export function hasCandidateAccessToken() {
  return Boolean(getCandidateSession()?.accessToken)
}
