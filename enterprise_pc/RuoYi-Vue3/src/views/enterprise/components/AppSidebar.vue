<script setup>
import { useRoute } from 'vue-router'
import { LayoutDashboard, BriefcaseBusiness, CalendarDays, MessageCircle, Settings, UsersRound } from '@/views/enterprise/components/icons'
import AppLogo from './AppLogo.vue'

const route = useRoute()
const menus = [
  { label: '招聘总览', to: '/enterprise/dashboard', icon: LayoutDashboard, match: 'EnterpriseDashboard' },
  { label: '岗位管理', to: '/enterprise/jobs', icon: BriefcaseBusiness, match: ['EnterpriseJobs', 'EnterpriseJobDetail', 'EnterpriseWorkflowConfig'] },
  { label: '候选人管理', to: '/enterprise/candidates', icon: UsersRound, match: ['EnterpriseCandidates', 'EnterpriseCandidateProcess'] },
  { label: '面试安排中心', to: '/enterprise/interviews', icon: CalendarDays, match: ['EnterpriseInterviews', 'EnterpriseInterviewEvaluation'] },
  { label: '消息中心', to: '/enterprise/messages', icon: MessageCircle, match: 'EnterpriseMessages', badge: 5 },
  { label: '系统设置', to: '/enterprise/settings', icon: Settings, match: 'EnterpriseSettings' }
]
const active = (item) => Array.isArray(item.match) ? item.match.includes(route.name) : route.name === item.match
</script>

<template>
  <aside class="sidebar">
    <AppLogo />
    <nav>
      <RouterLink v-for="item in menus" :key="item.label" :to="item.to" :class="{ active: active(item) }">
        <component :is="item.icon" :size="19" :stroke-width="1.7" />
        <span>{{ item.label }}</span>
        <em v-if="item.badge">{{ item.badge }}</em>
      </RouterLink>
    </nav>
    <div class="support">
      <div class="support-icon">?</div>
      <div><b>需要帮助？</b><small>查看使用指南</small></div>
    </div>
    <span class="version">TalentFlow v1.0</span>
  </aside>
</template>

<style scoped>
.sidebar { position: fixed; inset: 0 auto 0 0; z-index: 20; width: 220px; padding: 20px 16px; background: linear-gradient(180deg, #172554 0%, #172b5f 100%); display: flex; flex-direction: column; box-shadow: 6px 0 24px rgba(15,23,42,.08); }
.app-logo { margin: 0 7px 30px; }
nav { display: flex; flex-direction: column; gap: 7px; }
nav a { height: 46px; border-radius: 10px; display: flex; align-items: center; gap: 13px; padding: 0 13px; color: #9fb0d4; font-size: 14px; position: relative; transition: .18s; }
nav a:hover { color: white; background: rgba(255,255,255,.07); }
nav a.active { color: #143988; background: #dce7ff; font-weight: 600; box-shadow: 0 5px 14px rgba(3,10,32,.12); }
nav em { margin-left: auto; min-width: 20px; height: 20px; padding: 0 5px; font-style: normal; display: grid; place-items: center; border-radius: 10px; background: #ef4444; color: white; font-size: 10px; }
.support { margin-top: auto; display: flex; align-items: center; gap: 9px; color: #dce7ff; background: rgba(255,255,255,.07); border: 1px solid rgba(255,255,255,.06); border-radius: 11px; padding: 11px; }
.support-icon { width: 28px; height: 28px; display: grid; place-items: center; border-radius: 8px; color: white; background: #2d5bc3; font-weight: 700; }
.support b { display: block; font-size: 11px; }
.support small { color: #8fa4d0; font-size: 10px; }
.version { color: #687da9; text-align: center; font-size: 10px; margin-top: 13px; }
</style>



