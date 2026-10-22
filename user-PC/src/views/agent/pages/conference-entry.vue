<template>
  <div class="ce-page">
    <section class="ce-card">
      <template v-if="status === 'loading'">
        <div class="ce-loading">正在校验面试身份…</div>
      </template>

      <template v-else>
        <span class="ce-badge">无法进入</span>
        <h1>链接无效或您不是本场面试的候选人</h1>
        <p class="ce-tip">请确认您使用的是面试官发给您的专属链接，并以本人候选人账号登录。</p>
        <button class="ce-primary" @click="goWorkbench">返回工作台</button>
      </template>
    </section>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { joinByRoomToken } from '@/api/system/conference'
import { getToken } from '@/utils/auth'

const route = useRoute()
const router = useRouter()
const status = ref('loading')

function goWorkbench() {
  router.replace('/agent/index')
}

onMounted(async () => {
  const token = route.query.token || ''
  if (!token) {
    status.value = 'error'
    return
  }
  // 面试链接不允许绕过身份校验直接进入准备页：未登录时先登录，登录后回到本页按链接校验候选人身份
  if (!getToken()) {
    router.replace({ path: '/agent/login', query: { redirect: route.fullPath } })
    return
  }
  try {
    const res = await joinByRoomToken(token)
    const sessionId = res?.data?.sessionId
    if (!sessionId) {
      status.value = 'error'
      return
    }
    router.replace('/agent/conference-prep?sessionId=' + sessionId)
  } catch (error) {
    status.value = 'error'
  }
})
</script>

<style scoped>
.ce-page {
  --p: #1A3C6E;
  --b: #2B7FFF;
  --bg: #F5F7FA;
  --text: #172B4D;
  --muted: #6B7A90;
  --line: #E6EBF2;
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 40px 24px;
  background: var(--bg);
  color: var(--text);
  font: 14px/1.6 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
.ce-page * { box-sizing: border-box; }
.ce-page h1 { margin: 0; }

.ce-card { width: min(520px, 100%); padding: 36px 32px; border: 1px solid var(--line); border-radius: 14px; background: #fff; box-shadow: 0 12px 34px rgba(26, 60, 110, .08); text-align: center; }
.ce-loading { padding: 40px 0; color: var(--muted); }
.ce-badge { display: inline-block; padding: 4px 10px; border-radius: 999px; color: #C98A00; background: #FFF7E6; font-size: 12px; font-weight: 700; }
.ce-card h1 { margin-top: 14px; font-size: 20px; color: var(--p); }
.ce-tip { margin-top: 14px; color: var(--muted); font-size: 13px; }
.ce-primary { width: 100%; height: 46px; margin-top: 24px; border: 0; border-radius: 10px; color: #fff; font-size: 15px; font-weight: 700; background: linear-gradient(135deg, #2B7FFF, #1A3C6E); box-shadow: 0 8px 20px rgba(43, 127, 255, .26); cursor: pointer; }
</style>