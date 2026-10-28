<template>
  <div class="app-container">
    <!-- 统计概览 -->
    <el-row :gutter="12" class="stat-row">
      <el-col :xs="12" :sm="8" :md="4" v-for="card in statCards" :key="card.label">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-num" :style="{ color: card.color }">{{ card.value }}</div>
          <div class="stat-label">{{ card.label }}</div>
        </el-card>
      </el-col>
    </el-row>

    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="姓名/手机号" prop="userName">
        <el-input v-model="queryParams.userName" placeholder="姓名或手机号" clearable style="width: 180px" @keyup.enter="handleQuery" />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="全部状态" clearable style="width: 140px">
          <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="标签" prop="tags">
        <el-select v-model="queryParams.tags" placeholder="全部标签" clearable style="width: 150px">
          <el-option v-for="tag in tagOptions" :key="tag" :label="tag" :value="tag" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
        <el-button type="warning" icon="Download" @click="handleExport">导出Excel</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="candidateList" @sort-change="handleSortChange">
      <el-table-column label="ID" align="center" prop="candidateId" width="70" />
      <el-table-column label="姓名" align="center" prop="userName" min-width="90" />
      <el-table-column label="手机号" align="center" width="120">
        <template #default="scope">{{ maskPhone(scope.row.phonenumber) }}</template>
      </el-table-column>
      <el-table-column label="意向岗位" align="center" prop="jobName" min-width="140" :show-overflow-tooltip="true" />
      <el-table-column label="综合评分" align="center" width="100" sortable="custom" prop="totalScore">
        <template #default="scope">
          <span :style="{ color: scoreColor(scope.row.totalScore) }">{{ scope.row.totalScore ?? '-' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" width="100">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="最近操作" align="center" width="150">
        <template #default="scope">{{ parseTime(scope.row.updateTime) || '-' }}</template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="210" fixed="right">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleView(scope.row)">详情</el-button>
          <el-button link type="primary" icon="Connection" @click="handleTag(scope.row)">标签</el-button>
          <el-button link type="warning" icon="Switch" @click="handleStatus(scope.row)">变更状态</el-button>
        </template>
      </el-table-column>
    </el-table>

    <pagination v-show="total > 0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getList" />

    <!-- 候选人详情对话框 -->
    <el-dialog title="候选人详情" v-model="detailOpen" width="620px" append-to-body class="candidate-detail-dialog">
      <div v-loading="detailLoading">
        <div class="detail-header">
          <div class="detail-avatar">{{ (detail.userName || '?').charAt(0) }}</div>
          <div class="detail-head-info">
            <div class="detail-name">
              {{ detail.userName || '-' }}
              <el-tag :type="statusTag(detail.status)" size="small" effect="light">{{ statusLabel(detail.status) }}</el-tag>
            </div>
            <div class="detail-sub">意向岗位：{{ detail.jobName || '-' }}</div>
          </div>
          <div class="detail-score">
            <div class="score-num" :style="{ color: scoreColor(detail.totalScore) }">{{ detail.totalScore ?? '-' }}</div>
            <div class="score-label">综合评分</div>
          </div>
        </div>

        <el-descriptions :column="2" border size="small" class="detail-desc">
          <el-descriptions-item label="手机号">{{ maskPhone(detail.phonenumber) }}</el-descriptions-item>
          <el-descriptions-item label="邮箱">{{ detail.email && detail.email.includes('@') ? detail.email : '-' }}</el-descriptions-item>
          <el-descriptions-item label="当前轮次">第 {{ detail.currentRound ?? 0 }} 轮</el-descriptions-item>
          <el-descriptions-item label="笔试成绩">
            <span v-if="detail.examScore != null">{{ detail.examScore }} 分（{{ detail.examPass === 1 ? '通过' : '未通过' }}）</span>
            <span v-else>-</span>
          </el-descriptions-item>
          <el-descriptions-item label="最近面试" :span="2">{{ parseTime(detail.latestInterviewTime) || '-' }}</el-descriptions-item>
          <el-descriptions-item label="意向岗位" :span="2">{{ detail.jobName || '-' }}</el-descriptions-item>
          <el-descriptions-item label="简历编号">{{ detail.resumeId || '-' }}</el-descriptions-item>
          <el-descriptions-item label="企业编号">{{ detail.companyId || '-' }}</el-descriptions-item>
          <el-descriptions-item label="创建时间" :span="2">{{ parseTime(detail.createTime) || '-' }}</el-descriptions-item>
        </el-descriptions>

        <div class="detail-tags" v-if="detail.tags && detail.tags.length">
          <div class="tags-title">标签</div>
          <el-tag v-for="t in detail.tags" :key="t" size="small" type="info" effect="plain" class="tag-item">{{ t }}</el-tag>
        </div>

        <div class="detail-history" v-if="detailLogs.length">
          <div class="tags-title">变更历史</div>
          <el-timeline>
            <el-timeline-item v-for="(log, i) in detailLogs" :key="i" :timestamp="fmtTime(log.auditTime)" placement="top">
              <span class="hist-tag">{{ codeLabel(log.fromStatus) }}</span>
              <el-icon class="hist-arrow"><ArrowRight /></el-icon>
              <el-tag size="small" :type="codeTag(log.toStatus)">{{ codeLabel(log.toStatus) }}</el-tag>
              <div class="hist-reason" v-if="log.reason">{{ log.reason }}</div>
            </el-timeline-item>
          </el-timeline>
        </div>
      </div>
    </el-dialog>

    <!-- 标签管理对话框 -->
    <el-dialog :title="dialogTitle" v-model="dialogOpen" width="500px" append-to-body>
      <el-form ref="tagFormRef" :model="tagForm" label-width="80px">
        <el-form-item label="候选人"><span>{{ tagForm.userName }}</span></el-form-item>
        <el-form-item label="推荐标签">
          <el-checkbox-group v-model="tagForm.tags">
            <el-checkbox v-for="tag in tagOptions" :key="tag" :label="tag">{{ tag }}</el-checkbox>
          </el-checkbox-group>
        </el-form-item>
        <el-form-item v-if="tagForm.customTags.length" label="已有标签">
          <el-tag v-for="tag in tagForm.customTags" :key="tag" closable size="small" effect="plain" class="custom-tag" @close="removeCustomTag(tag)">{{ tag }}</el-tag>
        </el-form-item>
        <el-form-item label="备注"><el-input v-model="tagForm.remark" type="textarea" :rows="3" placeholder="可选" /></el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitTag">确 定</el-button>
          <el-button @click="dialogOpen = false">取 消</el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 变更状态对话框 -->
    <el-dialog title="变更状态" v-model="statusOpen" width="460px" append-to-body>
      <el-form label-width="80px">
        <el-form-item label="候选人"><span>{{ statusForm.userName }}</span></el-form-item>
        <el-form-item label="目标状态">
          <el-radio-group v-model="statusForm.target">
            <el-radio v-for="s in statusChangeOptions" :key="s.value" :value="s.value">{{ s.label }}</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="原因"><el-input v-model="statusForm.reason" type="textarea" :rows="3" placeholder="可选，如：面试未通过 / 复试通过" /></el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitStatus">确 定</el-button>
          <el-button @click="statusOpen = false">取 消</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="BizCandidate">
import { ArrowRight } from '@element-plus/icons-vue'
import {
  listCandidate, getCandidate, batchUpdateTag, updateCandidateStatus,
  getCandidateLogs, getCandidateSummary
} from '@/api/biz/business'

const { proxy } = getCurrentInstance()

const SCORE_GOOD = 80
const SCORE_PASS = 60

// 数字状态 → 展示（详情历史用）
const CODE_MAP = {
  0: '新候选人', 1: '已初筛', 2: '面试中', 3: '淘汰', 4: '通过',
  5: '通过', 6: '归档', 7: '归档', 8: '淘汰', 9: '新候选人'
}
const CODE_TAG = { 0: 'info', 1: 'primary', 2: 'warning', 3: 'danger', 4: 'success', 5: 'success', 6: 'info', 7: 'info', 8: 'danger', 9: 'info' }
// 字符串状态（列表SQL映射）→ 展示
const STATUS_LABEL_MAP = { new: '新候选人', screened: '已初筛', interviewing: '面试中', passed: '通过', rejected: '淘汰', archived: '归档' }
const STATUS_TAG_MAP = { new: 'info', screened: 'primary', interviewing: 'warning', passed: 'success', rejected: 'danger', archived: 'info' }

function statusLabel(v) { return STATUS_LABEL_MAP[v] || v || '-' }
function statusTag(v) { return STATUS_TAG_MAP[v] || 'info' }
function codeLabel(v) { return CODE_MAP[v] ?? '-' }
function codeTag(v) { return CODE_TAG[v] || 'info' }
function scoreColor(v) {
  if (v === undefined || v === null || v === '') return '#909399'
  const n = Number(v)
  if (n >= SCORE_GOOD) return '#22C55E'
  if (n >= SCORE_PASS) return '#F59E0B'
  return '#EF4444'
}
function maskPhone(p) {
  if (!p || String(p).length < 7) return p || '-'
  const s = String(p)
  return s.slice(0, 3) + '****' + s.slice(-4)
}
function fmtTime(t) { return t ? String(t).replace('T', ' ').substring(0, 19) : '-' }

const candidateList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const detailOpen = ref(false)
const detailLoading = ref(false)
const detailLogs = ref([])
const dialogOpen = ref(false)
const dialogTitle = ref('')
const statusOpen = ref(false)
const summaryMap = ref({})
const detail = reactive({})

const queryParams = ref({ pageNum: 1, pageSize: 10, userName: undefined, status: undefined, tags: undefined })
const tagForm = reactive({ candidateId: undefined, userName: '', tags: [], customTags: [], remark: '' })
const statusForm = reactive({ candidateId: undefined, userName: '', target: 1, reason: '' })

const tagOptions = ['技术能力强', '沟通表达佳', '经验匹配', '学历优质', '领导潜质']
const statusOptions = [
  { value: 'new', label: '新候选人' },
  { value: 'screened', label: '已初筛' },
  { value: 'interviewing', label: '面试中' },
  { value: 'passed', label: '通过' },
  { value: 'rejected', label: '淘汰' },
  { value: 'archived', label: '归档' }
]
const statusChangeOptions = [
  { value: 1, label: '已初筛' },
  { value: 2, label: '面试中' },
  { value: 4, label: '通过' },
  { value: 3, label: '淘汰' },
  { value: 6, label: '归档' }
]

/** 统计卡 */
const statCards = computed(() => {
  const m = summaryMap.value
  const sum = (codes) => codes.reduce((a, c) => a + (m[c]?.cnt || 0), 0)
  const all = Object.values(m).reduce((a, x) => a + (x.cnt || 0), 0)
  const avg = all ? (Object.values(m).reduce((a, x) => a + (x.avgScore || 0) * x.cnt, 0) / all).toFixed(1) : '0'
  return [
    { label: '候选人总数', value: all, color: '#409eff' },
    { label: '面试中', value: sum([2]), color: '#F59E0B' },
    { label: '通过', value: sum([4, 5]), color: '#22C55E' },
    { label: '淘汰', value: sum([3, 8]), color: '#EF4444' },
    { label: '平均匹配分', value: avg, color: '#909399' }
  ]
})

function loadSummary() {
  getCandidateSummary().then((res) => {
    const map = {}
    ;(res.data || []).forEach((r) => { map[r.statusCode] = r })
    summaryMap.value = map
  }).catch(() => {})
}

function getList() {
  loading.value = true
  listCandidate(queryParams.value)
    .then((response) => {
      candidateList.value = response.rows || []
      total.value = response.total
    })
    .catch((err) => console.error('候选人列表查询失败:', err))
    .finally(() => { loading.value = false })
}

function handleQuery() { queryParams.value.pageNum = 1; getList() }
function resetQuery() { queryParams.value = { pageNum: 1, pageSize: 10, userName: undefined, status: undefined, tags: undefined }; getList() }
function handleExport() {
  proxy.$download.name('候选人数据.xlsx')
  proxy.$download.response('biz/candidate/export', { params: queryParams.value })
}

function handleSortChange({ prop, order }) {
  if (!order) { getList(); return }
  const dir = order === 'ascending' ? 1 : -1
  candidateList.value = [...candidateList.value].sort((a, b) => ((a[prop] ?? 0) - (b[prop] ?? 0)) * dir)
}

/** 详情 */
function handleView(row) {
  detailOpen.value = true
  detailLoading.value = true
  detailLogs.value = []
  getCandidate(row.candidateId).then((res) => {
    Object.assign(detail, res.data || {})
  }).catch((err) => console.error('详情加载失败:', err))
  getCandidateLogs(row.candidateId).then((res) => { detailLogs.value = res.data || [] }).catch(() => {})
    .finally(() => { detailLoading.value = false })
}

/** 标签 */
function handleTag(row) {
  tagForm.candidateId = row.candidateId
  tagForm.userName = row.userName
  const existing = row.tags ? String(row.tags).split(',').map((s) => s.trim()).filter(Boolean) : []
  tagForm.tags = existing.filter((t) => tagOptions.includes(t))
  tagForm.customTags = existing.filter((t) => !tagOptions.includes(t))
  tagForm.remark = ''
  dialogTitle.value = '标签管理 - ' + row.userName
  dialogOpen.value = true
}
function removeCustomTag(tag) { tagForm.customTags = tagForm.customTags.filter((t) => t !== tag) }
function submitTag() {
  batchUpdateTag({ candidateId: tagForm.candidateId, tags: [...tagForm.tags, ...tagForm.customTags].join(','), remark: tagForm.remark })
    .then(() => { dialogOpen.value = false; proxy.$modal.msgSuccess('标签更新成功'); getList() })
    .catch((err) => console.error('标签更新失败:', err))
}

/** 变更状态 */
function handleStatus(row) {
  statusForm.candidateId = row.candidateId
  statusForm.userName = row.userName
  statusForm.target = 1
  statusForm.reason = ''
  statusOpen.value = true
}
function submitStatus() {
  updateCandidateStatus({ candidateId: statusForm.candidateId, status: statusForm.target, reason: statusForm.reason })
    .then(() => { statusOpen.value = false; proxy.$modal.msgSuccess('状态更新成功'); getList(); loadSummary() })
    .catch((err) => console.error('状态更新失败:', err))
}

getList()
loadSummary()
</script>

<style scoped>
.stat-row { margin-bottom: 12px; }
.stat-card { text-align: center; }
.stat-num { font-size: 26px; font-weight: 700; line-height: 1.2; }
.stat-label { font-size: 13px; color: #909399; margin-top: 4px; }
.candidate-detail-dialog .detail-header { display: flex; align-items: center; gap: 16px; padding: 4px 4px 18px; border-bottom: 1px solid #ebeef5; }
.candidate-detail-dialog .detail-avatar { width: 56px; height: 56px; border-radius: 50%; background: linear-gradient(135deg, #4e7cff, #22c55e); color: #fff; font-size: 24px; font-weight: 600; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.candidate-detail-dialog .detail-head-info { flex: 1; min-width: 0; }
.candidate-detail-dialog .detail-name { font-size: 18px; font-weight: 600; color: #303133; display: flex; align-items: center; gap: 8px; }
.candidate-detail-dialog .detail-sub { margin-top: 6px; font-size: 13px; color: #909399; }
.candidate-detail-dialog .detail-score { text-align: center; flex-shrink: 0; }
.candidate-detail-dialog .score-num { font-size: 28px; font-weight: 700; line-height: 1; }
.candidate-detail-dialog .score-label { margin-top: 4px; font-size: 12px; color: #909399; }
.detail-desc { margin-top: 18px; }
.detail-tags, .detail-history { margin-top: 16px; }
.tags-title { font-size: 13px; color: #606266; margin-bottom: 8px; font-weight: 600; }
.tag-item { margin: 0 8px 8px 0; }
.custom-tag { margin: 0 8px 8px 0; }
.hist-tag { margin-right: 4px; color: #909399; }
.hist-arrow { margin: 0 4px; vertical-align: middle; }
.hist-reason { color: #606266; font-size: 13px; margin-top: 2px; }
</style>
