<template>
  <div class="cj-page">
    <header class="cj-topbar">
      <div class="cj-bar">
        <a class="cj-brand" href="/agent/index"><span class="cj-mark">智</span>智聘 AI</a>
      </div>
    </header>

    <main class="cj-main">
      <section class="cj-card">
        <template v-if="loading">
          <div class="cj-loading">正在校验面试链接…</div>
        </template>

        <template v-else-if="valid">
          <span class="cj-badge">{{ info.modeName || '视频面试' }}邀请</span>
          <h1>{{ info.companyName || '企业' }} · {{ info.positionTitle || '岗位面试' }}</h1>
          <div class="cj-info">
            <div class="cj-row"><span>应聘岗位</span><b>{{ info.positionTitle || '—' }}</b></div>
            <div class="cj-row"><span>面试方式</span><b>{{ info.modeName || '—' }}</b></div>
            <div class="cj-row"><span>面试时间</span><b>{{ timeText }}</b></div>
            <div class="cj-row"><span>面试官</span><b>{{ interviewerText }}</b></div>
          </div>
          <p class="cj-tip">{{ info.expiresTip || '面试结束前均可通过本链接进入' }}</p>
          <p v-if="info.mode === 1" class="cj-tip">本场为纯 AI 面试，无人工面试官，登录后即可直接开始。</p>
          <div class="cj-actions">
            <button class="cj-primary" @click="asCandidate">以求职者身份登录并进入</button>
            <button class="cj-ghost" @click="asInterviewer">我是面试官 / HR</button>
          </div>
        </template>

        <template v-else>
          <span class="cj-badge warn">{{ finished ? '面试已结束' : '链接无效' }}</span>
          <h1>{{ finished ? '本场面试已结束' : '面试链接无效或已失效' }}</h1>
          <p class="cj-tip">{{ info?.expiresTip || '请确认链接是否完整，或联系面试官重新获取邀请链接。' }}</p>
        </template>
      </section>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { verifyRoomToken } from '@/api/system/conference'

const route = useRoute()
const router = useRouter()
const token = ref('')
const loading = ref(true)
const info = ref(null)

const valid = computed(() => info.value?.valid === true)
const finished = computed(() => info.value?.reason === 'finished')
// 纯 AI 面试没有人工面试官，避免把发起人误展示为面试官
const interviewerText = computed(() => (info.value?.mode === 1 ? 'AI 面试官（无人工面试官）' : (info.value?.interviewerName || '—')))
const timeText = computed(() => {
  const start = info.value?.appointmentStartAt
  if (!start) return '待定'
  const end = info.value?.appointmentEndAt
  return end ? `${start} - ${end.split(' ')[1] || ''}` : start
})

function asCandidate() {
  router.push('/agent/conference-entry?token=' + encodeURIComponent(token.value))
}

function asInterviewer() {
  const base = import.meta.env.VITE_ENTERPRISE_APP_URL || ''
  window.location.href = base + '/enterprise/conference/join?token=' + encodeURIComponent(token.value)
}

onMounted(async () => {
  token.value = route.query.token || ''
  if (!token.value) {
    loading.value = false
    return
  }
  try {
    const res = await verifyRoomToken(token.value)
    info.value = res?.data || { valid: false, reason: 'invalid' }
  } catch (error) {
    info.value = { valid: false, reason: 'invalid' }
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.cj-page {
  --p: #1A3C6E;
  --b: #2B7FFF;
  --bg: #F5F7FA;
  --text: #172B4D;
  --muted: #6B7A90;
  --line: #E6EBF2;
  min-height: 100vh;
  background: var(--bg);
  color: var(--text);
  font: 14px/1.6 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
.cj-page * { box-sizing: border-box; }
.cj-page button { font: inherit; cursor: pointer; }
.cj-page h1 { margin: 0; }

.cj-topbar { height: 72px; display: flex; align-items: center; background: #fff; border-bottom: 1px solid var(--line); }
.cj-bar { width: min(1120px, calc(100% - 48px)); margin: auto; }
.cj-brand { display: flex; align-items: center; gap: 10px; color: var(--p); font-size: 18px; font-weight: 800; text-decoration: none; }
.cj-mark { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 9px; color: #fff; background: linear-gradient(145deg, #2B7FFF, #1A3C6E); }

.cj-main { display: grid; place-items: center; padding: 48px 24px; }
.cj-card { width: min(520px, 100%); padding: 32px; border: 1px solid var(--line); border-radius: 14px; background: #fff; box-shadow: 0 12px 34px rgba(26, 60, 110, .08); text-align: center; }
.cj-loading { padding: 40px 0; color: var(--muted); }
.cj-badge { display: inline-block; padding: 4px 10px; border-radius: 999px; color: var(--b); background: #EAF2FF; font-size: 12px; font-weight: 700; }
.cj-badge.warn { color: #C98A00; background: #FFF7E6; }
.cj-card h1 { margin-top: 14px; font-size: 20px; color: var(--p); }
.cj-info { margin-top: 20px; text-align: left; }
.cj-row { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 11px 0; border-bottom: 1px dashed var(--line); }
.cj-row:last-child { border-bottom: 0; }
.cj-row span { color: var(--muted); font-size: 13px; }
.cj-row b { font-weight: 600; font-size: 13px; text-align: right; }
.cj-tip { margin-top: 16px; color: var(--muted); font-size: 12px; }
.cj-actions { display: grid; gap: 10px; margin-top: 22px; }
.cj-primary, .cj-ghost { height: 46px; border-radius: 10px; font-size: 15px; font-weight: 700; }
.cj-primary { border: 0; color: #fff; background: linear-gradient(135deg, #2B7FFF, #1A3C6E); box-shadow: 0 8px 20px rgba(43, 127, 255, .26); }
.cj-ghost { border: 1px solid var(--line); background: #fff; color: var(--p); }
.cj-ghost:hover { border-color: var(--b); color: var(--b); }
</style>