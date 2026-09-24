<template>
  <div class="app-container">
    <el-row :gutter="16">
      <!-- 左侧：分类列表 -->
      <el-col :span="14">
        <el-card shadow="never" class="list-card">
          <template #header>
            <div class="card-header">
              <span class="card-title">分类列表</span>
              <div class="card-actions">
                <el-input
                  v-model="filterName"
                  placeholder="请输入分类名称"
                  clearable
                  style="width: 150px"
                  prefix-icon="Search"
                />
                <el-button type="info" plain icon="Sort">排序</el-button>
              </div>
            </div>
          </template>
          <el-table
            v-if="refreshTable"
            v-loading="loading"
            ref="categoryTableRef"
            :data="categoryTree"
            row-key="categoryId"
            :default-expand-all="isExpandAll"
            :tree-props="{ children: 'children', hasChildren: 'hasChildren' }"
            highlight-current-row
            @row-click="handleRowClick"
          >
            <el-table-column prop="categoryName" label="分类名称" :show-overflow-tooltip="true"></el-table-column>
            <el-table-column prop="orderNum" label="排序" width="70" align="center"></el-table-column>
            <el-table-column prop="jobCount" label="关联职位数" width="100" align="center"></el-table-column>
            <el-table-column label="状态" width="80" align="center">
              <template #default="scope">
                <el-tag :type="scope.row.status == '0' ? 'success' : 'danger'">{{
                  scope.row.status == '0' ? '正常' : '停用'
                }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="190" align="center" class-name="small-padding fixed-width">
              <template #default="scope">
                <el-button
                  v-if="canAddChild(scope.row)"
                  link
                  type="primary"
                  icon="Plus"
                  @click="handleAddChild(scope.row)"
                  v-hasPermi="['content:category:add']"
                  >新增</el-button
                >
                <el-button
                  link
                  type="primary"
                  icon="Edit"
                  @click="handleRowClick(scope.row)"
                  v-hasPermi="['content:category:edit']"
                  >修改</el-button
                >
                <el-button
                  link
                  type="primary"
                  icon="Delete"
                  @click="handleDelete(scope.row)"
                  v-hasPermi="['content:category:remove']"
                  >删除</el-button
                >
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
      <!-- 右侧：分类详情 -->
      <el-col :span="10">
        <el-card shadow="never" class="form-card">
          <template #header>
            <div class="card-header">
              <span class="card-title">分类详情</span>
              <el-button type="primary" plain icon="Plus" @click="handleAddTop" v-hasPermi="['content:category:add']"
                >新增顶级分类</el-button
              >
            </div>
          </template>
          <el-form ref="categoryRef" :model="form" :rules="rules" label-width="90px">
            <el-form-item label="上级分类" prop="parentId">
              <el-select
                v-model="form.parentId"
                placeholder="请选择上级分类"
                style="width: 100%"
                :disabled="form.categoryId != undefined"
              >
                <el-option label="顶级分类" :value="0"></el-option>
                <el-option
                  v-for="item in parentOptions"
                  :key="item.categoryId"
                  :label="item.categoryName"
                  :value="item.categoryId"
                ></el-option>
              </el-select>
            </el-form-item>
            <el-form-item label="分类名称" prop="categoryName">
              <el-input v-model="form.categoryName" placeholder="请输入分类名称" maxlength="50" />
            </el-form-item>
            <el-form-item label="排序" prop="orderNum">
              <el-input-number v-model="form.orderNum" controls-position="right" :min="0" style="width: 160px" />
            </el-form-item>
            <el-form-item label="状态">
              <el-radio-group v-model="form.status">
                <el-radio value="0">正常</el-radio>
                <el-radio value="1">停用</el-radio>
              </el-radio-group>
            </el-form-item>
            <el-form-item label="关联职位数">
              <el-input v-model="form.jobCount" disabled placeholder="暂无关联职位" />
            </el-form-item>
          </el-form>
          <div class="form-footer">
            <el-button type="primary" icon="Check" @click="submitForm">保 存</el-button>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup name="Category">
import { listCategory, getCategory, addCategory, updateCategory, delCategory } from '@/api/content/category'

const { proxy } = getCurrentInstance()

const categoryList = ref([])
const loading = ref(true)
const isExpandAll = ref(true)
const refreshTable = ref(true)
const filterName = ref('')
const categoryTableRef = ref(null)
let loadSeq = 0
let listInited = false

const categoryTree = ref([])
const open = ref(false)
const title = ref('')
const parentOptions = ref([])

const form = ref({})
const rules = {
  parentId: [{ required: true, message: '上级分类不能为空', trigger: 'change' }],
  categoryName: [{ required: true, message: '分类名称不能为空', trigger: 'blur' }]
}

/** 查询参数 */
const queryParams = reactive({
  pageNum: 1,
  pageSize: 10,
  categoryName: undefined,
  status: undefined
})

/** 查询分类列表 */
function getList() {
  loading.value = true
  const seq = ++loadSeq
  listCategory(queryParams)
    .then((response) => {
      if (seq !== loadSeq) return
      const payload = response?.data
      categoryTree.value = Array.isArray(payload) ? payload : payload?.rows || response?.rows || []
      loading.value = false
    })
    .catch((err) => {
      console.error('查询分类列表失败:', err)
      loading.value = false
    })
}

/** 展开/折叠 */
function toggleExpandAll() {
  isExpandAll.value = !isExpandAll.value
}

/** 行单击事件 */
function handleRowClick(row) {
  categoryTableRef.value?.setCurrentRow(row)
  form.value = { ...row }
  parentOptions.value = buildParentOptions(categoryTree.value, row.categoryId)
}

/** 递归构建父级选项 */
function buildParentOptions(list, excludeId) {
  const options = []
  for (const item of list) {
    if (item.categoryId != excludeId) {
      options.push(item)
    }
    if (item.children && item.children.length) {
      options.push(...buildParentOptions(item.children, excludeId))
    }
  }
  options.unshift({ categoryId: 0, categoryName: '顶级分类' })
  return options
}

/** 新增顶级分类 */
function handleAddTop() {
  reset()
  parentOptions.value = [{ categoryId: 0, categoryName: '顶级分类' }]
  open.value = true
  title.value = '添加分类'
}

/** 新增子分类 */
function handleAddChild(row) {
  reset()
  parentOptions.value = buildParentOptions(categoryTree.value, row.categoryId)
  form.value.parentId = row.categoryId
  open.value = true
  title.value = '添加子分类'
}

/** 表单重置 */
function reset() {
  form.value = {
    categoryId: undefined,
    parentId: 0,
    categoryName: undefined,
    orderNum: 1,
    status: '0'
  }
  proxy.resetForm('categoryRef')
}

/** 修改按钮操作 */
function handleUpdate(row) {
  reset()
  getCategory(row.categoryId)
    .then((response) => {
      form.value = response.data
      parentOptions.value = buildParentOptions(categoryTree.value, row.categoryId)
      open.value = true
      title.value = '修改分类'
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('操作失败')
    })
}

/** 提交按钮 */
function submitForm() {
  proxy.$refs['categoryRef'].validate((valid) => {
    if (valid) {
      if (form.value.categoryId != undefined) {
        updateCategory(form.value)
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
        addCategory(form.value).then(() => {
          proxy.$modal.msgSuccess('新增成功')
          open.value = false
          getList()
        })
      }
    }
  })
}

/** 删除按钮操作 */
function handleDelete(row) {
  proxy.$modal
    .confirm('是否确认删除分类编号为"' + row.categoryId + '"的数据项？')
    .then(function () {
      return delCategory(row.categoryId)
    })
    .then(() => {
      if (form.value.categoryId === row.categoryId) {
        reset()
      }
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(() => {})
}

/** 取消按钮 */
function cancel() {
  open.value = false
  reset()
}

/** 判断是否可以添加子节点 */
function canAddChild(row) {
  return row.jobCount == 0
}

getList()
</script>

<style lang="scss" scoped>
.app-container {
  .card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;

    .card-title {
      font-size: 15px;
      font-weight: 600;
    }

    .card-actions {
      display: flex;
      align-items: center;
      gap: 8px;
    }
  }

  .form-footer {
    text-align: center;
    margin-top: 6px;
  }
}
</style>
