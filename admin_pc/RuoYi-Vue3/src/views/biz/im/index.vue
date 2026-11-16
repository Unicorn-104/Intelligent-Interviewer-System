<template>
  <div class="app-container">
    <el-row :gutter="16">
      <!-- 会话列表 -->
      <el-col :span="10">
        <el-card shadow="never">
          <template #header><span>会话列表</span></template>
          <el-table v-loading="loading" :data="sessions" highlight-current-row @current-change="selectSession">
            <el-table-column label="用户A" prop="user_a" width="100" />
            <el-table-column label="用户B" prop="user_b" width="100" />
            <el-table-column label="最后消息" prop="ims_last_message" show-overflow-tooltip />
            <el-table-column label="时间" prop="ims_last_message_at" width="150">
              <template #default="{row}">{{ formatDt(row.ims_last_message_at) }}</template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>

      <!-- 消息详情 -->
      <el-col :span="14">
        <el-card shadow="never">
          <template #header>
            <span>{{ current ? `对话详情 - ${current.user_a} ↔ ${current.user_b}` : '选择会话查看详情' }}</span>
          </template>
          <div v-if="current" class="msg-list">
            <div v-for="msg in messages" :key="msg.imsg_id" class="msg-item" :class="msg.imsg_sender_id === current.ims_user_a_id ? 'left' : 'right'">
              <div class="msg-bubble">{{ msg.imsg_content }}</div>
              <div class="msg-time">{{ formatDt(msg.imsg_created_at) }}</div>
            </div>
            <el-empty v-if="messages.length === 0" description="无消息" />
          </div>
          <el-empty v-else description="请选择左侧会话" />
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup name="ImRecords">
import { ref, onMounted } from 'vue'
import request from '@/utils/request'

const sessions = ref([])
const messages = ref([])
const current = ref(null)
const loading = ref(false)

function getSessions() {
  loading.value = true
  request({ url: '/biz/im/sessions', method: 'get' }).then(res => {
    sessions.value = res.rows || []
  }).finally(() => loading.value = false)
}

function selectSession(row) {
  if (!row) return
  current.value = row
  request({ url: `/biz/im/messages/${row.ims_id}`, method: 'get' }).then(res => {
    messages.value = res.data || []
  })
}

function formatDt(d) { return d ? d.replace('T',' ').substring(0,16) : '-' }

onMounted(getSessions)
</script>

<style scoped>
.msg-list { max-height: 500px; overflow-y: auto; padding: 10px; }
.msg-item { margin-bottom: 15px; }
.msg-item.left { text-align: left; }
.msg-item.right { text-align: right; }
.msg-bubble { display: inline-block; padding: 10px 14px; border-radius: 8px; max-width: 70%; word-break: break-all; }
.msg-item.left .msg-bubble { background: #f4f4f5; }
.msg-item.right .msg-bubble { background: #ecf5ff; }
.msg-time { font-size: 12px; color: #909399; margin-top: 4px; }
</style>
