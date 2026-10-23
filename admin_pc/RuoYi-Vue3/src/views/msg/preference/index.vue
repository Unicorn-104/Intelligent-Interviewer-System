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
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="preferenceList">
      <el-table-column label="用户名称" align="center" prop="userName" min-width="120" />
      <el-table-column label="App推送" align="center" width="110">
        <template #default="scope">
          <el-switch
            :model-value="scope.row.enabledApp === 1 || scope.row.enabledApp === '1'"
            @change="(val) => handleToggle(scope.row, 'app')"
          />
        </template>
      </el-table-column>
      <el-table-column label="邮件通知" align="center" width="110">
        <template #default="scope">
          <el-switch
            :model-value="scope.row.enabledEmail === 1 || scope.row.enabledEmail === '1'"
            @change="(val) => handleToggle(scope.row, 'email')"
          />
        </template>
      </el-table-column>
      <el-table-column label="短信通知" align="center" width="110">
        <template #default="scope">
          <el-switch
            :model-value="scope.row.enabledSms === 1 || scope.row.enabledSms === '1'"
            @change="(val) => handleToggle(scope.row, 'sms')"
          />
        </template>
      </el-table-column>
      <el-table-column label="更新时间" align="center" prop="updateTime" width="170">
        <template #default="scope">
          <span>{{ parseTime(scope.row.updateTime) }}</span>
        </template>
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
        <el-form-item label="App推送">
          <el-switch v-model="form.enabledApp" :active-value="1" :inactive-value="0" />
        </el-form-item>
        <el-form-item label="邮件通知">
          <el-switch v-model="form.enabledEmail" :active-value="1" :inactive-value="0" />
        </el-form-item>
        <el-form-item label="短信通知">
          <el-switch v-model="form.enabledSms" :active-value="1" :inactive-value="0" />
        </el-form-item>
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
const total = ref(0)
const dialogOpen = ref(false)
const dialogTitle = ref('')

const data = reactive({
  form: {},
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    userName: undefined
  }
})
const { queryParams } = toRefs(data)

/** 查询通知偏好列表 */
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

function handleQuery() {
  data.queryParams.pageNum = 1
  getList()
}

function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}

/** 行内开关切换 */
function handleToggle(row, channel) {
  toggleChannel({ userId: row.userId, channel })
    .then(() => {
      proxy.$modal.msgSuccess('状态已更新')
      getList()
    })
    .catch(() => getList())
}

/** 编辑按钮操作 */
function handleUpdate(row) {
  getPreference(row.preferenceId)
    .then((response) => {
      data.form = response.data
      dialogOpen.value = true
      dialogTitle.value = '编辑通知偏好'
    })
    .catch((err) => console.error('查询通知偏好详情失败:', err))
}

/** 提交保存 */
function submitForm() {
  updatePreference(data.form)
    .then(() => {
      proxy.$modal.msgSuccess('修改成功')
      dialogOpen.value = false
      getList()
    })
    .catch((err) => console.error('修改通知偏好失败:', err))
}

getList()
</script>
