<script setup>
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Search, Plus, Sparkles, GraduationCap, CalendarClock, Users, WandSparkles, ChevronRight, Pencil, Copy, Share2 } from '@/views/enterprise/components/icons'
import JobCard from '@/views/enterprise/components/JobCard.vue'
import PublishJobModal from '@/views/enterprise/components/PublishJobModal.vue'
import ShareJobModal from '@/views/enterprise/components/ShareJobModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listJobs, jobDepartments, changeJobStatus, jobDetail, duplicateJob } from '@/api/system/job'

const router = useRouter()
const route = useRoute()
const jobs = ref([])
const total = ref(0)
const pageNum = ref(1)
// 顶栏全局搜索带 ?keyword= 进入岗位页时，直接带入关键词
const search = ref(typeof route.query.keyword === 'string' ? route.query.keyword : '')
const department = ref('')
const statusFilter = ref('')
const departments = ref([])
const selectedId = ref(null)
const publishOpen = ref(false)
const toast = ref('')
const jobListEl = ref(null)
const pageSize = ref(3)
let resizeObserver

const educationMap = { 1: '不限', 2: '大专', 3: '本科', 4: '硕士', 5: '博士' }
const statusMeta = { 1: { text: '招聘中', tone: 'green' }, 2: { text: '已暂停', tone: 'gray' }, 0: { text: '已下线', tone: 'red' } }

function parseRow(row) {
  let jd = {}
  try { jd = JSON.parse(row.jdJson || '{}') } catch (e) { jd = {} }
  return {
    id: row.posId,
    name: row.title,
    dept: row.dept || '未分配',
    city: row.city || '—',
    salary: row.salaryMin != null ? `${Math.round(row.salaryMin / 1000)}-${Math.round(row.salaryMax / 1000)}K` : '面议',
    education: educationMap[row.education] || '不限',
    experience: row.experience || '经验不限',
    date: row.date,
    applicants: row.applicantCount || 0,
    status: (statusMeta[row.status] || statusMeta[0]).text,
    tone: (statusMeta[row.status] || statusMeta[0]).tone,
    statusCode: row.status,
    active: row.status === 1,
    skills: (jd.requirements || []).slice(0, 3),
    responsibilities: jd.responsibilities || [],
    requirements: jd.requirements || []
  }
}

// 根据列表容器可视高度动态计算每页条数，让卡片铺满区域后再换页
function updatePageSize() {
  const el = jobListEl.value
  if (!el) return
  const card = el.querySelector('.job-card')
  if (!card) return
  const styles = getComputedStyle(el)
  const gap = parseFloat(styles.rowGap) || 9
  const rowH = card.offsetHeight + gap
  if (rowH <= 0) return
  const available = el.clientHeight
  const fit = Math.max(1, Math.floor((available + gap) / rowH))
  if (fit !== pageSize.value) {
    pageSize.value = fit
    pageNum.value = 1
    fetchJobs()
  }
}

async function fetchJobs() {
  const res = await listJobs({ pageNum: pageNum.value, pageSize: pageSize.value, keyword: search.value, dept: department.value, status: statusFilter.value === '' ? undefined : statusFilter.value })
  jobs.value = (res.rows || []).map(parseRow)
  total.value = res.total || 0
  if (!jobs.value.find(j => j.id === selectedId.value)) selectedId.value = jobs.value[0]?.id || null
}

const selected = computed(() => jobs.value.find(j => j.id === selectedId.value) || jobs.value[0] || {})
const pages = computed(() => Math.max(1, Math.ceil(total.value / pageSize.value)))

function goPage(p) {
  if (p < 1 || p > pages.value || p === pageNum.value) return
  pageNum.value = p
  fetchJobs()
}

function doFilter() {
  pageNum.value = 1
  fetchJobs()
}

// 已在岗位页时再次使用顶栏搜索，仅查询串变化，这里同步关键词并重新检索
watch(() => route.query.keyword, kw => {
  if (typeof kw !== 'string') return
  search.value = kw
  pageNum.value = 1
  fetchJobs()
})

async function toggleJob(job) {
  const next = job.active ? 2 : 1
  await changeJobStatus(job.id, next)
  job.active = !job.active
  job.statusCode = next
  job.status = (statusMeta[next] || statusMeta[0]).text
  job.tone = (statusMeta[next] || statusMeta[0]).tone
  notify(job.active ? '岗位已重新开启招聘' : '岗位已暂停招聘')
}

function notify(msg) { toast.value = msg; setTimeout(() => toast.value = '', 2200) }

// 编辑已发布岗位：加载详情后复用发布弹窗（不改变岗位状态与流程模板）
const editOpen = ref(false)
const editJob = ref(null)

async function openEdit() {
  if (!selected.value.id) return notify('请先选择需要编辑的岗位')
  try {
    const res = await jobDetail(selected.value.id)
    const data = res.data || {}
    const job = data.job || {}
    let jd = {}
    try { jd = JSON.parse(job.jdJson || '{}') } catch (e) { jd = {} }
    editJob.value = {
      posId: job.posId,
      title: job.title,
      dept: job.dept,
      city: job.city,
      salaryMin: job.salaryMin,
      salaryMax: job.salaryMax,
      jobType: job.jobType,
      education: job.education,
      experience: job.experience,
      description: jd.description || '',
      requirements: jd.requirements || [],
      responsibilities: jd.responsibilities || [],
      skills: (data.skills || []).map(s => s.name)
    }
    editOpen.value = true
  } catch (e) { /* 拦截器已提示 */ }
}

async function onEdited() {
  editOpen.value = false
  await fetchJobs()
  notify('岗位信息已保存')
}

async function copyJob() {
  if (!selected.value.id) return notify('请先选择需要复制的岗位')
  try {
    const res = await duplicateJob(selected.value.id)
    const newId = res.data?.posId
    notify(res.data?.message || '已复制为草稿岗位')
    await fetchJobs()
    if (newId && jobs.value.some(j => j.id === newId)) selectedId.value = newId
  } catch (e) { /* 拦截器已提示 */ }
}

// 分享当前查看的岗位：从消息中心已有会话的联系人里选择后发送岗位卡片
const shareOpen = ref(false)

function openShare() {
  if (!selected.value.id) return notify('请先选择需要分享的岗位')
  shareOpen.value = true
}

function onShared(name) {
  shareOpen.value = false
  notify(`岗位卡片已分享给 ${name}`)
}

onMounted(async () => {
  const res = await jobDepartments()
  await fetchJobs()
  await nextTick()
  updatePageSize()
  resizeObserver = new ResizeObserver(() => updatePageSize())
  if (jobListEl.value) resizeObserver.observe(jobListEl.value)
})

onUnmounted(() => resizeObserver?.disconnect())
</script>

<template>
  <div class="page jobs-page">
    <div class="page-heading">
      <div><h1>岗位管理</h1><p>集中管理招聘岗位，AI 实时解析岗位画像</p></div>
      <div class="heading-actions"><button class="btn primary" @click="publishOpen = true"><Plus :size="16"/>发布新岗位</button></div>
    </div>

    <div class="jobs-layout">
      <aside class="card analysis-card">
        <div class="analysis-title"><span class="ai-icon"><Sparkles :size="17"/></span><h2>岗位分析结果</h2><span class="pill">AI</span><small>刚刚更新</small></div>
        <div class="analysis-body">
        <div class="current"><label>当前查看岗位</label><b>{{ selected.name || '暂无岗位' }}</b><span v-if="selected.name" class="pill" :class="selected.tone"><i class="dot"/>{{ selected.status }}</span><p>{{ selected.dept }} · {{ selected.city }} · 发布于 {{ selected.date }}</p></div>
        <div class="analysis-grid">
          <div><span class="cell-head"><span class="mini-icon"><GraduationCap :size="14"/></span><small>学历要求</small></span><b>{{ selected.education }}</b></div>
          <div><span class="cell-head"><span class="mini-icon"><CalendarClock :size="14"/></span><small>工作年限</small></span><b>{{ selected.experience }}</b></div>
          <div><span class="cell-head"><span class="mini-icon"><Users :size="14"/></span><small>投递人数</small></span><b>{{ selected.applicants }} 人</b></div>
          <div><span class="cell-head"><span class="mini-icon"><WandSparkles :size="14"/></span><small>综合匹配度</small></span><b class="primary-text">92%</b></div>
        </div>
        <div class="profile-section"><h3>技能标签</h3><div class="tag-cloud"><span v-for="skill in selected.skills" :key="skill">{{ skill }}</span></div></div>
        <div class="profile-section"><h3>职责关键词</h3><ul><li v-for="r in selected.responsibilities" :key="r">{{ r }}</li></ul></div>
        <div class="match-box"><div><span>胜任力模型匹配度</span><b>92%</b></div><div class="meter"><i /></div><p><span>专业技能 96%</span><span>项目交付 90%</span><span>沟通协作 88%</span></p></div>
        </div>
        <div class="analysis-actions"><div class="row-actions"><button class="btn sm" @click="openEdit"><Pencil :size="13"/>编辑</button><button class="btn sm" @click="copyJob"><Copy :size="13"/>复制</button><button class="btn sm" :disabled="selected.statusCode !== 1" :title="selected.statusCode === 1 ? '分享该岗位给消息中心联系人' : '仅招聘中的岗位可分享'" @click="openShare"><Share2 :size="13"/>分享</button></div><button class="btn ghost-primary" @click="router.push(`/enterprise/jobs/${selected.id}`)">查看完整岗位详情<ChevronRight :size="14"/></button><button class="process-btn" @click="router.push(`/enterprise/jobs/${selected.id}/workflow`)">招聘流程配置 <ChevronRight :size="14"/></button></div>
      </aside>

      <section class="card list-card">
        <div class="list-head"><div><h2>所有岗位 <span>{{ total }}</span></h2><p>点击岗位查看 AI 岗位画像与详情</p></div></div>
        <div class="filters">
          <label class="search-box"><Search :size="16"/><input v-model="search" placeholder="搜索岗位名称、关键词" @keyup.enter="doFilter"/></label>
          <select v-model="department" class="select" @change="doFilter"><option value="">全部部门</option><option v-for="d in departments" :key="d" :value="d">{{ d }}</option></select>
          <select v-model="statusFilter" class="select" @change="doFilter"><option value="">全部状态</option><option value="1">招聘中</option><option value="2">已暂停</option><option value="0">已下线</option></select>
        </div>
        <div ref="jobListEl" class="job-list"><JobCard v-for="job in jobs" :key="job.id" :job="job" :selected="selectedId === job.id" @select="selectedId = job.id" @toggle="toggleJob(job)"/></div>
        <div class="pagination"><span>共 {{ total }} 个岗位</span><button :disabled="pageNum <= 1" @click="goPage(pageNum - 1)">‹</button><button v-for="p in pages" :key="p" :class="{ active: p === pageNum }" @click="goPage(p)">{{ p }}</button><button :disabled="pageNum >= pages" @click="goPage(pageNum + 1)">›</button></div>
      </section>
    </div>
    <PublishJobModal v-if="publishOpen" @close="publishOpen = false" @submitted="(s) => { publishOpen = false; fetchJobs(); notify(s === 0 ? '草稿已保存' : '岗位发布成功') }" />
    <PublishJobModal v-if="editOpen" :edit="true" :job="editJob" @close="editOpen = false" @submitted="onEdited" />
    <ShareJobModal v-if="shareOpen" :job="selected" @close="shareOpen = false" @sent="onShared" />
    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.heading-actions{display:flex;gap:10px}.jobs-layout{display:grid;grid-template-columns:minmax(340px,38%) minmax(600px,62%);gap:16px;align-items:stretch}.analysis-card,.list-card{height:calc(100vh - 182px);min-height:540px}.analysis-card{padding:18px;display:flex;flex-direction:column}.analysis-body{flex:1;min-height:0;overflow-y:auto;padding-right:4px;margin-right:-4px}.analysis-title{display:flex;align-items:center;gap:7px}.analysis-title h2{font-size:17px}.analysis-title small{margin-left:auto;color:#9aa8ba;font-size:10px}.ai-icon{width:31px;height:31px;border-radius:9px;display:grid;place-items:center;color:#2563eb;background:#e9f1ff}.current{background:linear-gradient(135deg,#edf4ff,#f8fbff);border:1px solid #dce8fc;border-radius:12px;padding:14px;margin:15px 0}.current label{display:block;color:#7d8da5;font-size:10px;margin-bottom:7px}.current b{font-size:17px;margin-right:7px}.current p{font-size:10px;color:#8090a8;margin-top:7px}.analysis-grid{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e5ebf3;border-radius:11px;overflow:hidden}.analysis-grid>div{padding:11px 12px;display:flex;flex-direction:column;gap:6px;border-bottom:1px solid #e8edf4}.analysis-grid>div:nth-child(odd){border-right:1px solid #e8edf4}.analysis-grid>div:nth-child(n+3){border-bottom:0}.cell-head{display:flex;align-items:center;gap:6px}.mini-icon{width:22px;height:22px;border-radius:6px;display:grid;place-items:center;color:#4b7ae3;background:#eef4ff;flex:none}.analysis-grid small{font-size:10px;color:#91a0b4;line-height:1}.analysis-grid b{font-size:13px}.primary-text{color:#2563eb}.profile-section{margin-top:15px}.profile-section h3{font-size:12px;margin-bottom:8px}.tag-cloud{display:flex;gap:6px;flex-wrap:wrap}.tag-cloud span{padding:5px 8px;background:#edf4ff;color:#2563eb;border-radius:6px;font-size:11px}.profile-section ul{list-style:none;margin:0;padding:0}.profile-section li{display:flex;align-items:center;gap:8px;font-size:11px;color:#5b6c85;margin:7px 0}.profile-section li:before{content:'';width:5px;height:5px;border-radius:50%;background:#3b82f6;flex:none}.match-box{margin-top:13px;padding:12px;background:#f7f9fc;border-radius:10px}.match-box>div:first-child{display:flex;justify-content:space-between;font-size:11px}.match-box>div b{color:#2563eb}.meter{height:7px;background:#dce5f0;border-radius:6px;margin:8px 0}.meter i{display:block;width:92%;height:100%;border-radius:inherit;background:linear-gradient(90deg,#1d4ed8,#0ea5e9)}.match-box p{display:flex;justify-content:space-between;color:#77869c;font-size:9px}.analysis-actions{margin-top:auto;display:flex;flex-direction:column;gap:4px}.analysis-actions .row-actions{display:flex;gap:6px}.analysis-actions .row-actions .btn{flex:1}.analysis-actions .btn{width:100%}.process-btn{border:0;background:transparent;color:#2563eb;height:35px;display:flex;gap:5px;align-items:center;justify-content:center;font-size:11px}.list-card{padding:18px;display:flex;flex-direction:column}.list-head h2{font-size:19px}.list-head h2 span{font-size:11px;color:#2563eb;background:#eaf1ff;border-radius:11px;padding:4px 8px;margin-left:4px}.list-head p{font-size:10px;color:#9aa8ba;margin-top:4px}.filters{display:grid;grid-template-columns:1.5fr .8fr .72fr;gap:9px;margin:15px 0 12px}.search-box{height:38px;border:1px solid #dce4ee;border-radius:9px;display:flex;align-items:center;gap:8px;padding:0 11px;color:#8da0ba}.search-box input{width:100%;border:0;outline:0;font-size:12px}.job-list{flex:1;min-height:0;display:flex;flex-direction:column;gap:9px;overflow:auto;padding:1px 3px 1px 1px}.pagination{margin-top:auto;padding-top:12px;display:flex;align-items:center;justify-content:flex-end;gap:5px;color:#8a99ad;font-size:11px}.pagination span{margin-right:auto}.pagination button{width:29px;height:29px;border:1px solid #dde5ef;background:white;border-radius:7px;color:#6b7b92}.pagination button.active{color:white;background:#2563eb;border-color:#2563eb}
</style>
