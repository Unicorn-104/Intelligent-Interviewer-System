<template>
  <div class="app-container">
    <div class="stat-row">
      <div class="stat-card stat-total" :class="{ active: !queryParams.category }" @click="quickCategory(null)">
        <div class="stat-num">{{ stats.total }}</div>
        <div class="stat-label">全部题目</div>
      </div>
      <div class="stat-card stat-pro" :class="{ active: queryParams.category === 1 }" @click="quickCategory(1)">
        <div class="stat-num">{{ stats.category[1] || 0 }}</div>
        <div class="stat-label">专业题</div>
      </div>
      <div class="stat-card stat-person" :class="{ active: queryParams.category === 2 }" @click="quickCategory(2)">
        <div class="stat-num">{{ stats.category[2] || 0 }}</div>
        <div class="stat-label">性格测试</div>
      </div>
      <div class="stat-card stat-general" :class="{ active: queryParams.category === 3 }" @click="quickCategory(3)">
        <div class="stat-num">{{ stats.category[3] || 0 }}</div>
        <div class="stat-label">综合能力</div>
      </div>
      <div class="stat-card stat-behavior" :class="{ active: queryParams.category === 4 }" @click="quickCategory(4)">
        <div class="stat-num">{{ stats.category[4] || 0 }}</div>
        <div class="stat-label">行为面试</div>
      </div>
      <div class="stat-card stat-other" :class="{ active: queryParams.category === 5 }" @click="quickCategory(5)">
        <div class="stat-num">{{ stats.category[5] || 0 }}</div>
        <div class="stat-label">其他</div>
      </div>
    </div>

    <el-card v-if="bankType !== 'enterprise'" shadow="never" class="search-card">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="题目分类" prop="category">
        <el-select v-model="queryParams.category" placeholder="全部分类" clearable style="width: 140px">
          <el-option v-for="item in categoryOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="题目内容" prop="keyword">
        <el-input
          v-model="queryParams.keyword"
          placeholder="请输入题干关键词"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="题型" prop="type">
        <el-select v-model="queryParams.type" placeholder="全部题型" clearable style="width: 140px">
          <el-option v-for="item in typeOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="难度" prop="difficulty">
        <el-select v-model="queryParams.difficulty" placeholder="全部难度" clearable style="width: 140px">
          <el-option v-for="item in difficultyOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item v-if="bankType === 'enterprise'" label="企业" prop="companyId">
        <el-select v-model="queryParams.companyId" placeholder="全部企业" clearable filterable style="width: 200px">
          <el-option v-for="item in companyOptions" :key="item.id" :label="item.name" :value="item.id" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>
    </el-card>

    <el-card shadow="never" class="table-card">
    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['content:question:add']"
          >新增题目</el-button
        >
      </el-col>
      <el-col :span="1.5">
        <el-button type="warning" plain icon="Upload" @click="openImport" v-hasPermi="['content:question:add']"
          >文件导入</el-button
        >
      </el-col>
      <el-col :span="1.5">
        <el-button type="info" plain icon="Tickets" @click="openImportLogs"
          >导入记录</el-button
        >
      </el-col>
      <el-col v-if="bankType !== 'enterprise'" :span="1.5">
        <el-button
          type="success"
          plain
          icon="Edit"
          :disabled="single"
          @click="handleUpdate()"
          v-hasPermi="['content:question:edit']"
          >修改</el-button
        >
      </el-col>
      <el-col v-if="bankType !== 'enterprise'" :span="1.5">
        <el-button
          type="danger"
          plain
          icon="Delete"
          :disabled="multiple"
          @click="handleDelete()"
          v-hasPermi="['content:question:remove']"
          >删除</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-collapse v-if="bankType === 'enterprise'" v-model="activePanels" class="company-collapse" @change="handlePanelChange">
      <el-collapse-item v-for="c in companyPanels" :key="c.id" :name="c.id">
        <template #title>
          <div class="company-head">
            <span class="company-name">{{ c.name }}</span>
            <el-tag size="small" type="info" effect="plain">{{ c.total }} 题</el-tag>
            <el-tag v-if="c.c1" size="small" effect="plain">专业题 {{ c.c1 }}</el-tag>
            <el-tag v-if="c.c2" size="small" effect="plain" type="warning">性格 {{ c.c2 }}</el-tag>
            <el-tag v-if="c.c3" size="small" effect="plain" type="success">综合 {{ c.c3 }}</el-tag>
            <el-tag v-if="c.c4" size="small" effect="plain" type="danger">行为 {{ c.c4 }}</el-tag>
            <el-tag v-if="c.c5" size="small" effect="plain" type="info">其他 {{ c.c5 }}</el-tag>
            <el-button class="company-add" size="small" type="primary" link icon="Plus" @click.stop="handleAddForCompany(c)" v-hasPermi="['content:question:add']"
              >新增题目</el-button
            >
          </div>
        </template>
        <el-table v-loading="c.loading" :data="c.items" border size="small">
          <el-table-column label="序号" prop="seq" width="70" align="center" />
          <el-table-column label="题干" prop="content" min-width="260" show-overflow-tooltip />
          <el-table-column label="分类" width="100" align="center">
            <template #default="scope">
              <el-tag size="small" :type="categoryTag(scope.row.category)">{{ categoryLabel(scope.row.category) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="题型" width="90" align="center">
            <template #default="scope">{{ typeLabel(scope.row.type) }}</template>
          </el-table-column>
          <el-table-column label="难度" width="80" align="center">
            <template #default="scope">{{ difficultyLabel(scope.row.difficulty) }}</template>
          </el-table-column>
          <el-table-column label="分值" prop="score" width="80" align="center" />
          <el-table-column label="创建时间" prop="createTime" width="170" align="center" />
          <el-table-column label="操作" width="130" align="center">
            <template #default="scope">
              <el-button link type="primary" @click="handleUpdate(scope.row)" v-hasPermi="['content:question:edit']">编辑</el-button>
              <el-button link type="danger" @click="handleDelete(scope.row)" v-hasPermi="['content:question:remove']">删除</el-button>
            </template>
          </el-table-column>
        </el-table>
        <el-empty v-if="!c.loading && !c.items.length" description="该企业还没有题目" :image-size="56" />
      </el-collapse-item>
    </el-collapse>

    <el-table v-if="bankType !== 'enterprise'" v-loading="loading" :data="questionList" @selection-change="handleSelectionChange" border stripe>
      <el-table-column type="selection" width="50" align="center" />
      <el-table-column label="序号" prop="seq" width="70" align="center" />
      <el-table-column label="题干" prop="content" :show-overflow-tooltip="true" min-width="260" />
      <el-table-column label="分类" width="100" align="center">
        <template #default="scope">
          <el-tag :type="categoryTag(scope.row.category)" effect="light" size="small">{{
            categoryLabel(scope.row.category)
          }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="题型" width="90" align="center">
        <template #default="scope">
          <el-tag :type="typeTag(scope.row.type)">{{ typeLabel(scope.row.type) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="难度" width="80" align="center">
        <template #default="scope">
          <el-tag :type="difficultyTag(scope.row.difficulty)" effect="plain">{{
            difficultyLabel(scope.row.difficulty)
          }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="分值" prop="score" width="80" align="center" />
      <el-table-column label="技能标签" prop="skillTag" width="120" align="center" :show-overflow-tooltip="true" />
      <el-table-column label="所属题库" width="170" align="center" :show-overflow-tooltip="true">
        <template #default="scope">
          <el-tag v-if="!scope.row.companyId" type="success" effect="plain">系统题库</el-tag>
          <el-tag v-else type="warning" effect="plain">{{ scope.row.companyName || '企业 ' + scope.row.companyId }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="解析" width="80" align="center">
        <template #default="scope">
          <el-tag :type="scope.row.analysis ? 'success' : 'info'" effect="plain">{{
            scope.row.analysis ? '已有' : '待补'
          }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="创建时间" prop="createTime" width="165" align="center" />
      <el-table-column label="操作" width="150" align="center" fixed="right">
        <template #default="scope">
          <el-button
            link
            type="primary"
            icon="Edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['content:question:edit']"
            >编辑</el-button
          >
          <el-button
            link
            type="danger"
            icon="Delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['content:question:remove']"
            >删除</el-button
          >
        </template>
      </el-table-column>
    </el-table>

    <pagination
      v-if="bankType !== 'enterprise'"
      v-show="total > 0"
      :total="total"
      v-model:page="queryParams.pageNum"
      v-model:limit="queryParams.pageSize"
      @pagination="getList"
    />
    </el-card>

    <el-dialog :title="title" v-model="open" width="860px" append-to-body>
      <el-form ref="questionRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="题目分类" prop="category">
          <el-radio-group v-model="form.category">
            <el-radio v-for="item in categoryOptions" :key="item.value" :value="item.value">{{ item.label }}</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="题目类型" prop="type">
          <el-radio-group v-model="form.type" @change="handleTypeChange">
            <el-radio v-for="item in typeOptions" :key="item.value" :value="item.value">{{ item.label }}</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="题目内容" prop="content">
          <el-input
            v-model="form.content"
            type="textarea"
            :rows="3"
            placeholder="请输入题干"
            maxlength="1000"
            show-word-limit
          />
        </el-form-item>

        <template v-if="form.type === 1 || form.type === 2">
          <el-form-item
            v-for="(option, index) in form.options"
            :key="index"
            :label="index === 0 ? '选项与答案' : ' '"
          >
            <div class="option-row">
              <span class="option-key">{{ option.key }}</span>
              <el-input v-model="option.text" placeholder="请输入选项内容" class="option-input" />
              <el-radio
                v-if="form.type === 1"
                v-model="form.singleKey"
                :value="option.key"
                @change="handleSingleCorrect(option)"
                >正确答案</el-radio
              >
              <el-checkbox v-else v-model="option.correct">正确答案</el-checkbox>
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

        <el-form-item v-if="form.type === 3" label="正确答案" prop="judgeAnswer">
          <el-radio-group v-model="form.judgeAnswer">
            <el-radio value="对">对</el-radio>
            <el-radio value="错">错</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item v-if="form.type === 4 || form.type === 5" label="参考答案" prop="answer">
          <el-input
            v-model="form.answer"
            type="textarea"
            :rows="4"
            placeholder="请输入参考答案或解题思路"
            maxlength="2000"
            show-word-limit
          />
        </el-form-item>

        <el-row>
          <el-col :span="8">
            <el-form-item label="分值" prop="score">
              <el-input-number v-model="form.score" :min="1" :max="100" :step="1" controls-position="right" style="width: 100%" />
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="难度" prop="difficulty">
              <el-select v-model="form.difficulty" placeholder="请选择难度" style="width: 100%">
                <el-option v-for="item in difficultyOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="技能标签" prop="skillTag">
              <el-input v-model="form.skillTag" placeholder="如 Java基础、算法" maxlength="100" />
            </el-form-item>
          </el-col>
        </el-row>

        <el-form-item v-if="bankType === 'enterprise'" label="所属企业" prop="companyId">
          <el-select v-model="form.companyId" placeholder="请选择企业" filterable style="width: 100%">
            <el-option v-for="item in companyOptions" :key="item.id" :label="item.name" :value="item.id" />
          </el-select>
        </el-form-item>

        <el-form-item label="解析说明" prop="analysis">
          <el-input v-model="form.analysis" type="textarea" :rows="4" placeholder="请输入解析说明（选填）">
            <template #append>
              <el-button :loading="aiLoading" @click="aiExpandAnalysis">
                <el-icon><MagicStick /></el-icon> AI扩写
              </el-button>
            </template>
          </el-input>
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" :loading="submitting" @click="submitForm">确 定</el-button>
          <el-button @click="cancel">取 消</el-button>
        </div>
      </template>
    </el-dialog>

    <el-dialog v-model="importOpen" title="文件导入题库" width="920px" append-to-body :close-on-click-modal="false">
      <el-alert type="info" :closable="false" show-icon style="margin-bottom: 12px">
        <template #title>
          支持 docx / xlsx / xls / csv / txt / md / pdf；可一次选多个文件，也可选整个文件夹（自动跳过 node_modules、dist 等目录）。题目按「1.」「第1题」等题号切分，选项按「A.」「B、」识别，答案/解析按「答案：」「解析：」识别。
        </template>
      </el-alert>
      <div class="import-bar">
        <input ref="fileInputRef" type="file" multiple accept=".docx,.xlsx,.xls,.csv,.txt,.md,.pdf" style="display: none" @change="onFilesPicked" />
        <input ref="dirInputRef" type="file" webkitdirectory directory multiple style="display: none" @change="onFilesPicked" />
        <el-button plain icon="FolderOpened" @click="pickDir">选择文件夹</el-button>
        <el-button plain icon="Document" @click="pickFiles">选择文件</el-button>
        <el-button type="success" plain icon="MagicStick" :disabled="!importItems.length" :loading="classifying" @click="runClassify"
          >AI 识别分类/题型</el-button
        >
        <span class="import-tip">已解析 {{ importItems.length }} 题 / {{ importFiles.length }} 个文件</span>
        <el-select v-if="bankType === 'enterprise'" v-model="importCompanyId" placeholder="导入到企业" filterable style="width: 200px; margin-left: auto">
          <el-option v-for="item in companyOptions" :key="item.id" :label="item.name" :value="item.id" />
        </el-select>
      </div>
      <el-table v-loading="parsing" :data="importItems" height="360" border size="small">
        <el-table-column type="index" width="50" align="center" />
        <el-table-column prop="content" label="题干" min-width="260" show-overflow-tooltip />
        <el-table-column label="分类" width="118">
          <template #default="scope">
            <el-select v-model="scope.row.category" size="small">
              <el-option v-for="c in categoryOptions" :key="c.value" :label="c.label" :value="c.value" />
            </el-select>
          </template>
        </el-table-column>
        <el-table-column label="题型" width="112">
          <template #default="scope">
            <el-select v-model="scope.row.type" size="small">
              <el-option v-for="t in typeOptions" :key="t.value" :label="t.label" :value="t.value" />
            </el-select>
          </template>
        </el-table-column>
        <el-table-column label="难度" width="104">
          <template #default="scope">
            <el-select v-model="scope.row.difficulty" size="small">
              <el-option v-for="d in difficultyOptions" :key="d.value" :label="d.label" :value="d.value" />
            </el-select>
          </template>
        </el-table-column>
        <el-table-column label="分值" width="90">
          <template #default="scope">
            <el-input v-model="scope.row.score" size="small" />
          </template>
        </el-table-column>
        <el-table-column prop="source" label="来源文件" width="150" show-overflow-tooltip />
        <el-table-column prop="answer" label="答案" width="90" show-overflow-tooltip />
      </el-table>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" :loading="importing" :disabled="!importItems.length" @click="submitImport"
            >导入 {{ importItems.length }} 题</el-button
          >
          <el-button @click="importOpen = false">取 消</el-button>
        </div>
      </template>
    </el-dialog>

    <el-dialog v-model="logOpen" title="导入记录" width="960px" append-to-body>
      <el-table :data="logRows" v-loading="logLoading" size="small" max-height="460">
        <el-table-column label="时间" prop="createTime" width="160" />
        <el-table-column label="类型" width="100">
          <template #default="scope">
            <el-tag :type="scope.row.type === 1 ? 'warning' : 'success'" size="small">
              {{ scope.row.type === 1 ? '文件导入' : '单条新增' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="文件" min-width="170" show-overflow-tooltip>
          <template #default="scope">{{ scope.row.fileName || '—' }}</template>
        </el-table-column>
        <el-table-column label="题库" width="150" show-overflow-tooltip>
          <template #default="scope">{{ scope.row.companyName || '系统题库' }}</template>
        </el-table-column>
        <el-table-column label="成功/提交" width="100" align="center">
          <template #default="scope">{{ scope.row.inserted }}/{{ scope.row.total }}</template>
        </el-table-column>
        <el-table-column label="操作人" prop="operator" width="110" show-overflow-tooltip />
        <el-table-column label="状态" width="90" align="center">
          <template #default="scope">
            <el-tag :type="scope.row.status === 0 ? 'success' : 'info'" size="small">
              {{ scope.row.status === 0 ? '正常' : '已撤销' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="90" align="center">
          <template #default="scope">
            <el-button
              link
              type="danger"
              size="small"
              :disabled="scope.row.status === 1 || !scope.row.inserted"
              @click="handleUndo(scope.row)"
              >撤销</el-button
            >
          </template>
        </el-table-column>
      </el-table>
      <el-pagination
        v-model:current-page="logQuery.pageNum"
        :page-size="logQuery.pageSize"
        :total="logTotal"
        layout="total, prev, pager, next"
        class="mt10"
        @current-change="loadLogs"
      />
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="logOpen = false">关 闭</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="Question">
import { listExamQuestion, getExamQuestion, addExamQuestion, updateExamQuestion, delExamQuestion, listExamCompany, getExamStats, parseExamQuestionFiles, classifyExamQuestions, batchAddExamQuestions, getCompanyOverview, listImportLogs, undoImportBatch } from '@/api/content/examQuestion'
import { MagicStick } from '@element-plus/icons-vue'
import request from '@/utils/request'
import { useRoute } from 'vue-router'

const { proxy } = getCurrentInstance()
const route = useRoute()

/** 题库类型由菜单路由决定：/question/system 系统题库，/question/enterprise 企业题库 */
const bankType = computed(() =>
  route.path.includes('enterprise') || route.query.bankType === 'enterprise' ? 'enterprise' : 'platform'
)

/** 企业下拉数据，用于企业题库的归属筛选与选择 */
const companyOptions = ref([])

const typeOptions = [
  { value: 1, label: '单选' },
  { value: 2, label: '多选' },
  { value: 3, label: '判断' },
  { value: 4, label: '简答' },
  { value: 5, label: '编程' }
]
const difficultyOptions = [
  { value: 1, label: '简单' },
  { value: 2, label: '中等' },
  { value: 3, label: '困难' }
]
/** 题目分类：专业题（技能面）、性格测试（人格/职业倾向）、综合能力（行测类）、行为面试（BQ 情景）、其他 */
const categoryOptions = [
  { value: 1, label: '专业题' },
  { value: 2, label: '性格测试' },
  { value: 3, label: '综合能力' },
  { value: 4, label: '行为面试' },
  { value: 5, label: '其他' }
]
const optionLetters = ['A', 'B', 'C', 'D', 'E', 'F']

/** 文件导入状态 */
const importOpen = ref(false)
const importItems = ref([])
const importFiles = ref([])
const importCompanyId = ref(null)
const parsing = ref(false)
const classifying = ref(false)
const importing = ref(false)

/** 企业题库折叠面板 */
const companyPanels = ref([])
const activePanels = ref([])

/** 文件导入的原生 input 引用 */
const fileInputRef = ref(null)
const dirInputRef = ref(null)

const questionList = ref([])
const open = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const ids = ref([])
const single = ref(true)
const multiple = ref(true)
const total = ref(0)
const title = ref('')
const submitting = ref(false)
const aiLoading = ref(false)
/** 顶部统计：total 为当前题库题目总数，category 为各分类数量 */
const stats = ref({ total: 0, category: {} })

const data = reactive({
  form: {},
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    bankType: 'platform',
    category: undefined,
    keyword: undefined,
    type: undefined,
    difficulty: undefined,
    companyId: undefined
  },
  rules: {
    category: [{ required: true, message: '请选择题目分类', trigger: 'change' }],
    type: [{ required: true, message: '请选择题目类型', trigger: 'change' }],
    content: [{ required: true, message: '题目内容不能为空', trigger: 'blur' }],
    score: [{ required: true, message: '分值不能为空', trigger: 'blur' }]
  }
})

const { form, queryParams, rules } = toRefs(data)

function typeLabel(v) {
  const found = typeOptions.find((o) => o.value === Number(v))
  return found ? found.label : v
}
function typeTag(v) {
  return { 1: 'primary', 2: 'success', 3: 'warning', 4: 'info', 5: 'danger' }[Number(v)] || 'info'
}
function difficultyLabel(v) {
  const found = difficultyOptions.find((o) => o.value === Number(v))
  return found ? found.label : v
}
function difficultyTag(v) {
  return { 1: 'success', 2: 'warning', 3: 'danger' }[Number(v)] || 'info'
}
function categoryLabel(v) {
  const found = categoryOptions.find((o) => o.value === Number(v))
  return found ? found.label : '其他'
}
function categoryTag(v) {
  return { 1: 'primary', 2: 'success', 3: 'warning', 4: 'danger', 5: 'info' }[Number(v)] || 'info'
}

/** 加载企业下拉 */
function loadCompanies() {
  listExamCompany()
    .then((response) => {
      companyOptions.value = response.data || []
    })
    .catch((err) => {
      console.error('加载企业列表失败:', err)
    })
}

/** 顶部各分类统计（按当前题库与企业筛选口径） */
function loadStats() {
  getExamStats({ bankType: bankType.value, companyId: queryParams.value.companyId })
    .then((response) => {
      const rows = response.data || []
      let total = 0
      const map = {}
      rows.forEach((r) => {
        const c = Number(r.category) || 5
        const n = Number(r.cnt) || 0
        map[c] = n
        total += n
      })
      stats.value = { total, category: map }
    })
    .catch((err) => {
      console.error('加载分类统计失败:', err)
    })
}

/** 企业题库总览：每个企业的题量与分类分布，作为折叠面板数据源 */
function loadCompanyOverview() {
  if (bankType.value !== 'enterprise') return
  const keepActive = activePanels.value.slice()
  getCompanyOverview()
    .then((response) => {
      const rows = response.data || []
      companyPanels.value = rows.map((r) => ({
        id: r.id,
        name: r.name,
        total: Number(r.total) || 0,
        c1: Number(r.c1) || 0,
        c2: Number(r.c2) || 0,
        c3: Number(r.c3) || 0,
        c4: Number(r.c4) || 0,
        c5: Number(r.c5) || 0,
        items: [],
        loading: false,
        loaded: false
      }))
      nextTick(() => handlePanelChange(keepActive))
    })
    .catch((err) => {
      console.error('加载企业题库总览失败:', err)
    })
}

/** 展开某个企业面板时懒加载该企业题目 */
function handlePanelChange(names) {
  names.forEach((id) => {
    const panel = companyPanels.value.find((p) => p.id === id)
    if (panel && !panel.loaded && !panel.loading) {
      loadCompanyQuestions(panel)
    }
  })
}

function loadCompanyQuestions(panel) {
  panel.loading = true
  listExamQuestion({ bankType: 'enterprise', companyId: panel.id, pageNum: 1, pageSize: 200 })
    .then((response) => {
      const rows = response.rows || []
      // 企业内同样按倒序给全局序号：企业题目总数即最大序号
      panel.items = rows.map((r, i) => ({ ...r, seq: rows.length - i }))
      panel.loaded = true
    })
    .catch((err) => {
      console.error('加载企业题目失败:', err)
    })
    .finally(() => {
      panel.loading = false
    })
}

/** 在企业面板内新增题目：沿用新增弹窗并把企业预设为该企业 */
function handleAddForCompany(panel) {
  handleAdd()
  form.value.companyId = panel.id
}

/** 点击统计卡快速按分类筛选 */
function quickCategory(c) {
  queryParams.value.category = c || undefined
  queryParams.value.pageNum = 1
  getList()
}

/** 查询列表 */
function getList() {
  queryParams.value.bankType = bankType.value
  loadStats()
  if (bankType.value === 'enterprise') {
    loading.value = false
    loadCompanyOverview()
    return
  }
  loading.value = true
  listExamQuestion(queryParams.value)
    .then((response) => {
      const rows = response.rows || []
      total.value = response.total
      // 序号按「倒序排列下的全局位置」计算：最新一条 = 当前总数，逐条递减，跨页连续
      const offset = (queryParams.value.pageNum - 1) * queryParams.value.pageSize
      questionList.value = rows.map((r, i) => ({ ...r, seq: total.value - offset - i }))
      loading.value = false
    })
    .catch((err) => {
      console.error('查询题库列表失败:', err)
      loading.value = false
    })
}

function handleQuery() {
  queryParams.value.pageNum = 1
  getList()
}

function resetQuery() {
  proxy.resetForm('queryRef')
  queryParams.value.keyword = undefined
  queryParams.value.category = undefined
  queryParams.value.type = undefined
  queryParams.value.difficulty = undefined
  queryParams.value.companyId = undefined
  handleQuery()
}

function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.id)
  single.value = selection.length !== 1
  multiple.value = !selection.length
}

/** 重置表单 */
function reset() {
  form.value = {
    id: undefined,
    category: queryParams.value.category || 1,
    type: 1,
    content: undefined,
    options: [
      { key: 'A', text: '', correct: false },
      { key: 'B', text: '', correct: false }
    ],
    singleKey: undefined,
    judgeAnswer: '对',
    answer: undefined,
    analysis: undefined,
    score: 5,
    difficulty: 1,
    skillTag: undefined,
    companyId: undefined
  }
  proxy.resetForm('questionRef')
}

function handleAdd() {
  reset()
  open.value = true
  title.value = bankType.value === 'enterprise' ? '新增企业题目' : '新增系统题目'
}

function handleUpdate(row) {
  reset()
  const id = row ? row.id : ids.value[0]
  if (!id) {
    return
  }
  getExamQuestion(id)
    .then((response) => {
      const d = response.data || {}
      form.value.id = d.id
      form.value.category = Number(d.category) || 1
      form.value.type = Number(d.type) || 1
      form.value.content = d.content
      form.value.analysis = d.analysis
      form.value.score = d.score !== null && d.score !== undefined ? Number(d.score) : 5
      form.value.difficulty = Number(d.difficulty) || 1
      form.value.skillTag = d.skillTag
      form.value.companyId = d.companyId
      form.value.judgeAnswer = d.answer === '错' ? '错' : '对'
      form.value.answer = d.answer
      // 选项回填
      let opts = []
      if (d.optionsJson) {
        try {
          const parsed = typeof d.optionsJson === 'string' ? JSON.parse(d.optionsJson) : d.optionsJson
          if (Array.isArray(parsed)) {
            opts = parsed.map((text, i) => ({ key: optionLetters[i], text: String(text), correct: false }))
          }
        } catch (e) {
          opts = []
        }
      }
      if (opts.length === 0) {
        opts = [
          { key: 'A', text: '', correct: false },
          { key: 'B', text: '', correct: false }
        ]
      }
      const ans = (d.answer || '').toUpperCase()
      if (form.value.type === 1) {
        form.value.singleKey = ans
        opts.forEach((o) => (o.correct = o.key === ans))
      } else if (form.value.type === 2) {
        opts.forEach((o) => (o.correct = ans.includes(o.key)))
      }
      form.value.options = opts
      open.value = true
      title.value = '修改题目'
    })
    .catch((err) => {
      console.error('查询题目详情失败:', err)
    })
}

/** 组装提交数据 */
function buildPayload() {
  const f = form.value
  const payload = {
    id: f.id,
    category: f.category,
    type: f.type,
    typeName: typeLabel(f.type),
    content: f.content,
    analysis: f.analysis,
    score: f.score,
    difficulty: f.difficulty,
    skillTag: f.skillTag,
    companyId: bankType.value === 'enterprise' ? f.companyId : null
  }
  if (f.type === 1 || f.type === 2) {
    payload.options = f.options.map((o) => o.text)
    payload.answer =
      f.type === 1 ? f.options.find((o) => o.correct)?.key || '' : f.options.filter((o) => o.correct).map((o) => o.key).join('')
  } else if (f.type === 3) {
    payload.answer = f.judgeAnswer
  } else {
    payload.answer = f.answer
  }
  return payload
}

function submitForm() {
  proxy.$refs['questionRef'].validate((valid) => {
    if (!valid) {
      return
    }
    const payload = buildPayload()
    if (bankType.value === 'enterprise' && !payload.companyId) {
      proxy.$modal.msgWarning('企业自定义题库必须选择所属企业')
      return
    }
    if ((payload.type === 1 || payload.type === 2) && !payload.answer) {
      proxy.$modal.msgWarning('请设置正确答案')
      return
    }
    if ((payload.type === 3 || payload.type === 4 || payload.type === 5) && !payload.answer) {
      proxy.$modal.msgWarning('请填写正确答案')
      return
    }
    submitting.value = true
    const done = () => {
      submitting.value = false
      open.value = false
      getList()
    }
    const req = payload.id !== undefined ? updateExamQuestion(payload) : addExamQuestion(payload)
    req
      .then(() => {
        proxy.$modal.msgSuccess(payload.id !== undefined ? '修改成功' : '新增成功')
        done()
      })
      .catch((err) => {
        submitting.value = false
        console.error('保存题目失败:', err)
      })
  })
}

function cancel() {
  open.value = false
  reset()
}

function handleDelete(row) {
  const delIds = row ? [row.id] : ids.value
  proxy.$modal
    .confirm('是否确认删除选中的 ' + delIds.length + ' 道题目？')
    .then(() => delExamQuestion(delIds))
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(() => {})
}

/** 题型切换 */
function handleTypeChange() {
  const t = form.value.type
  if (t === 1 || t === 2) {
    if (!form.value.options || form.value.options.length < 2) {
      form.value.options = [
        { key: 'A', text: '', correct: false },
        { key: 'B', text: '', correct: false }
      ]
    }
  }
}

function handleAddOption() {
  if (form.value.options.length < 6) {
    const idx = form.value.options.length
    form.value.options.push({ key: optionLetters[idx], text: '', correct: false })
  }
}

function handleRemoveOption(index) {
  if (form.value.options.length <= 2) {
    proxy.$modal.msgWarning('至少保留2个选项')
    return
  }
  form.value.options.splice(index, 1)
  form.value.options.forEach((o, i) => (o.key = optionLetters[i]))
}

function handleSingleCorrect(option) {
  form.value.options.forEach((o) => (o.correct = o === option))
}

/** AI 扩写解析：调用后台 AI 助手接口 */
async function aiExpandAnalysis() {
  const f = form.value
  if (!f.content) {
    proxy.$modal.msgWarning('请先填写题目内容')
    return
  }
  aiLoading.value = true
  try {
    const optionText = (f.options || [])
      .filter((o) => o.text)
      .map((o) => o.key + '. ' + o.text)
      .join('；')
    const answerText =
      f.type === 1
        ? f.options.find((o) => o.correct)?.key || ''
        : f.type === 2
          ? f.options.filter((o) => o.correct).map((o) => o.key).join('')
          : f.type === 3
            ? f.judgeAnswer
            : f.answer || ''
    const prompt =
      '请为下面这道' + typeLabel(f.type) + '题写一段解析，150字以内，包含考查知识点、解题思路和易错点。只输出解析正文，不要标题、不要重复题目。\n' +
      '题目：' + f.content +
      (optionText ? '\n选项：' + optionText : '') +
      (answerText ? '\n正确答案：' + answerText : '')
    const res = await request({ url: '/ai/assistant/chat', method: 'post', data: { message: prompt } })
    const answer = res?.data?.answer || res?.answer || ''
    if (!answer) {
      proxy.$modal.msgWarning('AI 未返回内容，请稍后重试')
      return
    }
    f.analysis = answer.trim()
    proxy.$modal.msgSuccess('AI 扩写完成')
  } catch (e) {
    console.error('AI 扩写失败:', e)
    proxy.$modal.msgError('AI 扩写失败，请检查 AI 模型配置')
  } finally {
    aiLoading.value = false
  }
}

/** 打开导入弹窗 */
function openImport() {
  importOpen.value = true
  importItems.value = []
  importFiles.value = []
  importCompanyId.value = bankType.value === 'enterprise' ? queryParams.value.companyId || null : null
}

function pickFiles() {
  const el = fileInputRef.value
  if (!el) return
  el.value = ''
  el.click()
}

function pickDir() {
  const el = dirInputRef.value
  if (!el) return
  el.value = ''
  el.click()
}

/** 单次导入上限：文件数、总大小、每批上传数 */
const IMPORT_MAX_FILES = 60
const IMPORT_MAX_SIZE = 50 * 1024 * 1024
const IMPORT_BATCH = 8

/** 选中文件或文件夹后统一提交解析（分批上传，避免单请求过大超时） */
async function onFilesPicked(e) {
  const picked = Array.from(e.target.files || [])
  if (!picked.length) return
  e.target.value = ''
  const allowed = ['.docx', '.xlsx', '.xls', '.csv', '.txt', '.md', '.pdf']
  const junkDir = /(^|\/)(node_modules|\.git|dist|build|target|\.idea|\.vscode|coverage|__pycache__)(\/|$)/i
  let valid = picked
    .filter((f) => allowed.some((ext) => f.name.toLowerCase().endsWith(ext)))
    .filter((f) => !junkDir.test(f.webkitRelativePath || ''))
  if (!valid.length) {
    proxy.$modal.msgWarning('未找到可解析的文件（支持 docx/xlsx/xls/csv/txt/md/pdf）')
    return
  }
  if (valid.length > IMPORT_MAX_FILES) {
    valid = valid.slice(0, IMPORT_MAX_FILES)
    proxy.$modal.msgWarning(`单次最多 ${IMPORT_MAX_FILES} 个文件，已取前 ${IMPORT_MAX_FILES} 个`)
  }
  const accepted = []
  let size = 0
  for (const f of valid) {
    if (size + f.size > IMPORT_MAX_SIZE) break
    accepted.push(f)
    size += f.size
  }
  if (accepted.length < valid.length) {
    proxy.$modal.msgWarning(`总大小超过 50MB，已保留前 ${accepted.length} 个文件`)
  }
  parsing.value = true
  try {
    const allItems = []
    const allFiles = []
    for (let i = 0; i < accepted.length; i += IMPORT_BATCH) {
      const fd = new FormData()
      accepted.slice(i, i + IMPORT_BATCH).forEach((f) => fd.append('files', f))
      const res = await parseExamQuestionFiles(fd)
      const data = res?.data || res
      allItems.push(...(data?.items || []))
      allFiles.push(...(data?.files || []))
    }
    importItems.value = allItems.map((it) => ({
      content: it.content,
      options: it.options || [],
      answer: it.answer || '',
      analysis: it.analysis || '',
      score: it.score,
      type: it.type,
      typeName: it.typeName,
      category: it.category,
      difficulty: it.difficulty,
      source: it.source
    }))
    importFiles.value = allFiles
    const failed = allFiles.filter((f) => f.status !== 'ok')
    if (failed.length) {
      proxy.$modal.msgWarning(`${failed.length} 个文件解析失败：${failed.map((f) => f.name).slice(0, 3).join('、')}（其余已正常解析）`)
    } else if (!allItems.length) {
      proxy.$modal.msgWarning('未解析出题目，请确认文件中的题号格式（如「1.」「第1题」）')
    } else {
      proxy.$modal.msgSuccess(`解析完成，共 ${importItems.value.length} 题`)
    }
  } catch (err) {
    proxy.$modal.msgError('文件解析失败：' + (err?.message || '请检查文件格式或大小'))
  } finally {
    parsing.value = false
  }
}

/** AI 批量校正分类/题型/难度 */
async function runClassify() {
  if (!importItems.value.length) return
  classifying.value = true
  try {
    const payload = importItems.value.map((it) => ({
      content: it.content,
      options: it.options,
      answer: it.answer
    }))
    const res = await classifyExamQuestions(payload)
    const rows = res?.data || res || []
    let hit = 0
    rows.forEach((r) => {
      const idx = r.index
      if (idx >= 0 && idx < importItems.value.length) {
        if (r.category) importItems.value[idx].category = r.category
        if (r.type) {
          importItems.value[idx].type = r.type
          importItems.value[idx].typeName = r.typeName
        }
        if (r.difficulty) importItems.value[idx].difficulty = r.difficulty
        hit++
      }
    })
    proxy.$modal.msgSuccess(`AI 已识别 ${hit} 题，可继续手工调整`)
  } catch (err) {
    proxy.$modal.msgError('AI 识别失败，保留规则识别结果：' + (err?.message || ''))
  } finally {
    classifying.value = false
  }
}

/** 批量入库 */
async function submitImport() {
  if (!importItems.value.length) return
  if (bankType.value === 'enterprise' && !importCompanyId.value) {
    proxy.$modal.msgWarning('请先选择导入的企业')
    return
  }
  importing.value = true
  try {
    const sources = [...new Set(importItems.value.map((i) => i.source).filter(Boolean))]
    const res = await batchAddExamQuestions({
      bankType: bankType.value,
      companyId: importCompanyId.value,
      fileName: sources.join(', ').slice(0, 255) || null,
      items: importItems.value
    })
    const data = res?.data || res || {}
    if (data.failed) {
      proxy.$modal.msgWarning(`成功 ${data.inserted} 条，失败 ${data.failed} 条：${(data.errors || []).slice(0, 3).join('；')}`)
    } else {
      proxy.$modal.msgSuccess(`导入成功 ${data.inserted} 条`)
    }
    importOpen.value = false
    getList()
    loadStats()
  } catch (err) {
    proxy.$modal.msgError('导入失败：' + (err?.message || ''))
  } finally {
    importing.value = false
  }
}

/** 导入记录 */
const logOpen = ref(false)
const logLoading = ref(false)
const logRows = ref([])
const logTotal = ref(0)
const logQuery = reactive({ pageNum: 1, pageSize: 10 })

function openImportLogs() {
  logOpen.value = true
  logQuery.pageNum = 1
  loadLogs()
}

async function loadLogs() {
  logLoading.value = true
  try {
    const res = await listImportLogs(logQuery)
    const data = res?.data || res || {}
    logRows.value = data.rows || []
    logTotal.value = data.total || 0
  } catch (err) {
    proxy.$modal.msgError('加载导入记录失败：' + (err?.message || ''))
  } finally {
    logLoading.value = false
  }
}

async function handleUndo(row) {
  const tip = `确认撤销这条记录？将删除本批导入且未被考卷引用的 ${row.inserted} 道题，已被考卷引用的题会保留。`
  try {
    await proxy.$modal.confirm(tip)
  } catch (e) {
    return
  }
  try {
    const res = await undoImportBatch(row.id)
    const data = res?.data || res || {}
    let msg = `已撤销：删除 ${data.deleted || 0} 题`
    if (data.skipped) msg += `，保留 ${data.skipped} 题（已删除或被考卷引用）`
    proxy.$modal.msgSuccess(msg)
    loadLogs()
    getList()
    loadStats()
  } catch (err) {
    proxy.$modal.msgError('撤销失败：' + (err?.message || ''))
  }
}

getList()
loadCompanies()
</script>

<style lang="scss" scoped>
.company-collapse {
  margin-top: 4px;

  .company-head {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;

    .company-name {
      font-weight: 600;
      font-size: 14px;
      color: #303133;
      min-width: 180px;
    }

    .company-add {
      margin-left: auto;
      margin-right: 12px;
    }
  }
}
.import-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;

  .import-tip {
    font-size: 13px;
    color: #909399;
  }
}
</style>

<style lang="scss" scoped>
.stat-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(112px, 1fr));
  gap: 12px;
  margin-bottom: 15px;
}
.stat-card {
  background: #fff;
  border-radius: 10px;
  padding: 18px 20px;
  box-shadow: 0 2px 10px rgba(72, 47, 105, 0.05);
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  border-left: 4px solid transparent;
}
.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 18px rgba(72, 47, 105, 0.1);
}
.stat-card.active {
  box-shadow: 0 6px 18px rgba(47, 128, 237, 0.18);
  border-bottom: 2px solid #2f80ed;
}
.stat-num {
  font-size: 26px;
  font-weight: 700;
  line-height: 1.2;
}
.stat-label {
  color: #86909c;
  font-size: 13px;
  margin-top: 4px;
}
.stat-total {
  border-left-color: #2f80ed;
}
.stat-total .stat-num {
  color: #2f80ed;
}
.stat-pro {
  border-left-color: #0ea5e9;
}
.stat-pro .stat-num {
  color: #0ea5e9;
}
.stat-person {
  border-left-color: #22c55e;
}
.stat-person .stat-num {
  color: #22c55e;
}
.stat-general {
  border-left-color: #f59e0b;
}
.stat-general .stat-num {
  color: #f59e0b;
}
.stat-behavior {
  border-left-color: #ef4444;
}
.stat-behavior .stat-num {
  color: #ef4444;
}
.stat-other {
  border-left-color: #94a3b8;
}
.stat-other .stat-num {
  color: #94a3b8;
}
.search-card {
  margin-bottom: 15px;
}
.table-card {
  min-height: 400px;
}
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
