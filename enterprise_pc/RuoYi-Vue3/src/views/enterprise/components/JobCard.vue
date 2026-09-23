<script setup>
import { MapPin, Users, CalendarDays } from '@/views/enterprise/components/icons'
defineProps({ job: Object, selected: Boolean })
defineEmits(['select', 'toggle'])
</script>

<template>
  <article class="job-card" :class="{ selected }" @click="$emit('select')">
    <div class="job-head"><div><h3>{{ job.pos_title || job.name }}</h3><span class="pill" :class="job.tone"><i class="dot" />{{ job.status }}</span></div><button class="toggle" :class="{ on: job.active }" @click.stop="$emit('toggle')"><i /></button></div>
    <div class="tags"><span v-for="skill in job.skills.slice(0,3)" :key="skill">{{ skill }}</span></div>
    <div class="meta"><span><BriefcaseBusinessIcon/>{{ job.pos_department || job.dept }}</span><span><MapPin :size="13"/>{{ job.pos_work_city || job.city }}</span><span><Users :size="13"/>招聘 {{ job.count }} 人</span><span>{{ job.salary || `${job.pos_salary_min}-${job.pos_salary_max}` }}</span><span><CalendarDays :size="13"/>{{ job.date }} 发布</span></div>
  </article>
</template>

<script>
import { BriefcaseBusiness as BriefcaseBusinessIcon } from '@/views/enterprise/components/icons'
export default { components: { BriefcaseBusinessIcon } }
</script>

<style scoped>
.job-card{border:1px solid #e1e8f2;border-radius:13px;padding:14px 16px;background:white;cursor:pointer;transition:.18s}.job-card:hover{border-color:#b6cbf7;box-shadow:0 7px 18px rgba(37,99,235,.07)}.job-card.selected{border:1.5px solid var(--primary);box-shadow:0 0 0 3px rgba(37,99,235,.05)}.job-head,.job-head>div{display:flex;align-items:center}.job-head{justify-content:space-between}.job-head h3{font-size:15px}.job-head>div{gap:9px}.toggle{width:39px;height:22px;border:0;border-radius:20px;background:#cbd5e1;padding:3px}.toggle i{display:block;width:16px;height:16px;border-radius:50%;background:white;transition:.2s}.toggle.on{background:#2563eb}.toggle.on i{transform:translateX(17px)}.tags{display:flex;gap:6px;margin:10px 0}.tags span{font-size:10px;padding:3px 7px;border-radius:5px;background:#f0f5ff;color:#3868c4}.meta{display:flex;align-items:center;gap:15px;color:#74849b;font-size:11px}.meta span{display:flex;align-items:center;gap:4px}.meta svg{width:13px;height:13px}
</style>



