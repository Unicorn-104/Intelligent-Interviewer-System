<script setup>
import { ref, inject, onMounted } from 'vue'
import { MailPlus } from '@/views/enterprise/components/icons'
import SwitchToggle from '@/views/enterprise/components/SwitchToggle.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import { listMembers, changeMemberRole, changeMemberStatus, inviteMember } from '@/api/system/settings'
const notify = inject('settingsNotify')
const members = ref([])
const showInvite = ref(false)
const form = ref({})
const roles = [{ id: 101, name: '管理员' }, { id: 102, name: 'HR' }, { id: 103, name: '面试官' }]
const roleName = (id) => (roles.find(r => r.id === Number(id)) || { name: '未分配' }).name

async function load() { const res = await listMembers(); members.value = res.data }
async function changeRole(m, e) {
  const roleId = Number(e.target.value)
  if (!roleId) return
  await changeMemberRole(m.userId, roleId); notify('角色已更新'); load()
}
async function toggleStatus(m, val) {
  try { await changeMemberStatus(m.userId, val); notify(val ? '账号已启用' : '账号已停用') }
  catch (e) { m.enabled = val ? 0 : 1 }
}
function openInvite() { form.value = { userName: '', nickName: '', email: '', dept: '', roleId: 102 }; showInvite.value = true }
async function submitInvite() {
  if (!form.value.userName || !form.value.nickName) { notify('登录账号与姓名不能为空'); return }
  const res = await inviteMember(form.value)
  showInvite.value = false
  alert(`邀请成功！\n初始密码：${res.data.initPassword}\n请通知成员登录后修改密码`)
  notify('邀请成功'); load()
}
onMounted(load)
</script>

<template>
  <div><header class="tab-head"><div><h2>用户权限</h2><p>配置团队成员角色与功能访问范围</p></div><button class="btn primary" @click="openInvite"><MailPlus :size="15"/>邀请新用户</button></header>
    <div class="user-table"><div class="user-head"><span>姓名</span><span>所属部门</span><span>角色</span><span>账号状态</span><span>操作</span></div>
      <div v-for="m in members" :key="m.userId">
        <b>{{m.nickName}}<small class="uname">{{m.userName}}</small></b>
        <span>{{m.dept||'未分配'}}</span>
        <select class="select" :value="m.roleId" @change="changeRole(m,$event)"><option :value="null" disabled>{{roleName(m.roleId)}}</option><option v-for="r in roles" :key="r.id" :value="r.id">{{r.name}}</option></select>
        <SwitchToggle :model-value="!!m.enabled" @update:model-value="toggleStatus(m,$event)"/>
        <span class="text-muted">{{m.enabled?'正常':'已停用'}}</span>
      </div>
      <p v-if="!members.length" class="empty">暂无成员</p>
    </div>
    <BaseModal v-if="showInvite" title="邀请新用户" width="460px" @close="showInvite=false">
      <div class="form">
        <label>登录账号<input v-model.trim="form.userName" placeholder="字母/数字，登录使用"/></label>
        <label>姓名<input v-model="form.nickName" placeholder="成员姓名"/></label>
        <label>邮箱<input v-model="form.email" placeholder="选填"/></label>
        <label>所属部门<input v-model="form.dept" placeholder="部门名称"/></label>
        <label>角色<select v-model.number="form.roleId"><option v-for="r in roles" :key="r.id" :value="r.id">{{r.name}}</option></select></label>
      </div>
      <template #footer><button class="btn" @click="showInvite=false">取消</button><button class="btn primary" @click="submitInvite">发送邀请</button></template>
    </BaseModal>
  </div>
</template>

<style scoped>
.tab-head{display:flex;align-items:flex-start;justify-content:space-between}.tab-head h2{font-size:19px}.tab-head p{font-size:10px;color:#8d9baf;margin-top:5px}
.user-table{margin-top:20px;border:1px solid #e2e8f0;border-radius:10px;overflow:hidden}.user-head,.user-table>div:not(.user-head){height:55px;display:grid;grid-template-columns:1fr 1.3fr 1fr .8fr .8fr;align-items:center;padding:0 15px;border-bottom:1px solid #e8edf4;font-size:11px}.user-head{height:38px!important;background:#f5f7fa;color:#7f8da2}.user-table .select{width:110px;height:31px}.uname{font-size:9px;color:#9aa7b9;margin-left:6px}.text-muted{font-size:9px;color:#8f9bad}.empty{height:60px;display:grid;place-items:center;color:#9aa7b9;font-size:10px}
.form{display:flex;flex-direction:column;gap:12px}.form label{font-size:11px;color:#465b79;display:flex;flex-direction:column;gap:5px}.form input,.form select{height:34px;border:1px solid #dfe6ef;border-radius:8px;padding:0 10px;font-size:12px}
</style>
