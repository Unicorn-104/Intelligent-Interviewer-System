import { agentPageDefinitions } from '../router/agentPages.js'

const candidatePaths = new Set(agentPageDefinitions.map(([page]) => `/${page}`))
const publicEntryPaths = new Set(['/conference-join', '/exam-sub', '/survey-fill'])
const defaultBase = import.meta.env ? import.meta.env.BASE_URL : '/'

function appBase(base) {
  const path = String(base || '/').split('/').filter(Boolean).join('/')
  return path ? `/${path}/` : '/'
}

export function toAppRoute(target, base = defaultBase, origin = globalThis.location?.origin || 'http://app.local') {
  if (typeof target !== 'string' || !target || /[\u0000-\u001f\u007f\\]/.test(target) || target.startsWith('//')) return null
  try {
    const url = new URL(target, `${origin}/`)
    if (url.origin !== origin || !['http:', 'https:'].includes(url.protocol)) return null
    const prefix = appBase(base)
    let path = url.pathname
    if (prefix !== '/' && path === prefix.slice(0, -1)) path = '/'
    else if (prefix !== '/' && path.startsWith(prefix)) path = `/${path.slice(prefix.length)}`
    if (path === '/agent') path = '/'
    else if (path.startsWith('/agent/')) path = path.slice('/agent'.length)
    return `${path}${url.search}${url.hash}`
  } catch {
    return null
  }
}

export function appHref(target, base = defaultBase) {
  const route = toAppRoute(target, base)
  return route === null ? appBase(base) : `${appBase(base)}${route.slice(1)}`
}

export function isCandidatePath(target, base = defaultBase) {
  const route = toAppRoute(target, base)
  return route !== null && candidatePaths.has(route.split(/[?#]/)[0])
}

export function candidateRedirect(target, base = defaultBase) {
  const route = toAppRoute(target, base)
  const path = route?.split(/[?#]/)[0]
  return path && !['/login', '/register'].includes(path) && (candidatePaths.has(path) || publicEntryPaths.has(path))
    ? route
    : '/index'
}
