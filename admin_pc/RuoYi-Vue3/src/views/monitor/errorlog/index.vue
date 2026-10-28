<template>
  <div class="app-container">
    <el-card shadow="never">
      <el-table :data="list" v-loading="loading" border size="small">
        <el-table-column label="ID" prop="operId" width="70" />
        <el-table-column label="模块" prop="title" width="140" />
        <el-table-column label="操作人" prop="operName" width="100" />
        <el-table-column label="URL" prop="operUrl" min-width="160" show-overflow-tooltip />
        <el-table-column label="错误信息" prop="errorMsg" min-width="200" show-overflow-tooltip>
          <template #default="{ row }">
            <span style="color:#f56c6c;">{{ row.errorMsg }}</span>
          </template>
        </el-table-column>
        <el-table-column label="时间" width="160">
          <template #default="{ row }">{{ row.operTime ? String(row.operTime).replace('T',' ').substring(0,19) : '-' }}</template>
        </el-table-column>
      </el-table>
      <pagination v-show="total>0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="load" />
      <el-empty v-if="!loading && !list.length" description="暂无错误日志，系统运行正常" />
    </el-card>
  </div>
</template>

<script setup name="ErrorLog">
import request from '@/utils/request'
const list = ref([])
const total = ref(0)
const loading = ref(false)
const query = ref({ pageNum: 1, pageSize: 20 })

function load() {
  loading.value = true
  request({ url: '/monitor/errorlog/list', method: 'get', params: query.value })
    .then((r) => { list.value = r.rows; total.value = r.total })
    .finally(() => (loading.value = false))
}
onMounted(load)
</script>
