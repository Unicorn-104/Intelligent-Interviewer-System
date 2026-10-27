<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="配置键" prop="privacyKey">
        <el-input
          v-model="queryParams.privacyKey"
          placeholder="请输入配置键"
          clearable
          style="width: 220px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="类型" prop="privacyType">
        <el-select v-model="queryParams.privacyType" placeholder="全部类型" clearable style="width: 180px">
          <el-option v-for="t in typeOptions" :key="t.value" :label="t.label" :value="t.value" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['system:privacy:add']"
          >新增</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList" />
    </el-row>

    <el-table v-loading="loading" :data="privacyList">
      <el-table-column label="配置键" align="center" prop="privacyKey" min-width="180" :show-overflow-tooltip="true" />
      <el-table-column
        label="配置值"
        align="center"
        prop="privacyValue"
        min-width="140"
        :show-overflow-tooltip="true"
      />
      <el-table-column label="类型" align="center" prop="privacyType" width="120">
        <template #default="scope">
          <el-tag :type="typeTag(scope.row.privacyType)">{{ typeLabel(scope.row.privacyType) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="说明" align="center" prop="description" min-width="200" :show-overflow-tooltip="true" />
      <el-table-column label="创建时间" align="center" prop="createTime" width="180">
        <template #default="scope">
          <span>{{ parseTime(scope.row.createTime) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="150" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button
            link
            type="primary"
            icon="Edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['system:privacy:edit']"
            >修改</el-button
          >
          <el-button
            link
            type="primary"
            icon="Delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['system:privacy:remove']"
            >删除</el-button
          >
        </template>
      </el-table-column>
    </el-table>

    <el-dialog title="隐私配置" v-model="dialogVisible" width="520px" append-to-body>
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="配置键" prop="privacyKey">
          <el-input v-model="form.privacyKey" placeholder="如 data_retention_days" :disabled="form.privacyId != null" />
        </el-form-item>
        <el-form-item label="配置值" prop="privacyValue">
          <el-input v-model="form.privacyValue" placeholder="请输入配置值" />
        </el-form-item>
        <el-form-item label="类型" prop="privacyType">
          <el-select v-model="form.privacyType" placeholder="请选择类型" style="width: 100%">
            <el-option v-for="t in typeOptions" :key="t.value" :label="t.label" :value="t.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="说明" prop="description">
          <el-input v-model="form.description" type="textarea" placeholder="配置用途说明" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="submitForm">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="SystemPrivacy">
import { listPrivacy, addPrivacy, updatePrivacy, deletePrivacy } from '@/api/system/service'

const { proxy } = getCurrentInstance()

const typeOptions = [
  { value: 'retention', label: '数据保留' },
  { value: 'log', label: '日志策略' },
  { value: 'backup', label: '备份策略' }
]

const loading = ref(false)
const showSearch = ref(true)
const privacyList = ref([])
const dialogVisible = ref(false)
const formRef = ref(null)
const form = ref({ privacyId: null, privacyKey: '', privacyValue: '', privacyType: 'retention', description: '' })
const queryParams = ref({ privacyKey: '', privacyType: '' })

const rules = {
  privacyKey: [{ required: true, message: '配置键不能为空', trigger: 'blur' }],
  privacyValue: [{ required: true, message: '配置值不能为空', trigger: 'blur' }],
  privacyType: [{ required: true, message: '请选择类型', trigger: 'change' }]
}

function typeLabel(v) {
  const t = typeOptions.find((x) => x.value === v)
  return t ? t.label : v
}
function typeTag(v) {
  return { retention: 'primary', log: 'success', backup: 'warning' }[v] || 'info'
}

function getList() {
  loading.value = true
  listPrivacy(queryParams.value)
    .then((res) => {
      privacyList.value = res.rows || res.data || []
    })
    .finally(() => {
      loading.value = false
    })
}

function handleQuery() {
  getList()
}
function resetQuery() {
  queryParams.value = { privacyKey: '', privacyType: '' }
  handleQuery()
}

function handleAdd() {
  form.value = { privacyId: null, privacyKey: '', privacyValue: '', privacyType: 'retention', description: '' }
  dialogVisible.value = true
}

function handleUpdate(row) {
  form.value = { ...row }
  dialogVisible.value = true
}

function submitForm() {
  formRef.value.validate((valid) => {
    if (!valid) return
    const req = form.value.privacyId ? updatePrivacy(form.value) : addPrivacy(form.value)
    req
      .then(() => {
        proxy.$modal.msgSuccess(form.value.privacyId ? '修改成功' : '新增成功')
        dialogVisible.value = false
        getList()
      })
      .catch(() => {})
  })
}

function handleDelete(row) {
  proxy.$modal
    .confirm('确认删除该隐私配置吗？')
    .then(() => deletePrivacy(row.privacyId))
    .then(() => {
      proxy.$modal.msgSuccess('删除成功')
      getList()
    })
    .catch(() => {})
}

getList()
</script>
