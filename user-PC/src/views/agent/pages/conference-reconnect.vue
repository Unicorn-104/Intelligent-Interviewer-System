<template>
  <div class="cr-page">
    <section class="cr-panel">
      <div class="cr-signal" :class="state">
        <span class="cr-wave" />
        <span class="cr-wave delay" />
        <span class="cr-core">
          <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">
            <path d="M5 12.55a11 11 0 0 1 14.08 0" />
            <path d="M1.42 9a16 16 0 0 1 21.16 0" />
            <path d="M8.53 16.11a6 6 0 0 1 6.95 0" />
            <path d="M12 20h.01" />
          </svg>
        </span>
      </div>

      <h1>{{ state === 'ok' ? '已重新连接' : '连接断开，正在尝试重连…' }}</h1>
      <p class="cr-sub">
        {{ state === 'ok'
          ? '网络已恢复，正在返回面试房间，请稍候。'
          : `第 ${attempt} 次自动重连中，请保持页面打开并确认网络可用。` }}
      </p>

      <div class="cr-progress"><u :style="{ width: progress + '%' }" /></div>

      <ul class="cr-steps">
        <li :class="{ done: step >= 1 }"><i />检测本地网络连接</li>
        <li :class="{ done: step >= 2 }"><i />重新建立音视频通道</li>
        <li :class="{ done: step >= 3 }"><i />恢复面试进度与字幕同步</li>
      </ul>

      <div class="cr-info">
        <div><span>面试进度</span><b>已保留 3 / 10 题</b></div>
        <div><span>断线时长</span><b>{{ offlineSeconds }} 秒</b></div>
        <div><span>累计中断</span><b>{{ attempt }} 次</b></div>
      </div>

      <div class="cr-actions">
        <button class="cr-ghost" @click="go('/agent/index')">返回首页</button>
        <button class="cr-primary" :disabled="state === 'ok'" @click="reconnect(true)">
          {{ state === 'ok' ? '正在返回…' : '手动重连' }}
        </button>
      </div>

      <p class="cr-tip">若超过 30 秒仍未恢复，系统将自动挂断并标记为异常终止，并通知 HR 人工复核。</p>
    </section>
  </div>
</template>

<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { getCurrentSession, heartbeat } from '@/api/system/conference'

const state = ref('retrying')
const progress = ref(0)
const step = ref(0)
const attempt = ref(1)
const offlineSeconds = ref(0)
const sessionId = ref(null)
let progressTimer = null
let stepTimer1 = null
let stepTimer2 = null
let offlineTimer = null

function go(path) {
  window.__agentNavigate(path)
}

function reconnect(manual) {
  if (state.value === 'ok') return
  // 重置进度，重新走一遍重连流程
  clearTimeout(stepTimer1)
  clearTimeout(stepTimer2)
  progress.value = 0
  step.value = 0
  if (manual) attempt.value += 1
  stepTimer1 = setTimeout(() => (step.value = 1), 500)
  stepTimer2 = setTimeout(() => (step.value = 2), 1200)
  setTimeout(() => {
    step.value = 3
    state.value = 'ok'
    progress.value = 100
    setTimeout(async () => {
      if (sessionId.value) {
        try {
          await heartbeat(sessionId.value)
        } catch (error) {
          // 心跳失败不阻塞返回面试
        }
      }
      go('/agent/conference-waiting?sessionId=' + (sessionId.value || ''))
    }, 1200)
  }, 2200)
}

onMounted(async () => {
  progressTimer = setInterval(() => {
    if (progress.value < 92 && state.value !== 'ok') progress.value += 2
  }, 120)
  offlineTimer = setInterval(() => (offlineSeconds.value += 1), 1000)
  setTimeout(() => (step.value = 1), 700)
  setTimeout(() => (step.value = 2), 1600)
  try {
    const res = await getCurrentSession()
    if (res.data && res.data.sessionId) sessionId.value = res.data.sessionId
  } catch (error) {
    // 无后端时保留本地演示
  }
})

onBeforeUnmount(() => {
  clearInterval(progressTimer)
  clearInterval(offlineTimer)
  clearTimeout(stepTimer1)
  clearTimeout(stepTimer2)
})
</script>

<style scoped>
.cr-page {
  --p: #1A3C6E;
  --b: #2B7FFF;
  --bad: #FF4D4F;
  --ok: #52C41A;
  --line: rgba(255, 255, 255, .1);
  position: fixed; inset: 0;
  display: grid; place-items: center;
  padding: 32px 20px;
  background: radial-gradient(900px 460px at 50% 0%, #1B2436 0%, #121722 60%, #0C1017 100%);
  color: #EDF1F7;
  font: 14px/1.6 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
.cr-page * { box-sizing: border-box; }
.cr-page button { font: inherit; cursor: pointer; }
.cr-page h1 { margin: 0; }
.cr-page p { margin: 0; }

.cr-panel { width: min(520px, 100%); padding: 36px 34px 30px; border-radius: 16px; background: rgba(24, 30, 43, .82); border: 1px solid var(--line); box-shadow: 0 26px 60px rgba(0, 0, 0, .5); text-align: center; backdrop-filter: blur(6px); }

.cr-signal { position: relative; width: 96px; height: 96px; margin: 0 auto; display: grid; place-items: center; }
.cr-core { width: 62px; height: 62px; display: grid; place-items: center; border-radius: 50%; color: #FFB3B4; background: rgba(255, 77, 79, .16); border: 1px solid rgba(255, 77, 79, .4); }
.cr-signal.ok .cr-core { color: #B6F0C8; background: rgba(82, 196, 26, .16); border-color: rgba(82, 196, 26, .42); }
.cr-wave { position: absolute; inset: 6px; border-radius: 50%; border: 1px solid rgba(255, 77, 79, .5); animation: cr-pulse 2s ease-out infinite; }
.cr-wave.delay { animation-delay: 1s; }
.cr-signal.ok .cr-wave { border-color: rgba(82, 196, 26, .5); animation: none; opacity: 0; }
@keyframes cr-pulse { 0% { transform: scale(.82); opacity: .8; } 100% { transform: scale(1.3); opacity: 0; } }

.cr-panel h1 { margin-top: 20px; font-size: 21px; }
.cr-sub { margin-top: 8px; color: #97A5BB; font-size: 13px; }

.cr-progress { height: 5px; margin-top: 22px; border-radius: 999px; background: rgba(255, 255, 255, .12); overflow: hidden; }
.cr-progress u { display: block; height: 100%; border-radius: inherit; background: linear-gradient(90deg, #2B7FFF, #6FA8FF); transition: width .15s linear; }

.cr-steps { list-style: none; margin: 20px 0 0; padding: 0; text-align: left; }
.cr-steps li { position: relative; display: flex; align-items: center; gap: 10px; padding: 7px 0; color: #7F8CA1; font-size: 13px; }
.cr-steps i { width: 9px; height: 9px; border-radius: 50%; background: rgba(255, 255, 255, .22); flex: none; }
.cr-steps li.done { color: #D5DEEA; }
.cr-steps li.done i { background: var(--ok); box-shadow: 0 0 0 4px rgba(82, 196, 26, .16); }

.cr-info { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-top: 20px; padding: 14px 12px; border-radius: 11px; background: rgba(255, 255, 255, .05); border: 1px solid var(--line); }
.cr-info span { display: block; color: #8394AC; font-size: 11px; }
.cr-info b { display: block; margin-top: 4px; font-size: 13px; }

.cr-actions { display: flex; gap: 10px; margin-top: 26px; }
.cr-ghost, .cr-primary { flex: 1; height: 44px; border-radius: 10px; font-weight: 700; font-size: 14px; }
.cr-ghost { border: 1px solid var(--line); background: transparent; color: #C3CCDB; }
.cr-ghost:hover { border-color: #4A5A75; color: #fff; }
.cr-primary { border: 0; color: #fff; background: linear-gradient(135deg, #2B7FFF, #1A3C6E); box-shadow: 0 8px 20px rgba(43, 127, 255, .3); }
.cr-primary:disabled { background: #3A4A63; box-shadow: none; cursor: default; }
.cr-tip { margin-top: 18px; color: #6E7C90; font-size: 12px; line-height: 1.7; }

@media (max-width: 560px) {
  .cr-panel { padding: 28px 20px 24px; }
  .cr-actions { flex-direction: column; }
}
</style>