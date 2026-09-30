<template>
  <div class="cab-page">
    <section class="cab-panel">
      <div class="cab-badge">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z" />
          <path d="M12 9v4" />
          <path d="M12 17h.01" />
        </svg>
      </div>

      <h1>面试已异常终止</h1>
      <p class="cab-sub">{{ reasonInfo.desc }}</p>

      <div class="cab-reason">
        <span class="cab-reason-label">终止原因</span>
        <strong>{{ reasonInfo.title }}</strong>
        <small>{{ reasonInfo.rule }}</small>
      </div>

      <div class="cab-status">
        <div class="cab-status-item done">
          <span class="cab-dot" />
          <div><b>自动挂断</b><small>系统已结束本次会话，未完成题目不计入评分</small></div>
        </div>
        <div class="cab-status-item done">
          <span class="cab-dot" />
          <div><b>已标记「异常终止」</b><small>本次面试状态已更新，不进入自动评估流程</small></div>
        </div>
        <div class="cab-status-item pending">
          <span class="cab-dot" />
          <div><b>已通知 HR 人工复核</b><small>HR 将在 1 个工作日内联系你确认情况并安排后续</small></div>
        </div>
      </div>

      <div class="cab-log">
        <h2>事件记录</h2>
        <ul>
          <li v-for="(item, index) in reasonInfo.logs" :key="index">
            <span>{{ item.time }}</span>
            <p>{{ item.text }}</p>
          </li>
        </ul>
      </div>

      <div class="cab-keep">
        <div><span>已完成题目</span><b>3 / 10</b></div>
        <div><span>有效面试时长</span><b>{{ reasonInfo.duration }}</b></div>
        <div><span>会话编号</span><b>SES-6002</b></div>
      </div>

      <div class="cab-actions">
        <button class="cab-ghost" @click="go('/agent/index')">返回首页</button>
        <button class="cab-primary" @click="go('/agent/interview-schedule')">查看面试安排</button>
      </div>

      <p class="cab-tip">若因网络或设备问题导致中断，可联系 HR 申请重新安排面试，本次记录不会影响你的正常应聘流程。</p>
    </section>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { getCurrentSession, getSessionResult, abortSession } from '@/api/system/conference'

const sessionId = ref(null)
const REASONS = {
  silence: {
    title: '连续 2 分钟未检测到有效语音',
    desc: '为保证面试的完整性，系统在长时间未检测到有效语音后自动挂断了本次面试。',
    rule: '触发规则：无有效语音 > 2 分钟 → 自动挂断',
    duration: '06分12秒',
    logs: [
      { time: '14:33:50', text: '系统提示：已连续 60 秒未检测到有效语音，请确认你在麦克风前作答。' },
      { time: '14:34:50', text: '系统提示：仍未检测到有效语音，若 1 分钟后无响应将自动结束面试。' },
      { time: '14:35:50', text: '连续 2 分钟无有效语音，系统自动挂断本次会话。' },
      { time: '14:35:51', text: '本次面试已标记为「异常终止」，未完成题目不计入评分。' },
      { time: '14:35:52', text: '已通知 HR 进行人工复核。' }
    ]
  },
  offline: {
    title: '网络中断超过 30 秒',
    desc: '你的网络连接长时间未恢复，系统已自动挂断本次面试，避免面试记录持续为空。',
    rule: '触发规则：断网 > 30 秒 → 自动挂断',
    duration: '11分04秒',
    logs: [
      { time: '14:38:02', text: '检测到网络中断，正在尝试自动重连（第 1 次）。' },
      { time: '14:38:12', text: '自动重连失败，正在尝试第 2 次重连。' },
      { time: '14:38:24', text: '自动重连失败，网络已中断 22 秒。' },
      { time: '14:38:32', text: '网络中断超过 30 秒，系统自动挂断本次会话。' },
      { time: '14:38:33', text: '本次面试已标记为「异常终止」，并通知 HR 人工复核。' }
    ]
  }
}

const reasonInfo = computed(() => REASONS[new URLSearchParams(window.location.search).get('reason')] || REASONS.silence)

function go(path) {
  window.__agentNavigate(path)
}

onMounted(async () => {
  try {
    const res = await getCurrentSession()
    if (res.data && res.data.sessionId) sessionId.value = res.data.sessionId
  } catch (error) {
    // 无后端时保留本地演示
  }
  if (!sessionId.value) return
  try {
    const result = await getSessionResult(sessionId.value)
    // 仅当后端尚未标记异常终止时才写入，避免重复提交
    if (result.data && result.data.status !== 3) {
      const reason = new URLSearchParams(window.location.search).get('reason')
      await abortSession(sessionId.value, reason === 'offline' ? 'offline' : 'silence')
    }
  } catch (error) {
    // 终止上报失败静默
  }
})
</script>

<style scoped>
.cab-page {
  --p: #1A3C6E;
  --b: #2B7FFF;
  --warn: #FAAD14;
  --bad: #FF4D4F;
  --ok: #52C41A;
  --line: rgba(255, 255, 255, .1);
  position: fixed; inset: 0;
  display: grid; place-items: center;
  padding: 32px 20px;
  overflow-y: auto;
  background: radial-gradient(900px 460px at 50% 0%, #2A1A1E 0%, #171B24 58%, #0C1017 100%);
  color: #EDF1F7;
  font: 14px/1.6 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
.cab-page * { box-sizing: border-box; }
.cab-page button { font: inherit; cursor: pointer; }
.cab-page h1, .cab-page h2 { margin: 0; }
.cab-page p { margin: 0; }
.cab-page ul { margin: 0; padding: 0; list-style: none; }

.cab-panel { width: min(640px, 100%); padding: 34px 34px 28px; border-radius: 16px; background: rgba(24, 30, 43, .86); border: 1px solid var(--line); box-shadow: 0 26px 60px rgba(0, 0, 0, .5); text-align: center; backdrop-filter: blur(6px); }

.cab-badge { display: flex; justify-content: center; }
.cab-badge svg { width: 60px; height: 60px; padding: 15px; border-radius: 50%; color: #FFB3B4; background: rgba(255, 77, 79, .16); border: 1px solid rgba(255, 77, 79, .4); }
.cab-panel h1 { margin-top: 18px; font-size: 23px; }
.cab-sub { margin-top: 8px; color: #97A5BB; font-size: 13px; line-height: 1.75; }

.cab-reason { margin-top: 22px; padding: 15px 16px; border-radius: 12px; text-align: left; background: rgba(250, 173, 20, .12); border: 1px solid rgba(250, 173, 20, .3); }
.cab-reason-label { display: inline-block; padding: 2px 8px; border-radius: 5px; background: rgba(250, 173, 20, .22); color: #FFD591; font-size: 11px; font-weight: 700; }
.cab-reason strong { display: block; margin-top: 8px; font-size: 15px; }
.cab-reason small { display: block; margin-top: 4px; color: #FFD591; font-size: 12px; }

.cab-status { display: grid; gap: 10px; margin-top: 18px; text-align: left; }
.cab-status-item { display: grid; grid-template-columns: 12px 1fr; gap: 11px; align-items: center; padding: 12px 14px; border-radius: 10px; background: rgba(255, 255, 255, .05); border: 1px solid var(--line); }
.cab-status-item b { display: block; font-size: 13px; }
.cab-status-item small { display: block; margin-top: 2px; color: #8394AC; font-size: 12px; }
.cab-dot { width: 10px; height: 10px; border-radius: 50%; background: var(--ok); box-shadow: 0 0 0 4px rgba(82, 196, 26, .16); }
.cab-status-item.pending .cab-dot { background: var(--warn); box-shadow: 0 0 0 4px rgba(250, 173, 20, .18); animation: cab-blink 1.4s infinite; }
@keyframes cab-blink { 0%, 100% { opacity: 1; } 50% { opacity: .35; } }

.cab-log { margin-top: 18px; padding: 16px; border-radius: 12px; background: rgba(255, 255, 255, .04); border: 1px solid var(--line); text-align: left; }
.cab-log h2 { font-size: 13px; color: #97A5BB; font-weight: 600; }
.cab-log ul { margin-top: 10px; display: grid; gap: 9px; }
.cab-log li { display: grid; grid-template-columns: 62px 1fr; gap: 10px; align-items: start; }
.cab-log li span { color: #6E7C90; font-size: 12px; font-variant-numeric: tabular-nums; padding-top: 1px; }
.cab-log li p { color: #C3CCDB; font-size: 12px; line-height: 1.65; }

.cab-keep { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-top: 18px; padding: 14px 12px; border-radius: 11px; background: rgba(255, 255, 255, .05); border: 1px solid var(--line); }
.cab-keep span { display: block; color: #8394AC; font-size: 11px; }
.cab-keep b { display: block; margin-top: 4px; font-size: 13px; }

.cab-actions { display: flex; gap: 10px; margin-top: 24px; }
.cab-ghost, .cab-primary { flex: 1; height: 44px; border-radius: 10px; font-weight: 700; font-size: 14px; }
.cab-ghost { border: 1px solid var(--line); background: transparent; color: #C3CCDB; }
.cab-ghost:hover { border-color: #4A5A75; color: #fff; }
.cab-primary { border: 0; color: #fff; background: linear-gradient(135deg, #2B7FFF, #1A3C6E); box-shadow: 0 8px 20px rgba(43, 127, 255, .3); }
.cab-tip { margin-top: 16px; color: #6E7C90; font-size: 12px; line-height: 1.7; }

@media (max-width: 560px) {
  .cab-panel { padding: 26px 20px 22px; }
  .cab-keep { grid-template-columns: 1fr; }
  .cab-actions { flex-direction: column; }
}
</style>