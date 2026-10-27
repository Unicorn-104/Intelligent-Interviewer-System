<template>
  <div class="app-container">
    <el-row :gutter="16">
      <el-col :span="6">
        <el-card shadow="hover"><div class="ov-num">{{ overview.todayTotal || 0 }}</div><div class="ov-label">今日事件</div></el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover"><div class="ov-num">{{ overview.total || 0 }}</div><div class="ov-label">总事件</div></el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div v-for="t in overview.byType || []" :key="t.event_type" class="type-row">
            <el-tag size="small">{{ t.event_type }}</el-tag> {{ t.c }}
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div style="font-size:13px;color:#999;margin-bottom:6px">近7天分布</div>
          <div v-for="d in overview.byDay || []" :key="d.d" class="type-row">{{ fmtDay(d.d) }}: {{ d.c }}</div>
        </el-card>
      </el-col>
    </el-row>

    <el-form :inline="true" style="margin-top:16px">
      <el-form-item label="类型">
        <el-select v-model="query.eventType" clearable style="width:120px">
          <el-option label="delta" value="delta" /><el-option label="status" value="status" />
          <el-option label="done" value="done" /><el-option label="c" value="c" />
        </el-select>
      </el-form-item>
      <el-form-item label="关键词">
        <el-input v-model="query.keyword" placeholder="data_json 搜索" clearable style="width:200px" @keyup.enter="load" />
      </el-form-item>
      <el-button type="primary" @click="load">搜索</el-button>
    </el-form>

    <el-table :data="list" v-loading="loading" border size="small">
      <el-table-column label="ID" prop="id" width="80" />
      <el-table-column label="run_id" prop="run_id" width="120" show-overflow-tooltip />
      <el-table-column label="类型" prop="event_type" width="80">
        <template #default="s"><el-tag size="small">{{ s.row.event_type }}</el-tag></template>
      </el-table-column>
      <el-table-column label="数据预览" prop="data_preview" show-overflow-tooltip />
      <el-table-column label="时间" prop="created_at" width="160" />
      <el-table-column label="操作" width="100">
        <template #default="s">
          <el-button link type="primary" @click="showTrace(s.row.run_id)">链路</el-button>
        </template>
      </el-table-column>
    </el-table>
    <pagination v-show="total>0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="load" />

    <el-dialog v-model="traceOpen" title="事件链路" width="700px">
      <el-timeline>
        <el-timeline-item v-for="e in traceList" :key="e.id" :timestamp="e.created_at">
          <el-tag size="small">{{ e.event_type }}</el-tag>
          <pre class="trace-data">{{ e.data_json }}</pre>
        </el-timeline-item>
      </el-timeline>
    </el-dialog>
  </div>
</template>

<script setup name="AiAgentMonitor">
import request from '@/utils/request'
const overview = ref({})
const list = ref([])
const total = ref(0)
const loading = ref(false)
const query = ref({ eventType: '', keyword: '', pageNum: 1, pageSize: 20 })
const traceOpen = ref(false)
const traceList = ref([])

function load() {
  loading.value = true
  request({ url: '/admin/aiagent/list', method: 'get', params: query.value })
    .then((r) => { list.value = r.rows; total.value = r.total })
    .finally(() => (loading.value = false))
}
function loadOverview() { request({ url: '/admin/aiagent/overview' }).then((r) => (overview.value = r.data || {})) }
function fmtDay(s) {
  if (!s) return s
  // 2026-10-23T16:00:00.000Z -> 10-23
  const m = String(s).match(/\d{4}-(\d{2}-\d{2})/)
  return m ? m[1] : s
}
function showTrace(runId) {
  request({ url: '/admin/aiagent/trace', params: { runId } }).then((r) => {
    traceList.value = r.data || []
    traceOpen.value = true
  })
}
onMounted(() => { loadOverview(); load() })
</script>

<style scoped>
.ov-num { font-size: 28px; font-weight: bold; color: #4f6ef7; }
.ov-label { color: #999; font-size: 13px; }
.type-row { margin-bottom: 4px; font-size: 13px; }
.trace-data { white-space: pre-wrap; word-break: break-all; font-size: 12px; background: #f5f5f5; padding: 8px; border-radius: 4px; max-height: 200px; overflow: auto; }
</style>
