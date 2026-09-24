<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch" label-width="100px">
      <el-form-item label="姓名" prop="name">
        <el-input
          v-model="queryParams.name"
          placeholder="请输入姓名"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="岗位" prop="jobName">
        <el-input
          v-model="queryParams.jobName"
          placeholder="请输入岗位"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="来源" prop="source">
        <el-select v-model="queryParams.source" placeholder="全部" clearable style="width: 150px">
          <el-option label="网络投递" value="web" /><el-option label="猎头推荐" value="headhunter" /><el-option
            label="内部推荐"
            value="internal"
          />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5"
        ><el-button type="primary" plain icon="Plus" @click="handleImport" v-hasPermi="['biz:resume:add']"
          >导入简历</el-button
        ></el-col
      >
      <el-col :span="1.5"
        ><el-button
          type="danger"
          plain
          icon="Delete"
          :disabled="multiple"
          @click="handleDelete"
          v-hasPermi="['biz:resume:remove']"
          >删除</el-button
        ></el-col
      >
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="resumeList" @selection-change="handleSelectionChange" stripe>
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="姓名" align="center" prop="name" width="100" />
      <el-table-column label="手机号" align="center" prop="phone" width="130" />
      <el-table-column label="目标岗位" align="center" prop="jobName" :show-overflow-tooltip="true" min-width="180" />
      <el-table-column label="来源" align="center" prop="source" width="100">
        <template #default="scope"
          ><el-tag>{{ scope.row.source }}</el-tag></template
        >
      </el-table-column>
      <el-table-column label="上传时间" align="center" prop="uploadTime" width="160">
        <template #default="scope"
          ><span>{{ parseTime(scope.row.uploadTime) }}</span></template
        >
      </el-table-column>
      <el-table-column label="操作" align="center" width="200">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleView(scope.row)">预览</el-button>
          <el-button link type="primary" icon="Download" @click="handleDownload(scope.row)">下载</el-button>
          <el-button link type="danger" icon="Delete" @click="handleDelete(scope.row)" v-if="!scope.row.processed"
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

    <el-dialog :title="detailTitle" v-model="dialogOpen" width="700px" append-to-body>
      <div v-if="resumeDetail" style="line-height: 2">
        <h4>基本信息</h4>
        <p>
          姓名：<strong>{{ resumeDetail.name || '-' }}</strong>
        </p>
        <p>
          手机：<strong>{{ resumeDetail.phone || '-' }}</strong>
        </p>
        <p>
          岗位：<strong>{{ resumeDetail.jobName || '-' }}</strong>
        </p>
        <p>
          邮箱：<strong>{{ resumeDetail.email || '-' }}</strong>
        </p>
        <p>
          经验：<strong>{{ resumeDetail.experience || '-' }}</strong>
        </p>
        <h4>工作经历</h4>
        <p style="background: #f5f7fa; padding: 12px; border-radius: 4px">
          {{ resumeDetail.workExperience || '暂无' }}
        </p>
        <h4>自我评价</h4>
        <p style="background: #f5f7fa; padding: 12px; border-radius: 4px">
          {{ resumeDetail.selfEval || '暂无' }}
        </p>
      </div>
      <template #footer><el-button @click="dialogOpen = false">关 闭</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="BizResume">
import { listResume, getResume, delResume, downloadResume } from '@/api/biz/resume'

const { proxy } = getCurrentInstance()

// ==================== State ====================
const resumeList = ref([])
const ids = ref([])
const dialogOpen = ref(false)
const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  name: undefined,
  jobName: undefined,
  source: undefined
})

const total = ref(0)
const loading = ref(true)
const detailTitle = ref('')
const resumeDetail = ref(null)
const showSearch = ref(true)
const multiple = ref(true)

function handleQuery() {
  getList()
}

function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}

function handleImport() {
  proxy.$modal.msgWarning('导入功能开发中')
}
/** 查询简历列表 */
function getList() {
  loading.value = true
  listResume(queryParams.value)
    .then((res) => {
      resumeList.value = res.rows
      total.value = res.total
    })
    .catch((err) => {
      console.error('简历列表查询失败:', err)
      proxy.$modal.msgError('查询失败，请重试')
    })
    .finally(() => {
      loading.value = false
    })
}

/** 预览按钮操作 */
function handleView(row) {
  getResume(row.resumeId)
    .then((res) => {
      resumeDetail.value = res.data
      detailTitle.value = row.name + ' - 简历详情'
      dialogOpen.value = true
    })
    .catch((err) => {
      console.error(err)
      proxy.$modal.msgError('加载详情失败')
    })
}

/** 下载按钮操作 */
function handleDownload(row) {
  downloadResume(row.resumeId)
}

/** 删除按钮操作 */
function handleDelete(row) {
  const resumeIds = row.resumeId || ids.value
  proxy.$modal
    .confirm('是否确认删除简历编号为"' + resumeIds + '"的数据项？')
    .then(() => {
      return delResume(resumeIds.join(','))
    })
    .then(() => {
      proxy.$modal.msgSuccess('删除成功')
      getList()
    })
    .catch(() => {})
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.resumeId)
}

getList()
</script>
