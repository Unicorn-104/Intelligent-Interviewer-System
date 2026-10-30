export function unreadCount(value) {
  const count = Number(value)
  return Number.isSafeInteger(count) && count > 0 ? count : 0
}

export function unreadBadge(value) {
  const count = unreadCount(value)
  return count > 99 ? '99+' : count ? String(count) : ''
}

export function createUnreadCounter(loaders, onChange) {
  const counts = loaders.map(() => 0)
  let revision = 0
  let stopped = false

  return {
    async refresh() {
      if (stopped) return
      const currentRevision = ++revision
      const results = await Promise.allSettled(loaders.map(loader => Promise.resolve().then(loader)))
      if (stopped || currentRevision !== revision) return
      results.forEach((result, index) => {
        if (result.status === 'fulfilled') counts[index] = unreadCount(result.value)
      })
      onChange(counts.reduce((total, count) => total + count, 0))
    },
    stop() {
      stopped = true
      revision++
    }
  }
}
