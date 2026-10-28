<script setup>
import { markRaw, reactive, ref, watch } from 'vue'
import { onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { LayoutDashboard, BriefcaseBusiness, CalendarDays, MessageCircle, Settings, UsersRound, Video, ChevronDown, FileText } from '@/views/enterprise/components/icons'
import AppLogo from './AppLogo.vue'
import { totalUnread, refreshUnread } from '@/views/enterprise/store/unread'

const route = useRoute()
onMounted(refreshUnread)
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
    match: ['EnterpriseCandidates', 'EnterpriseCandidateUnscreened', 'EnterpriseCandidateProcess', 'EnterpriseScreening', 'EnterpriseTalent', 'EnterpriseSurvey'],
    children: [
      { label: '候选人列表', to: '/enterprise/candidates', match: ['EnterpriseCandidates', 'EnterpriseCandidateProcess'] },
      { label: '待初筛投递', to: '/enterprise/candidates/unscreened', match: ['EnterpriseCandidateUnscreened'] },
      { label: 'AI 初筛', to: '/enterprise/screening', match: ['EnterpriseScreening'] },
      { label: '人才库', to: '/enterprise/talent', match: ['EnterpriseTalent'] },
      { label: '满意度调研', to: '/enterprise/survey', match: ['EnterpriseSurvey'] }
    ] },
  { label: '面试与笔试', to: '/enterprise/interviews', icon: markRaw(CalendarDays),
    match: ['EnterpriseInterviews', 'EnterpriseInterviewEvaluation', 'EnterpriseExam', 'EnterpriseExamProctor', 'EnterpriseExamProctorRoom'],
    children: [
      { label: '面试安排', to: '/enterprise/interviews', match: ['EnterpriseInterviews', 'EnterpriseInterviewEvaluation'] },
      { label: '笔试管理', to: '/enterprise/exam', match: ['EnterpriseExam'] },
      { label: '监考监控', to: '/enterprise/exam/proctor', match: ['EnterpriseExamProctor', 'EnterpriseExamProctorRoom'] }
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
const openGroup = ref(null)
const helpOpen = ref(false)
const active = (item) => item.match.includes(route.name)
// 进入任意页面自动展开所在分组（单开：同时只展开一组）
watch(() => route.name, (name) => {
  const group = menus.find(m => m.match.includes(name))
  if (group) openGroup.value = group.label
}, { immediate: true })
// 点击父项：已展开且已在本组页面则收起，否则展开并跳转主页面
function toggle(item) {
  if (!item.children) return
  openGroup.value = openGroup.value === item.label ? null : item.label
}
</script>

<template>
  <aside class="sidebar">
    <AppLogo />
    <nav>
      <div v-for="item in menus" :key="item.label" class="nav-group">
        <RouterLink :to="item.to" :class="{ active: active(item) }" @click="toggle(item)">
          <component :is="item.icon" :size="19" :stroke-width="1.7" />
          <span>{{ item.label }}</span>
          <em v-if="item.badge">{{ item.badge }}</em>
          <ChevronDown v-if="item.children" class="arrow" :class="{ open: openGroup === item.label }" :size="15" />
        </RouterLink>
        <div v-show="item.children && openGroup === item.label" class="sub-menu">
          <RouterLink v-for="c in item.children" :key="c.to" :to="c.to" :class="{ 'sub-active': c.match.includes(route.name) }">{{ c.label }}</RouterLink>
        </div>
      </div>
    </nav>
    <button class="support" @click="helpOpen = true">
      <div class="support-icon">?</div>
      <div><b>需要帮助？</b><small>查看使用指南</small></div>
    </button>
    <span class="version">TalentFlow v1.0</span>
    <el-dialog v-model="helpOpen" title="使用指南" width="540px">
      <div class="guide">
        <p><b>1. 发布岗位</b>：招聘总览右上角「快速发布岗位」，或进入「岗位管理」新建、导入岗位与草稿。</p>
        <p><b>2. 候选人初筛</b>：在「候选人与初筛」的待初筛投递、AI 初筛中处理简历，可批量打标签与更新状态。</p>
        <p><b>3. 面试与笔试</b>：在「面试与笔试」安排面试、发起视频会议，并录入面试评价。</p>
        <p><b>4. Offer 管理</b>：候选人通过面试后，在「Offer 管理」发起并跟踪 Offer 流程。</p>
        <p><b>5. 消息与协作</b>：顶栏铃铛与「消息中心」查看候选人消息、面试邀约与系统通知。</p>
      </div>
    </el-dialog>
  </aside>
</template>

<style scoped>
.sidebar { position: fixed; inset: 0 auto 0 0; z-index: 20; width: 220px; padding: 20px 16px; background: linear-gradient(180deg, #172554 0%, #172b5f 100%); display: flex; flex-direction: column; box-shadow: 6px 0 24px rgba(15,23,42,.08); }
.app-logo { margin: 0 7px 24px; }
nav { display: flex; flex-direction: column; gap: 7px; }
nav a { height: 46px; border-radius: 10px; display: flex; align-items: center; gap: 13px; padding: 0 13px; color: #9fb0d4; font-size: 14px; position: relative; transition: .18s; }
nav a:hover { color: white; background: rgba(255,255,255,.07); }
nav a.active { color: #143988; background: #dce7ff; font-weight: 600; box-shadow: 0 5px 14px rgba(3,10,32,.12); }
nav em { margin-left: auto; min-width: 20px; height: 20px; padding: 0 5px; font-style: normal; display: grid; place-items: center; border-radius: 10px; background: #ef4444; color: white; font-size: 10px; line-height: 1; }
.arrow { margin-left: auto; transition: transform .2s; color: #7f95c4; flex: none; }
a.active .arrow { color: #143988; }
.arrow.open { transform: rotate(180deg); }
.sub-menu { display: flex; flex-direction: column; gap: 2px; padding: 4px 0 2px; overflow: hidden; }
.sub-menu a { height: 34px; font-size: 12px; padding: 0 13px 0 45px; border-radius: 8px; color: #8fa4d0; gap: 0; }
.sub-menu a:hover { color: white; background: rgba(255,255,255,.06); }
.sub-menu a.sub-active { color: #dce7ff; background: rgba(220,231,255,.14); font-weight: 600; box-shadow: none; }
.support { margin-top: auto; display: flex; align-items: center; gap: 9px; color: #dce7ff; background: rgba(255,255,255,.07); border: 1px solid rgba(255,255,255,.06); border-radius: 11px; padding: 11px; width: 100%; font: inherit; text-align: left; cursor: pointer; }
.support:hover { background: rgba(255,255,255,.12); }
.support-icon { width: 28px; height: 28px; display: grid; place-items: center; border-radius: 8px; color: white; background: #2d5bc3; font-weight: 700; }
.support b { display: block; font-size: 11px; }
.support small { color: #8fa4d0; font-size: 10px; }
.guide p { margin: 0 0 10px; font-size: 13px; line-height: 1.7; color: #46536a; }
.guide b { color: #1f2937; }
.version { color: #687da9; text-align: center; font-size: 10px; margin-top: 13px; }
</style>
