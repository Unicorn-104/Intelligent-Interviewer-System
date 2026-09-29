<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch" label-width="68px">
      <el-form-item label="字典名称" prop="dictName">
        <el-input
          v-model="queryParams.dictName"
          placeholder="请输入字典名称"
          clearable
          style="width: 240px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="字典类型" prop="dictType">
        <el-input
          v-model="queryParams.dictType"
          placeholder="请输入字典类型"
          clearable
          style="width: 240px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="字典状态" clearable style="width: 240px">
          <el-option v-for="dict in sys_normal_disable" :key="dict.value" :label="dict.label" :value="dict.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="创建时间" style="width: 308px">
        <el-date-picker
          v-model="dateRange"
          value-format="YYYY-MM-DD"
          type="daterange"
          range-separator="-"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
        ></el-date-picker>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['system:dict:add']">新增</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="success"
          plain
          icon="Edit"
          :disabled="single"
          @click="handleUpdate"
          v-hasPermi="['system:dict:edit']"
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
          v-hasPermi="['system:dict:remove']"
          >删除</el-button
        >
      </el-col>
      <el-col :span="1.5">
        <el-button type="warning" plain icon="Download" @click="handleExport" v-hasPermi="['system:dict:export']"
          >导出</el-button
        >
      </el-col>
      <el-col :span="1.5">
        <el-button type="danger" plain icon="Refresh" @click="handleRefreshCache" v-hasPermi="['system:dict:remove']"
          >刷新缓存</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="typeList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="字典编号" align="center" prop="dictId" />
      <el-table-column label="字典名称" align="center" prop="dictName" :show-overflow-tooltip="true" />
      <el-table-column label="字典类型" align="center" :show-overflow-tooltip="true">
        <template #default="scope">
          <a class="link-type" style="cursor: pointer" @click="handleViewData(scope.row)">{{ scope.row.dictType }}</a>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" prop="status">
        <template #default="scope">
          <dict-tag :options="sys_normal_disable" :value="scope.row.status" />
        </template>
      </el-table-column>
      <el-table-column label="备注" align="center" prop="remark" :show-overflow-tooltip="true" />
      <el-table-column label="创建时间" align="center" prop="createTime" width="180">
        <template #default="scope">
          <span>{{ parseTime(scope.row.createTime) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="280" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['system:dict:edit']"
            >修改</el-button
          >
          <el-button
            link
            type="primary"
            icon="Operation"
            @click="handleDataList(scope.row)"
            v-hasPermi="['system:dict:edit']"
            >列表</el-button
          >
          <el-button
            link
            type="primary"
            icon="Delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['system:dict:remove']"
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

    <!-- 添加或修改参数配置对话框 -->
    <el-dialog :title="title" v-model="open" width="500px" append-to-body>
      <el-form ref="dictRef" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="字典名称" prop="dictName">
          <el-input v-model="form.dictName" placeholder="请输入字典名称" />
        </el-form-item>
        <el-form-item prop="dictType">
          <el-input v-model="form.dictType" placeholder="请输入字典类型" />
          <template #label>
            <span>
              <el-tooltip content="数据存储中的Key值，如：sys_user_sex" placement="top">
                <el-icon><question-filled /></el-icon>
              </el-tooltip>
              字典类型
            </span>
          </template>
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-radio-group v-model="form.status">
            <el-radio v-for="dict in sys_normal_disable" :key="dict.value" :value="dict.value">{{
              dict.label
            }}</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="备注" prop="remark">
          <el-input v-model="form.remark" type="textarea" placeholder="请输入内容"></el-input>
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitForm">确 定</el-button>
          <el-button @click="cancel">取 消</el-button>
        </div>
      </template>
    </el-dialog>

    <dict-data-drawer v-model:visible="drawerVisible" :row="drawerRow" />
  </div>
</template>

<script setup name="SystemDict">
import DictDataDrawer from './detail'
import useDictStore from '@/store/modules/dict'
import { listType, getType, delType, addType, updateType, refreshCache } from '@/api/system/dict/type'

const { proxy } = getCurrentInstance()
const { sys_normal_disable } = useDict('sys_normal_disable')

const typeList = ref([])
const open = ref(false)
const loading = ref(true)
const showSearch = ref(true)
const ids = ref([])
const single = ref(true)
const multiple = ref(true)
const total = ref(0)
const title = ref('')
const dateRange = ref([])
const drawerVisible = ref(false)
const drawerRow = ref({})

const form = ref({})
const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  dictName: undefined,
  dictType: undefined,
  status: undefined
})

/** 查询字典类型列表 */
function getList() {
  loading.value = true
  listType(proxy.addDateRange(queryParams.value, dateRange.value))
    .then((response) => {
      typeList.value = response.rows
      total.value = response.total
    })
    .catch(function (err) {
      console.error('查询字典类型列表失败:', err)
    })
    .finally(function () {
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
  dateRange.value = []
  proxy.resetForm('queryRef')
  handleQuery()
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.dictId)
  single.value = selection.length != 1
  multiple.value = !selection.length
}

/** 新增按钮操作 */
function handleAdd() {
  reset()
  open.value = true
  title.value = '添加字典类型'
}

/** 修改按钮操作 */
function handleUpdate(row) {
  reset()
  var dictId = row.dictId || ids.value
  getType(dictId)
    .then((response) => {
      form.value = response.data
      open.value = true
      title.value = '修改字典类型'
    })
    .catch(function (err) {
      console.error('查询字典类型失败:', err)
    })
}

/** 查看字典数据 */
function handleViewData(row) {
  drawerRow.value = row
  drawerVisible.value = true
}

/** 查看字典明细 */
function handleDataList(row) {
  drawerRow.value = row
  drawerVisible.value = true
}

/** 提交按钮 */
function submitForm() {
  proxy.$refs['dictRef'].validate(function (valid) {
    if (valid) {
      if (form.value.dictId != undefined) {
        updateType(form.value)
          .then(function () {
            proxy.$modal.msgSuccess('修改成功')
            open.value = false
            getList()
          })
          .catch(function (err) {
            console.error('修改字典类型失败:', err)
          })
      } else {
        addType(form.value)
          .then(function () {
            proxy.$modal.msgSuccess('新增成功')
            open.value = false
            getList()
          })
          .catch(function (err) {
            console.error('新增字典类型失败:', err)
          })
      }
    }
  })
}

/** 删除按钮操作 */
function handleDelete(row) {
  var dictIds = row.dictId || ids.value
  proxy.$modal
    .confirm('是否确认删除字典编号为"' + dictIds + '"的数据项？')
    .then(function () {
      return delType(dictIds)
    })
    .then(function () {
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(function () {})
}

/** 导出按钮操作 */
function handleExport() {
  proxy.download(
    'system/dict/type/export',
    proxy.addDateRange(queryParams.value, dateRange.value),
    'dict_' + new Date().getTime() + '.xlsx'
  )
}

/** 刷新缓存按钮操作 */
function handleRefreshCache() {
  refreshCache()
    .then(function () {
      proxy.$modal.msgSuccess('刷新成功')
      useDictStore().cleanDict()
    })
    .catch(function (err) {
      console.error('刷新缓存失败:', err)
    })
}

/** 重置表单 */
function reset() {
  form.value = {
    dictId: undefined,
    dictName: undefined,
    dictType: undefined,
    status: '0',
    remark: undefined
  }
  proxy.resetForm('dictRef')
}

getList()
</script>
