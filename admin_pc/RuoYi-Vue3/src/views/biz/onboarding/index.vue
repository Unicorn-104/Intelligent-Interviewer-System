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
        <el-form-item label="关键词">
          <el-input v-model="query.keyword" placeholder="候选人/企业" clearable @keyup.enter="handleQuery" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="query.status" placeholder="全部" clearable>
            <el-option label="待入职" value="0" />
            <el-option label="已入职" value="1" />
            <el-option label="已逾期" value="2" />
            <el-option label="已取消" value="3" />
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
        <el-table-column label="企业" prop="cmp_name" min-width="150" show-overflow-tooltip />
        <el-table-column label="预计入职日" prop="obd_expected_onboard_date" width="120" />
        <el-table-column label="跟进记录" prop="obd_followup_record" min-width="200" show-overflow-tooltip />
        <el-table-column label="状态" width="100">
          <template #default="{row}">
            <el-tag :type="statusType(row.obd_status)">{{ statusText(row.obd_status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{row}">
            <el-button type="text" size="small" @click="followup(row)">跟进</el-button>
            <el-button v-if="row.obd_status === 0" type="text" size="small" style="color:#67c23a" @click="confirm(row)">确认入职</el-button>
          </template>
        </el-table-column>
      </el-table>
      <pagination v-show="total>0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="getList" />
    </el-card>
  </div>
</template>

<script setup name="OnboardingManage">
import { ref, reactive, onMounted, computed, getCurrentInstance } from 'vue'
import request from '@/utils/request'
const { proxy } = getCurrentInstance()

const list = ref([])
const loading = ref(false)
const total = ref(0)
const query = reactive({ pageNum: 1, pageSize: 10, keyword: '', status: '' })

const stats = computed(() => [
  { label: '全部', value: list.value.length, color: '#409EFF' },
  { label: '待入职', value: list.value.filter(r => r.obd_status === 0).length, color: '#E6A23C' },
  { label: '已入职', value: list.value.filter(r => r.obd_status === 1).length, color: '#67C23A' },
  { label: '已逾期', value: list.value.filter(r => r.obd_status === 2).length, color: '#F56C6C' },
])

function getList() {
  loading.value = true
  request({ url: '/biz/onboarding/list', method: 'get', params: query }).then(res => {
    list.value = res.rows || []
    total.value = res.total || 0
  }).finally(() => loading.value = false)
}

function handleQuery() { query.pageNum = 1; getList() }
function resetQuery() { query.keyword=''; query.status=''; handleQuery() }

function statusText(s) { return ['待入职','已入职','已逾期','已取消'][s] || '未知' }
function statusType(s) { return ['warning','success','danger','info'][s] || 'info' }

function followup(row) {
  proxy.$prompt('输入跟进记录', '跟进', { inputType: 'textarea', inputValue: row.obd_followup_record || '' }).then(({value}) => {
    request({ url: `/biz/onboarding/status/${row.obd_id}`, method: 'put', params: { status: row.obd_status, followup: value } }).then(() => {
      proxy.$modal.msgSuccess('已保存'); getList()
    })
  }).catch(()=>{})
}

function confirm(row) {
  proxy.$modal.confirm(`确认 ${row.tal_name} 已入职？`).then(() => {
    request({ url: `/biz/onboarding/status/${row.obd_id}`, method: 'put', params: { status: 1 } }).then(() => {
      proxy.$modal.msgSuccess('已确认入职'); getList()
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
