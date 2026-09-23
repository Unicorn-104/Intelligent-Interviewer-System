<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { BriefcaseBusiness, FileText, Clock3, CircleCheckBig, ArrowUpRight, CalendarDays, UserRoundCheck, Timer, Sparkles, Plus } from '@/views/enterprise/components/icons'
import StatCard from '@/views/enterprise/components/StatCard.vue'
import PublishJobModal from '@/views/enterprise/components/PublishJobModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { api, reserveApi } from '@/views/enterprise/api/contract'

const router = useRouter()
const publishOpen = ref(false)
const toast = ref('')
reserveApi(api.positions.list, { status: 1, keyword: '', page: 1, pageSize: 5 })
reserveApi({ method: 'GET', path: '/api/v1/positions/{positionId}/application-statistics', params: ['positionId', 'from', 'to'] }, { positionId: 1, from: '2026-09-01', to: '2026-09-30' })
const statItems = [
  { title: '在招岗位数', value: 36, note: '↗ 环比 +12.5%', tone: 'blue', icon: BriefcaseBusiness },
  { title: '简历总量', value: '1,286', note: '本月新增 +186', tone: 'blue', icon: FileText },
  { title: '待处理面试', value: 8, note: '需尽快安排 2 场', tone: 'orange', icon: Clock3 },
  { title: '本周已完成面试', value: 26, note: '完成率 93%', tone: 'green', icon: CircleCheckBig }
]
const bars = [
  { label: '简历投递', value: 320, height: 100 },
  { label: '初筛通过', value: 218, height: 68 },
  { label: '面试中', value: 142, height: 45 },
  { label: '已录用', value: 76, height: 25 }
]
const todos = [
  { title: '待确认面试', meta: '产品经理 · 王芳 · 今天 14:00', icon: CalendarDays, tone: 'blue', go: '/enterprise/interviews' },
  { title: '待终审候选人', meta: '高级前端工程师 · 李强', icon: UserRoundCheck, tone: 'cyan', go: '/enterprise/jobs/1' },
  { title: '即将开始的面试', meta: 'UI 设计师 · 张敏 · 15:30', icon: Timer, tone: 'orange', go: '/enterprise/meeting/ai' }
]
const timeline = [
  ['王芳的简历已入库 · 应聘产品经理', '10 分钟前'],
  ['李强已通过初筛，进入面试环节', '1 小时前'],
  ['张敏的面试已安排 · UI 设计师 · 今天 15:30', '3 小时前'],
  ['陈晨已通过终审，进入录用审批', '昨天 18:24']
]
function published() { publishOpen.value = false; toast.value = '岗位已成功发布'; setTimeout(() => toast.value = '', 2200) }
</script>

<template>
  <div class="page dashboard">
    <div class="page-heading">
      <div><h1>早上好，王经理</h1><p>2026年9月9日 星期三 · 今天也要发现优秀的人才</p></div>
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
        <div class="chart-foot"><span><i class="legend" />当前周期</span><span>转化率 <b>23.8%</b></span></div>
      </section>

      <section class="card todo-card">
        <div class="section-title"><span>待办事项</span><span class="pill">3 项待处理</span></div>
        <div class="todos">
          <article v-for="todo in todos" :key="todo.title">
            <span class="todo-icon" :class="todo.tone"><component :is="todo.icon" :size="18" /></span>
            <div><b>{{ todo.title }}</b><small>{{ todo.meta }}</small></div>
            <button class="btn sm" @click="router.push(todo.go)">去处理<ArrowUpRight :size="13" /></button>
          </article>
        </div>
        <button class="ai-note"><Sparkles :size="16"/><span><b>AI 今日建议</b>优先处理 14:00 的产品经理面试，候选人匹配度 94%</span></button>
      </section>
    </div>

    <section class="card activity-card">
      <div class="section-title"><span>最近动态</span><button>查看全部</button></div>
      <div class="timeline">
        <div v-for="(item, index) in timeline" :key="item[0]" class="timeline-row">
          <span class="node" :class="{ last: index === timeline.length - 1 }" />
          <b>{{ item[0] }}</b><time>{{ item[1] }}</time>
        </div>
      </div>
    </section>
    <PublishJobModal v-if="publishOpen" @close="publishOpen = false" @submit="published" />
    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:15px;margin-bottom:16px}.overview-grid{display:grid;grid-template-columns:minmax(0,1.8fr) minmax(330px,.92fr);gap:16px;margin-bottom:16px}.chart-card,.todo-card{height:300px;padding:20px}.section-title small{font-size:12px;color:#99a6b8;font-weight:400}.chart{height:205px;padding:28px 35px 0;display:flex;gap:11%;align-items:flex-end;border-bottom:1px solid #dfe7f1}.bar-wrap{height:100%;flex:1;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;position:relative}.bar{width:55px;min-height:12px;border-radius:8px 8px 1px 1px;background:linear-gradient(180deg,#2869ee,#0ea5e9);position:relative}.bar i{position:absolute;inset:0;background:linear-gradient(90deg,transparent,rgba(255,255,255,.15),transparent)}.bar-value{font-size:12px;font-weight:700;margin-bottom:7px}.bar-wrap label{position:absolute;top:calc(100% + 11px);white-space:nowrap;color:#75849a;font-size:12px}.chart-foot{display:flex;justify-content:space-between;margin:31px 4px 0;font-size:11px;color:#8b98ac}.chart-foot span{display:flex;gap:6px;align-items:center}.chart-foot b{color:var(--primary)}.legend{width:8px;height:8px;border-radius:3px;background:var(--primary)}.todos{display:flex;flex-direction:column;gap:9px;margin-top:15px}.todos article{display:flex;align-items:center;gap:11px;padding:10px;border-radius:11px;background:#f5f8fc}.todo-icon{width:34px;height:34px;border-radius:9px;display:grid;place-items:center;background:#e6efff;color:#2563eb}.todo-icon.cyan{background:#e5f8fa;color:#069bad}.todo-icon.orange{background:#fff1dc;color:#f18908}.todos article div{min-width:0;flex:1}.todos b,.todos small{display:block}.todos b{font-size:12px}.todos small{font-size:10px;color:#8b99ad;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.ai-note{width:100%;border:0;background:#edf4ff;color:#526b94;border-radius:10px;margin-top:10px;padding:8px 10px;display:flex;text-align:left;gap:9px;font-size:10px}.ai-note svg{color:var(--primary);flex:none}.ai-note b{display:block;color:#315289;margin-bottom:2px}.activity-card{padding:18px 20px 16px}.section-title button{border:0;background:none;color:var(--primary);font-size:12px}.timeline{margin-top:15px}.timeline-row{height:37px;display:flex;align-items:center;gap:13px;position:relative}.timeline-row .node{width:8px;height:8px;border-radius:50%;background:#2d6ff2;margin-left:4px;position:relative}.timeline-row .node:not(.last)::after{content:'';position:absolute;left:3px;top:8px;width:2px;height:30px;background:#dbe7fd}.timeline-row b{font-size:12px;font-weight:500}.timeline-row time{margin-left:auto;color:#95a3b7;font-size:11px}
</style>



