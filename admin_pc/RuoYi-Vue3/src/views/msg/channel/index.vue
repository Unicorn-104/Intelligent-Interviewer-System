<template>
  <div class="app-container">
    <el-row :gutter="10" class="mb8">
      <right-toolbar :search="false" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="channelList">
      <el-table-column label="ID" align="center" prop="channelId" width="70" />
      <el-table-column label="渠道名称" align="center" prop="channelName" :show-overflow-tooltip="true" />
      <el-table-column label="类型" align="center" width="110">
        <template #default="scope">
          <el-tag :type="channelTypeTag(scope.row.channelType)">{{ channelTypeLabel(scope.row.channelType) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="服务商" align="center" prop="provider" :show-overflow-tooltip="true" />
      <el-table-column label="接入配置" align="center" prop="config" :show-overflow-tooltip="true" />
      <el-table-column label="当日限额" align="center" width="100">
        <template #default="scope">
          <span>{{ scope.row.dailyLimit > 0 ? scope.row.dailyLimit : '不限' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="今日已用" align="center" width="180">
        <template #default="scope">
          <el-progress v-if="scope.row.dailyLimit > 0" :percentage="usedPercent(scope.row)" :stroke-width="10" />
          <span v-else>{{ scope.row.todayUsed }}</span>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" width="90">
        <template #default="scope">
          <el-switch
            v-model="scope.row.status"
            active-value="0"
            inactive-value="1"
            @change="handleStatusChange(scope.row)"
            v-hasPermi="['msg:channel:edit']"
          />
        </template>
      </el-table-column>
      <el-table-column label="备注" align="center" prop="remark" :show-overflow-tooltip="true" />
      <el-table-column label="操作" align="center" width="100" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['msg:channel:edit']"
            >修改</el-button
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

    <!-- 修改通知渠道对话框 -->
    <el-dialog :title="title" v-model="open" width="600px" append-to-body>
      <el-form ref="channelRef" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="渠道名称" prop="channelName">
          <el-input v-model="form.channelName" placeholder="请输入渠道名称" />
        </el-form-item>
        <el-form-item label="服务商" prop="provider">
          <el-input v-model="form.provider" placeholder="请输入服务商" />
        </el-form-item>
        <el-form-item label="接入配置" prop="config">
          <el-input v-model="form.config" type="textarea" :rows="4" placeholder="请输入接入配置" />
        </el-form-item>
        <el-form-item label="当日限额" prop="dailyLimit">
          <el-input-number v-model="form.dailyLimit" :min="0" />
          <span class="form-tip">0 表示不限</span>
        </el-form-item>
        <el-form-item label="备注" prop="remark">
          <el-input v-model="form.remark" type="textarea" :rows="2" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitForm">确 定</el-button>
          <el-button @click="cancel">取 消</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="MsgChannel">
import { listChannel, updateChannel, toggleChannel } from '@/api/msg/channel'

const { proxy } = getCurrentInstance()

const channelList = ref([])
const open = ref(false)
const loading = ref(true)
const title = ref('')
const total = ref(0)

// 渠道类型选项
const channelTypeOptions = [
  { value: 'sms', label: '短信', tag: 'primary' },
  { value: 'email', label: '邮件', tag: 'success' },
  { value: 'miniapp', label: '小程序', tag: 'warning' },
  { value: 'site', label: '站内', tag: 'info' }
]

const data = reactive({
  form: {
    channelId: undefined,
    channelType: undefined,
    channelName: undefined,
    provider: undefined,
    config: undefined,
    dailyLimit: 0,
    remark: undefined,
    status: '0'
  },
  queryParams: {
    pageNum: 1,
    pageSize: 10
  },
  rules: {
    channelName: [{ required: true, message: '渠道名称不能为空', trigger: 'blur' }]
  }
})

const { form, queryParams } = toRefs(data)

/**
 查询列表 */
function getList() {
  loading.value = true

  listChannel(queryParams)
    .then((response) => {
      const payload = response?.data
      channelList.value = Array.isArray(payload) ? payload : payload?.rows || response?.rows || []
      total.value = payload?.total ?? response?.total ?? channelList.value.length
      loading.value = false
    })
    .catch((err) => {
      console.error('查询通知渠道失败:', err)
      channelList.value = []
      total.value = 0
      loading.value = false
    })
}

/** 修改按钮操作 */
function handleUpdate(row) {
  data.form = { ...row }
  open.value = true
  title.value = '修改通知渠道'
}

/** 提交按钮 */
function submitForm() {
  proxy.$refs['channelRef'].validate((valid) => {
    if (valid) {
      updateChannel(data.form)
        .then(() => {
          proxy.$modal.msgSuccess('修改成功')
          open.value = false
          getList()
        })
        .catch((err) => {
          console.error(err)
          proxy?.$msgError?.('操作失败')
        })
    }
  })
}

/** 取消按钮 */
function cancel() {
  open.value = false
}

/** 状态切换 */
function channelTypeLabel(val) {
  const item = channelTypeOptions.find((o) => o.value === val)
  return item ? item.label : val
}

function channelTypeTag(val) {
  const item = channelTypeOptions.find((o) => o.value === val)
  return item ? item.tag : ''
}

function handleStatusChange(row) {
  const enabling = row.status === '0'
  const text = enabling ? '启用' : '停用'
  proxy.$modal
    .confirm('确认要"' + text + '"' + row.channelName + '"渠道吗？')
    .then(function () {
      return toggleChannel({ channelId: row.channelId })
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess(text + '成功')
    })
    .catch(() => {
      row.status = enabling ? '1' : '0'
      getList()
    })
}

getList()
</script>

<style lang="scss" scoped>
.app-container {
  .form-tip {
    margin-left: 8px;
    color: #909399;
    font-size: 12px;
  }
}
</style>
