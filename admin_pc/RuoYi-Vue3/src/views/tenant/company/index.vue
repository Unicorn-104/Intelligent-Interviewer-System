<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="企业名称" prop="companyName">
        <el-input
          v-model="queryParams.companyName"
          placeholder="请输入企业名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="联系人" prop="contactName">
        <el-input
          v-model="queryParams.contactName"
          placeholder="请输入联系人"
          clearable
          style="width: 160px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="套餐类型" prop="packageType">
        <el-select v-model="queryParams.packageType" placeholder="请选择套餐类型" clearable style="width: 160px">
          <el-option v-for="item in packageTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable style="width: 140px">
          <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="创建时间">
        <el-date-picker
          v-model="dateRange"
          type="daterange"
          value-format="YYYY-MM-DD"
          range-separator="-"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          style="width: 240px"
        ></el-date-picker>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['tenant:company:add']"
          >新增企业</el-button
        >
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="danger"
          plain
          icon="Delete"
          :disabled="multiple"
          @click="handleDelete"
          v-hasPermi="['tenant:company:remove']"
          >删除</el-button
        >
      </el-col>
      <el-col :span="1.5">
        <el-button type="warning" plain icon="Download" @click="handleExport">导出</el-button>
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="companyList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="企业名称" align="center" prop="companyName" min-width="160" :show-overflow-tooltip="true">
        <template #default="scope">
          <a class="company-link" @click="handleDetail(scope.row)">{{ scope.row.companyName }}</a>
        </template>
      </el-table-column>
      <el-table-column label="联系人" align="center" width="140">
        <template #default="scope">
          <div>{{ scope.row.contactName }}</div>
          <div class="sub-text">{{ scope.row.contactPhone }}</div>
        </template>
      </el-table-column>
      <el-table-column label="套餐类型" align="center" width="100">
        <template #default="scope">
          <el-tag :type="packageTypeTag(scope.row.packageType)">{{ packageTypeLabel(scope.row.packageType) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" width="90">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="候选人数" align="center" prop="candidateCount" width="100" />
      <el-table-column label="API 用量" align="center" width="180">
        <template #default="scope">
          <el-progress
            :percentage="usagePercent(scope.row.apiUsed, scope.row.apiQuota)"
            :status="usageStatus(scope.row.apiUsed, scope.row.apiQuota)"
            :stroke-width="8"
          />
          <div class="sub-text">{{ scope.row.apiUsed }} / {{ scope.row.apiQuota }}</div>
        </template>
      </el-table-column>
      <el-table-column label="到期时间" align="center" width="110">
        <template #default="scope">
          <span :style="expireSoon(scope.row) ? { color: '#E6A23C' } : {}">{{ scope.row.expireTime }}</span>
        </template>
      </el-table-column>
      <el-table-column label="创建时间" align="center" width="110">
        <template #default="scope">
          <span>{{ parseTime(scope.row.createTime, '{y}-{m}-{d}') }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="260" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleDetail(scope.row)">详情</el-button>
          <el-button
            link
            type="primary"
            icon="Edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['tenant:company:edit']"
            >修改</el-button
          >
          <el-button
            link
            :type="scope.row.status === '0' ? 'warning' : 'success'"
            :icon="scope.row.status === '0' ? 'SwitchButton' : 'CircleCheck'"
            @click="handleToggleStatus(scope.row)"
            v-hasPermi="['tenant:company:edit']"
            >{{ scope.row.status === '0' ? '停用' : '启用' }}</el-button
          >
          <el-button
            link
            type="danger"
            icon="Delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['tenant:company:remove']"
            >删除</el-button
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

    <!-- 添加或修改企业对话框 -->
    <el-dialog :title="title" v-model="open" width="640px" append-to-body>
      <el-form ref="companyRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="企业名称" prop="companyName">
          <el-input v-model="form.companyName" placeholder="请输入企业名称" />
        </el-form-item>
        <el-form-item label="联系人" prop="contactName">
          <el-input v-model="form.contactName" placeholder="请输入联系人" />
        </el-form-item>
        <el-form-item label="联系电话" prop="contactPhone">
          <el-input v-model="form.contactPhone" placeholder="请输入联系电话" />
        </el-form-item>
        <el-form-item label="套餐类型" prop="packageType">
          <el-select v-model="form.packageType" placeholder="请选择套餐类型" style="width: 100%">
            <el-option v-for="item in packageTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-radio-group v-model="form.status">
            <el-radio v-for="item in statusOptions" :key="item.value" :value="item.value">{{ item.label }}</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="到期时间" prop="expireTime">
          <el-date-picker
            v-model="form.expireTime"
            type="date"
            value-format="YYYY-MM-DD"
            placeholder="请选择到期时间"
            style="width: 100%"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitForm">确 定</el-button>
          <el-button @click="cancel">取 消</el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 企业详情抽屉 -->
    <el-drawer v-model="detailOpen" size="55%" :title="detailTitle" append-to-body>
      <div v-loading="detailLoading" class="drawer-body">
        <el-tabs v-model="activeTab">
          <el-tab-pane label="基本信息" name="base">
            <el-descriptions :column="2" border>
              <el-descriptions-item label="企业名称">{{ detailCompany.companyName }}</el-descriptions-item>
              <el-descriptions-item label="统一社会信用代码">{{ detail.creditCode }}</el-descriptions-item>
              <el-descriptions-item label="所属行业">{{ detail.industry }}</el-descriptions-item>
              <el-descriptions-item label="企业规模">{{ detail.scale }}</el-descriptions-item>
              <el-descriptions-item label="企业地址" :span="2">{{ detail.address }}</el-descriptions-item>
              <el-descriptions-item label="状态">
                <el-tag :type="statusTag(detailCompany.status)">{{ statusLabel(detailCompany.status) }}</el-tag>
              </el-descriptions-item>
              <el-descriptions-item label="到期时间">{{ detailCompany.expireTime }}</el-descriptions-item>
              <el-descriptions-item label="创建时间" :span="2">{{
                parseTime(detailCompany.createTime)
              }}</el-descriptions-item>
            </el-descriptions>
          </el-tab-pane>
          <el-tab-pane label="套餐与配额" name="quota">
            <div v-for="(item, index) in detail.quotaList || []" :key="index" class="quota-item">
              <div class="quota-head">
                <span>{{ item.name }}</span>
                <span class="sub-text">{{ item.used }} / {{ item.quota }}</span>
              </div>
              <el-progress
                :percentage="usagePercent(item.used, item.quota)"
                :status="usageStatus(item.used, item.quota)"
                :stroke-width="10"
              />
            </div>
            <el-empty
              v-if="!(detail.quotaList && detail.quotaList.length)"
              description="暂无配额数据"
              :image-size="80"
            />
          </el-tab-pane>
          <el-tab-pane label="子账号" name="accounts">
            <el-table :data="detail.accounts || []">
              <el-table-column label="账号" align="center" prop="userName" />
              <el-table-column label="昵称" align="center" prop="nickName" />
              <el-table-column label="部门" align="center" prop="dept" />
              <el-table-column label="状态" align="center" width="90">
                <template #default="scope">
                  <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'">{{
                    scope.row.status === '0' ? '正常' : '停用'
                  }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column label="创建时间" align="center" width="160">
                <template #default="scope">
                  <span>{{ parseTime(scope.row.createTime) }}</span>
                </template>
              </el-table-column>
            </el-table>
          </el-tab-pane>
          <el-tab-pane label="操作日志" name="logs">
            <el-timeline>
              <el-timeline-item
                v-for="(log, index) in detail.logs || []"
                :key="index"
                :timestamp="log.operTime"
                placement="top"
              >
                <div>{{ log.content }}</div>
                <div class="sub-text">操作人：{{ log.operName }}</div>
              </el-timeline-item>
            </el-timeline>
            <el-empty v-if="!(detail.logs && detail.logs.length)" description="暂无操作日志" :image-size="80" />
          </el-tab-pane>
        </el-tabs>
      </div>
    </el-drawer>
  </div>
</template>

<script setup name="Company">
import {
  listCompany,
  getCompany,
  addCompany,
  updateCompany,
  delCompany,
  changeCompanyStatus
} from '@/api/tenant/company'

const { proxy } = getCurrentInstance()

const companyList = ref([])
const open = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const ids = ref([])
const multiple = ref(true)
const total = ref(0)
const title = ref('')
const detailTitle = ref('')
const dateRange = ref([])
const detailOpen = ref(false)
const detailLoading = ref(false)
const detail = ref({})
const detailCompany = computed(() => detail.value.company || detail.value)
const activeTab = ref('base')

const packageTypeOptions = [
  { value: 'basic', label: '基础版' },
  { value: 'pro', label: '专业版' },
  { value: 'flag', label: '旗舰版' }
]

const statusOptions = [
  { value: '0', label: '正常' },
  { value: '1', label: '停用' },
  { value: '2', label: '试用期' }
]

const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  companyName: undefined,
  contactName: undefined,
  packageType: undefined,
  status: undefined
})

const form = ref({})

const rules = ref({
  companyName: [{ required: true, message: '企业名称不能为空', trigger: 'blur' }],
  contactName: [{ required: true, message: '联系人不能为空', trigger: 'blur' }],
  contactPhone: [{ required: true, message: '联系电话不能为空', trigger: 'blur' }]
})

/** 查询企业列表 */
function getList() {
  loading.value = true
  listCompany(queryParams.value)
    .then((response) => {
      companyList.value = response.rows
      total.value = response.total
      loading.value = false
    })
    .catch((err) => {
      console.error('查询企业列表失败:', err)
      loading.value = false
    })
}

/** 搜索按钮操作 */
function handleQuery() {
  queryParams.value.pageNum = 1
  getList()
}

/** 重置按钮操作 */
function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}

/** 表单重置 */
function reset() {
  form.value = {}
  proxy.resetForm('companyRef')
}

/** 新增按钮操作 */
function handleAdd() {
  reset()
  open.value = true
  title.value = '添加企业'
}

/** 修改按钮操作 */
function handleUpdate(row) {
  reset()
  const companyId = row.companyId || form.value.companyId
  getCompany(companyId)
    .then((response) => {
      form.value = response.data
      open.value = true
      title.value = '修改企业'
    })
    .catch((err) => {
      console.error('查询企业详情失败:', err)
    })
}

/** 提交按钮 */
function submitForm() {
  proxy.$refs['companyRef'].validate((valid) => {
    if (valid) {
      if (form.value.companyId != undefined) {
        updateCompany(form.value)
          .then(() => {
            proxy.$modal.msgSuccess('修改成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error('修改企业失败:', err)
          })
      } else {
        addCompany(form.value)
          .then(() => {
            proxy.$modal.msgSuccess('新增成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error('新增企业失败:', err)
          })
      }
    }
  })
}

/** 查看详情 */
function handleDetail(row) {
  detailOpen.value = true
  detailLoading.value = true
  detailTitle.value = row.companyName + ' - 企业详情'
  getCompany(row.companyId)
    .then((response) => {
      detail.value = response.data || {}
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('加载详情失败')
    })
    .finally(() => {
      detailLoading.value = false
    })
}

/** 状态切换 */
function handleToggleStatus(row) {
  const nextStatus = row.status === '0' ? '1' : '0'
  const text = nextStatus === '0' ? '启用' : '停用'
  proxy.$modal
    .confirm('确认要"' + text + '""' + row.companyName + '"企业吗？')
    .then(() => {
      return changeCompanyStatus(row.companyId, nextStatus)
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess(text + '成功')
    })
    .catch(() => {})
}

/** 删除按钮操作 */
function handleDelete(row) {
  const companyIds = row.companyId || ids.value
  proxy.$modal
    .confirm(`是否确认删除企业编号为${companyIds}的数据项？`)
    .then(function () {
      return delCompany(companyIds)
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(() => {})
}

/** 导出按钮操作 */
function handleExport() {
  proxy.download('/tenant/company/export', queryParams.value, '企业列表_' + Date.now() + '.xlsx')
}

/** 套餐类型显示 */
function packageTypeLabel(val) {
  const item = packageTypeOptions.find((o) => o.value === val)
  return item ? item.label : val
}

function packageTypeTag(val) {
  const map = { basic: 'info', pro: 'primary', flag: 'warning' }
  return map[val] || 'info'
}

/** 状态显示 */
function statusLabel(val) {
  const item = statusOptions.find((o) => o.value === val)
  return item ? item.label : val
}

/** 状态标签颜色 */
function statusTag(val) {
  const map = { 0: 'success', 1: 'danger', 2: 'warning' }
  return map[val] || 'info'
}

/** 用量进度计算（百分比超过 100 时进度条按 100 展示并标记异常） */
function usageRaw(used, quota) {
  if (!quota || quota <= 0) {
    return 0
  }
  return Math.round(((used || 0) / quota) * 100)
}

function usagePercent(used, quota) {
  return Math.min(usageRaw(used, quota), 100)
}

function usageStatus(used, quota) {
  const pct = usageRaw(used, quota)
  if (pct > 100) {
    return 'exception'
  }
  if (pct > 80) {
    return 'warning'
  }
  return ''
}

/** 到期时间距今是否不足 30 天 */
function expireSoon(row) {
  if (!row.expireTime) {
    return false
  }
  const end = new Date(String(row.expireTime).replace(/-/g, '/')).getTime()
  if (isNaN(end)) {
    return false
  }
  return end - Date.now() < 30 * 24 * 60 * 60 * 1000
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.companyId)
}

getList()
</script>
