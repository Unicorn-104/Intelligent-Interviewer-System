<template>
  <div class="app-container">
    <el-table v-loading="loading" :data="interviewList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="50" align="center" />
      <el-table-column label="ID" align="center" prop="interviewId" width="70" />
      <el-table-column label="候选人" align="center" prop="candidate" min-width="120" />
      <el-table-column label="岗位" align="center" prop="jobName" min-width="180" :show-overflow-tooltip="true" />
      <el-table-column label="企业" align="center" prop="companyName" min-width="120" />
      <el-table-column label="轮次" align="center" prop="roundName" width="80" />
      <el-table-column label="面试模式" align="center" width="120">
        <template #default="scope">
          <el-tag :type="modeTag(scope.row.mode)">{{ modeLabel(scope.row.mode) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" width="100">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">
            <span v-if="Number(scope.row.status) === 1" class="dot-running"></span>{{ statusLabel(scope.row.status) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="开始时间" align="center" width="160">
        <template #default="scope">{{ parseTime(scope.row.startTime) || '-' }}</template>
      </el-table-column>
      <el-table-column label="已进行时长" align="center" prop="duration" width="100" />
      <el-table-column label="综合评分" align="center" width="90">
        <template #default="scope">
          <span>{{ formatScore(scope.row.score) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="鉴权异常" align="center" width="90">
        <template #default="scope">
          <el-tag v-if="scope.row.authFail > 0" type="danger">{{ scope.row.authFail }} 次</el-tag>
          <span v-else>0</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="150" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleDetail(scope.row)">详情</el-button>
          <el-button
            v-if="Number(scope.row.status) === 1"
            link
            type="danger"
            icon="CircleClose"
            @click="handleTerminate(scope.row)"
            >强制结束</el-button
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

    <!-- 面试详情抽屉 -->
    <el-drawer v-model="detailOpen" size="700px" :title="detailTitle" append-to-body>
      <div v-loading="detailLoading" class="drawer-body">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="面试ID">{{ detailInterview.interviewId }}</el-descriptions-item>
          <el-descriptions-item label="候选人">{{ detailInterview.candidate }}</el-descriptions-item>
          <el-descriptions-item label="岗位">{{ detailInterview.jobName }}</el-descriptions-item>
          <el-descriptions-item label="企业">{{ detailInterview.companyName }}</el-descriptions-item>
          <el-descriptions-item label="轮次">{{ detailInterview.roundName }}</el-descriptions-item>
          <el-descriptions-item label="面试模式">
            <el-tag :type="modeTag(detailInterview.mode)">{{ modeLabel(detailInterview.mode) }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="statusTag(detailInterview.status)">{{ statusLabel(detailInterview.status) }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="开始时间">{{ parseTime(detailInterview.startTime) || '-' }}</el-descriptions-item>
          <el-descriptions-item label="已进行时长">{{ detailInterview.duration }}</el-descriptions-item>
          <el-descriptions-item label="综合评分">{{ formatScore(detailInterview.score) }}</el-descriptions-item>
          <el-descriptions-item label="鉴权异常" :span="2">
            <el-tag v-if="detailInterview.authFail > 0" type="danger">{{ detailInterview.authFail }} 次</el-tag>
            <span v-else>0</span>
          </el-descriptions-item>
          <el-descriptions-item v-if="detailInterview.terminateReason" label="终止原因" :span="2">{{
            detailInterview.terminateReason
          }}</el-descriptions-item>
        </el-descriptions>

        <el-divider content-position="left">会话鉴权日志</el-divider>
        <el-table :data="authLogs">
          <el-table-column label="时间" align="center" prop="time" width="160" />
          <el-table-column label="事件" align="center" prop="event" min-width="140" />
          <el-table-column label="IP" align="center" prop="ip" width="130" />
          <el-table-column label="设备" align="center" prop="device" min-width="150" :show-overflow-tooltip="true" />
          <el-table-column label="结果" align="center" width="80">
            <template #default="scope">
              <el-tag :type="resultTag(scope.row.result)">{{ scope.row.result }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="详情" align="center" min-width="160" :show-overflow-tooltip="true">
            <template #default="scope">
              <span>{{ scope.row.detail || '-' }}</span>
            </template>
          </el-table-column>
        </el-table>
      </div>
    </el-drawer>

    <!-- 强制结束面试对话框 -->
    <el-dialog title="强制结束面试" v-model="terminateOpen" width="500px" append-to-body>
      <el-form ref="terminateRef" :model="terminateForm" :rules="terminateRules" label-width="80px">
        <el-form-item label="候选人">
          <span>{{ terminateRow.candidate }}</span>
        </el-form-item>
        <el-form-item label="结束原因" prop="reason">
          <el-input
            v-model="terminateForm.reason"
            type="textarea"
            :rows="4"
            maxlength="200"
            show-word-limit
            placeholder="如：检测到作弊行为"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitTerminate">确 定</el-button>
          <el-button @click="cancelTerminate">取 消</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="BizInterview">
import { listInterview, getInterview, terminateInterview } from '@/api/biz/interview'

const { proxy } = getCurrentInstance()

// Constants
const MODE_LABEL_MAP = { 0: '纯AI面试', 1: 'AI+HR协同', 2: '级联面试' }
const MODE_TAG_MAP = { 0: 'primary', 1: 'success', 2: 'warning' }
const STATUS_LABEL_MAP = { 0: '待开始', 1: '进行中', 2: '已完成', 3: '异常' }
const STATUS_TAG_MAP = { 0: 'info', 1: 'primary', 2: 'success', 3: 'danger' }

const interviewList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const selectedIds = ref([])
const handleSelectionChange = (selection) => {
  selectedIds.value = selection.map((item) => item.interviewId)
}

const detailOpen = ref(false)
const detailLoading = ref(false)
const detailTitle = ref('面试详情')
const detailInterview = ref({})
const terminateOpen = ref(false)
const terminateRow = ref({})
const queryParams = ref({ pageNum: 1, pageSize: 10 })
const terminateForm = ref({ interviewId: undefined, reason: undefined })
const terminateRules = ref({
  reason: [{ required: true, message: '结束原因不能为空', trigger: 'blur' }]
})
const authLogs = ref([])

/** 查询面试列表 */
function getList() {
  loading.value = true
  listInterview(queryParams.value)
    .then((response) => {
      interviewList.value = response.rows
      total.value = response.total
    })
    .catch((err) => {
      console.error('面试列表查询失败:', err)
    })
    .finally(() => {
      loading.value = false
    })
}

/** 详情按钮操作 */
function handleDetail(row) {
  detailOpen.value = true
  detailLoading.value = true
  getInterview(row.interviewId)
    .then((response) => {
      const data = response.data || {}
      detailInterview.value = data
      authLogs.value = data.authLogs || []
    })
    .catch((err) => {
      console.error('面试详情查询失败:', err)
    })
    .finally(() => {
      detailLoading.value = false
    })
}

/** 强制结束面试 */
function handleTerminate(row) {
  terminateRow.value = row
  terminateForm.value = { interviewId: row.interviewId, reason: undefined }
  terminateOpen.value = true
}

/** 提交强制结束 */
function submitTerminate() {
  proxy.$refs['terminateRef'].validate((valid) => {
    if (valid) {
      terminateInterview({
        interviewId: terminateForm.value.interviewId,
        reason: terminateForm.value.reason
      })
        .then(() => {
          terminateOpen.value = false
          proxy.$modal.msgSuccess('强制结束成功')
          getList()
        })
        .catch((err) => {
          console.error('强制结束失败:', err)
        })
    }
  })
}

/** 取消终止 */
function cancelTerminate() {
  terminateOpen.value = false
}

/** 面试模式显示 */
function modeLabel(val) {
  return MODE_LABEL_MAP[val] !== undefined ? MODE_LABEL_MAP[val] : val
}

function modeTag(val) {
  return MODE_TAG_MAP[val] !== undefined ? MODE_TAG_MAP[val] : undefined
}

/** 状态显示 */
function statusLabel(val) {
  return STATUS_LABEL_MAP[val] !== undefined ? STATUS_LABEL_MAP[val] : val
}

function statusTag(val) {
  return STATUS_TAG_MAP[val] !== undefined ? STATUS_TAG_MAP[val] : undefined
}

/** 鉴权显示结果 */
function resultTag(val) {
  if (val === '拦截') {
    return 'danger'
  }
  return 'success'
}

/** 综合评分为 0 时显示 - */
function formatScore(val) {
  if (val === undefined || val === null || val === '' || Number(val) === 0) {
    return '-'
  }
  return String(val)
}

getList()
</script>
