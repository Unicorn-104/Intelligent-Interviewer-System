<template>
  <div class="app-container">
    <el-card shadow="never">
      <el-table v-loading="loading" :data="list" stripe>
        <el-table-column label="候选人" prop="tal_name" width="120" />
        <el-table-column label="岗位" prop="pos_title" min-width="150" show-overflow-tooltip />
        <el-table-column label="企业" prop="cmp_name" min-width="150" show-overflow-tooltip />
        <el-table-column label="分析报告" min-width="300">
          <template #default="{row}">
            <el-button type="text" size="small" @click="showReport(row)">查看报告</el-button>
          </template>
        </el-table-column>
        <el-table-column label="更新时间" prop="asr_updated_at" width="170">
          <template #default="{row}">{{ formatDt(row.asr_updated_at) }}</template>
        </el-table-column>
      </el-table>
      <pagination v-show="total>0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="getList" />
    </el-card>

    <el-dialog v-model="dialogVisible" title="AI分析报告" width="700px">
      <pre class="report-content">{{ reportText }}</pre>
    </el-dialog>
  </div>
</template>

<script setup name="AiAnalysis">
import { ref, reactive, onMounted } from 'vue'
import request from '@/utils/request'

const list = ref([])
const loading = ref(false)
const total = ref(0)
const query = reactive({ pageNum: 1, pageSize: 10 })
const dialogVisible = ref(false)
const reportText = ref('')

function getList() {
  loading.value = true
  request({ url: '/biz/ai-analysis/list', method: 'get', params: query }).then(res => {
    list.value = res.rows || []
    total.value = res.total || 0
  }).finally(() => loading.value = false)
}

function showReport(row) {
  try {
    reportText.value = typeof row.asr_report === 'string' ? row.asr_report : JSON.stringify(row.asr_report, null, 2)
  } catch { reportText.value = String(row.asr_report) }
  dialogVisible.value = true
}

function formatDt(d) { return d ? d.replace('T',' ').substring(0,16) : '-' }

onMounted(getList)
</script>

<style scoped>
.report-content { background: #f5f7fa; padding: 16px; border-radius: 4px; max-height: 500px; overflow: auto; white-space: pre-wrap; }
</style>
