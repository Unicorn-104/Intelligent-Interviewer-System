<template>
  <div class="app-container">
    <div class="stat-row">
      <div class="stat-card c-total">
        <div class="stat-num">{{ summary.total }}</div>
        <div class="stat-label">企业总数</div>
      </div>
      <div class="stat-card c-normal">
        <div class="stat-num">{{ summary.normal }}</div>
        <div class="stat-label">正常</div>
      </div>
      <div class="stat-card c-expired">
        <div class="stat-num">{{ summary.expired }}</div>
        <div class="stat-label">已过期</div>
      </div>
      <div class="stat-card c-staff">
        <div class="stat-num">{{ summary.staff }}</div>
        <div class="stat-label">员工总数</div>
      </div>
    </div>

    <el-card shadow="never" class="search-card">
      <el-form :inline="true" @submit.prevent>
        <el-form-item label="企业名称">
          <el-input v-model="query.companyName" placeholder="请输入企业名称" clearable style="width: 200px" />
        </el-form-item>
        <el-form-item label="套餐">
          <el-select v-model="query.packageType" placeholder="全部套餐" clearable style="width: 140px">
            <el-option label="基础版" value="basic" />
            <el-option label="专业版" value="pro" />
            <el-option label="旗舰版" value="flag" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="query.status" placeholder="全部状态" clearable style="width: 130px">
            <el-option label="正常" value="0" />
            <el-option label="已过期" value="1" />
            <el-option label="即将到期" value="soon" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button icon="Refresh" @click="resetQuery">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never" v-loading="loading">
      <el-collapse v-model="activeNames">
        <el-collapse-item v-for="company in filteredList" :key="company.companyId" :name="company.companyId">
          <template #title>
            <div class="company-header">
              <el-icon class="company-icon"><OfficeBuilding /></el-icon>
              <span class="company-name">{{ company.companyName }}</span>
              <el-tag
                :type="company.packageType === 'pro' ? 'primary' : company.packageType === 'flag' ? 'warning' : 'info'"
                size="small"
              >
                {{ company.packageTypeName }}
              </el-tag>
              <el-tag size="small" :type="company.status === '0' ? 'success' : 'danger'">
                {{ company.status === '0' ? '正常' : '已过期' }}
              </el-tag>
              <el-tag
                v-if="
                  expireDays(company.expireTime) !== null &&
                  expireDays(company.expireTime) >= 0 &&
                  expireDays(company.expireTime) <= 30
                "
                size="small"
                type="warning"
              >
                即将到期({{ expireDays(company.expireTime) }}天)
              </el-tag>
              <span class="employee-count">{{ company.employeeCount }} 名员工</span>
            </div>
          </template>

          <el-descriptions :column="3" border class="subscription-info">
            <el-descriptions-item label="套餐类型">{{ company.packageTypeName }}</el-descriptions-item>
            <el-descriptions-item label="到期时间">{{ company.expireTime }}</el-descriptions-item>
            <el-descriptions-item label="API配额">{{ company.apiQuota }} 次/月</el-descriptions-item>
          </el-descriptions>
          <div class="subscription-actions">
            <el-button size="small" type="primary" plain @click="openSubscription(company)">改套餐 / 续费</el-button>
          </div>

          <div class="api-usage">
            <div class="api-usage-header">
              <span>本月API调用量</span>
              <span>{{ company.apiUsed }} / {{ company.apiQuota }}</span>
            </div>
            <el-progress
              :percentage="apiPercent(company.apiUsed, company.apiQuota)"
              :status="apiStatus(company.apiUsed, company.apiQuota)"
            />
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
                  {{ scope.row.status === '0' ? '在职' : '停用' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="入职时间" align="center" width="160">
              <template #default="scope">{{ formatTime(scope.row.entryTime) }}</template>
            </el-table-column>
            <el-table-column label="操作" align="center" width="150">
              <template #default="scope">
                <el-button
                  link
                  :type="scope.row.status === '0' ? 'warning' : 'success'"
                  size="small"
                  @click="toggleEmployeeStatus(scope.row, company)"
                >
                  {{ scope.row.status === '0' ? '停用' : '启用' }}
                </el-button>
                <el-button link type="primary" size="small" @click="openResetPwd(scope.row, company)"
                  >重置密码</el-button
                >
              </template>
            </el-table-column>
          </el-table>
        </el-collapse-item>
      </el-collapse>
      <el-empty v-if="filteredList.length === 0" description="暂无企业数据" />

      <el-dialog v-model="subVisible" title="改套餐 / 续费" width="460px">
        <el-form :model="subForm" label-width="90px">
          <el-form-item label="套餐类型">
            <el-select v-model="subForm.packageType" style="width: 100%" @change="applyDefaultQuota">
              <el-option label="基础版" value="basic" />
              <el-option label="专业版" value="pro" />
              <el-option label="旗舰版" value="flag" />
            </el-select>
          </el-form-item>
          <el-form-item label="到期日期">
            <el-date-picker
              v-model="subForm.expireDate"
              type="date"
              value-format="YYYY-MM-DD"
              placeholder="选择到期日"
              style="width: 100%"
            />
          </el-form-item>
          <el-form-item label="API配额">
            <el-input-number v-model="subForm.apiQuota" :min="0" :step="1000" />
            <span style="margin-left: 8px; color: #909399; font-size: 12px">次/月</span>
          </el-form-item>
          <el-form-item label="联系人">
            <el-input v-model="subForm.contactName" placeholder="认证联系人姓名" style="width: 100%" />
          </el-form-item>
          <el-form-item label="联系电话">
            <el-input v-model="subForm.contactPhone" placeholder="联系人手机号" style="width: 100%" />
          </el-form-item>
        </el-form>
        <template #footer>
          <el-button @click="subVisible = false">取消</el-button>
          <el-button type="primary" @click="saveSubscription">保存</el-button>
        </template>
      </el-dialog>
    </el-card>
  </div>
</template>

<script setup name="TenantUser">
import { computed, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { OfficeBuilding } from '@element-plus/icons-vue'
import request from '@/utils/request'

const companyList = ref([])
const activeNames = ref([])
const loading = ref(true)
const query = ref({ companyName: '', packageType: '', status: '' })

const subVisible = ref(false)
const subForm = ref({
  companyId: null,
  packageType: 'basic',
  expireDate: '',
  apiQuota: 10000,
  contactName: '',
  contactPhone: ''
})

// 各套餐默认API配额（次/月）
const QUOTA_PRESET = { basic: 10000, pro: 50000, flag: 200000 }
function applyDefaultQuota(type) {
  if (QUOTA_PRESET[type]) subForm.value.apiQuota = QUOTA_PRESET[type]
}

function getList() {
  loading.value = true
  request({
    url: '/tenant/user/list',
    method: 'get'
  })
    .then((response) => {
      companyList.value = response.rows || []
      loading.value = false
    })
    .catch(() => {
      loading.value = false
    })
}

const filteredList = computed(() => {
  return companyList.value.filter((c) => {
    if (query.value.companyName && !(c.companyName || '').includes(query.value.companyName)) return false
    if (query.value.packageType && c.packageType !== query.value.packageType) return false
    if (query.value.status === 'soon') {
      const d = expireDays(c.expireTime)
      if (d === null || d < 0 || d > 30) return false
    } else if (query.value.status !== '' && c.status !== query.value.status) {
      return false
    }
    return true
  })
})

const summary = computed(() => {
  const list = companyList.value
  return {
    total: list.length,
    normal: list.filter((c) => c.status === '0').length,
    expired: list.filter((c) => c.status !== '0').length,
    staff: list.reduce((sum, c) => sum + (Number(c.employeeCount) || 0), 0)
  }
})

function resetQuery() {
  query.value = { companyName: '', packageType: '', status: '' }
}

function expireDays(expireTime) {
  if (!expireTime) return null
  const exp = new Date(expireTime)
  if (isNaN(exp.getTime())) return null
  const diff = Math.ceil((exp.getTime() - Date.now()) / 86400000)
  return diff
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

/** 格式化时间 */
function formatTime(time) {
  if (!time) return ''
  return time.replace('T', ' ').substring(0, 19)
}

/** 启用/停用员工 */
function toggleEmployeeStatus(emp, company) {
  const next = emp.status === '0' ? '1' : '0'
  const label = next === '1' ? '停用' : '启用'
  ElMessageBox.confirm(`确认${label}员工「${emp.realName}」？`, '提示', { type: 'warning' })
    .then(() =>
      request({
        url: '/tenant/user/employee/status',
        method: 'put',
        data: { userId: emp.userId, companyId: company.companyId, status: next }
      })
    )
    .then(() => {
      ElMessage.success('操作成功')
      getList()
    })
    .catch(() => {})
}

/** 重置员工密码 */
function openResetPwd(emp, company) {
  ElMessageBox.prompt(`为员工「${emp.realName}」设置新密码`, '重置密码', {
    inputType: 'password',
    inputPlaceholder: '请输入新密码（至少6位）',
    inputValidator: (v) => (v && v.length >= 6) || '密码至少6位'
  })
    .then(({ value }) =>
      request({
        url: '/tenant/user/employee/resetPwd',
        method: 'put',
        data: { userId: emp.userId, companyId: company.companyId, password: value }
      })
    )
    .then(() => ElMessage.success('密码已重置'))
    .catch(() => {})
}

/** 打开改套餐/续费弹窗 */
function openSubscription(company) {
  subForm.value = {
    companyId: company.companyId,
    packageType: company.packageType || 'basic',
    expireDate: company.expireTime || '',
    apiQuota: company.apiQuota || QUOTA_PRESET[company.packageType] || 10000,
    contactName: company.contactName || '',
    contactPhone: company.contactPhone || ''
  }
  subVisible.value = true
}

/** 保存套餐/续费 */
function saveSubscription() {
  if (!subForm.value.expireDate) {
    ElMessage.warning('请选择到期日期')
    return
  }
  request({ url: '/tenant/user/subscription', method: 'put', data: subForm.value }).then(() => {
    ElMessage.success('套餐已更新')
    subVisible.value = false
    getList()
  })
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
  border-left: 4px solid transparent;
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
.c-total {
  border-left-color: #2f80ed;
}
.c-total .stat-num {
  color: #2f80ed;
}
.c-normal {
  border-left-color: #22c55e;
}
.c-normal .stat-num {
  color: #22c55e;
}
.c-expired {
  border-left-color: #ef4444;
}
.c-expired .stat-num {
  color: #ef4444;
}
.c-staff {
  border-left-color: #f59e0b;
}
.c-staff .stat-num {
  color: #f59e0b;
}
.search-card {
  margin-bottom: 15px;
}
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
  margin-bottom: 10px;
}
.subscription-actions {
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
