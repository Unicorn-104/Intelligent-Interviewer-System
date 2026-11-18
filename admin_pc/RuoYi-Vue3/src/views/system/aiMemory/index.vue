<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryRef" :inline="true" label-width="80px">
      <el-form-item label="用户ID" prop="userId">
        <el-input v-model="queryParams.userId" placeholder="用户ID" clearable style="width:150px" />
      </el-form-item>
      <el-form-item label="记忆类型" prop="memoryType">
        <el-select v-model="queryParams.memoryType" placeholder="全部" clearable style="width:150px">
          <el-option label="工作经历" value="work" />
          <el-option label="教育背景" value="education" />
          <el-option label="技能特长" value="skill" />
          <el-option label="求职偏好" value="preference" />
          <el-option label="个人信息" value="personal" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
        <el-button icon="Refresh" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-table v-loading="loading" :data="list" border stripe>
      <el-table-column label="用户ID" prop="userId" width="90" align="center" />
      <el-table-column label="记忆类型" prop="memoryType" width="110" align="center">
        <template #default="scope">
          <el-tag size="small" type="info">{{ typeLabel(scope.row.memoryType) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="记忆内容" prop="content" min-width="300" show-overflow-tooltip />
      <el-table-column label="状态" prop="status" width="90" align="center">
        <template #default="scope">
          <el-tag size="small" :type="scope.row.status === 'ACTIVE' ? 'success' : 'danger'">
            {{ scope.row.status === 'ACTIVE' ? '生效中' : '已删除' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="创建时间" prop="createdAt" width="160" align="center">
        <template #default="scope">{{ fmtTime(scope.row.createdAt) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="100" align="center" fixed="right">
        <template #default="scope">
          <el-button link type="danger" icon="Delete" @click="handleDelete(scope.row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <pagination v-show="total > 0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </div>
</template>

<script setup name="AiMemory">
import { ref, reactive, onMounted } from 'vue'
import request from '@/utils/request'

const loading = ref(false)
const list = ref([])
const total = ref(0)

const queryParams = reactive({
  pageNum: 1,
  pageSize: 10,
  userId: '',
  memoryType: ''
})

const TYPE_MAP = {
  work: '工作经历',
  education: '教育背景',
  skill: '技能特长',
  preference: '求职偏好',
  personal: '个人信息'
}

function typeLabel(t) {
  return TYPE_MAP[t] || t || '-'
}

function fmtTime(t) {
  if (!t) return '-'
  return String(t).replace('T', ' ').substring(0, 19)
}

/** 加载AI记忆列表 */
async function getList() {
  loading.value = true
  try {
    const res = await request({
      url: '/system/aiMemory/list',
      method: 'get',
      params: queryParams
    })
    list.value = res.rows || []
    total.value = res.total || 0
  } catch (e) {
    list.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

function handleQuery() {
  queryParams.pageNum = 1
  getList()
}

function resetQuery() {
  queryParams.userId = ''
  queryParams.memoryType = ''
  handleQuery()
}

/** 删除记忆 */
async function handleDelete(row) {
  try {
    await request({
      url: '/system/aiMemory/' + row.id,
      method: 'delete'
    })
    ElMessage.success('删除成功')
    getList()
  } catch (e) {
    ElMessage.error('删除失败')
  }
}

onMounted(() => {
  getList()
})
</script>
