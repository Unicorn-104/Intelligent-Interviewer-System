<script setup>
import { ref, provide } from 'vue'
import { Building2, UsersRound, Link2, FileText, Database, CircleCheck } from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import DeptTab from './DeptTab.vue'
import MemberTab from './MemberTab.vue'
import IntegrationTab from './IntegrationTab.vue'
import TemplateTab from './TemplateTab.vue'
import DataTab from './DataTab.vue'
const active = ref('组织架构')
const toast = ref('')
const nav = [['组织架构', Building2], ['用户权限', UsersRound], ['面试集成', Link2], ['通知模板', FileText], ['数据管理', Database]]
function notify(m) { toast.value = m; setTimeout(() => toast.value = '', 2500) }
provide('settingsNotify', notify)
</script>

<template>
  <div class="page settings-page"><div class="page-heading"><div><h1>系统设置</h1><p>统一管理组织架构、成员权限、面试集成与通知数据</p></div></div>
    <div class="settings-layout"><aside class="card settings-nav"><div class="health"><CircleCheck :size="16"/><div><b>系统运行正常</b><small>服务与集成状态良好</small></div></div><button v-for="item in nav" :key="item[0]" :class="{active:active===item[0]}" @click="active=item[0]"><component :is="item[1]" :size="17"/>{{item[0]}}</button><div class="help"><b>需要帮助？</b><p>各 Tab 内操作即时保存生效</p><a>查看帮助文档</a></div></aside>
      <main class="card settings-content">
        <DeptTab v-if="active==='组织架构'"/>
        <MemberTab v-else-if="active==='用户权限'"/>
        <IntegrationTab v-else-if="active==='面试集成'"/>
        <TemplateTab v-else-if="active==='通知模板'"/>
        <DataTab v-else/>
      </main>
    </div><ToastMessage :message="toast"/></div>
</template>

<style scoped>
.settings-layout{display:grid;grid-template-columns:230px minmax(760px,1fr);gap:15px;min-height:680px}.settings-nav{padding:12px;display:flex;flex-direction:column}.health{height:61px;border:1px solid #e1e8f1;border-radius:10px;background:#f7f9fc;display:flex;align-items:center;gap:9px;padding:0 12px;color:#10b981;margin-bottom:8px}.health b,.health small{display:block}.health b{font-size:11px;color:#394b67}.health small{font-size:8px;color:#91a0b4;margin-top:3px}.settings-nav>button{height:43px;border:0;border-radius:9px;background:white;color:#465b79;display:flex;align-items:center;gap:10px;padding:0 13px;font-size:12px}.settings-nav>button.active{background:#eaf1ff;color:#2563eb;font-weight:600}.help{margin-top:auto;border-radius:10px;background:#edf4ff;padding:14px;color:#34578c}.help b{font-size:11px}.help p{font-size:9px;margin:5px 0}.help a{font-size:9px;color:#2563eb}.settings-content{padding:22px}
</style>
