const personalFields = ['realName', 'gender', 'workStatus', 'currentCity', 'phone', 'email', 'jobDirection', 'targetRole', 'salaryExpectation', 'targetCity', 'arrivalTime']
export const resumeSections = ['educations', 'works', 'projects', 'skills']

const text = value => value == null ? '' : String(value).trim()

export function profileResumeDefaults(profile = {}) {
  return {
    realName: text(profile.realName),
    gender: ({ '0': '男', '1': '女' })[text(profile.sex)] || '',
    workStatus: ({ '1': '在职-考虑机会', '2': '离职-随时到岗', '3': '在校-寻找实习' })[text(profile.currentStatus)] || '',
    currentCity: text(profile.currentCity),
    phone: text(profile.phonenumber),
    email: text(profile.email),
    jobDirection: text(profile.targetDirection),
    targetRole: text(profile.targetDirection),
    targetCity: text(profile.targetCity)
  }
}

export function mergeParsedResume(current = {}, parsed = {}) {
  const result = { ...current }
  for (const field of personalFields) result[field] = text(current[field]) || text(parsed[field])
  for (const field of resumeSections) {
    result[field] = Array.isArray(parsed[field]) && parsed[field].length
      ? parsed[field].map(item => ({ ...item }))
      : Array.isArray(current[field]) ? current[field] : []
  }
  result.parseWarnings = Array.isArray(parsed.parseWarnings) ? parsed.parseWarnings : []
  result.unmappedText = text(parsed.unmappedText)
  result.parseMethod = text(parsed.parseMethod)
  result.structureMethod = text(parsed.structureMethod)
  result.resumeName = text(current.resumeName) || text(parsed.resumeName)
  return result
}

export function resumeDate(value) {
  const match = text(value).match(/^(\d{4})[-/.年](\d{1,2})(?:[-/.月](\d{1,2})日?)?(?:月|(?:T|\s).*)?$/)
  if (!match) return ''
  const year = Number(match[1])
  const month = Number(match[2])
  const day = Number(match[3] || 1)
  const date = new Date(Date.UTC(year, month - 1, day))
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return ''
  return `${match[1]}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
}

export function resumeDegree(value) {
  const degree = Number(value)
  return [1, 2, 3, 4, 5].includes(degree) ? degree : null
}
