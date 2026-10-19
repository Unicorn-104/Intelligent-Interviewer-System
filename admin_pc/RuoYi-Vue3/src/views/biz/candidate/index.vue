<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="姓名" prop="userName">
        <el-input
          v-model="queryParams.userName"
          placeholder="请输入候选人姓名"
          clearable
          style="width: 180px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable style="width: 150px">
          <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="标签" prop="tags">
        <el-input
          v-model="queryParams.tags"
          placeholder="请输入标签搜索"
          clearable
          style="width: 150px"
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

    <el-table v-loading="loading" :data="candidateList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="50" align="center" />
      <el-table-column label="ID" align="center" prop="candidateId" width="70" />
      <el-table-column label="姓名" align="center" prop="userName" min-width="90" />
      <el-table-column label="手机号" align="center" prop="phonenumber" width="120" />
      <el-table-column label="意向岗位" align="center" prop="jobName" min-width="140" :show-overflow-tooltip="true" />
      <el-table-column label="综合评分" align="center" width="90">
        <template #default="scope">
          <span :style="{ color: scoreColor(scope.row.totalScore) }">{{ scope.row.totalScore || '-' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" width="100">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="最近操作时间" align="center" width="150">
        <template #default="scope">{{ parseTime(scope.row.updateTime) || '-' }}</template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="150" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleView(scope.row)">详情</el-button>
          <el-button link type="primary" icon="Connection" @click="handleTag(scope.row)">标签</el-button>
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

    <!-- 标签管理对话框 -->
    <el-dialog :title="dialogTitle" v-model="dialogOpen" width="500px" append-to-body>
      <el-form ref="tagFormRef" :model="tagForm" label-width="80px">
        <el-form-item label="候选人">
          <span>{{ tagForm.userName }}</span>
        </el-form-item>
        <el-form-item label="选择标签">
          <el-checkbox-group v-model="tagForm.tags">
            <el-checkbox v-for="tag in tagOptions" :key="tag" :label="tag">{{ tag }}</el-checkbox>
          </el-checkbox-group>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="tagForm.remark" type="textarea" :rows="3" placeholder="可选" />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitTag">确 定</el-button>
          <el-button @click="dialogOpen = false">取 消</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="BizCandidate">
import { listCandidate, getCandidate, addCandidateTag, batchUpdateTag, updateCandidateStatus } from '@/api/biz/business'

const { proxy } = getCurrentInstance()

// Constants
const SCORE_THRESHOLD_GOOD = 80
const SCORE_THRESHOLD_PASS = 60

const candidateList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const ids = ref([])
const total = ref(0)
const dialogOpen = ref(false)
const dialogTitle = ref('')
const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  userName: undefined,
  status: undefined,
  tags: undefined
})

const tagForm = reactive({
  candidateId: undefined,
  userName: '',
  tags: [],
  remark: ''
})

/** 查询列表 */
function getList() {
  loading.value = true
  listCandidate(queryParams.value)
    .then((response) => {
      candidateList.value = response.rows
      total.value = response.total
    })
    .catch((err) => {
      console.error('候选人列表查询失败:', err)
    })
    .finally(() => {
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
  // proxy.resetForm("queryRef");
  handleQuery()
}

/** 详情 */
function handleView(row) {
  getCandidate(row.candidateId)
    .then((res) => {
      const d = res.data || {}
      proxy.$alert(
        [
          '姓名：' + (d.userName || '-'),
          '手机：' + (d.phonenumber || '-'),
          '邮箱：' + (d.email || '-'),
          '意向岗位：' + (d.jobName || '-'),
          '综合评分：' + (d.totalScore ?? '-')
        ].join('\n'),
        '候选人详情',
        { confirmButtonText: '关闭', type: 'info' }
      )
    })
    .catch((err) => console.error('候选人详情加载失败:', err))
}

/** 标签管理 */
function handleTag(row) {
  tagForm.candidateId = row.candidateId
  tagForm.userName = row.userName
  tagForm.tags = row.tags ? String(row.tags).split(',').filter(Boolean) : []
  tagForm.remark = ''
  dialogTitle.value = '标签管理 - ' + row.userName
  dialogOpen.value = true
}

/** 提交标签 */
function submitTag() {
  batchUpdateTag({
    candidateId: tagForm.candidateId,
    tags: tagForm.tags.join(','),
    remark: tagForm.remark
  })
    .then(() => {
      dialogOpen.value = false
      proxy.$modal.msgSuccess('标签更新成功')
      getList()
    })
    .catch((err) => {
      console.error('标签更新失败:', err)
    })
}

/** 状态修改 */
function handleStatusChange(status, row) {
  updateCandidateStatus({ candidateId: row.candidateId, status: status })
    .then(() => {
      proxy.$modal.msgSuccess('状态更新成功')
      getList()
    })
    .catch((err) => {
      console.error('状态更新失败:', err)
    })
}

getList()
function scoreColor(v) {
  if (v === undefined || v === null || v === '') {
    return '#909399'
  }
  if (Number(v) >= SCORE_THRESHOLD_GOOD) {
    return '#22C55E'
  }
  if (Number(v) >= SCORE_THRESHOLD_PASS) {
    return '#F59E0B'
  }
  return '#EF4444'
}

/** 状态显示 */
const STATUS_LABEL_MAP = {
  new: '新候选人',
  screened: '已初筛',
  interviewing: '面试中',
  evaluated: '已评估',
  passed: '通过',
  rejected: '淘汰',
  archived: '已归档'
}
const STATUS_TAG_MAP = {
  new: 'info',
  screened: 'primary',
  interviewing: 'warning',
  evaluated: 'success',
  passed: 'success',
  rejected: 'danger',
  archived: 'info'
}

function statusLabel(val) {
  return STATUS_LABEL_MAP[val] !== undefined ? STATUS_LABEL_MAP[val] : val
}

function statusTag(val) {
  return STATUS_TAG_MAP[val] !== undefined ? STATUS_TAG_MAP[val] : 'info'
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.candidateId)
}

const tagOptions = ['技术能力强', '沟通表达佳', '经验匹配', '学历优质', '领导潜质']

const statusOptions = [
  { value: 'new', label: '新候选人' },
  { value: 'screened', label: '已初筛' },
  { value: 'interviewing', label: '面试中' },
  { value: 'evaluated', label: '已评估' },
  { value: 'passed', label: '通过' },
  { value: 'rejected', label: '淘汰' }
]
</script>
