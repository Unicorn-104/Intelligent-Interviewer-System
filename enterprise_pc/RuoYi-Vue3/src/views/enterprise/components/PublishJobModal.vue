<script setup>
import { ref } from 'vue'
import { Sparkles, Plus, X } from '@/views/enterprise/components/icons'
import BaseModal from './BaseModal.vue'
import { api, reserveApi } from '@/views/enterprise/api/contract'

defineEmits(['close', 'submit'])
const skills = ref(['Vue 3', 'TypeScript'])
const skillInput = ref('')
function addSkill() { const v = skillInput.value.trim(); if (v && !skills.value.includes(v)) skills.value.push(v); skillInput.value = '' }
function parseJd() { reserveApi(api.positions.parseJd, { jdText: '岗位职责与任职要求文本' }) }
</script>

<template>
  <BaseModal title="发布新岗位" width="720px" @close="$emit('close')">
    <div class="form-grid">
      <div class="field"><label>岗位名称</label><input class="input" value="高级前端工程师" /></div>
      <div class="field"><label>所属部门</label><select class="select"><option>产品研发部</option><option>设计中心</option><option>人力资源部</option></select></div>
      <div class="field"><label>招聘人数</label><input class="input" type="number" value="2" /></div>
      <div class="field"><label>薪资范围</label><input class="input" value="25-35K · 14薪" /></div>
      <div class="field"><label>岗位类型</label><select class="select"><option>全职</option><option>实习</option><option>兼职</option></select></div>
      <div class="field"><label>工作地点</label><input class="input" value="杭州" /></div>
      <div class="field"><label>学历要求</label><select class="select"><option>本科及以上</option><option>大专及以上</option></select></div>
      <div class="field"><label>工作年限</label><select class="select"><option>3-5年</option><option>5-10年</option></select></div>
      <div class="field full"><label>技能标签</label><div class="skill-input"><span v-for="s in skills" :key="s">{{ s }}<button @click="skills = skills.filter(x => x !== s)"><X :size="12"/></button></span><input v-model="skillInput" @keyup.enter="addSkill" placeholder="输入技能后按 Enter"/><button class="add" @click="addSkill"><Plus :size="15"/></button></div></div>
      <div class="field full"><label>岗位描述</label><textarea class="textarea" value="负责公司核心业务前端架构设计与开发，建设高质量、可复用的前端能力。" /></div>
      <div class="field full"><label>任职要求</label><textarea class="textarea" value="熟练掌握 Vue 3、TypeScript，具备复杂 B 端项目经验和良好的工程化思维。" /></div>
    </div>
    <template #footer><button class="btn ghost-primary" @click="parseJd"><Sparkles :size="16"/>AI 智能解析 JD</button><span class="spacer"/><button class="btn" @click="$emit('close')">保存草稿</button><button class="btn primary" @click="$emit('submit')">发布岗位</button></template>
  </BaseModal>
</template>

<style scoped>
.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:17px 16px}.full{grid-column:1/-1}.skill-input{min-height:42px;padding:5px 7px;border:1px solid #dce4ee;border-radius:9px;display:flex;align-items:center;gap:6px;flex-wrap:wrap}.skill-input span{display:flex;align-items:center;gap:4px;padding:4px 7px;border-radius:6px;background:#eaf1ff;color:#2563eb;font-size:11px}.skill-input span button{border:0;background:none;color:inherit;padding:0;display:grid}.skill-input input{min-width:150px;flex:1;border:0;outline:0;font-size:12px;padding:5px}.skill-input .add{width:26px;height:26px;display:grid;place-items:center;border:0;border-radius:6px;background:#edf4ff;color:var(--primary)}.textarea{min-height:72px}.spacer{flex:1}
</style>



