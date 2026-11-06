<template>
  <div class="app-container">
    <el-row :gutter="16">
      <el-col :span="12">
        <el-card shadow="hover">
          <template #header>候选人状态分布</template>
          <div ref="talChart" style="height:300px"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card shadow="hover">
          <template #header>岗位城市 TOP10</template>
          <div ref="cityChart" style="height:300px"></div>
        </el-card>
      </el-col>
    </el-row>
    <el-row :gutter="16" style="margin-top:16px">
      <el-col :span="24">
        <el-card shadow="hover">
          <template #header>近7天投递趋势</template>
          <div v-if="trendEmpty" style="height:300px;display:flex;align-items:center;justify-content:center;color:#999">近7天无投递数据</div>
          <div v-else ref="trendChart" style="height:300px"></div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup name="Dashboard">
import * as echarts from 'echarts'
import request from '@/utils/request'
const talChart = ref(null)
const cityChart = ref(null)
const trendChart = ref(null)
const trendEmpty = ref(false)

// 候选人状态分布按投递六态渲染：0已投递 1招聘中 2待发Offer 3待确认Offer 4已录用 5未录用
const STATUS_MAP = {
  0: '已投递', 1: '招聘中', 2: '待发Offer', 3: '待确认Offer', 4: '已录用', 5: '未录用'
}

onMounted(async () => {
  const r = await request({ url: '/admin/dashboard/overview' })
  const d = r.data || {}
  echarts.init(talChart.value).setOption({
    tooltip: { trigger: 'item' },
    legend: { bottom: 0, type: 'scroll', width: '90%' },
    series: [{
      type: 'pie', radius: ['40%','65%'],
      label: { formatter: '{b}: {c}' },
      data: (d.talStatus||[]).map(x => ({ name: STATUS_MAP[x.tal_status] || ('状态'+x.tal_status), value: x.c }))
    }]
  })
  echarts.init(cityChart.value).setOption({
    tooltip: {},
    grid: { left: 40, right: 20, bottom: 50, top: 20 },
    xAxis: { type: 'category', data: (d.posCity||[]).map(x => x.city), axisLabel: {rotate: 30} },
    yAxis: { type: 'value' },
    series: [{ type: 'bar', itemStyle: { color: '#4f6ef7' }, data: (d.posCity||[]).map(x => x.c) }]
  })
  const trend = d.appTrend || []
  trendEmpty.value = trend.length === 0
  if (!trendEmpty.value) {
    echarts.init(trendChart.value).setOption({
      tooltip: { trigger: 'axis' },
      xAxis: { type: 'category', data: trend.map(x => {
        try { return new Date(x.d).toISOString().slice(5,10).replace('-','/') } catch { return x.d }
      }) },
      yAxis: { type: 'value', minInterval: 1 },
      series: [{ type: 'line', smooth: true, areaStyle: {}, itemStyle: { color: '#67c23a' }, data: trend.map(x => x.c) }]
    })
  }
})
</script>
