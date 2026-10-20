<script setup>
// 岗位内容字段表单：导入解析预览与草稿编辑共用，字段与后端 createJob/updateJob 校验口径一致
defineProps({
  form: { type: Object, required: true }
})
const emit = defineEmits(['change'])

const EDUCATION_OPTIONS = [
  { value: null, label: '未识别' }, { value: 1, label: '不限' }, { value: 2, label: '大专及以上' },
  { value: 3, label: '本科及以上' }, { value: 4, label: '硕士及以上' }, { value: 5, label: '博士' }
]
const JOB_TYPE_OPTIONS = [{ value: 1, label: '全职' }, { value: 2, label: '实习' }, { value: 3, label: '兼职' }]
</script>

<template>
  <div class="grid">
    <div class="field"><label>岗位名称 <i>*</i></label><input class="input" v-model="form.title" @input="emit('change')" placeholder="如：高级前端工程师" /></div>
    <div class="field"><label>所属部门 <i>*</i></label><input class="input" v-model="form.dept" @input="emit('change')" placeholder="如：技术部" /></div>
    <div class="field"><label>工作城市 <i>*</i></label><input class="input" v-model="form.city" placeholder="如：杭州" /></div>
    <div class="field"><label>最低薪资（元/月）</label><input class="input" type="number" v-model="form.salaryMin" /></div>
    <div class="field"><label>最高薪资（元/月）</label><input class="input" type="number" v-model="form.salaryMax" /></div>
    <div class="field"><label>经验要求</label><input class="input" v-model="form.experience" placeholder="如 3-5年" /></div>
    <div class="field"><label>学历要求</label><select class="select" v-model="form.education"><option v-for="opt in EDUCATION_OPTIONS" :key="String(opt.value)" :value="opt.value">{{ opt.label }}</option></select></div>
    <div class="field"><label>工作性质</label><select class="select" v-model.number="form.jobType"><option v-for="opt in JOB_TYPE_OPTIONS" :key="opt.value" :value="opt.value">{{ opt.label }}</option></select></div>
    <div class="field full"><label>岗位概述</label><textarea class="textarea" v-model="form.description" /></div>
    <div class="field full"><label>工作职责 <i>*</i>每行一条</label><textarea class="textarea" v-model="form.responsibilities" /></div>
    <div class="field full"><label>任职要求 <i>*</i>每行一条</label><textarea class="textarea" v-model="form.requirements" /></div>
  </div>
</template>

<style scoped>
.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.full{grid-column:1/-1}
.field label{display:block;margin-bottom:5px;font-size:12px;color:#5b6b83;font-weight:600}
.field label i{color:#ef4444;font-style:normal}
.textarea{min-height:64px}
</style>
