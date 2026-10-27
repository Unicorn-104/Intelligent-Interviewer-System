<template>
  <div class="page">
    <AgentTopbar active="jobs" />
    <main class="page-shell">
      <div v-if="loading" class="state-panel">正在加载岗位详情...</div>
      <div v-else-if="errorMessage" class="state-panel"><strong>岗位详情加载失败</strong><span>{{ errorMessage }}</span><button class="primary-button" type="button" @click="loadJob">重新加载</button></div>
      <template v-else-if="job">
        <div class="main-column">
          <section class="panel job-hero">
            <a class="breadcrumb" href="/agent/jobs"><svg viewBox="0 0 24 24"><path d="m15 18-6-6 6-6" /></svg>岗位浏览 / 职位详情</a>
            <div class="hero-row">
              <div>
                <h1 class="job-title">{{ job.title }}</h1>
                <div class="company-line"><span class="company-name">{{ job.companyName }}</span><span class="verified">认证企业</span><span>{{ job.workCity || '地点不限' }}</span><span>· {{ job.jobTypeText }}</span></div>
              </div>
              <div class="hero-tools"><button class="tool-button" :class="{ active: saved }" type="button" aria-label="收藏岗位" @click="toggleSaved"><svg viewBox="0 0 24 24"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg></button><button class="tool-button" type="button" aria-label="分享岗位" @click="showToast('岗位链接已复制，可分享给好友')"><svg viewBox="0 0 24 24"><circle cx="18" cy="5" r="2.5" /><circle cx="6" cy="12" r="2.5" /><circle cx="18" cy="19" r="2.5" /><path d="m8.2 10.8 7.6-4.5M8.2 13.2l7.6 4.5" /></svg></button></div>
            </div>
            <div class="hero-tags"><span class="hero-tag salary">{{ job.salaryText }}</span><span class="hero-tag">{{ job.educationText }}</span><span class="hero-tag">{{ job.experienceRequired || '经验不限' }}</span><span class="hero-tag">{{ job.jobTypeText }}</span><span v-for="skill in job.skills" :key="skill" class="hero-tag primary">{{ skill }}</span></div>
          </section>

          <section class="panel match-banner"><div class="match-score"><strong>{{ job.matchScore || 0 }}%</strong><span>综合匹配度</span></div><div class="match-copy"><h2>AI 匹配度分析 <span class="fit-pill">{{ Number(job.matchScore || 0) >= 80 ? '高度契合' : '建议完善简历' }}</span></h2><p>匹配结果基于当前简历方向、岗位技能和学历要求计算，投递时仍可重新选择简历。</p><div class="match-chips"><span class="match-chip">技能匹配 {{ job.matchScore || 0 }}%</span><span class="match-chip">岗位状态 {{ job.statusText }}</span></div></div></section>

          <section class="panel content-panel"><div class="section-heading"><h2>职位描述</h2><span class="section-note">{{ job.jobTypeText }} · {{ job.statusText }}</span></div><p class="intro-copy">{{ job.companyIntro || '该岗位暂无额外职位介绍，请结合岗位职责和任职要求了解机会。' }}</p><ul class="bullet-list"><li v-for="item in job.responsibilities" :key="item">{{ item }}</li><li v-if="!job.responsibilities?.length">暂无职位职责说明</li></ul></section>
          <section class="panel content-panel"><div class="section-heading"><h2>任职要求</h2></div><ul class="bullet-list"><li v-for="item in job.requirements" :key="item">{{ item }}</li><li v-if="!job.requirements?.length">暂无任职要求说明</li></ul></section>
          <section class="panel content-panel company-panel"><div class="section-heading"><h2>公司信息</h2></div><div class="company-identity"><div class="company-logo">{{ companyMark(job.companyName) }}</div><div><strong>{{ job.companyName }}</strong><span>{{ job.companyIndustry || '企业服务' }} · {{ job.companySize || '规模信息待补充' }}</span></div></div><p class="company-description">{{ job.companyIntro || '企业暂未补充公司介绍。' }}</p><div class="company-stats"><div class="company-stat"><span>公司城市</span><strong>{{ job.companyCity || '未填写' }}</strong></div><div class="company-stat"><span>办公地址</span><strong>{{ job.companyAddress || '未填写' }}</strong></div><div class="company-stat"><span>岗位发布</span><strong>{{ formatDate(job.publishedAt) }}</strong></div></div></section>
        </div>

        <aside class="side-column">
          <section class="panel action-panel"><div class="side-salary">{{ job.salaryText }}</div><div class="side-meta">{{ job.workCity || '地点不限' }} · {{ job.educationText }} · {{ job.experienceRequired || '经验不限' }} · {{ job.jobTypeText }}</div><button class="primary-button" :class="{ applied: job.appliedFlag }" type="button" @click="apply"><span>{{ job.appliedFlag ? '查看投递记录' : '立即投递' }}</span></button><div class="secondary-actions"><button class="secondary-button" :class="{ active: saved }" type="button" @click="toggleSaved"><svg viewBox="0 0 24 24"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg>{{ saved ? '已收藏' : '收藏岗位' }}</button><button class="secondary-button" type="button" @click="showToast('岗位链接已复制，可分享给好友')">分享</button></div><div class="ai-tip">投递前可以从你的有效简历中选择最适合该岗位的一份。</div></section>
          <section class="panel side-panel"><div class="side-heading"><h2>岗位技能</h2><span class="side-badge">{{ job.skills?.length || 0 }} 项</span></div><div class="company-tags"><span v-for="skill in job.skills" :key="skill" class="company-tag">{{ skill }}</span><span v-if="!job.skills?.length" class="metric-note">暂无技能标签</span></div></section>
          <section class="panel side-panel"><div class="side-heading"><h2>投递后流程</h2><span class="metric-note">状态会实时更新</span></div><ol class="timeline"><li class="timeline-item done"><span class="step-number">1</span><span class="step-copy"><strong>选择简历</strong><span>确认本次投递使用的简历</span></span></li><li class="timeline-item current"><span class="step-number">2</span><span class="step-copy"><strong>企业初筛</strong><span>企业处理后会产生新的进度节点</span></span></li><li class="timeline-item"><span class="step-number">3</span><span class="step-copy"><strong>面试与反馈</strong><span>查看后续面试安排和结果</span></span></li></ol></section>
          <section class="panel assistant-panel"><strong>AI 求职助手</strong><p>对岗位或投递流程有疑问？进入助手继续咨询。</p><button class="chat-button" type="button" @click="openAssistant">去咨询</button></section>
        </aside>
      </template>
    </main>
    <div class="toast" :class="{ show: toastVisible }" role="status">✓ {{ toastMessage }}</div>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { getJob } from '@/api/agent/job'

const route = useRoute()
const job = ref(null)
const loading = ref(false)
const errorMessage = ref('')
const saved = ref(false)
const toastVisible = ref(false)
const toastMessage = ref('')
let toastTimer

async function loadJob() {
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await getJob(route.query.id)
    job.value = response.data
    saved.value = readSavedJobs().includes(String(job.value.id))
    document.title = `${job.value.title} · 智聘 AI`
  } catch (error) {
    errorMessage.value = error?.message || '岗位详情暂时无法读取'
  } finally {
    loading.value = false
  }
}

function readSavedJobs() {
  try {
    const value = JSON.parse(localStorage.getItem('zhipin-ai-saved-jobs') || '[]')
    return Array.isArray(value) ? value.map(String) : []
  } catch {
    return []
  }
}

function toggleSaved() {
  const savedJobs = new Set(readSavedJobs())
  const id = String(job.value.id)
  saved.value = !saved.value
  saved.value ? savedJobs.add(id) : savedJobs.delete(id)
  try { localStorage.setItem('zhipin-ai-saved-jobs', JSON.stringify([...savedJobs])) } catch { /* 保留当前页面状态 */ }
  showToast(saved.value ? '已收藏该岗位' : '已取消收藏')
}

function apply() {
  if (job.value.appliedFlag && job.value.applicationId) {
    window.__agentNavigate(`/agent/application-detail?id=${job.value.applicationId}`)
  } else {
    window.__agentNavigate(`/agent/resume-select?job=${job.value.id}`)
  }
}

function openAssistant() {
  window.__agentNavigate(`/agent/job-assistant?job=${job.value.id}`)
}

function companyMark(name) {
  return (name || '企业').slice(0, 2)
}

function formatDate(value) {
  return value ? String(value).slice(0, 10) : '未填写'
}

function showToast(message) {
  toastMessage.value = message
  toastVisible.value = true
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { toastVisible.value = false }, 2300)
}

onMounted(loadJob)
</script>

<style scoped>
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}.page-shell{width:min(1240px,calc(100% - 48px));margin:0 auto;padding:20px 0 52px;display:grid;grid-template-columns:minmax(0,1fr) 312px;gap:16px}.main-column,.side-column{min-width:0;display:grid;gap:14px}.side-column{position:sticky;top:88px;align-self:start}.panel{border:1px solid #E6EBF2;border-radius:10px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045)}.job-hero,.content-panel,.side-panel,.action-panel{padding:18px 20px}.breadcrumb{display:inline-flex;align-items:center;gap:5px;color:#96A3B5;font-size:11px;text-decoration:none}.breadcrumb svg{width:14px;stroke:currentColor;fill:none;stroke-width:1.8}.hero-row{display:flex;justify-content:space-between;gap:18px;margin-top:11px}.job-title{margin:0;color:#1A3C6E;font-size:24px;line-height:1.35}.company-line{display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin-top:8px;color:#6B7A90;font-size:12px}.company-name{color:#1A3C6E;font-weight:800}.verified,.side-badge,.hero-tag{padding:4px 8px;border-radius:5px;color:#2B7FFF;background:#EAF2FF;font-size:10px;font-weight:700}.hero-tools{display:flex;gap:8px}.tool-button{width:36px;height:36px;border:0;border-radius:8px;color:#1A3C6E;background:#F3F6FA;cursor:pointer}.tool-button.active{color:#2B7FFF;background:#EAF2FF}.tool-button svg{width:17px;margin:auto;stroke:currentColor;fill:none;stroke-width:1.7}.tool-button.active svg{fill:currentColor}.hero-tags{display:flex;flex-wrap:wrap;gap:8px;margin-top:15px}.hero-tag{color:#52647D;background:#F2F5FA;font-weight:500}.hero-tag.salary{color:#fff;background:#1A3C6E;font-weight:800}.hero-tag.primary{color:#2B7FFF;background:#EAF2FF}.match-banner{display:grid;grid-template-columns:125px 1fr;gap:18px;padding:20px;border-color:#DDE9FA;background:#EFF5FF}.match-score{display:flex;flex-direction:column;justify-content:center;border-right:1px solid #D7E4F5}.match-score strong{color:#2B7FFF;font-size:34px;line-height:1}.match-score span{margin-top:8px;color:#6B7A90;font-size:11px}.match-copy h2{margin:0;color:#1A3C6E;font-size:15px}.fit-pill{margin-left:7px;padding:3px 7px;border-radius:5px;color:#fff;background:#2B7FFF;font-size:10px}.match-copy p{margin:8px 0 0;color:#52647D;font-size:12px}.match-chips{display:flex;flex-wrap:wrap;gap:7px;margin-top:10px}.match-chip{padding:4px 8px;border-radius:4px;color:#2B7FFF;background:#fff;font-size:10px}.section-heading,.side-heading{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px}.section-heading h2,.side-heading h2{margin:0;color:#1A3C6E;font-size:15px}.section-note,.metric-note{color:#96A3B5;font-size:10px}.intro-copy,.company-description{margin:0 0 10px;color:#52647D;font-size:12px;line-height:1.7}.bullet-list{margin:0;padding:0;list-style:none}.bullet-list li{position:relative;padding:6px 0 6px 15px;color:#52647D;font-size:12px;line-height:1.7}.bullet-list li::before{content:"";position:absolute;top:14px;left:1px;width:6px;height:6px;border-radius:50%;background:#2B7FFF}.company-identity{display:flex;align-items:center;gap:11px}.company-logo{width:44px;height:44px;display:grid;place-items:center;border-radius:9px;color:#fff;background:#2B7FFF;font-size:12px;font-weight:800}.company-identity strong{display:block;color:#1A3C6E;font-size:14px}.company-identity span{display:block;margin-top:3px;color:#96A3B5;font-size:11px}.company-description{margin-top:14px}.company-stats{display:grid;grid-template-columns:repeat(3,1fr);gap:9px;margin-top:13px}.company-stat{padding:10px;border-radius:7px;background:#F7F9FC}.company-stat span{display:block;color:#96A3B5;font-size:10px}.company-stat strong{display:block;margin-top:3px;overflow:hidden;color:#1A3C6E;font-size:11px;text-overflow:ellipsis;white-space:nowrap}.side-salary{color:#1A3C6E;font-size:24px;font-weight:800}.side-meta{margin-top:7px;color:#96A3B5;font-size:11px}.primary-button{width:100%;min-height:44px;margin-top:14px;border:0;border-radius:7px;color:#fff;background:#2B7FFF;font-size:13px;font-weight:800;cursor:pointer}.primary-button.applied{color:#16865F;background:#E8F7F1}.secondary-actions{display:grid;grid-template-columns:1fr 90px;gap:8px;margin-top:9px}.secondary-button,.chat-button{min-height:36px;border:0;border-radius:7px;color:#1A3C6E;background:#F3F6FA;font-size:11px;font-weight:700;cursor:pointer}.secondary-button.active{color:#2B7FFF;background:#EAF2FF}.secondary-button svg{width:15px;margin-right:5px;vertical-align:middle;stroke:currentColor;fill:none;stroke-width:1.7}.ai-tip{margin-top:10px;padding:10px;border-radius:7px;color:#52647D;background:#EDF4FF;font-size:10px;line-height:1.6}.company-tags{display:flex;flex-wrap:wrap;gap:7px}.company-tag{padding:4px 8px;border-radius:5px;color:#2B7FFF;background:#EAF2FF;font-size:10px}.timeline{margin:0;padding:0;list-style:none}.timeline-item{display:grid;grid-template-columns:25px 1fr;gap:8px;min-height:55px}.step-number{width:23px;height:23px;display:grid;place-items:center;border-radius:50%;color:#96A3B5;background:#EFF3F8;font-size:10px;font-weight:800}.timeline-item.done .step-number,.timeline-item.current .step-number{color:#fff;background:#2B7FFF}.step-copy strong{display:block;color:#1A3C6E;font-size:11px}.step-copy span{display:block;margin-top:2px;color:#96A3B5;font-size:10px}.assistant-panel{padding:16px;border-color:#DDE9FA;background:#EFF5FF}.assistant-panel strong{color:#1A3C6E;font-size:13px}.assistant-panel p{margin:8px 0;color:#52647D;font-size:11px}.chat-button{padding:0 12px;color:#2B7FFF;background:#fff}.state-panel{grid-column:1/-1;display:grid;place-items:center;gap:9px;min-height:280px;padding:30px;border:1px dashed #CBD9E8;border-radius:10px;color:#6B7A90;background:#fff;text-align:center}.state-panel strong{color:#1A3C6E;font-size:16px}.state-panel .primary-button{width:auto;padding:0 20px}.toast{position:fixed;right:24px;bottom:24px;z-index:50;padding:11px 15px;border:1px solid #CCE9DE;border-radius:8px;color:#176B50;background:#F2FBF7;opacity:0;transform:translateY(8px);transition:.18s}.toast.show{opacity:1;transform:translateY(0)}@media(max-width:950px){.page-shell{width:calc(100% - 32px);grid-template-columns:1fr}.side-column{position:static;grid-template-columns:repeat(2,1fr)}.action-panel,.assistant-panel{grid-column:1/-1}}@media(max-width:620px){.page-shell{width:calc(100% - 28px)}.hero-row{display:block}.hero-tools{margin-top:12px}.match-banner{grid-template-columns:1fr}.match-score{padding-bottom:13px;border-right:0;border-bottom:1px solid #D7E4F5}.company-stats,.side-column{grid-template-columns:1fr}.job-title{font-size:21px}}
</style>
