<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="套餐名称" prop="packageName">
        <el-input
          v-model="queryParams.packageName"
          placeholder="请输入套餐名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
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
      <el-col :span="1.5">
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['tenant:package:add']"
          >新增套餐</el-button
        >
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="success"
          plain
          icon="Edit"
          :disabled="single"
          @click="handleUpdate"
          v-hasPermi="['tenant:package:edit']"
          >修改</el-button
        >
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="danger"
          plain
          icon="Delete"
          :disabled="multiple"
          @click="handleDelete"
          v-hasPermi="['tenant:package:remove']"
          >删除</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="packageList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column
        label="套餐名称"
        align="center"
        prop="packageName"
        min-width="140"
        :show-overflow-tooltip="true"
      />
      <el-table-column label="月费" align="center" width="100">
        <template #default="scope">
          <span>¥{{ scope.row.price }}</span>
        </template>
      </el-table-column>
      <el-table-column label="AI 面试配额" align="center" width="130">
        <template #default="scope">
          <span>{{ scope.row.aiInterviewQuota }} 次/月</span>
        </template>
      </el-table-column>
      <el-table-column label="简历解析配额" align="center" width="130">
        <template #default="scope">
          <span>{{ scope.row.resumeParseQuota }} 次/月</span>
        </template>
      </el-table-column>
      <el-table-column label="最大子账号数" align="center" prop="maxAccounts" width="110" />
      <el-table-column label="功能权限" align="center" min-width="260">
        <template #default="scope">
          <el-tag v-for="func in scope.row.functions || []" :key="func" :type="functionTag(func)" class="func-tag">{{
            functionLabel(func)
          }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" width="90">
        <template #default="scope">
          <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'">{{
            scope.row.status === '0' ? '正常' : '停用'
          }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="备注" align="center" prop="remark" min-width="140" :show-overflow-tooltip="true" />
      <el-table-column label="操作" align="center" width="140" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button
            link
            type="primary"
            icon="Edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['tenant:package:edit']"
            >修改</el-button
          >
          <el-button
            link
            type="danger"
            icon="Delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['tenant:package:remove']"
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

    <!-- 添加或修改套餐对话框 -->
    <el-dialog :title="title" v-model="open" width="640px" append-to-body>
      <el-form ref="packageRef" :model="form" :rules="rules" label-width="110px">
        <el-form-item label="套餐名称" prop="packageName">
          <el-input v-model="form.packageName" placeholder="请输入套餐名称" />
        </el-form-item>
        <el-form-item label="月费(元)" prop="price">
          <el-input-number
            v-model="form.price"
            :min="0"
            :precision="2"
            controls-position="right"
            style="width: 200px"
          />
        </el-form-item>
        <el-form-item label="AI 面试配额" prop="aiInterviewQuota">
          <el-input-number v-model="form.aiInterviewQuota" :min="0" controls-position="right" style="width: 200px" />
        </el-form-item>
        <el-form-item label="简历解析配额" prop="resumeParseQuota">
          <el-input-number v-model="form.resumeParseQuota" :min="0" controls-position="right" style="width: 200px" />
        </el-form-item>
        <el-form-item label="最大子账号数" prop="maxAccounts">
          <el-input-number v-model="form.maxAccounts" :min="1" controls-position="right" style="width: 200px" />
        </el-form-item>
        <el-form-item label="功能权限" prop="functions">
          <el-checkbox-group v-model="form.functions">
            <el-checkbox v-for="item in functionOptions" :key="item.value" :value="item.value">{{
              item.label
            }}</el-checkbox>
          </el-checkbox-group>
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-radio-group v-model="form.status">
            <el-radio v-for="item in statusOptions" :key="item.value" :value="item.value">{{ item.label }}</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="备注" prop="remark">
          <el-input v-model="form.remark" type="textarea" :rows="3" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitForm">确 定</el-button>
          <el-button @click="cancel">取 消</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="Package">
import { listPackage, getPackage, addPackage, updatePackage, delPackage } from '@/api/tenant/package'

const { proxy } = getCurrentInstance()

const packageList = ref([])
const open = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const ids = ref([])
const single = ref(true)
const multiple = ref(true)
const total = ref(0)
const title = ref('')

const statusOptions = [
  { value: '0', label: '正常' },
  { value: '1', label: '停用' }
]

const functionOptions = [
  { value: 'ai_interview', label: 'AI 面试' },
  { value: 'resume_parse', label: '简历解析' },
  { value: 'ai_screening', label: 'AI 初筛' },
  { value: 'video_interview', label: '视频面试' },
  { value: 'cascade_mode', label: '级联面试' },
  { value: 'collab_mode', label: 'AI+HR 协同' },
  { value: 'im_chat', label: 'IM 沟通' },
  { value: 'calendar_sync', label: '日历同步' },
  { value: 'online_exam', label: '在线考核' },
  { value: 'talent_pool', label: '人才库' },
  { value: 'survey', label: '体验调研' },
  { value: 'dashboard', label: '数据看板' },
  { value: 'custom_prompt', label: '自定义提示词' }
]

const functionTagMap = {
  ai_interview: 'primary',
  resume_parse: 'success',
  ai_screening: 'primary',
  video_interview: 'warning',
  cascade_mode: 'danger',
  collab_mode: 'success',
  im_chat: 'primary',
  calendar_sync: 'info',
  online_exam: 'warning',
  talent_pool: 'success',
  survey: 'info',
  dashboard: 'info',
  custom_prompt: 'danger'
}

const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  packageName: undefined,
  status: undefined
})

const form = ref({})

const rules = ref({
  packageName: [{ required: true, message: '套餐名称不能为空', trigger: 'blur' }]
})

/** 查询套餐列表 */
function getList() {
  loading.value = true
  listPackage(queryParams.value)
    .then((response) => {
      packageList.value = response.rows
      total.value = response.total
      // removed - moved to finally
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('查询失败')
    })
    .finally(() => {
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

/** 新增按钮操作 */
function handleAdd() {
  resetForm()
  open.value = true
  title.value = '添加套餐'
}

/** 表单重置 */
function resetForm() {
  form.value = {
    packageId: undefined,
    packageName: undefined,
    price: 0,
    aiInterviewQuota: 0,
    resumeParseQuota: 0,
    maxAccounts: 1,
    functions: [],
    status: '0',
    remark: undefined
  }
  proxy.resetForm('packageRef')
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.packageId)
  single.value = selection.length !== 1
  multiple.value = !selection.length
}

/** 修改按钮操作 */
function handleUpdate(row) {
  resetForm()
  getPackage(row.packageId)
    .then((response) => {
      form.value = response.data
      open.value = true
      title.value = '修改套餐'
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('操作失败')
    })
}

/** 提交按钮 */
function submitForm() {
  proxy.$refs['packageRef'].validate((valid) => {
    if (valid) {
      if (form.value.packageId != undefined) {
        updatePackage(form.value)
          .then(() => {
            proxy.$modal.msgSuccess('修改成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error(err)
            proxy?.$msgError?.('操作失败')
          })
      } else {
        addPackage(form.value).then(() => {
          proxy.$modal.msgSuccess('新增成功')
          open.value = false
          getList()
        })
      }
    }
  })
}

/** 取消按钮 */
function cancel() {
  open.value = false
  resetForm()
}

getList()

/** 删除按钮操作 */
function handleDelete(row) {
  const packageIds = row.packageId || ids.value
  proxy.$modal
    .confirm(`是否确认删除套餐编号为"${packageIds}"的数据项？`)
    .then(function () {
      return delPackage(packageIds)
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(() => {})
}

/** 功能权限显示 */
function functionLabel(val) {
  const item = functionOptions.find((o) => o.value === val)
  return item ? item.label : val
}

function functionTag(val) {
  return functionTagMap[val] || 'info'
}

getList()
</script>

<style lang="scss" scoped>
.app-container {
  // 搜索区域卡片化
  :deep(.el-form--inline) {
    .el-form-item {
      margin-bottom: 12px;
    }
    .el-input__wrapper,
    .el-select .el-input__wrapper {
      border-radius: 6px;
    }
  }

  // 表格样式
  :deep(.el-table) {
    overflow: hidden;
    box-shadow: 0 2px 8px rgba(19, 107, 253, 0.08);

    th {
      background-color: #fafbfc !important;
      color: #4e5969 !important;
      font-weight: 600;
    }
  }

  // 对话框样式
  :deep(.el-dialog) {
    border-radius: 8px;
    .el-dialog__header {
      border-bottom: 1px solid #f2f3f5;
      padding: 16px 20px;
    }
    .el-dialog__body {
      padding: 20px;
    }
  }

  .func-tag {
    margin: 2px 4px 2px 0;
  }

  // 输入框品牌化
  :deep(.el-input__wrapper) {
    border-radius: 6px;
    &:focus {
      box-shadow: 0 0 0 2px rgba(19, 107, 253, 0.2) !important;
    }
  }

  .dialog-footer {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
  }
}
</style>
