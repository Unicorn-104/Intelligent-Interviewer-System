<template>
  <div class="app-shell">
    <AgentTopbar active="jobs" />
    <main class="main-content">
      <section class="page-header">
        <div>
          <p class="eyebrow">ROLE DISCOVERY</p>
          <h1>岗位浏览</h1>
          <p class="page-intro">从真实招聘岗位中筛选机会，查看详情后选择简历完成投递。</p>
        </div>
      </section>

      <section class="search-panel" aria-label="岗位搜索">
        <form class="search-row" @submit.prevent="loadJobs">
          <label class="search-box" for="jobSearch">
            <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.8" /><path d="m16 16 4.3 4.3" /></svg>
            <input id="jobSearch" v-model.trim="keyword" type="search" placeholder="搜索岗位名称、公司或技能关键词" autocomplete="off" />
            <button v-if="keyword" class="clear-search" type="button" aria-label="清除搜索" @click="keyword = ''; loadJobs()">×</button>
          </label>
          <button class="search-submit" type="submit"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.8" /><path d="m16 16 4.3 4.3" /></svg>搜索</button>
          <select v-model="sort" class="filter-select" aria-label="岗位排序" @change="loadJobs">
            <option value="match">按匹配度排序</option>
            <option value="latest">按最新发布排序</option>
            <option value="salary">按薪资范围排序</option>
          </select>
        </form>
        <div class="search-result-row">
          <div class="result-count">共找到 <span>{{ visibleJobs.length }}</span> 个匹配岗位</div>
          <div class="result-hint">支持岗位名、公司、技能和城市模糊搜索</div>
        </div>
        <div class="hot-tags">
          <span class="hot-label">试试：</span>
          <button v-for="tag in hotTags" :key="tag" class="hot-tag" type="button" @click="keyword = tag; loadJobs()">{{ tag }}</button>
        </div>
      </section>

      <section>
        <div class="list-toolbar">
          <div>
            <h2 class="list-title">{{ savedOnly ? '收藏的岗位' : keyword ? '搜索结果' : '推荐岗位' }}</h2>
            <p class="list-subtitle">{{ errorMessage || '岗位数据来自招聘数据库，可直接进入详情和投递流程' }}</p>
          </div>
          <div class="list-controls">
            <button class="saved-filter" type="button" :class="{ active: savedOnly }" :aria-pressed="savedOnly" @click="savedOnly = !savedOnly">
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg>
              <span>收藏</span><span class="saved-count">{{ savedJobs.size }}</span>
            </button>
            <div class="view-toggle">
              <button :class="{ active: !gridMode }" type="button" aria-label="列表视图" @click="gridMode = false"><svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h16" /></svg></button>
              <button :class="{ active: gridMode }" type="button" aria-label="网格视图" @click="gridMode = true"><svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" /><rect x="14" y="4" width="6" height="6" /><rect x="4" y="14" width="6" height="6" /><rect x="14" y="14" width="6" height="6" /></svg></button>
            </div>
          </div>
        </div>

        <div v-if="loading" class="empty-state visible"><strong>正在加载岗位</strong><span>正在读取最新岗位数据，请稍候。</span></div>
        <div v-else-if="visibleJobs.length" class="jobs-list" :class="{ 'grid-mode': gridMode }">
          <article v-for="job in visibleJobs" :key="job.id" class="job-card" @click="openJob(job.id)">
            <div class="job-main">
              <div class="job-card-head">
                <div class="company-logo">{{ companyMark(job.companyName) }}</div>
                <div class="job-heading">
                  <a class="job-title" :href="`/agent/job-detail?id=${job.id}`" @click.stop>{{ job.title }}</a>
                  <div class="job-company">{{ job.companyName }}</div>
                  <div class="job-location"><svg viewBox="0 0 24 24"><path d="M12 21s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12Z" /><circle cx="12" cy="9" r="2.2" /></svg>{{ job.workCity || '地点不限' }}</div>
                </div>
              </div>
              <div class="tag-row">
                <span class="job-tag primary">{{ job.statusText }}</span>
                <span v-if="job.skills?.[0]" class="job-tag">{{ job.skills[0] }}</span>
                <span class="job-tag">{{ job.educationText }}</span>
                <span v-if="job.experienceRequired" class="job-tag">{{ job.experienceRequired }}</span>
              </div>
              <div class="job-meta">
                <span v-if="job.responsibilities?.[0]"><svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h16" /></svg>{{ job.responsibilities[0] }}</span>
                <span v-if="job.skills?.length"><svg viewBox="0 0 24 24"><path d="M12 3v18M3 12h18" /></svg>{{ job.skills.slice(0, 3).join(' · ') }}</span>
              </div>
            </div>
            <div class="job-side">
              <div class="job-side-top"><div class="job-salary">{{ job.salaryText }}</div><div class="job-posted">{{ formatDate(job.publishedAt) }}</div></div>
              <div class="feedback" :class="{ progress: job.appliedFlag }">{{ job.appliedFlag ? '已投递，可查看进度' : '欢迎投递' }}</div>
              <div class="card-actions">
                <button class="save-button" type="button" :class="{ saved: isSaved(job.id) }" @click.stop="toggleSaved(job.id)">
                  <svg viewBox="0 0 24 24"><path d="M6 4.8A1.8 1.8 0 0 1 7.8 3h8.4A1.8 1.8 0 0 1 18 4.8V21l-6-3.7L6 21Z" /></svg><span>{{ isSaved(job.id) ? '已收藏' : '收藏岗位' }}</span>
                </button>
                <button class="apply-button" type="button" @click.stop="applyJob(job)">{{ job.appliedFlag ? '查看投递' : '投递简历' }}</button>
              </div>
            </div>
          </article>
        </div>
        <div v-else class="empty-state visible">
          <strong>{{ errorMessage ? '岗位加载失败' : (savedOnly ? '还没有符合条件的收藏岗位' : '没有找到匹配岗位') }}</strong>
          <span>{{ errorMessage || '换一个岗位名称、公司或技能关键词试试。' }}</span>
          <button v-if="errorMessage" class="search-submit" type="button" @click="loadJobs">重新加载</button>
        </div>
      </section>
    </main>
  </div>
  <div class="toast" :class="{ show: toastVisible }" role="status"><span>✓</span><span>{{ toastMessage }}</span></div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { listJobs } from '@/api/agent/job'

const jobs = ref([])
const keyword = ref('')
const sort = ref('match')
const loading = ref(false)
const errorMessage = ref('')
const savedOnly = ref(false)
const gridMode = ref(false)
const savedJobs = ref(new Set(readSavedJobs()))
const toastVisible = ref(false)
const toastMessage = ref('')
let toastTimer
const hotTags = ['AI 产品经理', 'React', '大模型应用', '用户增长', '杭州']
const visibleJobs = computed(() => savedOnly.value ? jobs.value.filter(job => savedJobs.value.has(String(job.id))) : jobs.value)

async function loadJobs() {
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await listJobs({ keyword: keyword.value || undefined, sort: sort.value, page: 1, size: 50 })
    jobs.value = response.data?.items || []
  } catch (error) {
    errorMessage.value = error?.message || '岗位数据暂时无法读取，请稍后重试'
  } finally {
    loading.value = false
  }
}

function readSavedJobs() {
  try {
    const saved = JSON.parse(localStorage.getItem('zhipin-ai-saved-jobs') || '[]')
    return Array.isArray(saved) ? saved.map(String) : []
  } catch {
    return []
  }
}

function persistSavedJobs() {
  try {
    localStorage.setItem('zhipin-ai-saved-jobs', JSON.stringify([...savedJobs.value]))
  } catch {
    // 隐私模式下保留当前页面状态。
  }
}

function isSaved(id) {
  return savedJobs.value.has(String(id))
}

function toggleSaved(id) {
  const next = new Set(savedJobs.value)
  const key = String(id)
  if (next.has(key)) {
    next.delete(key)
    showToast('已取消收藏')
  } else {
    next.add(key)
    showToast('已收藏该岗位')
  }
  savedJobs.value = next
  persistSavedJobs()
}

function openJob(id) {
  window.__agentNavigate(`/agent/job-detail?id=${encodeURIComponent(id)}`)
}

function applyJob(job) {
  if (job.appliedFlag && job.applicationId) {
    window.__agentNavigate(`/agent/application-detail?id=${encodeURIComponent(job.applicationId)}`)
  } else {
    window.__agentNavigate(`/agent/resume-select?job=${encodeURIComponent(job.id)}`)
  }
}

function companyMark(name) {
  return (name || '企业').slice(0, 2)
}

function formatDate(value) {
  return value ? `发布于 ${String(value).slice(5, 10)}` : '最新发布'
}

function showToast(message) {
  toastMessage.value = message
  toastVisible.value = true
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { toastVisible.value = false }, 2400)
}

onMounted(loadJobs)
</script>

<style scoped>
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}.main-content{width:min(1240px,calc(100% - 48px));margin:0 auto;padding:34px 0 56px}.page-header{margin-bottom:22px}.eyebrow{margin:0 0 7px;color:#2B7FFF;font-size:11px;font-weight:800;letter-spacing:1px}.page-header h1{margin:0;color:#1A3C6E;font-size:28px}.page-intro{margin:8px 0 0;color:#6B7A90;font-size:13px}.search-panel{padding:18px 20px;border:1px solid #E6EBF2;border-radius:10px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045)}.search-row{display:flex;gap:10px}.search-box{position:relative;display:flex;align-items:center;flex:1;height:42px;border:1px solid #DCE4EE;border-radius:8px;background:#fff}.search-box svg{width:18px;margin:0 11px;color:#96A3B5;stroke:currentColor;fill:none;stroke-width:1.8}.search-box input{width:100%;height:100%;border:0;outline:0;color:#172B4D;background:transparent}.clear-search{width:28px;height:28px;margin-right:5px;border:0;border-radius:6px;color:#6B7A90;background:transparent;font-size:18px}.search-submit{display:inline-flex;align-items:center;justify-content:center;gap:6px;min-width:84px;height:42px;padding:0 14px;border:0;border-radius:7px;color:#fff;background:#2B7FFF;font-size:12px;font-weight:800;cursor:pointer}.search-submit svg{width:16px;stroke:currentColor;fill:none;stroke-width:1.8}.filter-select{height:42px;padding:0 12px;border:1px solid #DCE4EE;border-radius:7px;color:#52647D;background:#fff}.search-result-row,.list-toolbar,.list-controls,.card-actions,.job-side-top{display:flex;align-items:center;justify-content:space-between;gap:12px}.search-result-row{margin-top:13px;color:#6B7A90;font-size:11px}.result-count span,.saved-count{color:#2B7FFF;font-weight:800}.result-hint{color:#A0ABBA}.hot-tags{display:flex;flex-wrap:wrap;gap:7px;margin-top:12px;align-items:center}.hot-label{color:#96A3B5;font-size:11px}.hot-tag{padding:5px 9px;border:1px solid #E0E8F3;border-radius:5px;color:#52647D;background:#F8FAFD;font-size:11px;cursor:pointer}.hot-tag:hover{border-color:#B9D0F1;color:#2B7FFF;background:#EAF2FF}.list-toolbar{margin:24px 0 13px}.list-title{margin:0;color:#1A3C6E;font-size:17px}.list-subtitle{margin:4px 0 0;color:#6B7A90;font-size:11px}.list-controls{justify-content:flex-end}.saved-filter{display:inline-flex;align-items:center;gap:6px;height:34px;padding:0 10px;border:1px solid #DDE6F1;border-radius:7px;color:#52647D;background:#fff;font-size:11px;cursor:pointer}.saved-filter svg{width:15px;stroke:currentColor;fill:none;stroke-width:1.7}.saved-filter.active{color:#2B7FFF;background:#EAF2FF;border-color:#BFD5F2}.view-toggle{display:flex;border:1px solid #DDE6F1;border-radius:7px;overflow:hidden;background:#fff}.view-toggle button{width:34px;height:32px;border:0;color:#96A3B5;background:#fff;cursor:pointer}.view-toggle button+button{border-left:1px solid #DDE6F1}.view-toggle button.active{color:#2B7FFF;background:#EAF2FF}.view-toggle svg{width:16px;margin:auto;stroke:currentColor;fill:none;stroke-width:1.8}.jobs-list{display:grid;gap:13px}.jobs-list.grid-mode{grid-template-columns:repeat(2,minmax(0,1fr))}.job-card{display:grid;grid-template-columns:minmax(0,1fr) 260px;gap:22px;padding:18px 20px;border:1px solid #E6EBF2;border-radius:10px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045);cursor:pointer;transition:.18s}.job-card:hover{border-color:#BFD5F2;box-shadow:0 10px 24px rgba(26,60,110,.09);transform:translateY(-1px)}.job-card-head{display:flex;gap:12px}.company-logo{width:42px;height:42px;display:grid;place-items:center;flex:0 0 auto;border-radius:9px;color:#fff;background:#2B7FFF;font-size:12px;font-weight:800}.job-heading{min-width:0}.job-title{display:block;overflow:hidden;color:#1A3C6E;font-size:15px;font-weight:800;text-decoration:none;text-overflow:ellipsis;white-space:nowrap}.job-company{margin-top:3px;color:#6B7A90;font-size:12px}.job-location{display:flex;align-items:center;gap:5px;margin-top:6px;color:#96A3B5;font-size:11px}.job-location svg{width:14px;stroke:currentColor;fill:none;stroke-width:1.7}.tag-row{display:flex;flex-wrap:wrap;gap:7px;margin-top:15px}.job-tag{padding:4px 8px;border-radius:5px;color:#5C708A;background:#F1F4F8;font-size:10px}.job-tag.primary{color:#2B7FFF;background:#EAF2FF}.job-meta{display:flex;flex-wrap:wrap;gap:8px 16px;margin-top:14px;color:#52647D;font-size:11px}.job-meta span{display:flex;align-items:flex-start;gap:5px}.job-meta svg{width:14px;flex:0 0 auto;margin-top:2px;stroke:#96A3B5;fill:none;stroke-width:1.7}.job-side{display:flex;flex-direction:column;justify-content:space-between;min-width:0}.job-salary{color:#1A3C6E;font-size:17px;font-weight:800}.job-posted{color:#A0ABBA;font-size:10px}.feedback{align-self:flex-start;margin-top:18px;padding:5px 8px;border-radius:5px;color:#7C8B9D;background:#F3F6FA;font-size:10px}.feedback.progress{color:#16865F;background:#E8F7F1}.card-actions{justify-content:flex-end;margin-top:14px}.save-button{display:inline-flex;align-items:center;gap:5px;padding:0;border:0;color:#8291A4;background:transparent;font-size:10px;cursor:pointer}.save-button svg{width:16px;stroke:currentColor;fill:none;stroke-width:1.7}.save-button.saved{color:#2B7FFF}.save-button.saved svg{fill:currentColor}.apply-button{min-height:32px;padding:0 12px;border:0;border-radius:6px;color:#fff;background:#2B7FFF;font-size:11px;font-weight:800;cursor:pointer}.empty-state{display:none;padding:48px 20px;border:1px dashed #CBD9E8;border-radius:10px;color:#6B7A90;background:#fff;text-align:center}.empty-state.visible{display:grid;place-items:center;gap:8px}.empty-state strong{color:#1A3C6E;font-size:15px}.empty-state span{font-size:12px}.empty-state .search-submit{margin-top:8px}.toast{position:fixed;right:24px;bottom:24px;z-index:50;display:flex;gap:8px;padding:11px 15px;border:1px solid #CCE9DE;border-radius:8px;color:#176B50;background:#F2FBF7;box-shadow:0 10px 25px rgba(23,43,77,.1);font-size:12px;opacity:0;transform:translateY(8px);pointer-events:none;transition:.18s}.toast.show{opacity:1;transform:translateY(0)}@media(max-width:850px){.main-content{width:calc(100% - 32px)}.job-card{grid-template-columns:1fr}.job-side{gap:8px}.job-card .feedback{margin-top:4px}.jobs-list.grid-mode{grid-template-columns:1fr}}@media(max-width:560px){.main-content{width:calc(100% - 28px);padding-top:25px}.search-row{display:grid;grid-template-columns:1fr 84px}.filter-select{grid-column:1/-1}.search-result-row{display:block}.result-hint{margin-top:5px}.list-toolbar{display:block}.list-controls{justify-content:flex-start;margin-top:12px}.job-card{padding:15px}.job-title{white-space:normal}.card-actions{justify-content:space-between}}
</style>
