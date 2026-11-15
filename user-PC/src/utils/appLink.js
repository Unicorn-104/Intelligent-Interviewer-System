// 各端链接的运行时拼接：用户端部署在 /user/ 子路径，企业端在 /enterprise/，端口变化后无需重新打包
const trimTrailing = (url) => String(url || '').replace(/\/+$/, '')

/** 用户端自身地址（包含部署子路径，如 /user/）
 * 本地联调时用 VITE_USER_APP_ORIGIN 指定手机可访问的局域网地址，避免二维码里是本机 localhost */
export function userAppUrl(path = '') {
  const base = import.meta.env.BASE_URL || '/'
  const origin = trimTrailing(import.meta.env.VITE_USER_APP_ORIGIN) || window.location.origin
  return `${origin}${base}${String(path).replace(/^\/+/, '')}`
}

/**
 * 企业端面试间地址。
 * 优先使用构建配置 VITE_ENTERPRISE_APP_URL（本地联调指向独立端口）；
 * 未配置时按当前访问地址同源 + /enterprise 子路径拼接。
 */
export function enterpriseJoinUrl(token) {
  const configured = trimTrailing(import.meta.env.VITE_ENTERPRISE_APP_URL)
  const base = configured || `${window.location.origin}/enterprise`
  return `${base}/conference/join?token=${encodeURIComponent(token)}`
}
