<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="模板名称" prop="templateName">
        <el-input
          v-model="queryParams.templateName"
          placeholder="请输入模板名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="发送渠道" prop="channel">
        <el-select v-model="queryParams.channel" placeholder="请选择发送渠道" clearable style="width: 200px">
          <el-option v-for="item in channelOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="消息类型" prop="msgType">
        <el-select v-model="queryParams.msgType" placeholder="请选择消息类型" clearable style="width: 200px">
          <el-option v-for="item in msgTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
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
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['msg:template:add']"
          >新增模板</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="templateList">
      <el-table-column label="ID" align="center" prop="templateId" width="70" />
      <el-table-column label="模板名称" align="center" prop="templateName" :show-overflow-tooltip="true" />
      <el-table-column label="模板编码" align="center" prop="templateCode" :show-overflow-tooltip="true" />
      <el-table-column label="渠道" align="center" width="100">
        <template #default="scope">
          <el-tag :type="channelTag(scope.row.channel)">{{ channelLabel(scope.row.channel) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="类型" align="center" width="110">
        <template #default="scope">
          <el-tag :type="msgTypeTag(scope.row.msgType)">{{ msgTypeLabel(scope.row.msgType) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="变量" align="center" width="220">
        <template #default="scope">
          <template v-if="scope.row.variables && scope.row.variables.length > 0">
            <el-tag
              v-for="(item, index) in scope.row.variables"
              :key="index"
              size="small"
              type="info"
              class="variable-tag"
              >{{ item }}</el-tag
            >
          </template>
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column label="内容" align="center" prop="content" :show-overflow-tooltip="true" />
      <el-table-column label="状态" align="center" width="90">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="更新时间" align="center" prop="updateTime" width="170" />
      <el-table-column label="操作" align="center" width="150" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="View" @click="handlePreview(scope.row)">预览</el-button>
          <el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['msg:template:edit']"
            >修改</el-button
          >
          <el-button
            link
            type="primary"
            icon="Delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['msg:template:remove']"
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

    <!-- 添加或修改消息模板对话框 -->
    <el-dialog :title="title" v-model="open" width="700px" append-to-body>
      <el-form ref="templateRef" :model="form" :rules="rules" label-width="110px">
        <el-row>
          <el-col :span="12">
            <el-form-item label="模板名称" prop="templateName">
              <el-input v-model="form.templateName" placeholder="请输入模板名称" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="模板编码" prop="templateCode">
              <el-input v-model="form.templateCode" placeholder="请输入模板编码，如：OFFER_EMAIL" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="发送渠道" prop="channel">
              <el-select v-model="form.channel" placeholder="请选择发送渠道" style="width: 100%">
                <el-option v-for="item in channelOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="消息类型" prop="msgType">
              <el-select v-model="form.msgType" placeholder="请选择消息类型" style="width: 100%">
                <el-option v-for="item in msgTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="模板变量" prop="variables">
              <el-select
                v-model="form.variables"
                multiple
                filterable
                allow-create
                default-first-option
                placeholder="输入变量名后回车，如：候选人姓名"
                style="width: 100%"
              />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item prop="content" label-width="130px">
              <template #label>
                <div class="content-label">
                  <div>模板内容</div>
                  <div class="form-tip">内容中可用 ${变量名} 引用变量</div>
                </div>
              </template>
              <el-input v-model="form.content" type="textarea" :rows="5" placeholder="请输入模板内容" />
            </el-form-item>
          </el-col>
        </el-row>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitForm">确 定</el-button>
          <el-button @click="cancel">取 消</el-button>
        </div>
      </template>
    </el-dialog>
    <!-- 模板预览对话框 -->
    <el-dialog title="模板预览" v-model="previewOpen" width="600px" append-to-body>
      <el-descriptions :column="1" border>
        <el-descriptions-item label="模板名称">{{ previewRow.templateName }}</el-descriptions-item>
        <el-descriptions-item label="渠道">{{ channelLabel(previewRow.channel) }}</el-descriptions-item>
      </el-descriptions>
      <el-divider content-position="left">渲染效果（变量以示例值替换）</el-divider>
      <div class="preview-text">{{ previewText }}</div>
    </el-dialog>
  </div>
</template>

<script setup name="MsgTemplate">
import { listTemplate, getTemplate, addTemplate, updateTemplate, delTemplate } from '@/api/msg/template'

const { proxy } = getCurrentInstance()

const templateList = ref([])
const open = ref(false)
const loading = ref(true)
const ids = ref([])
const showSearch = ref(true)
const total = ref(0)
const title = ref('')

// 发送渠道选项
const channelOptions = [
  { value: 'sms', label: '短信', tag: 'primary' },
  { value: 'email', label: '邮件', tag: 'success' },
  { value: 'site', label: '站内', tag: 'info' }
]

// 消息类型选项
const msgTypeOptions = [
  { value: '0', label: '面试提醒', tag: 'warning' },
  { value: '1', label: '面试结果', tag: 'primary' },
  { value: '2', label: '录用通知', tag: 'success' },
  { value: '3', label: '淘汰关怀', tag: 'info' },
  { value: '4', label: '体验调研', tag: 'primary' },
  { value: '5', label: '系统公告', tag: 'danger' }
]

// 状态选项（DB：1启用 0停用）
const statusOptions = [
  { value: '1', label: '启用', tag: 'success' },
  { value: '0', label: '停用', tag: 'info' }
]

const data = reactive({
  form: {
    templateId: undefined,
    templateName: undefined,
    templateCode: undefined,
    channel: undefined,
    msgType: undefined,
    variables: [],
    content: undefined,
    status: '1'
  },
  queryParams: {
    pageNum: 1,
    pageSize: 10,
    templateName: undefined,
    channel: undefined,
    msgType: undefined,
    status: undefined
  },
  rules: {
    templateName: [{ required: true, message: '模板名称不能为空', trigger: 'blur' }],
    templateCode: [{ required: true, message: '模板编码不能为空', trigger: 'blur' }],
    channel: [{ required: true, message: '发送渠道不能为空', trigger: 'change' }],
    msgType: [{ required: true, message: '消息类型不能为空', trigger: 'change' }]
  }
})

const { form, queryParams } = toRefs(data)

/** 查询消息模板列表 */
function getList() {
  loading.value = true
  listTemplate(data.queryParams)
    .then((response) => {
      templateList.value = response.rows
      total.value = response.total
      loading.value = false
    })
    .catch((err) => {
      console.error('查询消息模板列表失败:', err)
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

/** 表单重置 */
function reset() {
  data.form = {
    templateId: undefined,
    templateName: undefined,
    templateCode: undefined,
    channel: undefined,
    msgType: undefined,
    variables: [],
    content: undefined,
    status: '1'
  }
  proxy.resetForm('templateRef')
}

/** 新增按钮操作 */
function handleAdd() {
  reset()
  open.value = true
  title.value = '添加消息模板'
}

/** 修改按钮操作 */
function handleUpdate(row) {
  reset()
  const templateId = row.templateId || data.form.templateId
  getTemplate(templateId)
    .then((response) => {
      data.form = response.data
      open.value = true
      title.value = '修改消息模板'
    })
    .catch((err) => {
      console.error('查询消息模板详情失败:', err)
    })
}

/** 提交按钮 */
function submitForm() {
  proxy.$refs['templateRef'].validate((valid) => {
    if (valid) {
      if (data.form.templateId != undefined) {
        updateTemplate(data.form)
          .then(() => {
            proxy.$modal.msgSuccess('修改成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error('修改消息模板失败:', err)
          })
      } else {
        addTemplate(data.form)
          .then(() => {
            proxy.$modal.msgSuccess('新增成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error('新增消息模板失败:', err)
          })
      }
    }
  })
}

/** 删除按钮操作 */
function handleDelete(row) {
  const templateIds = row.templateId || ids.value
  proxy.$modal
    .confirm('是否确认删除消息模板编号为"' + templateIds + '"的数据项？')
    .then(function () {
      return delTemplate(templateIds)
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(() => {})
}

// Channel helpers
function channelLabel(val) {
  const item = channelOptions.find((o) => o.value === val)
  return item ? item.label : val
}
function channelTag(val) {
  const item = channelOptions.find((o) => o.value === val)
  return item && item.tag ? item.tag : 'info'
}

/** 消息类型标签 */
function msgTypeLabel(val) {
  const item = msgTypeOptions.find((o) => o.value === val)
  return item ? item.label : val
}
function msgTypeTag(val) {
  const item = msgTypeOptions.find((o) => o.value === val)
  return item && item.tag ? item.tag : 'info'
}

/** 状态显示 */
function statusLabel(val) {
  const item = statusOptions.find((o) => o.value === val)
  return item ? item.label : val
}
function statusTag(val) {
  const item = statusOptions.find((o) => o.value === val)
  return item && item.tag ? item.tag : 'danger'
}

/** 模板预览：将 ${变量} 以示例值替换后渲染 */
const previewOpen = ref(false)
const previewRow = ref({})
const previewText = ref('')
const PREVIEW_SAMPLE = {
  candidate_name: '张三',
  candidate: '张三',
  name: '张三',
  position_name: 'Java高级工程师',
  position: 'Java高级工程师',
  company: '本公司',
  phone: '13800000000',
  email: 'zhang@example.com',
  date: '2026-10-22',
  time: '14:00',
  interview_link: 'https://example.com/interview'
}
function handlePreview(row) {
  previewRow.value = row
  let text = row.content || ''
  text = text.replace(/\$\{([^}]+)\}/g, (_, key) => PREVIEW_SAMPLE[key.trim()] ?? `【${key.trim()}】`)
  previewText.value = text
  previewOpen.value = true
}

getList()
</script>

<style lang="scss" scoped>
.app-container {
  .variable-tag {
    margin: 2px 4px 2px 0;
  }
  .preview-text {
    white-space: pre-wrap;
    line-height: 1.8;
    padding: 12px;
    background: #f7f8fa;
    border-radius: 6px;
  }
  .content-label {
    line-height: 1.4;
    .form-tip {
      display: block;
      margin-top: 2px;
      color: #909399;
      font-size: 12px;
      font-weight: normal;
    }
  }
}
</style>
