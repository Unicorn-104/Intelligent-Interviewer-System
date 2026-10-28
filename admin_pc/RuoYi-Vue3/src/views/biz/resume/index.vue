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

    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="姓名" prop="name">
        <el-input v-model="queryParams.name" placeholder="请输入姓名" clearable style="width: 180px" @keyup.enter="handleQuery" />
      </el-form-item>
      <el-form-item label="目标岗位" prop="jobName">
        <el-input v-model="queryParams.jobName" placeholder="请输入岗位" clearable style="width: 180px" @keyup.enter="handleQuery" />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="resumeList" stripe>
      <el-table-column label="姓名" align="center" prop="name" width="100" />
      <el-table-column label="手机号" align="center" width="130">
        <template #default="scope">{{ maskPhone(scope.row.phone) }}</template>
      </el-table-column>
      <el-table-column label="邮箱" align="center" prop="email" :show-overflow-tooltip="true" min-width="180">
        <template #default="scope">{{ scope.row.email ? scope.row.email.replace(/(\w{2})\w*(@.*)/, '$1****$2') : '-' }}</template>
      </el-table-column>
      <el-table-column label="目标岗位" align="center" prop="jobName" :show-overflow-tooltip="true" min-width="150" />
      <el-table-column label="匹配分" align="center" width="90">
        <template #default="scope">
          <span :style="{ color: scoreColor(scope.row.matchScore), fontWeight: 600 }">
            {{ scope.row.matchScore == null || scope.row.matchScore === '' ? '-' : scope.row.matchScore }}
          </span>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" width="100">
        <template #default="scope">
          <el-tag :type="codeTag(scope.row.statusCode)">{{ codeLabel(scope.row.statusCode) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="上传时间" align="center" width="160">
        <template #default="scope">{{ fmtTime(scope.row.uploadTime) }}</template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="150" fixed="right">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleView(scope.row)">预览</el-button>
          <el-button link type="success" icon="Download" @click="handleDownload(scope.row)">下载</el-button>
          <el-button link type="danger" icon="Delete" @click="handleDelete(scope.row)">删除</el-button>
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

    <!-- 简历详情 -->
    <el-dialog :title="detailTitle" v-model="dialogOpen" width="760px" append-to-body>
      <div v-if="resumeDetail" class="resume-detail">
        <h4>基本信息</h4>
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="姓名">{{ resumeDetail.name || '-' }}</el-descriptions-item>
          <el-descriptions-item label="手机号">{{ maskPhone(resumeDetail.phone) }}</el-descriptions-item>
          <el-descriptions-item label="邮箱">{{ resumeDetail.email ? resumeDetail.email.replace(/(\w{2})\w*(@.*)/, '$1****$2') : '-' }}</el-descriptions-item>
          <el-descriptions-item label="目标岗位">{{ resumeDetail.jobName || '-' }}</el-descriptions-item>
          <el-descriptions-item label="上传时间">{{ fmtTime(resumeDetail.uploadTime) }}</el-descriptions-item>
        </el-descriptions>

        <template v-if="(resumeDetail.skillList || []).length">
          <h4>技能</h4>
          <el-tag v-for="sk in resumeDetail.skillList" :key="sk.skillId" class="skill-tag" type="info" effect="light">
            {{ sk.name }}（{{ levelLabel(sk.level) }}）
          </el-tag>
        </template>

        <template v-if="(resumeDetail.workList || []).length">
          <h4>工作经历</h4>
          <div v-for="w in resumeDetail.workList" :key="w.workId" class="exp-item">
            <div class="exp-head">
              <strong>{{ w.company }}</strong>
              <span class="exp-meta">{{ w.position }}<template v-if="w.department"> · {{ w.department }}</template></span>
              <span class="exp-time">{{ fmtRange(w.startDate, w.endDate, w.isCurrent) }}</span>
            </div>
            <div v-if="w.description" class="exp-desc">{{ w.description }}</div>
          </div>
        </template>

        <template v-if="(resumeDetail.eduList || []).length">
          <h4>教育经历</h4>
          <div v-for="e in resumeDetail.eduList" :key="e.eduId" class="exp-item">
            <div class="exp-head">
              <strong>{{ e.school }}</strong>
              <span class="exp-meta">{{ degreeLabel(e.degree) }} · {{ e.major }}</span>
              <span class="exp-time">{{ fmtRange(e.startDate, e.endDate) }}</span>
            </div>
            <div v-if="e.description" class="exp-desc">{{ e.description }}</div>
          </div>
        </template>

        <template v-if="(resumeDetail.projList || []).length">
          <h4>项目经历</h4>
          <div v-for="p in resumeDetail.projList" :key="p.projId" class="exp-item">
            <div class="exp-head">
              <strong>{{ p.name }}</strong>
              <span class="exp-meta">{{ p.role }}</span>
              <span class="exp-time">{{ fmtRange(p.startDate, p.endDate) }}</span>
            </div>
            <div v-if="p.techStack" class="exp-desc tech">技术栈：{{ p.techStack }}</div>
            <div v-if="p.description" class="exp-desc">{{ p.description }}</div>
          </div>
        </template>

        <el-empty v-if="isEmptyDetail" description="暂无简历详细内容" :image-size="80" />
      </div>
      <template #footer><el-button @click="dialogOpen = false">关 闭</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="BizResume">
import { listResume, getResume, delResume, getResumeSummary } from '@/api/biz/resume'

const { proxy } = getCurrentInstance()

// ==================== 状态映射 ====================
const CODE_MAP = {
  0: '新候选人', 1: '已初筛', 2: '面试中', 3: '淘汰', 4: '通过',
  5: '通过', 6: '归档', 7: '归档', 8: '淘汰', 9: '新候选人'
}
const CODE_TAG = { 0: 'info', 1: 'primary', 2: 'warning', 3: 'danger', 4: 'success', 5: 'success', 6: 'info', 7: 'info', 8: 'danger', 9: 'info' }
const DEGREE_MAP = { 1: '大专', 2: '本科', 3: '硕士', 4: '博士' }
const LEVEL_MAP = { 1: '初级', 2: '中级', 3: '高级' }

function codeLabel(v) { return CODE_MAP[v] ?? (v == null ? '-' : v) }
function codeTag(v) { return CODE_TAG[v] || 'info' }
function degreeLabel(v) { return DEGREE_MAP[v] || (v == null ? '-' : v) }
function levelLabel(v) { return LEVEL_MAP[v] || (v == null ? '-' : v) }
function scoreColor(v) {
  if (v === undefined || v === null || v === '') return '#909399'
  const n = Number(v)
  if (n >= 80) return '#22C55E'
  if (n >= 60) return '#F59E0B'
  return '#EF4444'
}
function maskPhone(p) {
  if (!p || String(p).length < 7) return p || '-'
  const s = String(p)
  return s.slice(0, 3) + '****' + s.slice(-4)
}
function fmtTime(t) { return t ? String(t).replace('T', ' ').substring(0, 19) : '-' }
function fmtRange(start, end, isCurrent) {
  const s = start ? String(start).substring(0, 10) : '?'
  const e = isCurrent === 1 ? '至今' : (end ? String(end).substring(0, 10) : '至今')
  return `${s} ~ ${e}`
}

// ==================== State ====================
const resumeList = ref([])
const total = ref(0)
const loading = ref(true)
const showSearch = ref(true)
const summaryMap = ref({})
const dialogOpen = ref(false)
const detailTitle = ref('')
const resumeDetail = ref(null)
const queryParams = ref({ pageNum: 1, pageSize: 10, name: undefined, jobName: undefined })

const isEmptyDetail = computed(() => {
  const d = resumeDetail.value
  if (!d) return false
  return !(d.skillList?.length || d.workList?.length || d.eduList?.length || d.projList?.length)
})

const statCards = computed(() => {
  const m = summaryMap.value
  const sum = (codes) => codes.reduce((a, c) => a + (m[c]?.cnt || 0), 0)
  return [
    { label: '简历总数', value: total.value, color: '#409eff' },
    { label: '面试中', value: sum([2]), color: '#F59E0B' },
    { label: '通过', value: sum([4, 5]), color: '#22C55E' },
    { label: '淘汰', value: sum([3, 8]), color: '#EF4444' }
  ]
})

function handleQuery() {
  queryParams.pageNum = 1
  getList()
}

function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}

function loadSummary() {
  getResumeSummary().then((res) => {
    const map = {}
    ;(res.data || []).forEach((r) => { map[r.statusCode] = r })
    summaryMap.value = map
  }).catch(() => {})
}

function getList() {
  loading.value = true
  listResume(queryParams.value)
    .then((res) => {
      resumeList.value = res.rows
      total.value = res.total
    })
    .catch((err) => {
      console.error('简历列表查询失败:', err)
      proxy.$modal.msgError('查询失败，请重试')
    })
    .finally(() => { loading.value = false })
}

function handleView(row) {
  getResume(row.resumeId)
    .then((res) => {
      resumeDetail.value = res.data
      detailTitle.value = row.name + ' - 简历详情'
      dialogOpen.value = true
    })
    .catch((err) => {
      console.error(err)
      proxy.$modal.msgError('加载详情失败')
    })
}

function handleDownload(row) {
  const url = row.resumeFile || row.fileUrl
  if (!url) {
    proxy.$modal.msgWarning('该简历无附件')
    return
  }
  window.open(url, '_blank')
}

function handleDelete(row) {
  if (!row.resumeId) {
    proxy.$modal.msgWarning('请先选择要删除的简历')
    return
  }
  proxy.$modal
    .confirm(`是否确认删除简历「${row.name}」？删除后不可恢复。`)
    .then(() => delResume(row.resumeId))
    .then(() => {
      proxy.$modal.msgSuccess('删除成功')
      getList()
      loadSummary()
    })
    .catch(() => {})
}

getList()
loadSummary()
</script>

<style scoped>
.stat-row { margin-bottom: 12px; }
.stat-card { text-align: center; }
.stat-num { font-size: 26px; font-weight: 700; line-height: 1.4; }
.stat-label { color: '#909399'; font-size: 13px; margin-top: 4px; }
.resume-detail h4 { margin: 16px 0 8px; }
.skill-tag { margin: 0 8px 8px 0; }
.exp-item { padding: 10px 12px; background: #f5f7fa; border-radius: 6px; margin-bottom: 10px; }
.exp-head { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; flex-wrap: wrap; }
.exp-meta { color: #606266; font-size: 13px; }
.exp-time { color: '#909399'; font-size: 12px; white-space: nowrap; }
.exp-desc { margin-top: 6px; font-size: 13px; color: #606266; line-height: 1.7; }
.exp-desc.tech { color: #409eff; }
</style>
