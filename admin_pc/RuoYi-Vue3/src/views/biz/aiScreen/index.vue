<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch" label-width="100px">
      <el-form-item label="岗位名称" prop="jobName">
        <el-input
          v-model="queryParams.jobName"
          placeholder="请输入岗位名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="筛选状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="全部" clearable style="width: 150px">
          <el-option label="待筛选" value="pending" /><el-option label="已筛选" value="screened" /><el-option
            label="短名单"
            value="shortlist"
          />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button type="success" plain icon="VideoPlay" @click="handleRunScreen" v-hasPermi="['biz:aiScreen:run']"
          >运行AI初筛</el-button
        >
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="3"
        ><el-statistic title="待筛选" :value="stats.pending" /><span class="stat-label">人</span></el-col
      >
      <el-col :span="3"><el-statistic title="已通过" :value="stats.passed" /><span class="stat-label">人</span></el-col>
      <el-col :span="3"
        ><el-statistic title="短名单" :value="stats.shortlist" /><span class="stat-label">人</span></el-col
      >
      <el-col :span="3"><el-statistic title="淘汰" :value="stats.rejected" /><span class="stat-label">人</span></el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="screenList" @selection-change="handleSelectionChange" stripe>
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="候选人" align="center" prop="userName" width="120" />
      <el-table-column label="岗位" align="center" prop="jobName" width="180" />
      <el-table-column label="匹配度" align="center" prop="matchScore" width="100">
        <template #default="scope">
          <el-tag :type="scoreTag(scope.row.matchScore)">{{ scope.row.matchScore }}分</el-tag>
        </template>
      </el-table-column>
      <el-table-column
        label="维度得分"
        align="center"
        prop="dimensionScores"
        :show-overflow-tooltip="true"
        min-width="200"
      />
      <el-table-column label="筛选结果" align="center" prop="status">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column
        label="匹配亮点"
        align="center"
        prop="highlights"
        :show-overflow-tooltip="true"
        min-width="150"
      />
      <el-table-column label="筛选时间" align="center" prop="screenTime" width="160">
        <template #default="scope"
          ><span>{{ parseTime(scope.row.screenTime) }}</span></template
        >
      </el-table-column>
      <el-table-column label="操作" align="center" width="150">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleDetail(scope.row)">详情</el-button>
          <el-button
            link
            type="primary"
            icon="CircleCheck"
            @click="handleShortlist(scope.row)"
            v-if="scope.row.status === 'passed'"
            >加入短名单</el-button
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

    <el-dialog :title="detailTitle" v-model="dialogOpen" width="600px" append-to-body>
      <div v-if="detailData" style="line-height: 2">
        <h4>匹配度分析</h4>
        <p>
          综合评分: <strong>{{ detailData.matchScore }}分</strong>
        </p>
        <h4>维度得分</h4>
        <el-progress
          v-for="(s, i) in detailData.dimensionScores || []"
          :key="i"
          :percentage="s.score"
          :label="s.name"
          :color="s.score >= 80 ? '#22C55E' : s.score >= 60 ? '#F59E0B' : '#EF4444'"
          style="margin: 8px 0"
        />
        <h4>匹配亮点</h4>
        <p v-for="(h, i) in detailData.highlights || []" :key="i">&radic; {{ h }}</p>
        <h4>差距点</h4>
        <p v-for="(g, i) in detailData.gaps || []" :key="i">&#x2717; {{ g }}</p>
      </div>
      <template #footer><el-button @click="dialogOpen = false">关 闭</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="BizAiScreen">
import { listAiScreen, runAiScreen, updateScreenStatus } from '@/api/biz/aiScreen'

const { proxy } = getCurrentInstance()

// ==================== State ====================
const screenList = ref([])
const ids = ref([])
const stats = ref({ pending: 0, passed: 0, shortlist: 0, rejected: 0 })
const dialogOpen = ref(false)
const queryParams = reactive({
  pageNum: 1,
  pageSize: 10,
  jobName: undefined,
  status: undefined
})

// ==================== Methods ====================
const total = ref(0)
const loading = ref(true)
const detailData = ref(null)
const showSearch = ref(true)
const detailTitle = ref('初筛详情')

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
  listAiScreen(queryParams)
    .then((res) => {
      screenList.value = res.rows
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

/** 运行AI初筛 */
function handleRunScreen() {
  proxy.$modal
    .confirm('确认要运行AI初筛吗？')
    .then(function () {
      return runAiScreen({ jobName: queryParams.jobName })
    })
    .then(() => {
      proxy.$modal.msgSuccess('AI初筛已启动，请稍候')
      getList()
    })
    .catch((err) => {
      console.error(err)
      proxy.$modal.msgError('运行失败')
    })
}

/** 详情 */
function handleDetail(row) {
  listAiScreen({ screenId: row.screenId })
    .then((res) => {
      detailData.value = res.data
      dialogOpen.value = true
    })
    .catch((err) => {
      console.error(err)
      proxy.$modal.msgError('加载详情失败')
    })
}

/** 加入短名单 */
function handleShortlist(row) {
  updateScreenStatus({ screenId: row.screenId, status: 'shortlist' })
    .then(() => {
      proxy.$modal.msgSuccess('已加入短名单')
      getList()
    })
    .catch((err) => {
      console.error(err)
      proxy.$modal.msgError('操作失败')
    })
}

/** 匹配分数标签 */
function scoreTag(score) {
  if (score >= 80) return 'success'
  if (score >= 60) return 'warning'
  return 'danger'
}

/** 筛选状态标签 */
function statusLabel(s) {
  const map = { pending: '待筛选', screened: '已筛选', shortlist: '短名单' }
  return map[s] || s
}
function statusTag(s) {
  const map = { pending: 'warning', screened: 'info', shortlist: 'success' }
  return map[s] || ''
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.screenId)
}

getList()
</script>
