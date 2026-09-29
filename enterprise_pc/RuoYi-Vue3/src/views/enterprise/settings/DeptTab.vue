<script setup>
import { ref, computed, inject, onMounted } from 'vue'
import { Building2, UsersRound, FileText, Plus, ChevronDown, ChevronRight } from '@/views/enterprise/components/icons'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import { deptOverview, addDept, updateDept, delDept } from '@/api/system/settings'
const notify = inject('settingsNotify')
const data = ref({ depts: [], deptCount: 0, memberCount: 0, positionCount: 0 })
const collapsed = ref(new Set())
const modal = ref(null)
const form = ref({})

// 按 parent_id 组装为带 depth 的扁平树
const rows = computed(() => {
  const out = []
  const children = (pid) => data.value.depts.filter(d => (d.parentId || 0) === pid)
  const walk = (list, depth) => list.forEach(d => {
    out.push({ ...d, depth })
    if (!collapsed.value.has(d.id)) walk(children(d.id), depth + 1)
  })
  walk(children(0), 0)
  return out
})
const parentOptions = computed(() => [{ id: 0, label: '顶级部门' }, ...rows.value.map(d => ({ id: d.id, label: '　'.repeat(d.depth) + d.name }))])

// 判断是否有子部门须基于原始数据，收起后子节点不在 rows 中，否则无法再次展开
function hasChildren(id) { return data.value.depts.some(d => (d.parentId || 0) === id) }
function toggle(id) { const s = new Set(collapsed.value); s.has(id) ? s.delete(id) : s.add(id); collapsed.value = s }
async function load() { const res = await deptOverview(); data.value = res.data }
function openAdd(parentId) { form.value = { parentId: parentId || 0, name: '', leader: '', orderNum: 0 }; modal.value = 'add' }
function openEdit(d) { form.value = { id: d.id, parentId: d.parentId, name: d.name, leader: d.leader, orderNum: d.orderNum, status: d.status }; modal.value = 'edit' }
async function submit() {
  if (!form.value.name) { notify('部门名称不能为空'); return }
  if (modal.value === 'add') await addDept(form.value)
  else await updateDept(form.value.id, form.value)
  notify('保存成功'); modal.value = null; load()
}
async function remove(d) {
  if (!confirm(`确定删除部门「${d.name}」？`)) return
  try { await delDept(d.id); notify('删除成功'); load() } catch (e) { /* 拦截器已提示 */ }
}
onMounted(load)
</script>

<template>
  <div><header class="tab-head"><div><h2>组织架构</h2><p>管理公司部门结构与汇报关系，支持新增、编辑与删除部门</p></div><button class="btn primary" @click="openAdd(0)"><Plus :size="15"/>新增部门</button></header>
    <div class="summary"><article><strong>{{data.deptCount}}</strong><span>部门总数</span><Building2 :size="18"/></article><article><strong>{{data.memberCount}}</strong><span>在职成员</span><UsersRound :size="18"/></article><article><strong>{{data.positionCount}}</strong><span>涉及在招岗位</span><FileText :size="18"/></article></div>
    <div class="org-table"><div class="table-head"><span>部门名称</span><span>负责人</span><span>成员数</span><span>在招岗位</span><span>状态</span><span>操作</span></div>
      <div v-for="row in rows" :key="row.id" class="table-row">
        <span :style="{paddingLeft:`${row.depth*20+10}px`}"><component :is="collapsed.has(row.id)?ChevronRight:ChevronDown" :size="13" v-if="hasChildren(row.id)" @click="toggle(row.id)"/><component :is="ChevronDown" :size="13" v-else style="opacity:0"/> <b>{{row.name}}</b></span>
        <span>{{row.leader||'待指定'}}</span><span>{{row.members}}</span><span class="text-primary">{{row.jobs}} 个</span><span :class="row.status?'enabled':'off'">{{row.status?'启用':'停用'}}</span>
        <span class="ops"><button @click="openAdd(row.id)">新增</button><button @click="openEdit(row)">编辑</button><button class="del" @click="remove(row)">删除</button></span>
      </div>
      <p class="table-tip">提示：删除部门前请确认该部门下无关联岗位与成员</p></div>
    <BaseModal v-if="modal" :title="modal==='add'?'新增部门':'编辑部门'" width="460px" @close="modal=null">
      <div class="form"><label>部门名称<input v-model="form.name" placeholder="请输入部门名称"/></label>
        <label>上级部门<select v-model.number="form.parentId"><option v-for="o in parentOptions" :key="o.id" :value="o.id">{{o.label}}</option></select></label>
        <label>负责人<input v-model="form.leader" placeholder="负责人姓名"/></label>
        <label>显示顺序<input v-model.number="form.orderNum" type="number"/></label>
        <label v-if="modal==='edit'">状态<select v-model.number="form.status"><option :value="1">启用</option><option :value="0">停用</option></select></label>
      </div>
      <template #footer><button class="btn" @click="modal=null">取消</button><button class="btn primary" @click="submit">保存</button></template>
    </BaseModal>
  </div>
</template>

<style scoped>
.tab-head{display:flex;align-items:flex-start;justify-content:space-between}.tab-head h2{font-size:19px}.tab-head p{font-size:10px;color:#8d9baf;margin-top:5px}
.summary{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin:18px 0 15px}.summary article{height:70px;border:1px solid #e3e9f2;border-radius:10px;background:#f8fafc;padding:11px 14px;position:relative}.summary strong,.summary span{display:block}.summary strong{font-size:23px}.summary span{font-size:9px;color:#7e8da2;margin-top:3px}.summary svg{position:absolute;right:13px;top:20px;color:#2563eb}
.org-table{border:1px solid #dfe6ef;border-radius:10px;overflow:hidden}.table-head,.table-row{display:grid;grid-template-columns:2.2fr .75fr .65fr .72fr .55fr .9fr;align-items:center}.table-head{height:35px;background:#f5f7fa;color:#8391a5;font-size:9px}.table-head span{padding-left:10px}.table-row{min-height:42px;border-top:1px solid #e8edf4;font-size:9px}.table-row>span:first-child{display:flex;align-items:center;gap:5px}.table-row>span:first-child svg{cursor:pointer}.table-row .enabled{color:#079267}.table-row .off{color:#8f9bad}.ops{display:flex;gap:7px}.ops button{border:0;background:none;color:#2563eb;font-size:9px;padding:0}.ops button.del{color:#ef4444}.table-tip{font-size:8px;color:#9aa7b9;padding:10px}
.form{display:flex;flex-direction:column;gap:12px}.form label{font-size:11px;color:#465b79;display:flex;flex-direction:column;gap:5px}.form input,.form select{height:34px;border:1px solid #dfe6ef;border-radius:8px;padding:0 10px;font-size:12px}
</style>
