<template>
  <div class="app-container">
    <!-- 统计卡 -->
    <el-row :gutter="16" class="mb16">
      <el-col :span="6" v-for="card in stats" :key="card.label">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-num" :style="{color: card.color}">{{ card.value }}</div>
          <div class="stat-label">{{ card.label }}</div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 搜索区 -->
    <el-card shadow="never" class="mb16">
      <el-form :inline="true" :model="query" @submit.prevent="handleQuery">
        <el-form-item label="关键词">
          <el-input v-model="query.keyword" placeholder="候选人/企业" clearable @keyup.enter="handleQuery" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="query.status" placeholder="全部" clearable>
            <el-option label="待确认" value="0" />
            <el-option label="已接受" value="1" />
            <el-option label="已拒绝" value="2" />
            <el-option label="已过期" value="3" />
            <el-option label="草稿" value="4" />
            <el-option label="审批中" value="5" />
            <el-option label="已撤回" value="6" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleQuery">搜索</el-button>
          <el-button @click="resetQuery">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 表格 -->
    <el-card shadow="never">
      <el-table v-loading="loading" :data="list" stripe>
        <el-table-column label="候选人" prop="tal_name" width="120" />
        <el-table-column label="手机号" prop="tal_phone" width="130" />
        <el-table-column label="应聘岗位" prop="pos_title" min-width="150" show-overflow-tooltip />
        <el-table-column label="企业" prop="cmp_name" min-width="150" show-overflow-tooltip />
        <el-table-column label="Offer薪资" prop="ofr_salary_offer" width="120" />
        <el-table-column label="截止日期" prop="ofr_deadline" width="170">
          <template #default="{row}">{{ formatDate(row.ofr_deadline) }}</template>
        </el-table-column>
        <el-table-column label="入职日期" prop="ofr_onboard_date" width="120" />
        <el-table-column label="审批状态" width="100">
          <template #default="{row}">
            <el-tag :type="approvalType(row.ofr_approval_status)">{{ approvalText(row.ofr_approval_status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{row}">
            <el-tag :type="offerType(row.ofr_status)">{{ offerText(row.ofr_status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{row}">
            <el-button v-if="row.ofr_approval_status === 0" type="text" size="small" @click="approve(row, 2)">通过</el-button>
            <el-button v-if="row.ofr_approval_status === 0" type="text" size="small" style="color:#f56c6c" @click="approve(row, 3)">拒绝</el-button>
            <el-button v-if="row.ofr_status === 0" type="text" size="small" style="color:#e6a23c" @click="withdraw(row)">撤回</el-button>
          </template>
        </el-table-column>
      </el-table>
      <pagination v-show="total>0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="getList" />
    </el-card>
  </div>
</template>

<script setup name="OfferManage">
import { ref, reactive, onMounted, computed, getCurrentInstance } from 'vue'
import request from '@/utils/request'
const { proxy } = getCurrentInstance()

const list = ref([])
const loading = ref(false)
const total = ref(0)
const query = reactive({ pageNum: 1, pageSize: 10, keyword: '', status: '' })

const stats = computed(() => [
  { label: '全部Offer', value: list.value.length, color: '#409EFF' },
  { label: '待审批', value: list.value.filter(r => r.ofr_approval_status === 0).length, color: '#E6A23C' },
  { label: '已通过', value: list.value.filter(r => r.ofr_approval_status === 2).length, color: '#67C23A' },
  { label: '已撤回', value: list.value.filter(r => r.ofr_status === 6).length, color: '#F56C6C' },
])

function getList() {
  loading.value = true
  request({ url: '/biz/offer/list', method: 'get', params: query }).then(res => {
    list.value = res.rows || []
    total.value = res.total || 0
  }).finally(() => loading.value = false)
}

function handleQuery() { query.pageNum = 1; getList() }
function resetQuery() { query.keyword=''; query.status=''; handleQuery() }

// 状态口径与 enterprise_pc 一致：
// ofr_approval_status 0-待审批 1-审批中 2-已通过 3-已拒绝
// ofr_status 0-待确认(已发送) 1-已接受 2-已拒绝 3-已过期 4-草稿 5-审批中 6-已撤回
function approvalText(s) { return ['待审批','审批中','已通过','已拒绝'][s] || '未知' }
function approvalType(s) { return ['warning','primary','success','danger'][s] || 'info' }
function offerText(s) { return ['待确认','已接受','已拒绝','已过期','草稿','审批中','已撤回'][s] || '未知' }
function offerType(s) { return ['primary','success','danger','info','info','warning','danger'][s] || 'info' }
function formatDate(d) { return d ? d.replace('T',' ').substring(0,16) : '-' }

function approve(row, status) {
  proxy.$modal.confirm(`确认${status===2?'通过':'拒绝'}该Offer？`).then(() => {
    request({ url: `/biz/offer/approve/${row.ofr_id}`, method: 'put', params: { status } }).then(() => {
      proxy.$modal.msgSuccess('操作成功'); getList()
    })
  }).catch(()=>{})
}

function withdraw(row) {
  proxy.$prompt('请输入撤回原因', '撤回Offer', { confirmButtonText: '确定', cancelButtonText: '取消' }).then(({value}) => {
    request({ url: `/biz/offer/withdraw/${row.ofr_id}`, method: 'put', params: { reason: value } }).then(() => {
      proxy.$modal.msgSuccess('已撤回'); getList()
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
