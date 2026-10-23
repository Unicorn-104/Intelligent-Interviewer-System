<template>
  <div class="app-container">
    <!-- 统计卡 -->
    <el-row :gutter="16" class="stats-row">
      <el-col :span="8">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-label">发送总数</div>
          <div class="stat-value">{{ stats.total }}</div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-label">成功</div>
          <div class="stat-value success">{{ stats.success }}</div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-label">失败</div>
          <div class="stat-value danger">{{ stats.fail }}</div>
        </el-card>
      </el-col>
    </el-row>

    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="接收人" prop="receiver">
        <el-input
          v-model="queryParams.receiver"
          placeholder="请输入接收人"
          clearable
          style="width: 180px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="发送渠道" prop="channel">
        <el-select v-model="queryParams.channel" placeholder="请选择发送渠道" clearable style="width: 160px">
          <el-option v-for="item in channelOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="发送状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择发送状态" clearable style="width: 150px">
          <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="发送时间">
        <el-date-picker
          v-model="dateRange"
          type="daterange"
          range-separator="至"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          value-format="YYYY-MM-DD"
          style="width: 260px"
        />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="warning" plain icon="Download" @click="exportCsv">导出当前列表</el-button>
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="recordList">
      <el-table-column label="ID" align="center" prop="recordId" width="70" />
      <el-table-column label="发送时间" align="center" prop="sendTime" width="160">
        <template #default="scope">
          <span>{{ parseTime(scope.row.sendTime) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="渠道" align="center" width="100">
        <template #default="scope">
          <el-tag :type="channelTag(scope.row.channel)">{{ channelLabel(scope.row.channel) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="模板" align="center" prop="templateName" :show-overflow-tooltip="true" min-width="140" />
      <el-table-column label="接收人" align="center" prop="receiver" width="110" />
      <el-table-column label="联系方式" align="center" width="150">
        <template #default="scope">
          <span>{{ maskContact(scope.row.contact) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="内容" align="center" min-width="180" :show-overflow-tooltip="true">
        <template #default="scope">
          <span>{{ scope.row.content }}</span>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" width="90">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="失败原因" align="center" width="180" :show-overflow-tooltip="true">
        <template #default="scope">
          <span>{{ scope.row.failReason || '-' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="150" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleDetail(scope.row)">详情</el-button>
          <el-button
            v-if="scope.row.status === '1'"
            link
            type="primary"
            icon="RefreshRight"
            @click="handleResend(scope.row)"
            v-hasPermi="['msg:record:edit']"
            >重发</el-button
          >
        </template>
      </el-table-column>
    </el-table>

    <pagination
      v-show="total > 0"
      :total="total"
      v-model:page="queryParams.pageNum"
      v-model:limit="queryParams.pageSize"
      @pagination="getList"
    />

    <!-- 消息详情 -->
    <el-dialog title="消息详情" v-model="detailOpen" width="600px" append-to-body>
      <el-descriptions :column="1" border>
        <el-descriptions-item label="接收人">{{ detail.receiver || '-' }}</el-descriptions-item>
        <el-descriptions-item label="联系方式">{{ maskContact(detail.contact) }}</el-descriptions-item>
        <el-descriptions-item label="渠道">{{ channelLabel(detail.channel) }}</el-descriptions-item>
        <el-descriptions-item label="模板">{{ detail.templateName || '-' }}</el-descriptions-item>
        <el-descriptions-item label="状态">{{ statusLabel(detail.status) }}</el-descriptions-item>
        <el-descriptions-item label="发送时间">{{ parseTime(detail.sendTime) }}</el-descriptions-item>
        <el-descriptions-item v-if="detail.failReason" label="失败原因">{{ detail.failReason }}</el-descriptions-item>
        <el-descriptions-item label="内容">
          <div class="detail-content">{{ detail.content || '-' }}</div>
        </el-descriptions-item>
      </el-descriptions>
    </el-dialog>
  </div>
</template>

<script setup name="MsgRecord">
import { listRecord, resendRecord, statsRecord } from '@/api/msg/record'

const { proxy } = getCurrentInstance()

const recordList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const dateRange = ref([])
const detailOpen = ref(false)
const detail = ref({})

const stats = ref({ total: 0, success: 0, fail: 0 })

// 发送渠道选项
const channelOptions = [
  { value: 'sms', label: '短信', tag: 'primary' },
  { value: 'email', label: '邮件', tag: 'success' },
  { value: 'system', label: '站内', tag: 'info' }
]

// 发送状态选项
const statusOptions = [
  { value: '0', label: '成功', tag: 'success' },
  { value: '1', label: '失败', tag: 'danger' }
]

const data = reactive({
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    receiver: undefined,
    channel: undefined,
    status: undefined
  }
})

const { queryParams } = toRefs(data)

/** 查询统计 */
function loadStats() {
  statsRecord({ channel: data.queryParams.channel })
    .then((res) => {
      stats.value = res.data || { total: 0, success: 0, fail: 0 }
    })
    .catch(() => {})
}

/** 查询消息记录列表 */
function getList() {
  loading.value = true
  const params = { ...data.queryParams }
  if (dateRange.value && dateRange.value.length === 2) {
    params.beginTime = dateRange.value[0] + ' 00:00:00'
    params.endTime = dateRange.value[1] + ' 23:59:59'
  }
  listRecord(params)
    .then((response) => {
      recordList.value = response.rows
      total.value = response.total
      loading.value = false
    })
    .catch((err) => {
      console.error('查询消息记录失败:', err)
      loading.value = false
    })
  loadStats()
}

/** 搜索按钮操作 */
function handleQuery() {
  data.queryParams.pageNum = 1
  getList()
}

/** 重置按钮操作 */
function resetQuery() {
  proxy.resetForm('queryRef')
  dateRange.value = []
  handleQuery()
}

/** 渠道标签 */
function channelLabel(val) {
  const item = channelOptions.find((o) => o.value === val)
  return item ? item.label : val
}
function channelTag(val) {
  const item = channelOptions.find((o) => o.value === val)
  return item && item.tag ? item.tag : 'info'
}

/** 状态显示 */
function statusLabel(val) {
  const item = statusOptions.find((o) => o.value === val)
  return item ? item.label : val
}
function statusTag(val) {
  const item = statusOptions.find((o) => o.value === val)
  return item && item.tag ? item.tag : 'danger'
}

/** 联系方式脱敏：手机号保留前3后4，邮箱保留首字符与域名 */
function maskContact(contact) {
  if (!contact) return '-'
  const s = String(contact)
  if (s.includes('@')) {
    const [name, domain] = s.split('@')
    return name.charAt(0) + '***@' + domain
  }
  if (/^\d{11}$/.test(s)) {
    return s.slice(0, 3) + '****' + s.slice(-4)
  }
  return s
}

/** 查看详情 */
function handleDetail(row) {
  detail.value = row
  detailOpen.value = true
}

/** 重发按钮操作 */
function handleResend(row) {
  proxy.$modal
    .confirm('确认重新发送该消息吗？')
    .then(function () {
      return resendRecord(row.recordId)
    })
    .then((res) => {
      proxy.$modal.msgSuccess(res.msg || '已触发重试')
      getList()
    })
    .catch(() => {})
}

/** 导出当前已加载行为 CSV（UTF-8 BOM，Excel 可直接打开） */
function exportCsv() {
  if (!recordList.value.length) {
    proxy.$modal.msgWarning('当前无数据可导出')
    return
  }
  const headers = ['ID', '发送时间', '渠道', '模板', '接收人', '联系方式', '内容', '状态', '失败原因']
  const rows = recordList.value.map((r) => [
    r.recordId,
    r.sendTime || '',
    channelLabel(r.channel),
    r.templateName || '',
    r.receiver || '',
    r.contact || '',
    (r.content || '').replace(/\s+/g, ' '),
    statusLabel(r.status),
    r.failReason || ''
  ])
  const escape = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [headers, ...rows].map((line) => line.map(escape).join(',')).join('\r\n')
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  const d = new Date()
  const pad = (n) => String(n).padStart(2, '0')
  const stamp = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
  a.download = `发送记录_${stamp}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

getList()
</script>

<style lang="scss" scoped>
.stats-row {
  margin-bottom: 16px;
}
.stat-card {
  text-align: center;
  padding: 8px 0;
}
.stat-label {
  color: #909399;
  font-size: 13px;
}
.stat-value {
  font-size: 28px;
  font-weight: 600;
  margin-top: 6px;
  &.success {
    color: #67c23a;
  }
  &.danger {
    color: #f56c6c;
  }
}
.detail-content {
  white-space: pre-wrap;
  line-height: 1.6;
}
</style>
