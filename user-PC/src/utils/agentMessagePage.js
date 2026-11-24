export function mergeMessagePages(current, incoming) {
  const rows = new Map(current.map(item => [String(item.messageId), item]))
  for (const item of incoming) {
    if (!/^[1-9]\d*$/.test(String(item.messageId))) throw new Error('消息标识无效，请重新加载')
    rows.set(String(item.messageId), { ...rows.get(String(item.messageId)), ...item })
  }
  return [...rows.values()].sort((first, second) => {
    const left = BigInt(first.messageId)
    const right = BigInt(second.messageId)
    return left < right ? -1 : left > right ? 1 : 0
  })
}

export function messagePageData(response) {
  const data = response?.data
  if (!Array.isArray(data?.items) || typeof data.hasMore !== 'boolean') {
    throw new Error('消息分页接口不可用，请同步更新后端后重试')
  }
  if (data.hasMore && !data.items.length) throw new Error('消息分页返回异常，请重试')
  return data
}
