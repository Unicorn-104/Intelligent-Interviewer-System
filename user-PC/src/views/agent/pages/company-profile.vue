<template>
  <div class="company-profile-page">
    <AgentTopbar active="jobs" />
    <main class="company-profile-main">
      <a :href="appHref('/jobs')">← 返回岗位浏览</a>
      <p v-if="loading" role="status">正在读取企业资料…</p>
      <section v-else-if="error" class="company-profile-panel" role="alert">{{ error }} <button type="button" @click="load">重新加载</button></section>
      <template v-else-if="company">
        <section class="company-profile-panel company-profile-hero">
          <div><p class="company-profile-eyebrow">企业主页 <span v-if="company.verified">· 已认证</span></p><h1>{{ company.name }}</h1><p>{{ [company.industry, company.city, company.size].filter(Boolean).join(' · ') || '企业暂未完善基本信息' }}</p></div>
          <button type="button" :disabled="following" @click="toggleFollow">{{ following ? '正在更新…' : company.followed ? '已关注 · 取消关注' : '关注企业' }}</button>
        </section>
        <section class="company-profile-panel"><h2>企业介绍</h2><p class="company-profile-intro">{{ company.intro || '企业暂未填写介绍' }}</p><dl><div><dt>办公地址</dt><dd>{{ company.address || '暂未提供' }}</dd></div><div><dt>企业网站</dt><dd><a v-if="website" :href="website" target="_blank" rel="noopener noreferrer">{{ company.website }}</a><span v-else>{{ company.website || '暂未提供' }}</span></dd></div></dl></section>
        <CompanyJobs :company-id="company.id" />
      </template>
      <p v-if="feedback" role="status">{{ feedback }}</p>
    </main>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import CompanyJobs from '@/components/agent/CompanyJobs.vue'
import { appHref } from '@/utils/agentNavigation'
import { getCompany, setCompanyFollowed } from '@/api/agent/company'

const route = useRoute()
const company = ref(null)
const loading = ref(false)
const error = ref('')
const feedback = ref('')
const following = ref(false)
let revision = 0
const website = computed(() => {
  const text = String(company.value?.website || '').trim()
  if (!text) return ''
  try {
    if (/^[a-z][a-z\d+.-]*:/i.test(text) && !/^https?:\/\//i.test(text)) return ''
    const url = new URL(/^https?:\/\//i.test(text) ? text : 'https://' + text)
    return ['http:', 'https:'].includes(url.protocol) && !url.username && !url.password ? url.href : ''
  } catch { return '' }
})
async function load() {
  const current = ++revision
  company.value = null
  error.value = ''
  feedback.value = ''
  const id = String(route.query.id || '')
  if (!/^[1-9]\d*$/.test(id)) { loading.value = false; error.value = '企业编号无效，请从真实岗位或联系人进入'; return }
  loading.value = true
  try {
    const response = await getCompany(id)
    if (current === revision) company.value = response.data
  } catch (failure) {
    if (current === revision) error.value = failure?.message || '企业资料读取失败'
  } finally { if (current === revision) loading.value = false }
}
async function toggleFollow() {
  if (following.value || !company.value) return
  following.value = true
  const current = revision
  try {
    const response = await setCompanyFollowed(company.value.id, !company.value.followed)
    if (current !== revision) return
    company.value.followed = response.data.followed === true
    feedback.value = company.value.followed ? '已关注该企业' : '已取消关注'
  } catch (failure) { if (current === revision) feedback.value = failure?.message || '关注操作失败' }
  finally { following.value = false }
}
watch(() => route.query.id, load, { immediate: true })
</script>

<style scoped>
.company-profile-page{min-height:100vh;background:#f5f7fa;color:#263e5b;font-family:"Microsoft YaHei",sans-serif}.company-profile-main{width:min(1040px,calc(100% - 32px));margin:28px auto 50px}.company-profile-main>a{color:#657b96;text-decoration:none;font-size:13px}.company-profile-panel{margin-top:20px;padding:28px;border:1px solid #e3eaf3;border-radius:12px;background:#fff}.company-profile-hero{display:flex;align-items:center;justify-content:space-between;gap:24px}.company-profile-eyebrow{color:#3777ce;font-size:12px}.company-profile-panel h1{margin:8px 0;font-size:26px}.company-profile-panel h2{font-size:18px}.company-profile-panel p{color:#687e97;line-height:1.9}.company-profile-intro{white-space:pre-wrap;overflow-wrap:anywhere}.company-profile-panel button{flex-shrink:0;padding:11px 18px;border:1px solid #bfd4f0;border-radius:8px;background:#edf5ff;color:#2466bc;cursor:pointer}.company-profile-panel dl{display:grid;gap:16px;margin-top:24px}.company-profile-panel dt{color:#8595a8;font-size:12px}.company-profile-panel dd{margin:5px 0 0;overflow-wrap:anywhere}.company-profile-panel a{color:#2466bc}@media(max-width:600px){.company-profile-panel{padding:18px}.company-profile-hero{align-items:flex-start;flex-direction:column}.company-profile-panel h1{font-size:22px}}
</style>
