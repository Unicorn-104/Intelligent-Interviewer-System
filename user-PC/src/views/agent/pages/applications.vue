<template>
  <div class="applications-page">
    <AgentTopbar active="applications" />
    <main class="applications-main">
      <div class="page-heading"><h1>投递跟踪</h1><div class="page-meta">共 {{ applications.length }} 条投递记录 · 数据来自实时投递状态</div></div>
      <section class="summary-grid">
        <article class="summary-card"><div class="summary-top"><span>总投递数</span><span class="summary-icon">↗</span></div><strong class="summary-value">{{ applications.length }}</strong><div class="summary-note">已提交的岗位投递</div></article>
        <article class="summary-card"><div class="summary-top"><span>正在进行</span><span class="summary-icon orange">◷</span></div><strong class="summary-value">{{ countBy('active') }}</strong><div class="summary-note">等待企业处理或反馈</div></article>
        <article class="summary-card"><div class="summary-top"><span>面试中</span><span class="summary-icon blue">□</span></div><strong class="summary-value">{{ countBy('interview') }}</strong><div class="summary-note">包含待面试与面试阶段</div></article>
        <article class="summary-card"><div class="summary-top"><span>已结束</span><span class="summary-icon gray">✓</span></div><strong class="summary-value">{{ countBy('closed') }}</strong><div class="summary-note">未通过、录用或流程结束</div></article>
      </section>

      <section class="records-panel"><div class="records-head"><h2>投递记录</h2><select v-model="filter" class="filter-select" aria-label="筛选投递状态" @change="loadApplications"><option value="all">全部状态</option><option value="active">正在进行</option><option value="interview">面试中</option><option value="closed">已结束</option></select></div>
        <div v-if="loading" class="empty-state visible">正在读取投递记录...</div>
        <div v-else-if="filteredApplications.length">
          <article v-for="item in filteredApplications" :key="item.id" class="application-item" :class="{ open: expandedId === item.id }">
            <div class="application-summary" tabindex="0" role="button" :aria-expanded="expandedId === item.id" @click="toggleItem(item)" @keydown.enter.prevent="toggleItem(item)" @keydown.space.prevent="toggleItem(item)">
              <span class="status-icon" :class="statusClass(item.status)">{{ statusSymbol(item.status) }}</span>
              <div class="application-copy"><div class="application-title">{{ item.jobTitle }}</div><div class="application-sub">{{ item.companyName }} · 投递于 {{ formatDate(item.appliedAt) }}</div></div>
              <span class="status-pill" :class="statusClass(item.status)">{{ item.statusText }}</span><button class="expand-button" type="button" :aria-label="expandedId === item.id ? '收起进度' : '展开进度'" @click.stop="toggleItem(item)">⌄</button>
            </div>
            <div v-if="expandedId === item.id" class="progress-panel"><div v-if="detailLoading" class="progress-content">正在加载流程节点...</div><div v-else class="progress-content"><div class="progress-caption">流程进度 <span>当前阶段：{{ item.statusText }}</span></div><div v-if="details[item.id]?.timeline?.length" class="progress-steps"><div v-for="(node, index) in details[item.id].timeline" :key="`${node.stage}-${index}`" class="progress-step" :class="node.state === 'current' ? 'current' : node.state === 'closed' || node.state === 'done' ? 'done' : ''"><span class="step-dot">{{ node.state === 'done' ? '✓' : index + 1 }}</span><span class="step-name">{{ node.title }}</span><span class="step-time">{{ formatDate(node.occurredAt) }}</span></div></div><div v-else class="empty-inline">暂无状态日志</div><div class="detail-row"><a class="detail-link" :href="appHref(`/application-detail?id=${item.id}`)" @click.stop>查看详细进度 →</a></div></div></div>
          </article>
        </div>
        <div v-else class="empty-state visible">当前筛选条件下没有投递记录。</div>
      </section>
    </main>
    <footer class="footer">© 2026 企业级智能招聘面试官 Agent 系统 · 隐私政策 / 用户协议</footer>
  </div>
</template>

<script setup>
import { appHref } from '@/utils/agentNavigation'
import { computed, onMounted, ref } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { getApplication, listApplications } from '@/api/agent/application'

const applications = ref([])
const filter = ref('all')
const loading = ref(false)
const detailLoading = ref(false)
const expandedId = ref(null)
const details = ref({})
const filteredApplications = computed(() => filter.value === 'all' ? applications.value : applications.value.filter(item => item.status === filter.value))

async function loadApplications() {
  loading.value = true
  try {
    const response = await listApplications({ page: 1, size: 100 })
    applications.value = response.data?.items || []
  } finally {
    loading.value = false
  }
}

async function toggleItem(item) {
  if (expandedId.value === item.id) {
    expandedId.value = null
    return
  }
  expandedId.value = item.id
  if (details.value[item.id]) return
  detailLoading.value = true
  try {
    const response = await getApplication(item.id)
    details.value = { ...details.value, [item.id]: response.data }
  } finally {
    detailLoading.value = false
  }
}

function countBy(status) {
  return applications.value.filter(item => item.status === status).length
}

function statusClass(status) {
  if (status === 'interview') return 'green'
  if (status === 'closed') return 'red'
  return status === 'active' ? 'orange' : 'gray'
}

function statusSymbol(status) {
  return status === 'closed' ? '×' : status === 'interview' ? '✓' : '◷'
}

function formatDate(value) {
  return value ? String(value).replace('T', ' ').slice(0, 16) : '刚刚'
}

onMounted(loadApplications)
</script>

<style scoped>
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}.main{width:min(1240px,calc(100% - 48px));margin:0 auto;padding:27px 0 54px}.page-heading{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;margin-bottom:20px}.page-heading h1{margin:0;color:#1A3C6E;font-size:25px}.page-meta{color:#96A3B5;font-size:11px}.summary-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px}.summary-card{min-height:128px;padding:18px 20px;border:1px solid #E6EBF2;border-radius:10px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045)}.summary-top{display:flex;align-items:center;justify-content:space-between;color:#53647B;font-size:12px}.summary-icon{width:32px;height:32px;display:grid;place-items:center;border-radius:50%;color:#1A3C6E;background:#EDF3FC;font-weight:800}.summary-icon.orange{color:#D88725;background:#FFF4E6}.summary-icon.blue{color:#2B7FFF;background:#EAF2FF}.summary-icon.gray{color:#647894;background:#EEF2F7}.summary-value{display:block;margin-top:14px;color:#17233F;font-size:30px;line-height:1;font-weight:800}.summary-note{margin-top:9px;color:#96A3B5;font-size:11px}.records-panel{margin-top:16px;border:1px solid #E6EBF2;border-radius:10px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045);overflow:hidden}.records-head{height:56px;display:flex;align-items:center;justify-content:space-between;padding:0 20px;border-bottom:1px solid #E6EBF2}.records-head h2{margin:0;color:#1A3C6E;font-size:16px}.filter-select{height:34px;padding:0 28px 0 10px;border:0;border-radius:6px;color:#6B7A90;background:#F7F9FC;font-size:11px}.application-item+.application-item{border-top:1px solid #E6EBF2}.application-summary{min-height:76px;display:grid;grid-template-columns:44px minmax(0,1fr) auto 34px;align-items:center;gap:14px;padding:12px 18px;cursor:pointer}.application-summary:hover{background:#FAFCFF}.status-icon{width:36px;height:36px;display:grid;place-items:center;border-radius:50%;color:#647894;background:#EEF2F7;font-weight:800}.status-icon.orange,.status-pill.orange{color:#D88725;background:#FFF4E6}.status-icon.green,.status-pill.green{color:#20A36F;background:#E9F7F1}.status-icon.red,.status-pill.red{color:#D94B55;background:#FCEDEF}.status-icon.gray,.status-pill.gray{color:#60738F;background:#EEF2F7}.application-copy{min-width:0}.application-title{overflow:hidden;color:#1A3C6E;font-size:14px;font-weight:800;text-overflow:ellipsis;white-space:nowrap}.application-sub{margin-top:4px;color:#96A3B5;font-size:11px}.status-pill{min-width:76px;padding:5px 10px;border-radius:5px;color:#2B7FFF;background:#EAF2FF;font-size:11px;text-align:center}.expand-button{width:34px;height:34px;border:0;border-radius:7px;color:#91A0B2;background:transparent;font-size:18px;cursor:pointer}.application-item.open .expand-button{transform:rotate(180deg)}.progress-panel{background:#F6F9FD}.progress-content{padding:14px 22px 20px;border-top:1px solid #E8EEF6}.progress-caption{display:flex;justify-content:space-between;gap:15px;margin-bottom:13px;color:#1A3C6E;font-size:11px;font-weight:700}.progress-caption span{color:#2B7FFF;font-weight:500}.progress-steps{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));align-items:start;gap:0}.progress-step{position:relative;text-align:center}.progress-step:not(:first-child)::before{content:"";position:absolute;top:15px;right:50%;left:-50%;height:2px;background:#DDE6F2}.progress-step.done::before,.progress-step.current::before{background:#20A36F}.step-dot{position:relative;z-index:1;width:30px;height:30px;display:grid;place-items:center;margin:0 auto 7px;border:1px solid #D8E1ED;border-radius:50%;color:#9AA7B7;background:#fff;font-size:11px;font-weight:800}.progress-step.done .step-dot{border-color:#20A36F;color:#fff;background:#20A36F}.progress-step.current .step-dot{border-color:#2B7FFF;color:#fff;background:#2B7FFF}.step-name{display:block;color:#687A91;font-size:10px}.step-time{display:block;margin-top:3px;color:#A1ADBC;font-size:9px}.detail-row{display:flex;justify-content:flex-end;margin-top:13px}.detail-link{padding:8px 11px;border:1px solid #C8D9F0;border-radius:6px;color:#2B7FFF;background:#fff;font-size:10px;font-weight:700;text-decoration:none}.empty-state{display:none;padding:48px 20px;color:#6B7A90;text-align:center}.empty-state.visible{display:block}.empty-inline{padding:15px;color:#96A3B5;text-align:center;font-size:11px}.footer{padding:16px;color:#A0ABBA;font-size:10px;text-align:center}@media(max-width:900px){.main{width:calc(100% - 32px)}.summary-grid{grid-template-columns:repeat(2,1fr)}}@media(max-width:620px){.main{width:calc(100% - 28px)}.page-heading{display:block}.page-meta{margin-top:6px}.summary-grid{gap:8px}.summary-card{padding:14px}.application-summary{grid-template-columns:36px minmax(0,1fr) 30px;padding:11px 12px;gap:9px}.status-pill{grid-column:2;justify-self:start}.expand-button{grid-column:3;grid-row:1/3}.progress-content{padding:14px 10px 18px;overflow:auto}.progress-steps{min-width:480px}.progress-caption{display:block}.progress-caption span{display:block;margin-top:4px}}
</style>

<style scoped>
.applications-page{width:100%;min-height:100vh;background:#F5F7FA}
.applications-main{width:min(1240px,calc(100% - 48px));margin:0 auto;padding:27px 0 54px}
@media(max-width:900px){.applications-main{width:calc(100% - 32px)}}
@media(max-width:620px){.applications-main{width:calc(100% - 28px)}}
</style>
