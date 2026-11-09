export function candidateAuthError(error, fallback = '登录失败，请稍后重试') {
  const message = typeof error === 'string' ? error : String(error?.message || '')
  if (['ECONNABORTED', 'ETIMEDOUT'].includes(error?.code) || /timeout|timed out/i.test(message)) {
    return '请求超时，请检查网络，或联系管理员确认后端及数据库连接正常后再试'
  }
  if (error?.code === 'ERR_NETWORK' || /network error|failed to fetch/i.test(message)) {
    return '无法连接登录服务，请检查网络和后端服务是否正常运行'
  }
  if ([502, 503, 504].includes(error?.response?.status)) {
    return '登录服务暂不可用，请稍后重试或联系管理员'
  }
  return message || fallback
}
