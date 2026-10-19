function pad(value) {
  return String(value).padStart(2, '0')
}

function formatDate(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

function parseDate(value) {
  const [year, month, day] = String(value || '').split('-').map(Number)
  if (!year || !month || !day) return new Date()
  return new Date(year, month - 1, day)
}

function withTime(date, time) {
  return `${formatDate(date)} ${time}`
}

function buildItem(appointmentId, date, startTime, endTime, positionTitle, companyName, statusText, mode) {
  return {
    appointmentId,
    sessionId: null,
    roomToken: `mock-room-token-${appointmentId}`,
    positionId: `mock-${appointmentId}`,
    positionTitle,
    companyName,
    startAt: withTime(date, startTime),
    endAt: withTime(date, endTime),
    appointmentStatus: 1,
    sessionStatus: statusText === '已结束' ? 2 : 0,
    mode,
    statusText
  }
}

export function getMockCandidateSchedule(params = {}) {
  const monthStart = parseDate(params.from)
  const today = new Date()
  const isCurrentMonth = monthStart.getFullYear() === today.getFullYear()
    && monthStart.getMonth() === today.getMonth()

  if (isCurrentMonth) {
    const todayDate = new Date(today.getFullYear(), today.getMonth(), today.getDate())
    const yesterday = new Date(todayDate)
    yesterday.setDate(yesterday.getDate() - 2)
    const tomorrow = new Date(todayDate)
    tomorrow.setDate(tomorrow.getDate() + 1)
    const later = new Date(todayDate)
    later.setDate(later.getDate() + 4)

    return [
      buildItem('mock-past', yesterday, '11:00', '11:45', 'Java 后端开发工程师', '星河科技', '已结束', 1),
      buildItem('mock-today', todayDate, '14:30', '15:15', 'AI 产品经理', '云帆智能', '待面试', 1),
      buildItem('mock-tomorrow', tomorrow, '10:00', '11:00', '前端开发工程师', '远见网络', '待面试', 2),
      buildItem('mock-later', later, '16:00', '16:45', '数据分析师', '青禾数据', '待确认', 1)
    ]
  }

  const dates = [5, 12, 18, 25]
  const positions = [
    ['Java 后端开发工程师', '星河科技', '已结束', 1],
    ['AI 产品经理', '云帆智能', '待面试', 1],
    ['前端开发工程师', '远见网络', '待面试', 2],
    ['数据分析师', '青禾数据', '待确认', 1]
  ]

  return dates.map((day, index) => {
    const date = new Date(monthStart.getFullYear(), monthStart.getMonth(), day)
    const item = positions[index]
    return buildItem(
      `mock-${monthStart.getFullYear()}${pad(monthStart.getMonth() + 1)}-${day}`,
      date,
      index % 2 ? '14:00' : '10:30',
      index % 2 ? '14:45' : '11:15',
      item[0],
      item[1],
      item[2],
      item[3]
    )
  })
}
