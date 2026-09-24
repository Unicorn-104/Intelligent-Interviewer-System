<template>
  <div class="app-container">
    <el-card v-loading="configLoading">
      <template #header>
        <span>考核环境配置</span>
      </template>
      <el-form :model="form" label-width="160px">
        <el-form-item label="支持语言" prop="languages">
          <el-select
            v-model="form.languages"
            multiple
            filterable
            allow-create
            default-first-option
            placeholder="请选择或输入支持语言"
            style="width: 400px"
          >
            <el-option v-for="item in languageOptions" :key="item" :label="item" :value="item" />
          </el-select>
        </el-form-item>
        <el-form-item label="编辑器主题" prop="editorTheme">
          <el-select v-model="form.editorTheme" placeholder="请选择编辑器主题" style="width: 200px">
            <el-option v-for="item in themeOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="单题限时(分钟)" prop="timeLimit">
          <el-input-number v-model="form.timeLimit" :min="5" :max="180" />
        </el-form-item>
        <el-form-item label="内存限制(MB)" prop="memoryLimit">
          <el-input-number v-model="form.memoryLimit" :min="64" :max="2048" :step="64" />
        </el-form-item>
        <el-form-item label="超时自动提交" prop="autoSubmit">
          <el-switch v-model="form.autoSubmit" />
        </el-form-item>
        <el-form-item label="代码查重检测" prop="plagiarismCheck">
          <el-switch v-model="form.plagiarismCheck" />
        </el-form-item>
        <el-form-item label="启用状态" prop="status">
          <el-radio-group v-model="form.status">
            <el-radio value="0">启用</el-radio>
            <el-radio value="1">停用</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="备注" prop="remark">
          <el-input v-model="form.remark" type="textarea" :rows="3" placeholder="请输入备注" style="width: 400px" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="saveLoading" @click="handleSave">保 存</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card class="record-card" v-loading="recordLoading">
      <template #header>
        <span>近期考核记录</span>
      </template>
      <div class="record-tip">
        <el-text type="info" size="small">仅展示最近 10 条</el-text>
      </div>
      <el-table :data="recordList">
        <el-table-column label="ID" align="center" prop="recordId" width="70" />
        <el-table-column label="候选人" align="center" prop="candidate" min-width="130" />
        <el-table-column label="岗位" align="center" prop="jobName" min-width="180" :show-overflow-tooltip="true" />
        <el-table-column label="企业" align="center" prop="companyName" min-width="120" />
        <el-table-column label="语言" align="center" prop="language" width="100" />
        <el-table-column label="用时" align="center" prop="duration" width="90" />
        <el-table-column label="得分" align="center" width="80">
          <template #default="scope">
            <span>{{ formatScore(scope.row.score) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" align="center" width="90">
          <template #default="scope">
            <el-tag :type="recordStatusTag(scope.row.status)">{{ recordStatusLabel(scope.row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="提交时间" align="center" prop="submitTime" width="160" />
        <el-table-column label="异常说明" align="center" min-width="200" :show-overflow-tooltip="true">
          <template #default="scope">
            <span>{{ scope.row.remark || '-' }}</span>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup name="BizExam">
import { getExamConfig, updateExamConfig, listExamRecord } from '@/api/biz/exam'

const { proxy } = getCurrentInstance()

const configLoading = ref(false)
const saveLoading = ref(false)
const recordLoading = ref(false)
const recordList = ref([])

// 支持语言候选
const languageOptions = ['Java', 'Python', 'JavaScript', 'C++', 'Go', 'SQL', 'C']

// 编辑器主题选项
const themeOptions = [
  { value: 'vs-dark', label: '深色' },
  { value: 'vs', label: '浅色' },
  { value: 'hc-black', label: '高对比' }
]

// 考核记录状态选项
const recordStatusOptions = [
  { value: '0', label: '已完成', tag: 'success' },
  { value: '1', label: '进行中', tag: 'primary' },
  { value: '2', label: '异常', tag: 'danger' }
]

const form = ref({
  languages: [],
  editorTheme: 'vs-dark',
  timeLimit: 60,
  memoryLimit: 256,
  autoSubmit: true,
  plagiarismCheck: false,
  status: '0',
  remark: undefined
})

/** 获取配置 */
function getConfig() {
  configLoading.value = true
  getExamConfig()
    .then((response) => {
      var res = response.data || {}
      form.value = {
        languages: res.languages || [],
        editorTheme: res.editorTheme || 'vs-dark',
        timeLimit: res.timeLimit != undefined ? res.timeLimit : 60,
        memoryLimit: res.memoryLimit != undefined ? res.memoryLimit : 256,
        autoSubmit: res.autoSubmit != undefined ? res.autoSubmit : true,
        plagiarismCheck: res.plagiarismCheck != undefined ? res.plagiarismCheck : false,
        status: res.status != undefined ? res.status : '0',
        remark: res.remark
      }
    })
    .catch(function (err) {
      console.error('加载配置失败:', err)
    })
    .finally(function () {
      configLoading.value = false
    })
}

/** 保存配置 */
function handleSave() {
  saveLoading.value = true
  updateExamConfig(form.value)
    .then(function () {
      proxy.$modal.msgSuccess('保存成功')
    })
    .catch(function (err) {
      console.error(err)
      proxy.$modal.msgError('保存失败')
    })
    .finally(function () {
      saveLoading.value = false
    })
}

/** 获取记录列表 */
function getRecordList() {
  recordLoading.value = true
  listExamRecord()
    .then((response) => {
      recordList.value = response.rows || []
    })
    .catch(function (err) {
      console.error(err)
      proxy.$modal.msgError('加载记录失败')
    })
    .finally(function () {
      recordLoading.value = false
    })
}

/** 考核记录状态显示 */
function recordStatusLabel(val) {
  var item = recordStatusOptions.find(function (o) {
    return o.value === val
  })
  return item ? item.label : val
}

function recordStatusTag(val) {
  var item = recordStatusOptions.find(function (o) {
    return o.value === val
  })
  return item && item.tag ? item.tag : undefined
}

/** 得分为 0 时显示 - */
function formatScore(val) {
  if (val === undefined || val === null || val === '' || Number(val) === 0) return '-'
  return val
}

getConfig()
getRecordList()
</script>

<style lang="scss" scoped>
.record-card {
  margin-top: 16px;

  .record-tip {
    margin-bottom: 12px;
  }
}
</style>
