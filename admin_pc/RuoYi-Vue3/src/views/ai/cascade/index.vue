<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="规则名称" prop="ruleName">
        <el-input
          v-model="queryParams.ruleName"
          placeholder="请输入规则名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
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
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['ai:cascade:add']"
          >新增规则</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="cascadeList">
      <el-table-column label="ID" align="center" prop="ruleId" width="80" />
      <el-table-column label="规则名称" align="center" prop="ruleName" :show-overflow-tooltip="true" />
      <el-table-column label="粗排保留Top" align="center" prop="roughTopN" width="110" />
      <el-table-column label="深析候选Top" align="center" prop="deepTopN" width="110" />
      <el-table-column label="评分阈值" align="center" width="90">
        <template #default="scope">
          <span>{{ scope.row.scoreThreshold }} 分</span>
        </template>
      </el-table-column>
      <el-table-column label="自动流转" align="center" width="100">
        <template #default="scope">
          <el-tag :type="autoFlowTag(scope.row.autoFlow)">{{ autoFlowLabel(scope.row.autoFlow) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column
        label="面试轮次"
        align="center"
        prop="interviewRounds"
        width="150"
        :show-overflow-tooltip="true"
      />
      <el-table-column label="状态" align="center" width="90">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="说明" align="center" prop="remark" :show-overflow-tooltip="true" />
      <el-table-column label="创建时间" align="center" width="110">
        <template #default="scope">
          <span>{{ parseTime(scope.row.createTime, '{y}-{m}-{d}') }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="140" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['ai:cascade:edit']"
            >修改</el-button
          >
          <el-button
            link
            type="primary"
            icon="Delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['ai:cascade:remove']"
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

    <!-- 添加或修改级联规则对话框 -->
    <el-dialog :title="title" v-model="open" width="720px" append-to-body>
      <el-form ref="cascadeRef" :model="form" :rules="rules" label-width="110px">
        <el-form-item label="规则名称" prop="ruleName">
          <el-input v-model="form.ruleName" placeholder="请输入规则名称" />
        </el-form-item>
        <el-row>
          <el-col :span="12">
            <el-form-item label="粗排保留Top" prop="roughTopN">
              <el-input-number v-model="form.roughTopN" :min="1" :max="100" @change="handleRoughChange" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="深析候选Top" prop="deepTopN">
              <el-input-number v-model="form.deepTopN" :min="1" :max="50" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="评分阈值" prop="scoreThreshold">
              <el-input-number v-model="form.scoreThreshold" :min="0" :max="100" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="自动流转" prop="autoFlow">
              <el-switch
                v-model="form.autoFlow"
                :active-value="'1'"
                :inactive-value="'0'"
                active-text="自动流转"
                inactive-text="人工复核"
              />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="面试轮次" prop="interviewRounds">
              <el-input v-model="form.interviewRounds" placeholder="如：初面-复面-终面" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="状态" prop="status">
              <el-radio-group v-model="form.status">
                <el-radio value="0">启用</el-radio>
                <el-radio value="1">停用</el-radio>
              </el-radio-group>
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="说明" prop="remark">
          <el-input v-model="form.remark" type="textarea" :rows="3" placeholder="请输入说明（选填）" />
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

<script setup name="Cascade">
import { listCascade, getCascade, addCascade, updateCascade, delCascade } from '@/api/ai/cascade'

const { proxy } = getCurrentInstance()

const cascadeList = ref([])
const open = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const title = ref('')

// 状态选项
const statusOptions = [
  { value: '0', label: '启用', tag: 'success' },
  { value: '1', label: '停用', tag: 'info' }
]

/** 深析候选数不能大于粗排保留数校验 */
function validateDeepTopN(rule, value, callback) {
  if (value != undefined && data.form.roughTopN != undefined && Number(value) > Number(data.form.roughTopN)) {
    callback(new Error('深析候选数不能大于粗排保留数'))
  } else {
    callback()
  }
}

const data = reactive({
  form: {
    ruleId: undefined,
    ruleName: undefined,
    roughTopN: 10,
    deepTopN: 5,
    scoreThreshold: 60,
    autoFlow: '1',
    interviewRounds: undefined,
    status: '0',
    remark: undefined
  },
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    ruleName: undefined,
    status: undefined
  },
  rules: {
    ruleName: [{ required: true, message: '规则名称不能为空', trigger: 'blur' }],
    deepTopN: [{ validator: validateDeepTopN, trigger: ['blur', 'change'] }]
  }
})

const { form, queryParams, rules } = toRefs(data)

/**
 查询列表 */
function getList() {
  loading.value = true

  listCascade(data.queryParams)
    .then((response) => {
      cascadeList.value = response.rows
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
  title.value = '添加级联规则'
}

/** 表单重置 */
function reset() {
  data.form = {
    ruleId: undefined,
    ruleName: undefined,
    roughTopN: 10,
    deepTopN: 5,
    scoreThreshold: 60,
    autoFlow: '1',
    interviewRounds: undefined,
    status: '0',
    remark: undefined
  }
  proxy.resetForm('cascadeRef')
}

/** 修改按钮操作 */
function handleUpdate(row) {
  reset()
  getCascade(row.ruleId)
    .then((response) => {
      data.form = response.data
      open.value = true
      title.value = '修改级联规则'
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('操作失败')
    })
}

/** 提交按钮 */
function submitForm() {
  proxy.$refs['cascadeRef'].validate((valid) => {
    if (valid) {
      if (data.form.ruleId != undefined) {
        updateCascade(data.form)
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
        addCascade(data.form)
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
  const ruleId = row.ruleId
  proxy.$modal
    .confirm('是否确认删除级联规则编号为"' + ruleId + '"的数据项？')
    .then(function () {
      return delCascade(ruleId)
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(() => {})
}

/** 粗排变化时校验深析候选数 */
function handleRoughChange(val) {
  if (proxy.$refs['cascadeRef']) {
    proxy.$refs['cascadeRef'].clearValidate('deepTopN')
  }
}

/** 自动流转显示 */
function autoFlowLabel(val) {
  return val === '1' ? '是' : '否'
}

function autoFlowTag(val) {
  return val === '1' ? 'success' : 'info'
}

function statusTag(val) {
  const option = statusOptions.find((item) => item.value === val)
  return option?.tag || 'info'
}

getList()
</script>
