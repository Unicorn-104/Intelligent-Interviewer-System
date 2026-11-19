<template>
  <div class="contact-profile-page">
    <AgentTopbar active="messages" />
    <main class="contact-profile-main">
      <a :href="appHref('/messages')">← 返回消息通知</a>
      <p v-if="loading" role="status">正在读取招聘联系人…</p>
      <section v-else-if="error" class="contact-profile-card" role="alert">{{ error }} <button type="button" @click="load">重新加载</button></section>
      <template v-else-if="contact">
        <section class="contact-profile-card">
          <span class="contact-profile-avatar">{{ (contact.name || '联').slice(0, 1) }}</span>
          <div><p>企业招聘联系人</p><h1>{{ contact.name }}</h1><a :href="appHref('/company-profile?id=' + encodeURIComponent(contact.companyId))">{{ contact.companyName }} →</a></div>
          <a class="contact-profile-action" :href="appHref('/messages?peerId=' + encodeURIComponent(contact.id) + '&peerName=' + encodeURIComponent(contact.name))">发起对话</a>
        </section>
        <p class="contact-profile-note">以下为该企业当前公开招聘的岗位。联系人未公开的信息不予展示。</p>
        <CompanyJobs :company-id="contact.companyId" />
      </template>
    </main>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import CompanyJobs from '@/components/agent/CompanyJobs.vue'
import { appHref } from '@/utils/agentNavigation'
import { getRecruiter } from '@/api/agent/company'
const route = useRoute()
const contact = ref(null)
const loading = ref(false)
const error = ref('')
let revision = 0
async function load() {
  const current = ++revision
  contact.value = null
  error.value = ''
  const id = String(route.query.id || '')
  if (!/^[1-9]\d*$/.test(id)) { loading.value = false; error.value = '联系人编号无效，请从真实会话进入'; return }
  loading.value = true
  try {
    const response = await getRecruiter(id)
    if (current === revision) contact.value = response.data
  } catch (failure) { if (current === revision) error.value = failure?.message || '联系人读取失败' }
  finally { if (current === revision) loading.value = false }
}
watch(() => route.query.id, load, { immediate: true })
</script>

<style scoped>
.contact-profile-page{min-height:100vh;background:#f5f7fa;color:#2b4565;font-family:"Microsoft YaHei",sans-serif}.contact-profile-main{width:min(1040px,calc(100% - 32px));margin:28px auto 50px}.contact-profile-main a{color:#2d6fc7;text-decoration:none}.contact-profile-card{display:flex;align-items:center;gap:20px;margin-top:20px;padding:28px;border:1px solid #e3eaf3;border-radius:12px;background:#fff}.contact-profile-avatar{display:grid;width:64px;height:64px;place-items:center;flex-shrink:0;border-radius:50%;background:#454b54;color:#fff;font-size:24px}.contact-profile-card h1{margin:5px 0 10px;font-size:24px}.contact-profile-card p,.contact-profile-note{color:#7a8ca3;font-size:13px}.contact-profile-action{margin-left:auto;padding:12px 20px;border-radius:8px;background:#eaf3ff;white-space:nowrap}.contact-profile-card button{padding:8px 14px;border:1px solid #c7d9f0;background:#fff;color:#2466bc;border-radius:6px}@media(max-width:600px){.contact-profile-card{flex-wrap:wrap;padding:18px}.contact-profile-action{margin:0}}
</style>
