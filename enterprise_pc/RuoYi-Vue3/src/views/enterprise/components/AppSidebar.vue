<script setup>
import { markRaw, reactive, ref, watch } from 'vue'
import { onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { LayoutDashboard, BriefcaseBusiness, CalendarDays, MessageCircle, Settings, UsersRound, Video, ChevronDown, FileText } from '@/views/enterprise/components/icons'
import AppLogo from './AppLogo.vue'
import HelpGuideDialog from './HelpGuideDialog.vue'
import { totalUnread, refreshUnread } from '@/views/enterprise/store/unread'
import { pendingRescheduleCount, refreshPendingReschedule } from '@/views/enterprise/store/reschedule'

const route = useRoute()
onMounted(refreshUnread)
onMounted(refreshPendingReschedule)
// 分组导航：父项点击跳转主页面并展开子项（单开手风琴），子项点击直达对应页面
const menus = reactive([
  { label: '招聘总览', to: '/enterprise/dashboard', icon: markRaw(LayoutDashboard), match: ['EnterpriseDashboard', 'EnterpriseRootDashboard'] },
  { label: '岗位管理', to: '/enterprise/jobs', icon: markRaw(BriefcaseBusiness),
    match: ['EnterpriseJobs', 'EnterpriseJobDetail', 'EnterpriseWorkflowConfig', 'EnterpriseJobImport'],
    children: [
      { label: '岗位列表', to: '/enterprise/jobs', match: ['EnterpriseJobs', 'EnterpriseJobDetail', 'EnterpriseWorkflowConfig'] },
      { label: '岗位导入与草稿', to: '/enterprise/jobs/import', match: ['EnterpriseJobImport'] }
    ] },
  { label: '候选人与初筛', to: '/enterprise/candidates', icon: markRaw(UsersRound),
    match: ['EnterpriseCandidates', 'EnterpriseCandidateProcess', 'EnterpriseResumeScreening', 'EnterpriseResumeScreeningAi', 'EnterpriseTalent'],
    children: [
      { label: '候选人列表', to: '/enterprise/candidates', match: ['EnterpriseCandidates', 'EnterpriseCandidateProcess'] },
      { label: '投递详情', to: '/enterprise/resume-screening', match: ['EnterpriseResumeScreening'] },
      { label: 'AI 评分详情', to: '/enterprise/resume-screening/ai', match: ['EnterpriseResumeScreeningAi'] },
      { label: '人才库', to: '/enterprise/talent', match: ['EnterpriseTalent'] }
    ] },
  { label: '面试与笔试', to: '/enterprise/interviews', icon: markRaw(CalendarDays),
    match: ['EnterpriseInterviews', 'EnterpriseInterviewEvaluation', 'EnterpriseExam', 'EnterpriseExamProctor', 'EnterpriseExamProctorRoom', 'EnterpriseSurvey', 'EnterpriseRescheduleReview'],
    dot: pendingRescheduleCount,
    children: [
      { label: '面试安排', to: '/enterprise/interviews', match: ['EnterpriseInterviews', 'EnterpriseInterviewEvaluation'] },
      { label: '改期审批', to: '/enterprise/interviews/reschedule-review', match: ['EnterpriseRescheduleReview'], badge: pendingRescheduleCount },
      { label: '笔试管理', to: '/enterprise/exam', match: ['EnterpriseExam'] },
      { label: '监考监控', to: '/enterprise/exam/proctor', match: ['EnterpriseExamProctor', 'EnterpriseExamProctorRoom'] },
      { label: '满意度调研', to: '/enterprise/survey', match: ['EnterpriseSurvey'] }
    ] },
  { label: 'Offer 管理', to: '/enterprise/offer', icon: markRaw(FileText), match: ['EnterpriseOffer'] },
  { label: '视频会议', to: '/enterprise/conference/active', icon: markRaw(Video),
    match: ['EnterpriseConferenceActive', 'EnterpriseConferenceRecords', 'EnterpriseConferencePlayback'],
    children: [
      { label: '正在进行的面试', to: '/enterprise/conference/active', match: ['EnterpriseConferenceActive'] },
      { label: '录制回放', to: '/enterprise/conference/records', match: ['EnterpriseConferenceRecords', 'EnterpriseConferencePlayback'] }
    ] },
  { label: '消息中心', to: '/enterprise/messages', icon: markRaw(MessageCircle), match: ['EnterpriseMessages'], badge: totalUnread },
  { label: '系统设置', to: '/enterprise/settings', icon: markRaw(Settings),
    match: ['EnterpriseSettings', 'EnterpriseProfile'],
    children: [
      { label: '系统设置', to: '/enterprise/settings', match: ['EnterpriseSettings'] },
      { label: '个人档案', to: '/enterprise/profile', match: ['EnterpriseProfile'] }
    ] }
])
const openGroups = reactive(new Set())
const helpOpen = ref(false)
const active = (item) => item.match.includes(route.name)
// 进入任意页面自动展开所在分组（多个分组可同时展开）
watch(() => route.name, (name) => {
  const group = menus.find(m => m.match.includes(name))
  if (group) openGroups.add(group.label)
}, { immediate: true })
// 点击父项：仅展开/收起子菜单，不做页面跳转
function toggle(item) {
  if (!item.children) return
  if (openGroups.has(item.label)) openGroups.delete(item.label)
  else openGroups.add(item.label)
}
</script>

<template>
  <aside class="sidebar">
    <AppLogo />
    <nav>
      <div v-for="item in menus" :key="item.label" class="nav-group">
        <div class="nav-row" :class="{ active: active(item) }">
          <button v-if="item.children" type="button" class="parent-btn" :class="{ active: active(item) }" @click="toggle(item)">
            <component :is="item.icon" :size="19" :stroke-width="1.7" />
            <span>{{ item.label }}</span>
            <em v-if="item.badge">{{ item.badge }}</em>
            <i v-if="item.dot" class="dot-badge"></i>
          </button>
          <RouterLink v-else :to="item.to" :class="{ active: active(item) }">
            <component :is="item.icon" :size="19" :stroke-width="1.7" />
            <span>{{ item.label }}</span>
            <em v-if="item.badge">{{ item.badge }}</em>
            <i v-if="item.dot" class="dot-badge"></i>
          </RouterLink>
          <button v-if="item.children" type="button" class="arrow-btn" :class="{ open: openGroups.has(item.label) }" :title="openGroups.has(item.label) ? '收起' : '展开'" @click.stop="toggle(item)">
            <ChevronDown :size="15" />
          </button>
        </div>
        <div v-show="item.children && openGroups.has(item.label)" class="sub-menu">
          <RouterLink v-for="c in item.children" :key="c.to" :to="c.to" :class="{ 'sub-active': c.match.includes(route.name) }">{{ c.label }}<em v-if="c.badge">{{ c.badge }}</em></RouterLink>
        </div>
      </div>
    </nav>
    <button class="support" @click="helpOpen = true">
      <div class="support-icon">?</div>
      <div><b>需要帮助？</b><small>查看使用指南</small></div>
    </button>
    <span class="version">TalentFlow v1.0</span>
    <HelpGuideDialog v-model="helpOpen" />
  </aside>
</template>

<style scoped>
.sidebar { position: fixed; inset: 0 auto 0 0; z-index: 20; width: 220px; padding: 20px 16px; background: linear-gradient(180deg, #172554 0%, #172b5f 100%); display: flex; flex-direction: column; box-shadow: 6px 0 24px rgba(15,23,42,.08); }
.app-logo { margin: 0 7px 24px; flex: none; }
nav { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 7px; overflow-y: auto; scrollbar-width: none; }
nav::-webkit-scrollbar { width: 0; height: 0; display: none; }
nav a { height: 46px; border-radius: 10px; display: flex; align-items: center; gap: 0; padding: 0 13px; color: #9fb0d4; font-size: 14px; position: relative; transition: .18s; }
.nav-group { flex: none; }
.nav-row { position: relative; }
.nav-row > a, .parent-btn { padding-right: 36px; }
.parent-btn { width: 100%; height: 46px; display: flex; align-items: center; gap: 0; padding: 0 36px 0 13px; border: 0; border-radius: 10px; background: transparent; color: #9fb0d4; font: inherit; font-size: 14px; text-align: left; cursor: pointer; transition: .18s; }
.nav-row:hover a, .nav-row:hover .parent-btn { color: white; background: rgba(255,255,255,.07); }
nav a.active, .parent-btn.active { color: #143988; background: #dce7ff; font-weight: 600; box-shadow: 0 5px 14px rgba(3,10,32,.12); }
nav a > svg:first-child, .parent-btn > svg:first-child { margin-right: 12px; flex: none; }
nav a span, .parent-btn span { flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
nav em { margin-left: 8px; flex: none; min-width: 20px; height: 20px; padding: 0 5px; font-style: normal; display: grid; place-items: center; border-radius: 10px; background: #ef4444; color: white; font-size: 10px; line-height: 1; }
.arrow-btn { position: absolute; right: 7px; top: 50%; transform: translateY(-50%); width: 26px; height: 26px; display: grid; place-items: center; padding: 0; border: 0; border-radius: 7px; background: transparent; color: #7f95c4; cursor: pointer; }
.arrow-btn:hover { color: #fff; }
.arrow-btn svg { transition: transform .2s; }
.arrow-btn.open svg { transform: rotate(180deg); }
.nav-row.active .arrow-btn { color: #143988; }
.nav-row.active .arrow-btn:hover { color: #143988; }
.sub-menu { display: flex; flex-direction: column; gap: 2px; padding: 4px 0 2px; overflow: hidden; }
.dot-badge { width: 8px; height: 8px; border-radius: 50%; background: #ef4444; box-shadow: 0 0 0 3px rgba(239,68,68,.18); flex: none; margin-left: 8px; }
.sub-menu em { min-width: 18px; height: 18px; padding: 0 5px; font-size: 10px; margin-left: auto; }
.sub-menu a { height: 34px; font-size: 12px; padding: 0 13px 0 45px; border-radius: 8px; color: #8fa4d0; gap: 0; }
.sub-menu a:hover { color: white; background: rgba(255,255,255,.06); }
.sub-menu a.sub-active { color: #dce7ff; background: rgba(220,231,255,.14); font-weight: 600; box-shadow: none; }
.support { margin-top: 12px; flex: none; display: flex; align-items: center; gap: 9px; color: #dce7ff; background: rgba(255,255,255,.07); border: 1px solid rgba(255,255,255,.06); border-radius: 11px; padding: 11px; width: 100%; font: inherit; text-align: left; cursor: pointer; }
.support:hover { background: rgba(255,255,255,.12); }
.support-icon { width: 28px; height: 28px; display: grid; place-items: center; border-radius: 8px; color: white; background: #2d5bc3; font-weight: 700; }
.support b { display: block; font-size: 11px; }
.support small { color: #8fa4d0; font-size: 10px; }
.version { flex: none; color: #687da9; text-align: center; font-size: 10px; margin-top: 13px; }
</style>
