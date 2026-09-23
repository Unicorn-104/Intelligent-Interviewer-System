<script setup>
import { useRouter } from 'vue-router'
import { ArrowLeft, UsersRound, Settings } from '@/views/enterprise/components/icons'
import AppLogo from './AppLogo.vue'
const router=useRouter()
</script>

<template>
  <aside class="meeting-rail"><AppLogo/><span class="label">面试工作台</span><button @click="router.push('/enterprise/interviews')"><ArrowLeft :size="19"/><span>返回面试列表</span></button><button><UsersRound :size="19"/><span>切换候选人</span></button><button class="settings" @click="router.push('/enterprise/settings')"><Settings :size="19"/><span>系统设置</span></button></aside>
</template>

<style scoped>
.meeting-rail{position:fixed;inset:0 auto 0 0;width:96px;background:white;border-right:1px solid #e5ebf3;display:flex;flex-direction:column;align-items:center;padding:16px 7px;z-index:10}.app-logo{transform:scale(.84);transform-origin:top center;width:178px;color:var(--text)}.label{color:#8a99ad;font-size:9px;margin:27px 0 10px}.meeting-rail button{width:80px;height:60px;border:0;border-radius:10px;background:white;color:#62738f;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;font-size:9px}.meeting-rail button:hover,.meeting-rail button:first-of-type{background:#edf4ff;color:#2563eb}.meeting-rail .settings{margin-top:auto}
</style>



