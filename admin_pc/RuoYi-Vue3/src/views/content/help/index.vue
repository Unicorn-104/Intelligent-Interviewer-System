<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="标题" prop="title">
        <el-input
          v-model="queryParams.title"
          placeholder="请输入文章标题"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="分类" prop="categoryName">
        <el-select v-model="queryParams.categoryName" placeholder="请选择分类" clearable style="width: 200px">
          <el-option v-for="item in categoryOptions" :key="item" :label="item" :value="item" />
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
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['content:help:add']"
          >新增文章</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="helpList">
      <el-table-column label="编号" align="center" prop="articleId" width="80" />
      <el-table-column label="分类" align="center" width="120">
        <template #default="scope">
          <el-tag>{{ scope.row.categoryName }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="标题" align="center" prop="title" :show-overflow-tooltip="true" />
      <el-table-column label="摘要" align="center" prop="summary" :show-overflow-tooltip="true" />
      <el-table-column label="浏览量" align="center" prop="views" width="100" />
      <el-table-column label="有用数" align="center" prop="usefulCount" width="100" />
      <el-table-column label="状态" align="center" width="100">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="更新人" align="center" prop="updateBy" width="110" />
      <el-table-column label="更新时间" align="center" prop="updateTime" width="170" />
      <el-table-column label="操作" align="center" width="150" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['content:help:edit']"
            >修改</el-button
          >
          <el-button
            link
            type="primary"
            icon="Delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['content:help:remove']"
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

    <!-- 添加或修改帮助文章对话框 -->
    <el-dialog :title="title" v-model="open" width="700px" append-to-body>
      <el-form ref="helpRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="分类" prop="categoryName">
          <el-select v-model="form.categoryName" placeholder="请选择分类" style="width: 100%">
            <el-option v-for="item in categoryOptions" :key="item" :label="item" :value="item" />
          </el-select>
        </el-form-item>
        <el-form-item label="标题" prop="title">
          <el-input v-model="form.title" placeholder="请输入文章标题" />
        </el-form-item>
        <el-form-item label="摘要" prop="summary">
          <el-input v-model="form.summary" type="textarea" :rows="3" placeholder="请输入文章摘要" />
        </el-form-item>
        <el-form-item label="正文内容" prop="content">
          <el-input v-model="form.content" type="textarea" :rows="6" placeholder="请输入正文内容" />
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

<script setup name="Help">
import { listHelp, getHelp, addHelp, updateHelp, delHelp } from '@/api/content/help'

const { proxy } = getCurrentInstance()

const helpList = ref([])
const open = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const title = ref('')
const ids = ref([])

// 文章分类选项
const categoryOptions = ['新手指引', '账号安全', '简历管理', '面试指南', '企业端帮助']

// 状态选项
const statusOptions = [
  { value: '0', label: '已发布', tag: 'success' },
  { value: '1', label: '已下架', tag: 'info' }
]

const data = reactive({
  form: {
    articleId: undefined,
    categoryName: undefined,
    title: undefined,
    summary: undefined,
    content: undefined
  },
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    title: undefined,
    categoryName: undefined,
    status: undefined
  },
  rules: {
    categoryName: [{ required: true, message: '文章分类不能为空', trigger: 'change' }],
    title: [{ required: true, message: '文章标题不能为空', trigger: 'blur' }]
  }
})

const { form, queryParams } = toRefs(data)

/**
 查询帮助文章列表 */
function getList() {
  loading.value = true

  listHelp(data.queryParams)
    .then((response) => {
      helpList.value = response.rows
      total.value = response.total
      loading.value = false
    })
    .catch((err) => {
      console.error('查询帮助文章列表失败:', err)
      loading.value = false
    })
}

/** 搜索按钮操作 */
function handleQuery() {
  data.queryParams.pageNum = 1
  getList()
}

/** 重置按钮操作 */
function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}

/** 新增按钮操作 */
function handleAdd() {
  reset()
  open.value = true
  title.value = '添加帮助文章'
}

/** 修改按钮操作 */
function handleUpdate(row) {
  reset()
  const articleId = row.articleId || data.form.articleId
  getHelp(articleId)
    .then((response) => {
      data.form = response.data
      open.value = true
      title.value = '修改帮助文章'
    })
    .catch((err) => {
      console.error('查询帮助文章详情失败:', err)
    })
}

/** 表单重置 */
function reset() {
  data.form = {
    articleId: undefined,
    categoryName: undefined,
    title: undefined,
    summary: undefined,
    content: undefined
  }
  proxy.resetForm('helpRef')
}

/** 提交按钮 */
function submitForm() {
  proxy.$refs['helpRef'].validate((valid) => {
    if (valid) {
      if (data.form.articleId != undefined) {
        updateHelp(data.form)
          .then(() => {
            proxy.$modal.msgSuccess('修改成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error('修改帮助文章失败:', err)
          })
      } else {
        addHelp(data.form)
          .then(() => {
            proxy.$modal.msgSuccess('新增成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error('新增帮助文章失败:', err)
          })
      }
    }
  })
}

/** 删除按钮操作 */
function handleDelete(row) {
  const articleIds = row.articleId || ids.value
  proxy.$modal
    .confirm('是否确认删除帮助文章编号为"' + articleIds + '"的数据项？')
    .then(function () {
      return delHelp(articleIds)
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(() => {})
}

// Status helpers
function statusLabel(val) {
  const item = statusOptions.find((o) => o.value === val)
  return item ? item.label : val
}
function statusTag(val) {
  const item = statusOptions.find((o) => o.value === val)
  return item && item.tag ? item.tag : undefined
}

getList()
</script>
