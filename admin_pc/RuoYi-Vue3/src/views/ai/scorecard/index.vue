<template>
  <div class="app-container list-page">
    <!-- 搜索卡片 -->
    <div class="search-card">
      <el-form :model="queryParams" ref="queryRef" :inline="true">
        <el-form-item label="评分卡名称" prop="cardName">
          <el-input
            v-model="queryParams.cardName"
            placeholder="请输入评分卡名称"
            clearable
            @keyup.enter="handleQuery"
          />
        </el-form-item>
        <el-form-item label="岗位方向" prop="jobDirection">
          <el-select v-model="queryParams.jobDirection" placeholder="请选择" clearable>
            <el-option v-for="item in jobDirectionOptions" :key="item" :label="item" :value="item" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-select v-model="queryParams.status" placeholder="请选择" clearable>
            <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
          <el-button icon="Refresh" @click="resetQuery">重置</el-button>
        </el-form-item>
      </el-form>
    </div>

    <!-- 表格卡片 -->
    <div class="table-card">
      <el-row :gutter="10" class="toolbar">
        <el-col :span="1.5">
          <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['ai:scorecard:add']"
            >新增评分卡</el-button
          >
        </el-col>
        <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
      </el-row>

      <el-table v-loading="loading" :data="scorecardList" stripe border>
        <el-table-column label="ID" align="center" prop="cardId" width="80" />
        <el-table-column label="评分卡名称" align="center" prop="cardName" min-width="160" />
        <el-table-column label="岗位方向" align="center" width="120">
          <template #default="scope"
            ><el-tag effect="plain">{{ scope.row.jobDirection }}</el-tag></template
          >
        </el-table-column>
        <el-table-column label="评分维度" align="center" min-width="240">
          <template #default="scope">
            <el-tag v-for="(d, i) in scope.row.dimensions" :key="i" size="small" class="dim-tag"
              >{{ d.name }} {{ d.weight }}%</el-tag
            >
          </template>
        </el-table-column>
        <el-table-column label="总分" align="center" prop="totalScore" width="80" />
        <el-table-column label="状态" align="center" width="90">
          <template #default="scope"
            ><el-tag effect="plain" :type="statusTag(scope.row.status)">{{
              statusLabel(scope.row.status)
            }}</el-tag></template
          >
        </el-table-column>
        <el-table-column label="说明" align="center" prop="remark" min-width="160" />
        <el-table-column label="创建时间" align="center" prop="createTime" width="120">
          <template #default="scope"
            ><span>{{ parseTime(scope.row.createTime, '{y}-{m}-{d}') }}</span></template
          >
        </el-table-column>
        <el-table-column label="操作" align="center" width="140" fixed="right">
          <template #default="scope">
            <el-button
              link
              type="primary"
              icon="Edit"
              @click="handleUpdate(scope.row)"
              v-hasPermi="['ai:scorecard:edit']"
              >修改</el-button
            >
            <el-button
              link
              type="primary"
              icon="Delete"
              @click="handleDelete(scope.row)"
              v-hasPermi="['ai:scorecard:remove']"
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
    </div>

    <!-- 编辑对话框 -->
    <el-dialog :title="title" v-model="open" width="720px" append-to-body>
      <el-form ref="scorecardRef" :model="form" :rules="rules" label-width="90px">
        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="评分卡名称" prop="cardName"
              ><el-input v-model="form.cardName" placeholder="请输入名称"
            /></el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="岗位方向" prop="jobDirection">
              <el-select v-model="form.jobDirection" placeholder="请选择" style="width: 100%">
                <el-option v-for="item in jobDirectionOptions" :key="item" :label="item" :value="item" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="状态" prop="status">
              <el-radio-group v-model="form.status">
                <el-radio value="0">启用</el-radio>
                <el-radio value="1">停用</el-radio>
              </el-radio-group>
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="评分维度">
          <div class="dimension-editor">
            <el-table :data="form.dimensions" border size="small" class="inner-table" style="width: 100%">
              <el-table-column label="维度名称">
                <template #default="scope"><el-input v-model="scope.row.name" placeholder="维度名称" /></template>
              </el-table-column>
              <el-table-column label="权重" width="200">
                <template #default="scope"
                  ><el-input-number
                    v-model="scope.row.weight"
                    :min="1"
                    :max="100"
                    controls-position="right"
                    style="width: 100%"
                /></template>
              </el-table-column>
              <el-table-column label="操作" width="80">
                <template #default="scope"
                  ><el-button link type="danger" icon="Delete" @click="handleRemoveDimension(scope.$index)"
                    >删除</el-button
                  ></template
                >
              </el-table-column>
            </el-table>
            <el-button type="primary" plain icon="Plus" class="add-dimension" @click="handleAddDimension"
              >添加维度</el-button
            >
          </div>
        </el-form-item>
        <el-form-item label="说明" prop="remark">
          <el-input v-model="form.remark" type="textarea" :rows="3" placeholder="选填" />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="weight-summary">
          <span
            >当前合计权重：<strong :class="{ warning: totalWeight !== 100 }">{{ totalWeight }}%</strong></span
          >
          <span v-if="totalWeight !== 100" class="weight-warning">合计权重必须等于 100%</span>
        </div>
        <div class="dialog-footer">
          <el-button type="primary" :disabled="submitDisabled" @click="submitForm">确 定</el-button>
          <el-button @click="cancel">取 消</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="Scorecard">
import { listScorecard, getScorecard, addScorecard, updateScorecard, delScorecard } from '@/api/ai/scorecard'

const { proxy } = getCurrentInstance()
const scorecardList = ref([])
const open = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const title = ref('')

const jobDirectionOptions = ['技术研发', '算法工程', '产品运营', '测试/QA', '不限']
const statusOptions = [
  { value: '0', label: '启用', tag: 'success' },
  { value: '1', label: '停用', tag: 'info' }
]

const ids = ref([])
const single = ref(true)
const multiple = ref(true)

const data = reactive({
  form: {
    cardId: undefined,
    cardName: undefined,
    jobDirection: undefined,
    status: '0',
    remark: undefined,
    dimensions: []
  },
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    cardName: undefined,
    jobDirection: undefined,
    status: undefined
  },
  rules: {
    cardName: [{ required: true, message: '名称不能为空', trigger: 'blur' }],
    jobDirection: [{ required: true, message: '请选择岗位方向', trigger: 'change' }]
  }
})

const { form, queryParams, rules } = toRefs(data)

/** 查询评分卡列表 */
function getList() {
  loading.value = true
  listScorecard(data.queryParams)
    .then((response) => {
      scorecardList.value = response.rows
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
  title.value = '添加评分卡'
}

/** 表单重置 */
function reset() {
  data.form = {
    cardId: undefined,
    cardName: undefined,
    jobDirection: undefined,
    status: '0',
    remark: undefined,
    dimensions: []
  }
  proxy.resetForm('scorecardRef')
}

/** 修改按钮操作 */
function handleUpdate(row) {
  reset()
  getScorecard(row.cardId)
    .then((response) => {
      data.form = response.data
      open.value = true
      title.value = '修改评分卡'
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('操作失败')
    })
}

/** 提交按钮 */
function submitForm() {
  if (totalWeight.value !== 100) {
    proxy.$modal.msgError('合计权重必须等于 100%')
    return
  }
  proxy.$refs['scorecardRef'].validate((valid) => {
    if (valid) {
      if (data.form.cardId != undefined) {
        updateScorecard(data.form)
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
        addScorecard(data.form)
          .then(() => {
            proxy.$modal.msgSuccess('新增成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error(err)
            proxy?.$msgError?.('操作失败')
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

/** 删除按钮操作 */
function handleDelete(row) {
  const cardIds = row.cardId || ids.value
  proxy.$modal
    .confirm(`是否确认删除评分卡编号为"${cardIds}"的数据项？`)
    .then(function () {
      return delScorecard(cardIds)
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(() => {})
}

/** 计算合计权重 */
const totalWeight = computed(() => {
  if (!data.form.dimensions) return 0
  return data.form.dimensions.reduce((sum, d) => sum + (Number(d.weight) || 0), 0)
})

/** 提交是否禁用 */
const submitDisabled = computed(() => {
  return totalWeight.value !== 100
})

/**
 添加维度 */
function handleAddDimension() {
  data.form.dimensions.push({ name: '', weight: 0 })
}

/** 删除维度 */
function handleRemoveDimension(index) {
  data.form.dimensions.splice(index, 1)
}

function statusTag(val) {
  const option = statusOptions.find((item) => item.value === val)
  return option?.tag || 'info'
}

getList()
</script>

<style lang="scss" scoped>
.list-page {
  .search-card {
    background: #fff;
    padding: 18px 20px 6px;
    margin-bottom: 16px;
    border-radius: 8px;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
    border: 1px solid #ebeef5;
  }
  .table-card {
    background: #fff;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
    border: 1px solid #ebeef5;
  }
  .toolbar {
    padding: 12px 20px;
    border-bottom: 1px solid #f5f7fa;
  }
  .dim-tag {
    margin: 2px;
  }
  .add-dimension {
    margin-top: 8px;
  }
  .weight-summary {
    margin-bottom: 8px;
    text-align: right;
    font-size: 13px;
    color: #4e5969;
    strong {
      font-weight: 700;
      &.warning {
        color: #ef4444;
      }
    }
    .weight-warning {
      margin-left: 8px;
      color: #ef4444;
      font-size: 12px;
    }
  }
  .dialog-footer {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
  }
  .inner-table {
    margin-bottom: 8px;
  }
}
</style>
