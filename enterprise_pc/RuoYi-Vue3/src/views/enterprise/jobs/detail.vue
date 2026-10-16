<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, Pencil, PauseCircle, Sparkles, FileText, MessageCircle, BellRing, CalendarPlus, Check, ChevronDown, Settings2, Copy } from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { jobDetail, changeJobStatus } from '@/api/system/job'

const route = useRoute()
const router = useRouter()
const posId = route.params.id
const job = ref({})
const funnel = ref([])
const candidates = ref([])
const stages = ref([])
const selected = ref(new Set())
const toast = ref('')

const educationMap = { 1: '不限', 2: '大专及以上', 3: '本科及以上', 4: '硕士及以上', 5: '博士' }
const jobTypeMap = { 1: '全职', 2: '实习', 3: '兼职' }
const statusTone = { 0: 'gray', 1: 'blue', 2: 'purple', 3: 'red', 4: 'green', 5: 'green', 6: 'gray', 7: 'blue', 8: 'red', 9: 'orange' }
const stageTypeMap = { 1: '笔试', 2: 'AI 面试', 3: 'HR 面试', 4: '实操' }

const checkedCount = computed(() => selected.value.size)
const jd = computed(() => { try { return JSON.parse(job.value.jdJson || '{}') } catch (e) { return {} } })
const salary = computed(() => job.value.salaryMin != null ? `${Math.round(job.value.salaryMin / 1000)}-${Math.round(job.value.salaryMax / 1000)}K` : '面议')

function toggle(i) { const s = new Set(selected.value); s.has(i) ? s.delete(i) : s.add(i); selected.value = s }
function notify(v) { toast.value = v; setTimeout(() => toast.value = '', 2000) }

async function closeRecruit() {
  await changeJobStatus(posId, 2)
  job.value.status = 2
  notify('招聘已关闭（岗位已暂停）')
}

async function load() {
  const res = await jobDetail(posId)
  const d = res.data
  job.value = d.job || {}
  const f = d.funnel || {}
  const total = Number(f.total) || 0
  funnel.value = [
    { label: '简历总量', value: total, width: 100 },
    { label: '初筛通过待面试', value: Number(f.passed) || 0, width: total ? (Number(f.passed) / total) * 100 : 0 },
    { label: '面试中', value: Number(f.interviewing) || 0, width: total ? (Number(f.interviewing) / total) * 100 : 0 },
    { label: '已淘汰', value: Number(f.rejected) || 0, width: total ? (Number(f.rejected) / total) * 100 : 0 },
    { label: '待发放/已发 Offer', value: Number(f.offered) || 0, width: total ? (Number(f.offered) / total) * 100 : 0 }
  ]
  candidates.value = (d.candidates || []).map(c => ({ ...c, match: Math.round(Number(c.matchScore) || 0), tone: statusTone[c.statusCode] || 'gray', stage: c.currentStage || c.statusLabel || '待定' }))
  stages.value = (d.stages || []).map(s => ({ name: s.name, type: stageTypeMap[s.type] || '综合面' }))
}

onMounted(load)
</script>

<template>
  <div class="page detail-page">
    <button class="back" @click="router.back()"><ArrowLeft :size="15"/>返回岗位列表</button>
    <section class="card job-header">
      <div><h1>{{ job.title || '加载中…' }} <span class="pill" :class="job.status === 1 ? 'green' : job.status === 2 ? 'gray' : 'red'"><i class="dot"/>{{ job.status === 1 ? '招聘中' : job.status === 2 ? '已暂停' : '已下线' }}</span></h1><p>岗位编号 JOB-{{ String(job.posId || 0).padStart(4, '0') }} · {{ job.dept || '—' }} · {{ job.city || '—' }} · {{ salary }} · {{ educationMap[job.education] || '不限' }} · {{ job.experience || '经验不限' }}</p></div>
      <div><button class="btn" @click="notify('编辑岗位功能开发中')"><Pencil :size="15"/>编辑岗位</button><button class="btn" @click="notify('复制岗位功能开发中')"><Copy :size="15"/>复制岗位</button><button class="btn" @click="router.push({ path: '/enterprise/screening', query: { taskId: posId } })"><Sparkles :size="15"/>AI 初筛</button><button class="btn danger-ghost" :disabled="job.status !== 1" @click="closeRecruit"><PauseCircle :size="15"/>关闭招聘</button></div>
    </section>

    <div class="detail-grid">
      <div class="left-col">
        <section class="card funnel-card">
          <div class="section-title"><span>招聘漏斗</span><small><i class="live-dot"/>实时更新</small></div>
          <div class="funnel-list"><div v-for="(item,index) in funnel" :key="item.label"><label>{{ item.label }}</label><span class="rail"><i :style="{ width:`${Math.max(item.width,4)}%`, opacity: 1-index*.11 }"/></span><b>{{ item.value }}</b></div></div>
          <p v-if="funnel.length && funnel[0].value">漏斗参考：初筛通过率 {{ Math.round(funnel[1].value / funnel[0].value * 1000) / 10 }}% · 面试转化 {{ Math.round(funnel[2].value / funnel[0].value * 1000) / 10 }}% · Offer 转化 {{ Math.round(funnel[4].value / funnel[0].value * 1000) / 10 }}%</p>
        </section>
        <section class="card candidates-card">
          <div class="section-title"><span>候选人列表 <em>{{ candidates.length }}</em></span><button>全部阶段 <ChevronDown :size="14"/></button></div>
          <table><thead><tr><th></th><th>姓名</th><th>匹配度</th><th>当前阶段</th><th>操作</th></tr></thead><tbody><tr v-for="(person,i) in candidates" :key="person.instanceId"><td><button class="check" :class="{ on: selected.has(i) }" @click="toggle(i)"><Check v-if="selected.has(i)" :size="13"/></button></td><td><b>{{ person.name }}</b><small>{{ person.statusLabel }}</small></td><td><span class="score">{{ person.match }}%</span><i class="score-bar"><u :style="{ width:`${person.match}%` }"/></i></td><td><span class="pill" :class="person.tone">{{ person.stage }}</span></td><td><button @click="router.push(`/enterprise/candidates/${person.talId}/process`)"><FileText :size="13"/>流程详情</button><button @click="router.push({ path: '/enterprise/messages', query: { peerId: person.userId, peerName: person.name } })"><MessageCircle :size="13"/>发起对话</button></td></tr></tbody></table>
          <p v-if="!candidates.length" class="empty-tip">该岗位暂无候选人投递</p>
        </section>
      </div>
      <aside class="right-col">
        <section class="card portrait-card">
          <div class="section-title"><span><span class="title-icon"><Sparkles :size="17"/></span>岗位画像</span><small><b>JD</b> {{ job.date }}</small></div>
          <h4>硬性条件</h4><div class="tag-list"><span>{{ educationMap[job.education] || '学历不限' }}</span><span>{{ job.experience || '经验不限' }}</span><span>{{ job.city || '—' }}</span><span>{{ jobTypeMap[job.jobType] || '全职' }}</span></div>
          <h4>任职要求</h4><div class="tag-list blue"><span v-for="r in (jd.requirements || [])" :key="r">{{ r }}</span></div>
          <h4>职责关键词</h4><div class="tag-list purple"><span v-for="r in (jd.responsibilities || [])" :key="r">{{ r }}</span></div>
        </section>
        <section class="card process-card">
          <div class="section-title"><span>{{ job.templateName || '未配置招聘流程' }} <small v-if="job.templateVersion">{{ job.templateVersion }}</small></span><button @click="router.push(`/enterprise/jobs/${posId}/workflow`)"><Settings2 :size="14"/>编辑流程</button></div>
          <p class="process-caption">{{ stages.length }} 个阶段 · 已开始的候选人使用流程快照</p>
          <div v-for="(stage,index) in stages" :key="stage.name" class="process-step"><span><Check :size="15"/></span><div><b>{{ index + 1 }}. {{ stage.name }}</b><p>{{ stage.type }}</p></div></div>
        </section>
      </aside>
    </div>
    <div class="batch-bar"><div><span class="batch-icon"><Check :size="14"/></span>已选 <b>{{ checkedCount }}</b> 位候选人 <small>支持批量发送通知或安排面试</small></div><div><button class="btn" @click="notify('通知已加入发送队列')"><BellRing :size="15"/>批量发送通知</button><button class="btn primary" @click="router.push('/enterprise/interviews')"><CalendarPlus :size="15"/>批量安排面试</button></div></div>
    <ToastMessage :message="toast"/>
  </div>
</template>

<style scoped>
.detail-page{padding-bottom:86px}.back{border:0;background:transparent;color:#6f7f99;display:flex;align-items:center;gap:5px;font-size:11px;padding:0;margin-bottom:9px}.job-header{min-height:91px;padding:19px 20px;display:flex;align-items:center;justify-content:space-between;margin-bottom:15px}.job-header h1{font-size:24px;display:flex;align-items:center;gap:10px}.job-header p{font-size:11px;color:#71829c;margin-top:8px}.job-header>div:last-child{display:flex;gap:10px}.detail-grid{display:grid;grid-template-columns:minmax(650px,1.45fr) minmax(360px,.75fr);gap:15px}.left-col,.right-col{display:flex;flex-direction:column;gap:15px}.funnel-card{padding:18px 20px}.section-title small{font-size:10px;color:#93a2b7;font-weight:400}.live-dot{display:inline-block;width:7px;height:7px;border-radius:50%;background:#16b87a;margin-right:5px}.funnel-list{margin-top:13px}.funnel-list>div{display:grid;grid-template-columns:135px 1fr 42px;align-items:center;gap:10px;height:31px;font-size:11px}.rail{height:8px;border-radius:10px;background:#edf1f6;overflow:hidden}.rail i{display:block;height:100%;border-radius:inherit;background:linear-gradient(90deg,#84b8ff,#2563eb)}.funnel-list b{text-align:right}.funnel-card>p{font-size:9px;color:#9aa8ba;margin-top:7px}.candidates-card{padding:18px 20px}.section-title em{font-style:normal;color:#2563eb;background:#edf4ff;border-radius:10px;font-size:10px;padding:3px 7px;margin-left:5px}.section-title button{border:0;background:#f4f7fb;color:#64748b;border-radius:7px;height:30px;padding:0 10px;display:flex;align-items:center;gap:5px;font-size:11px}.candidates-card table{width:100%;border-collapse:collapse;margin-top:12px;table-layout:fixed}.candidates-card th{height:31px;color:#7f8ea4;background:#f6f8fb;font-size:10px;font-weight:500;text-align:left}.candidates-card th:first-child{width:35px}.candidates-card th:nth-child(2){width:30%}.candidates-card th:nth-child(3){width:22%}.candidates-card th:nth-child(4){width:24%}.candidates-card td{height:48px;border-bottom:1px solid #edf1f6;font-size:11px}.candidates-card td:nth-child(2) b,.candidates-card td:nth-child(2) small{display:block}.candidates-card td:nth-child(2) small{font-size:9px;color:#9aa7b9;margin-top:2px}.check{width:17px;height:17px;border:1px solid #cdd8e7;border-radius:4px;background:white;padding:0;display:grid;place-items:center;color:white}.check.on{background:#2563eb;border-color:#2563eb}.score{margin-right:6px}.score-bar{display:inline-block;width:38px;height:5px;background:#dce4ef;border-radius:5px;vertical-align:middle}.score-bar u{display:block;height:100%;background:#3477f5;border-radius:inherit}.candidates-card td:last-child button{border:0;background:none;color:#2563eb;font-size:10px;padding:3px 7px 3px 0;display:inline-flex;gap:3px;align-items:center}.empty-tip{font-size:11px;color:#9aa8ba;padding:14px 0}.portrait-card,.process-card{padding:18px}.title-icon{width:29px;height:29px;border-radius:8px;background:#eaf1ff;color:#2563eb;display:inline-grid;place-items:center;margin-right:7px;vertical-align:middle}.section-title small b{color:#fff;background:#2563eb;border-radius:10px;padding:3px 6px}.portrait-card h4{font-size:11px;margin:14px 0 7px}.tag-list{display:flex;gap:6px;flex-wrap:wrap}.tag-list span{font-size:10px;padding:5px 8px;border-radius:6px;background:#f2f5f9;color:#475b77}.tag-list.blue span{background:#edf4ff;color:#2563eb}.tag-list.purple span{background:#f0efff;color:#6758d4}.process-card .section-title button{color:#2563eb;background:transparent;padding:0}.process-step{display:flex;gap:10px;align-items:center;margin-top:15px}.process-step>span{width:30px;height:30px;border-radius:8px;display:grid;place-items:center;background:#eaf1ff;color:#2563eb}.process-step:last-child>span{background:#2563eb;color:#fff}.process-step b{font-size:12px}.process-step p{font-size:9px;color:#7f8da2;margin-top:3px}.batch-bar{position:fixed;z-index:10;left:244px;right:24px;bottom:18px;min-height:58px;border:1px solid #dfe6ef;border-radius:13px;background:rgba(255,255,255,.96);box-shadow:0 8px 24px rgba(15,23,42,.09);display:flex;align-items:center;justify-content:space-between;padding:0 18px;font-size:12px}.batch-bar>div{display:flex;align-items:center;gap:9px}.batch-bar small{color:#97a5b9}.batch-icon{width:26px;height:26px;border-radius:8px;background:#eaf1ff;color:#2563eb;display:grid;place-items:center}
.process-caption{font-size:9px;color:#93a2b7;margin-top:7px}.process-card .section-title button{display:flex;align-items:center;gap:4px}.process-step em{margin-left:auto;flex:none;font-style:normal}.process-step b{font-size:11px}
</style>
