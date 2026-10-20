<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="岗位名称" prop="jobName">
        <el-input
          v-model="queryParams.jobName"
          placeholder="请输入岗位名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="企业名称" prop="companyName">
        <el-input
          v-model="queryParams.companyName"
          placeholder="请输入企业名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable style="width: 160px">
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

    <el-table v-loading="loading" :data="jobList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="50" align="center" />
      <el-table-column label="ID" align="center" prop="jobId" width="80" />
      <el-table-column label="岗位名称" align="center" prop="jobName" :show-overflow-tooltip="true" />
      <el-table-column label="发布企业" align="center" prop="companyName" :show-overflow-tooltip="true" />
      <el-table-column label="薪资" align="center" prop="salary" width="120" />
      <el-table-column label="城市" align="center" prop="city" width="90" />
      <el-table-column label="风险等级" align="center" width="90">
        <template #default="scope">
          <el-tag
            v-if="scope.row.riskLevel !== null && scope.row.riskLevel !== undefined && scope.row.riskLevel !== ''"
            :type="riskLevelTag(scope.row.riskLevel)"
            >{{ riskLevelLabel(scope.row.riskLevel) }}</el-tag
          >
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column label="命中风控词" align="center" min-width="160">
        <template #default="scope">
          <template v-if="scope.row.riskWords && scope.row.riskWords.length > 0">
            <el-tag
              v-for="(word, index) in scope.row.riskWords"
              :key="index"
              type="danger"
              size="small"
              class="risk-tag"
              >{{ word }}</el-tag
            >
          </template>
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" width="100">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="发布时间" align="center" width="110">
        <template #default="scope">
          <span>{{ parseTime(scope.row.publishTime, '{y}-{m}-{d}') || '-' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="150" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button
            v-if="Number(scope.row.status) === 0"
            link
            type="primary"
            icon="Edit"
            @click="handleAudit(scope.row)"
            v-hasPermi="['biz:job:audit']"
            >审核</el-button
          >
          <el-button
            v-if="Number(scope.row.status) === 1"
            link
            type="danger"
            icon="CircleClose"
            @click="handleOff(scope.row)"
            v-hasPermi="['biz:job:audit']"
            >违规下架</el-button
          >
          <el-button
            v-if="Number(scope.row.status) === 2 || Number(scope.row.status) === 3"
            link
            type="primary"
            icon="View"
            @click="handleViewReason(scope.row)"
            v-hasPermi="['biz:job:query']"
            >查看原因</el-button
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

    <!-- 岗位审核对话框 -->
    <el-dialog title="岗位审核" v-model="auditOpen" width="500px" append-to-body>
      <el-form ref="auditRef" :model="auditForm" :rules="auditRules" label-width="90px">
        <el-form-item label="岗位名称">
          <span>{{ auditForm.jobName }}</span>
        </el-form-item>
        <el-form-item label="审核结论" prop="result">
          <el-radio-group v-model="auditForm.result" @change="handleAuditResultChange">
            <el-radio value="1">通过发布</el-radio>
            <el-radio value="2">驳回(违规)</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="驳回原因" prop="reason">
          <el-input v-model="auditForm.reason" type="textarea" :rows="3" placeholder="驳回时必填，请输入驳回原因" />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitAudit">确 定</el-button>
          <el-button @click="auditOpen = false">取 消</el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 违规下架对话框 -->
    <el-dialog title="违规下架" v-model="offOpen" width="500px" append-to-body>
      <el-form ref="offRef" :model="offForm" :rules="offRules" label-width="90px">
        <el-form-item label="岗位名称">
          <span>{{ offForm.jobName }}</span>
        </el-form-item>
        <el-form-item label="下架原因" prop="reason">
          <el-input v-model="offForm.reason" type="textarea" :rows="3" placeholder="请输入违规下架原因" />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="danger" @click="submitOff">确 定</el-button>
          <el-button @click="offOpen = false">取 消</el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 处理信息查看对话框 -->
    <el-dialog title="处理信息" v-model="reasonOpen" width="500px" append-to-body>
      <el-descriptions :column="1" border>
        <el-descriptions-item label="岗位名称">{{ reasonRow.jobName }}</el-descriptions-item>
        <el-descriptions-item label="处理原因">{{ reasonRow.reason || '-' }}</el-descriptions-item>
        <el-descriptions-item label="处理时间">{{ reasonRow.auditTime || '-' }}</el-descriptions-item>
      </el-descriptions>
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="reasonOpen = false">关 闭</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="BizJob">
import { listJob, auditJob } from '@/api/biz/job'

const { proxy } = getCurrentInstance()

// Constants
const STATUS_LABEL_MAP = {
  0: '待审核',
  1: '已发布',
  2: '违规下架',
  3: '已下架'
}
const STATUS_TAG_MAP = { 0: 'warning', 1: 'success', 2: 'danger', 3: 'info' }
const RISK_LEVEL_LABEL_MAP = { 0: '低', 1: '中', 2: '高' }
const RISK_LEVEL_TAG_MAP = { 0: 'success', 1: 'warning', 2: 'danger' }

function statusTag(status) {
  return STATUS_TAG_MAP[status] || 'info'
}

function statusLabel(status) {
  return STATUS_LABEL_MAP[status] || '未知'
}

function riskLevelTag(level) {
  return RISK_LEVEL_TAG_MAP[level] || 'info'
}

function riskLevelLabel(level) {
  return RISK_LEVEL_LABEL_MAP[level] || '-'
}

/** 后端 riskWords 为 JSON 字符串，统一解析为数组 */
function parseRiskWords(val) {
  if (Array.isArray(val)) return val
  if (!val) return []
  try {
    const parsed = JSON.parse(val)
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}
const jobList = ref([])
const loading = ref(true)
const ids = ref([])
const showSearch = ref(true)
const total = ref(0)
const selectedIds = ref([])
const auditOpen = ref(false)
const offOpen = ref(false)
const reasonOpen = ref(false)
const reasonRow = ref({})
const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  jobName: undefined,
  companyName: undefined,
  status: undefined
})

const auditForm = reactive({ jobId: undefined, result: '1', reason: '' })
const offForm = reactive({ jobId: undefined, jobName: '', reason: '' })
const auditRules = {
  result: [{ required: true, message: '请选择审核结论', trigger: 'change' }],
  reason: [{ required: true, message: '请输入驳回原因', trigger: 'blur' }]
}
const offRules = {
  reason: [{ required: true, message: '请输入违规下架原因', trigger: 'blur' }]
}

/** 查询岗位列表 */
function getList() {
  loading.value = true
  listJob(queryParams.value)
    .then((response) => {
      jobList.value = (response.rows || []).map((r) => ({
        ...r,
        riskWords: parseRiskWords(r.riskWords)
      }))
      total.value = response.total
    })
    .catch((err) => {
      console.error('岗位列表查询失败:', err)
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

/** 审核按钮操作 */
function handleAudit(row) {
  auditForm.jobId = row.jobId
  auditForm.jobName = row.jobName
  auditForm.result = '1'
  auditForm.reason = ''
  auditOpen.value = true
}

/** 审核结果变化 */
function handleAuditResultChange(val) {
  if (val === '1') {
    auditForm.reason = ''
  }
}

/** 提交审核 */
function submitAudit() {
  proxy.$refs['auditRef'].validate((valid) => {
    if (valid) {
      const passing = auditForm.result === '1'
      auditJob({
        jobId: auditForm.jobId,
        result: auditForm.result,
        reason: auditForm.reason
      })
        .then(() => {
          proxy.$modal.msgSuccess(passing ? '审核通过，岗位已发布' : '已驳回，岗位已违规下架')
          auditOpen.value = false
          getList()
        })
        .catch((err) => {
          console.error('审核提交失败:', err)
        })
    }
  })
}

/** 违规下架按钮操作 */
function handleOff(row) {
  offForm.jobId = row.jobId
  offForm.jobName = row.jobName
  offForm.reason = ''
  offOpen.value = true
}

/** 提交违规下架 */
function submitOff() {
  proxy.$refs['offRef'].validate((valid) => {
    if (valid) {
      auditJob({
        jobId: offForm.jobId,
        result: '2',
        reason: offForm.reason
      })
        .then(() => {
          proxy.$modal.msgSuccess('违规下架成功')
          offOpen.value = false
          getList()
        })
        .catch((err) => {
          console.error('违规下架失败:', err)
        })
    }
  })
}

/** 查看处理原因 */
function handleViewReason(row) {
  reasonRow.value = row
  reasonOpen.value = true
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.jobId)
}

getList()

const statusOptions = [
  { value: 0, label: '待审核' },
  { value: 1, label: '已发布' },
  { value: 2, label: '违规下架' },
  { value: 3, label: '已下架' }
]
</script>
