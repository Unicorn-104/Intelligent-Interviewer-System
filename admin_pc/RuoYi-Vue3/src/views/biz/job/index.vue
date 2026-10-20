<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="岗位名称" prop="jobName">
        <el-input v-model="queryParams.jobName" placeholder="请输入岗位名称" clearable style="width: 200px" @keyup.enter="handleQuery" />
      </el-form-item>
      <el-form-item label="企业名称" prop="companyName">
        <el-input v-model="queryParams.companyName" placeholder="请输入企业名称" clearable style="width: 200px" @keyup.enter="handleQuery" />
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

    <el-card shadow="never" v-loading="loading">
      <el-collapse v-model="activeNames">
        <el-collapse-item v-for="group in companyGroups" :key="group.companyName" :name="group.companyName">
          <template #title>
            <div class="company-header">
              <el-icon class="company-icon"><OfficeBuilding /></el-icon>
              <span class="company-name">{{ group.companyName }}</span>
              <el-tag size="small" type="info">{{ group.count }} 个岗位</el-tag>
            </div>
          </template>

          <el-table :data="group.jobs" border size="small">
            <el-table-column label="ID" align="center" prop="jobId" width="70" />
            <el-table-column label="岗位名称" align="center" prop="jobName" :show-overflow-tooltip="true" />
            <el-table-column label="薪资" align="center" prop="salary" width="110" />
            <el-table-column label="城市" align="center" prop="city" width="80" />
            <el-table-column label="风险等级" align="center" width="80">
              <template #default="scope">
                <el-tag v-if="scope.row.riskLevel !== null && scope.row.riskLevel !== undefined && scope.row.riskLevel !== ''"
                  :type="riskLevelTag(scope.row.riskLevel)">{{ riskLevelLabel(scope.row.riskLevel) }}</el-tag>
                <span v-else>-</span>
              </template>
            </el-table-column>
            <el-table-column label="命中风控词" align="center" min-width="140">
              <template #default="scope">
                <template v-if="scope.row.riskWords && scope.row.riskWords.length > 0">
                  <el-tag v-for="(word, index) in scope.row.riskWords" :key="index" type="danger" size="small" class="risk-tag">{{ word }}</el-tag>
                </template>
                <span v-else>-</span>
              </template>
            </el-table-column>
            <el-table-column label="状态" align="center" width="90">
              <template #default="scope">
                <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="发布时间" align="center" width="105">
              <template #default="scope">
                <span>{{ parseTime(scope.row.publishTime, '{y}-{m}-{d}') || '-' }}</span>
              </template>
            </el-table-column>
            <el-table-column label="操作" align="center" width="210" fixed="right">
              <template #default="scope">
                <el-button v-if="Number(scope.row.status) === 0" link type="primary" icon="Edit" @click="handleAudit(scope.row)" v-hasPermi="['biz:job:audit']">审核</el-button>
                <el-button v-if="Number(scope.row.status) === 1" link type="danger" icon="CircleClose" @click="handleOff(scope.row)" v-hasPermi="['biz:job:audit']">违规下架</el-button>
                <el-button v-if="Number(scope.row.status) === 2 || Number(scope.row.status) === 3" link type="success" icon="RefreshRight" @click="handleRestore(scope.row)" v-hasPermi="['biz:job:audit']">恢复上架</el-button>
                <el-button v-if="Number(scope.row.status) === 2 || Number(scope.row.status) === 3" link type="primary" icon="View" @click="handleHistory(scope.row)" v-hasPermi="['biz:job:query']">查看原因</el-button>
                <el-button link type="primary" icon="Document" @click="handleDetail(scope.row)" v-hasPermi="['biz:job:query']">详情</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-collapse-item>
      </el-collapse>
      <el-empty v-if="!loading && companyGroups.length === 0" description="暂无岗位数据" />
    </el-card>

    <pagination v-show="total > 0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getList" />

    <!-- 岗位审核对话框 -->
    <el-dialog title="岗位审核" v-model="auditOpen" width="500px" append-to-body>
      <el-form ref="auditRef" :model="auditForm" :rules="auditRules" label-width="90px">
        <el-form-item label="岗位名称"><span>{{ auditForm.jobName }}</span></el-form-item>
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
        <el-form-item label="岗位名称"><span>{{ offForm.jobName }}</span></el-form-item>
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

    <!-- 岗位详情 / JD 对话框 -->
    <el-dialog title="岗位详情" v-model="detailOpen" width="620px" append-to-body>
      <el-descriptions :column="2" border>
        <el-descriptions-item label="岗位名称">{{ detailForm.jobName }}</el-descriptions-item>
        <el-descriptions-item label="企业名称">{{ detailForm.companyName }}</el-descriptions-item>
        <el-descriptions-item label="城市">{{ detailForm.city || '-' }}</el-descriptions-item>
        <el-descriptions-item label="薪资">{{ detailSalary }}</el-descriptions-item>
        <el-descriptions-item label="状态">
          <el-tag :type="statusTag(detailForm.status)">{{ statusLabel(detailForm.status) }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="发布时间">{{ fmtTime(detailForm.publishTime) }}</el-descriptions-item>
      </el-descriptions>
      <div class="jd-block" v-if="jd.responsibilities && jd.responsibilities.length">
        <div class="jd-title">岗位职责</div>
        <ul><li v-for="(r, i) in jd.responsibilities" :key="i">{{ r }}</li></ul>
      </div>
      <div class="jd-block" v-if="jd.requirements && jd.requirements.length">
        <div class="jd-title">任职要求</div>
        <ul><li v-for="(r, i) in jd.requirements" :key="i">{{ r }}</li></ul>
      </div>
      <el-empty v-if="!jd.requirements?.length && !jd.responsibilities?.length" description="暂无 JD 内容" :image-size="60" />
    </el-dialog>

    <!-- 变更历史 / 处理原因对话框 -->
    <el-dialog title="处理信息与变更历史" v-model="historyOpen" width="560px" append-to-body>
      <el-timeline v-if="logList.length">
        <el-timeline-item v-for="(log, i) in logList" :key="i" :timestamp="fmtTime(log.auditTime)"
          :type="logTypeColor(log.toStatus)" placement="top">
          <div class="log-line">
            <el-tag size="small" :type="statusTag(log.fromStatus)">{{ statusLabel(log.fromStatus) }}</el-tag>
            <el-icon><ArrowRight /></el-icon>
            <el-tag size="small" :type="statusTag(log.toStatus)">{{ statusLabel(log.toStatus) }}</el-tag>
          </div>
          <div class="log-reason" v-if="log.reason">原因：{{ log.reason }}</div>
        </el-timeline-item>
      </el-timeline>
      <el-empty v-else description="暂无处理记录" :image-size="60" />
    </el-dialog>
  </div>
</template>

<script setup name="BizJob">
import { OfficeBuilding, RefreshRight, Document, View, ArrowRight } from '@element-plus/icons-vue'
import { listJob, auditJob, getJobDetail, getJobLogs } from '@/api/biz/job'

const { proxy } = getCurrentInstance()

const STATUS_LABEL_MAP = { 0: '待审核', 1: '已发布', 2: '违规下架', 3: '已下架' }
const STATUS_TAG_MAP = { 0: 'warning', 1: 'success', 2: 'danger', 3: 'info' }
const RISK_LEVEL_LABEL_MAP = { 0: '低', 1: '中', 2: '高' }
const RISK_LEVEL_TAG_MAP = { 0: 'success', 1: 'warning', 2: 'danger' }

function statusTag(status) { return STATUS_TAG_MAP[status] || 'info' }
function statusLabel(status) { return STATUS_LABEL_MAP[status] || '未知' }
function riskLevelTag(level) { return RISK_LEVEL_TAG_MAP[level] || 'info' }
function riskLevelLabel(level) { return RISK_LEVEL_LABEL_MAP[level] || '-' }
function logTypeColor(to) { return to === 1 ? 'success' : to === 2 ? 'danger' : 'info' }

function parseRiskWords(val) {
  if (Array.isArray(val)) return val
  if (!val) return []
  try { const p = JSON.parse(val); return Array.isArray(p) ? p : [] } catch { return [] }
}

function fmtTime(time) {
  if (!time) return '-'
  return String(time).replace('T', ' ').substring(0, 19)
}

const jobList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const activeNames = ref([])
const auditOpen = ref(false)
const offOpen = ref(false)
const detailOpen = ref(false)
const historyOpen = ref(false)
const logList = ref([])
const detailForm = reactive({})
const queryParams = ref({ pageNum: 1, pageSize: 10, jobName: undefined, companyName: undefined, status: undefined })

const auditForm = reactive({ jobId: undefined, jobName: '', result: '1', reason: '' })
const offForm = reactive({ jobId: undefined, jobName: '', reason: '' })
const auditRules = {
  result: [{ required: true, message: '请选择审核结论', trigger: 'change' }]
}
const offRules = { reason: [{ required: true, message: '请输入违规下架原因', trigger: 'blur' }] }

const jd = ref({})
const detailSalary = computed(() => {
  if (detailForm.salaryMin == null && detailForm.salaryMax == null) return '面议'
  const min = detailForm.salaryMin ? Math.round(detailForm.salaryMin / 1000) : null
  const max = detailForm.salaryMax ? Math.round(detailForm.salaryMax / 1000) : null
  if (min != null && max != null) return `${min}-${max}K`
  return min != null ? `${min}K起` : `${max}K以下`
})

const companyGroups = computed(() => {
  const map = new Map()
  jobList.value.forEach((row) => {
    const key = row.companyName || '未知企业'
    if (!map.has(key)) map.set(key, [])
    map.get(key).push(row)
  })
  return [...map.entries()].map(([companyName, jobs]) => ({ companyName, jobs, count: jobs.length }))
})

function getList() {
  loading.value = true
  listJob(queryParams.value)
    .then((response) => {
      jobList.value = (response.rows || []).map((r) => ({ ...r, riskWords: parseRiskWords(r.riskWords) }))
      total.value = response.total
      activeNames.value = companyGroups.value.map((g) => g.companyName)
    })
    .catch((err) => console.error('岗位列表查询失败:', err))
    .finally(() => { loading.value = false })
}

function handleQuery() { queryParams.value.pageNum = 1; getList() }
function resetQuery() { handleQuery() }

function handleAudit(row) {
  auditForm.jobId = row.jobId
  auditForm.jobName = row.jobName
  auditForm.result = '1'
  auditForm.reason = ''
  auditOpen.value = true
}
function handleAuditResultChange(val) { if (val === '1') auditForm.reason = '' }

function submitAudit() {
  proxy.$refs['auditRef'].validate((valid) => {
    if (!valid) return
    const passing = auditForm.result === '1'
    if (!passing && !auditForm.reason?.trim()) {
      proxy.$modal.msgError('请输入驳回原因')
      return
    }
    auditJob({ jobId: auditForm.jobId, result: auditForm.result, reason: auditForm.reason })
      .then(() => {
        proxy.$modal.msgSuccess(passing ? '审核通过，岗位已发布' : '已驳回，岗位已违规下架')
        auditOpen.value = false
        getList()
      })
      .catch((err) => console.error('审核提交失败:', err))
  })
}

function handleOff(row) {
  offForm.jobId = row.jobId
  offForm.jobName = row.jobName
  offForm.reason = ''
  offOpen.value = true
}

function submitOff() {
  proxy.$refs['offRef'].validate((valid) => {
    if (!valid) return
    auditJob({ jobId: offForm.jobId, result: '2', reason: offForm.reason })
      .then(() => {
        proxy.$modal.msgSuccess('违规下架成功')
        offOpen.value = false
        getList()
      })
      .catch((err) => console.error('违规下架失败:', err))
  })
}

/** 恢复上架：违规/已下架 → 已发布 */
function handleRestore(row) {
  proxy.$confirm(`确认将「${row.jobName}」恢复上架为已发布？`, '恢复上架', { type: 'warning' })
    .then(() => auditJob({ jobId: row.jobId, result: '3', reason: '恢复上架' }))
    .then(() => {
      proxy.$modal.msgSuccess('已恢复上架')
      getList()
    })
    .catch((err) => { if (err !== 'cancel') console.error('恢复上架失败:', err) })
}

/** 岗位详情 / JD */
function handleDetail(row) {
  getJobDetail(row.jobId).then((res) => {
    Object.assign(detailForm, res.data || {})
    try { jd.value = detailForm.jdJson ? JSON.parse(detailForm.jdJson) : {} } catch { jd.value = {} }
    detailOpen.value = true
  })
}

/** 变更历史 / 处理原因 */
function handleHistory(row) {
  getJobLogs(row.jobId).then((res) => {
    logList.value = res.data || []
    historyOpen.value = true
  })
}

getList()

const statusOptions = [
  { value: 0, label: '待审核' },
  { value: 1, label: '已发布' },
  { value: 2, label: '违规下架' },
  { value: 3, label: '已下架' }
]
</script>

<style scoped>
.company-header { display: flex; align-items: center; gap: 8px; }
.company-icon { color: #409eff; }
.company-name { font-weight: 600; margin-right: 4px; }
.risk-tag { margin-right: 4px; }
.jd-block { margin-top: 14px; }
.jd-title { font-weight: 600; margin-bottom: 6px; color: #303133; }
.jd-block ul { margin: 0; padding-left: 20px; }
.jd-block li { line-height: 1.9; color: #606266; }
.log-line { display: flex; align-items: center; gap: 6px; margin-bottom: 4px; }
.log-reason { color: #606266; font-size: 13px; }
</style>
