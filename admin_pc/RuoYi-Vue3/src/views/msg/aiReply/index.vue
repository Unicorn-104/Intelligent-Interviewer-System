<template>
  <div class="app-container">
    <el-card class="box-card" shadow="hover">
      <template #header><span class="section-title">AI应答配置</span></template>
      <el-form :model="aiConfig" label-width="120px" style="max-width: 600px">
        <el-form-item label="启用AI应答"><el-switch v-model="aiConfig.enabled" @change="handleSave" /></el-form-item>
        <el-form-item label="回复语言">
          <el-select v-model="aiConfig.language" style="width: 200px" @change="handleSave">
            <el-option label="中文" value="zh" /><el-option label="English" value="en" /><el-option
              label="日本語"
              value="ja"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="回复风格">
          <el-select v-model="aiConfig.style" style="width: 200px" @change="handleSave">
            <el-option label="专业正式" value="formal" /><el-option label="亲切友好" value="friendly" /><el-option
              label="简洁高效"
              value="concise"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="响应超时(秒)"
          ><el-input-number v-model="aiConfig.timeout" :min="5" :max="60" @change="handleSave"
        /></el-form-item>
        <el-form-item label="自动回复阈值">
          <el-select v-model="aiConfig.autoReply" style="width: 200px" @change="handleSave">
            <el-option label="简单问题自动回复" value="simple" /><el-option
              label="所有问题自动回复"
              value="all"
            /><el-option label="仅转发人工" value="human" />
          </el-select>
        </el-form-item>
        <el-form-item label="知识库ID"><el-input v-model="aiConfig.knowledgeBaseId" disabled /></el-form-item>
        <el-form-item><el-button type="primary" @click="handleSave">保存配置</el-button></el-form-item>
      </el-form>
    </el-card>

    <el-card class="box-card" shadow="hover" style="margin-top: 20px">
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center">
          <span class="section-title">最近应答记录</span>
          <el-button text type="primary" @click="loadRecords">刷新</el-button>
        </div>
      </template>
      <el-table v-loading="recordsLoading" :data="records" stripe>
        <el-table-column label="提问用户" align="center" prop="userName" width="120" />
        <el-table-column
          label="问题内容"
          align="center"
          prop="question"
          :show-overflow-tooltip="true"
          min-width="200"
        />
        <el-table-column label="AI回复" align="center" prop="answer" :show-overflow-tooltip="true" min-width="200" />
        <el-table-column label="是否转人工" align="center" prop="transferToHuman" width="100">
          <template #default="scope">
            <el-tag :type="scope.row.transferToHuman === '1' ? 'danger' : 'success'">{{
              scope.row.transferToHuman === '1' ? '转人工' : 'AI回复'
            }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="响应时间" align="center" prop="responseTime" width="100" />
        <el-table-column label="提问时间" align="center" prop="createTime" width="160">
          <template #default="scope"
            ><span>{{ parseTime(scope.row.createTime) }}</span></template
          >
        </el-table-column>
      </el-table>
      <pagination
        v-show="recordsTotal > 0"
        :total="recordsTotal"
        v-model:page="recordQuery.pageNum"
        v-model:limit="recordQuery.pageSize"
        @pagination="loadRecords"
      />
    </el-card>

    <el-card class="box-card" shadow="hover" style="margin-top: 20px">
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center">
          <span class="section-title">知识库管理</span>
          <el-button type="primary" plain icon="Plus" size="small" @click="handleAddKnowledge">新增条目</el-button>
        </div>
      </template>
      <el-form :inline="true" class="kb-filter">
        <el-form-item label="关键词">
          <el-input
            v-model="kbQuery.keyword"
            placeholder="问题 / 回答关键词"
            clearable
            style="width: 200px"
            @keyup.enter="handleKbSearch"
          />
        </el-form-item>
        <el-form-item label="分类">
          <el-select v-model="kbQuery.category" placeholder="全部分类" clearable style="width: 140px">
            <el-option v-for="c in kbCategories" :key="c" :label="c" :value="c" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" icon="Search" @click="handleKbSearch">查询</el-button>
          <el-button icon="Refresh" @click="resetKbSearch">重置</el-button>
        </el-form-item>
      </el-form>
      <el-table v-loading="kbLoading" :data="knowledgeBase" stripe>
        <el-table-column label="编号" align="center" prop="id" width="70" />
        <el-table-column label="问题" align="center" prop="question" :show-overflow-tooltip="true" min-width="200" />
        <el-table-column label="回答" align="center" prop="answer" :show-overflow-tooltip="true" min-width="200" />
        <el-table-column label="分类" align="center" prop="category" width="100" />
        <el-table-column label="使用次数" align="center" prop="useCount" width="80" />
        <el-table-column label="操作" align="center" width="150">
          <template #default="scope">
            <el-button link type="primary" icon="Edit" @click="handleEditKnowledge(scope.row)">编辑</el-button>
            <el-button link type="danger" icon="Delete" @click="handleDeleteKnowledge(scope.row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog :title="kbTitle" v-model="kbOpen" width="500px" append-to-body>
      <el-form ref="kbRef" :model="kbForm" :rules="kbRules" label-width="80px">
        <el-form-item label="问题" prop="question"
          ><el-input v-model="kbForm.question" placeholder="请输入常见问题"
        /></el-form-item>
        <el-form-item label="回答" prop="answer"
          ><el-input v-model="kbForm.answer" type="textarea" :rows="4" placeholder="请输入标准回答"
        /></el-form-item>
        <el-form-item label="分类" prop="category">
          <el-select v-model="kbForm.category" style="width: 100%">
            <el-option v-for="c in kbCategories" :key="c" :label="c" :value="c" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button type="primary" @click="submitKb">确 定</el-button>
        <el-button @click="kbOpen = false">取 消</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="MsgAiReply">
import {
  getAiConfig,
  updateAiConfig,
  listAiRecord,
  listAiKnowledge,
  addAiKnowledge,
  delAiKnowledge,
  updateAiKnowledge
} from '@/api/msg/aiReply'

const { proxy } = getCurrentInstance()
const aiConfig = ref({})
const records = ref([])
const recordsTotal = ref(0)
const recordsLoading = ref(false)
const knowledgeBase = ref([])
const kbLoading = ref(false)
const kbOpen = ref(false)
const kbTitle = ref('')
const kbCategories = ['常见问题', '面试流程', '岗位详情', '简历投递', '账号问题', '其他']
const recordQuery = ref({ pageNum: 1, pageSize: 10 })
const kbForm = ref({
  id: undefined,
  question: '',
  answer: '',
  category: ''
})
const kbRules = {
  question: [{ required: true, message: '问题不能为空', trigger: 'blur' }],
  answer: [{ required: true, message: '回答不能为空', trigger: 'blur' }]
}

/** 加载配置 */
function loadConfig() {
  getAiConfig()
    .then((res) => {
      aiConfig.value = res.data || aiConfig.value
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('加载配置失败')
    })
}

/** 加载记录列表 */
function loadRecords() {
  recordsLoading.value = true
  listAiRecord(recordQuery.value)
    .then((res) => {
      records.value = res.rows
      recordsTotal.value = res.total
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('查询失败')
    })
    .finally(() => {
      recordsLoading.value = false
    })
}

/** 加载知识库 */
function loadKnowledge() {
  kbLoading.value = true
  listAiKnowledge({ keyword: kbQuery.keyword, category: kbQuery.category })
    .then((res) => {
      knowledgeBase.value = res.rows || []
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('查询失败')
    })
    .finally(() => {
      kbLoading.value = false
    })
}

/** 知识库查询 / 重置 */
const kbQuery = reactive({ keyword: '', category: '' })
function handleKbSearch() {
  loadKnowledge()
}
function resetKbSearch() {
  kbQuery.keyword = ''
  kbQuery.category = ''
  loadKnowledge()
}

/** 保存配置 */
function handleSave() {
  updateAiConfig(aiConfig.value)
    .then(() => {
      proxy.$modal.msgSuccess('保存成功')
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('保存失败')
    })
}

/** 新增知识库 */
function handleAddKnowledge() {
  kbTitle.value = '新增知识库条目'
  Object.assign(kbForm.value, {
    id: undefined,
    question: '',
    answer: '',
    category: ''
  })
  kbOpen.value = true
}

/** 编辑知识库 */
function handleEditKnowledge(row) {
  kbTitle.value = '编辑知识库条目'
  Object.assign(kbForm.value, row)
  kbOpen.value = true
}

/** 删除知识库 */
function handleDeleteKnowledge(row) {
  proxy.$modal
    .confirm('确认删除？')
    .then(() => {
      return delAiKnowledge(row.id)
    })
    .then(() => {
      proxy.$modal.msgSuccess('删除成功')
      loadKnowledge()
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('操作失败')
    })
}

/** 提交知识库表单 */
function submitKb() {
  const fn = kbForm.value.id ? updateAiKnowledge : addAiKnowledge
  fn(kbForm.value)
    .then(() => {
      proxy.$modal.msgSuccess('保存成功')
      kbOpen.value = false
      loadKnowledge()
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('保存失败')
    })
}

loadConfig()
loadRecords()
loadKnowledge()
</script>
