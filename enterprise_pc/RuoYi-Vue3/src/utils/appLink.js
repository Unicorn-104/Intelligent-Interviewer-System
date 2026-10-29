// 各端链接的运行时拼接：避免部署端口/域名变化后构建产物里的地址失效
const trimTrailing = (url) => String(url || '').replace(/\/+$/, '')

/**
 * 候选人（用户端）基址。
 * 优先使用构建配置 VITE_CANDIDATE_APP_URL（本地联调指向独立端口）；
 * 未配置时按当前访问地址同源 + /user 子路径拼接，部署到任意域名/端口都无需重新打包。
 */
export function candidateAppBase() {
  const configured = trimTrailing(import.meta.env.VITE_CANDIDATE_APP_URL)
  return configured || `${window.location.origin}/user`
}

export function candidateAppUrl(path = '') {
  return `${candidateAppBase()}/${String(path).replace(/^\/+/, '')}`
}
