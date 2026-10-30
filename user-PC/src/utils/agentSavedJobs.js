export function normalizeSavedJobIds(values) {
  if (!Array.isArray(values)) return []
  return [...new Set(values.filter(value => ['string', 'number'].includes(typeof value)).map(value => String(value).trim())
    .filter(value => /^\d{1,19}$/.test(value) && BigInt(value) > 0n && BigInt(value) <= 9223372036854775807n)
    .map(value => String(BigInt(value))))]
}

export function sortSavedJobItems(items, sort) {
  return [...items].sort((first, second) => {
    const score = sort === 'salary' ? Number(second.salaryMax ?? -1) - Number(first.salaryMax ?? -1)
      : sort === 'match' ? Number(second.matchScore || 0) - Number(first.matchScore || 0) : 0
    if (score) return score
    const date = String(second.publishedAt || '').localeCompare(String(first.publishedAt || ''))
    if (date) return date
    const firstId = BigInt(first.id)
    const secondId = BigInt(second.id)
    return firstId < secondId ? 1 : firstId > secondId ? -1 : 0
  })
}

export async function loadSavedJobItems(loadJobs, savedIds, filters = {}) {
  const ids = normalizeSavedJobIds(savedIds)
  const items = new Map()
  for (let offset = 0; offset < ids.length; offset += 200) {
    const batch = ids.slice(offset, offset + 200)
    const allowed = new Set(batch)
    let page = 1
    let hasNext = true
    while (hasNext) {
      const response = await loadJobs({ ...filters, jobIds: batch.join(','), page, size: 100 })
      const data = response.data
      if (!Array.isArray(data?.items)) throw new Error('收藏岗位数据暂时无法读取，请重试')
      for (const job of data.items) {
        if (allowed.has(String(job.id))) items.set(String(job.id), job)
      }
      hasNext = data.hasNext === true || Number(data.total) > page * 100
      if (hasNext && !data.items.length) throw new Error('收藏岗位分页数据异常，请重试')
      page++
    }
  }
  return sortSavedJobItems([...items.values()], filters.sort)
}
