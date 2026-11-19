<template>
  <section class="company-jobs">
    <h2>企业在招岗位 <span v-if="total !== null">{{ total }}</span></h2>
    <p v-if="error" class="company-jobs__error" role="alert">{{ error }} <button type="button" @click="load">重试</button></p>
    <p v-if="!items.length && !loading && !error">企业暂无公开在招岗位</p>
    <a v-for="job in items" :key="job.id" class="company-jobs__item" :href="appHref(`/job-detail?id=${encodeURIComponent(job.id)}`)">
      <div><strong>{{ job.title }}</strong><p>{{ [job.workCity, job.educationText, job.experienceRequired].filter(Boolean).join(' · ') || '具体要求见职位详情' }}</p></div>
      <span>{{ job.salaryText || '薪资面议' }}</span>
    </a>
    <button v-if="hasNext || loading" type="button" :disabled="loading" @click="load">{{ loading ? '正在读取岗位…' : '加载更多岗位' }}</button>
  </section>
</template>

<script setup>
import { ref, watch } from 'vue'
import { appHref } from '@/utils/agentNavigation'
import { getCompanyJobs } from '@/api/agent/company'

const props = defineProps({ companyId: { type: [String, Number], required: true } })
const items = ref([])
const total = ref(null)
const page = ref(1)
const hasNext = ref(true)
const loading = ref(false)
const error = ref('')
let revision = 0

async function load() {
  if (loading.value || !hasNext.value) return
  const current = revision
  loading.value = true
  error.value = ''
  try {
    const response = await getCompanyJobs(props.companyId, { page: page.value, size: 10 })
    if (current !== revision) return
    if (!Array.isArray(response.data?.items)) throw new Error('岗位数据格式异常')
    const data = response.data
    items.value = [...new Map([...items.value, ...data.items].map(job => [String(job.id), job])).values()]
    total.value = Number(data.total || 0)
    hasNext.value = data.hasNext === true || page.value * 10 < total.value
    if (hasNext.value && !data.items.length) throw new Error('岗位分页异常，请稍后重试')
    page.value++
  } catch (failure) {
    if (current === revision) error.value = failure?.message || '岗位读取失败'
  } finally {
    if (current === revision) loading.value = false
  }
}

watch(() => props.companyId, () => {
  revision++
  items.value = []
  total.value = null
  page.value = 1
  hasNext.value = true
  loading.value = false
  load()
}, { immediate: true })
</script>

<style scoped>
.company-jobs{margin-top:20px;padding:24px;border:1px solid #e3eaf3;border-radius:12px;background:#fff;color:#607187}
.company-jobs h2{margin:0 0 16px;color:#1a3c6e;font-size:18px}.company-jobs h2 span{margin-left:6px;color:#8594a7;font-size:13px}
.company-jobs__item{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:18px 0;border-bottom:1px solid #edf1f6;color:#27466b;text-decoration:none}
.company-jobs__item div{min-width:0}.company-jobs__item strong{overflow-wrap:anywhere}.company-jobs__item p{margin:7px 0 0;color:#7a899d;font-size:12px}.company-jobs__item>span{flex-shrink:0;color:#c67735;font-size:13px}.company-jobs__item:hover strong{color:#2b7fff}
.company-jobs button{margin-top:12px;padding:8px 14px;border:1px solid #d2dfef;border-radius:7px;background:#f5f9ff;color:#2a61a6;cursor:pointer}.company-jobs__error{color:#b84b4b}
@media(max-width:560px){.company-jobs{padding:16px}.company-jobs__item{align-items:flex-start;flex-direction:column;gap:8px}}
</style>
