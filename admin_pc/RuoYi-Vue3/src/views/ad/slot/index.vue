<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="广告位名称" prop="slotName">
        <el-input
          v-model="queryParams.slotName"
          placeholder="请输入广告位名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="广告位类型" prop="slotType">
        <el-select v-model="queryParams.slotType" placeholder="请选择广告位类型" clearable style="width: 200px">
          <el-option v-for="item in slotTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="投放端" prop="target">
        <el-select v-model="queryParams.target" placeholder="请选择投放端" clearable style="width: 200px">
          <el-option v-for="item in targetOptions" :key="item.value" :label="item.label" :value="item.value" />
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
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['ad:slot:add']"
          >新增广告位</el-button
        >
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="success"
          plain
          icon="Edit"
          :disabled="single"
          @click="handleUpdate"
          v-hasPermi="['ad:slot:edit']"
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
          v-hasPermi="['ad:slot:remove']"
          >删除</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="slotList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="广告位名称" align="center" prop="slotName" :show-overflow-tooltip="true" />
      <el-table-column label="广告位类型" align="center" width="120">
        <template #default="scope">
          <el-tag :type="slotTypeTag(scope.row.slotType)">{{ slotTypeLabel(scope.row.slotType) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="投放端" align="center" width="110">
        <template #default="scope">
          <el-tag :type="targetTag(scope.row.target)">{{ targetLabel(scope.row.target) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="展示规则" align="center" prop="ruleDesc" :show-overflow-tooltip="true" />
      <el-table-column label="当前广告数" align="center" prop="adCount" width="100" />
      <el-table-column label="状态" align="center" width="90">
        <template #default="scope">
          <el-switch
            v-model="scope.row.status"
            active-value="0"
            inactive-value="1"
            @change="handleStatusChange(scope.row)"
          />
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="150" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['ad:slot:edit']"
            >修改</el-button
          >
          <el-button link type="primary" icon="Delete" @click="handleDelete(scope.row)" v-hasPermi="['ad:slot:remove']"
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

    <!-- 添加或修改广告位对话框 -->
    <el-dialog :title="title" v-model="open" width="760px" append-to-body>
      <el-form ref="slotRef" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="广告位名称" prop="slotName">
          <el-input v-model="form.slotName" placeholder="请输入广告位名称" />
        </el-form-item>
        <el-form-item label="广告位类型" prop="slotType">
          <el-select
            v-model="form.slotType"
            placeholder="请选择广告位类型"
            style="width: 100%"
            @change="handleSlotTypeChange"
          >
            <el-option v-for="item in slotTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="投放端" prop="target">
          <el-select v-model="form.target" placeholder="请选择投放端" style="width: 100%">
            <el-option v-for="item in targetOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>

        <el-divider content-position="left">展示规则配置</el-divider>
        <!-- 开屏广告规则 -->
        <template v-if="form.slotType === 'splash'">
          <el-form-item label="展示时长">
            <el-radio-group v-model="form.rule.showDuration">
              <el-radio :value="3">3秒</el-radio>
              <el-radio :value="5">5秒</el-radio>
            </el-radio-group>
          </el-form-item>
          <el-form-item label="是否可跳过">
            <el-switch v-model="form.rule.skippable" />
          </el-form-item>
          <el-form-item v-if="form.rule.skippable" label="跳过按钮位置">
            <el-radio-group v-model="form.rule.skipPosition">
              <el-radio value="right-top">右上角</el-radio>
              <el-radio value="right-bottom">右下角</el-radio>
            </el-radio-group>
          </el-form-item>
        </template>
        <!-- 弹窗广告规则 -->
        <template v-else-if="form.slotType === 'popup'">
          <el-form-item label="触发时机">
            <el-radio-group v-model="form.rule.triggerMode">
              <el-radio value="first">登录后首次进入</el-radio>
              <el-radio value="every">每次进入</el-radio>
            </el-radio-group>
          </el-form-item>
          <el-form-item label="弹出间隔">
            <el-input-number v-model="form.rule.popupInterval" :min="1" :max="168" />
            <span class="rule-tip">小时（两次弹出之间的最小间隔）</span>
          </el-form-item>
          <el-form-item label="是否可关闭">
            <el-switch v-model="form.rule.closable" />
          </el-form-item>
        </template>
        <!-- Banner 轮播规则 -->
        <template v-else-if="form.slotType === 'banner'">
          <el-form-item label="轮播间隔">
            <el-input-number v-model="form.rule.carouselInterval" :min="1" :max="60" />
            <span class="rule-tip">秒</span>
          </el-form-item>
          <el-form-item label="自动播放">
            <el-switch v-model="form.rule.autoPlay" />
          </el-form-item>
        </template>
        <!-- 信息流广告规则 -->
        <template v-else-if="form.slotType === 'feed'">
          <el-form-item label="插入位置">
            <el-input-number v-model="form.rule.feedPosition" :min="1" :max="100" />
            <span class="rule-tip">第 N 条内容后插入广告</span>
          </el-form-item>
        </template>
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

<script setup name="AdSlot">
import { listAdSlot, getAdSlot, addAdSlot, updateAdSlot, delAdSlot, changeAdSlotStatus } from '@/api/ad/slot'

const { proxy } = getCurrentInstance()

const slotList = ref([])
const open = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const ids = ref([])
const single = ref(true)
const multiple = ref(true)
const total = ref(0)
const title = ref('')

// 广告位类型选项
const slotTypeOptions = [
  { value: 'splash', label: '开屏广告', tag: 'primary' },
  { value: 'popup', label: '弹窗广告', tag: 'warning' },
  { value: 'banner', label: 'Banner轮播', tag: 'info' },
  { value: 'feed', label: '信息流广告', tag: 'success' }
]
// 投放端选项
const targetOptions = [
  { value: 'hr', label: 'HR端', tag: 'info' },
  { value: 'candidate', label: '候选人端', tag: 'primary' },
  { value: 'all', label: '全部', tag: '' }
]
// 状态选项
const statusOptions = [
  { value: '0', label: '启用' },
  { value: '1', label: '停用' }
]

/** 各类型展示规则的默认值 */
function defaultRule(slotType) {
  if (slotType === 'splash') {
    return { showDuration: 3, skippable: true, skipPosition: 'right-top' }
  }
  if (slotType === 'popup') {
    return { triggerMode: 'first', popupInterval: 24, closable: true }
  }
  if (slotType === 'banner') {
    return { carouselInterval: 5, autoPlay: true }
  }
  if (slotType === 'feed') {
    return { feedPosition: 5 }
  }
  return {}
}

const data = reactive({
  form: {
    slotId: undefined,
    slotName: undefined,
    slotType: 'splash',
    target: 'all',
    status: '0',
    ruleDesc: undefined,
    rule: { showDuration: 3, skippable: true, skipPosition: 'right-top' }
  },
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    slotName: undefined,
    slotType: undefined,
    target: undefined,
    status: undefined
  },
  rules: {
    slotName: [{ required: true, message: '广告位名称不能为空', trigger: 'blur' }]
  }
})

const { form, queryParams } = toRefs(data)

/**
 查询广告位列表 */
function getList() {
  loading.value = true

  listAdSlot(data.queryParams)
    .then((response) => {
      slotList.value = response.rows
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

/** 重置按钮操作 */
function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}

/** 新增按钮操作 */
function handleAdd() {
  reset()
  open.value = true
  title.value = '添加广告位'
}

/** 表单重置 */
function reset() {
  data.form = {
    slotId: undefined,
    slotName: undefined,
    slotType: 'splash',
    target: 'all',
    status: '0',
    ruleDesc: undefined,
    rule: defaultRule('splash')
  }
  proxy.resetForm('slotRef')
}

/** 修改按钮操作 */
function handleUpdate(row) {
  reset()
  getAdSlot(row.slotId)
    .then((response) => {
      data.form = response.data
      open.value = true
      title.value = '修改广告位'
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('操作失败')
    })
}

/** 提交按钮 */
function submitForm() {
  proxy.$refs['slotRef'].validate((valid) => {
    if (valid) {
      if (data.form.slotId != undefined) {
        updateAdSlot(data.form)
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
        addAdSlot(data.form).then(() => {
          proxy.$modal.msgSuccess('新增成功')
          open.value = false
          getList()
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
  const slotIds = row.slotId || ids.value
  proxy.$modal
    .confirm('是否确认删除广告位编号为"' + slotIds + '"的数据项？')
    .then(function () {
      return delAdSlot(slotIds)
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(() => {})
}

/** 启用状态切换 */
function handleStatusChange(row) {
  const nextStatus = row.status === '0' ? '1' : '0'
  const text = nextStatus === '0' ? '启用' : '停用'
  proxy.$modal
    .confirm('确认要"' + text + '"' + row.slotName + '"广告位吗？')
    .then(function () {
      return changeAdSlotStatus(row.slotId, nextStatus)
    })
    .then(() => {
      proxy.$modal.msgSuccess(text + '成功')
    })
    .catch(() => {
      row.status = row.status === '0' ? '1' : '0'
    })
}

/** 广告位类型变化 */
function handleSlotTypeChange(val) {
  data.form.rule = defaultRule(val)
}

/** 广告位类型显示 */
function slotTypeLabel(val) {
  const item = slotTypeOptions.find((o) => o.value === val)
  return item ? item.label : val
}

function slotTypeTag(val) {
  const item = slotTypeOptions.find((o) => o.value === val)
  return item ? item.tag : ''
}

/** 投放端显示 */
function targetLabel(val) {
  const item = targetOptions.find((o) => o.value === val)
  return item ? item.label : val
}

function targetTag(val) {
  const item = targetOptions.find((o) => o.value === val)
  return item ? item.tag : ''
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.slotId)
}

getList()
</script>
