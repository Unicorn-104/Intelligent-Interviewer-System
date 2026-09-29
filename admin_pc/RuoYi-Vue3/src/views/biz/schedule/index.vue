<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch" label-width="100px">
      <el-form-item label="候选人" prop="candidate">
        <el-input
          v-model="queryParams.candidate"
          placeholder="请输入候选人"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="岗位" prop="jobName">
        <el-input
          v-model="queryParams.jobName"
          placeholder="请输入岗位"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="全部" clearable style="width: 150px">
          <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5"
        ><el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['biz:schedule:add']"
          >新建面试</el-button
        ></el-col
      >
      <el-col :span="1.5"
        ><el-button
          type="danger"
          plain
          icon="Delete"
          :disabled="multiple"
          @click="handleCancel"
          v-hasPermi="['biz:schedule:remove']"
          >取消面试</el-button
        ></el-col
      >
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="scheduleList" @selection-change="handleSelectionChange" stripe>
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="候选人" align="center" prop="candidate" width="120" />
      <el-table-column label="岗位" align="center" prop="jobName" width="180" />
      <el-table-column label="面试官" align="center" prop="interviewer" width="120" />
      <el-table-column label="面试轮次" align="center" prop="roundName" width="100" />
      <el-table-column label="面试时间" align="center" prop="startTime" width="170" />
      <el-table-column label="面试模式" align="center" prop="mode">
        <template #default="scope"
          ><el-tag :type="modeTag(scope.row.mode)">{{ modeLabel(scope.row.mode) }}</el-tag></template
        >
      </el-table-column>
      <el-table-column label="状态" align="center" prop="status">
        <template #default="scope"
          ><el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag></template
        >
      </el-table-column>
      <el-table-column label="操作" align="center" width="200">
        <template #default="scope">
          <el-button
            link
            type="primary"
            icon="Edit"
            @click="handleReschedule(scope.row)"
            v-if="scope.row.status === 'pending'"
            >改期</el-button
          >
          <el-button
            link
            type="danger"
            icon="VideoPause"
            @click="handleCancelRow(scope.row)"
            v-if="scope.row.status === 'pending'"
            >取消</el-button
          >
          <el-button
            link
            type="primary"
            icon="VideoPlay"
            @click="handleEnter(scope.row)"
            v-if="scope.row.status === 'ready'"
            >进入面试</el-button
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

    <el-dialog :title="dialogTitle" v-model="dialogOpen" width="600px" append-to-body>
      <el-form ref="schedRef" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="候选人" prop="candidate"
          ><el-input v-model="form.candidate" placeholder="候选人名称"
        /></el-form-item>
        <el-form-item label="岗位" prop="jobName"
          ><el-input v-model="form.jobName" placeholder="岗位名称"
        /></el-form-item>
        <el-form-item label="面试官" prop="interviewer"
          ><el-input v-model="form.interviewer" placeholder="面试官名称"
        /></el-form-item>
        <el-form-item label="面试轮次" prop="roundName">
          <el-select v-model="form.roundName" style="width: 100%">
            <el-option label="初面" value="初面" /><el-option label="复面" value="复面" /><el-option
              label="终面"
              value="终面"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="面试模式" prop="mode">
          <el-select v-model="form.mode" style="width: 100%">
            <el-option label="纯AI面试" value="0" /><el-option label="AI+HR协同" value="1" /><el-option
              label="级联面试"
              value="2"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="面试时间" prop="startTime"
          ><el-date-picker v-model="form.startTime" type="datetime" placeholder="选择面试时间" style="width: 100%"
        /></el-form-item>
        <el-form-item label="会议链接"
          ><el-input v-model="form.meetingUrl" placeholder="自动生成或手动输入"
        /></el-form-item>
      </el-form>
      <template #footer>
        <el-button type="primary" @click="submitForm">确 定</el-button>
        <el-button @click="dialogOpen = false">取 消</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="BizSchedule">
import { listSchedule, createSchedule, updateSchedule, cancelSchedule, rescheduleInterview } from '@/api/biz/schedule'

const { proxy } = getCurrentInstance()

// ==================== State ====================
const scheduleList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const ids = ref([])
const single = ref(true)
const multiple = ref(true)
const dialogOpen = ref(false)
const dialogTitle = ref('')
const form = ref({})
const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  candidate: undefined,
  jobName: undefined,
  status: undefined
})

const rules = ref({
  candidate: [{ required: true, message: '请输入候选人名称', trigger: 'blur' }],
  jobName: [{ required: true, message: '请输入岗位名称', trigger: 'blur' }],
  startTime: [{ required: true, message: '请选择面试时间', trigger: 'blur' }]
})

const statusOptions = [
  { value: 'pending', label: '待面试' },
  { value: 'ready', label: '准备中' },
  { value: 'completed', label: '已完成' },
  { value: 'cancelled', label: '已取消' }
]

/** 查询面试列表 */
function getList() {
  loading.value = true
  listSchedule(queryParams.value)
    .then((res) => {
      scheduleList.value = res.rows
      total.value = res.total
    })
    .catch(function (err) {
      console.error(err)
      proxy.$modal.msgError('查询失败，请重试')
    })
    .finally(function () {
      loading.value = false
    })
}

/** 搜索按钮操作 */
function handleQuery() {
  queryParams.value.pageNum = 1
  getList()
}

/** 重置按钮操作 */
function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map(function (item) {
    return item.scheduleId
  })
  single.value = selection.length != 1
  multiple.value = !selection.length
}

/** 新建面试 */
function handleAdd() {
  reset()
  dialogOpen.value = true
  dialogTitle.value = '新建面试'
}

/** 表单重置 */
function reset() {
  form.value = {
    candidate: undefined,
    jobName: undefined,
    interviewer: undefined,
    roundName: '初面',
    mode: '0',
    startTime: '',
    meetingUrl: undefined
  }
  proxy.resetForm('schedRef')
}

/** 提交表单 */
function submitForm() {
  proxy.$refs['schedRef'].validate(function (valid) {
    if (valid) {
      if (form.value.scheduleId != undefined) {
        updateSchedule(form.value)
          .then(function () {
            proxy.$modal.msgSuccess('保存成功')
            dialogOpen.value = false
            getList()
          })
          .catch(function (err) {
            console.error(err)
            proxy.$modal.msgError('保存失败')
          })
      } else {
        createSchedule(form.value)
          .then(function () {
            proxy.$modal.msgSuccess('保存成功')
            dialogOpen.value = false
            getList()
          })
          .catch(function (err) {
            console.error(err)
            proxy.$modal.msgError('保存失败')
          })
      }
    }
  })
}

/** 改期 */
function handleReschedule(row) {
  reset()
  form.value = Object.assign({}, row)
  dialogOpen.value = true
  dialogTitle.value = '改期面试'
}

/** 批量取消面试 */
function handleCancel() {
  proxy.$modal
    .confirm('确认要取消选中的面试吗？')
    .then(function () {
      return cancelSchedule(ids.value)
    })
    .then(function () {
      proxy.$modal.msgSuccess('已取消')
      getList()
    })
    .catch(function (err) {
      console.error(err)
      proxy.$modal.msgError('取消失败')
    })
}

/** 单条取消 */
function handleCancelRow(row) {
  proxy.$modal
    .confirm('确认要取消面试"' + row.candidate + '"吗？')
    .then(function () {
      return cancelSchedule(row.scheduleId)
    })
    .then(function () {
      proxy.$modal.msgSuccess('已取消')
      getList()
    })
    .catch(function () {})
}

function handleEnter(row) {
  proxy.$router.push('/biz/interview/' + row.scheduleId)
}

function modeLabel(mode) {
  var modeMap = { 0: '纯AI面试', 1: 'AI+HR协同', 2: '级联面试' }
  return modeMap[mode] || mode
}
function modeTag(mode) {
  var modeMap = { 0: 'info', 1: 'warning', 2: 'success' }
  return modeMap[mode] || 'info'
}
function statusLabel(s) {
  var statusMap = { pending: '待安排', scheduled: '已安排', completed: '已完成', cancelled: '已取消' }
  return statusMap[s] || s
}
function statusTag(s) {
  var statusMap = { pending: 'info', scheduled: 'warning', completed: 'success', cancelled: 'danger' }
  return statusMap[s] || 'info'
}

getList()
</script>
