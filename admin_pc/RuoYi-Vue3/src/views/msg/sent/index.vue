<template>
  <div class="app-container">
    <el-form :inline="true">
      <el-form-item label="标题">
        <el-input v-model="query.title" clearable @keyup.enter="load" />
      </el-form-item>
      <el-form-item label="已读">
        <el-select v-model="query.isRead" clearable style="width:100px">
          <el-option label="已读" :value="1" /><el-option label="未读" :value="0" />
        </el-select>
      </el-form-item>
      <el-button type="primary" @click="load">搜索</el-button>
    </el-form>
    <el-table :data="list" v-loading="loading" border size="small">
      <el-table-column label="ID" prop="msg_id" width="70" />
      <el-table-column label="标题" prop="msg_title" show-overflow-tooltip />
      <el-table-column label="接收人" prop="receiver_name" width="120" />
      <el-table-column label="手机号" prop="receiver_phone" width="130" />
      <el-table-column label="类型" prop="msg_type" width="90">
        <template #default="s">
          <el-tag size="small" :type="MSG_TYPE[s.row.msg_type]?.type || 'info'">{{ MSG_TYPE[s.row.msg_type]?.label || '未知' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="状态" width="80">
        <template #default="s">
          <el-tag size="small" :type="s.row.msg_is_read===1?'success':'info'">{{ s.row.msg_is_read===1?'已读':'未读' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="发送时间" prop="msg_created_at" width="160" />
    </el-table>
    <pagination v-show="total>0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="load" />
  </div>
</template>

<script setup name="MsgSent">
import request from '@/utils/request'
const list = ref([])
const total = ref(0)
const loading = ref(false)
const query = ref({ title: '', isRead: null, pageNum: 1, pageSize: 20 })
const MSG_TYPE = {
  1: { label: '面试通知', type: 'primary' },
  2: { label: '录用通知', type: 'success' },
  3: { label: '简历投递', type: 'warning' },
  4: { label: '企业动态', type: 'info' }
}
function load() {
  loading.value = true
  request({ url: '/admin/msg/sent/list', method: 'get', params: query.value })
    .then((r) => { list.value = r.rows; total.value = r.total })
    .finally(() => (loading.value = false))
}
onMounted(load)
</script>
