<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="题目内容" prop="content">
        <el-input
          v-model="queryParams.content"
          placeholder="请输入题目内容"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="题目类型" prop="questionType">
        <el-select v-model="queryParams.questionType" placeholder="请选择题目类型" clearable style="width: 160px">
          <el-option v-for="item in questionTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="适用场景" prop="scene">
        <el-select v-model="queryParams.scene" placeholder="请选择适用场景" clearable style="width: 160px">
          <el-option v-for="item in sceneOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="难度" prop="difficulty">
        <el-select v-model="queryParams.difficulty" placeholder="请选择难度" clearable style="width: 160px">
          <el-option v-for="item in difficultyOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
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
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['content:question:add']"
          >新增题目</el-button
        >
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="success"
          plain
          icon="Edit"
          :disabled="single"
          @click="handleUpdate"
          v-hasPermi="['content:question:edit']"
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
          v-hasPermi="['content:question:remove']"
          >删除</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="questionList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="题目内容" align="center" prop="content" :show-overflow-tooltip="true" />
      <el-table-column label="题目类型" align="center" width="100">
        <template #default="scope">
          <el-tag :type="typeTag(scope.row).type">{{ typeTag(scope.row).label }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="适用场景" align="center" width="100">
        <template #default="scope">
          <el-tag :type="sceneTag(scope.row).type">{{ sceneTag(scope.row).label }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="难度" align="center" width="90">
        <template #default="scope">
          <el-tag :type="difficultyTag(scope.row).type">{{ difficultyTag(scope.row).label }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="使用次数" align="center" prop="useCount" width="90" />
      <el-table-column label="状态" align="center" width="90">
        <template #default="scope">
          <el-tag :type="scope.row.status == '0' ? 'success' : 'danger'">{{
            scope.row.status == '0' ? '启用' : '停用'
          }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="创建时间" align="center" prop="createTime" width="110">
        <template #default="scope">
          <span>{{ parseTime(scope.row.createTime, '{y}-{m}-{d}') }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="220" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button
            link
            :type="scope.row.status == '0' ? 'warning' : 'success'"
            icon="SwitchButton"
            @click="handleStatusChange(scope.row)"
            v-hasPermi="['content:question:edit']"
            >{{ scope.row.status == '0' ? '停用' : '启用' }}</el-button
          >
          <el-button
            link
            type="primary"
            icon="Edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['content:question:edit']"
            >修改</el-button
          >
          <el-button
            link
            type="primary"
            icon="Delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['content:question:remove']"
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

    <!-- 新增或修改面试题对话框 -->
    <el-dialog :title="title" v-model="open" width="900px" append-to-body>
      <el-form ref="questionRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="题目内容" prop="content">
          <el-input
            v-model="form.content"
            type="textarea"
            :rows="4"
            placeholder="请输入题目内容"
            maxlength="500"
            show-word-limit
          />
        </el-form-item>
        <el-form-item label="题目类型" prop="questionType">
          <el-radio-group v-model="form.questionType" @change="handleTypeChange">
            <el-radio v-for="item in questionTypeOptions" :key="item.value" :value="item.value">{{
              item.label
            }}</el-radio>
          </el-radio-group>
        </el-form-item>
        <template v-if="form.questionType !== 'open'">
          <el-form-item v-for="(option, index) in form.options" :key="index" :label="index === 0 ? '选项设置' : ' '">
            <div class="option-row">
              <span class="option-key">{{ option.key }}</span>
              <el-input v-model="option.text" placeholder="请输入选项内容" class="option-input" />
              <el-radio
                v-if="form.questionType === 'single'"
                v-model="option.isCorrect"
                @change="handleSingleCorrect(option)"
                >正确答案</el-radio
              >
              <el-checkbox v-else v-model="option.isCorrect">正确答案</el-checkbox>
              <el-button
                link
                type="danger"
                icon="Delete"
                :disabled="form.options.length <= 2"
                @click="handleRemoveOption(index)"
                >删除</el-button
              >
            </div>
          </el-form-item>
          <el-form-item label=" " label-width="90px">
            <el-button type="primary" plain icon="Plus" :disabled="form.options.length >= 6" @click="handleAddOption"
              >添加选项</el-button
            >
          </el-form-item>
        </template>
        <el-row>
          <el-col :span="12">
            <el-form-item label="适用场景" prop="scene">
              <el-select v-model="form.scene" placeholder="请选择适用场景" clearable style="width: 100%">
                <el-option v-for="item in sceneOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="难度" prop="difficulty">
              <el-select v-model="form.difficulty" placeholder="请选择难度" clearable style="width: 100%">
                <el-option
                  v-for="item in difficultyOptions"
                  :key="item.value"
                  :label="item.label"
                  :value="item.value"
                />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="解析说明" prop="analysis">
          <el-input v-model="form.analysis" type="textarea" :rows="3" placeholder="请输入解析说明（选填）" />
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

<script setup name="Question">
import { listQuestion, getQuestion, addQuestion, updateQuestion, delQuestion } from '@/api/content/question'

const { proxy } = getCurrentInstance()

const questionList = ref([])
const open = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const ids = ref([])
const single = ref(true)
const multiple = ref(true)
const total = ref(0)
const title = ref('')

const optionLetters = ['A', 'B', 'C', 'D', 'E', 'F']
const questionTypeOptions = [
  { value: 'single', label: '单选' },
  { value: 'multiple', label: '多选' },
  { value: 'open', label: '开放题' }
]
const sceneOptions = [
  { value: 'tech', label: '技术面' },
  { value: 'behavior', label: '行为面' },
  { value: 'mixed', label: '综合面' }
]
const difficultyOptions = [
  { value: 'easy', label: '简单' },
  { value: 'medium', label: '中等' },
  { value: 'hard', label: '困难' }
]
const statusOptions = [
  { value: '0', label: '启用' },
  { value: '1', label: '停用' }
]

const data = reactive({
  form: {},
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    content: undefined,
    questionType: undefined,
    scene: undefined,
    difficulty: undefined,
    status: undefined
  },
  rules: {
    content: [{ required: true, message: '题目内容不能为空', trigger: 'blur' }]
  }
})

const { form, queryParams, rules } = toRefs(data)

/** 查询列表 */
function getList() {
  loading.value = true
  listQuestion(queryParams.value)
    .then((response) => {
      questionList.value = response.rows
      total.value = response.total
      loading.value = false
    })
    .catch((err) => {
      console.error('查询题目列表失败:', err)
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

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.questionId)
  single.value = selection.length !== 1
  multiple.value = !selection.length
}

/** 新增按钮操作 */
function handleAdd() {
  reset()
  open.value = true
  title.value = '新增题目'
  form.value.options = [
    { key: 'A', text: '', isCorrect: false },
    { key: 'B', text: '', isCorrect: false }
  ]
}

/** 修改按钮操作 */
function handleUpdate(row) {
  reset()
  const questionId = row.questionId || ids.value[0]
  getQuestion(questionId)
    .then((response) => {
      form.value = response.data
      if (!form.value.options || form.value.options.length === 0) {
        form.value.options = [
          { key: 'A', text: '', isCorrect: false },
          { key: 'B', text: '', isCorrect: false }
        ]
      }
      open.value = true
      title.value = '修改题目'
    })
    .catch((err) => {
      console.error('查询题目详情失败:', err)
    })
}

/** 提交表单 */
function submitForm() {
  proxy.$refs['questionRef'].validate((valid) => {
    if (valid) {
      if (form.value.questionId !== undefined) {
        updateQuestion(form.value)
          .then(() => {
            proxy.$modal.msgSuccess('修改成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error('修改失败:', err)
          })
      } else {
        addQuestion(form.value)
          .then(() => {
            proxy.$modal.msgSuccess('新增成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error('新增失败:', err)
          })
      }
    }
  })
}

/** 取消按钮 */
function cancel() {
  open.value = false
  reset()
}

/** 表单重置 */
function reset() {
  form.value = {
    questionId: undefined,
    content: undefined,
    questionType: undefined,
    options: [],
    scene: undefined,
    difficulty: undefined,
    analysis: undefined,
    status: '0'
  }
  proxy.resetForm('questionRef')
}

/** 状态修改 */
function handleStatusChange(row) {
  const nextStatus = row.status === '0' ? '1' : '0'
  const text = nextStatus === '0' ? '启用' : '停用'
  proxy.$modal
    .confirm('确认要"' + text + '""' + row.content + '"题目吗？')
    .then(function () {
      return updateQuestion({ questionId: row.questionId, status: nextStatus })
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess(text + '成功')
    })
    .catch(() => {})
}

/** 删除按钮操作 */
function handleDelete(row) {
  const questionIds = row.questionId || ids.value
  proxy.$modal
    .confirm('是否确认删除题目编号为"' + questionIds + '"的数据项？')
    .then(function () {
      return delQuestion(questionIds)
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(() => {})
}

/** 类型切换 */
function handleTypeChange() {
  if (form.value.questionType === 'open') {
    form.value.options = []
  } else if (!form.value.options || form.value.options.length === 0) {
    form.value.options = [
      { key: 'A', text: '', isCorrect: false },
      { key: 'B', text: '', isCorrect: false }
    ]
  }
}

/** 添加选项 */
function handleAddOption() {
  if (form.value.options.length < 6) {
    const idx = form.value.options.length
    form.value.options.push({
      key: optionLetters[idx] || String.fromCharCode(65 + idx),
      text: '',
      isCorrect: false
    })
  }
}

/** 删除选项 */
function handleRemoveOption(index) {
  if (form.value.options.length <= 2) {
    proxy.$modal.msgWarning('至少保留2个选项')
    return
  }
  form.value.options.splice(index, 1)
}

/** 单选题设置正确答案 */
function handleSingleCorrect(option) {
  form.value.options.forEach((o) => {
    if (o !== option) o.isCorrect = false
  })
}

/** 类型标签 */
function typeTag(row) {
  const found = questionTypeOptions.find((o) => o.value === row.questionType)
  return found ? { label: found.label, type: 'primary' } : { label: row.questionType, type: 'info' }
}

/** 场景标签 */
function sceneTag(row) {
  const found = sceneOptions.find((o) => o.value === row.scene)
  return found ? { label: found.label, type: 'success' } : { label: row.scene, type: 'info' }
}

/** 难度标签 */
function difficultyTag(row) {
  const found = difficultyOptions.find((o) => o.value === row.difficulty)
  return found ? { label: found.label, type: 'warning' } : { label: row.difficulty, type: 'info' }
}

getList()
</script>

<style lang="scss" scoped>
.app-container {
  .option-row {
    display: flex;
    align-items: center;
    width: 100%;

    .option-key {
      width: 24px;
      flex-shrink: 0;
      text-align: center;
      font-weight: 600;
    }

    .option-input {
      flex: 1;
      margin: 0 8px;
    }

    .el-button {
      flex-shrink: 0;
    }
  }
}
</style>
