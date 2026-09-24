<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="用户名称" prop="userName">
        <el-input
          v-model="queryParams.userName"
          placeholder="请输入用户名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="渠道类型" prop="channelType">
        <el-select v-model="queryParams.channelType" placeholder="全部" clearable style="width: 150px">
          <el-option v-for="item in channelOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="primary" plain icon="Edit" @click="handleBatchUpdate" v-hasPermi="['msg:preference:edit']"
          >批量更新</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="preferenceList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="用户名称" align="center" prop="userName" />
      <el-table-column label="渠道类型" align="center" prop="channelType">
        <template #default="scope">
          <el-tag :type="channelTagType(scope.row.channelType)">{{ scope.row.channelLabel }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="通知类型" align="center" prop="msgType" :show-overflow-tooltip="true" />
      <el-table-column label="当前状态" align="center" prop="status">
        <template #default="scope">
          <el-switch v-model="scope.row.status" active-value="0" inactive-value="1" @change="handleToggle(scope.row)" />
        </template>
      </el-table-column>
      <el-table-column label="更新时间" align="center" prop="updateTime" width="160">
        <template #default="scope"
          ><span>{{ parseTime(scope.row.updateTime) }}</span></template
        >
      </el-table-column>
      <el-table-column label="操作" align="center" width="120">
        <template #default="scope">
          <el-button
            link
            type="primary"
            icon="Edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['msg:preference:edit']"
            >编辑</el-button
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

    <el-dialog :title="dialogTitle" v-model="dialogOpen" width="500px" append-to-body>
      <el-form ref="prefRef" :model="form" label-width="100px">
        <el-form-item label="用户名称"><el-input v-model="form.userName" disabled /></el-form-item>
        <el-form-item label="邮件通知"
          ><el-switch v-model="form.emailEnabled" active-value="0" inactive-value="1"
        /></el-form-item>
        <el-form-item label="短信通知"
          ><el-switch v-model="form.smsEnabled" active-value="0" inactive-value="1"
        /></el-form-item>
        <el-form-item label="站内推送"
          ><el-switch v-model="form.siteEnabled" active-value="0" inactive-value="1"
        /></el-form-item>
        <el-form-item label="小程序消息"
          ><el-switch v-model="form.miniappEnabled" active-value="0" inactive-value="1"
        /></el-form-item>
        <el-form-item label="备注"
          ><el-input v-model="form.remark" type="textarea" placeholder="请输入备注"
        /></el-form-item>
      </el-form>
      <template #footer>
        <el-button type="primary" @click="submitForm">确 定</el-button>
        <el-button @click="dialogOpen = false">取 消</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="MsgPreference">
import { listPreference, getPreference, updatePreference, toggleChannel } from '@/api/msg/preference'

const { proxy } = getCurrentInstance()
const preferenceList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const ids = ref([])
const total = ref(0)
const dialogOpen = ref(false)
const dialogTitle = ref('')
const dateRange = ref([])

const channelOptions = [
  { value: 'email', label: '邮件' },
  { value: 'sms', label: '短信' },
  { value: 'site', label: '站内' },
  { value: 'miniapp', label: '小程序' }
]

const data = reactive({
  form: {},
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    userName: undefined,
    channelType: undefined
  }
})

const { form, queryParams } = toRefs(data)

/**
 查询通知偏好列表 */
function getList() {
  loading.value = true

  listPreference(data.queryParams)
    .then((response) => {
      preferenceList.value = response.rows
      total.value = response.total
      loading.value = false
    })
    .catch((err) => {
      console.error('查询通知偏好列表失败:', err)
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

/** 行勾选 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.preferenceId)
}

/** 渠道类型标签 */
function channelTagType(val) {
  const item = channelOptions.find((o) => o.value === val)
  return item && item.tag ? item.tag : 'info'
}

/** 单条开关切换 */
function handleToggle(row) {
  const status = row.status === '0' ? '1' : '0'
  toggleChannel({ preferenceId: row.preferenceId, status: status })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('状态已更新')
    })
    .catch((err) => {
      console.error('状态更新失败:', err)
      getList()
    })
}

/** 编辑按钮操作 */
function handleUpdate(row) {
  getPreference(row.preferenceId)
    .then((response) => {
      data.form = response.data
      dialogOpen.value = true
      dialogTitle.value = '编辑通知偏好'
    })
    .catch((err) => {
      console.error('查询通知偏好详情失败:', err)
    })
}

/** 批量更新按钮操作 */
function handleBatchUpdate() {
  if (ids.value.length === 0) {
    proxy.$modal.msgWarning('请先选择要更新的数据')
    return
  }
  proxy.$modal
    .confirm('确认批量更新所选用户的通知偏好吗？')
    .then(() => {
      return toggleChannel({ preferenceIds: ids.value.join(','), status: '0' })
    })
    .then(() => {
      proxy.$modal.msgSuccess('批量更新成功')
      getList()
    })
    .catch(() => {})
}

/** 提交按钮 */
function submitForm() {
  updatePreference(data.form)
    .then(() => {
      proxy.$modal.msgSuccess('修改成功')
      dialogOpen.value = false
      getList()
    })
    .catch((err) => {
      console.error('修改通知偏好失败:', err)
    })
}

getList()
</script>
