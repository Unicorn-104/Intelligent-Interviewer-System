<template>
  <div class="app-container">
    <el-row :gutter="16">
      <el-col :span="6">
        <el-card shadow="hover" class="status-card">
          <div class="status-title">数据库</div>
          <el-tag :type="data.db.ok ? 'success' : 'danger'" size="large">{{ data.db.ok ? '正常' : '异常' }}</el-tag>
          <div class="status-meta">{{ data.db.product || data.db.error }}</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="status-card">
          <div class="status-title">Redis</div>
          <el-tag :type="data.redis.ok ? 'success' : 'danger'" size="large">{{ data.redis.ok ? '正常' : '异常' }}</el-tag>
          <div class="status-meta">{{ data.redis.ok ? 'PONG' : data.redis.error }}</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="status-card">
          <div class="status-title">磁盘</div>
          <el-tag :type="data.disk.usedPct > 85 ? 'danger' : 'success'" size="large">{{ data.disk.usedPct }}%</el-tag>
          <div class="status-meta">{{ data.disk.usedGb }} / {{ data.disk.totalGb }} GB</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="status-card">
          <div class="status-title">JVM 堆</div>
          <el-tag :type="data.jvm.heapPct > 80 ? 'danger' : 'success'" size="large">{{ data.jvm.heapPct }}%</el-tag>
          <div class="status-meta">{{ data.jvm.heapUsedMb }} / {{ data.jvm.heapMaxMb }} MB</div>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never" style="margin-top: 20px">
      <template #header>
        <div style="display:flex;justify-content:space-between;align-items:center">
          <span>系统详情</span>
          <div>
            <el-button type="warning" size="small" @click="clearCache">清空 Redis 缓存</el-button>
            <el-button type="primary" size="small" @click="load" :loading="loading">刷新</el-button>
          </div>
        </div>
      </template>
      <el-descriptions :column="2" border v-loading="loading">
        <el-descriptions-item label="CPU 核数">{{ data.jvm.processors }}</el-descriptions-item>
        <el-descriptions-item label="运行时长">{{ uptime }}</el-descriptions-item>
        <el-descriptions-item label="数据库地址">{{ data.db.url }}</el-descriptions-item>
        <el-descriptions-item label="磁盘已用">{{ data.disk.usedGb }} GB / 共 {{ data.disk.totalGb }} GB</el-descriptions-item>
      </el-descriptions>
    </el-card>
    <el-card shadow="never" style="margin-top: 20px">
      <template #header>
        <div style="display:flex;justify-content:space-between;align-items:center">
          <span>最近错误（最近10条操作失败）</span>
        </div>
      </template>
      <el-table :data="errors" size="small" stripe>
        <el-table-column label="时间" prop="oper_time" width="160" />
        <el-table-column label="操作人" prop="oper_name" width="100" />
        <el-table-column label="URL" prop="oper_url" show-overflow-tooltip />
        <el-table-column label="错误" prop="error_msg" show-overflow-tooltip />
      </el-table>
    </el-card>
  </div>
</template>

<script setup name="OpsInspect">
import request from '@/utils/request'
const { proxy } = getCurrentInstance()
const loading = ref(false)
const data = ref({ db: {}, redis: {}, disk: {}, jvm: {} })
const errors = ref([])

const uptime = computed(() => {
  const ms = data.value.jvm.uptimeMs || 0
  const h = Math.floor(ms / 3600000)
  const m = Math.floor((ms % 3600000) / 60000)
  return h + 'h ' + m + 'm'
})

function load() {
  loading.value = true
  request({ url: '/admin/ops/inspect', method: 'get' })
    .then((res) => (data.value = res.data))
    .catch(() => proxy.$modal.msgError('巡检失败'))
    .finally(() => (loading.value = false))
  request({ url: '/admin/probe/recentErrors' }).then((r) => (errors.value = r.data || []))
}

function clearCache() {
  proxy.$modal
    .confirm('确认清空 Redis 全部缓存？（字典/菜单/登录态会重新加载）')
    .then(() => request({ url: '/monitor/cache/clearCacheAll', method: 'delete' }))
    .then(() => proxy.$modal.msgSuccess('缓存已清空'))
    .catch(() => {})
}
onMounted(load)
</script>

<style scoped>
.status-card { text-align: center; }
.status-title { font-size: 14px; color: #666; margin-bottom: 10px; }
.status-meta { margin-top: 10px; font-size: 12px; color: #999; }
</style>
