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

export function mergeMessageSnapshot(current, requestedIds, incoming) {
  const requested = new Set(requestedIds.map(String))
  if (!Array.isArray(incoming) || incoming.some(item => !requested.has(String(item.messageId)))) {
    throw new Error('消息状态响应异常，请重试')
  }
  const updated = new Map(incoming.map(item => [String(item.messageId), item]))
  const fields = ['content', 'type', 'attachmentUrl', 'isMine', 'deliveryStatus', 'sendTime', 'isRecalled']
  let changed = false
  const rows = []
  for (const message of current) {
    const id = String(message.messageId)
    if (!requested.has(id)) rows.push(message)
    else {
      const next = updated.get(id)
      if (!next) changed = true
      else if (fields.some(field => next[field] !== message[field])) {
        changed = true
        rows.push({ ...message, ...next })
      } else rows.push(message)
    }
  }
  return changed ? rows : current
}
