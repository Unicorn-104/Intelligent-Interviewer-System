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
      <el-form-item label="解析状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="全部" clearable style="width: 150px">
          <el-option label="待解析" value="pending" /><el-option label="已解析" value="parsed" /><el-option
            label="解析失败"
            value="failed"
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
        ><el-button type="primary" plain icon="Upload" @click="handleUpload" v-hasPermi="['biz:resumeParse:add']"
          >上传解析</el-button
        ></el-col
      >
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="parseList" @selection-change="handleSelectionChange" stripe>
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="姓名" align="center" prop="name" width="100" />
      <el-table-column label="手机号" align="center" prop="phone" width="130" />
      <el-table-column label="目标岗位" align="center" prop="jobName" :show-overflow-tooltip="true" min-width="180" />
      <el-table-column label="解析状态" align="center" prop="status" width="100">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="解析得分" align="center" prop="parseScore" width="100">
        <template #default="scope"
          ><span
            :style="{
              color: scoreColor(scope.row.parseScore),
              fontWeight: 600
            }"
            >{{ scope.row.parseScore || '-' }}</span
          ></template
        >
      </el-table-column>
      <el-table-column label="解析时间" align="center" prop="parseTime" width="160">
        <template #default="scope"
          ><span>{{ parseTime(scope.row.parseTime) }}</span></template
        >
      </el-table-column>
      <el-table-column label="操作" align="center" width="150">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handleDetail(scope.row)">详情</el-button>
          <el-button
            link
            type="warning"
            icon="Refresh"
            @click="handleRescan(scope.row)"
            v-if="scope.row.status === 'failed'"
            >重新解析</el-button
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

    <!-- Upload Dialog -->
    <el-dialog title="上传简历" v-model="uploadOpen" width="500px" append-to-body>
      <el-upload ref="uploadRef" drag :auto-upload="false" :limit="5" accept=".pdf,.doc,.docx" multiple>
        <el-icon><Upload /></el-icon>
        <div>将文件拖到此处，或<em>点击上传</em></div>
        <template #tip>
          <div style="color: #999">只能上传 pdf/doc/docx 文件，最多5个</div>
        </template>
      </el-upload>
      <template #footer>
        <el-button type="primary" @click="doUpload">开 始 解 析</el-button>
        <el-button @click="uploadOpen = false">取 消</el-button>
      </template>
    </el-dialog>

    <!-- Detail Dialog -->
    <el-dialog :title="detailTitle" v-model="dialogOpen" width="700px" append-to-body>
      <div v-if="parseDetail" style="line-height: 2">
        <h4>基本信息</h4>
        <p>
          姓名：<strong>{{ parseDetail.name || '-' }}</strong>
        </p>
        <p>
          手机：<strong>{{ parseDetail.phone || '-' }}</strong>
        </p>
        <p>
          岗位：<strong>{{ parseDetail.jobName || '-' }}</strong>
        </p>
        <h4>教育经历</h4>
        <p style="background: #f5f7fa; padding: 12px; border-radius: 4px">
          {{ parseDetail.education || '暂无' }}
        </p>
        <h4>工作经历</h4>
        <p style="background: #f5f7fa; padding: 12px; border-radius: 4px">
          {{ parseDetail.workExperience || '暂无' }}
        </p>
      </div>
      <template #footer><el-button @click="dialogOpen = false">关 闭</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup name="BizResumeParse">
import { listResumeParse, parseResumeFile, getParseDetail, rescanResume } from '@/api/biz/resumeParse'

const { proxy } = getCurrentInstance()

// ==================== State ====================
const parseList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const ids = ref([])
const single = ref(true)
const multiple = ref(true)
const total = ref(0)
const uploadOpen = ref(false)
const dialogOpen = ref(false)
const detailTitle = ref('解析详情')
const parseDetail = ref({})
const uploadRef = ref(null)

const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  name: undefined,
  status: undefined
})

/** 查询解析列表 */
function getList() {
  loading.value = true
  listResumeParse(queryParams.value)
    .then((res) => {
      parseList.value = res.rows
      total.value = res.total
    })
    .catch(function (err) {
      console.error(err)
      proxy.$modal.msgError('查询失败，请重试')
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
  proxy.resetForm('queryRef')
  handleQuery()
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map(function (item) {
    return item.parseId
  })
  single.value = selection.length != 1
  multiple.value = !selection.length
}

/** 上传解析 */
function handleUpload() {
  uploadOpen.value = true
}

/** 开始解析 */
function doUpload() {
  var files = uploadRef.value.uploadFiles.filter(function (f) {
    return f.status === 'ready'
  })
  if (files.length === 0) {
    proxy.$modal.msgError('请选择要上传的文件')
    return
  }
  var formData = new FormData()
  files.forEach(function (file) {
    formData.append('files', file.raw)
  })
  parseResumeFile(formData)
    .then(function () {
      proxy.$modal.msgSuccess('解析任务已提交')
      uploadOpen.value = false
      getList()
    })
    .catch(function (err) {
      console.error(err)
      proxy.$modal.msgError('提交失败')
    })
}

/** 详情查看 */
function handleDetail(row) {
  detailTitle.value = row.name + ' - 简历解析详情'
  getParseDetail(row.parseId)
    .then((res) => {
      parseDetail.value = res.data
      dialogOpen.value = true
    })
    .catch(function (err) {
      console.error(err)
      proxy.$modal.msgError('加载详情失败')
    })
}

/** 重新解析 */
function handleRescan(row) {
  proxy.$modal
    .confirm('确认要重新解析简历"' + row.name + '"吗？')
    .then(function () {
      return rescanResume(row.parseId)
    })
    .then(function () {
      proxy.$modal.msgSuccess('已重新提交解析')
      getList()
    })
    .catch(function () {})
}

/** 状态标签映射 */
function statusLabel(status) {
  var map = { pending: '待解析', parsed: '已解析', failed: '解析失败' }
  return map[status] || status
}
function statusTag(status) {
  var map = { pending: 'warning', parsed: 'success', failed: 'danger' }
  return map[status] || 'info'
}
function scoreColor(score) {
  if (!score) return '#909399'
  var n = Number(score)
  if (n >= 80) return '#67C23A'
  if (n >= 60) return '#E6A23C'
  return '#F56C6C'
}
function fileListToFormData(files) {
  var fd = new FormData()
  files.forEach(function (f) {
    fd.append('files', f.raw)
  })
  return fd
}

getList()
</script>
