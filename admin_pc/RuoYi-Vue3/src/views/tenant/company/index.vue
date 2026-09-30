<template>
  <div class="app-container">
    <el-card shadow="never" class="search-card">
      <el-form :model="queryParams" ref="queryForm" :inline="true" v-show="showSearch">
        <el-form-item label="企业名称" prop="companyName">
          <el-input v-model="queryParams.companyName" placeholder="请输入企业名称" clearable style="width: 200px" @keyup.enter="handleQuery" />
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
        <el-table-column label="提交时间" align="center" prop="createTime" width="130" />
        <el-table-column label="操作" align="center" width="150" fixed="right">
          <template #default="scope">
            <div class="action-buttons">
              <template v-if="scope.row.verifyStatus === 0">
                <el-button type="success" size="small" @click="handleAudit(scope.row, 1)">通过</el-button>
                <el-button type="danger" size="small" @click="handleAudit(scope.row, 2)">拒绝</el-button>
              </template>
              <el-button type="primary" size="small" link @click="handleDetail(scope.row)">详情</el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>

      <pagination v-show="total > 0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getList" />
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
        <el-descriptions-item label="审核状态">
          <el-tag :type="verifyStatusTag(detail.verifyStatus)">{{ verifyStatusLabel(detail.verifyStatus) }}</el-tag>
        </el-descriptions-item>
      </el-descriptions>
    </el-dialog>
  </div>
</template>

<script setup name="CompanyAudit">
import { listCompany, auditCompany } from '@/api/tenant/company'

const { proxy } = getCurrentInstance()

const companyList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const detailOpen = ref(false)
const detail = ref({})

const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  companyName: undefined,
  verifyStatus: undefined
})

function getList() {
  loading.value = true
  listCompany(queryParams.value).then(response => {
    companyList.value = response.rows
    total.value = response.total
    loading.value = false
  })
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
  const text = status === 1 ? '通过' : '拒绝'
  proxy.$modal.confirm(`确认要${text}企业「${row.companyName}」的审核申请吗？`).then(() => {
    return auditCompany({ companyId: row.companyId, status: status })
  }).then(() => {
    proxy.$modal.msgSuccess(`审核${text}成功`)
    getList()
  }).catch(() => {})
}

function handleDetail(row) {
  detail.value = row
  detailOpen.value = true
}

function verifyStatusLabel(val) {
  const map = { 0: '待审核', 1: '已通过', 2: '已拒绝' }
  return map[val] || '未知'
}

function verifyStatusTag(val) {
  const map = { 0: 'warning', 1: 'success', 2: 'danger' }
  return map[val] || 'info'
}

getList()
</script>

<style scoped>
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
