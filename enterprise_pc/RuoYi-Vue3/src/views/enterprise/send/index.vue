<template>
  <div class="sc-page">
    <header class="sc-topbar">
      <div>
        <h1>笔试面试安排中心</h1>
        <p>选择候选人的投递记录，直接发送笔试通知或面试邀约</p>
      </div>
      <span v-if="applications.length" class="sc-count">共 {{ total }} 条投递</span>
    </header>

    <div class="sc-grid">
      <section class="sc-panel sc-list">
        <div class="sc-search">
          <input v-model="keyword" class="sc-input" placeholder="搜索姓名 / 手机号" @keyup.enter="searchTalents" />
          <button class="sc-btn sc-search-btn" @click="searchTalents">搜索</button>
        </div>

        <div v-if="talents.length" class="sc-talents">
          <button v-for="t in talents" :key="t.talentId" class="sc-talent" @click="pickTalent(t)">
            <b>{{ t.name || ('人才 #' + t.talentId) }}</b>
            <em v-if="t.phone">{{ t.phone }}</em>
          </button>
        </div>

        <div class="sc-list-body">
          <button
            v-for="row in applications"
            :key="row.applicationId"
            class="sc-app"
            :class="{ active: current && current.applicationId === row.applicationId }"
            @click="pickApplication(row)"
          >
            <span class="sc-avatar">{{ initial(row.name) }}</span>
            <span class="sc-app-main">
              <b>{{ row.name || '未命名候选人' }}</b>
              <em>{{ row.positionName || '—' }}</em>
            </span>
            <span class="sc-tag" :class="appStatusInfo(row.appStatus)[1]">{{ appStatusInfo(row.appStatus)[0] }}</span>
          </button>
          <div v-if="!applications.length" class="sc-empty">暂无投递记录</div>
        </div>
      </section>

      <section class="sc-panel sc-detail">
        <div v-if="!current" class="sc-empty big">请选择左侧投递记录</div>
        <template v-else>
          <header class="sc-detail-head">
            <div class="sc-who">
              <span class="sc-avatar lg">{{ initial(current.name) }}</span>
              <div class="sc-who-text">
                <b>{{ current.name || '未命名候选人' }}</b>
                <em>{{ current.positionName }}</em>
              </div>
            </div>
            <div class="sc-badges">
              <span class="sc-tag" :class="appStatusInfo(current.appStatus)[1]">
                {{ appStatusInfo(current.appStatus)[0] }}
              </span>
              <span class="sc-tag ghost">下一阶段 · {{ currentStageName }}</span>
            </div>
          </header>

          <div v-if="terminal" class="sc-alert">
            该投递已进入终态（{{ appStatusInfo(current.appStatus)[0] }}），无法再发送笔试或面试。
          </div>
          <div v-else-if="context && context.activeAppointment" class="sc-note">
            该候选人在此岗位已有未开始的面试安排，创建新的会议链接会被拦截，请先在面试安排中心处理。
          </div>
          <div v-if="passedStages.length" class="sc-note">
            已通过轮次：{{ passedStages.map(s => s.name).join('、') }}，不会出现在可选阶段中。
          </div>
          <div v-if="examBeforeInterview" class="sc-note warn">
            该岗位流程中笔试阶段在前且尚未通过，暂不能安排笔试之后的面试。
          </div>

          <div class="sc-segment">
            <button :class="{ active: activeTab === 'exam' }" @click="activeTab = 'exam'">笔试</button>
            <button :class="{ active: activeTab === 'interview' }" @click="activeTab = 'interview'">面试</button>
          </div>

          <div v-if="activeTab === 'exam'" class="sc-form">
            <label class="sc-field">
              <span>考试安排</span>
              <select v-model="exam.scheduleId" class="sc-input">
                <option :value="null">新建考试安排</option>
                <option v-for="s in schedules" :key="s.scheduleId" :value="s.scheduleId">
                  {{ s.paperName || ('安排 #' + s.scheduleId) }}（{{ s.startAt }} ~ {{ s.endAt }}）
                </option>
              </select>
            </label>

            <template v-if="!exam.scheduleId">
              <label class="sc-field">
                <span>试卷</span>
                <select v-model="exam.paperId" class="sc-input">
                  <option :value="null">请选择试卷</option>
                  <option v-for="p in papers" :key="p.paperId" :value="p.paperId">
                    {{ p.name }}（{{ p.durationMin }} 分钟）
                  </option>
                </select>
              </label>
              <div class="sc-grid2">
                <label class="sc-field">
                  <span>开始时间</span>
                  <input v-model="exam.startAt" type="datetime-local" class="sc-input" />
                </label>
                <label class="sc-field">
                  <span>截止时间</span>
                  <input v-model="exam.endAt" type="datetime-local" class="sc-input" />
                </label>
              </div>
              <div class="sc-grid2">
                <label class="sc-field">
                  <span>作答次数</span>
                  <input v-model.number="exam.maxAttempts" type="number" min="1" max="5" class="sc-input" />
                </label>
                <label class="sc-field">
                  <span>通过分数线</span>
                  <input v-model.number="exam.passThreshold" type="number" min="0" max="100" class="sc-input" />
                </label>
              </div>
              <div class="sc-block">
                <div class="sc-block-title">自动邀约面试（可选）</div>
                <div class="sc-grid3">
                  <label class="sc-field">
                    <span>面试官</span>
                    <select v-model="exam.autoInterviewerId" class="sc-input">
                      <option value="">不自动流转</option>
                      <option v-for="it in interviewers" :key="it.userId" :value="String(it.userId)">
                        {{ interviewerName(it) }}
                      </option>
                    </select>
                  </label>
                  <label class="sc-field">
                    <span>结束后 N 天</span>
                    <input v-model.number="exam.autoInviteDays" type="number" min="1" max="30" class="sc-input" />
                  </label>
                  <label class="sc-field">
                    <span>面试时长（分钟）</span>
                    <input v-model.number="exam.autoInviteDuration" type="number" min="15" max="180" step="5" class="sc-input" />
                  </label>
                </div>
              </div>
            </template>

            <div class="sc-field">
              <span>通知渠道</span>
              <div class="sc-chips">
                <button class="sc-chip" :class="{ active: exam.channels.includes('inapp') }" @click="toggleChannel('inapp')">站内信</button>
                <button class="sc-chip" :class="{ active: exam.channels.includes('email') }" @click="toggleChannel('email')">邮件</button>
              </div>
            </div>
            <label class="sc-field">
              <span>通知标题（可选）</span>
              <input v-model="exam.title" class="sc-input" placeholder="留空使用默认标题" />
            </label>

            <footer class="sc-submit">
              <p class="sc-hint">发送后会创建考试安排、通知候选人，并把「已投递」推进为「招聘中」。</p>
              <button class="sc-btn primary" :disabled="terminal || exam.sending" @click="sendExam">
                {{ exam.sending ? '发送中…' : '发送笔试通知' }}
              </button>
            </footer>

            <div v-if="examResult" class="sc-result">
              <div class="sc-result-head">
                <span>发送结果</span>
                <b>{{ examResult.sent ?? 0 }} 条成功</b>
              </div>
              <div v-for="(r, i) in examResult.results || []" :key="i" class="sc-result-row">
                <span>{{ r.name || ('候选人 #' + r.talId) }}</span>
                <em>{{ examResultText(r) }}</em>
              </div>
            </div>
          </div>

          <div v-if="activeTab === 'interview'" class="sc-form">
            <div class="sc-segment sub">
              <button :class="{ active: interview.mode === 'single' }" @click="interview.mode = 'single'">单轮 · 生成会议链接</button>
              <button :class="{ active: interview.mode === 'multi' }" @click="switchToMulti">多轮 · 批量排期</button>
            </div>

            <template v-if="interview.mode === 'single'">
              <div class="sc-grid2">
                <label class="sc-field">
                  <span>面试阶段</span>
                  <select v-model="interview.stageId" class="sc-input" @change="onStageChange">
                    <option :value="null">请选择阶段</option>
                    <option v-for="s in interviewStages" :key="s.stageId" :value="s.stageId">
                      {{ s.name }}（{{ stageTypeLabel(s.type) }}）
                    </option>
                  </select>
                </label>
                <label class="sc-field">
                  <span>面试方式</span>
                  <select v-model.number="interview.roomMode" class="sc-input" @change="onRoomModeChange">
                    <option v-for="m in MODE_OPTIONS" :key="m.value" :value="m.value">{{ m.label }}</option>
                  </select>
                </label>
              </div>
              <div class="sc-grid2">
                <label class="sc-field">
                  <span>开始时间</span>
                  <input v-model="interview.startTime" type="datetime-local" class="sc-input" />
                </label>
                <label class="sc-field">
                  <span>时长（分钟）</span>
                  <input v-model.number="interview.durationMinutes" type="number" min="15" max="180" step="5" class="sc-input" />
                </label>
              </div>
              <div class="sc-field">
                <span>面试官</span>
                <div class="sc-picker" :class="{ disabled: interview.roomMode === 1 }">
                  <label v-for="it in interviewers" :key="it.userId" class="sc-pick">
                    <input
                      v-model="interview.interviewerIds"
                      type="checkbox"
                      :value="it.userId"
                      :disabled="interview.roomMode === 1"
                    />
                    <span>{{ interviewerName(it) }}</span>
                  </label>
                  <div v-if="!interviewers.length" class="sc-pick-empty">暂无可用面试官</div>
                </div>
                <small class="sc-hint">{{ interviewerHint }}</small>
              </div>

              <footer class="sc-submit">
                <p class="sc-hint">会生成真实会议链接并通知候选人；同一岗位已有未开始预约时会失败。</p>
                <button class="sc-btn primary" :disabled="terminal || interview.sending" @click="sendInterview">
                  {{ interview.sending ? '发送中…' : '发送面试邀约' }}
                </button>
              </footer>
            </template>

            <template v-else>
              <div v-if="!multiStages.length" class="sc-empty">没有可排期的面试阶段</div>
              <div v-else class="sc-multi">
                <div class="sc-multi-head">
                  <span>阶段</span>
                  <span>面试官</span>
                  <span>开始时间</span>
                </div>
                <div v-for="row in multiStages" :key="row.stageId" class="sc-multi-row">
                  <label class="sc-check">
                    <input v-model="row.selected" type="checkbox" />
                    <span>
                      {{ row.name }}
                      <em>{{ stageTypeLabel(row.type) }}</em>
                    </span>
                  </label>
                  <select v-model="row.interviewerId" class="sc-input" :disabled="!row.selected">
                    <option value="">选择面试官</option>
                    <option v-for="it in interviewers" :key="it.userId" :value="it.userId">
                      {{ interviewerName(it) }}
                    </option>
                  </select>
                  <input v-model="row.startTime" type="datetime-local" class="sc-input" :disabled="!row.selected" />
                </div>
              </div>

              <footer class="sc-submit">
                <p class="sc-hint">多轮排期只创建面试预约，会议链接需在面试安排中心发起。</p>
                <button class="sc-btn primary" :disabled="terminal || interview.sending" @click="sendInterview">
                  {{ interview.sending ? '发送中…' : '批量安排面试' }}
                </button>
              </footer>
            </template>

            <div v-if="interviewResult" class="sc-result">
              <div class="sc-result-head">
                <span>发送结果</span>
                <b>{{ interviewResult.multi ? '已安排 ' + interviewResult.count + ' 轮' : '会议已创建' }}</b>
              </div>
              <template v-if="interviewResult.multi">
                <div class="sc-result-row"><span>已安排轮次</span><em>{{ interviewResult.count }}</em></div>
              </template>
              <template v-else>
                <div class="sc-result-row"><span>开始时间</span><em>{{ interviewResult.startTime }}</em></div>
                <div class="sc-result-row"><span>会议链接</span><em class="sc-break">{{ interviewResult.meetingUrl }}</em></div>
              </template>
            </div>
          </div>
        </template>
      </section>
    </div>

    <ToastMessage :message="toast" />
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute } from 'vue-router'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { appStatusInfo, isTerminalAppStatus } from '@/views/enterprise/components/appStatus'
import { listTalents, listApplications } from '@/api/talent'
import { getSendContext, inviteInterviewStages } from '@/api/send'
import { listPapers, listSchedules, createSchedule, sendExamNotify } from '@/api/exam'
import { listInterviewers, createRoomLink } from '@/api/system/conference'

const STAGE_TYPE_MODE = { 2: 2, 3: 4, 4: 1 }
const MODE_OPTIONS = [
  { value: 1, label: '纯AI面试' },
  { value: 2, label: 'AI + 单面试官' },
  { value: 3, label: 'AI + 多面试官' },
  { value: 4, label: '无AI纯人工' }
]

const route = useRoute()
const toast = ref('')
function notify(message) {
  toast.value = message
  setTimeout(() => { toast.value = '' }, 2400)
}

const keyword = ref('')
const talents = ref([])
const applications = ref([])
const total = ref(0)
const current = ref(null)
const context = ref(null)
const activeTab = ref('exam')
const papers = ref([])
const schedules = ref([])
const interviewers = ref([])

const exam = reactive({
  scheduleId: null, paperId: null, startAt: '', endAt: '',
  maxAttempts: 1, passThreshold: 60, channels: ['inapp'], title: '',
  autoInterviewerId: '', autoInviteDays: 3, autoInviteDuration: 45, sending: false
})
const examResult = ref(null)

const interview = reactive({
  mode: 'single', stageId: null, interviewerIds: [], startTime: '',
  durationMinutes: 45, roomMode: 2, sending: false
})
const multiStages = ref([])
const interviewResult = ref(null)

const terminal = computed(() => current.value
  ? (context.value ? context.value.terminal : isTerminalAppStatus(current.value.appStatus))
  : false)
const passedStages = computed(() => (context.value?.stages || []).filter(s => s.passed))
const interviewStages = computed(() => (context.value?.stages || [])
  .filter(s => !s.passed && Number(s.type) !== 1))
const currentStageName = computed(() => interviewStages.value[0]?.name || '—')
const examBeforeInterview = computed(() => {
  if (!context.value || context.value.examPassed) return false
  const stages = context.value.stages || []
  const firstExam = stages.find(s => Number(s.type) === 1)
  const firstInterview = stages.find(s => Number(s.type) !== 1 && !s.passed)
  return Boolean(firstExam && firstInterview && Number(firstExam.sortOrder) < Number(firstInterview.sortOrder))
})
const interviewerHint = computed(() => {
  const count = interview.interviewerIds.length
  if (interview.roomMode === 1) return '纯AI面试无需选择面试官'
  if (interview.roomMode === 2) return `AI + 单面试官需选择 1 位，当前已选 ${count} 位`
  if (interview.roomMode === 3) return `AI + 多面试官至少 2 位，当前已选 ${count} 位`
  return `无AI纯人工至少 1 位，当前已选 ${count} 位`
})

onMounted(async () => {
  const talentId = Number(route.query.talentId || route.query.candidateId || 0)
  const positionId = Number(route.query.positionId || 0)
  if (talentId) {
    await loadApplications({ talentId, positionId: positionId || undefined })
    const hit = applications.value.find(r => Number(r.positionId) === positionId)
    if (hit) await pickApplication(hit)
  } else {
    await loadApplications()
  }
  loadInterviewers()
})

async function searchTalents() {
  if (!keyword.value.trim()) return
  const res = await listTalents({ keyword: keyword.value.trim(), pageNum: 1, pageSize: 10 }).catch(() => null)
  talents.value = res?.rows || []
  if (!talents.value.length) notify('未找到候选人')
}

async function pickTalent(talent) {
  talents.value = []
  await loadApplications({ talentId: talent.talentId })
  if (applications.value.length === 1) await pickApplication(applications.value[0])
  else if (!applications.value.length) notify('该候选人暂无投递记录')
}

async function loadApplications(query = {}) {
  const res = await listApplications({ pageNum: 1, pageSize: 50, ...query }).catch(() => null)
  applications.value = res?.rows || []
  total.value = res?.total || 0
}

async function pickApplication(row) {
  current.value = row
  context.value = null
  examResult.value = null
  interviewResult.value = null
  activeTab.value = 'exam'
  resetExam()
  resetInterview()
  await Promise.all([loadContext(row), loadPapers(row), loadSchedules(row), loadInterviewers()])
}

async function loadContext(row) {
  const res = await getSendContext({ candidateId: row.talentId, positionId: row.positionId }).catch(() => null)
  context.value = res?.data || null
  buildMultiStages()
}

async function loadPapers(row) {
  const res = await listPapers(row.positionId).catch(() => null)
  papers.value = res?.data || res?.rows || []
}

async function loadSchedules(row) {
  const res = await listSchedules({ positionId: row.positionId, pageNum: 1, pageSize: 50 }).catch(() => null)
  schedules.value = (res?.rows || []).filter(s => Number(s.status ?? 0) < 2)
}

async function loadInterviewers() {
  if (interviewers.value.length) return
  const res = await listInterviewers().catch(() => null)
  interviewers.value = res?.data || []
}

function resetExam() {
  exam.scheduleId = null
  exam.paperId = null
  exam.startAt = futureTime(24)
  exam.endAt = futureTime(26)
  exam.maxAttempts = 1
  exam.passThreshold = 60
  exam.channels = ['inapp']
  exam.title = ''
  exam.autoInterviewerId = ''
  exam.autoInviteDays = 3
  exam.autoInviteDuration = 45
  examResult.value = null
}

function resetInterview() {
  interview.mode = 'single'
  interview.stageId = null
  interview.interviewerIds = []
  interview.startTime = futureTime(49)
  interview.durationMinutes = 45
  interview.roomMode = 2
  interviewResult.value = null
}

function buildMultiStages() {
  multiStages.value = interviewStages.value.map(stage => ({
    stageId: stage.stageId,
    name: stage.name,
    type: stage.type,
    selected: false,
    interviewerId: '',
    startTime: futureTime(49)
  }))
}

function switchToMulti() {
  interview.mode = 'multi'
  if (!multiStages.value.length) buildMultiStages()
}

function onStageChange() {
  const stage = interviewStages.value.find(s => s.stageId === interview.stageId)
  if (!stage) return
  interview.durationMinutes = Number(stage.duration) || 45
  interview.roomMode = STAGE_TYPE_MODE[Number(stage.type)] || 2
  onRoomModeChange()
}

function onRoomModeChange() {
  if (interview.roomMode === 1) interview.interviewerIds = []
}

function toggleChannel(code) {
  const index = exam.channels.indexOf(code)
  if (index >= 0) exam.channels.splice(index, 1)
  else exam.channels.push(code)
}

async function sendExam() {
  if (terminal.value) return notify('该投递已进入终态，无法发送')
  if (exam.sending) return
  if (!exam.scheduleId) {
    if (!exam.paperId) return notify('请选择试卷')
    if (!exam.startAt || !exam.endAt) return notify('请选择笔试开始与截止时间')
    if (new Date(exam.endAt) <= new Date(exam.startAt)) return notify('截止时间必须晚于开始时间')
  }
  if (!exam.channels.length) return notify('请至少选择一个通知渠道')
  exam.sending = true
  try {
    let scheduleId = exam.scheduleId
    if (!scheduleId) {
      const res = await createSchedule({
        positionId: current.value.positionId,
        paperId: Number(exam.paperId),
        startAt: exam.startAt.replace('T', ' '),
        endAt: exam.endAt.replace('T', ' '),
        maxAttempts: Number(exam.maxAttempts) || 1,
        passThreshold: Number(exam.passThreshold) || 60,
        forceDualCamera: 0,
        dualCameraConfig: null,
        submitRule: { autoSubmit: true, allowEarly: true, autosaveInterval: 30 },
        autoFlow: exam.autoInterviewerId ? {
          interviewerId: Number(exam.autoInterviewerId),
          startAfterDays: Number(exam.autoInviteDays) || 3,
          durationMin: Number(exam.autoInviteDuration) || 45
        } : null
      })
      scheduleId = res.data
      exam.scheduleId = scheduleId
    }
    const res = await sendExamNotify(scheduleId, {
      channels: exam.channels,
      title: exam.title || undefined,
      candidateIds: [current.value.talentId]
    })
    examResult.value = res.data || null
    notify(`已发送 ${examResult.value?.sent ?? 0} 条笔试通知`)
    await Promise.all([loadSchedules(current.value), loadContext(current.value)])
  } catch (e) {
    // 请求拦截器已统一提示
  } finally {
    exam.sending = false
  }
}

async function sendInterview() {
  if (terminal.value) return notify('该投递已进入终态，无法发送')
  if (interview.sending) return
  if (interview.mode === 'multi') return sendMultiInterview()
  if (!interview.stageId) return notify('请选择面试阶段')
  if (!interview.startTime) return notify('请选择面试开始时间')
  const ids = interview.interviewerIds.map(Number)
  if (interview.roomMode === 2 && ids.length !== 1) return notify('AI + 单面试官需要选择 1 位面试官')
  if (interview.roomMode === 3 && ids.length < 2) return notify('AI + 多面试官至少选择 2 位面试官')
  if (interview.roomMode === 4 && ids.length < 1) return notify('无AI纯人工至少选择 1 位面试官')
  interview.sending = true
  try {
    const res = await createRoomLink({
      peerUserId: current.value.userId,
      positionId: current.value.positionId,
      stageId: interview.stageId,
      startTime: interview.startTime.replace('T', ' '),
      durationMinutes: Number(interview.durationMinutes) || 45,
      mode: interview.roomMode,
      interviewerIds: ids
    })
    interviewResult.value = res.data || null
    notify('面试邀约已发送')
    await loadContext(current.value)
  } catch (e) {
    // 请求拦截器已统一提示
  } finally {
    interview.sending = false
  }
}

async function sendMultiInterview() {
  const rows = multiStages.value.filter(row => row.selected)
  if (!rows.length) return notify('请至少选择一个面试阶段')
  for (const row of rows) {
    if (!row.interviewerId) return notify(`阶段「${row.name}」未选择面试官`)
    if (!row.startTime) return notify(`阶段「${row.name}」未选择开始时间`)
  }
  interview.sending = true
  try {
    await inviteInterviewStages({
      candidateId: current.value.talentId,
      positionId: current.value.positionId,
      stages: rows.map(row => ({
        stageId: row.stageId,
        interviewerId: Number(row.interviewerId),
        startTime: row.startTime.replace('T', ' ')
      }))
    })
    interviewResult.value = { multi: true, count: rows.length }
    notify(`已安排 ${rows.length} 轮面试`)
    await loadContext(current.value)
  } catch (e) {
    // 请求拦截器已统一提示
  } finally {
    interview.sending = false
  }
}

function stageTypeLabel(type) {
  return { 1: '在线笔试', 2: 'AI技术面试', 3: 'HR综合面试', 4: '编程实操' }[Number(type)] || '面试'
}

function interviewerName(item) {
  return item?.nickName || item?.name || item?.userName || ('用户 #' + item?.userId)
}

function initial(name) {
  const text = String(name || '').trim()
  return text ? text.slice(0, 1) : '?'
}

function examResultText(item) {
  if (item?.channels) {
    return Object.entries(item.channels)
      .map(([code, value]) => `${code === 'email' ? '邮件' : '站内信'}：${value}`)
      .join(' / ')
  }
  return item?.status || item?.message || '—'
}

function futureTime(hours) {
  const date = new Date(Date.now() + hours * 3600 * 1000)
  date.setSeconds(0, 0)
  const pad = value => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}
</script>

<style scoped>
.sc-page {
  min-height: calc(100vh - 96px);
  padding: 20px 24px 28px;
  background: #f5f7fb;
  color: #1f2d3d;
}
.sc-topbar {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 18px;
}
.sc-topbar h1 { margin: 0; font-size: 21px; letter-spacing: .2px; }
.sc-topbar p { margin: 6px 0 0; color: #8492a6; font-size: 13px; }
.sc-count {
  padding: 5px 12px;
  border-radius: 20px;
  background: #eef3ff;
  color: #3b6fe0;
  font-size: 12px;
}

.sc-grid {
  display: grid;
  grid-template-columns: 380px minmax(0, 1fr);
  gap: 18px;
  align-items: stretch;
}
.sc-panel {
  background: #fff;
  border: 1px solid #e9edf5;
  border-radius: 14px;
  box-shadow: 0 10px 30px rgba(30, 55, 100, .05);
}
.sc-list {
  display: flex;
  flex-direction: column;
  padding: 16px;
  max-height: calc(100vh - 190px);
}
.sc-search { display: flex; gap: 8px; }
.sc-search-btn { flex: 0 0 64px; }
.sc-list-body {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  margin: 12px -6px 0;
  padding: 0 6px;
}
.sc-list-body::-webkit-scrollbar { width: 6px; }
.sc-list-body::-webkit-scrollbar-thumb { background: #dfe5ef; border-radius: 3px; }

.sc-app {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 11px 12px;
  margin-bottom: 6px;
  border: 1px solid transparent;
  border-radius: 10px;
  background: transparent;
  text-align: left;
  cursor: pointer;
  transition: background .15s, box-shadow .15s;
}
.sc-app:hover { background: #f7f9fd; }
.sc-app.active {
  background: #eff5ff;
  border-color: #dbe7ff;
  box-shadow: inset 3px 0 0 #2f6bff;
}
.sc-avatar {
  flex: 0 0 34px;
  width: 34px;
  height: 34px;
  border-radius: 50%;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #e8efff, #d7e4ff);
  color: #2f6bff;
  font-size: 13px;
  font-weight: 600;
}
.sc-avatar.lg { flex-basis: 42px; width: 42px; height: 42px; font-size: 16px; }
.sc-app-main { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 3px; }
.sc-app-main b { font-size: 13.5px; font-weight: 600; color: #1f2d3d; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sc-app-main em { font-style: normal; font-size: 12px; color: #8d99ac; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

.sc-detail { padding: 20px 22px 22px; min-height: calc(100vh - 190px); }
.sc-detail-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  padding-bottom: 16px;
  border-bottom: 1px solid #eef1f6;
}
.sc-who { display: flex; align-items: center; gap: 12px; }
.sc-who-text { display: flex; flex-direction: column; gap: 3px; }
.sc-who-text b { font-size: 16px; }
.sc-who-text em { font-style: normal; font-size: 12.5px; color: #8d99ac; }
.sc-badges { display: flex; gap: 8px; flex-wrap: wrap; }

.sc-input {
  width: 100%;
  box-sizing: border-box;
  height: 36px;
  border: 1px solid #dbe1ec;
  border-radius: 8px;
  padding: 0 10px;
  font-size: 13px;
  background: #fff;
  color: #1f2d3d;
  outline: none;
  transition: border-color .15s, box-shadow .15s;
}
select.sc-input { cursor: pointer; }
.sc-input:focus { border-color: #2f6bff; box-shadow: 0 0 0 3px rgba(47, 107, 255, .12); }
.sc-input:disabled { background: #f5f7fa; color: #9aa5b7; cursor: not-allowed; }
textarea.sc-input { height: auto; padding: 8px 10px; }

.sc-btn {
  height: 36px;
  padding: 0 16px;
  border: 1px solid #dbe1ec;
  border-radius: 8px;
  background: #fff;
  color: #4a5a76;
  font-size: 13px;
  cursor: pointer;
  transition: border-color .15s, background .15s;
}
.sc-btn:hover { border-color: #b9c6dc; }
.sc-btn.primary {
  border-color: #2f6bff;
  background: #2f6bff;
  color: #fff;
  box-shadow: 0 6px 16px rgba(47, 107, 255, .25);
}
.sc-btn.primary:hover { background: #1f5bf0; }
.sc-btn:disabled { opacity: .55; cursor: not-allowed; box-shadow: none; }

.sc-talents { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
.sc-talent {
  display: inline-flex;
  gap: 6px;
  align-items: center;
  padding: 5px 11px;
  border: 1px solid #dbe1ec;
  border-radius: 16px;
  background: #f8fafd;
  font-size: 12px;
  cursor: pointer;
}
.sc-talent:hover { border-color: #2f6bff; color: #2f6bff; }
.sc-talent em { font-style: normal; color: #97a2b5; }

.sc-tag {
  display: inline-flex;
  align-items: center;
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 20px;
  font-size: 11.5px;
  font-weight: 500;
  white-space: nowrap;
}
.sc-tag.gray { background: #f1f4f9; color: #64748b; }
.sc-tag.blue { background: #eaf1ff; color: #2f6bff; }
.sc-tag.orange { background: #fff3e0; color: #b26a00; }
.sc-tag.purple { background: #f3ecff; color: #7a45d8; }
.sc-tag.green { background: #e8f7ee; color: #1f8a4c; }
.sc-tag.red { background: #fdecec; color: #c0392b; }
.sc-tag.ghost { background: #f5f7fa; color: #64748b; }

.sc-empty { padding: 44px 0; text-align: center; color: #9aa5b7; font-size: 13px; }
.sc-empty.big { padding: 120px 0; }

.sc-alert {
  margin-top: 14px;
  padding: 11px 14px;
  border-radius: 9px;
  background: #fff1f0;
  border: 1px solid #ffd9d5;
  color: #c0392b;
  font-size: 13px;
}
.sc-note {
  margin-top: 10px;
  padding: 9px 13px;
  border-radius: 9px;
  background: #f5f8ff;
  border: 1px solid #e4ecff;
  color: #4a5a76;
  font-size: 12.5px;
}
.sc-note.warn { background: #fffaf0; border-color: #ffe7bd; color: #96650b; }

.sc-segment {
  display: inline-flex;
  gap: 4px;
  margin: 16px 0 16px;
  padding: 4px;
  border-radius: 10px;
  background: #f2f5fa;
}
.sc-segment button {
  border: none;
  background: transparent;
  color: #64748b;
  font-size: 13px;
  padding: 7px 18px;
  border-radius: 8px;
  cursor: pointer;
  transition: background .15s, color .15s, box-shadow .15s;
}
.sc-segment button.active {
  background: #fff;
  color: #2f6bff;
  font-weight: 600;
  box-shadow: 0 2px 8px rgba(30, 55, 100, .08);
}
.sc-segment.sub { margin-top: 0; }

.sc-form { display: flex; flex-direction: column; gap: 14px; }
.sc-grid2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; }
.sc-grid3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px; }
.sc-field { display: flex; flex-direction: column; gap: 7px; font-size: 12.5px; color: #64748b; }
.sc-field > span { color: #5a6880; }

.sc-block {
  padding: 14px;
  border: 1px dashed #dfe6f2;
  border-radius: 10px;
  background: #fbfcfe;
}
.sc-block-title { font-size: 12.5px; color: #5a6880; margin-bottom: 10px; }

.sc-chips { display: flex; gap: 8px; flex-wrap: wrap; }
.sc-chip {
  height: 32px;
  padding: 0 16px;
  border: 1px solid #dbe1ec;
  border-radius: 18px;
  background: #fff;
  color: #5a6880;
  font-size: 12.5px;
  cursor: pointer;
  transition: all .15s;
}
.sc-chip.active { border-color: #2f6bff; background: #eef4ff; color: #2f6bff; font-weight: 500; }

.sc-picker {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 6px 10px;
  padding: 10px 12px;
  border: 1px solid #dbe1ec;
  border-radius: 9px;
  background: #fff;
  min-height: 74px;
  max-height: 170px;
  overflow-y: auto;
}
.sc-picker.disabled { background: #f7f9fc; }
.sc-pick {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: #1f2d3d;
  cursor: pointer;
  padding: 4px 6px;
  border-radius: 6px;
}
.sc-pick:hover { background: #f5f8ff; }
.sc-pick input { accent-color: #2f6bff; }
.sc-pick-empty { font-size: 12.5px; color: #9aa5b7; padding: 6px; }

.sc-multi { display: flex; flex-direction: column; }
.sc-multi-head {
  display: grid;
  grid-template-columns: minmax(180px, 1.2fr) minmax(150px, 1fr) minmax(180px, 1fr);
  gap: 12px;
  padding: 0 4px 8px;
  font-size: 12px;
  color: #8d99ac;
}
.sc-multi-row {
  display: grid;
  grid-template-columns: minmax(180px, 1.2fr) minmax(150px, 1fr) minmax(180px, 1fr);
  gap: 12px;
  align-items: center;
  padding: 9px 4px;
  border-top: 1px dashed #eef1f6;
}
.sc-check { display: flex; align-items: center; gap: 8px; font-size: 13px; cursor: pointer; }
.sc-check input { accent-color: #2f6bff; }
.sc-check em { font-style: normal; color: #97a2b5; font-size: 12px; margin-left: 4px; }

.sc-submit {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-top: 4px;
  padding-top: 16px;
  border-top: 1px solid #eef1f6;
}
.sc-hint { margin: 0; color: #8d99ac; font-size: 12px; line-height: 1.6; }
.sc-field .sc-hint { margin-top: 2px; }

.sc-result {
  margin-top: 4px;
  border: 1px solid #e4eaf4;
  border-radius: 10px;
  padding: 14px 16px;
  background: #fbfcfe;
}
.sc-result-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 13px;
  margin-bottom: 8px;
}
.sc-result-head b { color: #1f8a4c; font-weight: 600; }
.sc-result-row {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  font-size: 12.5px;
  color: #64748b;
  padding: 5px 0;
  border-top: 1px dashed #eef1f6;
}
.sc-result-row em { font-style: normal; color: #1f2d3d; max-width: 70%; }
.sc-break { word-break: break-all; text-align: right; }

@media (max-width: 1180px) {
  .sc-grid { grid-template-columns: 1fr; }
  .sc-list { max-height: 420px; }
  .sc-detail { min-height: auto; }
}
@media (max-width: 720px) {
  .sc-page { padding: 16px; }
  .sc-grid2, .sc-grid3, .sc-multi-head, .sc-multi-row { grid-template-columns: 1fr; }
  .sc-submit { flex-direction: column; align-items: stretch; }
}
</style>
