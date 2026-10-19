<template>
<div class="app-shell">
    <AgentTopbar active="index" />

    <main class="main-content" id="dashboard">
      <section class="welcome-row" aria-labelledby="pageTitle">
        <div>
          <p class="eyebrow">{{ todayLabel }}</p>
          <h1 id="pageTitle">{{ greeting }}，{{ displayName }}</h1>
          <p class="welcome-subtitle">岗位数据来自企业端已发布且正在招聘的真实岗位。</p>
        </div>
        <div class="search-box">
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.8" /><path d="m16 16 4.3 4.3" /></svg>
          <input v-model.trim="keyword" id="jobSearch" type="search" placeholder="搜索职位、公司或关键词" aria-label="搜索职位、公司或关键词" @keyup.enter="loadJobs" />
          <button v-if="keyword" class="search-clear visible" id="searchClear" type="button" aria-label="清除搜索" @click="clearSearch">×</button>
        </div>
      </section>

      <section class="dashboard-grid" aria-label="工作台摘要">
        <article class="panel application-panel" id="applications">
          <div class="panel-header">
            <div><h2 class="panel-title">我的投递进度摘要</h2><p class="panel-caption">持续跟进每一个值得期待的机会</p></div>
            <button class="text-button" id="viewAllApplications" type="button" @click="openApplications">查看全部 →</button>
          </div>
          <div v-if="applicationLoading" class="dashboard-state">正在读取真实投递数据...</div>
          <div v-else-if="applicationError" class="dashboard-state error-state">
            <span>{{ applicationError }}</span>
            <button class="text-button" type="button" @click="loadApplications">重新加载</button>
          </div>
          <template v-else>
            <div class="application-overview">
              <div class="progress-ring" :aria-label="`进行中的投递 ${inProgressApplicationCount} 个`">
                <svg viewBox="0 0 92 92" aria-hidden="true"><circle class="track" cx="46" cy="46" r="34" /><circle class="value" cx="46" cy="46" r="34" :style="{ strokeDashoffset: progressRingOffset }" /></svg>
                <div class="progress-ring-label">{{ inProgressApplicationCount }}<small>进行中</small></div>
              </div>
              <div class="stat-copy">
                <strong>{{ applicationTotal }} 个投递</strong>
                <span>数据来自当前账号的真实投递记录</span>
                <div class="stat-chips"><span class="stat-chip"><strong>{{ interviewApplicationCount }}</strong>面试中</span><span class="stat-chip"><strong>{{ activeApplicationCount }}</strong>待反馈</span><span class="stat-chip"><strong>{{ closedApplicationCount }}</strong>已结束</span></div>
              </div>
            </div>
            <div v-if="latestApplication" class="latest-application">
              <p class="latest-label">最新进展</p>
              <div class="latest-main">
                <div class="company-logo" :class="companyLogoClass(latestApplication.companyName)">{{ companyMark(latestApplication.companyName) }}</div>
                <div class="job-basic"><div class="job-title">{{ latestApplication.jobTitle }}</div><div class="job-company">{{ latestApplication.companyName }} · {{ latestApplication.locationText || '地点待定' }}</div></div>
                <span class="status-pill" :class="applicationStatusClass(latestApplication.status)">{{ latestApplication.statusText || '投递处理中' }}</span>
              </div>
              <div class="latest-footer"><span class="time-note">更新于 {{ formatApplicationTime(latestApplication.updatedAt || latestApplication.appliedAt) }}</span><button class="outline-button" type="button" @click="openApplication(latestApplication)">查看详情</button></div>
            </div>
            <div v-else class="latest-application dashboard-empty">暂无投递记录，去岗位浏览看看新的机会吧。</div>
          </template>
        </article>

        <article class="panel activity-panel">
          <div class="panel-header"><div><h2 class="panel-title">系统通知与平台动态</h2><p class="panel-caption">来自后端通知中心的最新消息</p></div><button class="text-button" type="button" @click="openMessages">查看全部 →</button></div>
          <div v-if="noticesLoading" class="dashboard-state">正在读取真实通知...</div>
          <div v-else-if="noticesError" class="dashboard-state error-state"><span>通知暂时无法读取</span><button class="text-button" type="button" @click="loadNotices">重新加载</button></div>
          <ul v-else-if="noticeItems.length" class="activity-list">
            <li v-for="item in noticeItems" :key="item.noticeId" class="activity-item" :class="{ 'activity-unread': !item.isRead }" role="button" tabindex="0" @click="openNotice(item)" @keydown.enter="openNotice(item)" @keydown.space.prevent="openNotice(item)"><span class="activity-dot"></span><div class="activity-body"><div class="activity-company">{{ item.noticeTitle || '系统通知' }} <span>{{ item.noticeType === '1' ? '通知' : '公告' }}</span></div><p class="activity-content">{{ noticePreview(item.noticeContent) || '暂无通知内容' }}</p><div class="activity-time">{{ formatRelativeTime(item.createTime) }}</div></div></li>
          </ul>
          <div v-else class="dashboard-state">暂无系统通知</div>
        </article>
      </section>

      <section class="jobs-section" id="jobs" aria-labelledby="jobsHeading">
        <div class="section-heading">
          <div><h2 id="jobsHeading">为你推荐的岗位</h2><p>基于你的经历、偏好与近期浏览行为智能匹配</p></div>
          <div class="jobs-controls"><select v-model="sort" class="filter-select" id="jobFilter" aria-label="岗位排序" @change="loadJobs"><option value="match">按匹配度排序</option><option value="salary">按薪资排序</option><option value="latest">按最新发布排序</option></select><button class="text-button" type="button" :disabled="loading" @click="loadJobs">刷新岗位 ↻</button></div>
        </div>

        <div class="jobs-grid" id="jobsGrid">




          <div v-if="loading" class="empty-state visible">正在读取企业发布的岗位...</div>
          <div v-else-if="errorMessage" class="empty-state visible">{{ errorMessage }}<button class="text-button" type="button" @click="loadJobs">重新加载</button></div>
          <template v-else-if="jobs.length">
            <article v-for="job in jobs" :key="job.id" class="job-card" tabindex="0" role="link" :aria-label="`查看${job.title}详情`" @click="openJob(job.id)" @keydown.enter="openJob(job.id)" @keydown.space.prevent="openJob(job.id)">
              <div class="job-card-top"><div class="company-logo" :class="companyLogoClass(job.companyName)">{{ companyMark(job.companyName) }}</div><button class="bookmark-button" :class="{ saved: isSaved(job.id) }" type="button" :aria-label="isSaved(job.id) ? `取消收藏${job.title}岗位` : `收藏${job.title}岗位`" title="收藏岗位" @click.stop="toggleSaved(job.id)"><svg viewBox="0 0 24 24"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg></button></div>
              <h3>{{ job.title }}</h3><div class="job-card-company">{{ job.companyName }} · {{ job.workCity || '地点不限' }}</div>
              <div class="job-card-meta"><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>{{ job.experienceRequired || '经验不限' }}</span><span class="meta-item"><svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16" /></svg>{{ job.educationText }}</span></div>
              <div class="job-card-tags"><span class="match-tag">{{ job.matchScore != null ? `${job.matchScore}%匹配` : job.statusText }}</span><span v-if="job.skills?.[0]" class="job-tag">{{ job.skills[0] }}</span><span v-if="job.jobTypeText" class="job-tag">{{ job.jobTypeText }}</span></div><div class="job-card-footer"><span class="salary">{{ job.salaryText }}</span><button class="apply-button" type="button" @click.stop="applyJob(job)">{{ job.appliedFlag ? '查看投递' : '立即投递' }}</button></div>
            </article>
          </template>
          <div v-else class="empty-state visible">当前暂无企业发布的在招岗位。</div>
        </div>
      </section>

      <section class="schedule-section" aria-labelledby="scheduleHeading">
        <article class="panel schedule-panel">
          <div class="schedule-header">
            <div>
              <h2 id="scheduleHeading" class="panel-title">面试安排</h2>
              <div class="schedule-caption">
                <p class="panel-caption">查看即将开始的面试与会议时间</p>
              </div>
            </div>
            <div class="schedule-toolbar">
              <div class="calendar-switcher" aria-label="切换面试月份">
                <button class="calendar-nav" type="button" title="上个月" aria-label="上个月" @click="changeMonth(-1)">‹</button>
                <strong>{{ scheduleMonthLabel }}</strong>
                <button class="calendar-nav" type="button" title="下个月" aria-label="下个月" @click="changeMonth(1)">›</button>
              </div>
              <button class="today-button" type="button" @click="goToToday">回到今天</button>
            </div>
          </div>

          <div class="schedule-layout">
            <div class="calendar-area">
              <div class="weekday-row" aria-hidden="true">
                <span v-for="weekday in weekdayLabels" :key="weekday">{{ weekday }}</span>
              </div>
              <div class="calendar-grid">
                <button
                  v-for="cell in calendarCells"
                  :key="cell.dateKey"
                  class="calendar-day"
                  :class="{ outside: !cell.inCurrentMonth, today: cell.isToday, selected: cell.dateKey === selectedDate, 'has-event': cell.items.length }"
                  type="button"
                  :aria-label="cellAriaLabel(cell)"
                  @click="selectCalendarDate(cell)"
                >
                  <span class="day-number">{{ cell.day }}</span>
                  <span v-if="cell.items.length" class="day-events"><i aria-hidden="true"></i><b>{{ cell.items.length }}</b></span>
                </button>
              </div>
              <div class="calendar-legend" aria-label="日历标记说明">
                <span><i class="legend-dot"></i>有面试</span>
                <span><i class="legend-today"></i>今天</span>
              </div>
            </div>

            <aside class="schedule-details" aria-live="polite">
              <div class="details-heading">
                <div><span class="details-kicker">SELECTED DATE</span><h3>{{ selectedDateLabel }}</h3></div>
                <span v-if="scheduleLoading" class="loading-label">读取中...</span>
              </div>
              <div v-if="scheduleError" class="schedule-state error-state">
                <strong>面试安排加载失败</strong>
                <span>{{ scheduleError }}</span>
                <button class="outline-button" type="button" @click="loadSchedule()">重新加载</button>
              </div>
              <div v-else-if="scheduleLoading" class="schedule-state">正在读取真实面试安排...</div>
              <div v-else-if="selectedItems.length" class="schedule-list">
                <article v-for="item in selectedItems" :key="`${item.appointmentId}-${item.sessionId || 'appointment'}`" class="schedule-item">
                  <div class="schedule-item-time"><strong>{{ formatScheduleTime(item.startAt) }}</strong><span>{{ formatScheduleTime(item.endAt) }} 结束</span></div>
                  <div class="schedule-item-copy">
                    <h4>{{ item.positionTitle || '面试岗位' }}</h4>
                    <p>{{ item.companyName || '企业信息待补充' }}</p>
                    <div class="schedule-item-meta"><span class="schedule-status" :class="scheduleStatusClass(item)">{{ item.statusText || '待面试' }}</span><span>{{ Number(item.mode) === 2 ? 'AI + HR 协同' : '线上面试' }}</span></div>
                  </div>
                  <div class="schedule-item-actions">
                    <button v-if="hasInterviewLink(item)" class="schedule-link" type="button" @click="openInterviewLink(item)">查看面试链接 <span aria-hidden="true">→</span></button>
                    <span v-else class="schedule-link unavailable">等待企业发送链接</span>
                    <button v-if="item.sessionId && !String(item.sessionId).startsWith('mock-')" class="schedule-link secondary" type="button" @click="openSchedule(item)">进入准备 <span aria-hidden="true">→</span></button>
                  </div>
                </article>
              </div>
              <div v-else class="schedule-state empty-schedule">
                <span class="empty-calendar-icon" aria-hidden="true">◷</span>
                <strong>当天暂无面试安排</strong>
                <span>有新的面试邀约后，会自动显示在这里。</span>
              </div>
            </aside>
          </div>
        </article>
      </section>
    </main>
  </div>

  <div v-if="linkDialogVisible" class="schedule-modal-backdrop" role="presentation" @click.self="closeInterviewLink">
    <section class="schedule-modal" role="dialog" aria-modal="true" aria-labelledby="scheduleLinkTitle">
      <button class="schedule-modal-close" type="button" aria-label="关闭面试链接弹窗" title="关闭" @click="closeInterviewLink">×</button>
      <span class="details-kicker">INTERVIEW LINK</span>
      <h2 id="scheduleLinkTitle">企业面试链接</h2>
      <p class="schedule-modal-summary">{{ linkDialogItem?.companyName || '企业' }} · {{ linkDialogItem?.positionTitle || '岗位面试' }}</p>
      <div class="schedule-modal-info">
        <span>面试时间</span>
        <strong>{{ formatScheduleDateTime(linkDialogItem?.startAt, linkDialogItem?.endAt) }}</strong>
      </div>
      <label class="schedule-link-field">
        <span>专属面试入口</span>
        <input :value="interviewLink" type="text" readonly aria-label="专属面试入口" @focus="$event.target.select()" />
      </label>
      <p v-if="linkDialogItem?.statusText === '已结束'" class="schedule-modal-tip expired">本场面试已结束，该链接已不能进入会议。</p>
      <p v-else-if="isMockScheduleItem(linkDialogItem)" class="schedule-modal-tip">当前为演示链接，仅用于查看格式；真实面试链接会由企业端发送。</p>
      <p v-else class="schedule-modal-tip">请使用此链接进入面试准备页，建议提前 10 分钟打开。</p>
      <div class="schedule-modal-actions">
        <button class="outline-button" type="button" @click="copyInterviewLink">{{ copiedLink ? '已复制' : '复制链接' }}</button>
        <button class="primary-button" type="button" :disabled="linkDialogItem?.statusText === '已结束' || isMockScheduleItem(linkDialogItem)" @click="visitInterviewLink">打开面试</button>
      </div>
    </section>
  </div>

  <div class="toast" :class="{ show: toastVisible }" role="status"><span>✓</span><span>{{ toastMessage }}</span></div>
</template>

<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { listJobs } from '@/api/agent/job'
import { listApplications } from '@/api/agent/application'
import { listCandidateSchedule } from '@/api/system/conference'
import { listNoticeTop, markNoticeRead } from '@/api/system/notice'
import useUserStore from '@/store/modules/user'

const userStore = useUserStore()
const jobs = ref([])
const keyword = ref('')
const sort = ref('match')
const loading = ref(false)
const errorMessage = ref('')
const applications = ref([])
const applicationLoading = ref(false)
const applicationError = ref('')
const noticeItems = ref([])
const noticesLoading = ref(false)
const noticesError = ref(false)
const savedJobs = ref(new Set(readSavedJobs()))
const toastVisible = ref(false)
const toastMessage = ref('')
const weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
const todayKey = ref(formatDateKey(new Date()))
const calendarDate = ref(startOfMonth(new Date()))
const selectedDate = ref(todayKey.value)
const scheduleItems = ref([])
const scheduleLoading = ref(false)
const scheduleError = ref('')
const linkDialogVisible = ref(false)
const linkDialogItem = ref(null)
const interviewLink = ref('')
const copiedLink = ref(false)
let toastTimer
let todayTimer

const displayName = computed(() => userStore.nickName || userStore.name || '求职者')
const greeting = computed(() => {
  const hour = new Date().getHours()
  if (hour < 6) return '晚上好'
  if (hour < 12) return '早上好'
  if (hour < 18) return '下午好'
  return '晚上好'
})
const todayLabel = computed(() => {
  const date = new Date()
  const weekdays = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY']
  return `${weekdays[date.getDay()]} · ${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`
})
const applicationTotal = computed(() => applications.value.length)
const activeApplicationCount = computed(() => applications.value.filter(item => item.status === 'active').length)
const interviewApplicationCount = computed(() => applications.value.filter(item => item.status === 'interview').length)
const closedApplicationCount = computed(() => applications.value.filter(item => item.status === 'closed').length)
const inProgressApplicationCount = computed(() => activeApplicationCount.value + interviewApplicationCount.value)
const latestApplication = computed(() => applications.value[0] || null)
const progressRingOffset = computed(() => {
  const circumference = 2 * Math.PI * 34
  const progress = applicationTotal.value ? inProgressApplicationCount.value / applicationTotal.value : 0
  return (circumference * (1 - Math.min(progress, 1))).toFixed(2)
})

const scheduleMonthLabel = computed(() => {
  const date = calendarDate.value
  return `${date.getFullYear()}年${date.getMonth() + 1}月`
})

const scheduleByDate = computed(() => {
  const grouped = {}
  scheduleItems.value.forEach((item) => {
    const dateKey = String(item.startAt || '').slice(0, 10)
    if (!dateKey) return
    if (!grouped[dateKey]) grouped[dateKey] = []
    grouped[dateKey].push(item)
  })
  return grouped
})

const calendarCells = computed(() => {
  const monthStart = startOfMonth(calendarDate.value)
  const leadingDays = (monthStart.getDay() + 6) % 7
  const daysInMonth = new Date(monthStart.getFullYear(), monthStart.getMonth() + 1, 0).getDate()
  const cellCount = Math.ceil((leadingDays + daysInMonth) / 7) * 7
  const firstCell = new Date(monthStart)
  firstCell.setDate(firstCell.getDate() - leadingDays)
  return Array.from({ length: cellCount }, (_, index) => {
    const date = new Date(firstCell)
    date.setDate(firstCell.getDate() + index)
    const dateKey = formatDateKey(date)
    return {
      dateKey,
      day: date.getDate(),
      inCurrentMonth: date.getMonth() === monthStart.getMonth(),
      isToday: dateKey === todayKey.value,
      items: scheduleByDate.value[dateKey] || []
    }
  })
})

const selectedItems = computed(() => scheduleByDate.value[selectedDate.value] || [])
const selectedDateLabel = computed(() => formatChineseDate(selectedDate.value))

async function loadJobs() {
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await listJobs({ keyword: keyword.value || undefined, sort: sort.value, page: 1, size: 6 })
    jobs.value = response.data?.items || []
  } catch (error) {
    jobs.value = []
    errorMessage.value = error?.message || '岗位数据暂时无法读取，请稍后重试'
  } finally {
    loading.value = false
  }
}

async function loadApplications() {
  applicationLoading.value = true
  applicationError.value = ''
  try {
    const response = await listApplications({ page: 1, size: 100 })
    applications.value = Array.isArray(response.data?.items) ? response.data.items : []
  } catch (error) {
    applications.value = []
    applicationError.value = error?.message || '投递数据暂时无法读取，请稍后重试'
  } finally {
    applicationLoading.value = false
  }
}

async function loadNotices() {
  noticesLoading.value = true
  noticesError.value = false
  try {
    const response = await listNoticeTop({ limit: 3 })
    noticeItems.value = Array.isArray(response.data) ? response.data : []
  } catch {
    noticeItems.value = []
    noticesError.value = true
  } finally {
    noticesLoading.value = false
  }
}

async function loadSchedule() {
  scheduleLoading.value = true
  scheduleError.value = ''
  const monthStart = startOfMonth(calendarDate.value)
  const nextMonth = new Date(monthStart.getFullYear(), monthStart.getMonth() + 1, 1)
  const from = formatDateKey(monthStart)
  const to = formatDateKey(nextMonth)
  try {
    const response = await listCandidateSchedule({ from, to })
    const data = Array.isArray(response.data) ? response.data : []
    scheduleItems.value = data
  } catch (error) {
    scheduleItems.value = []
    scheduleError.value = error?.message || '面试安排暂时无法读取，请稍后重试'
  } finally {
    scheduleLoading.value = false
  }
}

function changeMonth(offset) {
  const current = calendarDate.value
  calendarDate.value = new Date(current.getFullYear(), current.getMonth() + offset, 1)
  selectedDate.value = formatDateKey(calendarDate.value)
  loadSchedule()
}

function goToToday() {
  const today = new Date()
  todayKey.value = formatDateKey(today)
  calendarDate.value = startOfMonth(today)
  selectedDate.value = todayKey.value
  loadSchedule()
}

function selectCalendarDate(cell) {
  if (!cell.inCurrentMonth) {
    const date = dateFromKey(cell.dateKey)
    calendarDate.value = startOfMonth(date)
    selectedDate.value = cell.dateKey
    loadSchedule()
    return
  }
  selectedDate.value = cell.dateKey
}

function cellAriaLabel(cell) {
  return `${formatChineseDate(cell.dateKey)}${cell.items.length ? `，${cell.items.length} 场面试` : '，暂无面试'}`
}

function formatScheduleTime(value) {
  const text = String(value || '')
  return text.includes(' ') ? text.split(' ')[1] : text || '--:--'
}

function formatScheduleDateTime(startAt, endAt) {
  const start = String(startAt || '')
  const end = String(endAt || '')
  if (!start) return '时间待定'
  const date = start.split(' ')[0]
  const startTime = formatScheduleTime(start)
  const endTime = end ? formatScheduleTime(end) : ''
  return `${date} ${startTime}${endTime ? ` - ${endTime}` : ''}`
}

function getInterviewLink(item) {
  if (item?.interviewLink) return item.interviewLink
  if (!item?.roomToken) return ''
  return `${window.location.origin}/conference-join?token=${encodeURIComponent(item.roomToken)}`
}

function hasInterviewLink(item) {
  return Boolean(getInterviewLink(item))
}

function isMockScheduleItem(item) {
  return String(item?.appointmentId || '').startsWith('mock-')
}

function openInterviewLink(item) {
  const link = getInterviewLink(item)
  if (!link) {
    showToast('企业尚未发送面试链接')
    return
  }
  linkDialogItem.value = item
  interviewLink.value = link
  copiedLink.value = false
  linkDialogVisible.value = true
}

function closeInterviewLink() {
  linkDialogVisible.value = false
  linkDialogItem.value = null
  interviewLink.value = ''
  copiedLink.value = false
}

async function copyInterviewLink() {
  if (!interviewLink.value) return
  try {
    await navigator.clipboard.writeText(interviewLink.value)
  } catch {
    const input = document.createElement('textarea')
    input.value = interviewLink.value
    input.setAttribute('readonly', '')
    input.style.position = 'fixed'
    input.style.opacity = '0'
    document.body.appendChild(input)
    input.select()
    document.execCommand('copy')
    input.remove()
  }
  copiedLink.value = true
  showToast('面试链接已复制')
}

function visitInterviewLink() {
  if (!interviewLink.value || linkDialogItem.value?.statusText === '已结束' || isMockScheduleItem(linkDialogItem.value)) return
  window.open(interviewLink.value, '_blank', 'noopener,noreferrer')
}

function scheduleStatusClass(item) {
  const status = item.statusText || ''
  if (status === '进行中') return 'in-progress'
  if (status === '已结束') return 'finished'
  return 'upcoming'
}

function openSchedule(item) {
  window.__agentNavigate(`/agent/conference-prep?sessionId=${encodeURIComponent(item.sessionId)}`)
}

function startOfMonth(date) {
  return new Date(date.getFullYear(), date.getMonth(), 1)
}

function formatDateKey(date) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function dateFromKey(value) {
  const [year, month, day] = String(value).split('-').map(Number)
  return new Date(year, month - 1, day)
}

function formatChineseDate(value) {
  const date = dateFromKey(value)
  const weekday = weekdayLabels[(date.getDay() + 6) % 7]
  return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日 ${weekday}`
}

function clearSearch() {
  keyword.value = ''
  loadJobs()
}

function readSavedJobs() {
  try {
    const saved = JSON.parse(localStorage.getItem('zhipin-ai-saved-jobs') || '[]')
    return Array.isArray(saved) ? saved.map(String) : []
  } catch {
    return []
  }
}

function isSaved(id) {
  return savedJobs.value.has(String(id))
}

function toggleSaved(id) {
  const next = new Set(savedJobs.value)
  const key = String(id)
  if (next.has(key)) {
    next.delete(key)
    showToast('已取消收藏')
  } else {
    next.add(key)
    showToast('已收藏该岗位')
  }
  savedJobs.value = next
  localStorage.setItem('zhipin-ai-saved-jobs', JSON.stringify([...next]))
}

function openJob(id) {
  window.__agentNavigate(`/agent/job-detail?id=${encodeURIComponent(id)}`)
}

function applyJob(job) {
  if (job.appliedFlag && job.applicationId) {
    window.__agentNavigate(`/agent/application-detail?id=${encodeURIComponent(job.applicationId)}`)
  } else {
    window.__agentNavigate(`/agent/resume-select?job=${encodeURIComponent(job.id)}`)
  }
}

function openApplications() {
  window.__agentNavigate('/agent/applications')
}

function openMessages() {
  window.__agentNavigate('/agent/messages?view=system')
}

function openApplication(application) {
  window.__agentNavigate(`/agent/application-detail?id=${encodeURIComponent(application.id)}`)
}

async function openNotice(notice) {
  if (!notice.isRead) {
    try {
      await markNoticeRead(notice.noticeId)
      notice.isRead = true
      window.dispatchEvent(new CustomEvent('agent-notifications-updated'))
    } catch {
      // 通知打开失败时仍允许进入消息中心查看详情。
    }
  }
  window.__agentNavigate(`/agent/messages?view=system#notice-${encodeURIComponent(notice.noticeId)}`)
}

function plainText(value) {
  if (!value) return ''
  const holder = document.createElement('div')
  holder.innerHTML = value
  return (holder.textContent || holder.innerText || '').replace(/\s+/g, ' ').trim()
}

function noticePreview(value) {
  const content = plainText(value)
  return content.length > 120 ? `${content.slice(0, 120)}…` : content
}

function formatRelativeTime(value) {
  const date = parseDate(value)
  if (!date) return '--'
  const seconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000))
  if (seconds < 60) return '刚刚'
  if (seconds < 3600) return `${Math.floor(seconds / 60)} 分钟前`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)} 小时前`
  if (seconds < 604800) return `${Math.floor(seconds / 86400)} 天前`
  return `${date.getMonth() + 1}月${date.getDate()}日`
}

function parseDate(value) {
  if (!value) return null
  const date = new Date(String(value).includes(' ') ? String(value).replace(' ', 'T') : value)
  return Number.isNaN(date.getTime()) ? null : date
}

function formatApplicationTime(value) {
  return value ? String(value).replace('T', ' ').slice(0, 16) : '刚刚'
}

function applicationStatusClass(status) {
  if (status === 'interview') return 'green'
  if (status === 'closed') return 'red'
  return 'orange'
}

function companyMark(name) {
  return (name || '企业').slice(0, 2)
}

function companyLogoClass(name) {
  return ['orange', 'green'][String(name || '').length % 2]
}

function showToast(message) {
  toastMessage.value = message
  toastVisible.value = true
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { toastVisible.value = false }, 2600)
}

onMounted(() => {
  loadJobs()
  loadApplications()
  loadNotices()
  loadSchedule()
  todayTimer = window.setInterval(() => {
    const nextTodayKey = formatDateKey(new Date())
    if (nextTodayKey !== todayKey.value) {
      todayKey.value = nextTodayKey
      if (calendarDate.value.getMonth() === new Date().getMonth()
        && calendarDate.value.getFullYear() === new Date().getFullYear()) {
        selectedDate.value = nextTodayKey
      }
    }
  }, 60 * 1000)
})

onUnmounted(() => {
  window.clearInterval(todayTimer)
})

</script>

<style>
:root {
      --primary: #1A3C6E;
      --primary-deep: #102D53;
      --interactive: #2B7FFF;
      --interactive-soft: #EAF2FF;
      --bg: #F5F7FA;
      --card: #FFFFFF;
      --text: #172B4D;
      --muted: #6B7A90;
      --line: #E6EBF2;
      --success: #1B9A72;
      --success-soft: #E7F7F1;
      --warning: #D7811D;
      --warning-soft: #FFF4E5;
      --shadow: 0 8px 24px rgba(26, 60, 110, 0.07);
      --radius: 12px;
    }

    * { box-sizing: border-box; }

    html { scroll-behavior: smooth; }

    body {
      margin: 0;
      color: var(--text);
      background: var(--bg);
      font-family: "PingFang SC", "Microsoft YaHei", system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 14px;
      line-height: 1.5;
    }

    button, input { font: inherit; }

    button { cursor: pointer; }

    .app-shell { min-height: 100vh; }

    /* 顶部导航栏 */
    .topbar {
      position: sticky;
      top: 0;
      z-index: 20;
      height: 72px;
      display: flex;
      align-items: center;
      border-bottom: 1px solid rgba(230, 235, 242, 0.9);
      background: rgba(255, 255, 255, 0.96);
      backdrop-filter: blur(12px);
    }

    .topbar-inner {
      width: min(1240px, calc(100% - 48px));
      margin: 0 auto;
      display: flex;
      align-items: center;
      gap: 32px;
    }

    .brand {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      color: var(--primary);
      text-decoration: none;
      white-space: nowrap;
    }

    .brand-mark {
      width: 34px;
      height: 34px;
      display: grid;
      place-items: center;
      border-radius: 9px;
      color: #fff;
      background: linear-gradient(145deg, #2B7FFF, #1A3C6E);
      box-shadow: 0 5px 12px rgba(43, 127, 255, 0.22);
      font-size: 17px;
      font-weight: 800;
      letter-spacing: -1px;
    }

    .brand-name { font-weight: 800; font-size: 18px; letter-spacing: 0.2px; }
    .brand-tag { margin-left: 2px; color: var(--muted); font-size: 11px; font-weight: 500; }

    .main-nav { display: flex; align-items: center; gap: 5px; height: 100%; }

    .nav-link {
      position: relative;
      height: 72px;
      display: inline-flex;
      align-items: center;
      padding: 0 15px;
      border: 0;
      color: var(--muted);
      background: transparent;
      font-size: 14px;
      text-decoration: none;
      transition: color .2s ease;
    }

    .nav-link:hover, .nav-link.active { color: var(--primary); }
    .nav-link.active { font-weight: 700; }
    .nav-link.active::after {
      content: "";
      position: absolute;
      right: 15px;
      bottom: 0;
      left: 15px;
      height: 3px;
      border-radius: 3px 3px 0 0;
      background: var(--interactive);
    }

    .nav-badge { min-width: 17px; height: 17px; margin-left: 6px; padding: 0 5px; display: inline-grid; place-items: center; border-radius: 99px; color: #fff; background: #F05C63; font-size: 10px; line-height: 1; }

    .topbar-actions { margin-left: auto; display: flex; align-items: center; gap: 18px; }

    .icon-button {
      position: relative;
      width: 36px;
      height: 36px;
      display: grid;
      place-items: center;
      border: 0;
      border-radius: 9px;
      color: var(--muted);
      background: transparent;
      transition: background .2s, color .2s;
    }

    .icon-button:hover { color: var(--primary); background: var(--interactive-soft); }
    .icon-button svg { width: 19px; height: 19px; stroke: currentColor; fill: none; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
    .notification-dot { position: absolute; top: 6px; right: 6px; width: 7px; height: 7px; border: 2px solid #fff; border-radius: 50%; background: #F05C63; }

    .profile-chip { display: flex; align-items: center; gap: 9px; padding: 4px 0 4px 5px; border: 0; color: var(--text); background: transparent; }
    .avatar { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 50%; color: #fff; background: linear-gradient(135deg, #8EA9D1, #5377AE); font-size: 13px; font-weight: 700; }
    .profile-meta { text-align: left; line-height: 1.25; }
    .profile-name { display: block; font-weight: 700; }
    .profile-role { display: block; margin-top: 2px; color: var(--muted); font-size: 11px; }
    .profile-chevron { width: 15px; height: 15px; margin-left: 1px; color: var(--muted); }

    .main-content { width: min(1240px, calc(100% - 48px)); margin: 0 auto; padding: 34px 0 56px; }

    /* 页面问候区 */
    .welcome-row { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; margin-bottom: 26px; }
    .eyebrow { margin: 0 0 7px; color: var(--interactive); font-size: 12px; font-weight: 700; letter-spacing: .8px; }
    h1 { margin: 0; color: var(--primary); font-size: clamp(24px, 3vw, 30px); line-height: 1.25; letter-spacing: -.4px; }
    .welcome-subtitle { margin: 9px 0 0; color: var(--muted); font-size: 14px; }
    .welcome-subtitle strong { color: var(--primary); font-weight: 700; }

    .search-box { width: min(320px, 100%); height: 42px; position: relative; }
    .search-box input { width: 100%; height: 100%; padding: 0 42px 0 40px; border: 1px solid var(--line); border-radius: 9px; outline: 0; color: var(--text); background: var(--card); transition: border .2s, box-shadow .2s; }
    .search-box input:focus { border-color: rgba(43, 127, 255, .7); box-shadow: 0 0 0 3px rgba(43, 127, 255, .12); }
    .search-box svg { position: absolute; top: 12px; left: 14px; width: 18px; height: 18px; color: var(--muted); stroke: currentColor; fill: none; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; pointer-events: none; }
    .search-clear { display: none; position: absolute; top: 7px; right: 8px; width: 28px; height: 28px; border: 0; border-radius: 6px; color: var(--muted); background: transparent; }
    .search-clear.visible { display: block; }

    .dashboard-grid { display: grid; grid-template-columns: minmax(0, 1.06fr) minmax(0, .94fr); gap: 20px; margin-bottom: 25px; }

    .panel { border: 1px solid var(--line); border-radius: var(--radius); background: var(--card); box-shadow: var(--shadow); }
    .panel-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; padding: 22px 24px 18px; }
    .panel-title { margin: 0; color: var(--primary); font-size: 16px; font-weight: 800; }
    .panel-caption { margin: 5px 0 0; color: var(--muted); font-size: 12px; }
    .text-button { padding: 2px 0; border: 0; color: var(--interactive); background: transparent; font-size: 12px; font-weight: 700; white-space: nowrap; }
    .text-button:hover { color: var(--primary); }

    /* 投递摘要 */
    .application-panel { min-height: 280px; }
    .dashboard-state { min-height: 150px; display: flex; align-items: center; justify-content: center; gap: 10px; padding: 20px 24px; color: var(--muted); font-size: 12px; text-align: center; }
    .dashboard-state .text-button { padding: 0; }
    .dashboard-state.error-state { flex-direction: column; color: #A95D64; }
    .dashboard-empty { min-height: 92px; margin: 0 24px 22px; border: 1px dashed #DDE6F2; border-radius: 9px; background: #FBFCFE; }
    .application-overview { display: flex; align-items: center; gap: 22px; padding: 1px 24px 18px; }
    .progress-ring { position: relative; width: 92px; height: 92px; flex: 0 0 auto; }
    .progress-ring svg { width: 100%; height: 100%; transform: rotate(-90deg); }
    .progress-ring circle { fill: none; stroke-width: 7; }
    .progress-ring .track { stroke: #EDF1F6; }
    .progress-ring .value { stroke: var(--interactive); stroke-linecap: round; stroke-dasharray: 213.6; stroke-dashoffset: 58.9; }
    .progress-ring-label { position: absolute; inset: 0; display: grid; place-items: center; color: var(--primary); font-size: 22px; font-weight: 800; }
    .progress-ring-label small { margin-top: -25px; color: var(--muted); font-size: 10px; font-weight: 500; }
    .stat-copy strong { display: block; color: var(--primary); font-size: 25px; line-height: 1.15; }
    .stat-copy span { display: block; margin-top: 5px; color: var(--muted); font-size: 12px; }
    .stat-chips { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px; }
    .stat-chip { padding: 5px 9px; border-radius: 6px; color: var(--muted); background: #F7F9FC; font-size: 11px; }
    .stat-chip strong { display: inline; margin-right: 3px; color: var(--primary); font-size: 12px; }

    .latest-application { margin: 0 24px 22px; padding: 15px 16px; border: 1px solid #E6ECF5; border-radius: 9px; background: #FBFCFE; }
    .latest-label { margin: 0 0 11px; color: var(--muted); font-size: 11px; font-weight: 700; letter-spacing: .4px; }
    .latest-main { display: flex; align-items: center; gap: 13px; }
    .company-logo { width: 40px; height: 40px; display: grid; place-items: center; flex: 0 0 auto; border-radius: 9px; color: var(--primary); background: #EAF2FF; font-size: 13px; font-weight: 800; }
    .company-logo.orange { color: #9A5810; background: #FFF0D8; }
    .company-logo.green { color: #147156; background: #E5F7F0; }
    .job-basic { min-width: 0; flex: 1; }
    .job-title { overflow: hidden; color: var(--primary); font-size: 14px; font-weight: 700; text-overflow: ellipsis; white-space: nowrap; }
    .job-company { margin-top: 3px; color: var(--muted); font-size: 12px; }
    .status-pill { flex: 0 0 auto; padding: 5px 9px; border-radius: 6px; color: var(--interactive); background: var(--interactive-soft); font-size: 11px; font-weight: 700; }
    .latest-footer { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-top: 13px; padding-top: 12px; border-top: 1px dashed #DCE4EF; }
    .time-note { color: var(--muted); font-size: 11px; }
    .outline-button { display: inline-flex; align-items: center; justify-content: center; min-height: 30px; padding: 0 12px; border: 1px solid #BCD1ED; border-radius: 6px; color: var(--interactive); background: #fff; font-size: 12px; font-weight: 700; transition: all .2s; }
    .outline-button:hover { border-color: var(--interactive); background: var(--interactive-soft); }

    /* 企业动态 */
    .activity-panel { min-height: 280px; overflow: hidden; }
    .activity-list { max-height: 272px; display: flex; flex-direction: column; list-style: none; margin: 0; overflow-y: auto; padding: 0 24px 17px; }
    .activity-item { display: flex; align-items: flex-start; flex: 0 0 auto; min-width: 0; gap: 12px; padding: 0 0 16px; }
    .activity-item + .activity-item { padding-top: 16px; border-top: 1px solid #F0F2F6; }
    .activity-item.activity-unread .activity-company { color: var(--primary); }
    .activity-dot { position: relative; width: 9px; height: 9px; flex: 0 0 9px; margin-top: 5px; }
    .activity-dot::before { content: ""; position: absolute; top: 0; left: 0; width: 9px; height: 9px; border-radius: 50%; background: var(--interactive); box-shadow: 0 0 0 4px var(--interactive-soft); }
    .activity-item:nth-child(2) .activity-dot::before { background: #35A77F; box-shadow: 0 0 0 4px var(--success-soft); }
    .activity-item:nth-child(3) .activity-dot::before { background: #E19A38; box-shadow: 0 0 0 4px var(--warning-soft); }
    .activity-body { min-width: 0; flex: 1; overflow: hidden; }
    .activity-company { overflow: hidden; color: var(--primary); font-size: 13px; font-weight: 700; text-overflow: ellipsis; white-space: nowrap; }
    .activity-company span { margin-left: 6px; color: var(--muted); font-size: 11px; font-weight: 400; }
    .activity-content { display: -webkit-box; max-height: 38px; margin: 4px 0 0; overflow: hidden; color: #4D5F78; font-size: 12px; line-height: 1.55; overflow-wrap: anywhere; text-overflow: ellipsis; word-break: break-word; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
    .activity-time { margin-top: 6px; color: #9AA7B8; font-size: 11px; white-space: nowrap; }

    /* 推荐岗位区域 */
    .jobs-section { margin-top: 3px; }
    .section-heading { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; margin: 0 0 15px; }
    .section-heading h2 { margin: 0; color: var(--primary); font-size: 18px; }
    .section-heading p { margin: 5px 0 0; color: var(--muted); font-size: 12px; }
    .jobs-controls { display: flex; align-items: center; gap: 10px; }
    .filter-select { height: 34px; padding: 0 28px 0 10px; border: 1px solid var(--line); border-radius: 7px; color: var(--muted); background: #fff; font-size: 12px; }
    .jobs-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
    .job-card { position: relative; display: flex; min-height: 224px; flex-direction: column; padding: 18px; border: 1px solid var(--line); border-radius: 10px; background: var(--card); box-shadow: 0 4px 14px rgba(26, 60, 110, .04); transition: transform .2s ease, box-shadow .2s ease, border .2s; cursor: pointer; }
    .job-card:hover { transform: translateY(-2px); border-color: #D3E1F4; box-shadow: 0 10px 22px rgba(26, 60, 110, .09); }
    .job-card.hidden { display: none; }
    .job-card-top { display: flex; align-items: flex-start; justify-content: space-between; gap: 10px; }
    .job-card .company-logo { width: 42px; height: 42px; border-radius: 10px; }
    .bookmark-button { width: 30px; height: 30px; display: grid; place-items: center; border: 0; border-radius: 6px; color: #A7B2C1; background: transparent; }
    .bookmark-button:hover, .bookmark-button.saved { color: var(--interactive); background: var(--interactive-soft); }
    .bookmark-button svg { width: 17px; height: 17px; fill: currentColor; stroke: currentColor; stroke-width: 1.5; }
    .job-card h3 { overflow: hidden; margin: 14px 0 3px; color: var(--primary); font-size: 15px; text-overflow: ellipsis; white-space: nowrap; }
    .job-card-company { color: var(--muted); font-size: 12px; }
    .job-card-meta { display: flex; flex-wrap: wrap; gap: 7px 13px; margin-top: 13px; color: #4F617A; font-size: 12px; }
    .meta-item { display: inline-flex; align-items: center; gap: 5px; }
    .meta-item svg { width: 14px; height: 14px; color: #8C9BB0; stroke: currentColor; fill: none; stroke-width: 1.7; stroke-linecap: round; stroke-linejoin: round; }
    .job-card-tags { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 14px; }
    .match-tag { padding: 4px 7px; border-radius: 5px; color: var(--interactive); background: var(--interactive-soft); font-size: 11px; font-weight: 700; }
    .job-tag { padding: 4px 7px; border-radius: 5px; color: #5B6E87; background: #F1F4F8; font-size: 11px; }
    .urgent-tag { padding: 4px 7px; border-radius: 5px; color: #B36512; background: var(--warning-soft); font-size: 11px; font-weight: 700; }
    .job-card-footer { display: flex; align-items: center; justify-content: space-between; gap: 10px; margin-top: auto; padding-top: 15px; }
    .salary { color: var(--primary); font-size: 13px; font-weight: 800; }
    .salary small { color: var(--muted); font-size: 11px; font-weight: 400; }
    .apply-button { min-width: 72px; height: 32px; padding: 0 12px; border: 0; border-radius: 6px; color: #fff; background: var(--interactive); font-size: 12px; font-weight: 700; transition: background .2s, transform .2s; }
    .apply-button:hover { background: #1769DB; transform: translateY(-1px); }
    .apply-button.applied { color: var(--success); background: var(--success-soft); }
    .empty-state { grid-column: 1 / -1; display: none; padding: 34px; border: 1px dashed #CDD9E8; border-radius: 10px; color: var(--muted); background: #fff; text-align: center; }
    .empty-state.visible { display: block; }

    /* 通知浮层和详情弹窗 */
    .notification-popover { position: fixed; z-index: 30; top: 63px; right: max(24px, calc((100vw - 1240px) / 2)); width: 320px; display: none; border: 1px solid var(--line); border-radius: 10px; background: #fff; box-shadow: 0 16px 38px rgba(23, 43, 77, .16); overflow: hidden; }
    .notification-popover.open { display: block; animation: popIn .16s ease-out; }
    @keyframes popIn { from { opacity: 0; transform: translateY(-5px); } to { opacity: 1; transform: translateY(0); } }
    .popover-head { display: flex; align-items: center; justify-content: space-between; padding: 15px 16px; border-bottom: 1px solid var(--line); }
    .popover-head strong { color: var(--primary); font-size: 14px; }
    .popover-head button { padding: 0; border: 0; color: var(--interactive); background: transparent; font-size: 11px; }
    .notification-item { display: flex; gap: 10px; padding: 13px 16px; border-bottom: 1px solid #F1F3F7; }
    .notification-icon { width: 28px; height: 28px; display: grid; place-items: center; flex: 0 0 auto; border-radius: 7px; color: var(--interactive); background: var(--interactive-soft); font-size: 13px; font-weight: 800; }
    .notification-item p { margin: 0; color: var(--text); font-size: 12px; line-height: 1.45; }
    .notification-item time { display: block; margin-top: 4px; color: #9AA7B8; font-size: 10px; }
    .modal-backdrop { position: fixed; z-index: 40; inset: 0; display: none; align-items: center; justify-content: center; padding: 22px; background: rgba(16, 45, 83, .32); }
    .modal-backdrop.open { display: flex; }
    .detail-modal { width: min(520px, 100%); border-radius: 12px; background: #fff; box-shadow: 0 22px 50px rgba(16, 45, 83, .2); overflow: hidden; }
    .modal-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; padding: 22px 24px; border-bottom: 1px solid var(--line); }
    .modal-title-wrap { display: flex; align-items: center; gap: 13px; }
    .modal-title { margin: 0; color: var(--primary); font-size: 17px; }
    .modal-company { margin-top: 3px; color: var(--muted); font-size: 12px; }
    .modal-close { width: 30px; height: 30px; display: grid; place-items: center; border: 0; border-radius: 6px; color: var(--muted); background: transparent; font-size: 20px; }
    .modal-close:hover { background: #F2F5F9; }
    .modal-body { padding: 21px 24px 24px; }
    .progress-track { display: flex; align-items: flex-start; justify-content: space-between; gap: 0; margin: 15px 0 24px; }
    .progress-step { position: relative; flex: 1; text-align: center; }
    .progress-step::before { content: ""; position: absolute; z-index: 0; top: 9px; right: 50%; left: -50%; height: 2px; background: #E5EAF2; }
    .progress-step:first-child::before { display: none; }
    .progress-step.done::before, .progress-step.current::before { background: var(--interactive); }
    .step-dot { position: relative; z-index: 1; width: 20px; height: 20px; display: grid; place-items: center; margin: 0 auto 8px; border: 3px solid #E5EAF2; border-radius: 50%; color: #fff; background: #fff; font-size: 10px; }
    .progress-step.done .step-dot, .progress-step.current .step-dot { border-color: var(--interactive); background: var(--interactive); }
    .progress-step span { color: var(--muted); font-size: 11px; }
    .progress-step.current span { color: var(--interactive); font-weight: 700; }
    .modal-note { margin: 0; padding: 12px 13px; border-radius: 7px; color: #53647B; background: #F7F9FC; font-size: 12px; line-height: 1.6; }

    .toast { position: fixed; z-index: 60; right: 24px; bottom: 24px; display: flex; align-items: center; gap: 9px; max-width: calc(100vw - 48px); padding: 11px 15px; border: 1px solid #CCE9DE; border-radius: 8px; color: #176B50; background: #F2FBF7; box-shadow: 0 10px 25px rgba(23, 43, 77, .1); font-size: 12px; opacity: 0; transform: translateY(10px); pointer-events: none; transition: opacity .2s, transform .2s; }
    .toast.show { opacity: 1; transform: translateY(0); }

    @media (max-width: 980px) {
      .topbar-inner, .main-content { width: min(100% - 32px, 760px); }
      .topbar-inner { gap: 15px; }
      .brand-tag, .profile-meta, .profile-chevron { display: none; }
      .main-nav { margin-left: auto; }
      .nav-link { padding: 0 9px; }
      .nav-link.active::after { right: 9px; left: 9px; }
      .topbar-actions { margin-left: 0; }
      .dashboard-grid { grid-template-columns: 1fr; }
      .jobs-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    }

    @media (max-width: 640px) {
      .topbar { height: 64px; }
      .topbar-inner, .main-content { width: calc(100% - 28px); }
      .topbar-inner { gap: 9px; }
      .brand-name { font-size: 16px; }
      .main-nav { gap: 0; }
      .nav-link { width: 38px; height: 64px; padding: 0; justify-content: center; font-size: 0; }
      .nav-link::before { font-size: 17px; }
      .nav-link:nth-child(1)::before { content: "⌂"; }
      .nav-link:nth-child(2)::before { content: "▣"; }
      .nav-link:nth-child(3)::before { content: "◷"; }
      .nav-link:nth-child(4)::before { content: "◎"; }
      .nav-link.active::after { right: 7px; left: 7px; }
      .nav-badge { position: absolute; top: 14px; right: 1px; font-size: 9px; }
      .topbar-actions { gap: 2px; }
      .profile-chip { padding: 4px 0; }
      .main-content { padding-top: 25px; }
      .welcome-row { display: block; }
      .search-box { width: 100%; margin-top: 18px; }
      .application-overview { gap: 15px; padding-right: 18px; padding-left: 18px; }
      .latest-application { margin-right: 18px; margin-left: 18px; }
      .panel-header { padding-right: 18px; padding-left: 18px; }
      .activity-list { padding-right: 18px; padding-left: 18px; }
      .section-heading { display: block; }
      .jobs-controls { margin-top: 12px; }
      .jobs-grid { grid-template-columns: 1fr; }
      .job-card { min-height: 210px; }
      .notification-popover { top: 57px; right: 14px; width: min(320px, calc(100vw - 28px)); }
    }
    .job-card:focus-visible{outline:3px solid rgba(43,127,255,.22);outline-offset:3px}.job-card .bookmark-button,.job-card .apply-button{cursor:pointer}

    /* 面试安排日历 */
    .schedule-section { margin-top: 26px; }
    .schedule-panel { overflow: hidden; }
    .schedule-header { display: flex; align-items: center; justify-content: space-between; gap: 20px; padding: 22px 24px 19px; }
    .schedule-caption { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
    .mock-badge { padding: 3px 7px; border: 1px solid #F1D59B; border-radius: 999px; color: #9A6815; background: #FFF8E9; font-size: 9px; font-weight: 700; }
    .schedule-toolbar { display: flex; align-items: center; gap: 12px; }
    .calendar-switcher { display: flex; align-items: center; gap: 12px; color: var(--primary); }
    .calendar-switcher strong { min-width: 88px; color: var(--primary); font-size: 14px; text-align: center; }
    .calendar-nav { width: 30px; height: 30px; display: grid; place-items: center; border: 1px solid var(--line); border-radius: 7px; color: var(--primary); background: #fff; font-size: 22px; line-height: 1; transition: border .2s, background .2s, color .2s; }
    .calendar-nav:hover { border-color: #BCD1ED; color: var(--interactive); background: var(--interactive-soft); }
    .today-button { min-height: 30px; padding: 0 11px; border: 1px solid #BCD1ED; border-radius: 7px; color: var(--interactive); background: #fff; font-size: 11px; font-weight: 700; }
    .today-button:hover { background: var(--interactive-soft); }
    .schedule-layout { display: grid; grid-template-columns: minmax(0, 1.28fr) minmax(320px, .72fr); border-top: 1px solid var(--line); }
    .calendar-area { min-width: 0; padding: 22px 24px 18px; border-right: 1px solid var(--line); }
    .weekday-row, .calendar-grid { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 7px; }
    .weekday-row { margin-bottom: 7px; color: #93A0B3; font-size: 11px; font-weight: 700; text-align: center; }
    .calendar-day { position: relative; min-width: 0; min-height: 70px; display: flex; flex-direction: column; align-items: center; justify-content: space-between; padding: 10px 7px 8px; border: 1px solid transparent; border-radius: 8px; color: var(--text); background: #fff; text-align: center; transition: border .2s, background .2s, box-shadow .2s; }
    .calendar-day:hover { border-color: #C8DAF2; background: #F8FBFF; }
    .calendar-day.outside { color: #B9C2CF; background: #FBFCFE; }
    .calendar-day.today { border-color: #A7C9F6; background: #F7FBFF; }
    .calendar-day.today .day-number { color: var(--interactive); font-weight: 800; }
    .calendar-day.today::before { content: "今"; position: absolute; top: 5px; right: 6px; min-width: 13px; height: 13px; padding: 1px 3px; border-radius: 4px; color: #fff; background: var(--interactive); font-size: 8px; font-weight: 800; line-height: 11px; }
    .calendar-day.selected { border-color: #8CB6EF; background: var(--interactive-soft); box-shadow: inset 0 0 0 1px rgba(43, 127, 255, .08); }
    .calendar-day.selected .day-number { color: var(--primary); font-weight: 800; }
    .day-number { font-size: 13px; line-height: 1.2; }
    .day-events { display: inline-flex; align-items: center; gap: 5px; min-height: 17px; color: var(--interactive); font-size: 10px; font-weight: 800; }
    .day-events i, .legend-dot { width: 6px; height: 6px; display: inline-block; border-radius: 50%; background: var(--interactive); }
    .calendar-legend { display: flex; align-items: center; gap: 16px; margin-top: 14px; color: #718198; font-size: 10px; }
    .calendar-legend span { display: inline-flex; align-items: center; gap: 6px; }
    .legend-today { width: 12px; height: 12px; display: inline-grid; place-items: center; border: 1px solid #A7C9F6; border-radius: 4px; color: var(--interactive); background: #F7FBFF; font-size: 8px; font-style: normal; }
    .legend-today::after { content: "今"; }
    .schedule-details { min-width: 0; padding: 22px 22px 20px; background: #FBFCFE; }
    .details-heading { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 15px; }
    .details-kicker { color: #9AA7B8; font-size: 9px; font-weight: 800; letter-spacing: 1px; }
    .details-heading h3 { margin: 4px 0 0; color: var(--primary); font-size: 16px; }
    .loading-label { color: var(--interactive); font-size: 10px; font-weight: 700; }
    .schedule-list { display: grid; gap: 10px; }
    .schedule-item { position: relative; display: grid; grid-template-columns: 68px minmax(0, 1fr); gap: 12px; padding: 13px; border: 1px solid #E2EAF3; border-radius: 9px; background: #fff; }
    .schedule-item-time { padding-right: 10px; border-right: 1px solid #E8EDF4; }
    .schedule-item-time strong { display: block; color: var(--primary); font-size: 16px; line-height: 1.2; }
    .schedule-item-time span { display: block; margin-top: 5px; color: #9AA7B8; font-size: 10px; white-space: nowrap; }
    .schedule-item-copy { min-width: 0; }
    .schedule-item-copy h4 { overflow: hidden; margin: 0; color: var(--primary); font-size: 13px; text-overflow: ellipsis; white-space: nowrap; }
    .schedule-item-copy p { overflow: hidden; margin: 4px 0 0; color: var(--muted); font-size: 11px; text-overflow: ellipsis; white-space: nowrap; }
    .schedule-item-meta { display: flex; flex-wrap: wrap; align-items: center; gap: 7px; margin-top: 8px; color: #8492A5; font-size: 10px; }
    .schedule-status { padding: 3px 6px; border-radius: 4px; color: #B36B16; background: var(--warning-soft); font-weight: 700; }
    .schedule-status.in-progress { color: #167554; background: var(--success-soft); }
    .schedule-status.finished { color: #738197; background: #F0F3F7; }
    .schedule-item-actions { grid-column: 2; display: flex; flex-wrap: wrap; align-items: center; gap: 10px; margin-top: 3px; }
    .schedule-link { padding: 0; border: 0; color: var(--interactive); background: transparent; font-size: 11px; font-weight: 700; }
    .schedule-link:hover { color: var(--primary); }
    .schedule-link span { margin-left: 3px; }
    .schedule-link.secondary { color: #718198; font-weight: 600; }
    .schedule-link.unavailable { color: #9AA7B8; cursor: default; font-weight: 600; }
    .schedule-state { min-height: 150px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 7px; color: var(--muted); font-size: 11px; text-align: center; }
    .schedule-state strong { color: var(--primary); font-size: 13px; }
    .schedule-state .outline-button { margin-top: 5px; }
    .error-state { color: #A95D64; }
    .empty-calendar-icon { width: 38px; height: 38px; display: grid; place-items: center; margin-bottom: 3px; border-radius: 50%; color: #90A0B5; background: #EEF3F8; font-size: 21px; }
    .schedule-modal-backdrop { position: fixed; z-index: 40; inset: 0; display: grid; place-items: center; padding: 24px; background: rgba(16, 45, 83, .32); }
    .schedule-modal { position: relative; width: min(520px, 100%); padding: 28px; border: 1px solid #DDE7F2; border-radius: 12px; background: #fff; box-shadow: 0 18px 50px rgba(16, 45, 83, .2); }
    .schedule-modal-close { position: absolute; top: 15px; right: 17px; width: 30px; height: 30px; border: 0; color: #718198; background: transparent; font-size: 25px; line-height: 1; }
    .schedule-modal h2 { margin: 7px 38px 0 0; color: var(--primary); font-size: 20px; }
    .schedule-modal-summary { margin: 5px 0 20px; color: var(--muted); font-size: 12px; }
    .schedule-modal-info { display: flex; align-items: center; justify-content: space-between; gap: 18px; padding: 11px 13px; border-radius: 7px; background: #F7FAFE; color: #718198; font-size: 11px; }
    .schedule-modal-info strong { color: var(--primary); font-size: 12px; font-weight: 700; text-align: right; }
    .schedule-link-field { display: block; margin-top: 17px; color: var(--primary); font-size: 11px; font-weight: 700; }
    .schedule-link-field input { width: 100%; height: 42px; margin-top: 7px; padding: 0 11px; border: 1px solid #D9E3EF; border-radius: 7px; color: #536985; background: #FBFCFE; font-size: 12px; outline: 0; }
    .schedule-link-field input:focus { border-color: #8CB6EF; box-shadow: 0 0 0 3px rgba(43, 127, 255, .1); }
    .schedule-modal-tip { margin: 12px 0 0; color: #718198; font-size: 11px; }
    .schedule-modal-tip.expired { color: #A95D64; }
    .schedule-modal-actions { display: flex; justify-content: flex-end; gap: 9px; margin-top: 22px; }
    .schedule-modal-actions .outline-button, .schedule-modal-actions .primary-button { min-height: 36px; padding: 0 14px; border-radius: 7px; font-size: 11px; font-weight: 700; }
    .schedule-modal-actions .primary-button { border: 1px solid var(--interactive); color: #fff; background: var(--interactive); }
    .schedule-modal-actions .primary-button:disabled { border-color: #CBD5E2; color: #93A0B3; background: #E9EEF4; cursor: not-allowed; }

    @media (max-width: 980px) {
      .schedule-layout { grid-template-columns: 1fr; }
      .calendar-area { border-right: 0; border-bottom: 1px solid var(--line); }
    }

    @media (max-width: 640px) {
      .schedule-header { display: block; padding-right: 18px; padding-left: 18px; }
      .schedule-toolbar { justify-content: space-between; margin-top: 16px; }
      .calendar-area { padding: 18px 14px 16px; }
      .weekday-row, .calendar-grid { gap: 4px; }
      .calendar-day { min-height: 58px; padding: 8px 4px 6px; }
      .day-number { font-size: 12px; }
      .schedule-details { padding: 18px; }
      .schedule-item { grid-template-columns: 60px minmax(0, 1fr); gap: 10px; padding: 11px; }
      .schedule-item-time strong { font-size: 15px; }
      .schedule-modal { padding: 24px 18px 20px; }
      .schedule-modal-info { align-items: flex-start; flex-direction: column; gap: 3px; }
      .schedule-modal-info strong { text-align: left; }
    }
</style>

<style scoped>
.dashboard-grid{align-items:start}
.activity-list{max-height:none;overflow:visible;padding-bottom:22px}
.activity-item{display:grid;grid-template-columns:9px minmax(0,1fr);width:100%;min-height:78px;align-items:start}
.activity-body{width:100%;min-width:0}
.app-shell .search-box{margin-top:0}
.app-shell .search-box svg{top:12px;left:14px;width:18px;height:18px}
.app-shell .search-box input{height:100%;padding:0 42px 0 40px;border:1px solid var(--line);border-radius:9px;color:var(--text);background:var(--card)}
</style>
