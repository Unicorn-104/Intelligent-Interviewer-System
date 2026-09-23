<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowLeft, Pencil, PauseCircle, Sparkles, FileText, MessageCircle, BellRing, CalendarPlus, Check, ChevronDown, Settings2, Copy } from '@/views/enterprise/components/icons'
import { candidates } from '@/views/enterprise/data/mock'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { api, reserveApi } from '@/views/enterprise/api/contract'

const router = useRouter()
const selected = ref(new Set([0,1,2]))
const toast = ref('')
const checkedCount = computed(() => selected.value.size)
const funnel = [
  { label: '简历总量', value: 486, width: 100 }, { label: '初筛通过待面试', value: 152, width: 31 }, { label: '面试通过', value: 86, width: 18 }, { label: '已淘汰', value: 214, width: 44 }, { label: '待发放 Offer', value: 12, width: 5 }
]
const stages = [
  { name: 'HR 初筛沟通', type: 'HR 主导', status: '已完成', tone: 'green', target: '确认动机与基本条件' },
  { name: 'AI 结构化预面', type: '纯 AI', status: '进行中', tone: 'purple', target: '验证技术基础与项目经历' },
  { name: '专业技术面', type: 'AI + HR 协同', status: '未开始', tone: 'gray', target: '深挖架构设计与故障排查' },
  { name: '项目案例深挖', type: 'HR 主导', status: '未开始', tone: 'gray', target: '核实个人贡献和复盘能力' },
  { name: 'HR 终审与薪酬沟通', type: 'HR 主导', status: '未开始', tone: 'gray', target: '确认录用建议与入职时间' }
]
function toggle(i) { const s = new Set(selected.value); s.has(i) ? s.delete(i) : s.add(i); selected.value = s }
function notify(v) { toast.value = v; setTimeout(() => toast.value = '', 2000) }
function duplicateJob() { reserveApi(api.positions.duplicate, { positionId: 1, title: '高级前端工程师（副本）' }); notify('复制岗位接口已预留') }
</script>

<template>
  <div class="page detail-page">
    <button class="back" @click="router.back()"><ArrowLeft :size="15"/>返回岗位列表</button>
    <section class="card job-header">
      <div><h1>高级前端工程师 <span class="pill green"><i class="dot"/>招聘中</span></h1><p>岗位编号 JOB-2025-018 · 产品研发部 · 杭州 · 25-35K · 14薪 · 本科及以上 · 3-5 年</p></div>
      <div><button class="btn"><Pencil :size="15"/>编辑岗位</button><button class="btn" @click="duplicateJob"><Copy :size="15"/>复制岗位</button><button class="btn danger-ghost"><PauseCircle :size="15"/>关闭招聘</button></div>
    </section>

    <div class="detail-grid">
      <div class="left-col">
        <section class="card funnel-card">
          <div class="section-title"><span>招聘漏斗</span><small><i class="live-dot"/>实时更新</small></div>
          <div class="funnel-list"><div v-for="(item,index) in funnel" :key="item.label"><label>{{ item.label }}</label><span class="rail"><i :style="{ width:`${Math.max(item.width,4)}%`, opacity: 1-index*.11 }"/></span><b>{{ item.value }}</b></div></div>
          <p>漏斗参考：初筛通过率 31.3% · 面试通过率 17.7% · Offer 发放率 2.5%</p>
        </section>
        <section class="card candidates-card">
          <div class="section-title"><span>候选人列表 <em>12</em></span><button>全部阶段 <ChevronDown :size="14"/></button></div>
          <table><thead><tr><th></th><th>姓名</th><th>匹配度</th><th>当前阶段</th><th>操作</th></tr></thead><tbody><tr v-for="(person,i) in candidates" :key="person.name"><td><button class="check" :class="{ on: selected.has(i) }" @click="toggle(i)"><Check v-if="selected.has(i)" :size="13"/></button></td><td><b>{{ person.name }}</b><small>{{ person.role }}</small></td><td><span class="score">{{ person.match }}%</span><i class="score-bar"><u :style="{ width:`${person.match}%` }"/></i></td><td><span class="pill" :class="person.tone">{{ person.stage }}</span></td><td><button @click="router.push(`/enterprise/candidates/${8000+i}/process`)"><FileText :size="13"/>流程详情</button><button @click="router.push('/enterprise/messages')"><MessageCircle :size="13"/>发起对话</button></td></tr></tbody></table>
        </section>
      </div>
      <aside class="right-col">
        <section class="card portrait-card">
          <div class="section-title"><span><span class="title-icon"><Sparkles :size="17"/></span>岗位画像</span><small><b>AI</b> 06-18 更新</small></div>
          <h4>硬性条件</h4><div class="tag-list"><span>本科及以上</span><span>3-5 年经验</span><span>杭州 · 现场</span><span>全职</span></div>
          <h4>技能要求</h4><div class="tag-list blue"><span>Vue 3</span><span>TypeScript</span><span>微前端</span><span>Webpack</span><span>Node.js</span><span>性能优化</span><span>组件库建设</span></div>
          <h4>职责关键词</h4><div class="tag-list purple"><span>前端架构设计</span><span>性能优化</span><span>组件库</span><span>工程化</span><span>技术方案评审</span><span>跨团队协作</span></div>
        </section>
        <section class="card process-card">
          <div class="section-title"><span>招聘流程版本 v3</span><button @click="router.push('/enterprise/jobs/1/workflow')"><Settings2 :size="14"/>编辑流程</button></div>
          <p class="process-caption">{{ stages.length }} 个阶段 · 已开始的候选人使用流程快照</p>
          <div v-for="(stage,index) in stages" :key="stage.name" class="process-step"><span :class="stage.tone"><Check v-if="stage.status==='已完成'" :size="15"/><Sparkles v-else-if="stage.type==='纯 AI'" :size="15"/><MessageCircle v-else :size="15"/></span><div><b>{{ index + 1 }}. {{ stage.name }}</b><p>{{ stage.type }} · {{ stage.target }}</p></div><em class="pill" :class="stage.tone">{{ stage.status }}</em></div>
        </section>
      </aside>
    </div>
    <div class="batch-bar"><div><span class="batch-icon"><Check :size="14"/></span>已选 <b>{{ checkedCount }}</b> 位候选人 <small>支持批量发送通知或安排面试</small></div><div><button class="btn" @click="notify('通知已加入发送队列')"><BellRing :size="15"/>批量发送通知</button><button class="btn primary" @click="router.push('/enterprise/interviews')"><CalendarPlus :size="15"/>批量安排面试</button></div></div>
    <ToastMessage :message="toast"/>
  </div>
</template>

<style scoped>
.detail-page{padding-bottom:86px}.back{border:0;background:transparent;color:#6f7f99;display:flex;align-items:center;gap:5px;font-size:11px;padding:0;margin-bottom:9px}.job-header{min-height:91px;padding:19px 20px;display:flex;align-items:center;justify-content:space-between;margin-bottom:15px}.job-header h1{font-size:24px;display:flex;align-items:center;gap:10px}.job-header p{font-size:11px;color:#71829c;margin-top:8px}.job-header>div:last-child{display:flex;gap:10px}.detail-grid{display:grid;grid-template-columns:minmax(650px,1.45fr) minmax(360px,.75fr);gap:15px}.left-col,.right-col{display:flex;flex-direction:column;gap:15px}.funnel-card{padding:18px 20px}.section-title small{font-size:10px;color:#93a2b7;font-weight:400}.live-dot{display:inline-block;width:7px;height:7px;border-radius:50%;background:#16b87a;margin-right:5px}.funnel-list{margin-top:13px}.funnel-list>div{display:grid;grid-template-columns:135px 1fr 42px;align-items:center;gap:10px;height:31px;font-size:11px}.rail{height:8px;border-radius:10px;background:#edf1f6;overflow:hidden}.rail i{display:block;height:100%;border-radius:inherit;background:linear-gradient(90deg,#84b8ff,#2563eb)}.funnel-list b{text-align:right}.funnel-card>p{font-size:9px;color:#9aa8ba;margin-top:7px}.candidates-card{padding:18px 20px}.section-title em{font-style:normal;color:#2563eb;background:#edf4ff;border-radius:10px;font-size:10px;padding:3px 7px;margin-left:5px}.section-title button{border:0;background:#f4f7fb;color:#64748b;border-radius:7px;height:30px;padding:0 10px;display:flex;align-items:center;gap:5px;font-size:11px}.candidates-card table{width:100%;border-collapse:collapse;margin-top:12px;table-layout:fixed}.candidates-card th{height:31px;color:#7f8ea4;background:#f6f8fb;font-size:10px;font-weight:500;text-align:left}.candidates-card th:first-child{width:35px}.candidates-card th:nth-child(2){width:30%}.candidates-card th:nth-child(3){width:22%}.candidates-card th:nth-child(4){width:24%}.candidates-card td{height:48px;border-bottom:1px solid #edf1f6;font-size:11px}.candidates-card td:nth-child(2) b,.candidates-card td:nth-child(2) small{display:block}.candidates-card td:nth-child(2) small{font-size:9px;color:#9aa7b9;margin-top:2px}.check{width:17px;height:17px;border:1px solid #cdd8e7;border-radius:4px;background:white;padding:0;display:grid;place-items:center;color:white}.check.on{background:#2563eb;border-color:#2563eb}.score{margin-right:6px}.score-bar{display:inline-block;width:38px;height:5px;background:#dce4ef;border-radius:5px;vertical-align:middle}.score-bar u{display:block;height:100%;background:#3477f5;border-radius:inherit}.candidates-card td:last-child button{border:0;background:none;color:#2563eb;font-size:10px;padding:3px 7px 3px 0;display:inline-flex;gap:3px;align-items:center}.portrait-card,.process-card{padding:18px}.title-icon{width:29px;height:29px;border-radius:8px;background:#eaf1ff;color:#2563eb;display:inline-grid;place-items:center;margin-right:7px;vertical-align:middle}.section-title small b{color:#fff;background:#2563eb;border-radius:10px;padding:3px 6px}.portrait-card h4{font-size:11px;margin:14px 0 7px}.tag-list{display:flex;gap:6px;flex-wrap:wrap}.tag-list span{font-size:10px;padding:5px 8px;border-radius:6px;background:#f2f5f9;color:#475b77}.tag-list.blue span{background:#edf4ff;color:#2563eb}.tag-list.purple span{background:#f0efff;color:#6758d4}.process-card .section-title button{color:#2563eb;background:transparent;padding:0}.process-step{display:flex;gap:10px;align-items:center;margin-top:15px}.process-step>span{width:30px;height:30px;border-radius:8px;display:grid;place-items:center;background:#eaf1ff;color:#2563eb}.process-step:last-child>span{background:#2563eb;color:#fff}.process-step b{font-size:12px}.process-step p{font-size:9px;color:#7f8da2;margin-top:3px}.connector{height:19px;border-left:1px dashed #b9c9e3;margin-left:15px;display:block;position:relative}.connector small{position:absolute;left:7px;top:4px;white-space:nowrap;color:#9aa8ba;font-size:8px;font-style:normal}.batch-bar{position:fixed;z-index:10;left:244px;right:24px;bottom:18px;min-height:58px;border:1px solid #dfe6ef;border-radius:13px;background:rgba(255,255,255,.96);box-shadow:0 8px 24px rgba(15,23,42,.09);display:flex;align-items:center;justify-content:space-between;padding:0 18px;font-size:12px}.batch-bar>div{display:flex;align-items:center;gap:9px}.batch-bar small{color:#97a5b9}.batch-icon{width:26px;height:26px;border-radius:8px;background:#eaf1ff;color:#2563eb;display:grid;place-items:center}
.process-caption{font-size:9px;color:#93a2b7;margin-top:7px}.process-card .section-title button{display:flex;align-items:center;gap:4px}.process-step>span.green{background:#e4f8ef;color:#0b9c6c}.process-step>span.purple{background:#f0efff;color:#6758d4}.process-step em{margin-left:auto;flex:none;font-style:normal}.process-step b{font-size:11px}
</style>



