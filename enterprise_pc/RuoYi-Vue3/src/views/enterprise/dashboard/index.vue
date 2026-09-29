<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { BriefcaseBusiness, FileText, Clock3, CircleCheckBig, ArrowUpRight, CalendarDays, UserRoundCheck, Timer, Sparkles, Plus } from '@/views/enterprise/components/icons'
import StatCard from '@/views/enterprise/components/StatCard.vue'
import PublishJobModal from '@/views/enterprise/components/PublishJobModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { getDashboardOverview } from '@/api/system/dashboard'
import useUserStore from '@/store/modules/user'

const router = useRouter()
const userStore = useUserStore()
const publishOpen = ref(false)
const toast = ref('')

const overview = ref(null)
onMounted(() => {
  getDashboardOverview().then(res => { overview.value = res.data })
})

// 问候语：按当前小时动态生成 + 真实昵称
const greeting = computed(() => {
  const h = new Date().getHours()
  const word = h < 6 ? '夜深了' : h < 12 ? '早上好' : h < 14 ? '中午好' : h < 18 ? '下午好' : '晚上好'
  return `${word}，${userStore.nickName || userStore.name || '经理'}`
})
const todayText = computed(() => {
  const d = new Date()
  const week = ['日', '一', '二', '三', '四', '五', '六'][d.getDay()]
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日 星期${week} · 今天也要发现优秀的人才`
})

const statItems = computed(() => {
  const s = overview.value?.stats || {}
  return [
    { title: '在招岗位数', value: s.activePositions ?? '-', note: '招聘进行中', tone: 'blue', icon: BriefcaseBusiness },
    { title: '简历总量', value: s.resumeCount ?? '-', note: '候选人简历', tone: 'blue', icon: FileText },
    { title: '待处理面试', value: s.pendingInterviews ?? '-', note: '待确认/已确认', tone: 'orange', icon: Clock3 },
    { title: '本周已完成面试', value: s.weeklyCompleted ?? '-', note: '统计周期：本周一起', tone: 'green', icon: CircleCheckBig }
  ]
})

const bars = computed(() => {
  const f = overview.value?.funnel || {}
  const max = f.applied || 1
  const items = [
    { label: '简历投递', value: f.applied ?? 0 },
    { label: '初筛通过', value: f.screened ?? 0 },
    { label: '面试中', value: f.interviewing ?? 0 },
    { label: '已录用', value: f.hired ?? 0 }
  ]
  return items.map(b => ({ ...b, height: Math.max(Math.round(b.value * 100 / max), 6) }))
})
const conversion = computed(() => overview.value?.funnel?.conversion ?? 0)

const TODO_ICONS = { '待确认面试': CalendarDays, '待终审候选人': UserRoundCheck, '即将开始的面试': Timer }
const todos = computed(() => (overview.value?.todos || []).map(t => ({ ...t, icon: TODO_ICONS[t.title] || CalendarDays })))
const timeline = computed(() => overview.value?.timeline || [])
function published() { publishOpen.value = false; toast.value = '岗位已成功发布'; setTimeout(() => toast.value = '', 2200) }
</script>

<template>
  <div class="page dashboard">
    <div class="page-heading">
      <div><h1>{{ greeting }}</h1><p>{{ todayText }}</p></div>
      <button class="btn primary" @click="publishOpen = true"><Plus :size="17" />快速发布岗位</button>
    </div>

    <div class="stats"><StatCard v-for="item in statItems" :key="item.title" v-bind="item" /></div>

    <div class="overview-grid">
      <section class="card chart-card">
        <div class="section-title"><span>招聘进度概览</span><small>近 30 天</small></div>
        <div class="chart">
          <div v-for="bar in bars" :key="bar.label" class="bar-wrap">
            <span class="bar-value">{{ bar.value }}</span>
            <div class="bar" :style="{ height: `${bar.height}%` }"><i /></div>
            <label>{{ bar.label }}</label>
          </div>
        </div>
        <div class="chart-foot"><span><i class="legend" />当前周期</span><span>转化率 <b>{{ conversion }}%</b></span></div>
      </section>

      <section class="card todo-card">
        <div class="section-title"><span>待办事项</span><span class="pill">{{ todos.length }} 项待处理</span></div>
        <div class="todos">
          <article v-for="todo in todos" :key="todo.title">
            <span class="todo-icon" :class="todo.tone"><component :is="todo.icon" :size="18" /></span>
            <div><b>{{ todo.title }}</b><small>{{ todo.meta }}</small></div>
            <button class="btn sm" @click="router.push(todo.go)">去处理<ArrowUpRight :size="13" /></button>
          </article>
          <p v-if="!todos.length" style="color:#8ca3c0;font-size:12px;padding:14px 4px">当前没有待办事项</p>
        </div>
        <button class="ai-note"><Sparkles :size="16"/><span><b>AI 今日建议</b>优先处理 14:00 的产品经理面试，候选人匹配度 94%</span></button>
      </section>
    </div>

    <section class="card activity-card">
      <div class="section-title"><span>最近动态</span><button>查看全部</button></div>
      <div class="timeline">
        <div v-for="(item, index) in timeline" :key="index" class="timeline-row">
          <span class="node" :class="{ last: index === timeline.length - 1 }" />
          <b>{{ item.text }}</b><time>{{ item.time }}</time>
        </div>
        <p v-if="!timeline.length" style="color:#8ca3c0;font-size:12px;padding:14px 4px">暂无动态</p>
      </div>
    </section>
    <PublishJobModal v-if="publishOpen" @close="publishOpen = false" @submit="published" />
    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:15px;margin-bottom:16px}.overview-grid{display:grid;grid-template-columns:minmax(0,1.8fr) minmax(330px,.92fr);gap:16px;margin-bottom:16px}.chart-card,.todo-card{height:300px;padding:20px}.section-title small{font-size:12px;color:#99a6b8;font-weight:400}.chart{height:205px;padding:28px 35px 0;display:flex;gap:11%;align-items:flex-end;border-bottom:1px solid #dfe7f1}.bar-wrap{height:100%;flex:1;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;position:relative}.bar{width:55px;min-height:12px;border-radius:8px 8px 1px 1px;background:linear-gradient(180deg,#2869ee,#0ea5e9);position:relative}.bar i{position:absolute;inset:0;background:linear-gradient(90deg,transparent,rgba(255,255,255,.15),transparent)}.bar-value{font-size:12px;font-weight:700;margin-bottom:7px}.bar-wrap label{position:absolute;top:calc(100% + 11px);white-space:nowrap;color:#75849a;font-size:12px}.chart-foot{display:flex;justify-content:space-between;margin:31px 4px 0;font-size:11px;color:#8b98ac}.chart-foot span{display:flex;gap:6px;align-items:center}.chart-foot b{color:var(--primary)}.legend{width:8px;height:8px;border-radius:3px;background:var(--primary)}.todos{display:flex;flex-direction:column;gap:9px;margin-top:15px}.todos article{display:flex;align-items:center;gap:11px;padding:10px;border-radius:11px;background:#f5f8fc}.todo-icon{width:34px;height:34px;border-radius:9px;display:grid;place-items:center;background:#e6efff;color:#2563eb}.todo-icon.cyan{background:#e5f8fa;color:#069bad}.todo-icon.orange{background:#fff1dc;color:#f18908}.todos article div{min-width:0;flex:1}.todos b,.todos small{display:block}.todos b{font-size:12px}.todos small{font-size:10px;color:#8b99ad;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.ai-note{width:100%;border:0;background:#edf4ff;color:#526b94;border-radius:10px;margin-top:10px;padding:8px 10px;display:flex;text-align:left;gap:9px;font-size:10px}.ai-note svg{color:var(--primary);flex:none}.ai-note b{display:block;color:#315289;margin-bottom:2px}.activity-card{padding:18px 20px 16px}.section-title button{border:0;background:none;color:var(--primary);font-size:12px}.timeline{margin-top:15px}.timeline-row{height:37px;display:flex;align-items:center;gap:13px;position:relative}.timeline-row .node{width:8px;height:8px;border-radius:50%;background:#2d6ff2;margin-left:4px;position:relative}.timeline-row .node:not(.last)::after{content:'';position:absolute;left:3px;top:8px;width:2px;height:30px;background:#dbe7fd}.timeline-row b{font-size:12px;font-weight:500}.timeline-row time{margin-left:auto;color:#95a3b7;font-size:11px}
</style>



