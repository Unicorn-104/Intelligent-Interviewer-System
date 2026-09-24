<template>
  <div class="app-container home-page">
    <div class="dashboard-heading">
      <div>
        <div class="page-kicker">AI 招聘运营中心</div>
        <h1>招聘运营工作台</h1>
        <p>从岗位发布到面试评估，集中处理招聘链路中的关键待办。</p>
      </div>
      <div class="heading-actions">
        <span v-if="lastUpdated" class="last-updated">更新于 {{ lastUpdated }}</span>
        <el-button :loading="loading" :icon="Refresh" @click="loadDashboard">刷新数据</el-button>
      </div>
    </div>

    <!-- 顶部统计卡片区 -->
    <div class="stat-cards">
      <div v-for="card in statCards" :key="card.label" class="stat-card-item" @click="handleStatClick(card)">
        <div class="stat-icon-wrap" :class="card.iconClass">
          <el-icon :size="24"><component :is="card.icon" /></el-icon>
        </div>
        <div class="stat-info">
          <div class="stat-label">{{ card.label }}</div>
          <div class="stat-value">{{ card.value }}</div>
          <div class="stat-extra" :class="{ negative: card.negative }">
            {{ card.extra }}
          </div>
        </div>
      </div>
    </div>

    <el-alert v-if="loadError" class="dashboard-alert" :title="loadError" type="warning" show-icon :closable="false" />

    <!-- 招聘闭环工作台 -->
    <div class="workflow-layout">
      <div class="section-card pipeline-section">
        <div class="section-header">
          <span>招聘流程总览</span>
          <span class="header-hint">岗位发布 → 投递 → 初筛 → 面试 → 评估</span>
        </div>
        <div class="pipeline-grid">
          <button
            v-for="(item, index) in overview.pipeline"
            :key="item.key"
            type="button"
            class="pipeline-item"
            @click="goTo(item.route)"
          >
            <div class="pipeline-index">0{{ index + 1 }}</div>
            <div class="pipeline-icon" :class="item.tone">
              <el-icon :size="20"><component :is="item.icon" /></el-icon>
            </div>
            <div class="pipeline-copy">
              <strong>{{ item.label }}</strong>
              <b>{{ formatNum(item.value) }}</b>
              <small>{{ item.detail }}</small>
            </div>
            <el-icon class="pipeline-arrow"><ArrowRight /></el-icon>
          </button>
        </div>
      </div>

      <div class="section-card todo-section">
        <div class="section-header">
          <span>待办与风险</span>
          <span class="header-hint">需要优先处理</span>
        </div>
        <button v-for="todo in overview.todos" :key="todo.id" type="button" class="todo-item" @click="goTo(todo.route)">
          <span class="todo-dot" :class="todo.tone"></span>
          <span class="todo-copy">
            <strong>{{ todo.title }}</strong>
            <small>{{ todo.detail }}</small>
          </span>
          <b>{{ todo.count }}</b>
          <el-icon><ArrowRight /></el-icon>
        </button>
      </div>

      <div class="section-card funnel-section">
        <div class="section-header">
          <span>招聘转化漏斗</span>
          <span class="header-hint">本周期</span>
        </div>
        <div class="funnel-list">
          <div v-for="(item, index) in overview.funnel" :key="item.name" class="funnel-row">
            <span>{{ item.name }}</span>
            <div class="funnel-track">
              <i :style="{ width: `${funnelWidth(item.value)}%` }" :class="`funnel-${index}`"></i>
            </div>
            <b>{{ formatNum(item.value) }}</b>
          </div>
        </div>
      </div>
    </div>

    <!-- 中部图表区 -->
    <div class="chart-sections">
      <div class="section-card chart-trend">
        <div class="section-header">
          <span>近 30 天平台数据趋势</span>
          <el-radio-group v-model="trendRange" size="default" class="filter-group">
            <el-radio-button value="30">近30天</el-radio-button>
            <el-radio-button value="7">近7天</el-radio-button>
          </el-radio-group>
        </div>
        <div ref="trendChartRef" class="chart chart-lg"></div>
      </div>
      <div class="section-card chart-distribution">
        <div class="section-header">
          <span>套餐分布</span>
        </div>
        <div ref="pieChartRef" class="chart chart-lg"></div>
      </div>
    </div>

    <!-- 底部双列区 -->
    <div class="bottom-sections">
      <div class="section-card">
        <div class="section-header">
          <span>企业 API 调用量 TOP10</span>
          <span class="header-hint">超配额 80% 标橙色预警</span>
        </div>
        <div ref="topChartRef" class="chart chart-sm"></div>
      </div>
      <div class="section-card">
        <div class="section-header">
          <span>最近操作动态</span>
        </div>
        <div class="timeline-wrap">
          <el-timeline>
            <el-timeline-item
              v-for="log in recentLogs"
              :key="log.operTime"
              :timestamp="log.operTime"
              placement="top"
              :type="log.level === 'danger' ? 'danger' : log.level === 'warn' ? 'warning' : 'primary'"
            >
              <span class="log-oper">{{ log.operName }}</span>
              <span class="log-content">{{ log.content }}</span>
            </el-timeline-item>
          </el-timeline>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup name="Index">
import * as echarts from 'echarts'
import { ArrowRight, Refresh } from '@element-plus/icons-vue'
import { useRouter } from 'vue-router'
import {
  listStats,
  listTrend,
  listPackageDist,
  listApiTop,
  listRecentLogs,
  listRecruitmentOverview
} from '@/api/dashboard'

const trendChartRef = ref(null)
const pieChartRef = ref(null)
const topChartRef = ref(null)
const trendRange = ref('30')
const recentLogs = ref([])
const overview = ref({ pipeline: [], todos: [], funnel: [] })
const loading = ref(false)
const loadError = ref('')
const lastUpdated = ref('')
const router = useRouter()
const stats = ref({})

let trendChart = null
let pieChart = null
let topChart = null

const statCards = computed(() => [
  {
    label: '租户企业总数',
    value: stats.value.companyTotal ?? '-',
    extra: '较上月 +' + (stats.value.companyGrowth || 0),
    icon: 'OfficeBuilding',
    iconClass: 'blue',
    route: '/tenant/company',
    negative: false
  },
  {
    label: '本月活跃企业',
    value: stats.value.companyActive ?? '-',
    extra: '活跃率 ' + (stats.value.activeRate || '-'),
    icon: 'Lightning',
    iconClass: 'orange',
    route: '/tenant/company',
    negative: false
  },
  {
    label: '候选人总数',
    value: formatNum(stats.value.candidateTotal),
    extra: '较昨日 +' + (stats.value.candidateGrowth || 0),
    icon: 'User',
    iconClass: 'green',
    route: '/member/user',
    negative: false
  },
  {
    label: '今日 AI 调用量',
    value: formatNum(stats.value.todayApiCalls),
    extra: '配额使用 ' + (stats.value.apiQuotaUsage || '-'),
    icon: 'Cpu',
    iconClass: 'red',
    route: '/ai/quota',
    negative: true
  },
  {
    label: '投递总量',
    value: formatNum(stats.value.applicationTotal),
    extra: '较昨日 +' + (stats.value.applicationGrowth || 0),
    icon: 'Tickets',
    iconClass: 'purple',
    route: '/biz/resume',
    negative: false
  },
  {
    label: '今日简历解析',
    value: formatNum(stats.value.todayResumes),
    extra: '解析成功率 ' + (stats.value.resumeSuccessRate || '-'),
    icon: 'Document',
    iconClass: 'blue',
    route: '/biz/resumeParse',
    negative: false
  },
  {
    label: '今日面试场次',
    value: formatNum(stats.value.todayInterviews),
    extra: '覆盖企业 ' + (stats.value.companyActive || '-') + ' 家',
    icon: 'VideoCamera',
    iconClass: 'green',
    route: '/supervise/interview',
    negative: false
  },
  {
    label: '初筛通过率',
    value: stats.value.screenPassRate ?? '-',
    extra: '规则粗排 + LLM 深析',
    icon: 'DataAnalysis',
    iconClass: 'orange',
    route: '/biz/aiScreen',
    negative: true
  }
])

function formatNum(n) {
  if (n === undefined || n === null) return '-'
  return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

function handleStatClick(card) {
  goTo(card.route)
}

function goTo(path) {
  if (path) router.push(path)
}

function funnelWidth(value) {
  const max = overview.value.funnel?.[0]?.value || 1
  return Math.max(8, Math.round((Number(value) / max) * 100))
}

async function loadDashboard() {
  loading.value = true
  loadError.value = ''
  const results = await Promise.allSettled([
    listStats(),
    listTrend(),
    listPackageDist(),
    listApiTop(),
    listRecentLogs(),
    listRecruitmentOverview()
  ])
  const [statsRes, trendRes, packageRes, apiRes, logsRes, overviewRes] = results
  if (statsRes.status === 'fulfilled') stats.value = statsRes.value?.data || {}
  if (trendRes.status === 'fulfilled') initTrend(trendRes.value?.data || {})
  if (packageRes.status === 'fulfilled') initPie(packageRes.value?.data || [])
  if (apiRes.status === 'fulfilled') initTop(apiRes.value?.data || [])
  if (logsRes.status === 'fulfilled') recentLogs.value = logsRes.value?.data || []
  if (overviewRes.status === 'fulfilled') {
    overview.value = overviewRes.value?.data || { pipeline: [], todos: [], funnel: [] }
    lastUpdated.value = overview.value.asOf || ''
  }
  const failed = results.filter((item) => item.status === 'rejected')
  if (failed.length) {
    loadError.value = `有 ${failed.length} 项数据加载失败，请稍后刷新重试`
    failed.forEach((item) => console.error('仪表盘数据加载失败', item.reason))
  }
  loading.value = false
}

function initTrend(data) {
  if (!trendChartRef.value) return
  if (!trendChart) trendChart = echarts.init(trendChartRef.value)
  const sliceN = Number(trendRange.value)
  trendChart.setOption({
    tooltip: {
      trigger: 'axis',
      backgroundColor: '#fff',
      borderColor: '#EBEEF5',
      textStyle: { color: '#1D2129' }
    },
    legend: {
      data: ['新注册企业', '活跃候选人', 'AI 面试完成次数', '投递量'],
      bottom: 0,
      textStyle: { color: '#86909C', fontSize: 12 }
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '12%',
      top: '8%',
      containLabel: true
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: data.dates.slice(-sliceN),
      axisLine: { lineStyle: { color: '#E5E6E8' } },
      axisTick: { show: false },
      axisLabel: { color: '#86909C', fontSize: 11 }
    },
    yAxis: {
      type: 'value',
      splitLine: { lineStyle: { color: '#F5F7FA' } },
      axisLabel: { color: '#86909C', fontSize: 11 }
    },
    series: [
      {
        name: '新注册企业',
        type: 'line',
        smooth: true,
        data: data.companies.slice(-sliceN),
        lineStyle: { width: 2.5 },
        itemStyle: { color: '#2F80ED' },
        symbol: 'circle',
        symbolSize: 6
      },
      {
        name: '活跃候选人',
        type: 'line',
        smooth: true,
        data: data.candidates.slice(-sliceN),
        lineStyle: { width: 2.5 },
        itemStyle: { color: '#22C55E' },
        symbol: 'circle',
        symbolSize: 6
      },
      {
        name: 'AI 面试完成次数',
        type: 'line',
        smooth: true,
        data: data.interviews.slice(-sliceN),
        lineStyle: { width: 2.5 },
        itemStyle: { color: '#F59E0B' },
        symbol: 'circle',
        symbolSize: 6
      },
      {
        name: '投递量',
        type: 'line',
        smooth: true,
        data: (data.applications || []).slice(-sliceN),
        lineStyle: { width: 2.5 },
        itemStyle: { color: '#EF4444' },
        symbol: 'circle',
        symbolSize: 6
      }
    ]
  })
}

function initPie(data) {
  if (!pieChartRef.value) return
  if (!pieChart) pieChart = echarts.init(pieChartRef.value)
  else pieChart.clear()
  pieChart.setOption({
    tooltip: {
      trigger: 'item',
      backgroundColor: '#fff',
      borderColor: '#EBEEF5',
      textStyle: { color: '#1D2129' },
      formatter: '{b}: {c} 家 ({d}%)'
    },
    legend: {
      orient: 'vertical',
      left: 'left',
      top: 'middle',
      textStyle: { color: '#4E5969', fontSize: 12 },
      itemWidth: 12,
      itemHeight: 12,
      itemGap: 16
    },
    series: [
      {
        name: '套餐分布',
        type: 'pie',
        radius: ['42%', '68%'],
        center: ['58%', '55%'],
        avoidLabelOverlap: true,
        itemStyle: { borderRadius: 6, borderColor: '#fff', borderWidth: 2 },
        label: {
          show: true,
          formatter: '{b}\n{c} 家',
          fontSize: 12,
          color: '#4E5969'
        },
        emphasis: { label: { show: true, fontSize: 14, fontWeight: 'bold' } },
        data: [
          {
            value: (data.find((d) => d.name === '基础版') || {}).value || 0,
            name: '基础版',
            itemStyle: { color: '#909399' }
          },
          {
            value: (data.find((d) => d.name === '专业版') || {}).value || 0,
            name: '专业版',
            itemStyle: { color: '#2F80ED' }
          },
          {
            value: (data.find((d) => d.name === '旗舰版') || {}).value || 0,
            name: '旗舰版',
            itemStyle: { color: '#F59E0B' }
          }
        ]
      }
    ]
  })
}

function initTop(data) {
  if (!topChartRef.value) return
  if (!topChart) topChart = echarts.init(topChartRef.value)
  else topChart.clear()
  const sorted = [...data].sort((a, b) => b.calls - a.calls).slice(0, 10)
  topChart.setOption({
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      backgroundColor: '#fff',
      borderColor: '#EBEEF5',
      textStyle: { color: '#1D2129' },
      formatter: (params) => {
        const p = params[0]
        const item = sorted[p.dataIndex]
        return item.companyName + '<br/>调用量：' + item.calls + ' / ' + item.quota + '<br/>占比：' + item.percent + '%'
      }
    },
    grid: {
      left: '3%',
      right: '14%',
      bottom: '3%',
      top: '4%',
      containLabel: true
    },
    xAxis: {
      type: 'value',
      splitLine: { lineStyle: { color: '#F5F7FA' } },
      axisLabel: { color: '#86909C', fontSize: 11 }
    },
    yAxis: {
      type: 'category',
      data: sorted.map((d) => d.companyName),
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: {
        color: '#4E5969',
        fontSize: 11,
        width: 120,
        overflow: 'truncate'
      }
    },
    series: [
      {
        name: 'API 调用量',
        type: 'bar',
        barWidth: '45%',
        itemStyle: {
          borderRadius: [0, 4, 4, 0],
          color: (params) => (params.value.percent > 80 ? '#F59E0B' : '#2F80ED')
        },
        label: {
          show: true,
          position: 'right',
          formatter: '{c}',
          color: '#4E5969',
          fontSize: 11
        }
      }
    ]
  })
}

function resizeCharts() {
  trendChart && trendChart.resize()
  pieChart && pieChart.resize()
  topChart && topChart.resize()
}

onMounted(() => {
  loadDashboard()
  window.addEventListener('resize', resizeCharts)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', resizeCharts)
  trendChart && trendChart.dispose()
  pieChart && pieChart.dispose()
  topChart && topChart.dispose()
})

watch(trendRange, () => {
  listTrend()
    .then((res) => initTrend(res.data || {}))
    .catch((error) => {
      loadError.value = '趋势数据加载失败，请稍后刷新重试'
      console.error('趋势数据加载失败', error)
    })
})
</script>

<style lang="scss" scoped>
.home-page {
  max-width: 1680px;
  margin: 0 auto;
  padding: 26px 28px 36px;
  display: flex;
  flex-direction: column;

  .dashboard-heading {
    order: 1;
  }
  .stat-cards {
    order: 2;
  }
  .dashboard-alert {
    order: 3;
  }
  .chart-sections {
    order: 4;
  }
  .workflow-layout {
    order: 5;
  }
  .bottom-sections {
    order: 6;
  }

  .dashboard-heading {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 20px;
    margin: 0 0 20px;
    h1 {
      margin: 3px 0 6px;
      color: #1d2129;
      font-size: 24px;
      line-height: 1.25;
    }
    p {
      margin: 0;
      color: #86909c;
      font-size: 13px;
    }
  }
  .page-kicker {
    color: #8b5cf6;
    font-size: 12px;
    font-weight: 600;
    letter-spacing: 0.08em;
  }
  .heading-actions {
    display: flex;
    align-items: center;
    gap: 12px;
    padding-top: 8px;
  }
  .last-updated {
    color: #86909c;
    font-size: 12px;
  }
  .dashboard-alert {
    margin: -4px 0 16px;
  }
  .workflow-layout {
    display: grid;
    grid-template-columns: minmax(0, 2fr) minmax(280px, 1fr);
    gap: 16px;
    margin-bottom: 16px;
  }
  .pipeline-section {
    grid-row: span 2;
  }
  .pipeline-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 10px;
  }
  .pipeline-item,
  .todo-item {
    appearance: none;
    border: 0;
    font: inherit;
    text-align: left;
    cursor: pointer;
  }
  .pipeline-item {
    position: relative;
    display: flex;
    align-items: center;
    min-width: 0;
    min-height: 112px;
    padding: 14px;
    background: #f8fafc;
    border: 1px solid #eef1f5;
    border-radius: 6px;
    transition:
      border-color 0.2s ease,
      background 0.2s ease;
    &:hover {
      background: #f1f6ff;
      border-color: #b8d2ff;
    }
  }
  .pipeline-index {
    position: absolute;
    top: 12px;
    right: 12px;
    color: #c9d2df;
    font-size: 11px;
    font-weight: 700;
  }
  .pipeline-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 38px;
    height: 38px;
    margin: 0 10px 0 0;
    color: #fff;
    border-radius: 6px;
    &.blue {
      background: #7c3aed;
    }
    &.green {
      background: #22c55e;
    }
    &.orange {
      background: #f59e0b;
    }
    &.purple {
      background: #7c5cff;
    }
    &.red {
      background: #ef4444;
    }
    &.teal {
      background: #0f9f9a;
    }
  }
  .pipeline-copy {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-width: 0;
    strong,
    b,
    small {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    strong {
      color: #4e5969;
      font-size: 13px;
    }
    b {
      margin: 4px 0 2px;
      color: #1d2129;
      font-size: 22px;
      line-height: 1.1;
    }
    small {
      color: #86909c;
      font-size: 12px;
    }
  }
  .pipeline-arrow,
  .todo-item > .el-icon {
    flex-shrink: 0;
    color: #c9d2df;
  }
  .todo-item {
    display: flex;
    align-items: center;
    width: 100%;
    min-height: 48px;
    padding: 8px 0;
    background: transparent;
    border-bottom: 1px solid #f2f3f5;
    &:last-child {
      border-bottom: 0;
    }
    &:hover .todo-copy strong {
      color: #7c3aed;
    }
  }
  .todo-dot {
    width: 8px;
    height: 8px;
    margin-right: 10px;
    border-radius: 50%;
    &.danger {
      background: #ef4444;
    }
    &.warning {
      background: #f59e0b;
    }
    &.primary {
      background: #7c3aed;
    }
    &.info {
      background: #909399;
    }
  }
  .todo-copy {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-width: 0;
    strong {
      color: #1d2129;
      font-size: 13px;
      font-weight: 500;
    }
    small {
      margin-top: 3px;
      color: #86909c;
      font-size: 12px;
    }
  }
  .todo-item > b {
    margin-right: 12px;
    color: #1d2129;
    font-size: 16px;
  }
  .funnel-list {
    padding-top: 3px;
  }
  .funnel-row {
    display: grid;
    grid-template-columns: 72px minmax(0, 1fr) 48px;
    align-items: center;
    gap: 10px;
    min-height: 34px;
    color: #4e5969;
    font-size: 12px;
    b {
      color: #1d2129;
      text-align: right;
    }
  }
  .funnel-track {
    height: 8px;
    overflow: hidden;
    background: #edf1f7;
    border-radius: 4px;
    i {
      display: block;
      height: 100%;
      border-radius: 4px;
    }
    .funnel-0 {
      background: #7c3aed;
    }
    .funnel-1 {
      background: #4c8dff;
    }
    .funnel-2 {
      background: #22c55e;
    }
    .funnel-3 {
      background: #f59e0b;
    }
    .funnel-4 {
      background: #ef4444;
    }
  }
  .stat-cards {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 16px;
    margin-bottom: 20px;
    @media (max-width: 1100px) {
      grid-template-columns: repeat(2, 1fr);
    }
    @media (max-width: 768px) {
      grid-template-columns: 1fr;
    }
  }

  .stat-card-item {
    position: relative;
    display: flex;
    align-items: center;
    min-height: 104px;
    background: #fff;
    border-radius: 6px;
    padding: 16px 18px;
    box-shadow: 0 1px 2px rgba(23, 36, 61, 0.04);
    border: 1px solid #ebeef5;
    transition: all 0.3s ease;
    cursor: pointer;
    &:hover {
      border-color: #d7c1f5;
      box-shadow: 0 4px 14px rgba(111, 53, 201, 0.09);
    }

    &:first-child {
      background: linear-gradient(135deg, #33204f 0%, #5c367f 100%);
      border-color: #5c367f;
      box-shadow: 0 8px 18px rgba(70, 37, 100, 0.16);

      .stat-label,
      .stat-value,
      .stat-extra {
        color: #ffffff;
      }

      .stat-extra {
        opacity: 0.76;
      }
      .stat-icon-wrap {
        background: rgba(255, 255, 255, 0.16);
      }
    }
  }

  .stat-icon-wrap {
    width: 48px;
    height: 48px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    margin-right: 14px;
    i {
      font-size: 24px !important;
      color: #fff !important;
    }
    &.blue {
      background: #7c3aed;
    }
    &.green {
      background: #22c55e;
    }
    &.orange {
      background: #f59e0b;
    }
    &.red {
      background: #ef4444;
    }
    &.purple {
      background: #7c5cff;
    }
  }

  .stat-info {
    flex: 1;
    min-width: 0;
  }
  .stat-label {
    font-size: 13px;
    color: #86909c;
    font-weight: 500;
    margin-bottom: 4px;
  }
  .stat-value {
    font-size: 28px;
    font-weight: 700;
    color: #1d2129;
    line-height: 1.2;
  }
  .stat-extra {
    font-size: 12px;
    color: #22c55e;
    margin-top: 4px;
    &.negative {
      color: #ef4444;
    }
  }

  .chart-sections {
    display: grid;
    grid-template-columns: minmax(0, 1.7fr) minmax(340px, 0.8fr);
    gap: 18px;
    margin-bottom: 16px;
    @media (max-width: 992px) {
      grid-template-columns: 1fr;
    }
  }
  .bottom-sections {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
    margin-bottom: 20px;
    @media (max-width: 992px) {
      grid-template-columns: 1fr;
    }
  }

  .section-card {
    background: #fff;
    border-radius: 12px;
    padding: 18px;
    box-shadow: 0 2px 10px rgba(72, 47, 105, 0.04);
    border: 1px solid #e8e1ef;
    transition: box-shadow 0.3s ease;
    &:hover {
      box-shadow: 0 5px 16px rgba(111, 53, 201, 0.08);
    }
  }

  .chart-distribution {
    min-width: 0;
    min-height: 340px;
  }

  @media (max-width: 1200px) {
    .pipeline-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }
  @media (max-width: 992px) {
    .workflow-layout {
      grid-template-columns: 1fr;
    }
    .pipeline-section {
      grid-row: auto;
    }
  }
  @media (max-width: 600px) {
    padding: 16px;
    .dashboard-heading {
      flex-direction: column;
    }
    .heading-actions {
      width: 100%;
      justify-content: space-between;
    }
    .pipeline-grid {
      grid-template-columns: 1fr;
    }
    .section-card {
      padding: 16px;
    }
    .chart-lg {
      height: 260px;
    }
    .section-header {
      align-items: flex-start;
      gap: 8px;
    }
    .section-header .header-hint {
      text-align: right;
    }
  }

  .section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
    padding-bottom: 12px;
    border-bottom: 1px solid #f5f7fa;
    > span:first-child {
      font-size: 15px;
      font-weight: 600;
      color: #1d2129;
      position: relative;
      padding-left: 10px;
      &::before {
        content: '';
        position: absolute;
        left: 0;
        top: 50%;
        transform: translateY(-50%);
        width: 3px;
        height: 16px;
        background: #8b5cf6;
        border-radius: 3px;
      }
    }
    .header-hint {
      padding-left: 0;
      color: #86909c;
      font-size: 12px;
      font-weight: 400;
      &::before {
        display: none;
      }
    }
  }

  .header-hint {
    font-size: 12px;
    color: #86909c;
    font-weight: normal;
    padding-left: 0;
  }
  .filter-group {
    flex-shrink: 0;
  }
  .chart {
    width: 100%;
  }
  .chart-lg {
    height: 300px;
  }
  .chart-sm {
    height: 320px;
  }

  .timeline-wrap {
    max-height: 360px;
    overflow-y: auto;
  }
  .log-oper {
    font-weight: 600;
    color: #1d2129;
    margin-right: 6px;
    font-size: 13px;
  }
  .log-content {
    color: #4e5969;
    font-size: 13px;
  }
  :deep(.el-timeline-item__timestamp) {
    color: #86909c;
    font-size: 12px;
  }
  .timeline-wrap::-webkit-scrollbar {
    width: 4px;
  }
  .timeline-wrap::-webkit-scrollbar-thumb {
    background: #dcdfe6;
    border-radius: 2px;
  }

  @media (max-width: 1200px) {
    padding-right: 20px;
    padding-left: 20px;
    .pipeline-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }
}
</style>
