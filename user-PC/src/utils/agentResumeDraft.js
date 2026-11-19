const maxAge = 24 * 60 * 60 * 1000

export function resumeDraftKey(userId, resumeId) {
  if (!/^[1-9]\d*$/.test(String(userId || ''))) return null
  return 'candidate-resume-draft:v1:' + userId + ':' + (resumeId || 'new')
}

export function readResumeDraft(storage, key, now = Date.now()) {
  if (!storage || !key) return null
  try {
    const raw = storage.getItem(key)
    if (!raw) return null
    const draft = JSON.parse(raw)
    if (draft.version !== 1 || !Number.isFinite(draft.savedAt) || now - draft.savedAt > maxAge || draft.savedAt > now || !draft.payload || typeof draft.payload !== 'object' || Array.isArray(draft.payload)) {
      storage.removeItem(key)
      return null
    }
    return draft
  } catch {
    return null
  }
}

export function writeResumeDraft(storage, key, payload, pendingPdf, now = Date.now()) {
  if (!storage || !key) return false
  try {
    storage.setItem(key, JSON.stringify({ version: 1, savedAt: now, payload, pendingPdf: Boolean(pendingPdf) }))
    return true
  } catch {
    return false
  }
}

export function clearResumeDraft(storage, key) {
  try { if (storage && key) storage.removeItem(key) } catch {}
}
