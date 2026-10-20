<template>
  <div class="application-detail-page">
    <AgentTopbar active="applications" />
    <main class="main">
      <div v-if="loading" class="state">正在加载投递详情...</div>
      <div v-else-if="errorMessage" class="state"><strong>投递详情加载失败</strong><span>{{ errorMessage }}</span><div class="state-actions"><button class="primary-button" type="button" @click="loadApplication">重新加载</button><button class="secondary-button" type="button" @click="openApplications">返回投递跟踪</button></div></div>
      <template v-else-if="application">
        <section class="panel job-panel"><a class="breadcrumb" href="/agent/applications"><svg viewBox="0 0 24 24"><path d="m15 18-6-6 6-6" /></svg>投递跟踪 / 投递详情</a><div class="job-row"><div><h1>{{ application.jobTitle }}</h1><div class="job-meta"><strong>{{ application.companyName }}</strong><span>{{ application.locationText }}</span><span>投递于 {{ formatDate(application.appliedAt) }}</span><span>简历：{{ application.resumeName || '本次选择的简历' }}</span></div><span class="salary">{{ application.salaryText }}</span></div><span class="flow-state">{{ application.statusText }}</span></div></section>
        <section class="panel timeline-panel"><div class="panel-head"><h2>投递进度</h2><span>共 {{ timeline.length }} 个流程节点 · 状态由企业处理结果产生</span></div><ol class="timeline"><li v-for="(node, index) in timeline" :key="`${node.stage}-${index}`" class="timeline-item" :class="[nodeClass(node), directionClass(index), connectorClass(index)]" :style="nodeStyle(index)"><span class="dot">{{ nodeClass(node) === 'done' ? '✓' : index + 1 }}</span><div class="timeline-copy"><div class="timeline-title"><span>{{ node.title }}</span><span class="node-state">{{ stateText(node) }}</span></div><div class="timeline-desc">{{ node.description || '该节点暂无补充说明' }}</div><div class="timeline-time">{{ formatDate(node.occurredAt) }}</div></div></li></ol></section>
        <section class="panel info-grid"><div><h2>本次投递</h2><p>使用简历：<strong>{{ application.resumeName || '本次选择的简历' }}</strong></p><p>岗位匹配度：<strong>{{ application.matchedScore || 0 }}%</strong></p><p>最近更新：<strong>{{ formatDate(application.updatedAt) }}</strong></p></div><div><h2>接下来会发生什么</h2><p>企业处理投递后，新的筛选、测评、面试或结果节点会自动出现在上方进度中。</p><button class="secondary-button" type="button" @click="openMessages">去消息通知</button></div></section>
      </template>
    </main>
    <footer class="footer">© 2026 企业级智能招聘面试官 Agent 系统 · 隐私政策 / 用户协议</footer>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { getApplication } from '@/api/agent/application'
import { resolveApplicationId } from '@/utils/agentApplication'

const route = useRoute()
const application = ref(null)
const loading = ref(false)
const errorMessage = ref('')
const timeline = computed(() => application.value?.timeline || [])

async function loadApplication() {
  loading.value = true
  errorMessage.value = ''
  try {
    const applicationId = await resolveApplicationId(route.query.id || route.query.job)
    if (!applicationId) {
      throw new Error('未找到对应的真实投递记录，请从“投递跟踪”中选择具体记录')
    }
    const response = await getApplication(applicationId)
    application.value = response.data
    document.title = `${application.value.jobTitle} · 投递详情`
  } catch (error) {
    errorMessage.value = error?.message || '投递详情暂时无法读取'
  } finally {
    loading.value = false
  }
}

function nodeClass(node) {
  if (node.state === 'closed') return 'closed'
  if (node.state === 'current' || node.state === 'processing') return 'current'
  return node.state === 'done' ? 'done' : ''
}

function stateText(node) {
  if (node.state === 'closed') return '已结束'
  if (node.state === 'current' || node.state === 'processing') return '进行中'
  return node.state === 'done' ? '已完成' : '待处理'
}

function nodeStyle(index) {
  const columns = 3
  const row = Math.floor(index / columns)
  const offset = index % columns
  return { gridColumn: `${row % 2 ? columns - offset : offset + 1}`, gridRow: row + 1 }
}

function directionClass(index) {
  return Math.floor(index / 3) % 2 ? 'snake-backward' : 'snake-forward'
}

function connectorClass(index) {
  if (index >= timeline.value.length - 1) return ''
  return Math.floor(index / 3) !== Math.floor((index + 1) / 3) ? 'snake-turn' : 'snake-next'
}

function formatDate(value) {
  return value ? String(value).replace('T', ' ').slice(0, 16) : '暂无'
}

function openMessages() {
  window.__agentNavigate('/agent/messages')
}

function openApplications() {
  window.__agentNavigate('/agent/applications')
}

onMounted(loadApplication)
</script>

<style scoped>
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}.main{width:min(1240px,calc(100% - 48px));margin:0 auto;padding:18px 0 48px}.panel{border:1px solid #E6EBF2;border-radius:10px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045)}.job-panel{padding:17px 20px}.breadcrumb{display:inline-flex;align-items:center;gap:5px;color:#96A3B5;font-size:11px;text-decoration:none}.breadcrumb svg{width:14px;stroke:currentColor;fill:none;stroke-width:1.8}.job-row{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;margin-top:10px}.job-row h1{margin:0;color:#1A3C6E;font-size:22px;line-height:1.35}.job-meta{display:flex;flex-wrap:wrap;gap:7px 10px;margin-top:8px;color:#6B7A90;font-size:12px}.job-meta strong{color:#1A3C6E}.salary{display:inline-flex;margin-top:12px;padding:5px 12px;border-radius:5px;color:#fff;background:#1A3C6E;font-size:12px;font-weight:800}.flow-state{display:inline-flex;align-items:center;min-height:30px;padding:5px 12px;border-radius:99px;color:#2B7FFF;background:#EAF2FF;font-size:12px;font-weight:700}.timeline-panel{margin-top:14px;padding:20px}.panel-head{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;margin-bottom:14px}.panel-head h2,.info-grid h2{margin:0;color:#1A3C6E;font-size:16px}.panel-head span{color:#96A3B5;font-size:11px}.timeline{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:30px 22px;margin:0;padding:0;list-style:none}.timeline-item{position:relative;display:grid;grid-template-columns:34px minmax(0,1fr);align-items:start;gap:11px;min-height:142px;padding:16px;border:1px solid #E6EBF2;border-radius:10px;background:#fff;box-shadow:0 6px 18px rgba(26,60,110,.045)}.timeline-item.snake-next::after,.timeline-item.snake-turn::after{content:"";display:block;position:absolute;z-index:0;background:#BFD2EC}.timeline-item.snake-forward.snake-next::after{top:50%;right:-23px;width:23px;height:2px}.timeline-item.snake-backward.snake-next::after{top:50%;left:-23px;width:23px;height:2px}.timeline-item.snake-turn::after{bottom:-31px;width:2px;height:30px}.timeline-item.snake-forward.snake-turn::after{right:20px}.timeline-item.snake-backward.snake-turn::after{left:20px}.dot{position:relative;z-index:1;width:30px;height:30px;display:grid;place-items:center;border-radius:50%;color:#96A3B5;background:#EEF3F8;font-size:12px;font-weight:800}.timeline-item.done .dot{color:#fff;background:#2B7FFF}.timeline-item.current{border-color:#AFCDF5;box-shadow:0 0 0 3px rgba(43,127,255,.08),0 8px 22px rgba(26,60,110,.06)}.timeline-item.current .dot{color:#fff;background:#2B7FFF}.timeline-item.closed .dot{color:#fff;background:#D94B55}.timeline-copy{min-width:0}.timeline-title{display:flex;flex-direction:column;align-items:flex-start;gap:7px;color:#1A3C6E;font-size:14px;font-weight:800}.node-state{display:inline-flex;align-items:center;min-height:22px;padding:3px 7px;border-radius:4px;color:#20A36F;background:#E9F7F1;font-size:10px;line-height:1.3;white-space:nowrap}.current .node-state{color:#fff;background:#2B7FFF}.closed .node-state{color:#D94B55;background:#FCEDEF}.timeline-desc{min-height:38px;margin-top:6px;color:#6B7A90;font-size:12px;line-height:1.6;word-break:break-word}.timeline-time{margin-top:5px;color:#96A3B5;font-size:11px}.current .timeline-time{color:#2B7FFF;font-weight:700}.info-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:14px;padding:20px}.info-grid>div{padding:2px 0}.info-grid>div+div{padding-left:20px;border-left:1px solid #E6EBF2}.info-grid p{margin:10px 0 0;color:#6B7A90;font-size:12px;line-height:1.7}.info-grid strong{color:#1A3C6E}.secondary-button,.primary-button{min-height:38px;margin-top:14px;padding:0 14px;border:0;border-radius:7px;color:#2B7FFF;background:#EAF2FF;font-size:11px;font-weight:800;cursor:pointer}.primary-button{color:#fff;background:#2B7FFF}.state{display:grid;place-items:center;gap:9px;min-height:280px;padding:30px;color:#6B7A90;text-align:center}.state strong{color:#1A3C6E;font-size:16px}.state-actions{display:flex;justify-content:center;gap:9px;flex-wrap:wrap}.state-actions .secondary-button{border:1px solid #C8D9F0}.footer{padding:16px;color:#A0ABBA;font-size:10px;text-align:center}@media(max-width:760px){.main{width:calc(100% - 32px)}.timeline{grid-template-columns:1fr}.timeline-item{grid-column:auto!important;grid-row:auto!important}.timeline-item.snake-next::after,.timeline-item.snake-turn::after{display:none}.info-grid{grid-template-columns:1fr}.info-grid>div+div{padding:14px 0 0;border-top:1px solid #E6EBF2;border-left:0}}@media(max-width:620px){.main{width:calc(100% - 28px)}.job-row{display:block}.flow-state{margin-top:10px}.timeline-panel{padding:16px}.panel-head{display:block}.panel-head span{display:block;margin-top:5px}}
</style>

<style scoped>
.application-detail-page{display:block;min-height:100vh}
</style>
