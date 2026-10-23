<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="模型名称" prop="modelName">
        <el-input
          v-model="queryParams.modelName"
          placeholder="请输入模型名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="提供商" prop="provider">
        <el-select v-model="queryParams.provider" placeholder="请选择提供商" clearable style="width: 200px">
          <el-option v-for="item in providerOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable style="width: 200px">
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
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['ai:model:add']"
          >新增模型</el-button
        >
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="success"
          plain
          icon="Edit"
          :disabled="single"
          @click="handleUpdate"
          v-hasPermi="['ai:model:edit']"
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
          v-hasPermi="['ai:model:remove']"
          >删除</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="modelList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="模型名称" align="center" prop="modelName" :show-overflow-tooltip="true" min-width="140" />
      <el-table-column label="提供商" align="center" width="100">
        <template #default="scope">
          <el-tag :type="providerTagType(scope.row.provider)">{{ providerLabel(scope.row.provider) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="模型类型" align="center" min-width="150">
        <template #default="scope">
          <el-tag v-for="t in scope.row.modelTypes" :key="t" :type="typeTagType(t)" class="type-tag">{{
            typeLabel(t)
          }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="API 地址" align="center" prop="apiUrl" :show-overflow-tooltip="true" min-width="200" />
      <el-table-column label="调用单价(元/千tokens)" align="center" prop="unitPrice" width="160" />
      <el-table-column label="API Key" align="center" prop="apiKey" width="170" :show-overflow-tooltip="true" />
      <el-table-column label="状态" align="center" width="90">
        <template #default="scope">
          <el-switch
            v-model="scope.row.status"
            :active-value="1"
            :inactive-value="0"
            @change="handleStatusChange(scope.row)"
          />
        </template>
      </el-table-column>
      <el-table-column label="最近调用时间" align="center" width="160">
        <template #default="scope">
          <span>{{ parseTime(scope.row.lastCallTime) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="220" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="warning" icon="Link" @click="handleTest(scope.row)" v-hasPermi="['ai:model:edit']"
            >测试连接</el-button
          >
          <el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['ai:model:edit']"
            >修改</el-button
          >
          <el-button link type="primary" icon="Delete" @click="handleDelete(scope.row)" v-hasPermi="['ai:model:remove']"
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

    <!-- 添加或修改模型对话框 -->
    <el-dialog :title="title" v-model="open" width="720px" append-to-body>
      <el-form ref="modelRef" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="12">
            <el-form-item label="模型名称" prop="modelName">
              <el-input v-model="form.modelName" placeholder="请输入模型名称" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="提供商" prop="provider">
              <el-select v-model="form.provider" placeholder="请选择提供商" style="width: 100%">
                <el-option v-for="item in providerOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="模型类型" prop="modelTypes">
              <el-checkbox-group v-model="form.modelTypes">
                <el-checkbox v-for="t in typeOptions" :key="t.value" :value="t.value">{{ t.label }}</el-checkbox>
              </el-checkbox-group>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="API 地址" prop="apiUrl">
              <el-input v-model="form.apiUrl" placeholder="请输入API地址" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="API Key" prop="apiKey">
              <el-input v-model="form.apiKey" type="password" show-password placeholder="请输入API Key" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="调用单价" prop="unitPrice">
              <el-input-number
                v-model="form.unitPrice"
                :precision="3"
                :step="0.001"
                :min="0"
                controls-position="right"
                style="width: 180px"
              />
              <span class="form-tip">元/千tokens</span>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="超时时间" prop="timeout">
              <el-input-number
                v-model="form.timeout"
                :step="1000"
                :min="1000"
                controls-position="right"
                style="width: 180px"
              />
              <span class="form-tip">毫秒</span>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="最大并发" prop="maxConcurrency">
              <el-input-number
                v-model="form.maxConcurrency"
                :min="1"
                :step="1"
                controls-position="right"
                style="width: 180px"
              />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="状态">
              <el-radio-group v-model="form.status">
                <el-radio v-for="item in statusOptions" :key="item.value" :value="item.value">{{
                  item.label
                }}</el-radio>
              </el-radio-group>
            </el-form-item>
          </el-col>
        </el-row>
      </el-form>
      <template #footer>
        <div class="model-dialog-footer">
          <el-button v-if="form.modelId" type="warning" plain :loading="testLoading" @click="handleTestForm"
            >测试连接</el-button
          >
          <div class="footer-right">
            <el-button type="primary" @click="submitForm">确 定</el-button>
            <el-button @click="cancel">取 消</el-button>
          </div>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="AiModel">
import { listModel, getModel, addModel, updateModel, delModel, testModel, changeModelStatus } from '@/api/ai/model'
import { ElMessage } from 'element-plus'

const { proxy } = getCurrentInstance()

const modelList = ref([])
const open = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const ids = ref([])
const single = ref(true)
const multiple = ref(true)
const total = ref(0)
const title = ref('')
const testLoading = ref(false)

const providerOptions = ref([
  { value: 'aliyun', label: '阿里云' },
  { value: 'other', label: '其他' }
])
const typeOptions = ref([
  { value: 'vl', label: '多模态' },
  { value: 'text', label: '文本' },
  { value: 'voice', label: '语音' }
])
const statusOptions = ref([
  { value: 1, label: '启用' },
  { value: 0, label: '停用' }
])

const data = reactive({
  form: {},
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    modelName: undefined,
    provider: undefined,
    status: undefined
  },
  rules: {
    modelName: [{ required: true, message: '\u6a21\u578b\u540d\u79f0\u4e0d\u80fd\u4e3a\u7a7a', trigger: 'blur' }],
    apiUrl: [{ required: true, message: 'API\u5730\u5740\u4e0d\u80fd\u4e3a\u7a7a', trigger: 'blur' }]
  }
})

const { form, queryParams, rules } = toRefs(data)

function providerTagType(provider) {
  if (provider === 'aliyun') return 'success'
  return 'info'
}

function providerLabel(provider) {
  const opt = providerOptions.value.find((p) => p.value === provider)
  return opt ? opt.label : provider
}

function typeTagType(type) {
  if (type === 'vl') return 'primary'
  if (type === 'text') return 'info'
  return 'info'
}

function typeLabel(type) {
  const opt = typeOptions.value.find((item) => item.value === type)
  return opt ? opt.label : type
}

/** \u67e5\u8be2\u6a21\u578b\u5217\u8868 */
function getList() {
  loading.value = true
  listModel(data.queryParams)
    .then((response) => {
      modelList.value = response.rows
      total.value = response.total
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('\u67e5\u8be2\u5931\u8d25')
    })
    .finally(() => {
      loading.value = false
    })
}

/** \u641c\u7d22\u6309\u94ae\u64cd\u4f5c */
function handleQuery() {
  data.queryParams.pageNum = 1
  getList()
}

/** \u91cd\u7f6e\u6309\u94ae\u64cd\u4f5c */
function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}

/** \u65b0\u589e\u6309\u94ae\u64cd\u4f5c */
function handleAdd() {
  reset()
  open.value = true
  title.value = '\u6dfb\u52a0AI\u6a21\u578b'
}

/** \u8868\u5355\u91cd\u7f6e */
function reset() {
  data.form = {
    modelId: undefined,
    modelName: undefined,
    provider: undefined,
    modelTypes: [],
    apiUrl: undefined,
    apiKey: undefined,
    unitPrice: 0,
    timeout: 3000,
    maxConcurrency: 10,
    status: 1
  }
  proxy.resetForm('modelRef')
}

/** \u4fee\u6539\u6309\u94ae\u64cd\u4f5c */
function handleUpdate(row) {
  reset()
  getModel(row.modelId)
    .then((response) => {
      data.form = response.data
      open.value = true
      title.value = '\u4fee\u6539AI\u6a21\u578b'
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('\u64cd\u4f5c\u5931\u8d25')
    })
}

/** \u63d0\u4ea4\u6309\u94ae */
function submitForm() {
  proxy.$refs['modelRef'].validate((valid) => {
    if (valid) {
      if (data.form.modelId != undefined) {
        updateModel(data.form)
          .then(() => {
            proxy.$modal.msgSuccess('\u4fee\u6539\u6210\u529f')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error(err)
            proxy?.$msgError?.('\u64cd\u4f5c\u5931\u8d25')
          })
      } else {
        addModel(data.form)
          .then(() => {
            proxy.$modal.msgSuccess('\u65b0\u589e\u6210\u529f')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error(err)
            proxy?.$msgError?.('\u64cd\u4f5c\u5931\u8d25')
          })
      }
    }
  })
}

/** \u53d6\u6d88\u6309\u94ae */
function cancel() {
  open.value = false
  reset()
}

/** \u6d4b\u8bd5\u8fde\u63a5\u6309\u94ae */
function handleTest(row) {
  testLoading.value = true
  testModel(row.modelId)
    .then((res) => {
      testLoading.value = false
      const result = res.data || {}
      if (result.success) {
        ElMessage.success('\u8fde\u63a5\u6210\u529f\uff0c\u54cd\u5e94 ' + result.latency + 'ms')
      } else {
        ElMessage.error('\u8fde\u63a5\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u6a21\u578b\u914d\u7f6e')
      }
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('\u64cd\u4f5c\u5931\u8d25')
      testLoading.value = false
    })
}

/** \u6d4b\u8bd5\u8fde\u63a5\uff08\u5bf9\u8bdd\u6846\u5185\uff09 */
function handleTestForm() {
  testLoading.value = true
  testModel(data.form.modelId)
    .then((res) => {
      testLoading.value = false
      const result = res.data || {}
      if (result.success) {
        ElMessage.success('\u8fde\u63a5\u6210\u529f\uff0c\u54cd\u5e94 ' + result.latency + 'ms')
      } else {
        ElMessage.error('\u8fde\u63a5\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u6a21\u578b\u914d\u7f6e')
      }
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('\u64cd\u4f5c\u5931\u8d25')
      testLoading.value = false
    })
}

/** \u72b6\u6001\u5207\u6362 */
function handleStatusChange(row) {
  const nextStatus = Number(row.status) === 1 ? 1 : 0
  const text = nextStatus === 1 ? '\u542f\u7528' : '\u505c\u7528'
  proxy.$modal
    .confirm('\u786e\u8ba4\u8981"' + text + '"' + row.modelName + '"\u6a21\u578b\u5417\uff1f')
    .then(function () {
      return changeModelStatus(row.modelId, nextStatus)
    })
    .then(() => {
      proxy.$modal.msgSuccess(text + '\u6210\u529f')
    })
    .catch(() => {
      row.status = nextStatus === 1 ? 0 : 1
    })
}

/** \u5220\u9664\u6309\u94ae\u64cd\u4f5c */
function handleDelete(row) {
  const modelIds = row.modelId || ids.value
  proxy.$modal
    .confirm(
      '\u662f\u5426\u786e\u8ba4\u5220\u9664AI\u6a21\u578b\u7f16\u53f7\u4e3a"' +
        modelIds +
        '"\u7684\u6570\u636e\u9879\uff1f'
    )
    .then(function () {
      return delModel(modelIds)
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('\u5220\u9664\u6210\u529f')
    })
    .catch(() => {})
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.modelId)
}

getList()
</script>
