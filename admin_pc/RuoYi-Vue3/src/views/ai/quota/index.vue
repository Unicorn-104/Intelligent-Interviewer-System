<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" v-show="showSearch">
      <el-form-item label="企业名称" prop="companyName">
        <el-input
          v-model="queryParams.companyName"
          placeholder="请输入企业名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item label="模型名称" prop="modelName">
        <el-input
          v-model="queryParams.modelName"
          placeholder="请输入模型名称"
          clearable
          style="width: 200px"
          @keyup.enter="handleQuery"
        />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <right-toolbar v-model:showSearch="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="quotaList">
      <el-table-column
        label="企业名称"
        align="center"
        prop="companyName"
        :show-overflow-tooltip="true"
        min-width="200"
      />
      <el-table-column label="模型名称" align="center" prop="modelName" :show-overflow-tooltip="true" min-width="150" />
      <el-table-column label="月度配额" align="center" prop="monthlyQuota" width="100" />
      <el-table-column label="已用数量" align="center" prop="used" width="100" />
      <el-table-column label="剩余数量" align="center" width="100">
        <template #default="scope">
          <span>{{ scope.row.monthlyQuota - scope.row.used }}</span>
        </template>
      </el-table-column>
      <el-table-column label="使用率" align="center" min-width="160">
        <template #default="scope">
          <el-progress :percentage="barPercent(scope.row)" :status="progressStatus(scope.row)" :stroke-width="10" />
          <div class="percent-text">{{ usagePercent(scope.row) }}%</div>
        </template>
      </el-table-column>
      <el-table-column label="重置日期" align="center" prop="resetDate" width="120" />
      <el-table-column label="操作" align="center" width="170" class-name="small-padding fixed-width">
        <template #default="scope">
          <el-button link type="primary" icon="Edit" @click="handleAdjust(scope.row)" v-hasPermi="['ai:quota:edit']"
            >调整配额</el-button
          >
          <el-button link type="info" icon="View" @click="handleUsage(scope.row)" v-hasPermi="['ai:quota:list']"
            >查看明细</el-button
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

    <!-- 调整配额对话框 -->
    <el-dialog title="调整配额" v-model="adjustOpen" width="520px" append-to-body>
      <div class="quota-summary">
        当前配额：<span class="quota-num">{{ adjustRow.monthlyQuota }}</span> 次，已用数量：<span class="quota-num">{{
          adjustRow.used
        }}</span>
        次，剩余数量：<span class="quota-num">{{ adjustRow.monthlyQuota - adjustRow.used }}</span>
        次
      </div>
      <el-form ref="adjustRef" :model="adjustForm" :rules="adjustRules" label-width="90px">
        <el-form-item label="新配额" prop="newQuota">
          <el-input-number
            v-model="adjustForm.newQuota"
            :min="adjustRow.used"
            :step="100"
            controls-position="right"
            style="width: 220px"
          />
        </el-form-item>
        <el-form-item label="调整原因" prop="reason">
          <el-input v-model="adjustForm.reason" type="textarea" :rows="3" placeholder="请输入调整原因" />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="submitAdjust">确 定</el-button>
          <el-button @click="adjustOpen = false">取 消</el-button>
        </div>
      </template>
    </el-dialog>

    <!-- 使用明细对话框 -->
    <el-dialog :title="usageTitle" v-model="usageOpen" width="860px" append-to-body @closed="handleUsageClosed">
      <div ref="chartRef" class="usage-chart"></div>
    </el-dialog>
  </div>
</template>

<script setup name="AiQuota">
import { nextTick } from 'vue'
import * as echarts from 'echarts'
import { listQuota, adjustQuota, usageDetail } from '@/api/ai/quota'

const { proxy } = getCurrentInstance()

const quotaList = ref([])
const loading = ref(true)
const showSearch = ref(true)
const total = ref(0)

const adjustOpen = ref(false)
const adjustRow = ref({})
const adjustForm = reactive({
  newQuota: 0,
  reason: ''
})
const adjustRules = {
  newQuota: [{ required: true, message: '新配额不能为空', trigger: 'blur' }],
  reason: [{ required: true, message: '调整原因不能为空', trigger: 'blur' }]
}

const usageOpen = ref(false)
const usageTitle = ref('')
const usageDaily = ref([])
const chartRef = ref(null)
let chartInstance = null

const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  companyName: undefined,
  modelName: undefined
})

/** 使用率百分比（真实值，可能大于100） */
function usagePercent(row) {
  if (!row.monthlyQuota) {
    return 0
  }
  return Math.round((row.used / row.monthlyQuota) * 100)
}

/** 进度条百分比（封顶100，避免组件告警） */
function barPercent(row) {
  return Math.min(100, usagePercent(row))
}

/** 进度条状态：大于80警告，大于100异常 */
function progressStatus(row) {
  const percent = usagePercent(row)
  if (percent > 100) {
    return 'exception'
  }
  if (percent > 80) {
    return 'warning'
  }
  return undefined
}

/** 查询配额列表 */
function getList() {
  loading.value = true
  listQuota(queryParams.value)
    .then((response) => {
      quotaList.value = response.rows
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
  queryParams.value.pageNum = 1
  getList()
}

/** 重置按钮操作 */
function resetQuery() {
  proxy.resetForm('queryRef')
  handleQuery()
}

/** 调整配额按钮操作 */
function handleAdjust(row) {
  adjustRow.value = row
  adjustForm.newQuota = row.monthlyQuota
  adjustForm.reason = ''
  adjustOpen.value = true
  nextTick(() => {
    if (proxy.$refs['adjustRef']) {
      proxy.$refs['adjustRef'].clearValidate()
    }
  })
}

/** 提交调整配额 */
function submitAdjust() {
  proxy.$refs['adjustRef'].validate((valid) => {
    if (valid) {
      if (adjustForm.newQuota === null || adjustForm.newQuota === undefined) {
        proxy.$modal.msgError('请输入新配额')
        return
      }
      if (adjustForm.newQuota < adjustRow.value.used) {
        proxy.$modal.msgError('新配额不能小于已用数量')
        return
      }
      loading.value = true
      adjustQuota({
        quotaId: adjustRow.value.quotaId,
        newQuota: adjustForm.newQuota,
        reason: adjustForm.reason
      })
        .then(() => {
          proxy.$modal.msgSuccess('配额已调整')
          adjustOpen.value = false
          getList()
        })
        .catch((err) => {
          console.error(err)
          proxy?.$msgError?.('操作失败') || proxy?.$message?.error('操作失败')
        })
        .finally(() => {
          loading.value = false
        })
    }
  })
}

/** 查看明细按钮操作 */
function handleUsage(row) {
  usageTitle.value = row.companyName + ' - ' + row.modelName + ' 近30天每日调用量'
  usageDetail(row.quotaId)
    .then((res) => {
      usageDaily.value = (res.data && res.data.daily) || []
      usageOpen.value = true
      nextTick(() => {
        initChart()
      })
    })
    .catch((err) => {
      console.error(err)
      proxy?.$msgError?.('操作失败') || proxy?.$message?.error('操作失败')
    })
    .finally(() => {
      loading.value = false
    })
}

/** 初始化柱状图 */
function initChart() {
  if (!chartRef.value) {
    return
  }
  if (chartInstance) {
    chartInstance.dispose()
    chartInstance = null
  }
  chartInstance = echarts.init(chartRef.value)
  chartInstance.setOption({
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' }
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true
    },
    xAxis: {
      type: 'category',
      boundaryGap: true,
      data: usageDaily.value.map((item) => item.date),
      axisLabel: { rotate: 45 }
    },
    yAxis: {
      type: 'value',
      minInterval: 1,
      name: '调用次数'
    },
    series: [
      {
        name: '每日调用量',
        type: 'bar',
        barMaxWidth: 28,
        itemStyle: { color: '#409EFF' },
        data: usageDaily.value.map((item) => item.count)
      }
    ]
  })
}

/** 明细对话框关闭时销毁图表实例 */
function handleUsageClosed() {
  if (chartInstance) {
    chartInstance.dispose()
    chartInstance = null
  }
}

getList()
</script>

<style lang="scss" scoped>
.percent-text {
  margin-top: 2px;
  font-size: 12px;
  line-height: 1;
  color: #606266;
}
.quota-summary {
  margin-bottom: 16px;
  padding: 10px 12px;
  font-size: 13px;
  color: #606266;
  background-color: #f5f7fa;
  border-radius: 4px;
}
.quota-num {
  font-weight: 600;
  color: #409eff;
}
.usage-chart {
  width: 100%;
  height: 380px;
}
</style>
