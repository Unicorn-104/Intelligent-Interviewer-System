<template>
  <div class="app-container list-page">
    <!-- 状态统计条 -->
    <div class="stat-bar">
      <div class="stat-item blue">
        <span class="stat-num">{{ statusSummary['0'] }}</span>
        <span class="stat-label">待处理</span>
      </div>
      <div class="stat-item primary">
        <span class="stat-num">{{ statusSummary['1'] }}</span>
        <span class="stat-label">处理中</span>
      </div>
      <div class="stat-item green">
        <span class="stat-num">{{ statusSummary['2'] }}</span>
        <span class="stat-label">已解决</span>
      </div>
    </div>

    <!-- 搜索卡片 -->
    <div class="search-card">
      <el-form :model="queryParams" ref="queryRef" :inline="true">
        <el-form-item label="用户" prop="userName">
          <el-input v-model="queryParams.userName" placeholder="请输入用户名称" clearable @keyup.enter="handleQuery" />
        </el-form-item>
        <el-form-item label="类型" prop="type">
          <el-select v-model="queryParams.type" placeholder="请选择反馈类型" clearable>
            <el-option v-for="item in typeOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-select v-model="queryParams.status" placeholder="请选择状态" clearable>
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
        <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
      </el-row>

      <el-table v-loading="loading" :data="feedbackList" stripe border>
        <el-table-column label="编号" align="center" prop="feedbackId" width="80" />
        <el-table-column label="用户" align="center" prop="userName" min-width="140" />
        <el-table-column label="类型" align="center" width="110">
          <template #default="scope"
            ><el-tag effect="plain" :type="typeTag(scope.row.type)">{{ typeLabel(scope.row.type) }}</el-tag></template
          >
        </el-table-column>
        <el-table-column label="反馈内容" align="center" prop="content" min-width="200" />
        <el-table-column label="附件" align="center" width="100">
          <template #default="scope"
            ><span>{{ formatImages(scope.row.images) }}</span></template
          >
        </el-table-column>
        <el-table-column label="联系方式" align="center" prop="contact" min-width="160" />
        <el-table-column label="提交时间" align="center" prop="createTime" width="170" />
        <el-table-column label="状态" align="center" width="100">
          <template #default="scope"
            ><el-tag effect="plain" :type="statusTag(scope.row.status)">{{
              statusLabel(scope.row.status)
            }}</el-tag></template
          >
        </el-table-column>
        <el-table-column label="处理人" align="center" prop="handler" width="100" />
        <el-table-column label="操作" align="center" width="150" fixed="right">
          <template #default="scope">
            <el-button
              link
              type="primary"
              icon="View"
              @click="handleDetail(scope.row)"
              v-hasPermi="['content:feedback:query']"
              >详情</el-button
            >
            <el-button
              v-if="scope.row.status !== '2'"
              link
              type="primary"
              icon="Edit"
              @click="handleProcess(scope.row)"
              v-hasPermi="['content:feedback:edit']"
              >处理</el-button
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

    <!-- 反馈详情对话框 -->
    <el-dialog title="反馈详情" v-model="detailOpen" width="700px" append-to-body>
      <el-descriptions :column="2" border class="desc-table">
        <el-descriptions-item label="反馈编号">{{ detailRow.feedbackId }}</el-descriptions-item>
        <el-descriptions-item label="用户">{{ detailRow.userName }}</el-descriptions-item>
        <el-descriptions-item label="类型">{{ typeLabel(detailRow.type) }}</el-descriptions-item>
        <el-descriptions-item label="状态">{{ statusLabel(detailRow.status) }}</el-descriptions-item>
        <el-descriptions-item label="联系方式">{{ detailRow.contact }}</el-descriptions-item>
        <el-descriptions-item label="附件数">{{ formatImages(detailRow.images) }}</el-descriptions-item>
        <el-descriptions-item label="提交时间">{{ detailRow.createTime }}</el-descriptions-item>
        <el-descriptions-item label="处理人">{{ detailRow.handler || '-' }}</el-descriptions-item>
        <el-descriptions-item label="处理时间">{{ detailRow.handleTime || '-' }}</el-descriptions-item>
        <el-descriptions-item label="回复内容" :span="2">{{ detailRow.reply || '-' }}</el-descriptions-item>
        <el-descriptions-item label="反馈内容" :span="2">{{ detailRow.content }}</el-descriptions-item>
      </el-descriptions>
      <template #footer
        ><div class="dialog-footer">
          <el-button @click="detailOpen = false">关 闭</el-button>
        </div></template
      >
    </el-dialog>

    <!-- 处理反馈对话框 -->
    <el-dialog title="处理反馈" v-model="handleOpen" width="600px" append-to-body destroy-on-close>
      <el-form ref="handleRef" :model="handleForm" :rules="handleRules" label-width="100px">
        <el-form-item label="处理结果" prop="status">
          <el-select v-model="handleForm.status" placeholder="请选择处理结果">
            <el-option v-for="item in handleStatusOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="回复内容" prop="reply">
          <el-input
            v-model="handleForm.reply"
            type="textarea"
            :rows="4"
            :placeholder="handleForm.status === '2' ? '标记已解决时必填' : '请输入'"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitHandle">确 定</el-button>
          <el-button @click="handleOpen = false">取 消</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="Feedback">
import { listFeedback, handleFeedback } from '@/api/content/feedback'

const { proxy } = getCurrentInstance()
const feedbackList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)
const detailOpen = ref(false)
const handleOpen = ref(false)
const detailRow = ref({})

const typeOptions = [
  { value: '0', label: '功能异常', tag: 'danger' },
  { value: '1', label: '体验建议', tag: 'primary' },
  { value: '2', label: '账号问题', tag: 'warning' },
  { value: '3', label: '其他', tag: 'info' }
]
const statusOptions = [
  { value: '0', label: '待处理', tag: 'warning' },
  { value: '1', label: '处理中', tag: 'primary' },
  { value: '2', label: '已解决', tag: 'success' }
]
const handleStatusOptions = [
  { value: '1', label: '处理中' },
  { value: '2', label: '已解决' }
]

const handleForm = ref({ feedbackId: undefined, status: '1', reply: undefined })

const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  userName: undefined,
  type: undefined,
  status: undefined
})

const handleRules = computed(() => ({
  status: [{ required: true, message: '处理结果不能为空', trigger: 'change' }],
  reply: [
    {
      required: handleForm.value.status === '2',
      message: '标记已解决时回复内容不能为空',
      trigger: 'blur'
    }
  ]
}))

const statusSummary = computed(() =>
  feedbackList.value.reduce(
    (acc, item) => {
      acc[item.status] = (acc[item.status] || 0) + 1
      return acc
    },
    { 0: 0, 1: 0, 2: 0 }
  )
)

function typeLabel(v) {
  const o = typeOptions.find((x) => x.value === v)
  return o ? o.label : v
}
function typeTag(v) {
  const o = typeOptions.find((x) => x.value === v)
  return o?.tag || 'info'
}
function statusLabel(v) {
  const o = statusOptions.find((x) => x.value === v)
  return o ? o.label : v
}
function statusTag(v) {
  const o = statusOptions.find((x) => x.value === v)
  return o?.tag || 'info'
}
function formatImages(v) {
  const c = Array.isArray(v) ? v.length : Number(v) || 0
  return c > 0 ? c + ' 个附件' : '-'
}

const ids = ref([])

function getList() {
  loading.value = true
  listFeedback(queryParams.value)
    .then((r) => {
      feedbackList.value = r.rows
      total.value = r.total
      loading.value = false
    })
    .catch((err) => {
      console.error('查询反馈列表失败:', err)
      loading.value = false
    })
}
function handleQuery() {
  queryParams.value.pageNum = 1
  getList()
}
function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}
function handleDetail(row) {
  detailRow.value = row
  detailOpen.value = true
}
function handleProcess(row) {
  handleForm.value = {
    feedbackId: row.feedbackId,
    status: '1',
    reply: undefined
  }
  handleOpen.value = true
}
function handleStatusChange() {
  if (proxy.$refs['handleRef']) proxy.$refs['handleRef'].clearValidate('reply')
}
function submitHandle() {
  proxy.$refs['handleRef'].validate((v) => {
    if (v) {
      handleFeedback({
        feedbackId: handleForm.value.feedbackId,
        status: handleForm.value.status,
        reply: handleForm.value.reply
      })
        .then(() => {
          proxy.$modal.msgSuccess('处理成功')
          handleOpen.value = false
          getList()
        })
        .catch((err) => {
          console.error('处理反馈失败:', err)
        })
    }
  })
}

getList()
</script>

<style lang="scss" scoped>
.list-page {
  .stat-bar {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
    margin-bottom: 16px;
  }
  .stat-item {
    display: flex;
    align-items: center;
    background: #fff;
    padding: 16px 24px;
    border-radius: 8px;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
    border: 1px solid #ebeef5;
    transition: all 0.3s ease;
    &:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(0, 0, 0, 0.08);
    }
  }
  .stat-num {
    font-size: 32px;
    font-weight: 700;
    line-height: 1;
    margin-right: 12px;
    &.blue {
      color: #136bfd;
    }
    &.primary {
      color: #136bfd;
    }
    &.green {
      color: #22c55e;
    }
  }
  .stat-label {
    font-size: 14px;
    color: #86909c;
    font-weight: 500;
  }

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
  .dialog-footer {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
  }
  .desc-table {
    margin-bottom: 0;
  }
}
</style>
