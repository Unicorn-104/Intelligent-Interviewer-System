<template>
  <div class="app-container">
    <el-card shadow="never" v-loading="loading">
      <el-collapse v-model="activeNames">
        <el-collapse-item v-for="company in companyList" :key="company.companyId" :name="company.companyId">
          <template #title>
            <div class="company-header">
              <el-icon class="company-icon"><OfficeBuilding /></el-icon>
              <span class="company-name">{{ company.companyName }}</span>
              <el-tag :type="company.packageType === 'pro' ? 'primary' : company.packageType === 'flag' ? 'warning' : 'info'" size="small">
                {{ company.packageTypeName }}
              </el-tag>
              <el-tag size="small" :type="company.status === '0' ? 'success' : 'danger'">
                {{ company.status === '0' ? '正常' : '已过期' }}
              </el-tag>
              <span class="employee-count">{{ company.employeeCount }} 名员工</span>
            </div>
          </template>

          <el-descriptions :column="3" border class="subscription-info">
            <el-descriptions-item label="套餐类型">{{ company.packageTypeName }}</el-descriptions-item>
            <el-descriptions-item label="到期时间">{{ company.expireTime }}</el-descriptions-item>
            <el-descriptions-item label="API配额">{{ company.apiQuota }} 次/月</el-descriptions-item>
          </el-descriptions>

          <div class="api-usage">
            <div class="api-usage-header">
              <span>本月API调用量</span>
              <span>{{ company.apiUsed }} / {{ company.apiQuota }}</span>
            </div>
            <el-progress :percentage="apiPercent(company.apiUsed, company.apiQuota)" :status="apiStatus(company.apiUsed, company.apiQuota)" />
          </div>

          <el-table :data="company.employees" border size="small">
            <el-table-column label="员工ID" align="center" prop="userId" width="80" />
            <el-table-column label="姓名" align="center" prop="realName" />
            <el-table-column label="账号" align="center" prop="userName" />
            <el-table-column label="手机号" align="center" prop="phonenumber" />
            <el-table-column label="职位" align="center" prop="position" />
            <el-table-column label="状态" align="center" width="90">
              <template #default="scope">
                <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'" size="small">
                  {{ scope.row.status === '0' ? '在职' : '离职' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="入职时间" align="center" prop="entryTime" />
          </el-table>
        </el-collapse-item>
      </el-collapse>
      <el-empty v-if="companyList.length === 0" description="暂无企业数据" />
    </el-card>
  </div>
</template>

<script setup name="TenantUser">
import { OfficeBuilding } from '@element-plus/icons-vue'
import request from '@/utils/request'

const companyList = ref([])
const activeNames = ref([])
const loading = ref(true)

function getList() {
  loading.value = true
  request({
    url: '/tenant/user/list',
    method: 'get'
  }).then(response => {
    companyList.value = response.rows || []
    if (companyList.value.length > 0) {
      activeNames.value = [companyList.value[0].companyId]
    }
    loading.value = false
  }).catch(() => {
    loading.value = false
  })
}

function apiPercent(used, quota) {
  if (!quota || quota <= 0) return 0
  return Math.min(Math.round((used / quota) * 100), 100)
}

function apiStatus(used, quota) {
  const pct = apiPercent(used, quota)
  if (pct > 90) return 'exception'
  if (pct > 70) return 'warning'
  return ''
}

getList()
</script>

<style scoped>
.company-header {
  display: flex;
  align-items: center;
  gap: 10px;
}
.company-icon {
  font-size: 18px;
}
.company-name {
  font-weight: 600;
}
.employee-count {
  color: #909399;
  font-size: 13px;
}
.subscription-info {
  margin-bottom: 15px;
}
.api-usage {
  margin-bottom: 15px;
}
.api-usage-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 5px;
  font-size: 13px;
  color: #606266;
}
</style>
