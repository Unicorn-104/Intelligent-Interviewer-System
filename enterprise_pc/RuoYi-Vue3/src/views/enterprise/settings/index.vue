<script setup>
import { ref, provide } from 'vue'
import { Building2, BriefcaseBusiness, UsersRound, FileText, Database, CircleCheck } from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import DeptTab from './DeptTab.vue'
import CompanyTab from './CompanyTab.vue'
import MemberTab from './MemberTab.vue'
import TemplateTab from './TemplateTab.vue'
import DataTab from './DataTab.vue'
const active = ref('组织架构')
const toast = ref('')
const helpOpen = ref(false)
const nav = [['组织架构', Building2], ['公司信息', BriefcaseBusiness], ['用户权限', UsersRound], ['通知模板', FileText], ['数据管理', Database]]
function notify(m) { toast.value = m; setTimeout(() => toast.value = '', 2500) }
provide('settingsNotify', notify)
</script>

<template>
  <div class="page settings-page"><div class="page-heading"><div><h1>系统设置</h1><p>统一管理组织架构、成员权限与通知数据</p></div></div>
    <div class="settings-layout"><aside class="card settings-nav"><div class="health"><CircleCheck :size="16"/><div><b>系统运行正常</b><small>服务运行状态良好</small></div></div><button v-for="item in nav" :key="item[0]" :class="{active:active===item[0]}" @click="active=item[0]"><component :is="item[1]" :size="17"/>{{item[0]}}</button><div class="help"><b>系统设置帮助</b><p>了解各 Tab 的操作方式与注意事项</p><button type="button" class="help-link" @click="helpOpen = true">查看设置说明</button></div></aside>
      <main class="card settings-content">
        <DeptTab v-if="active==='组织架构'"/>
        <CompanyTab v-else-if="active==='公司信息'"/>
        <MemberTab v-else-if="active==='用户权限'"/>
        <TemplateTab v-else-if="active==='通知模板'"/>
        <DataTab v-else/>
      </main>
    </div><ToastMessage :message="toast"/>
    <el-dialog v-model="helpOpen" title="系统设置使用说明" width="540px">
      <div class="help-guide">
        <p><b>组织架构</b>：维护部门层级与负责人，支持新增、编辑、删除部门；删除前请确认该部门下没有关联岗位和成员。</p>
        <p><b>公司信息</b>：维护企业名称、行业、规模、地址、官网、Logo 与简介，保存后同步更新候选人端展示的企业资料。</p>
        <p><b>用户权限</b>：邀请成员加入企业并分配角色，调整角色后成员的访问范围立即生效。</p>
        <p><b>通知模板</b>：新增或编辑面试、Offer 等招聘节点的通知内容，正文支持 <code>${candidate_name}</code> 等变量占位符。</p>
        <p><b>数据管理</b>：导出候选人数据、备份核心业务数据，或清理两年以上的历史数据；清理操作不可撤销，请谨慎确认。</p>
      </div>
    </el-dialog>
  </div>
</template>

<style scoped>
.settings-layout{display:grid;grid-template-columns:208px minmax(0,1fr);gap:18px;align-items:start}.settings-nav{padding:12px;display:flex;flex-direction:column;gap:2px}.health{height:64px;border:1px solid #e1e8f1;border-radius:10px;background:#f7f9fc;display:flex;align-items:center;gap:9px;padding:0 12px;color:#10b981;margin-bottom:8px}.health b,.health small{display:block}.health b{font-size:12px;color:#394b67}.health small{font-size:11px;color:#91a0b4;margin-top:3px}.settings-nav>button{height:42px;border:0;border-radius:9px;background:transparent;color:#465b79;display:flex;align-items:center;gap:10px;padding:0 12px;font-size:13px;transition:.16s}.settings-nav>button:hover{background:#f4f7fb}.settings-nav>button.active{background:#eaf1ff;color:#2563eb;font-weight:600}.help{margin-top:14px;border-top:1px solid #e6ecf4;padding:14px 6px 2px;color:#5b6b84}.help b{font-size:12px;color:#334155}.help p{font-size:11px;line-height:1.6;margin:5px 0 8px;color:#8d9baf}.help-link{padding:0;border:0;background:none;color:#2563eb;font-size:12px;font-family:inherit;cursor:pointer}.help-link:hover{text-decoration:underline}.help-guide p{margin:0 0 10px;font-size:13px;line-height:1.7;color:#46536a}.help-guide b{color:#1f2937}.help-guide code{color:#2563eb;background:#eef4ff;padding:1px 3px;border-radius:3px}.settings-content{padding:24px;min-width:0}
</style>
