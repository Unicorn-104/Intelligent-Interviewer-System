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
      <el-form-item label="面试状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="全部" clearable style="width: 150px">
          <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button
          type="success"
          plain
          icon="CircleCheck"
          @click="handleBatchFinalize"
          v-hasPermi="['biz:interviewEval:finalize']"
          >批量终审</el-button
        >
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="3"
        ><el-statistic title="待评估" :value="stats.pending" /><span class="stat-label">场</span></el-col
      >
      <el-col :span="3"
        ><el-statistic title="已评估" :value="stats.evaluated" /><span class="stat-label">场</span></el-col
      >
      <el-col :span="3"><el-statistic title="已通过" :value="stats.passed" /><span class="stat-label">人</span></el-col>
      <el-col :span="3"
        ><el-statistic title="已淘汰" :value="stats.rejected" /><span class="stat-label">人</span></el-col
      >
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="evalList" stripe>
      <el-table-column label="候选人" align="center" prop="candidate" width="120" />
      <el-table-column label="岗位" align="center" prop="jobName" width="180" />
      <el-table-column label="轮次" align="center" prop="roundName" width="80" />
      <el-table-column label="综合评分" align="center" prop="totalScore" width="100">
        <template #default="scope">
          <span
            :style="{
              fontSize: '16px',
              fontWeight: 600,
              color: scoreColor(scope.row.totalScore)
            }"
            >{{ scope.row.totalScore }}</span
          >
        </template>
      </el-table-column>
      <el-table-column label="面试模式" align="center" prop="mode" width="100">
        <template #default="scope"
          ><el-tag :type="modeTag(scope.row.mode)">{{ modeLabel(scope.row.mode) }}</el-tag></template
        >
      </el-table-column>
      <el-table-column label="评语" align="center" prop="comment" :show-overflow-tooltip="true" min-width="200" />
      <el-table-column label="状态" align="center" prop="status">
        <template #default="scope"
          ><el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag></template
        >
      </el-table-column>
      <el-table-column label="评估时间" align="center" prop="evalTime" width="160">
        <template #default="scope"
          ><span>{{ parseTime(scope.row.evalTime) }}</span></template
        >
      </el-table-column>
      <el-table-column label="操作" align="center" width="150">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleDetail(scope.row)">详情</el-button>
          <el-button
            link
            type="primary"
            icon="Edit"
            @click="handleEdit(scope.row)"
            v-if="scope.row.status === 'pending'"
            >评估</el-button
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

    <el-dialog :title="detailTitle" v-model="dialogOpen" width="700px" append-to-body>
      <div v-if="detailData" style="line-height: 2">
        <h4>评分详情</h4>
        <el-progress
          v-for="(s, i) in detailData.dimensionScores || []"
          :key="i"
          :percentage="s.score"
          :label="s.name + ': ' + s.score + '分'"
          :color="scoreColor(s.score)"
          style="margin: 8px 0"
        />
        <h4>综合评语</h4>
        <p style="background: #f5f7fa; padding: 12px; border-radius: 4px">
          {{ detailData.comment || '暂无评语' }}
        </p>
        <h4>关键标记</h4>
        <p v-for="(k, i) in detailData.keyMarks || []" :key="i">{{ k }}</p>
        <el-form
          v-if="detailTitle === '面试评估'"
          ref="evalRef"
          :model="evalForm"
          :rules="evalRules"
          label-width="80px"
          style="margin-top: 16px"
        >
          <el-form-item label="综合评分"
            ><el-input-number v-model="evalForm.totalScore" :min="0" :max="100"
          /></el-form-item>
          <el-form-item label="评估结果">
            <el-radio-group v-model="evalForm.result">
              <el-radio value="pass">通过</el-radio><el-radio value="reject">淘汰</el-radio
              ><el-radio value="pending">待定</el-radio>
            </el-radio-group>
          </el-form-item>
          <el-form-item label="评语"
            ><el-input v-model="evalForm.comment" type="textarea" :rows="4" placeholder="请输入评估评语"
          /></el-form-item>
        </el-form>
      </div>
      <template #footer>
        <el-button v-if="detailTitle === '面试评估'" type="primary" @click="submitEvalForm">提 交</el-button>
        <el-button @click="dialogOpen = false">关 闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="BizInterviewEval">
import { listInterviewEval, getInterviewEval, submitEval, batchFinalize } from '@/api/biz/interviewEval'

const { proxy } = getCurrentInstance()

// ==================== State ====================
const evalList = ref([])
const stats = ref({ pending: 0, evaluated: 0, passed: 0, rejected: 0 })
const dialogOpen = ref(false)
const evalForm = ref({ totalScore: 0, result: 'pass', comment: '' })
const queryParams = reactive({
  pageNum: 1,
  pageSize: 10,
  candidate: undefined,
  jobName: undefined,
  status: undefined
})

// ==================== Methods ====================
const total = ref(0)
const loading = ref(true)
const detailTitle = ref('')
const detailData = ref(null)
const showSearch = ref(true)

function handleQuery() {
  getList()
}

function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}
/** 查询列表 */
function getList() {
  loading.value = true
  listInterviewEval(queryParams)
    .then((res) => {
      evalList.value = res.rows
      total.value = res.total
    })
    .catch((err) => {
      console.error(err)
      proxy.$modal.msgError('查询失败，请重试')
    })
    .finally(() => {
      loading.value = false
    })
}

/** 详情 */
function handleDetail(row) {
  getInterviewEval(row.evalId || row.interviewId)
    .then((res) => {
      detailData.value = res.data
      detailTitle.value = '面试评估详情'
      evalForm.value = {
        totalScore: res.data.totalScore || 0,
        result: 'pass',
        comment: ''
      }
      dialogOpen.value = true
    })
    .catch((err) => {
      console.error(err)
      proxy.$modal.msgError('加载详情失败')
    })
}

/** 编辑/评估 */
function handleEdit(row) {
  getInterviewEval(row.evalId || row.interviewId)
    .then((res) => {
      detailData.value = res.data
      evalForm.value = {
        totalScore: res.data.totalScore || 0,
        result: 'pass',
        comment: ''
      }
      detailTitle.value = '面试评估'
      dialogOpen.value = true
    })
    .catch((err) => {
      console.error(err)
      proxy.$modal.msgError('加载详情失败')
    })
}

/** 提交评估 */
function submitEvalForm() {
  submitEval({
    evalId: detailData.value?.evalId || detailData.value?.interviewId,
    totalScore: evalForm.value.totalScore,
    result: evalForm.value.result,
    comment: evalForm.value.comment
  })
    .then(() => {
      proxy.$modal.msgSuccess('评估已提交')
      dialogOpen.value = false
      getList()
    })
    .catch((err) => {
      console.error(err)
      proxy.$modal.msgError('提交失败')
    })
}

/** 批量终审 */
function handleBatchFinalize() {
  proxy.$modal
    .confirm('确认要批量终审所有待评估的面试吗？')
    .then(function () {
      return batchFinalize({ status: 'passed' })
    })
    .then(() => {
      proxy.$modal.msgSuccess('批量终审完成')
      getList()
    })
    .catch((err) => {
      console.error(err)
      proxy.$modal.msgError('终审失败')
    })
}

/** 评分颜色 */
function scoreColor(score) {
  if (score >= 80) return '#22C55E'
  if (score >= 60) return '#F59E0B'
  return '#EF4444'
}

/** 面试模式标签 */
function modeLabel(mode) {
  const modeMap = { 0: '纯AI', 1: 'AI+HR协同', 2: '级联' }
  return modeMap[mode] || mode
}
function modeTag(mode) {
  const modeMap = { 0: 'info', 1: 'warning', 2: 'success' }
  return modeMap[mode] || ''
}

/** 状态标签 */
function statusLabel(s) {
  const statusMap = { pending: '待评估', evaluated: '已评估', passed: '通过', rejected: '淘汰' }
  return statusMap[s] || s
}
function statusTag(s) {
  const statusMap = { pending: 'warning', evaluated: 'info', passed: 'success', rejected: 'danger' }
  return statusMap[s] || ''
}

getList()
const statusOptions = [
  { value: 'pending', label: '待评估' },
  { value: 'evaluated', label: '已评估' },
  { value: 'passed', label: '通过' },
  { value: 'rejected', label: '淘汰' }
]
</script>
