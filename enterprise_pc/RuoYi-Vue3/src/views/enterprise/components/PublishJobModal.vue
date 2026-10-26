<script setup>
import { onMounted, ref } from 'vue'
import { Sparkles, Plus, X } from '@/views/enterprise/components/icons'
import BaseModal from './BaseModal.vue'
import { createJob, updateJob, jobDepartments, parseJdText } from '@/api/system/job'

const props = defineProps({
  edit: { type: Boolean, default: false },
  job: { type: Object, default: null }
})
const emit = defineEmits(['close', 'submitted'])
const loading = ref(false)
const parsing = ref(false)
const form = ref({
  title: '', dept: '', city: '杭州', salaryMin: '', salaryMax: '',
  jobType: 1, education: 3, experience: '3-5年',
  description: '', requirements: '', responsibilities: ''
})
const skills = ref([])
const skillInput = ref('')
const departments = ref([])

// 薪资展示单位为 K，数据库存储单位为元/月
function yuanToK(value) {
  const number = Number(value)
  return Number.isFinite(number) && number > 0 ? Math.round(number / 100) / 10 : ''
}
function kToYuan(value) {
  const number = Number(value)
  return Number.isFinite(number) && number > 0 ? Math.round(number * 1000) : null
}

if (props.edit && props.job) {
  const job = props.job
  form.value = {
    title: job.title || '',
    dept: job.dept || '',
    city: job.city || '',
    salaryMin: yuanToK(job.salaryMin),
    salaryMax: yuanToK(job.salaryMax),
    jobType: job.jobType ?? 1,
    education: job.education ?? 3,
    experience: job.experience || '3-5年',
    description: job.description || '',
    requirements: (job.requirements || []).join('\n'),
    responsibilities: (job.responsibilities || []).join('\n')
  }
  skills.value = (job.skills || []).slice()
}

function addSkill() { const v = skillInput.value.trim(); if (v && !skills.value.includes(v)) skills.value.push(v); skillInput.value = '' }

async function submit(status) {
  if (!form.value.title.trim()) { alert('请填写岗位名称'); return }
  loading.value = true
  try {
    const payload = {
      ...form.value,
      salaryMin: kToYuan(form.value.salaryMin),
      salaryMax: kToYuan(form.value.salaryMax),
      status,
      requirements: skills.value.length ? skills.value : (form.value.requirements ? form.value.requirements.split(/[\n;；]/).map(s => s.trim()).filter(Boolean) : []),
      responsibilities: form.value.responsibilities ? form.value.responsibilities.split(/[\n;；]/).map(s => s.trim()).filter(Boolean) : []
    }
    if (props.edit && props.job?.posId) {
      await updateJob(props.job.posId, payload)
      emit('submitted', -1)
    } else {
      await createJob(payload)
      emit('submitted', status)
    }
  } finally {
    loading.value = false
  }
}

// AI 解析 JD：仅解析文本回填表单，不写库
const EXPERIENCE_RULES = [
  { min: 10, label: '10年以上' },
  { min: 5, label: '5-10年' },
  { min: 3, label: '3-5年' },
  { min: 1, label: '1-3年' },
  { min: 0, label: '应届/1年' }
]
const EDUCATION_MAP = { 博士: 5, 硕士: 4, 研究生: 4, 本科: 3, 学士: 3, 大专: 2, 专科: 2, 不限: 1 }

async function parseJd() {
  if (parsing.value) return
  const text = [form.value.description, form.value.responsibilities].filter(Boolean).join('\n').trim()
  if (!text) { alert('请先在岗位描述或工作职责中粘贴 JD 内容'); return }
  parsing.value = true
  try {
    const res = await parseJdText(text)
    const profile = res.data || {}
    const matched = (profile.skills || []).filter(s => s && !skills.value.includes(s))
    if (matched.length) skills.value = [...skills.value, ...matched]
    const years = String(profile.years || '')
    const number = years.match(/\d+/)
    if (number) {
      const rule = EXPERIENCE_RULES.find(r => Number(number[0]) >= r.min)
      if (rule) form.value.experience = rule.label
    }
    const eduKey = Object.keys(EDUCATION_MAP).find(k => String(profile.education || '').includes(k))
    if (eduKey) form.value.education = EDUCATION_MAP[eduKey]
    if (!matched.length && !number && !eduKey) {
      alert('未从 JD 中识别到学历、年限或技能标签，请补充更完整的岗位要求')
    }
  } catch (e) {
    // 请求拦截器已统一提示
  } finally {
    parsing.value = false
  }
}

onMounted(async () => {
  const res = await jobDepartments()
  departments.value = res.data || []
})
</script>

<template>
  <BaseModal :title="edit ? '编辑岗位' : '发布新岗位'" width="720px" @close="$emit('close')">
    <div class="form-grid">
      <div class="field"><label>岗位名称 <i>*</i></label><input class="input" v-model="form.title" placeholder="如：高级前端工程师" /></div>
      <div class="field"><label>所属部门</label><input class="input" v-model="form.dept" list="dept-options" placeholder="选择或输入部门" /><datalist id="dept-options"><option v-for="d in departments" :key="d" :value="d"/></datalist></div>
      <div class="field"><label>最低薪资(K)</label><input class="input" type="number" v-model="form.salaryMin" placeholder="如 25" /></div>
      <div class="field"><label>最高薪资(K)</label><input class="input" type="number" v-model="form.salaryMax" placeholder="如 35" /></div>
      <div class="field"><label>岗位类型</label><select class="select" v-model.number="form.jobType"><option :value="1">全职</option><option :value="2">实习</option><option :value="3">兼职</option></select></div>
      <div class="field"><label>工作地点</label><input class="input" v-model="form.city" placeholder="如 杭州" /></div>
      <div class="field"><label>学历要求</label><select class="select" v-model.number="form.education"><option :value="1">不限</option><option :value="2">大专及以上</option><option :value="3">本科及以上</option><option :value="4">硕士及以上</option><option :value="5">博士</option></select></div>
      <div class="field"><label>工作年限</label><select class="select" v-model="form.experience"><option>应届/1年</option><option>1-3年</option><option>3-5年</option><option>5-10年</option><option>10年以上</option></select></div>
      <div class="field full"><label>技能标签</label><div class="skill-input"><span v-for="s in skills" :key="s">{{ s }}<button @click="skills = skills.filter(x => x !== s)"><X :size="12"/></button></span><input v-model="skillInput" @keyup.enter="addSkill" placeholder="输入技能后按 Enter"/><button class="add" @click="addSkill"><Plus :size="15"/></button></div></div>
      <div class="field full"><label>岗位描述</label><textarea class="textarea" v-model="form.description" placeholder="岗位职责概述" /></div>
      <div class="field full"><label>任职要求</label><textarea class="textarea" v-model="form.requirements" placeholder="每行一条，或用分号分隔" /></div>
      <div class="field full"><label>工作职责</label><textarea class="textarea" v-model="form.responsibilities" placeholder="每行一条，或用分号分隔" /></div>
    </div>
    <template #footer><button class="btn ghost-primary" :disabled="parsing" @click="parseJd"><Sparkles :size="16"/>{{ parsing ? '解析中…' : 'AI 智能解析 JD' }}</button><span class="spacer"/><template v-if="edit"><button class="btn primary" :disabled="loading" @click="submit(1)">{{ loading ? '保存中…' : '保存修改' }}</button></template><template v-else><button class="btn" :disabled="loading" @click="submit(0)">保存草稿</button><button class="btn primary" :disabled="loading" @click="submit(1)">{{ loading ? '提交中…' : '发布岗位' }}</button></template></template>
  </BaseModal>
</template>

<style scoped>
.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:17px 16px}.full{grid-column:1/-1}.field label i{color:#ef4444;font-style:normal}.skill-input{min-height:42px;padding:5px 7px;border:1px solid #dce4ee;border-radius:9px;display:flex;align-items:center;gap:6px;flex-wrap:wrap}.skill-input span{display:flex;align-items:center;gap:4px;padding:4px 7px;border-radius:6px;background:#eaf1ff;color:#2563eb;font-size:11px}.skill-input span button{border:0;background:none;color:inherit;padding:0;display:grid}.skill-input input{min-width:150px;flex:1;border:0;outline:0;font-size:12px;padding:5px}.skill-input .add{width:26px;height:26px;display:grid;place-items:center;border:0;border-radius:6px;background:#edf4ff;color:var(--primary)}.textarea{min-height:72px}.spacer{flex:1}
</style>
