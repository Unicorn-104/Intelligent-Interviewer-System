<script setup>
import { BriefcaseBusiness } from '@/views/enterprise/components/icons'
</script>

<template>
  <div class="app-logo">
    <span class="logo-mark"><BriefcaseBusiness :size="19" /></span>
    <div><strong>TalentFlow</strong><small>招聘管理系统</small></div>
  </div>
</template>

<style scoped>
.app-logo { display: flex; align-items: center; gap: 11px; color: white; }
.logo-mark { width: 34px; height: 34px; border-radius: 10px; display: grid; place-items: center; background: linear-gradient(145deg,#3b82f6,#1d4ed8); box-shadow: 0 7px 18px rgba(37,99,235,.32); }
strong { display: block; font-size: 15px; letter-spacing: .1px; }
small { display: block; color: #9eb1de; font-size: 10px; margin-top: 1px; }
</style>



