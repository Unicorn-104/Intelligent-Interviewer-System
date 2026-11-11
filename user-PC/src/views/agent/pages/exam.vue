<template>
  <div class="page">
    <AgentTopbar active="exam" />
    <main class="main">
      <!-- 单场考试入口（通知链接携带 scheduleId） -->
      <section v-if="scheduleId" class="entry-card">
        <div v-if="loading" class="empty-state">正在加载考试信息...</div>
        <template v-else-if="entry">
          <div class="entry-head">
            <div class="entry-badge">✎</div>
            <div>
              <h1>{{ entry.paperName }}</h1>
              <div class="entry-sub">应聘岗位：{{ entry.positionTitle }}</div>
            </div>
            <span class="status-pill" :class="entryPillClass">{{ entryPillText }}</span>
          </div>
          <div class="entry-grid">
            <div class="entry-item"><span>试卷时长</span><strong>{{ entry.durationMin }} 分钟</strong></div>
            <div class="entry-item"><span>题目数量</span><strong>{{ entry.questionCount }} 题</strong></div>
            <div class="entry-item"><span>试卷总分</span><strong>{{ entry.totalScore }} 分</strong></div>
            <div class="entry-item"><span>通过线</span><strong>{{ entry.passThreshold }} 分</strong></div>
            <div class="entry-item"><span>开考时间</span><strong>{{ fmt(entry.startAt) }}</strong></div>
            <div class="entry-item"><span>截止时间</span><strong>{{ fmt(entry.endAt) }}</strong></div>
          </div>
          <div v-if="entry.forceDualCamera === 1" class="entry-note">本场考试要求双机位监考，请按指引开启副机位。</div>
          <div class="entry-actions">
            <button v-if="canEnter" class="primary-btn" type="button" @click="goRoom">
              {{ entry.recordStatus === 1 ? '继续作答' : '开始作答' }}
            </button>
            <button v-else class="primary-btn" type="button" disabled>{{ blockedText }}</button>
            <a class="ghost-link" :href="appHref('/exam')">返回考试列表</a>
          </div>
        </template>
        <div v-else class="empty-state">{{ loadError || '考试不存在或无权访问' }}</div>
      </section>

      <!-- 我的考试列表 -->
      <section v-else class="list-panel">
        <div class="page-heading">
          <div>
            <h1>在线笔试</h1>
            <div class="page-meta">来自应聘企业的笔试安排</div>
          </div>
          <span v-if="!loading && exams.length" class="list-count">共 {{ filteredExams.length }} 场</span>
        </div>
        <div v-if="!loading && exams.length" class="exam-filters">
          <button
            v-for="f in examFilters"
            :key="f.key"
            type="button"
            class="filter-chip"
            :class="{ active: statusFilter === f.key }"
            @click="statusFilter = f.key"
          >
            {{ f.label }}
          </button>
        </div>
        <div v-if="loading" class="empty-state">正在加载考试列表...</div>
        <template v-else>
          <div v-if="filteredExams.length" class="exam-grid">
            <article v-for="item in filteredExams" :key="item.scheduleId" class="exam-card" :class="listPillClass(item)">
              <div class="exam-card-head">
                <span class="status-pill" :class="listPillClass(item)">{{ listPillText(item) }}</span>
                <span class="exam-duration">{{ item.durationMin }} 分钟</span>
              </div>
              <div class="exam-title">{{ item.paperName }}</div>
              <div class="exam-position">{{ item.positionTitle }}</div>
              <div class="exam-time">
                <span>开考 {{ fmt(item.startAt) }}</span>
                <span>截止 {{ fmt(item.endAt) }}</span>
              </div>
              <div class="exam-card-foot">
                <span class="exam-score">{{ item.totalScore }} 分</span>
                <a class="enter-link" :href="appHref(`/exam?scheduleId=${item.scheduleId}`)">进入考试 →</a>
              </div>
            </article>
          </div>
          <div v-else class="empty-state empty-card">
            {{ exams.length ? '没有符合条件的考试' : '暂无笔试安排' }}
            <span>{{ exams.length ? '试试切换其他筛选条件。' : '收到企业笔试通知后，可点击通知中的链接进入考试。' }}</span>
          </div>
        </template>
      </section>
    </main>
    <footer class="footer">© 2026 企业级智能招聘面试官 Agent 系统</footer>
  </div>
</template>

<script setup>
import { appHref } from '@/utils/agentNavigation'
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { getExamEntry, listMyExams } from '@/api/agent/exam'

const route = useRoute()
const router = useRouter()
const scheduleId = computed(() => (route.query.scheduleId ? String(route.query.scheduleId) : null))

const loading = ref(false)
const exams = ref([])
const entry = ref(null)
const loadError = ref('')
const statusFilter = ref('all')
const examFilters = [
  { key: 'all', label: '全部' },
  { key: 'todo', label: '待参加' },
  { key: 'done', label: '已完成' },
  { key: 'invalid', label: '已失效' }
]

const canEnter = computed(() => {
  if (!entry.value) return false
  if (entry.value.recordStatus === 1) return true
  if (entry.value.recordStatus === 2 || entry.value.recordStatus === 4) return false
  return entry.value.status !== 3 && entry.value.openNow
})

const blockedText = computed(() => {
  const e = entry.value
  if (!e) return ''
  if (e.recordStatus === 2 || e.recordStatus === 4) return '已交卷'
  if (e.recordStatus === 3) return '本次考试已作废'
  if (e.status === 3) return '考试已取消'
  if (!e.openNow && e.startAt && new Date(e.startAt.replace(' ', 'T')) > new Date()) return '考试尚未开始'
  return '考试已结束'
})

const entryPillText = computed(() => {
  const e = entry.value
  if (!e) return ''
  if (e.recordStatus === 1) return '进行中'
  if (e.recordStatus === 2 || e.recordStatus === 4) return '已交卷'
  if (e.recordStatus === 3) return '已作废'
  if (e.status === 3) return '已取消'
  if (e.openNow) return '可开考'
  if (e.startAt && new Date(e.startAt.replace(' ', 'T')) > new Date()) return '未开始'
  return '已结束'
})

const entryPillClass = computed(() => {
  const t = entryPillText.value
  if (t === '进行中' || t === '可开考') return 'green'
  if (t === '已交卷') return 'blue'
  if (t === '已作废' || t === '已取消' || t === '已结束') return 'gray'
  return 'orange'
})

function listPillText(item) {
  if (item.recordStatus === 1) return '进行中'
  if (item.recordStatus === 2 || item.recordStatus === 4) return '已交卷'
  if (item.recordStatus === 3) return '已作废'
  if (item.status === 3) return '已取消'
  if (item.openNow) return '可开考'
  if (item.startAt && new Date(item.startAt.replace(' ', 'T')) > new Date()) return '未开始'
  return '已结束'
}

function listPillClass(item) {
  const t = listPillText(item)
  if (t === '进行中' || t === '可开考') return 'green'
  if (t === '已交卷') return 'blue'
  if (t === '已作废' || t === '已取消' || t === '已结束') return 'gray'
  return 'orange'
}

// 筛选分组与状态标签保持一致：待参加（未开始/可开考/进行中）、已完成（已交卷）、已失效（作废/取消/结束）
function examCategory(item) {
  const t = listPillText(item)
  if (t === '已交卷') return 'done'
  if (t === '已作废' || t === '已取消' || t === '已结束') return 'invalid'
  return 'todo'
}

const filteredExams = computed(() =>
  statusFilter.value === 'all' ? exams.value : exams.value.filter((item) => examCategory(item) === statusFilter.value)
)

function fmt(value) {
  return value ? String(value).slice(0, 16) : '--'
}

function goRoom() {
  // 首次进入先做设备检测（双机位考试必须通过检测才开考计时），续考直接回答题页
  const e = entry.value
  if (e && e.recordStatus !== 1) {
    router.push({ path: '/exam-prep', query: { scheduleId: scheduleId.value } })
    return
  }
  // 走路由跳转，自动带上部署子路径（/user/），避免硬编码根路径
  router.push({ path: '/exam-room', query: { scheduleId: scheduleId.value } })
}

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    if (scheduleId.value) {
      const res = await getExamEntry(scheduleId.value)
      entry.value = res.data
    } else {
      const res = await listMyExams()
      exams.value = res.data || []
    }
  } catch (e) {
    loadError.value = e?.message || '加载失败'
  } finally {
    loading.value = false
  }
}

// SPA 内从考试详情返回列表时组件会被复用，需要在 scheduleId 变化时重新加载
watch(scheduleId, () => {
  entry.value = null
  exams.value = []
  load()
})

onMounted(load)
</script>

<style scoped>
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}
.main{width:min(1080px,calc(100% - 48px));margin:0 auto;padding:27px 0 54px}
.page-heading{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;margin-bottom:16px}
.page-heading h1{margin:0;color:#1A3C6E;font-size:25px}
.page-meta{margin-top:4px;color:#96A3B5;font-size:11px}
.list-count{padding:5px 12px;border-radius:999px;color:#2B7FFF;background:#EAF2FF;font-size:11px;font-weight:700}
.entry-card{padding:26px 28px;border:1px solid #E6EBF2;border-radius:12px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045)}
.entry-head{display:flex;align-items:center;gap:14px}
.entry-badge{width:44px;height:44px;display:grid;place-items:center;border-radius:10px;color:#2B7FFF;background:#EAF2FF;font-size:20px;font-weight:800}
.entry-head h1{margin:0;color:#1A3C6E;font-size:20px}
.entry-sub{margin-top:4px;color:#96A3B5;font-size:12px}
.entry-head .status-pill{margin-left:auto}
.entry-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-top:20px}
.entry-item{padding:12px 14px;border:1px solid #EDF1F7;border-radius:8px;background:#F8FAFD}
.entry-item span{display:block;color:#96A3B5;font-size:11px}
.entry-item strong{display:block;margin-top:5px;color:#1A3C6E;font-size:13px}
.entry-note{margin-top:14px;padding:10px 12px;border-radius:8px;color:#D88725;background:#FFF4E6;font-size:12px}
.entry-actions{display:flex;align-items:center;gap:16px;margin-top:22px}
.primary-btn{height:40px;padding:0 26px;border:0;border-radius:8px;color:#fff;background:#2B7FFF;font-size:13px;font-weight:700;cursor:pointer}
.primary-btn:disabled{background:#C3CEDD;cursor:not-allowed}
.ghost-link{color:#2B7FFF;font-size:12px;text-decoration:none}
.list-panel{background:transparent}
.exam-filters{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px}
.filter-chip{height:30px;padding:0 14px;border:1px solid #E6EBF2;border-radius:999px;background:#fff;color:#647894;font-family:inherit;font-size:12px;cursor:pointer;transition:color .15s,border-color .15s,background .15s}
.filter-chip:hover{border-color:#C8D9F0;color:#2B7FFF}
.filter-chip.active{border-color:#2B7FFF;background:#EAF2FF;color:#2B7FFF;font-weight:700}
.exam-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px}
.exam-card{position:relative;display:flex;flex-direction:column;padding:18px 20px;border:1px solid #E6EBF2;border-radius:12px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045);overflow:hidden;transition:transform .18s,box-shadow .18s,border-color .18s}
.exam-card:hover{transform:translateY(-2px);border-color:#C8D9F0;box-shadow:0 10px 26px rgba(26,60,110,.1)}
.exam-card::before{content:"";position:absolute;left:0;top:0;bottom:0;width:3px;background:#E3EAF3}
.exam-card.green::before{background:#20A36F}
.exam-card.blue::before{background:#2B7FFF}
.exam-card.orange::before{background:#D88725}
.exam-card.gray::before{background:#A0ABBA}
.exam-card-head{display:flex;align-items:center;justify-content:space-between;gap:10px}
.exam-duration{padding:4px 9px;border-radius:999px;color:#647894;background:#F2F5FA;font-size:11px}
.exam-title{margin-top:12px;color:#1A3C6E;font-size:16px;font-weight:800;line-height:1.4}
.exam-position{margin-top:6px;color:#647894;font-size:12px}
.exam-time{display:flex;flex-direction:column;gap:2px;margin-top:10px;color:#96A3B5;font-size:11px}
.exam-card-foot{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-top:auto;padding-top:14px;border-top:1px solid #F0F3F8}
.exam-score{color:#1A3C6E;font-size:12px;font-weight:700}
.status-pill{min-width:70px;padding:5px 10px;border-radius:5px;font-size:11px;text-align:center}
.status-pill.green{color:#20A36F;background:#E9F7F1}
.status-pill.blue{color:#2B7FFF;background:#EAF2FF}
.status-pill.orange{color:#D88725;background:#FFF4E6}
.status-pill.gray{color:#60738F;background:#EEF2F7}
.enter-link{padding:8px 14px;border:1px solid #C8D9F0;border-radius:6px;color:#2B7FFF;background:#F7FAFF;font-size:11px;font-weight:700;text-decoration:none;white-space:nowrap;transition:background .15s,border-color .15s}
.enter-link:hover{border-color:#2B7FFF;background:#EAF2FF}
.empty-state{padding:48px 20px;color:#6B7A90;text-align:center;font-size:13px}
.empty-card{border:1px dashed #D7E0EC;border-radius:12px;background:#FBFCFE}
.empty-card span{display:block;margin-top:6px;color:#96A3B5;font-size:11px}
.footer{padding:16px;color:#A0ABBA;font-size:10px;text-align:center}
@media(max-width:720px){.main{width:calc(100% - 28px)}.entry-grid{grid-template-columns:repeat(2,1fr)}.exam-grid{grid-template-columns:1fr}.page-heading{align-items:center}}
</style>
