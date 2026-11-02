// 后端文件始终通过当前 API 入口访问，兼容旧磁盘路径和新的 RustFS 代理路径。
export function resourcePath(value, apiBase = '', origin = globalThis.location?.origin) {
  const parsed = parseResource(value, origin)
  if (!parsed) return ''
  try {
    const base = new URL(apiBase || '/', origin)
    const basePath = base.pathname.replace(/\/+$/, '')
    for (const prefix of ['/profile/', '/dev-api/profile/', '/prod-api/profile/', `${basePath}/profile/`]) {
      if (parsed.pathname.startsWith(prefix)) return `/profile/${parsed.pathname.slice(prefix.length)}${parsed.search}`
    }
  } catch {}
  return ''
}

export function resolveResourceUrl(value, apiBase, origin = globalThis.location?.origin) {
  const parsed = parseResource(value, origin)
  if (!parsed) return ''
  try {
    const base = new URL(apiBase || '/', origin)
    if (!['http:', 'https:'].includes(base.protocol) || base.username || base.password || base.search || base.hash) return ''
    const profile = resourcePath(value, apiBase, origin)
    if (profile) return `${base.href.replace(/\/+$/, '')}${profile}`
    const raw = String(value).trim()
    if (/^https?:\/\//i.test(raw)) return parsed.href
    if (/^\/(?:[^/]+\/)?(?:assets|static)\//.test(raw) || raw.startsWith('/src/assets/')) return parsed.href
    return new URL(`${base.href.replace(/\/+$/, '')}/${raw.replace(/^\/+/, '')}`, origin).href
  } catch {
    return ''
  }
}

function parseResource(value, origin) {
  const raw = String(value || '').trim()
  if (!raw || raw.startsWith('//') || /[\u0000-\u001f\u007f\\]/.test(raw)) return null
  const path = raw.split(/[?#]/)[0]
  if (/%2e|%2f|%5c/i.test(path) || /\/\.{1,2}(?:\/|$)/.test(path)) return null
  try {
    const parsed = new URL(raw, origin)
    if (!['http:', 'https:'].includes(parsed.protocol) || parsed.username || parsed.password || parsed.hash) return null
    return parsed
  } catch {
    return null
  }
}
