<script setup>
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { joinByRoomToken } from '@/api/system/conference'

const route = useRoute()
const router = useRouter()
// loading：正在校验；error：链接无效或当前账号不是本场面试的面试官
const status = ref('loading')

onMounted(async () => {
  const token = route.query.token
  if (!token) {
    status.value = 'error'
    return
  }
  try {
    const res = await joinByRoomToken(token)
    const sessionId = res.data && res.data.sessionId
    if (!sessionId) {
      status.value = 'error'
      return
    }
    // 带 query 一律用字符串形式，避免 Vue Router 不解析 path 里的 ?
    router.replace('/enterprise/conference/prep?sessionId=' + sessionId)
  } catch (error) {
    status.value = 'error'
  }
})
</script>

<template>
  <div class="cj-page">
    <section class="cj-card">
      <template v-if="status === 'loading'">
        <span class="cj-spinner" />
        <h1>正在校验面试链接…</h1>
        <p>请稍候，正在为您进入面试准备页</p>
      </template>
      <template v-else>
        <h1>无法进入面试</h1>
        <p>链接无效或您不是本场面试的面试官</p>
        <button class="cj-back" @click="router.replace('/enterprise/messages')">返回消息中心</button>
      </template>
    </section>
  </div>
</template>

<style scoped>
.cj-page {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
  background: #f5f7fa;
  color: #172b4d;
  font: 14px/1.6 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
.cj-card {
  width: min(420px, 100%);
  padding: 36px 28px;
  text-align: center;
  background: #fff;
  border: 1px solid #e6ebf2;
  border-radius: 14px;
  box-shadow: 0 12px 32px rgba(26, 60, 110, .08);
}
.cj-card h1 { margin: 0; font-size: 18px; }
.cj-card p { margin: 10px 0 0; color: #6b7a90; font-size: 13px; }
.cj-spinner {
  display: block;
  width: 34px; height: 34px;
  margin: 0 auto 16px;
  border: 3px solid #e6ebf2;
  border-top-color: #2b7fff;
  border-radius: 50%;
  animation: cj-spin .8s linear infinite;
}
@keyframes cj-spin { to { transform: rotate(360deg); } }
.cj-back {
  margin-top: 20px;
  height: 38px; padding: 0 20px;
  border: 0; border-radius: 9px;
  background: #2b7fff; color: #fff;
  font: inherit; font-weight: 600;
  cursor: pointer;
}
</style>