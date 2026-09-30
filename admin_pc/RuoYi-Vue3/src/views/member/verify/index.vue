<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="申请人" prop="userName">
        <el-input
          v-model="queryParams.userName"
          placeholder="请输入申请人"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="企业名称" prop="companyName">
        <el-input
          v-model="queryParams.companyName"
          placeholder="请输入企业名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="审核状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择审核状态" clearable style="width: 200px">
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

    <el-table v-loading="loading" :data="verifyList">
      <el-table-column label="ID" align="center" prop="verifyId" width="50" />
      <el-table-column label="申请人" align="center" prop="userName" width="80" :show-overflow-tooltip="true" />
      <el-table-column label="手机号" align="center" prop="phone" width="110" />
      <el-table-column
        label="统一社会信用代码"
        align="center"
        prop="creditCode"
        width="140"
        :show-overflow-tooltip="true"
      />
      <el-table-column label="身份" align="center" prop="position" width="50" />
      <el-table-column label="申请时间" align="center" prop="applyTime" width="130" />
      <el-table-column label="审核状态" align="center" width="70">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="审核时间" align="center" prop="auditTime" width="130" />
      <el-table-column label="审核人" align="center" prop="auditor" width="60" />
      <el-table-column label="操作" align="center" width="90" fixed="right">
        <template #default="scope">
          <el-button
            v-if="String(scope.row.status) === '0'"
            link
            type="primary"
            icon="Edit"
            @click="handleAudit(scope.row)"
            v-hasPermi="['member:verify:audit']"
            >审核</el-button
          >
          <el-button v-if="String(scope.row.status) !== '0'" link type="primary" icon="View" @click="handleView(scope.row)"
            >查看结果</el-button
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

    <!-- 企业认证审核对话框 -->
    <el-dialog title="企业认证审核" v-model="auditOpen" width="500px" append-to-body>
      <el-form ref="auditRef" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="申请人">
          <span>{{ form.userName }}</span>
        </el-form-item>
        <el-form-item label="审核结果" prop="status">
          <el-radio-group v-model="form.status" @change="handleStatusChange">
            <el-radio value="1">通过</el-radio>
            <el-radio value="2">驳回</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="审核意见" prop="reason">
          <el-input v-model="form.reason" type="textarea" :rows="3" placeholder="驳回时必须填写审核意见" />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitAudit">确 定</el-button>
          <el-button @click="cancelAudit">取 消</el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 审核结果对话框 -->
    <el-dialog title="审核结果" v-model="viewOpen" width="500px" append-to-body>
      <el-descriptions :column="1" border>
        <el-descriptions-item label="审核状态">
          <el-tag :type="statusTag(viewRow.status)">{{ statusLabel(viewRow.status) }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="审核意见">{{ viewRow.reason }}</el-descriptions-item>
        <el-descriptions-item label="审核时间">{{ viewRow.auditTime }}</el-descriptions-item>
        <el-descriptions-item label="审核人">{{ viewRow.auditor }}</el-descriptions-item>
      </el-descriptions>
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="viewOpen = false">关 闭</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="MemberVerify">
import { listVerify, auditVerify } from '@/api/member/verify'

const { proxy } = getCurrentInstance()

const verifyList = ref([])
const auditOpen = ref(false)
const viewOpen = ref(false)
const viewRow = ref({})
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)

// 审核状态选项
const statusOptions = [
  { value: '0', label: '待审核', tag: 'warning' },
  { value: '1', label: '已通过', tag: 'success' },
  { value: '2', label: '已驳回', tag: 'danger' }
]

// 驳回时审核意见必填
const validateReason = function (rule, value, callback) {
  if (form.value.status === '2' && (!value || String(value).trim() === '')) {
    callback(new Error('驳回时必须填写审核意见'))
  } else {
    callback()
  }
}

const form = ref({
  verifyId: undefined,
  userName: undefined,
  status: '1',
  reason: undefined
})

const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  userName: undefined,
  companyName: undefined,
  status: undefined
})

const rules = ref({
  status: [{ required: true, message: '请选择审核结果', trigger: 'change' }],
  reason: [{ required: true, validator: validateReason, trigger: 'blur' }]
})

function statusLabel(val) {
  var strVal = String(val)
  var item = statusOptions.find(function (o) {
    return o.value === strVal
  })
  return item ? item.label : val
}

function statusTag(val) {
  var strVal = String(val)
  var item = statusOptions.find(function (o) {
    return o.value === strVal
  })
  return item && item.tag ? item.tag : undefined
}

/** 查询企业认证申请列表 */
function getList() {
  loading.value = true
  listVerify(queryParams.value)
    .then((response) => {
      verifyList.value = response.rows
      total.value = response.total
      loading.value = false
    })
    .catch(function (err) {
      console.error('加载审核列表失败:', err)
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
  form.value = {
    verifyId: undefined,
    userName: undefined,
    status: '1',
    reason: undefined
  }
  proxy.resetForm('auditRef')
}

/** 审核按钮操作 */
function handleAudit(row) {
  reset()
  form.value.verifyId = row.verifyId
  form.value.userName = row.userName
  auditOpen.value = true
}

/** 审核结果切换时清除审核意见校验 */
function handleStatusChange() {
  if (proxy.$refs['auditRef']) {
    proxy.$refs['auditRef'].clearValidate('reason')
  }
}

/** 取消按钮 */
function cancelAudit() {
  auditOpen.value = false
  reset()
}

/** 提交审核 */
function submitAudit() {
  proxy.$refs['auditRef'].validate(function (valid) {
    if (valid) {
      auditVerify({
        verifyId: form.value.verifyId,
        status: form.value.status,
        reason: form.value.reason
      })
        .then(function () {
          proxy.$modal.msgSuccess('审核成功')
          auditOpen.value = false
          getList()
        })
        .catch(function (err) {
          console.error(err)
          proxy.$modal.msgError('审核失败')
        })
    }
  })
}

/** 查看结果按钮操作 */
function handleView(row) {
  viewRow.value = row
  viewOpen.value = true
}

getList()
</script>
