<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="接收人" prop="receiver">
        <el-input
          v-model="queryParams.receiver"
          placeholder="请输入接收人"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="发送渠道" prop="channel">
        <el-select v-model="queryParams.channel" placeholder="请选择发送渠道" clearable style="width: 200px">
          <el-option v-for="item in channelOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="发送状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择发送状态" clearable style="width: 200px">
          <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="recordList">
      <el-table-column label="ID" align="center" prop="recordId" width="70" />
      <el-table-column label="发送时间" align="center" prop="sendTime" width="160" />
      <el-table-column label="渠道" align="center" width="100">
        <template #default="scope">
          <el-tag :type="channelTag(scope.row.channel)">{{ channelLabel(scope.row.channel) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="模板" align="center" prop="templateName" :show-overflow-tooltip="true" />
      <el-table-column label="接收人" align="center" prop="receiver" :show-overflow-tooltip="true" />
      <el-table-column label="联系方式" align="center" prop="contact" width="150" />
      <el-table-column label="内容" align="center" prop="content" :show-overflow-tooltip="true" />
      <el-table-column label="状态" align="center" width="90">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="失败原因" align="center" width="200" :show-overflow-tooltip="true">
        <template #default="scope">
          <span>{{ scope.row.failReason || '-' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="100" class-name="small-padding fixed-width">
        <template #default="scope">
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
  </div>
</template>

<script setup name="MsgRecord">
import { listRecord, resendRecord } from '@/api/msg/record'

const { proxy } = getCurrentInstance()

const recordList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)

// 发送渠道选项
const channelOptions = [
  { value: 'sms', label: '短信', tag: 'primary' },
  { value: 'email', label: '邮件', tag: 'success' },
  { value: 'site', label: '站内', tag: 'info' },
  { value: 'miniapp', label: '小程序', tag: 'warning' }
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

const { form, queryParams } = toRefs(data)

/**
 查询消息记录列表 */
function getList() {
  loading.value = true

  listRecord(data.queryParams)
    .then((response) => {
      recordList.value = response.rows
      total.value = response.total
      loading.value = false
    })
    .catch((err) => {
      console.error('查询消息记录失败:', err)
      loading.value = false
    })
}

/** 搜索按钮操作 */
function handleQuery() {
  data.queryParams.pageNum = 1
  getList()
}

/** 重置按钮操作 */
function resetQuery() {
  proxy.resetForm('queryRef')
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

/** 重发按钮操作 */
function handleResend(row) {
  proxy.$modal
    .confirm('确认重新发送该消息吗？')
    .then(function () {
      return resendRecord(row.recordId)
    })
    .then(() => {
      proxy.$modal.msgSuccess('已重新触发发送')
      getList()
    })
    .catch(() => {})
}

getList()
</script>
