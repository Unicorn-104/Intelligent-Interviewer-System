<template>
  <div class="app-container">
    <div class="stat-row">
      <div class="stat-card stat-total">
        <div class="stat-num">{{ stats.total }}</div>
        <div class="stat-label">全部企业</div>
      </div>
      <div class="stat-card stat-pending" @click="quickFilter(0)">
        <div class="stat-num">{{ stats.pending }}</div>
        <div class="stat-label">待审核</div>
      </div>
      <div class="stat-card stat-approved" @click="quickFilter(1)">
        <div class="stat-num">{{ stats.approved }}</div>
        <div class="stat-label">已通过</div>
      </div>
      <div class="stat-card stat-rejected" @click="quickFilter(2)">
        <div class="stat-num">{{ stats.rejected }}</div>
        <div class="stat-label">已拒绝</div>
      </div>
      <div class="stat-card" style="background:#fff7e6;border-left:4px solid #faad14" @click="quickFilter('expiring')">
        <div class="stat-num" style="color:#faad14">{{ stats.expiring || 0 }}</div>
        <div class="stat-label">30天内到期</div>
      </div>
    </div>

    <el-card shadow="never" class="search-card">
      <el-form :model="queryParams" ref="queryForm" :inline="true" v-show="showSearch">
        <el-form-item label="企业名称" prop="companyName">
          <el-input
            v-model="queryParams.companyName"
            placeholder="请输入企业名称"
            clearable
            style="width: 200px"
            @keyup.enter="handleQuery"
          />
        </el-form-item>
        <el-form-item label="审核状态" prop="verifyStatus">
          <el-select v-model="queryParams.verifyStatus" placeholder="全部状态" clearable style="width: 140px">
            <el-option label="待审核" :value="0" />
            <el-option label="已通过" :value="1" />
            <el-option label="已拒绝" :value="2" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
          <el-button icon="Refresh" @click="resetQuery">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never" class="table-card">
      <el-table v-loading="loading" :data="companyList" border stripe style="width: 100%">
        <el-table-column label="企业ID" align="center" prop="companyId" width="60" />
        <el-table-column label="企业名称" align="left" prop="companyName" min-width="120" show-overflow-tooltip />
        <el-table-column label="统一社会信用代码" align="center" prop="creditCode" width="140" show-overflow-tooltip />
        <el-table-column label="所属行业" align="center" prop="industry" width="80" />
        <el-table-column label="企业规模" align="center" prop="size" width="70" />
        <el-table-column label="所在城市" align="center" prop="city" width="80" />
        <el-table-column label="审核状态" align="center" width="80">
          <template #default="scope">
            <el-tag :type="verifyStatusTag(scope.row.verifyStatus)" size="small">
              {{ verifyStatusLabel(scope.row.verifyStatus) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="提交时间" align="center" width="160">
          <template #default="scope">{{ formatTime(scope.row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" align="center" width="150" fixed="right">
          <template #default="scope">
            <div class="action-buttons">
              <template v-if="scope.row.verifyStatus === 0">
                <el-button
                  type="success"
                  size="small"
                  v-hasPermi="['tenant:company:audit']"
                  @click="handleAudit(scope.row, 1)"
                  >通过</el-button
                >
                <el-button
                  type="danger"
                  size="small"
                  v-hasPermi="['tenant:company:audit']"
                  @click="handleAudit(scope.row, 2)"
                  >拒绝</el-button
                >
              </template>
              <el-button v-else type="warning" size="small" link @click="handleRevoke(scope.row)">撤销</el-button>
              <el-button type="primary" size="small" link @click="handleDetail(scope.row)">详情</el-button>
            </div>
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
    </el-card>

    <!-- 企业详情对话框 -->
    <el-dialog title="企业详情" v-model="detailOpen" width="640px" append-to-body>
      <el-descriptions :column="1" border>
        <el-descriptions-item label="企业名称">{{ detail.companyName }}</el-descriptions-item>
        <el-descriptions-item label="统一社会信用代码">{{ detail.creditCode }}</el-descriptions-item>
        <el-descriptions-item label="所属行业">{{ detail.industry }}</el-descriptions-item>
        <el-descriptions-item label="企业规模">{{ detail.size }}</el-descriptions-item>
        <el-descriptions-item label="所在城市">{{ detail.city }}</el-descriptions-item>
        <el-descriptions-item label="详细地址">{{ detail.address }}</el-descriptions-item>
        <el-descriptions-item label="企业官网">{{ detail.website }}</el-descriptions-item>
        <el-descriptions-item label="企业介绍">{{ detail.intro }}</el-descriptions-item>
        <el-descriptions-item v-if="detail.contactName" label="联系人">{{ detail.contactName }}</el-descriptions-item>
        <el-descriptions-item v-if="detail.contactPhone" label="联系电话">{{
          detail.contactPhone
        }}</el-descriptions-item>
        <el-descriptions-item label="审核状态">
          <el-tag :type="verifyStatusTag(detail.verifyStatus)">{{ verifyStatusLabel(detail.verifyStatus) }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item v-if="detail.verifyByName" label="审核人">{{ detail.verifyByName }}</el-descriptions-item>
        <el-descriptions-item v-if="detail.verifyAt" label="审核时间">{{
          formatTime(detail.verifyAt)
        }}</el-descriptions-item>
        <el-descriptions-item v-if="detail.verifyStatus === 2 && detail.verifyRemark" label="驳回理由">
          <span style="color: #f56c6c">{{ detail.verifyRemark }}</span>
        </el-descriptions-item>
      </el-descriptions>
    </el-dialog>

    <!-- 驳回理由对话框 -->
    <el-dialog title="拒绝审核" v-model="rejectOpen" width="480px" append-to-body>
      <el-form :model="rejectForm" ref="rejectFormRef" :rules="rejectRules" label-width="80px">
        <el-form-item label="企业名称">
          <span>{{ rejectForm.companyName }}</span>
        </el-form-item>
        <el-form-item label="驳回理由" prop="rejectReason">
          <el-input
            v-model="rejectForm.rejectReason"
            type="textarea"
            :rows="3"
            placeholder="请填写拒绝原因，将反馈给企业"
            maxlength="200"
            show-word-limit
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="rejectOpen = false">取消</el-button>
        <el-button type="danger" @click="submitReject">确认拒绝</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="CompanyAudit">
import { listCompany, auditCompany, statsCompany, getCompany, revokeCompany } from '@/api/tenant/company'

const { proxy } = getCurrentInstance()

const companyList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const detailOpen = ref(false)
const detail = ref({})
const stats = ref({ total: 0, pending: 0, approved: 0, rejected: 0 })

const rejectOpen = ref(false)
const rejectFormRef = ref()
const rejectForm = ref({ companyId: undefined, companyName: '', rejectReason: '' })
const rejectRules = {
  rejectReason: [{ required: true, message: '请填写驳回理由', trigger: 'blur' }]
}

const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  companyName: undefined,
  verifyStatus: undefined
})

function getList() {
  loading.value = true
  listCompany(queryParams.value).then((response) => {
    companyList.value = response.rows
    total.value = response.total
    loading.value = false
  })
  getStats()
}

function getStats() {
  statsCompany().then((response) => {
    stats.value = response.data || response
  })
}

function quickFilter(status) {
  queryParams.value.verifyStatus = status
  handleQuery()
}

function handleQuery() {
  queryParams.value.pageNum = 1
  getList()
}

function resetQuery() {
  queryParams.value.companyName = undefined
  queryParams.value.verifyStatus = undefined
  handleQuery()
}

function handleAudit(row, status) {
  if (status === 1) {
    proxy.$modal
      .confirm(`确认通过企业「${row.companyName}」的审核申请吗？`)
      .then(() => {
        return auditCompany({ companyId: row.companyId, status: 1 })
      })
      .then(() => {
        proxy.$modal.msgSuccess('审核通过成功')
        getList()
      })
      .catch(() => {})
  } else {
    rejectForm.value = { companyId: row.companyId, companyName: row.companyName, rejectReason: '' }
    rejectOpen.value = true
  }
}

function submitReject() {
  rejectFormRef.value.validate((valid) => {
    if (!valid) return
    auditCompany({
      companyId: rejectForm.value.companyId,
      status: 2,
      rejectReason: rejectForm.value.rejectReason
    }).then(() => {
      proxy.$modal.msgSuccess('已拒绝该企业')
      rejectOpen.value = false
      getList()
    })
  })
}

function handleDetail(row) {
  getCompany(row.companyId).then((res) => {
    detail.value = res.data || res
    detailOpen.value = true
  })
}

function handleRevoke(row) {
  proxy.$modal
    .confirm(`确认撤销企业「${row.companyName}」的审核，重置为待审核吗？`)
    .then(() => {
      return revokeCompany(row.companyId)
    })
    .then(() => {
      proxy.$modal.msgSuccess('已撤销，重置为待审核')
      getList()
    })
    .catch(() => {})
}

function verifyStatusLabel(val) {
  const map = { 0: '待审核', 1: '已通过', 2: '已拒绝' }
  return map[val] || '未知'
}

function verifyStatusTag(val) {
  const map = { 0: 'warning', 1: 'success', 2: 'danger' }
  return map[val] || 'info'
}

/** 格式化时间 */
function formatTime(time) {
  if (!time) return ''
  return time.replace('T', ' ').substring(0, 19)
}

getList()
</script>

<style scoped>
.stat-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 14px;
  margin-bottom: 15px;
}
.stat-card {
  background: #fff;
  border-radius: 10px;
  padding: 18px 20px;
  box-shadow: 0 2px 10px rgba(72, 47, 105, 0.05);
  cursor: pointer;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
  border-left: 4px solid transparent;
}
.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 18px rgba(72, 47, 105, 0.1);
}
.stat-num {
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
}
.stat-label {
  color: #86909c;
  font-size: 13px;
  margin-top: 4px;
}
.stat-total {
  border-left-color: #2f80ed;
}
.stat-total .stat-num {
  color: #2f80ed;
}
.stat-pending {
  border-left-color: #f59e0b;
}
.stat-pending .stat-num {
  color: #f59e0b;
}
.stat-approved {
  border-left-color: #22c55e;
}
.stat-approved .stat-num {
  color: #22c55e;
}
.stat-rejected {
  border-left-color: #ef4444;
}
.stat-rejected .stat-num {
  color: #ef4444;
}
.search-card {
  margin-bottom: 15px;
}
.table-card {
  min-height: 400px;
}
.action-buttons {
  display: flex;
  gap: 4px;
  justify-content: center;
  align-items: center;
}
.action-buttons .el-button + .el-button {
  margin-left: 0;
}
</style>
