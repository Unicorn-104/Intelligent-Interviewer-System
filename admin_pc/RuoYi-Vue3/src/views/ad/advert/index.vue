<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="广告标题" prop="title">
        <el-input
          v-model="queryParams.title"
          placeholder="请输入广告标题"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="所属广告位" prop="slotId">
        <el-select v-model="queryParams.slotId" placeholder="请选择广告位" clearable style="width: 200px">
          <el-option v-for="item in slotOptions" :key="item.slotId" :label="item.slotName" :value="item.slotId" />
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
        <el-button type="primary" plain icon="Plus" @click="handleAdd" v-hasPermi="['ad:advert:add']"
          >新增广告</el-button
        >
      </el-col>
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="advertList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="50" align="center" />
      <el-table-column label="广告标题" align="center" prop="title" :show-overflow-tooltip="true" />
      <el-table-column label="所属广告位" align="center" width="180">
        <template #default="scope">
          <el-tag>{{ scope.row.slotName }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="广告类型" align="center" width="100">
        <template #default="scope">
          <el-tag :type="adTypeTag(scope.row.adType)">{{ adTypeLabel(scope.row.adType) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="投放端" align="center" width="110">
        <template #default="scope">
          <el-tag :type="targetTag(scope.row.target)">{{ targetLabel(scope.row.target) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="投放时间" align="center" width="170">
        <template #default="scope">
          <div>{{ scope.row.startTime }}</div>
          <div>{{ scope.row.endTime }}</div>
        </template>
      </el-table-column>
      <el-table-column label="曝光次数" align="center" width="110">
        <template #default="scope">
          <span>{{ formatThousand(scope.row.exposure) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="点击次数" align="center" width="110">
        <template #default="scope">
          <span>{{ formatThousand(scope.row.clicks) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="点击率" align="center" prop="ctr" width="90" />
      <el-table-column label="状态" align="center" width="90">
        <template #default="scope">
          <el-tag :type="statusTag(scope.row.status)">{{ statusLabel(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="230" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="Edit" @click="handleUpdate(scope.row)" v-hasPermi="['ad:advert:edit']"
            >编辑</el-button
          >
          <el-button
            v-if="scope.row.status === '1'"
            link
            type="warning"
            icon="VideoPause"
            @click="handleToggleStatus(scope.row)"
            v-hasPermi="['ad:advert:edit']"
            >暂停</el-button
          >
          <el-button
            v-if="scope.row.status === '2'"
            link
            type="success"
            icon="VideoPlay"
            @click="handleToggleStatus(scope.row)"
            v-hasPermi="['ad:advert:edit']"
            >恢复</el-button
          >
          <el-button
            link
            type="primary"
            icon="DataAnalysis"
            @click="handleData(scope.row)"
            v-hasPermi="['ad:advert:query']"
            >数据</el-button
          >
          <el-button
            link
            type="primary"
            icon="Delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['ad:advert:remove']"
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

    <!-- 添加或修改广告对话框 -->
    <el-dialog :title="title" v-model="open" width="900px" append-to-body>
      <el-form ref="advertRef" :model="form" :rules="rules" label-width="110px">
        <el-divider content-position="left">基本信息</el-divider>
        <el-row>
          <el-col :span="12">
            <el-form-item label="广告标题" prop="title">
              <el-input v-model="form.title" placeholder="请输入广告标题" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="所属广告位" prop="slotId">
              <el-select v-model="form.slotId" placeholder="请选择广告位" style="width: 100%">
                <el-option v-for="item in slotOptions" :key="item.slotId" :label="item.slotName" :value="item.slotId" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="广告类型" prop="adType">
              <el-radio-group v-model="form.adType" @change="handleAdTypeChange">
                <el-radio value="image">图片</el-radio>
                <el-radio value="video">视频</el-radio>
                <el-radio value="rich">富文本</el-radio>
              </el-radio-group>
            </el-form-item>
          </el-col>
        </el-row>

        <el-divider content-position="left">素材上传</el-divider>
        <el-form-item label="素材文件">
          <el-upload v-model:file-list="fileList" drag action="#" :auto-upload="false" :accept="uploadAccept">
            <el-icon class="el-icon--upload"><upload-filled /></el-icon>
            <div class="el-upload__text">将文件拖到此处，或<em>点击上传</em></div>
            <template #tip>
              <div class="el-upload__tip">{{ uploadTip }}</div>
            </template>
          </el-upload>
          <el-input
            v-if="form.adType === 'rich'"
            v-model="form.richContent"
            type="textarea"
            :rows="4"
            placeholder="请填写富文本内容"
            class="rich-input"
          />
        </el-form-item>

        <el-divider content-position="left">跳转配置</el-divider>
        <el-row>
          <el-col :span="24">
            <el-form-item label="跳转类型" prop="jumpType">
              <el-radio-group v-model="form.jumpType">
                <el-radio value="none">无跳转</el-radio>
                <el-radio value="h5">H5链接</el-radio>
                <el-radio value="miniapp">小程序页面</el-radio>
                <el-radio value="app">App内页面</el-radio>
              </el-radio-group>
            </el-form-item>
          </el-col>
          <el-col v-if="form.jumpType !== 'none'" :span="12">
            <el-form-item label="跳转地址" prop="jumpUrl">
              <el-input v-model="form.jumpUrl" :placeholder="jumpUrlPlaceholder" />
            </el-form-item>
          </el-col>
        </el-row>

        <el-divider content-position="left">投放设置</el-divider>
        <el-row>
          <el-col :span="24">
            <el-form-item label="投放时间">
              <el-date-picker
                v-model="timeRange"
                type="datetimerange"
                value-format="YYYY-MM-DD HH:mm:ss"
                range-separator="至"
                start-placeholder="开始时间"
                end-placeholder="结束时间"
                style="width: 100%"
              />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="每日展示频次">
              <el-input-number v-model="form.dailyLimit" :min="0" :max="100000" />
              <span class="form-tip">单个用户每日最多展示次数</span>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="总曝光上限">
              <el-input-number v-model="form.totalLimit" :min="0" :max="99999999" />
              <span class="form-tip">0 表示不限</span>
            </el-form-item>
          </el-col>
        </el-row>

        <el-divider content-position="left">定向投放（可选）</el-divider>
        <el-form-item label="目标套餐" prop="packageTarget">
          <el-checkbox-group v-model="form.packageTarget">
            <el-checkbox value="basic">仅基础版</el-checkbox>
            <el-checkbox value="pro">仅专业版</el-checkbox>
            <el-checkbox value="flag">仅旗舰版</el-checkbox>
          </el-checkbox-group>
          <span class="form-tip">不选则对所有套餐生效</span>
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitForm">确 定</el-button>
          <el-button @click="cancel">取 消</el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 广告数据对话框 -->
    <el-dialog
      title="广告数据"
      v-model="statsOpen"
      width="900px"
      append-to-body
      @opened="handleStatsOpened"
      @closed="handleStatsClosed"
    >
      <el-row :gutter="16" class="stat-cards">
        <el-col :span="8">
          <div class="stat-card">
            <div class="stat-label">累计曝光</div>
            <div class="stat-value">
              {{ formatThousand(statsRow.exposure) }}
            </div>
          </div>
        </el-col>
        <el-col :span="8">
          <div class="stat-card">
            <div class="stat-label">累计点击</div>
            <div class="stat-value">{{ formatThousand(statsRow.clicks) }}</div>
          </div>
        </el-col>
        <el-col :span="8">
          <div class="stat-card">
            <div class="stat-label">点击率</div>
            <div class="stat-value">{{ statsRow.ctr || '-' }}</div>
          </div>
        </el-col>
      </el-row>
      <el-row :gutter="16">
        <el-col :span="12">
          <div ref="exposureChartRef" class="stat-chart"></div>
        </el-col>
        <el-col :span="12">
          <div ref="clickChartRef" class="stat-chart"></div>
        </el-col>
      </el-row>
    </el-dialog>
  </div>
</template>

<script setup name="AdAdvert">
import { listAdvert, getAdvert, addAdvert, updateAdvert, delAdvert, changeAdvertStatus } from '@/api/ad/advert'
import { listAdSlot } from '@/api/ad/slot'
import { ElMessage } from 'element-plus'
import { getCurrentInstance } from 'vue'

const { proxy } = getCurrentInstance()

const advertList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const ids = ref([])
const single = ref(true)
const multiple = ref(true)
const total = ref(0)
const open = ref(false)
const title = ref('')
const form = ref({})
const queryParams = ref({ pageNum: 1, pageSize: 10, title: undefined, slotId: undefined, status: undefined })
const timeRange = ref([])
const fileList = ref([])
const slotOptions = ref([])

/** 查询广告列表 */
function getList() {
  loading.value = true
  listAdvert(queryParams.value)
    .then((response) => {
      advertList.value = response.rows
      total.value = response.total
    })
    .catch((err) => {
      console.error('广告列表查询失败:', err)
    })
    .finally(() => {
      loading.value = false
    })
}

/** 查询广告位下拉选项 */
function getSlotOptions() {
  listAdSlot({ pageNum: 1, pageSize: 100 }).then((response) => {
    slotOptions.value = response.rows || []
  })
}

/** 取消按钮 */
function cancel() {
  open.value = false
  reset()
}

/** 表单重置 */
function reset() {
  form.value = {
    advertId: undefined,
    title: undefined,
    slotId: undefined,
    adType: 'image',
    mediaUrl: undefined,
    richContent: undefined,
    jumpType: 'none',
    jumpUrl: undefined,
    dailyLimit: 0,
    totalLimit: 0,
    packageTarget: [],
    status: '0'
  }
  timeRange.value = []
  fileList.value = []
  proxy.resetForm('advertRef')
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

/** 新增按钮操作 */
function handleAdd() {
  reset()
  open.value = true
  title.value = '新增广告'
}

/** 广告类型切换时清空已选素材 */
function handleAdTypeChange() {
  fileList.value = []
}

/** 编辑按钮操作 */
function handleUpdate(row) {
  reset()
  getAdvert(row.advertId)
    .then((response) => {
      const res = response.data || response
      form.value = {
        advertId: res.advertId,
        title: res.title,
        slotId: res.slotId,
        adType: res.adType || 'image',
        mediaUrl: res.mediaUrl,
        richContent: res.richContent,
        jumpType: res.jumpType || 'none',
        jumpUrl: res.jumpUrl,
        dailyLimit: res.dailyLimit != undefined ? res.dailyLimit : 0,
        totalLimit: res.totalLimit != undefined ? res.totalLimit : 0,
        packageTarget: res.packageTarget || [],
        status: res.status
      }
      if (res.startTime && res.endTime) {
        timeRange.value = [res.startTime, res.endTime]
      }
      open.value = true
      title.value = '修改广告'
    })
    .catch((err) => {
      console.error('广告详情查询失败:', err)
    })
}

/** 提交按钮 */
function submitForm() {
  proxy.$refs['advertRef'].validate((valid) => {
    if (valid) {
      const submitData = Object.assign({}, form.value)
      if (timeRange.value && timeRange.value.length === 2) {
        submitData.startTime = timeRange.value[0]
        submitData.endTime = timeRange.value[1]
      }
      if (form.value.advertId != undefined) {
        updateAdvert(submitData)
          .then(() => {
            proxy.$modal.msgSuccess('修改成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error('修改广告失败:', err)
          })
      } else {
        addAdvert(submitData)
          .then(() => {
            proxy.$modal.msgSuccess('新增成功')
            open.value = false
            getList()
          })
          .catch((err) => {
            console.error('新增广告失败:', err)
          })
      }
    }
  })
}

/** 删除按钮操作 */
function handleDelete(row) {
  const advertId = row.advertId
  proxy.$modal
    .confirm('是否确认删除广告编号为"' + advertId + '"的数据项？')
    .then(function () {
      return delAdvert(advertId)
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess('删除成功')
    })
    .catch(() => {})
}

/** 暂停 / 恢复投放 */
function handleToggleStatus(row) {
  const pausing = row.status === '1'
  const text = pausing ? '暂停' : '恢复'
  proxy.$modal
    .confirm('是否确认' + text + '广告「' + row.title + '」？')
    .then(() => {
      return changeAdvertStatus(row.advertId, pausing ? '2' : '1')
    })
    .then(() => {
      getList()
      proxy.$modal.msgSuccess(text + '成功')
    })
    .catch(() => {})
}

/** 多选框选中数据 */
function handleSelectionChange(selection) {
  ids.value = selection.map((item) => item.advertId)
}
const statusOptions = [
  { value: '1', label: '进行中' },
  { value: '2', label: '暂停' },
  { value: '3', label: '已结束' }
]
const statsOpen = ref(false)
const exposureChartRef = ref(null)
const clickChartRef = ref(null)
const statsRow = ref({})
const adTypeOptions = [
  { value: 'banner', label: '横幅广告', tag: 'primary' },
  { value: 'popup', label: '弹窗广告', tag: 'warning' },
  { value: 'float', label: '悬浮广告', tag: 'success' },
  { value: 'native', label: '原生广告', tag: '' }
]
const targetOptions = [
  { value: 'pc', label: 'PC端', tag: 'info' },
  { value: 'mobile', label: '移动端', tag: 'warning' },
  { value: 'all', label: '全端', tag: 'success' }
]
function statusLabel(val) {
  const m = { 1: '进行中', 2: '暂停', 3: '已结束' }
  return m[val] || val
}
function statusTag(val) {
  const m = { 1: 'success', 2: 'warning', 3: 'info' }
  return m[val] || ''
}
function adTypeLabel(val) {
  const m = { banner: '横幅', popup: '弹窗', float: '悬浮', native: '原生' }
  return m[val] || val
}
function adTypeTag(val) {
  const item = adTypeOptions.find((o) => o.value === val)
  return item?.tag || ''
}
function targetLabel(val) {
  const item = targetOptions.find((o) => o.value === val)
  return item ? item.label : val
}
function targetTag(val) {
  const item = targetOptions.find((o) => o.value === val)
  return item?.tag || ''
}
function formatThousand(n) {
  if (n === null || n === undefined || n === '') return '-'
  return Number(n).toLocaleString('en-US')
}
function handleData(row) {
  statsRow.value = row
  statsOpen.value = true
}
function handleStatsOpened() {
  // initialize charts here
}
function handleStatsClosed() {
  statsRow.value = {}
}
const uploadAccept = ref('.jpg,.jpeg,.png,.gif,.bmp,.webp')
const uploadTip = ref('支持常见图片格式及PDF文档')
function jumpUrlPlaceholder() {
  const t = form.value.jumpType
  if (t === 'h5') return '请输入H5链接地址'
  if (t === 'miniapp') return '请输入小程序页面路径'
  if (t === 'app') return '请输入App内页面路由'
  return ''
}
</script>

<style lang="scss" scoped>
.app-container {
  .stat-cards {
    margin-bottom: 16px;
  }
  .stat-card {
    padding: 16px;
    text-align: center;
    border: 1px solid #ebeef5;
    border-radius: 4px;
    .stat-label {
      color: #909399;
      font-size: 13px;
    }
    .stat-value {
      margin-top: 8px;
      font-size: 24px;
      font-weight: 600;
      color: #303133;
    }
  }
  .stat-chart {
    width: 100%;
    height: 280px;
  }
  .form-tip {
    margin-left: 8px;
    color: #909399;
    font-size: 12px;
  }
  .rich-input {
    margin-top: 8px;
    width: 100%;
  }
}
</style>
