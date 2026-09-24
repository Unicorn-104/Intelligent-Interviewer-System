<template>
  <div class="app-container">
    <el-card class="box-card" shadow="hover">
      <template #header><span class="section-title">系统状态</span></template>
      <el-descriptions :column="3" border>
        <el-descriptions-item label="系统名称">{{ info.systemName }}</el-descriptions-item>
        <el-descriptions-item label="版本">{{ info.version }}</el-descriptions-item>
        <el-descriptions-item label="运行时间">{{ info.runTime }}</el-descriptions-item>
        <el-descriptions-item label="Java版本">{{ info.javaVersion }}</el-descriptions-item>
        <el-descriptions-item label="操作系统">{{ info.os }}</el-descriptions-item>
        <el-descriptions-item label="服务器IP">{{ info.serverIp }}</el-descriptions-item>
        <el-descriptions-item label="CPU使用率">
          <el-progress :percentage="info.cpuUsage" :color="info.cpuUsage > 80 ? '#EF4444' : '#22C55E'" />
        </el-descriptions-item>
        <el-descriptions-item label="内存使用率">
          <el-progress :percentage="info.memUsage" :color="info.memUsage > 80 ? '#EF4444' : '#22C55E'" />
        </el-descriptions-item>
        <el-descriptions-item label="磁盘使用率">
          <el-progress :percentage="info.diskUsage" :color="info.diskUsage > 85 ? '#EF4444' : '#22C55E'" />
        </el-descriptions-item>
      </el-descriptions>
    </el-card>

    <el-card class="box-card" shadow="hover" style="margin-top: 20px">
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center">
          <span class="section-title">操作日志</span>
          <el-button text type="primary" @click="loadLogs">刷新</el-button>
        </div>
      </template>
      <el-table v-loading="logsLoading" :data="operLogs" stripe>
        <el-table-column label="操作模块" align="center" prop="title" width="120" />
        <el-table-column label="操作人员" align="center" prop="operName" width="100" />
        <el-table-column label="操作类型" align="center" prop="businessType" width="100">
          <template #default="scope">
            <el-tag :type="typeTag(scope.row.businessType)">{{ typeLabel(scope.row.businessType) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" align="center" prop="status" width="80">
          <template #default="scope">
            <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'">{{
              scope.row.status === '0' ? '成功' : '失败'
            }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作IP" align="center" prop="operIp" width="140" />
        <el-table-column label="操作时间" align="center" prop="operTime" width="160">
          <template #default="scope"
            ><span>{{ parseTime(scope.row.operTime) }}</span></template
          >
        </el-table-column>
      </el-table>
      <pagination
        v-show="logsTotal > 0"
        :total="logsTotal"
        v-model:page="logQuery.pageNum"
        v-model:limit="logQuery.pageSize"
        @pagination="loadLogs"
      />
    </el-card>

    <el-card class="box-card" shadow="hover" style="margin-top: 20px">
      <template #header><span class="section-title">定时任务</span></template>
      <el-table v-loading="jobsLoading" :data="jobs" stripe>
        <el-table-column label="任务名称" align="center" prop="jobName" />
        <el-table-column label="任务组" align="center" prop="jobGroup" width="120" />
        <el-table-column label="Cron表达式" align="center" prop="cronExpression" width="180" />
        <el-table-column label="下次执行" align="center" prop="nextValidTime" width="180" />
        <el-table-column label="状态" align="center" prop="status" width="80">
          <template #default="scope">
            <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'">{{
              scope.row.status === '0' ? '正常' : '暂停'
            }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" align="center" width="150">
          <template #default="scope">
            <el-button link type="primary" icon="VideoPlay" @click="handleRun(scope.row)">执行</el-button>
            <el-button link type="primary" icon="VideoPause" @click="handlePause(scope.row)">{{
              scope.row.status === '0' ? '暂停' : '启动'
            }}</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup name="SystemMaintenance">
import request from '@/utils/request'
import { getMaintenanceInfo } from '@/api/system/service'
import { runJob, changeJobStatus } from '@/api/monitor/job'

const { proxy } = getCurrentInstance()

const logsLoading = ref(false)
const jobsLoading = ref(false)
const operLogs = ref([])
const logsTotal = ref(0)
const jobs = ref([])
const info = ref({})
const logQuery = reactive({
  pageNum: 1,
  pageSize: 10,
  status: undefined,
  operIp: undefined,
  beginTime: undefined,
  endTime: undefined
})

const typeMap = {
  10: '新增',
  20: '修改',
  30: '删除',
  40: '授权',
  50: '导出',
  60: '清空',
  70: '批量更新',
  80: '打印',
  90: '检查',
  99: '其他'
}
function typeTag(bizType) {
  return bizType === 30 ? 'danger' : bizType === 10 ? '' : 'info'
}
function typeLabel(bizType) {
  return typeMap[bizType] || bizType
}

function loadLogs() {
  logsLoading.value = true
  request({ url: '/monitor/operlog/list', method: 'get', params: logQuery })
    .then((res) => {
      operLogs.value = res.rows
      logsTotal.value = res.total
    })
    .catch((err) => {
      console.error('加载操作日志失败', err)
    })
    .finally(() => {
      logsLoading.value = false
    })
}

function loadJobs() {
  jobsLoading.value = true
  request({ url: '/monitor/job/list', method: 'get' })
    .then((res) => {
      jobs.value = res.rows || []
    })
    .catch((err) => {
      console.error('加载定时任务失败', err)
    })
    .finally(() => {
      jobsLoading.value = false
    })
}

function handleRun(row) {
  proxy.$modal
    .confirm('确认执行任务「' + row.jobName + '」吗？')
    .then(() => {
      return runJob({ jobId: row.jobId })
    })
    .then(() => {
      proxy.$modal.msgSuccess('任务已执行')
      loadJobs()
    })
    .catch(() => {})
}

function handlePause(row) {
  const newStatus = row.status === '0' ? '1' : '0'
  const text = newStatus === '0' ? '启动' : '暂停'
  proxy.$modal
    .confirm('确认' + text + '任务「' + row.jobName + '」吗？')
    .then(() => {
      return changeJobStatus({ jobId: row.jobId, status: newStatus })
    })
    .then(() => {
      proxy.$modal.msgSuccess(text + '成功')
      loadJobs()
    })
    .catch(() => {})
}

getMaintenanceInfo()
  .then((res) => {
    info.value = res.data || info.value
  })
  .catch((err) => {
    console.error('获取系统信息失败', err)
  })
loadLogs()
loadJobs()
</script>
