<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Search, Upload, Plus, Sparkles, GraduationCap, CalendarClock, Users, WandSparkles, ChevronRight, SlidersHorizontal } from '@/views/enterprise/components/icons'
import { jobs as sourceJobs } from '@/views/enterprise/data/mock'
import JobCard from '@/views/enterprise/components/JobCard.vue'
import PublishJobModal from '@/views/enterprise/components/PublishJobModal.vue'
import ImportJobModal from '@/views/enterprise/components/ImportJobModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { api, reserveApi } from '@/views/enterprise/api/contract'

const router = useRouter()
const jobs = ref(sourceJobs.map(j => ({ ...j })))
const selectedId = ref(1)
const search = ref('')
const department = ref('全部部门')
const publishOpen = ref(false)
const importOpen = ref(false)
const toast = ref('')
const selected = computed(() => jobs.value.find(j => j.id === selectedId.value) || jobs.value[0])
const filteredJobs = computed(() => jobs.value.filter(j => (j.pos_title || j.name).includes(search.value) && (department.value === '全部部门' || (j.pos_department || j.dept) === department.value)))
function notify(msg) { toast.value = msg; setTimeout(() => toast.value = '', 2200) }
reserveApi(api.positions.list, { status: null, keyword: '', page: 1, pageSize: 20 })
</script>

<template>
  <div class="page jobs-page">
    <div class="page-heading">
      <div><h1>岗位管理</h1><p>集中管理招聘岗位，AI 实时解析岗位画像</p></div>
      <div class="heading-actions"><button class="btn ghost-primary" @click="importOpen = true"><Upload :size="16"/>导入岗位文件</button><button class="btn primary" @click="publishOpen = true"><Plus :size="16"/>发布新岗位</button></div>
    </div>

    <div class="jobs-layout">
      <aside class="card analysis-card">
        <div class="analysis-title"><span class="ai-icon"><Sparkles :size="17"/></span><h2>岗位分析结果</h2><span class="pill">AI</span><small>刚刚更新</small></div>
        <div class="current"><label>当前查看岗位</label><b>{{ selected.name }}</b><span class="pill green"><i class="dot"/>{{ selected.status }}</span><p>{{ selected.dept }} · {{ selected.city }} · 发布于 {{ selected.date }}</p></div>
        <div class="analysis-grid">
          <div><span class="mini-icon"><GraduationCap :size="16"/></span><small>学历要求</small><b>本科及以上</b></div>
          <div><span class="mini-icon"><CalendarClock :size="16"/></span><small>工作年限</small><b>3-5 年</b></div>
          <div><span class="mini-icon"><Users :size="16"/></span><small>招聘人数</small><b>{{ selected.count }} 人</b></div>
          <div><span class="mini-icon"><WandSparkles :size="16"/></span><small>综合匹配度</small><b class="primary-text">92%</b></div>
        </div>
        <div class="profile-section"><h3>技能标签</h3><div class="tag-cloud"><span v-for="skill in selected.skills" :key="skill">{{ skill }}</span><span>工程化</span><span>团队协作</span></div></div>
        <div class="profile-section"><h3>职责关键词</h3><ul><li>负责核心业务产品的前端架构设计</li><li>主导性能优化、工程化与组件库建设</li><li>跨团队推进技术方案评审与交付</li></ul></div>
        <div class="match-box"><div><span>胜任力模型匹配度</span><b>92%</b></div><div class="meter"><i /></div><p><span>专业技能 96%</span><span>项目交付 90%</span><span>沟通协作 88%</span></p></div>
        <div class="analysis-actions"><button class="btn ghost-primary" @click="router.push(`/enterprise/jobs/${selected.id}`)">查看完整岗位详情<ChevronRight :size="14"/></button><button class="process-btn" @click="router.push(`/enterprise/jobs/${selected.id}/workflow`)">招聘流程配置 <ChevronRight :size="14"/></button></div>
      </aside>

      <section class="card list-card">
        <div class="list-head"><div><h2>所有岗位 <span>{{ jobs.length }}</span></h2><p>点击岗位查看 AI 岗位画像与详情</p></div></div>
        <div class="filters">
          <label class="search-box"><Search :size="16"/><input v-model="search" placeholder="搜索岗位名称、关键词"/></label>
          <select v-model="department" class="select"><option>全部部门</option><option>产品研发部</option><option>产品中心</option><option>设计中心</option><option>数据平台部</option></select>
          <select class="select"><option>全部状态</option><option>招聘中</option><option>已暂停</option></select>
          <button class="filter-btn"><SlidersHorizontal :size="16"/>筛选</button>
        </div>
        <div class="job-list"><JobCard v-for="job in filteredJobs" :key="job.id" :job="job" :selected="selectedId === job.id" @select="selectedId = job.id" @toggle="job.active = !job.active; job.status = job.active ? '招聘中' : '已暂停'; job.tone = job.active ? 'green' : 'gray'"/></div>
        <div class="pagination"><span>共 {{ filteredJobs.length }} 个岗位</span><button disabled>‹</button><button class="active">1</button><button>2</button><button>3</button><button>›</button></div>
      </section>
    </div>
    <PublishJobModal v-if="publishOpen" @close="publishOpen = false" @submit="publishOpen = false; notify('岗位发布成功')" />
    <ImportJobModal v-if="importOpen" @close="importOpen = false" @done="importOpen = false; notify('文件解析完成，岗位画像已生成')" />
    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.heading-actions{display:flex;gap:10px}.jobs-layout{display:grid;grid-template-columns:minmax(340px,38%) minmax(600px,62%);gap:16px;align-items:stretch}.analysis-card,.list-card{height:calc(100vh - 134px);min-height:695px}.analysis-card{padding:18px;display:flex;flex-direction:column}.analysis-title{display:flex;align-items:center;gap:7px}.analysis-title h2{font-size:17px}.analysis-title small{margin-left:auto;color:#9aa8ba;font-size:10px}.ai-icon{width:31px;height:31px;border-radius:9px;display:grid;place-items:center;color:#2563eb;background:#e9f1ff}.current{background:linear-gradient(135deg,#edf4ff,#f8fbff);border:1px solid #dce8fc;border-radius:12px;padding:14px;margin:15px 0}.current label{display:block;color:#7d8da5;font-size:10px;margin-bottom:7px}.current b{font-size:17px;margin-right:7px}.current p{font-size:10px;color:#8090a8;margin-top:7px}.analysis-grid{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e5ebf3;border-radius:11px;overflow:hidden}.analysis-grid>div{padding:11px 10px;display:grid;grid-template-columns:25px 1fr;align-items:center;border-bottom:1px solid #e8edf4}.analysis-grid>div:nth-child(odd){border-right:1px solid #e8edf4}.analysis-grid>div:nth-child(n+3){border-bottom:0}.mini-icon{grid-row:1/3;width:23px;height:23px;border-radius:6px;display:grid;place-items:center;color:#4b7ae3;background:#eef4ff}.analysis-grid small{font-size:9px;color:#91a0b4}.analysis-grid b{font-size:12px}.primary-text{color:#2563eb}.profile-section{margin-top:15px}.profile-section h3{font-size:12px;margin-bottom:8px}.tag-cloud{display:flex;gap:6px;flex-wrap:wrap}.tag-cloud span{padding:5px 8px;background:#edf4ff;color:#2563eb;border-radius:6px;font-size:11px}.profile-section ul{list-style:none;margin:0;padding:0}.profile-section li{font-size:11px;color:#5b6c85;margin:7px 0;padding-left:13px;position:relative}.profile-section li:before{content:'';position:absolute;left:1px;top:6px;width:5px;height:5px;border-radius:50%;background:#3b82f6}.match-box{margin-top:13px;padding:12px;background:#f7f9fc;border-radius:10px}.match-box>div:first-child{display:flex;justify-content:space-between;font-size:11px}.match-box>div b{color:#2563eb}.meter{height:7px;background:#dce5f0;border-radius:6px;margin:8px 0}.meter i{display:block;width:92%;height:100%;border-radius:inherit;background:linear-gradient(90deg,#1d4ed8,#0ea5e9)}.match-box p{display:flex;justify-content:space-between;color:#77869c;font-size:9px}.analysis-actions{margin-top:auto;display:flex;flex-direction:column;gap:4px}.analysis-actions .btn{width:100%}.process-btn{border:0;background:transparent;color:#2563eb;height:35px;display:flex;gap:5px;align-items:center;justify-content:center;font-size:11px}.list-card{padding:18px;display:flex;flex-direction:column}.list-head h2{font-size:19px}.list-head h2 span{font-size:11px;color:#2563eb;background:#eaf1ff;border-radius:11px;padding:4px 8px;margin-left:4px}.list-head p{font-size:10px;color:#9aa8ba;margin-top:4px}.filters{display:grid;grid-template-columns:1.5fr .8fr .72fr auto;gap:9px;margin:15px 0 12px}.search-box{height:38px;border:1px solid #dce4ee;border-radius:9px;display:flex;align-items:center;gap:8px;padding:0 11px;color:#8da0ba}.search-box input{width:100%;border:0;outline:0;font-size:12px}.filter-btn{height:38px;border:1px solid #dce4ee;border-radius:9px;background:white;color:#50627e;display:flex;align-items:center;gap:6px;padding:0 12px}.job-list{display:flex;flex-direction:column;gap:9px;overflow:auto;padding:1px 3px 1px 1px}.pagination{margin-top:auto;padding-top:12px;display:flex;align-items:center;justify-content:flex-end;gap:5px;color:#8a99ad;font-size:11px}.pagination span{margin-right:auto}.pagination button{width:29px;height:29px;border:1px solid #dde5ef;background:white;border-radius:7px;color:#6b7b92}.pagination button.active{color:white;background:#2563eb;border-color:#2563eb}
</style>



