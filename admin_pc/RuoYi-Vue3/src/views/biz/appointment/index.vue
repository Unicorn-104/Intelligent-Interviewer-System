<template>
  <div class="app-container">
    <el-row :gutter="16" class="mb16">
      <el-col :span="6" v-for="card in stats" :key="card.label">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-num" :style="{color: card.color}">{{ card.value }}</div>
          <div class="stat-label">{{ card.label }}</div>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never" class="mb16">
      <el-form :inline="true" :model="query" @submit.prevent="handleQuery">
        <el-form-item label="日期">
          <el-date-picker v-model="query.date" type="date" placeholder="选择日期" value-format="YYYY-MM-DD" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="query.status" placeholder="全部" clearable>
            <el-option label="待确认" value="0" />
            <el-option label="已确认" value="1" />
            <el-option label="已取消" value="2" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleQuery">搜索</el-button>
          <el-button @click="resetQuery">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never">
      <el-table v-loading="loading" :data="list" stripe>
        <el-table-column label="候选人" prop="tal_name" width="120" />
        <el-table-column label="手机号" prop="tal_phone" width="130" />
        <el-table-column label="岗位" prop="pos_title" min-width="150" show-overflow-tooltip />
        <el-table-column label="企业" prop="cmp_name" min-width="120" show-overflow-tooltip />
        <el-table-column label="面试阶段" prop="apt_stage_name" width="100" />
        <el-table-column label="开始时间" prop="apt_start_time" width="170">
          <template #default="{row}">{{ formatDt(row.apt_start_time) }}</template>
        </el-table-column>
        <el-table-column label="结束时间" prop="apt_end_time" width="170">
          <template #default="{row}">{{ formatDt(row.apt_end_time) }}</template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{row}">
            <el-tag :type="statusType(row.apt_status)">{{ statusText(row.apt_status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{row}">
            <el-button v-if="row.apt_status === 0" type="text" size="small" style="color:#67c23a" @click="confirm(row)">确认</el-button>
            <el-button v-if="row.apt_status === 0" type="text" size="small" style="color:#f56c6c" @click="cancel(row)">取消</el-button>
          </template>
        </el-table-column>
      </el-table>
      <pagination v-show="total>0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="getList" />
    </el-card>
  </div>
</template>

<script setup name="AppointmentManage">
import { ref, reactive, onMounted, computed, getCurrentInstance } from 'vue'
import request from '@/utils/request'
const { proxy } = getCurrentInstance()

const list = ref([])
const loading = ref(false)
const total = ref(0)
const query = reactive({ pageNum: 1, pageSize: 10, date: '', status: '' })

const stats = computed(() => [
  { label: '全部预约', value: list.value.length, color: '#409EFF' },
  { label: '待确认', value: list.value.filter(r => r.apt_status === 0).length, color: '#E6A23C' },
  { label: '已确认', value: list.value.filter(r => r.apt_status === 1).length, color: '#67C23A' },
  { label: '已取消', value: list.value.filter(r => r.apt_status === 2).length, color: '#F56C6C' },
])

function getList() {
  loading.value = true
  request({ url: '/biz/schedule/list', method: 'get', params: query }).then(res => {
    list.value = res.rows || []
    total.value = res.total || 0
  }).finally(() => loading.value = false)
}

function handleQuery() { query.pageNum = 1; getList() }
function resetQuery() { query.date=''; query.status=''; handleQuery() }

function statusText(s) { return ['待确认','已确认','已取消'][s] || '未知' }
function statusType(s) { return ['warning','success','danger'][s] || 'info' }
function formatDt(d) { return d ? d.replace('T',' ').substring(0,16) : '-' }

function confirm(row) {
  request({ url: `/biz/schedule/confirm/${row.apt_id}`, method: 'put' }).then(() => {
    proxy.$modal.msgSuccess('已确认'); getList()
  })
}

function cancel(row) {
  proxy.$prompt('取消原因', '取消预约', { inputType: 'textarea' }).then(({value}) => {
    request({ url: `/biz/schedule/cancel/${row.apt_id}`, method: 'put', params: { reason: value } }).then(() => {
      proxy.$modal.msgSuccess('已取消'); getList()
    })
  }).catch(()=>{})
}

onMounted(getList)
</script>

<style scoped>
.stat-card { text-align: center; }
.stat-num { font-size: 28px; font-weight: 700; line-height: 1.2; }
.stat-label { font-size: 13px; color: #909399; margin-top: 4px; }
.mb16 { margin-bottom: 16px; }
</style>
