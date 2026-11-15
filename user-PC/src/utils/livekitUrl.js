// HTTPS 页面不能直连 ws:// （混合内容会被浏览器拦截），
// 统一改走同源 wss，由 Vite 的 /livekit 代理转发到 LiveKit 信令端口。
export function resolveLivekitUrl(url) {
  if (!url || location.protocol !== 'https:') return url
  return url.startsWith('ws://') ? `wss://${location.host}/livekit` : url
}
