<template>
  <div class="job-ai-page">
    <AgentTopbar active="jobs" />
    <main class="job-ai-workspace">
      <aside class="job-ai-context">
        <a class="job-ai-back" :href="backHref">← {{ jobId ? '返回职位详情' : '返回岗位浏览' }}</a>
        <p class="job-ai-eyebrow">AI 求职工作台</p>
        <h1>让每一步求职<br />更有准备</h1>
        <p class="job-ai-description">选择自己的简历和已投递岗位，获取更有针对性的求职建议。对话与 App 同步保存。</p>
        <p v-if="jobLoading" class="job-ai-note">正在读取岗位信息…</p>
        <p v-else-if="jobError" class="job-ai-note">{{ jobError }}</p>
        <section v-else-if="job" class="job-ai-job"><span>当前浏览的真实岗位</span><h2>{{ job.title }}</h2><p>{{ job.companyName }}</p><p>{{ job.salaryText || '薪资面议' }} · {{ job.workCity || job.locationText || '地点未注明' }}</p><a :href="backHref">查看完整职位详情 →</a></section>
        <div class="job-ai-guidance"><h2>怎么使用</h2><p>1. 岗位推荐、简历分析：选择一份个人简历。</p><p>2. 面试准备：选择已投递岗位，自动关联投递时使用的简历。</p><p>3. 写作润色：输入需要润色的原文，无需选择资料。</p><p>4. 自由聊天：直接输入问题即可。</p></div>
        <p class="job-ai-note">AI 只提供辅助建议，不会自动投递、修改简历或编造个人经历。</p>
      </aside>
      <div class="job-ai-assistant"><AiAssistant standalone @close="returnToJob" /></div>
    </main>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import AiAssistant from '@/components/agent/AiAssistant.vue'
import { getJob } from '@/api/agent/job'
import { appHref } from '@/utils/agentNavigation'

const route = useRoute()
const router = useRouter()
const job = ref(null)
const jobLoading = ref(false)
const jobError = ref('')
const jobId = computed(() => /^\d+$/.test(String(route.query.id || '')) ? String(route.query.id) : '')
const backPath = computed(() => jobId.value ? `/job-detail?id=${encodeURIComponent(jobId.value)}` : '/jobs')
const backHref = computed(() => appHref(backPath.value))
let disposed = false

function returnToJob() {
  router.push(backPath.value)
}

onMounted(async () => {
  if (!jobId.value) return
  jobLoading.value = true
  try {
    const response = await getJob(jobId.value)
    if (!disposed) job.value = response.data
  } catch (failure) {
    if (!disposed) jobError.value = failure.message || '岗位信息暂不可用，自由聊天不受影响'
  } finally {
    if (!disposed) jobLoading.value = false
  }
})

onBeforeUnmount(() => { disposed = true })
</script>

<style scoped>
.job-ai-page{min-height:100vh;background:#f4f7fc;color:#294263;font-family:Inter,"PingFang SC","Microsoft YaHei",sans-serif}
.job-ai-workspace{display:grid;grid-template-columns:minmax(240px,330px) minmax(0,1fr);gap:24px;width:min(1180px,calc(100% - 48px));height:calc(100dvh - 110px);min-height:560px;max-height:1000px;margin:22px auto}
.job-ai-context{min-width:0;overflow-y:auto;padding:12px 10px 24px;overscroll-behavior:contain}.job-ai-back{color:#6380a1;text-decoration:none;font-size:13px}.job-ai-eyebrow{margin:34px 0 12px;color:#4a89da;font-size:12px;letter-spacing:2px}.job-ai-context h1{margin:0 0 18px;font-size:32px;line-height:1.5;font-weight:700}.job-ai-description{color:#70839d;font-size:13px;line-height:1.9}.job-ai-job{margin:24px 0;padding:18px;border:1px solid #dae7fa;border-radius:14px;background:#eef4ff}.job-ai-job>span{font-size:11px;color:#7992b2}.job-ai-job h2{margin:8px 0;font-size:17px}.job-ai-job p{color:#647e9e;font-size:12px}.job-ai-job a{color:#2b7fff;font-size:12px;text-decoration:none}.job-ai-guidance{margin-top:28px}.job-ai-guidance h2{font-size:15px}.job-ai-guidance p{font-size:12px;line-height:1.9;color:#71839c}.job-ai-note{margin-top:22px;color:#8d9cb0;font-size:11px;line-height:1.8}.job-ai-assistant{min-width:0;min-height:0}
@media(max-width:800px){.job-ai-workspace{grid-template-columns:1fr;width:calc(100% - 24px);height:calc(100dvh - 92px);min-height:450px;margin:12px auto}.job-ai-context{display:none}}
</style>
