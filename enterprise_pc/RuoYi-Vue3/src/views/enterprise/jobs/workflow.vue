<script setup>
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, Plus, GripVertical, Trash2, ChevronUp, ChevronDown, Save, GitBranch, ShieldCheck, Clock3, UsersRound, FileCheck2, Copy } from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { api, reserveApi } from '@/views/enterprise/api/contract'

const route = useRoute()
const router = useRouter()
const toast = ref('')
const selectedStage = ref(0)
const stages = ref([
  { id: 'stage-screen', name: 'HR 初筛沟通', type: 'HR 主导', target: '确认动机、薪资预期与基本条件', duration: 30, required: true, interviewer: '周琳', status: 'completed', mode: 'hr', skip: false, terminate: false, threshold: 70 },
  { id: 'stage-ai', name: 'AI 结构化预面', type: '纯 AI', target: '验证技术基础与项目经历', duration: 45, required: true, interviewer: 'AI 面试官', status: 'active', mode: 'ai', skip: true, terminate: true, threshold: 75 },
  { id: 'stage-tech', name: '专业技术面', type: 'AI + HR 协同', target: '深挖架构设计、故障排查和交付能力', duration: 60, required: true, interviewer: '陈志远', status: 'upcoming', mode: 'ai_hr', skip: true, terminate: true, threshold: 80 },
  { id: 'stage-case', name: '项目案例深挖', type: 'HR 主导', target: '核实关键项目中的个人贡献与复盘能力', duration: 45, required: false, interviewer: '待指定', status: 'upcoming', mode: 'hr', skip: true, terminate: false, threshold: 70 },
  { id: 'stage-offer', name: 'HR 终审与薪酬沟通', type: 'HR 主导', target: '确认录用建议、薪酬和入职时间', duration: 30, required: true, interviewer: '林晓雯', status: 'upcoming', mode: 'hr', skip: false, terminate: true, threshold: 70 }
])

const current = computed(() => stages.value[selectedStage.value])
const startedCount = computed(() => stages.value.filter(item => item.status !== 'upcoming').length)

function notify(message) { toast.value = message; setTimeout(() => { toast.value = '' }, 2200) }
function move(index, direction) {
  const target = index + direction
  if (target < 0 || target >= stages.value.length) return
  const copy = stages.value.slice(); [copy[index], copy[target]] = [copy[target], copy[index]]
  stages.value = copy; selectedStage.value = target
  notify('阶段顺序已调整，保存后生成新流程版本')
}
function addStage() {
  stages.value.push({ id: `stage-${Date.now()}`, name: '新建面试阶段', type: 'AI + HR 协同', target: '填写该阶段的重点考察项', duration: 45, required: false, interviewer: '待指定', status: 'upcoming', mode: 'ai_hr', skip: true, terminate: false, threshold: 70 })
  selectedStage.value = stages.value.length - 1
}
function removeStage(index) {
  if (stages.value[index].status !== 'upcoming') return notify('已开始或已完成的阶段不能删除')
  stages.value.splice(index, 1); selectedStage.value = Math.max(0, selectedStage.value - (selectedStage.value >= index ? 1 : 0)); notify('未开始阶段已删除')
}
function save() {
  reserveApi(api.positions.saveWorkflow, { positionId: route.params.id, mode: 'stages', stages: stages.value, transitions: { onPass: 'next', onHold: 'manual', onFail: 'terminate' }, notificationTemplateIds: [] })
  notify('流程草稿已保存，新候选人将使用新版本')
}
function publish() {
  save(); notify('流程版本已发布，已开始的候选人继续使用原流程快照')
}
</script>

<template>
  <div class="page workflow-page">
    <div class="page-heading"><div><button class="back" @click="router.back()"><ArrowLeft :size="15"/>返回岗位详情</button><h1>招聘流程配置</h1><p>高级前端工程师 · 流程版本 v3 · 已开始的候选人不会被新版本覆盖</p></div><div class="heading-actions"><button class="btn" @click="notify('已复制当前流程为新草稿')"><Copy :size="15"/>复制流程</button><button class="btn primary" @click="publish"><Save :size="15"/>发布新版本</button></div></div>
    <div class="workflow-grid">
      <section class="card stage-card">
        <header><div><h2>阶段时间线</h2><p>{{ stages.length }} 个阶段 · {{ startedCount }} 个阶段已开始</p></div><button class="btn primary sm" @click="addStage"><Plus :size="14"/>新增阶段</button></header>
        <div class="stage-list"><article v-for="(stage, index) in stages" :key="stage.id" :class="['stage-row', { selected: selectedStage === index, locked: stage.status !== 'upcoming' }]" @click="selectedStage = index"><span class="drag"><GripVertical :size="16"/></span><span class="stage-index">{{ index + 1 }}</span><div class="stage-main"><div><b>{{ stage.name }}</b><span class="pill" :class="stage.status === 'completed' ? 'green' : stage.status === 'active' ? '' : 'gray'">{{ stage.status === 'completed' ? '已完成' : stage.status === 'active' ? '进行中' : '未开始' }}</span></div><small>{{ stage.type }} · {{ stage.duration }} 分钟 · {{ stage.interviewer }}</small></div><div class="row-actions"><button title="上移" @click.stop="move(index, -1)"><ChevronUp :size="14"/></button><button title="下移" @click.stop="move(index, 1)"><ChevronDown :size="14"/></button><button class="delete" title="删除未开始阶段" @click.stop="removeStage(index)"><Trash2 :size="14"/></button></div></article></div>
        <div class="flow-note"><GitBranch :size="15"/><span>通过：进入下一阶段 · 暂缓：生成 HR 待办 · 未通过：按阶段规则终止或归档</span></div>
      </section>
      <section class="card editor-card" v-if="current">
        <header><div><span class="eyebrow">阶段 {{ selectedStage + 1 }}</span><h2>{{ current.name }}</h2><p>配置会写入流程版本，不会修改历史阶段实例</p></div><span class="locked-note" v-if="current.status !== 'upcoming'"><ShieldCheck :size="14"/>已锁定历史</span></header>
        <div class="form-grid"><div class="field full"><label>阶段名称</label><input class="input" v-model="current.name" :disabled="current.status !== 'upcoming'"/></div><div class="field"><label>阶段类型</label><select class="select" v-model="current.type"><option>纯 AI</option><option>AI + HR 协同</option><option>HR 主导</option><option>在线测评</option></select></div><div class="field"><label>阶段时长（分钟）</label><input class="input" type="number" v-model.number="current.duration"/></div><div class="field full"><label>阶段目标 / 重点考察项</label><textarea class="textarea" v-model="current.target"/><small class="help-text">候选人进入下一阶段时会携带本阶段未覆盖或需复核的重点。</small></div><div class="field"><label>面试官 / 执行人</label><select class="select" v-model="current.interviewer"><option>待指定</option><option>林晓雯</option><option>周琳</option><option>陈志远</option><option>AI 面试官</option></select></div><div class="field"><label>通过阈值</label><input class="input" type="number" min="0" max="100" v-model.number="current.threshold"/></div></div>
        <div class="rule-section"><h3>流转规则</h3><div class="rule-grid"><label><input type="checkbox" v-model="current.required"/>必选阶段</label><label><input type="checkbox" v-model="current.skip"/>允许跳过</label><label><input type="checkbox" v-model="current.terminate"/>未通过可终止流程</label></div><div class="branch-row"><span><Clock3 :size="15"/>暂缓</span><b>生成 HR 待办，不自动进入下一阶段</b><span><UsersRound :size="15"/>补面</span><b>允许重新预约当前阶段</b></div></div>
        <div class="scorecard"><FileCheck2 :size="17"/><div><b>评分卡</b><p>技术理论 · 动手实践 · 逻辑思维 · 沟通表达 · 文化匹配</p></div><button class="btn sm" @click="notify('评分卡配置入口已预留')">配置评分卡</button></div>
        <div class="save-row"><button class="btn" @click="router.back()">取消</button><button class="btn primary" @click="save"><Save :size="15"/>保存流程草稿</button></div>
      </section>
    </div><ToastMessage :message="toast"/>
  </div>
</template>

<style scoped>
.workflow-page{padding-bottom:25px}.back{border:0;background:transparent;color:#6f7f99;display:flex;align-items:center;gap:5px;font-size:11px;padding:0;margin-bottom:7px}.page-heading{align-items:flex-start}.page-heading h1{margin-top:2px}.page-heading>div:last-child{display:flex;gap:9px}.workflow-grid{display:grid;grid-template-columns:minmax(390px,.82fr) minmax(590px,1.18fr);gap:15px;align-items:start}.stage-card,.editor-card{padding:19px}.stage-card>header,.editor-card>header{display:flex;justify-content:space-between;align-items:flex-start}.stage-card h2,.editor-card h2{font-size:18px}.stage-card header p,.editor-card header p{font-size:10px;color:#94a2b5;margin-top:4px}.stage-list{margin-top:17px;position:relative}.stage-list:before{content:'';position:absolute;left:42px;top:23px;bottom:23px;border-left:1px dashed #c7d5e9}.stage-row{min-height:72px;display:grid;grid-template-columns:19px 28px 1fr auto;gap:8px;align-items:center;padding:9px 7px;border:1px solid transparent;border-radius:11px;position:relative;cursor:pointer}.stage-row:hover,.stage-row.selected{background:#f5f8ff;border-color:#cfe0ff}.stage-row.locked{opacity:.78}.drag{color:#b0bdce}.stage-index{width:27px;height:27px;border-radius:50%;display:grid;place-items:center;background:#eaf1ff;color:#2563eb;font-weight:700;font-size:11px;z-index:1}.stage-row.selected .stage-index{background:#2563eb;color:#fff}.stage-main{min-width:0}.stage-main>div{display:flex;align-items:center;gap:7px}.stage-main b{font-size:12px}.stage-main small{display:block;color:#7f8ea4;font-size:9px;margin-top:5px}.row-actions{display:flex;gap:2px}.row-actions button{border:0;background:transparent;color:#7b8ca5;width:25px;height:25px;display:grid;place-items:center;border-radius:6px}.row-actions button:hover{background:#eaf1ff;color:#2563eb}.row-actions .delete:hover{background:#fff0f0;color:#ef4444}.flow-note{display:flex;gap:7px;align-items:center;margin-top:13px;padding:10px;background:#edf4ff;color:#48658e;border-radius:9px;font-size:9px}.flow-note svg{color:#2563eb;flex:none}.eyebrow{font-size:10px;color:#2563eb;font-weight:700}.editor-card header{padding-bottom:15px;border-bottom:1px solid #e7edf5}.editor-card h2{margin-top:4px}.locked-note{display:flex;gap:5px;align-items:center;padding:5px 8px;border-radius:7px;background:#f1f4f8;color:#7d8da3;font-size:9px}.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:15px;margin-top:17px}.full{grid-column:1/-1}.field label{display:block;font-size:10px;color:#63748d;margin-bottom:6px}.field .input,.field .select{height:37px}.textarea{min-height:78px;resize:vertical}.help-text{display:block;font-size:9px;color:#95a3b6;margin-top:5px}.rule-section{margin-top:20px;padding-top:15px;border-top:1px solid #e7edf5}.rule-section h3{font-size:12px}.rule-grid{display:flex;gap:18px;margin-top:11px}.rule-grid label{font-size:10px;color:#536680}.rule-grid input{accent-color:#2563eb;margin-right:6px}.branch-row{display:grid;grid-template-columns:auto 1fr auto 1fr;gap:7px;align-items:center;margin-top:13px;padding:10px;background:#f7f9fc;border-radius:9px;font-size:9px;color:#718198}.branch-row span{display:flex;align-items:center;gap:4px;color:#2563eb}.branch-row b{font-weight:500}.scorecard{display:flex;align-items:center;gap:10px;margin-top:17px;padding:11px;border:1px solid #dce7f6;border-radius:9px;background:#f8fbff;color:#2563eb}.scorecard>div{flex:1}.scorecard b{display:block;color:#344b6e;font-size:11px}.scorecard p{color:#8998ac;font-size:9px;margin-top:3px}.save-row{display:flex;justify-content:flex-end;gap:8px;margin-top:19px}
</style>



