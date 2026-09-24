<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="模板名称" prop="promptName">
        <el-input
          v-model="queryParams.promptName"
          placeholder="请输入模板名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="适用场景" prop="scene">
        <el-select v-model="queryParams.scene" placeholder="请选择适用场景" clearable style="width: 200px">
          <el-option v-for="item in sceneOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="面试类型" prop="interviewType">
        <el-select v-model="queryParams.interviewType" placeholder="请选择面试类型" clearable style="width: 200px">
          <el-option v-for="item in interviewTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
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
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['ai:prompt:add']"
          >新增模板</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="promptList">
      <el-table-column
        label="模板名称"
        align="center"
        prop="promptName"
        :show-overflow-tooltip="true"
        min-width="170"
      />
      <el-table-column label="适用场景" align="center" width="110">
        <template #default="scope">
          <el-tag :type="sceneTagType(scope.row.scene)">{{ sceneLabel(scope.row.scene) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="面试类型" align="center" width="110">
        <template #default="scope">
          <el-tag :type="typeTagType(scope.row.interviewType)">{{ typeLabel(scope.row.interviewType) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="版本号" align="center" prop="version" width="90" />
      <el-table-column label="状态" align="center" width="100">
        <template #default="scope">
          <el-tag :type="statusTagType(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="最后修改人" align="center" prop="updateBy" width="110" />
      <el-table-column label="修改时间" align="center" width="160">
        <template #default="scope">
          <span>{{ parseTime(scope.row.updateTime) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="260" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['ai:prompt:edit']"
            >编辑</el-button
          >
          <el-button
            v-if="scope.row.status === '0'"
            link
            type="success"
            icon="Position"
            @click="handlePublish(scope.row)"
            v-hasPermi="['ai:prompt:edit']"
            >发布</el-button
          >
          <el-button link type="info" icon="Clock" @click="handleVersions(scope.row)" v-hasPermi="['ai:prompt:list']"
            >版本历史</el-button
          >
          <el-button
            v-if="scope.row.status === '1'"
            link
            type="danger"
            icon="SwitchButton"
            @click="handleDisable(scope.row)"
            v-hasPermi="['ai:prompt:edit']"
            >停用</el-button
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

    <!-- 编辑模板对话框（全屏） -->
    <el-dialog :title="title" v-model="open" fullscreen append-to-body>
      <el-form ref="promptRef" :model="form" :rules="rules" label-width="90px">
        <el-row :gutter="16">
          <el-col :span="6">
            <el-form-item label="模板名称" prop="promptName">
              <el-input v-model="form.promptName" placeholder="请输入模板名称" />
            </el-form-item>
          </el-col>
          <el-col :span="4">
            <el-form-item label="适用场景" prop="scene">
              <el-select v-model="form.scene" placeholder="请选择适用场景" style="width: 100%">
                <el-option v-for="item in sceneOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="4">
            <el-form-item label="面试类型" prop="interviewType">
              <el-select v-model="form.interviewType" placeholder="请选择面试类型" style="width: 100%">
                <el-option
                  v-for="item in interviewTypeOptions"
                  :key="item.value"
                  :label="item.label"
                  :value="item.value"
                />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col v-if="form.promptId" :span="4">
            <el-form-item label="版本号" prop="version">
              <el-input v-model="form.version" disabled />
            </el-form-item>
          </el-col>
        </el-row>
        <el-row :gutter="16">
          <el-col :span="17">
            <el-form-item label="提示词内容" prop="content">
              <el-input
                v-model="form.content"
                type="textarea"
                :rows="18"
                placeholder="请输入提示词内容，可点击右侧可用变量将其追加到内容末尾"
              />
            </el-form-item>
          </el-col>
          <el-col :span="7">
            <el-card shadow="never" class="variable-card">
              <template #header>
                <span>可用变量</span>
              </template>
              <div class="variable-tip">点击变量可将其追加到提示词内容末尾</div>
              <div v-for="v in variableList" :key="v.name" class="variable-item" @click="appendVariable(v.name)">
                <el-tag>{{ v.name }}</el-tag>
                <span class="variable-desc">{{ v.desc }}</span>
              </div>
            </el-card>
          </el-col>
        </el-row>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitDraft">保存草稿</el-button>
          <el-button type="success" @click="submitPublish">发 布</el-button>
          <el-button type="warning" plain @click="previewOpen = true">预 览</el-button>
          <el-button @click="cancel">取 消</el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 内容预览对话框 -->
    <el-dialog title="内容预览" v-model="previewOpen" width="700px" append-to-body>
      <div class="preview-content">{{ form.content || '暂无内容' }}</div>
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="previewOpen = false">关 闭</el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 版本历史对话框 -->
    <el-dialog title="版本历史" v-model="versionOpen" width="900px" append-to-body>
      <el-table :data="versionList">
        <el-table-column label="版本号" align="center" prop="version" width="100" />
        <el-table-column label="修改人" align="center" prop="updateBy" width="120" />
        <el-table-column label="修改时间" align="center" width="170">
          <template #default="scope">
            <span>{{ parseTime(scope.row.updateTime) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="变更摘要" align="center" prop="changeSummary" :show-overflow-tooltip="true" />
        <el-table-column label="操作" align="center" width="90">
          <template #default="scope">
            <el-button link type="primary" @click="handleRollback(scope.row)">回滚</el-button>
          </template>
        </el-table-column>
      </el-table>
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="versionOpen = false">关 闭</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="AiPrompt">
import { listPrompt, getPrompt, addPrompt, updatePrompt, publishPrompt, listVersions } from '@/api/ai/prompt'
import { ElMessage } from 'element-plus'

const { proxy } = getCurrentInstance()

const promptList = ref([])
const open = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const title = ref('')
const previewOpen = ref(false)
const versionOpen = ref(false)
const versionList = ref([])

const sceneOptions = ref([
  { value: 'hr', label: 'HR端' },
  { value: 'candidate', label: '候选人端' }
])
const interviewTypeOptions = ref([
  { value: 'tech', label: '技术面' },
  { value: 'behavior', label: '行为面' },
  { value: 'mixed', label: '综合面' }
])
const statusOptions = ref([
  { value: '0', label: '草稿' },
  { value: '1', label: '已发布' },
  { value: '2', label: '已停用' }
])

const variableList = [
  { name: '{候选人姓名}', desc: '当前候选人' },
  { name: '{岗位名称}', desc: '应聘岗位' },
  { name: '{面试轮次}', desc: '第几轮面试' },
  { name: '{题目数量}', desc: '本次面试题目总数' }
]

const data = reactive({
  form: {},
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    promptName: undefined,
    scene: undefined,
    interviewType: undefined,
    status: undefined
  },
  rules: {
    promptName: [{ required: true, message: '模板名称不能为空', trigger: 'blur' }]
  }
})

const { form, queryParams, rules } = toRefs(data)

/**
 查询提示词列表 */
function getList() {
  loading.value = true

  listPrompt(data.queryParams)
    .then((response) => {
      promptList.value = response.rows
      total.value = response.total
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
  data.queryParams.pageNum = 1
  getList()
}

function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}

function sceneTagType(scene) {
  return scene === 'hr' ? 'primary' : 'success'
}

function typeTagType(type) {
  if (type === 'tech') return 'primary'
  if (type === 'behavior') return 'warning'
  return 'success'
}

function statusTagType(status) {
  if (status === '0') return 'warning'
  if (status === '1') return 'success'
  return 'info'
}

function sceneLabel(scene) {
  const item = sceneOptions.value.find((o) => o.value === scene)
  return item ? item.label : scene
}

function typeLabel(type) {
  const item = interviewTypeOptions.value.find((o) => o.value === type)
  return item ? item.label : type
}

function statusLabel(status) {
  const item = statusOptions.value.find((o) => o.value === status)
  return item ? item.label : status
}

/** 新增按钮操作 */
function handleAdd() {
  reset()
  open.value = true
  title.value = '新增模板'
}

/** 表单重置 */
function reset() {
  data.form = {
    promptId: undefined,
    promptName: undefined,
    scene: undefined,
    interviewType: undefined,
    version: undefined,
    content: '',
    status: '0'
  }
  proxy.resetForm('promptRef')
}

/** 修改按钮操作 */
function handleUpdate(row) {
  reset()
  getPrompt(row.promptId)
    .then((response) => {
      data.form = response.data
      open.value = true
      title.value = '编辑模板'
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('操作失败')
    })
}

/** 提交草稿 */
function submitDraft() {
  proxy.$refs['promptRef'].validate((valid) => {
    if (valid) {
      if (data.form.promptId != undefined) {
        updatePrompt(data.form)
          .then(() => {
            proxy.$modal.msgSuccess('保存成功')
          })
          .catch((err) => {
            console.error(err)
            proxy?.$msgError?.('操作失败')
          })
      } else {
        addPrompt(data.form)
          .then(() => {
            proxy.$modal.msgSuccess('保存成功')
          })
          .catch((err) => {
            console.error(err)
            proxy?.$msgError?.('操作失败')
          })
      }
    }
  })
}

/** 发布（对话框内） */
function submitPublish() {
  proxy.$refs['promptRef'].validate((valid) => {
    if (valid) {
      publishPrompt(data.form.promptId)
        .then(() => {
          proxy.$modal.msgSuccess('发布成功')
          open.value = false
          getList()
        })
        .catch(() => {})
    }
  })
}

/** 发布（列表操作，仅草稿显示） */
function handlePublish(row) {
  proxy.$modal
    .confirm('确认要发布模板' + row.promptName + '吗？发布后将使用最新版本。')
    .then(function () {
      return publishPrompt(row.promptId)
    })
    .then(() => {
      proxy.$modal.msgSuccess('发布成功')
      getList()
    })
    .catch(() => {})
}

/** 停用（列表操作，仅已发布显示） */
function handleDisable(row) {
  proxy.$modal
    .confirm('确认要停用模板' + row.promptName + '吗？')
    .then(function () {
      return updatePrompt(Object.assign({}, row, { status: '2' }))
    })
    .then(() => {
      proxy.$modal.msgSuccess('已停用')
      getList()
    })
    .catch(() => {})
}

/** 查看版本历史 */
function handleVersions(row) {
  versionOpen.value = true
  listVersions(row.promptId)
    .then((res) => {
      versionList.value = res.data || []
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('版本加载失败')
    })
}

/** 回滚 */
function handleRollback(row) {
  proxy.$modal
    .confirm('确认要回滚到版本 ' + row.version + ' 吗？')
    .then(function () {
      return updatePrompt(
        Object.assign({}, data.form, {
          version: row.version,
          promptId: row.sourcePromptId || row.promptId
        })
      )
    })
    .then(() => {
      versionOpen.value = false
      proxy.$modal.msgSuccess('已回滚到版本 ' + row.version)
      getList()
    })
    .catch(() => {})
}

/** 取消按钮 */
function cancel() {
  open.value = false
  reset()
}

/** 追加变量 */
function appendVariable(name) {
  data.form.content += name
}

getList()
</script>

<style lang="scss" scoped>
.variable-card {
  :deep(.el-card__header) {
    padding: 12px 16px;
    font-weight: 600;
  }
}
.variable-tip {
  margin-bottom: 10px;
  font-size: 12px;
  color: #909399;
}
.variable-item {
  display: flex;
  align-items: center;
  padding: 7px 4px;
  border-bottom: 1px dashed #ebeef5;
  cursor: pointer;
  &:hover {
    background-color: #f5f7fa;
  }
  &:last-child {
    border-bottom: none;
  }
}
.variable-desc {
  margin-left: 10px;
  font-size: 13px;
  color: #606266;
}
.preview-content {
  max-height: 60vh;
  padding: 12px;
  overflow-y: auto;
  font-size: 14px;
  line-height: 1.8;
  color: #303133;
  white-space: pre-wrap;
  word-break: break-word;
  background-color: #f5f7fa;
  border-radius: 4px;
}
</style>
