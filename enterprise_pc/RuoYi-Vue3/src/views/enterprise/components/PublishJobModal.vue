<script setup>
import { onMounted, ref } from 'vue'
import { Sparkles, Plus, X } from '@/views/enterprise/components/icons'
import BaseModal from './BaseModal.vue'
import { createJob, jobDepartments } from '@/api/system/job'

const emit = defineEmits(['close', 'submitted'])
const loading = ref(false)
const form = ref({
  title: '', dept: '', city: '杭州', salaryMin: '', salaryMax: '',
  jobType: 1, education: 3, experience: '3-5年',
  description: '', requirements: '', responsibilities: ''
})
const skills = ref([])
const skillInput = ref('')
const departments = ref([])

function addSkill() { const v = skillInput.value.trim(); if (v && !skills.value.includes(v)) skills.value.push(v); skillInput.value = '' }

async function submit(status) {
  if (!form.value.title.trim()) { alert('请填写岗位名称'); return }
  loading.value = true
  try {
    const payload = {
      ...form.value,
      status,
      requirements: skills.value.length ? skills.value : (form.value.requirements ? form.value.requirements.split(/[\n;；]/).map(s => s.trim()).filter(Boolean) : []),
      responsibilities: form.value.responsibilities ? form.value.responsibilities.split(/[\n;；]/).map(s => s.trim()).filter(Boolean) : []
    }
    await createJob(payload)
    emit('submitted', status)
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  const res = await jobDepartments()
  departments.value = res.data || []
})
</script>

<template>
  <BaseModal title="发布新岗位" width="720px" @close="$emit('close')">
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
    <template #footer><button class="btn ghost-primary" disabled><Sparkles :size="16"/>AI 智能解析 JD</button><span class="spacer"/><button class="btn" :disabled="loading" @click="submit(0)">保存草稿</button><button class="btn primary" :disabled="loading" @click="submit(1)">{{ loading ? '提交中…' : '发布岗位' }}</button></template>
  </BaseModal>
</template>

<style scoped>
.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:17px 16px}.full{grid-column:1/-1}.field label i{color:#ef4444;font-style:normal}.skill-input{min-height:42px;padding:5px 7px;border:1px solid #dce4ee;border-radius:9px;display:flex;align-items:center;gap:6px;flex-wrap:wrap}.skill-input span{display:flex;align-items:center;gap:4px;padding:4px 7px;border-radius:6px;background:#eaf1ff;color:#2563eb;font-size:11px}.skill-input span button{border:0;background:none;color:inherit;padding:0;display:grid}.skill-input input{min-width:150px;flex:1;border:0;outline:0;font-size:12px;padding:5px}.skill-input .add{width:26px;height:26px;display:grid;place-items:center;border:0;border-radius:6px;background:#edf4ff;color:var(--primary)}.textarea{min-height:72px}.spacer{flex:1}
</style>
