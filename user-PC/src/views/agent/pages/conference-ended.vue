<template>
  <div class="ce-page">
    <section class="ce-card">
      <div class="ce-badge">
        <span class="ce-check">
          <svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5" /></svg>
        </span>
      </div>

      <h1>面试已结束</h1>
      <p class="ce-sub">感谢你的参与，本次面试已完成，以下为本次面试的完成情况。</p>

      <div class="ce-stats">
        <div class="ce-stat">
          <span>面试时长</span>
          <b>{{ stats.duration }}</b>
        </div>
        <div class="ce-stat">
          <span>完成题目</span>
          <b>{{ stats.answered }}<span class="ce-slash">/</span>{{ stats.total }}</b>
        </div>
        <div class="ce-stat">
          <span>面试轮次</span>
          <b>{{ stats.round ? `第 ${stats.round} 轮` : '—' }}<span v-if="stats.totalRounds" class="ce-unit">共 {{ stats.totalRounds }} 轮</span></b>
        </div>
      </div>

      <div class="ce-report" :class="reportState">
        <span class="ce-report-icon">
          <svg v-if="reportState === 'generating'" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M21 12a9 9 0 1 1-6.74-8.74" /></svg>
          <svg v-else width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10" /><path d="m9 12 2 2 4-4" /></svg>
        </span>
        <div>
          <strong>{{ reportState === 'generating' ? '正在生成评估报告…' : '评估报告已生成，请等待 HR 审核' }}</strong>
          <small>{{ reportState === 'generating' ? 'AI 正在结合你的回答生成多维度评估，预计 1 分钟内完成' : 'HR 审核通过后，结果会通过站内消息与短信通知你' }}</small>
        </div>
        <span class="ce-report-bar"><u :style="{ width: reportPercent + '%' }" /></span>
      </div>

      <div class="ce-meta">
        <div><span>应聘岗位</span><b>{{ meta.positionTitle }}</b></div>
        <div><span>面试模式</span><b>{{ meta.mode }}</b></div>
        <div><span>录制状态</span><b class="ce-rec"><i />已录制并加密存档</b></div>
      </div>

      <div class="ce-actions">
        <button class="ce-ghost" @click="go('/agent/index')">返回首页</button>
        <button class="ce-primary" @click="go('/agent/interview-result')">查看面试记录</button>
      </div>

      <p class="ce-tip">如需补面或对结果有疑问，可通过「消息」联系 HR。</p>
    </section>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { getCurrentSession, getSessionResult } from '@/api/system/conference'

const reportState = ref('generating')
// 报告生成进度由后端结果驱动：未生成 0%，已生成 100%
const reportPercent = ref(0)
const sessionId = ref(null)
// 完成情况与基本信息：全部来自后端真实数据，未取到时展示占位
const stats = ref({ duration: '—', answered: 0, total: 0, round: null, totalRounds: 0 })
const meta = ref({ positionTitle: '—', mode: '—' })

function formatDuration(seconds) {
  const v = Math.max(0, Math.floor(Number(seconds) || 0))
  return `${Math.floor(v / 60)}分${String(v % 60).padStart(2, '0')}秒`
}

function fillStats(data) {
  if (data.durationSeconds != null) stats.value.duration = formatDuration(data.durationSeconds)
  if (data.answeredCount != null) stats.value.answered = data.answeredCount
  if (data.totalQuestionNo) stats.value.total = data.totalQuestionNo
}

function fillMeta(data) {
  if (data.positionTitle) meta.value.positionTitle = data.positionTitle
  if (data.mode != null) meta.value.mode = modeLabel(Number(data.mode))
  if (data.roundNo) stats.value.round = data.roundNo
  if (data.totalRounds) stats.value.totalRounds = data.totalRounds
}

// 面试模式展示文案（1-纯AI，2-AI+单面试官，3-AI+多面试官，4-无AI纯人工）
function modeLabel(mode) {
  switch (mode) {
    case 1: return '纯 AI 面试'
    case 3: return 'AI + 多面试官'
    case 4: return '无 AI · 纯人工'
    default: return 'AI + HR 协同面试'
  }
}

function go(path) {
  window.__agentNavigate(path)
}

onMounted(async () => {
  try {
    const res = await getCurrentSession()
    if (res.data && res.data.sessionId) {
      sessionId.value = res.data.sessionId
      fillMeta(res.data)
    }
  } catch (error) {
    // 后端未就绪时保持占位
  }
  if (!sessionId.value) return
  try {
    const result = await getSessionResult(sessionId.value)
    if (result.data) {
      fillStats(result.data)
      fillMeta(result.data)
      if (result.data.reportStatus === 'ready') {
        reportState.value = 'ready'
        reportPercent.value = 100
      }
    }
  } catch (error) {
    // 后端未就绪时保持「生成中」状态
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
  --soft: #EAF2FF;
  min-height: 100vh;
  display: grid; place-items: center;
  padding: 40px 20px;
  background: radial-gradient(1200px 520px at 50% -10%, #E7F0FF 0%, var(--bg) 58%);
  color: var(--text);
  font: 14px/1.6 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
.ce-page * { box-sizing: border-box; }
.ce-page button { font: inherit; cursor: pointer; }
.ce-page h1 { margin: 0; }
.ce-page p { margin: 0; }

.ce-card { width: min(720px, 100%); padding: 38px 40px 30px; border: 1px solid var(--line); border-radius: 16px; background: #fff; box-shadow: 0 20px 50px rgba(26, 60, 110, .1); text-align: center; animation: ce-rise .3s ease both; }
@keyframes ce-rise { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: none; } }
.ce-badge { display: flex; justify-content: center; }
.ce-check { width: 66px; height: 66px; display: grid; place-items: center; border-radius: 50%; color: #fff; background: linear-gradient(145deg, #34C77B, #1B9A72); box-shadow: 0 10px 24px rgba(27, 154, 114, .32); }
.ce-card h1 { margin-top: 20px; font-size: 26px; color: var(--p); letter-spacing: .4px; }
.ce-sub { margin-top: 8px; color: var(--muted); font-size: 13px; }

.ce-stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-top: 26px; }
.ce-stat { padding: 18px 12px; border-radius: 12px; background: #F7FAFF; border: 1px solid var(--line); }
.ce-stat span { display: block; color: var(--muted); font-size: 12px; }
.ce-stat b { display: block; margin-top: 6px; font-size: 22px; color: var(--p); font-variant-numeric: tabular-nums; }
.ce-slash { color: #B7C4D6; margin: 0 1px; }
.ce-unit { display: block; margin-top: 2px; font-size: 11px; color: var(--muted); font-weight: 400; }

.ce-report { position: relative; overflow: hidden; display: grid; grid-template-columns: 34px 1fr; gap: 12px; align-items: center; margin-top: 18px; padding: 16px 18px 20px; border-radius: 12px; text-align: left; border: 1px solid #CFE3FF; background: var(--soft); }
.ce-report.ready { border-color: #C7EFD9; background: #EFFBF4; }
.ce-report-icon { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 50%; color: var(--b); background: #fff; }
.ce-report.ready .ce-report-icon { color: #1B9A72; }
.ce-report.generating .ce-report-icon svg { animation: ce-spin 1s linear infinite; }
@keyframes ce-spin { to { transform: rotate(360deg); } }
.ce-report strong { display: block; font-size: 14px; color: var(--p); }
.ce-report small { display: block; margin-top: 3px; color: var(--muted); font-size: 12px; }
.ce-report-bar { position: absolute; left: 0; bottom: 0; height: 3px; width: 100%; background: rgba(43, 127, 255, .16); }
.ce-report-bar u { display: block; height: 100%; background: var(--b); transition: width .3s linear; }
.ce-report.ready .ce-report-bar { background: rgba(27, 154, 114, .16); }
.ce-report.ready .ce-report-bar u { background: #1B9A72; }

.ce-meta { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-top: 22px; padding-top: 20px; border-top: 1px dashed var(--line); text-align: left; }
.ce-meta span { display: block; color: var(--muted); font-size: 12px; }
.ce-meta b { display: block; margin-top: 4px; font-size: 13px; }
.ce-rec { display: inline-flex !important; align-items: center; gap: 6px; color: #C34B55 !important; }
.ce-rec i { width: 7px; height: 7px; border-radius: 50%; background: #FF4D4F; }

.ce-actions { display: flex; justify-content: center; gap: 12px; margin-top: 28px; }
.ce-ghost, .ce-primary { height: 44px; padding: 0 24px; border-radius: 10px; font-weight: 700; font-size: 14px; }
.ce-ghost { border: 1px solid var(--line); background: #fff; color: var(--p); }
.ce-ghost:hover { border-color: var(--b); color: var(--b); }
.ce-primary { border: 0; color: #fff; background: linear-gradient(135deg, #2B7FFF, #1A3C6E); box-shadow: 0 8px 20px rgba(43, 127, 255, .26); }
.ce-tip { margin-top: 18px; color: #93A1B2; font-size: 12px; }

@media (max-width: 640px) {
  .ce-card { padding: 28px 20px 24px; }
  .ce-stats, .ce-meta { grid-template-columns: 1fr; }
  .ce-actions { flex-direction: column; }
  .ce-ghost, .ce-primary { width: 100%; }
}
</style>