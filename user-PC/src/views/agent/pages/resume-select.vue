<template>
  <div class="page">
    <header class="topbar"><div class="topbar-inner"><a class="brand" href="/agent/index"><span class="brand-mark">智</span><strong>智聘 AI</strong></a><a class="back-link" :href="detailUrl"><svg viewBox="0 0 24 24"><path d="m15 18-6-6 6-6" /></svg>返回岗位详情</a></div></header>
    <main class="main">
      <section v-if="successApplication" class="panel success"><span class="success-icon">✓</span><h1>投递成功</h1><p>简历已发送给企业，可在投递跟踪中查看后续进度。</p><div class="success-actions"><a class="secondary" :href="detailUrl">返回岗位详情</a><button class="primary" type="button" @click="goApplication">查看投递进度</button></div></section>
      <template v-else>
        <div class="page-head"><div><h1>选择投递简历</h1><p>选择最适合当前岗位的一份有效简历，确认后将发送给企业。</p></div><div class="steps"><span class="step"><span class="step-number">1</span>选择简历</span><span class="step-line"></span><span class="step pending"><span class="step-number">2</span>投递完成</span></div></div>
        <div v-if="loading" class="panel state">正在读取岗位和简历...</div>
        <div v-else-if="errorMessage" class="panel state"><strong>无法继续投递</strong><span>{{ errorMessage }}</span><button class="primary" type="button" @click="loadData">重新加载</button></div>
        <div v-else class="layout">
          <section class="panel"><div class="panel-head"><h2>我的简历</h2><p>AI 已根据岗位要求计算每份简历的匹配度</p></div><div v-if="resumes.length" class="resume-list"><label v-for="resume in resumes" :key="resume.id" class="resume-option" :class="{ selected: selectedResume?.id === resume.id }"><input v-model="selectedResumeId" type="radio" name="resume" :value="resume.id" /><span class="file-icon">▤</span><span><span class="resume-name">{{ resume.name }} <span v-if="resume.recommended" class="badge">AI 推荐</span><span v-else-if="resume.isDefault" class="badge">默认简历</span></span><span class="resume-summary">{{ resume.jobDirection || '综合求职方向' }} · 完整度 {{ resume.completion }}%</span><span class="resume-meta"><span>更新于 {{ formatDate(resume.updatedAt) }}</span><span>已使用 {{ resume.usedApplicationCount || 0 }} 次</span></span></span><span class="match"><strong>{{ resume.matchScore }}%</strong><span>岗位匹配</span></span></label></div><div v-else class="empty">暂无可投递简历，请先完善我的简历。</div><div class="panel-foot"><span>企业只能查看本次选择的简历</span><a href="/agent/profile-resumes">管理我的简历</a></div></section>
          <aside class="panel job-panel"><div class="job-summary"><div class="company">{{ job?.companyName }}</div><h2 class="job-title">{{ job?.title }}</h2><div class="salary">{{ job?.salaryText }}</div><div class="job-meta"><span>{{ job?.workCity || '地点不限' }}</span><span>{{ job?.educationText }}</span><span>{{ job?.experienceRequired || '经验不限' }}</span><span>{{ job?.jobTypeText }}</span></div></div><div class="match-box"><div class="match-head"><span>当前简历匹配度</span><strong>{{ selectedResume?.matchScore || 0 }}%</strong></div><div class="track"><div class="value" :style="{ width: `${selectedResume?.matchScore || 0}%` }"></div></div><div class="match-note">{{ selectedResume ? (selectedResume.matchScore >= 80 ? '该简历与岗位要求匹配度较高' : '建议补充与岗位相关的项目成果后再投递') : '请选择一份简历' }}</div></div><label class="agreement"><input v-model="agreement" type="checkbox" />我已确认简历内容真实，并同意《投递协议》与《隐私政策》</label><div class="actions"><button class="secondary" type="button" @click="cancel">取消</button><button class="primary" type="button" :disabled="!selectedResume || !agreement || submitting" @click="submitApplication">{{ submitting ? '提交中...' : '确认投递' }}</button></div></aside>
        </div>
      </template>
    </main>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { getJob, getResumeOptions } from '@/api/agent/job'
import { createApplication } from '@/api/agent/application'

const route = useRoute()
const jobId = route.query.job
const job = ref(null)
const resumes = ref([])
const selectedResumeId = ref(null)
const agreement = ref(false)
const loading = ref(false)
const submitting = ref(false)
const errorMessage = ref('')
const successApplication = ref(null)
const detailUrl = computed(() => `/agent/job-detail?id=${encodeURIComponent(jobId || '')}`)
const selectedResume = computed(() => resumes.value.find(item => item.id === selectedResumeId.value))

async function loadData() {
  loading.value = true
  errorMessage.value = ''
  try {
    const [jobResponse, resumeResponse] = await Promise.all([getJob(jobId), getResumeOptions(jobId)])
    job.value = jobResponse.data
    resumes.value = resumeResponse.data || []
    selectedResumeId.value = resumes.value.find(item => item.recommended || item.isDefault)?.id || resumes.value[0]?.id || null
    document.title = `为 ${job.value.title} 选择简历 · 智聘 AI`
  } catch (error) {
    errorMessage.value = error?.message || '岗位或简历数据暂时无法读取'
  } finally {
    loading.value = false
  }
}

async function submitApplication() {
  if (!selectedResume.value || !agreement.value || submitting.value) return
  submitting.value = true
  try {
    const response = await createApplication({ jobId: Number(jobId), resumeId: selectedResume.value.id, consentVersion: 'v1' })
    const application = response.data
    if (application?.duplicate) {
      window.__agentNavigate(`/agent/application-detail?id=${application.id}`)
      return
    }
    successApplication.value = application
  } catch (error) {
    errorMessage.value = error?.message || '投递失败，请稍后重试'
  } finally {
    submitting.value = false
  }
}

function goApplication() {
  if (successApplication.value?.id) {
    window.__agentNavigate(`/agent/application-detail?id=${successApplication.value.id}`)
  }
}

function cancel() {
  window.__agentNavigate(detailUrl.value)
}

function formatDate(value) {
  return value ? String(value).slice(0, 10) : '最近更新'
}

onMounted(loadData)
</script>

<style scoped>
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}.topbar{height:72px;border-bottom:1px solid #E5EAF1;background:#fff}.topbar-inner,.main{width:min(1120px,calc(100% - 48px));margin:0 auto}.topbar-inner{height:100%;display:flex;align-items:center}.brand{display:flex;align-items:center;gap:10px;color:#1A3C6E;text-decoration:none}.brand-mark{width:34px;height:34px;display:grid;place-items:center;border-radius:8px;color:#fff;background:linear-gradient(145deg,#2B7FFF,#1A3C6E);font-weight:800}.brand strong{font-size:17px}.back-link{display:flex;align-items:center;gap:6px;margin-left:auto;color:#6B7A90;font-size:12px;text-decoration:none}.back-link svg{width:16px;stroke:currentColor;fill:none;stroke-width:1.8}.main{padding:28px 0 54px}.page-head{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;margin-bottom:18px}.page-head h1{margin:0;color:#1A3C6E;font-size:24px}.page-head p{margin:5px 0 0;color:#6B7A90;font-size:12px}.steps{display:flex;align-items:center;color:#96A3B5;font-size:10px}.step{display:flex;align-items:center;gap:6px}.step-number{width:24px;height:24px;display:grid;place-items:center;border-radius:50%;color:#fff;background:#2B7FFF;font-weight:800}.step.pending .step-number{color:#74859A;background:#E9EEF5}.step-line{width:36px;height:1px;margin:0 8px;background:#D9E2EE}.layout{display:grid;grid-template-columns:minmax(0,1fr) 310px;gap:16px}.panel{border:1px solid #E5EAF1;border-radius:8px;background:#fff;box-shadow:0 6px 22px rgba(26,60,110,.055)}.panel-head{padding:17px 18px;border-bottom:1px solid #E5EAF1}.panel-head h2{margin:0;color:#1A3C6E;font-size:16px}.panel-head p{margin:4px 0 0;color:#96A3B5;font-size:10px}.resume-list{display:grid;gap:10px;padding:14px}.resume-option{position:relative;display:grid;grid-template-columns:22px 44px minmax(0,1fr) 76px;align-items:center;gap:12px;min-height:94px;padding:14px;border:1px solid #E5EAF1;border-radius:7px;cursor:pointer}.resume-option:hover,.resume-option.selected{border-color:#2B7FFF;background:#F8FBFF}.resume-option input{width:17px;height:17px;accent-color:#2B7FFF}.file-icon{width:42px;height:50px;display:grid;place-items:center;border-radius:6px;color:#2B7FFF;background:#EAF2FF;font-size:22px}.resume-name{display:flex;align-items:center;gap:7px;color:#1A3C6E;font-size:13px;font-weight:800}.badge{padding:2px 6px;border-radius:4px;color:#2B7FFF;background:#EAF2FF;font-size:9px}.resume-summary{display:block;margin-top:5px;color:#6B7A90;font-size:10px}.resume-meta{display:flex;flex-wrap:wrap;gap:5px 12px;margin-top:6px;color:#96A3B5;font-size:9px}.match{text-align:right}.match strong{display:block;color:#16845B;font-size:17px}.match span{color:#96A3B5;font-size:9px}.panel-foot{display:flex;align-items:center;justify-content:space-between;gap:14px;padding:12px 18px;border-top:1px solid #E5EAF1;color:#96A3B5;font-size:10px}.panel-foot a{color:#2B7FFF;text-decoration:none}.job-panel{align-self:start;overflow:hidden}.job-summary{padding:18px}.company{color:#6B7A90;font-size:10px}.job-title{margin:5px 0 0;color:#1A3C6E;font-size:17px}.salary{margin-top:10px;color:#2B7FFF;font-size:18px;font-weight:800}.job-meta{display:flex;flex-wrap:wrap;gap:7px;margin-top:10px}.job-meta span{padding:3px 7px;border-radius:4px;color:#5F7189;background:#F1F4F8;font-size:9px}.match-box{margin:0 18px 16px;padding:13px;border-radius:6px;background:#F7FAFE}.match-head{display:flex;justify-content:space-between;color:#6B7A90;font-size:10px}.match-head strong{color:#2B7FFF;font-size:18px}.track{height:6px;margin-top:8px;border-radius:99px;background:#DFE8F4}.value{height:100%;border-radius:inherit;background:#2B7FFF;transition:.2s}.match-note{margin-top:8px;color:#96A3B5;font-size:9px}.agreement{display:flex;align-items:flex-start;gap:7px;margin:0 18px 14px;color:#6B7A90;font-size:10px}.agreement input{margin-top:2px;accent-color:#2B7FFF}.actions{display:grid;grid-template-columns:1fr 1.6fr;gap:8px;padding:14px 18px;border-top:1px solid #E5EAF1;background:#FBFCFE}.primary,.secondary{height:40px;border-radius:6px;font-size:11px;font-weight:700;cursor:pointer}.primary{border:1px solid #2B7FFF;color:#fff;background:#2B7FFF}.primary:disabled{cursor:not-allowed;opacity:.45}.secondary{border:1px solid #CBD9EA;color:#1A3C6E;background:#fff}.state,.empty{display:grid;place-items:center;gap:10px;min-height:240px;padding:30px;color:#6B7A90;text-align:center}.state strong{color:#1A3C6E;font-size:16px}.success{padding:64px 24px;text-align:center}.success-icon{width:58px;height:58px;display:grid;place-items:center;margin:0 auto;border-radius:50%;color:#fff;background:#16845B;font-size:28px;font-weight:800}.success h1{margin:18px 0 0;color:#1A3C6E;font-size:22px}.success p{margin:8px 0 22px;color:#6B7A90;font-size:12px}.success-actions{display:flex;justify-content:center;gap:9px}.success-actions a,.success-actions button{height:40px;display:flex;align-items:center;padding:0 16px;border-radius:6px;font-size:11px;font-weight:700;text-decoration:none}.success-actions .primary{color:#fff}@media(max-width:800px){.topbar-inner,.main{width:calc(100% - 32px)}.page-head{display:block}.steps{margin-top:14px}.layout{grid-template-columns:1fr}.job-panel{grid-row:1}.resume-option{grid-template-columns:22px 40px minmax(0,1fr)}.match{grid-column:3;text-align:left;display:flex;align-items:center;gap:5px}}@media(max-width:520px){.topbar-inner,.main{width:calc(100% - 28px)}.resume-option{grid-template-columns:22px minmax(0,1fr)}.file-icon{display:none}.resume-name{align-items:flex-start;flex-direction:column}.match{grid-column:2}.actions,.success-actions{grid-template-columns:1fr;flex-direction:column}.success-actions a,.success-actions button{justify-content:center}}
</style>
