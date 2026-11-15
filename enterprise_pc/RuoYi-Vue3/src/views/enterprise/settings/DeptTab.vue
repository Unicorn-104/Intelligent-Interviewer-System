<script setup>
import { ref, computed, inject, onMounted } from 'vue'
import { Building2, UsersRound, FileText, Plus, ChevronDown, ChevronRight } from '@/views/enterprise/components/icons'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import { deptOverview, addDept, updateDept, delDept, listMembers } from '@/api/system/settings'
const notify = inject('settingsNotify')
const data = ref({ depts: [], deptCount: 0, memberCount: 0, positionCount: 0 })
const members = ref([])
const collapsed = ref(new Set())
const selectedId = ref(null)
const modal = ref(null)
const form = ref({})
const roles = [{ id: 101, name: '管理员' }, { id: 102, name: 'HR' }, { id: 103, name: '面试官' }]
const roleName = (id) => (roles.find(r => r.id === Number(id)) || { name: '未分配' }).name

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
const selected = computed(() => data.value.depts.find(d => d.id === selectedId.value) || null)
const deptMembers = computed(() => selected.value ? members.value.filter(m => m.dept === selected.value.name) : [])
const subDepts = computed(() => selected.value ? data.value.depts.filter(d => (d.parentId || 0) === selected.value.id) : [])
const parentOptions = computed(() => [{ id: 0, label: '顶级部门' }, ...rows.value.map(d => ({ id: d.id, label: '　'.repeat(d.depth) + d.name }))])

// 判断是否有子部门须基于原始数据，收起后子节点不在 rows 中，否则无法再次展开
function hasChildren(id) { return data.value.depts.some(d => (d.parentId || 0) === id) }
function within(id, ancestorId) {
  let cur = data.value.depts.find(d => d.id === id)
  while (cur && cur.parentId) {
    if (cur.parentId === ancestorId) return true
    cur = data.value.depts.find(d => d.id === cur.parentId)
  }
  return false
}
function toggle(id) {
  const s = new Set(collapsed.value)
  const collapse = !s.has(id)
  collapse ? s.add(id) : s.delete(id)
  collapsed.value = s
  if (collapse && within(selectedId.value, id)) selectedId.value = id
}
async function load() {
  const res = await deptOverview(); data.value = res.data
  try { const m = await listMembers(); members.value = m.data || [] } catch (e) { members.value = [] }
  if (!selectedId.value || !data.value.depts.some(d => d.id === selectedId.value)) selectedId.value = rows.value[0]?.id ?? null
}
function openAdd(parentId) { form.value = { parentId: parentId || 0, name: '', leader: '', orderNum: 0 }; modal.value = 'add' }
function openEdit(d) { form.value = { id: d.id, parentId: d.parentId, name: d.name, leader: d.leader, orderNum: d.orderNum, status: d.status }; modal.value = 'edit' }
async function submit() {
  if (!form.value.name) { notify('部门名称不能为空'); return }
  if (modal.value === 'add') await addDept(form.value)
  else await updateDept(form.value.id, form.value)
  notify('保存成功'); modal.value = null; load()
}
async function remove() {
  const d = selected.value
  if (!d) return
  if (!confirm(`确定删除部门「${d.name}」？`)) return
  try { await delDept(d.id); notify('删除成功'); selectedId.value = d.parentId || null; load() } catch (e) { /* 拦截器已提示 */ }
}
onMounted(load)
</script>

<template>
  <div><header class="tab-head"><div><h2>组织架构</h2><p>管理公司部门结构与汇报关系，支持新增、编辑与删除部门</p></div><button class="btn primary" @click="openAdd(0)"><Plus :size="15"/>新增部门</button></header>
    <div class="summary"><article><strong>{{data.deptCount}}</strong><span>部门总数</span><Building2 :size="18"/></article><article><strong>{{data.memberCount}}</strong><span>在职成员</span><UsersRound :size="18"/></article><article><strong>{{data.positionCount}}</strong><span>涉及在招岗位</span><FileText :size="18"/></article></div>

    <div class="org-layout">
      <aside class="org-tree">
        <div class="tree-title"><b>部门结构</b><span>{{ data.deptCount }} 个</span></div>
        <button v-for="row in rows" :key="row.id" class="tree-item" :class="{active: row.id === selectedId}" :style="{paddingLeft:`${row.depth*18+10}px`}" @click="selectedId = row.id">
          <component :is="collapsed.has(row.id)?ChevronRight:ChevronDown" :size="14" v-if="hasChildren(row.id)" class="chev" @click.stop="toggle(row.id)"/>
          <span v-else class="chev"></span>
          <span class="name">{{ row.name }}</span>
          <span class="count">{{ row.members }}</span>
        </button>
        <p v-if="!rows.length" class="tree-empty">暂无部门</p>
      </aside>

      <section v-if="selected" class="org-detail">
        <div class="detail-head">
          <div><h3>{{ selected.name }}<span :class="['status', selected.status ? 'on' : 'off']">{{ selected.status ? '启用' : '停用' }}</span></h3><p>负责人：{{ selected.leader || '待指定' }}</p></div>
          <div class="detail-ops"><button class="btn sm" @click="openAdd(selected.id)"><Plus :size="13"/>新增子部门</button><button class="btn sm" @click="openEdit(selected)">编辑</button><button class="btn sm danger-ghost" @click="remove">删除</button></div>
        </div>
        <div class="detail-meta">
          <article><span>成员数</span><strong>{{ selected.members }}</strong></article>
          <article><span>在招岗位</span><strong>{{ selected.jobs }}</strong></article>
          <article><span>下级部门</span><strong>{{ subDepts.length }}</strong></article>
          <article><span>显示顺序</span><strong>{{ selected.orderNum ?? 0 }}</strong></article>
        </div>
        <div class="detail-section">
          <div class="section-head"><b>部门成员</b><small>{{ deptMembers.length }} 人</small></div>
          <div class="member-list">
            <div v-for="m in deptMembers" :key="m.userId" class="member-row">
              <span class="avatar">{{ (m.nickName || '?').slice(0, 1) }}</span>
              <div class="member-info"><b>{{ m.nickName }}</b><small>{{ m.userName }}</small></div>
              <span class="member-role">{{ roleName(m.roleId) }}</span>
              <span :class="['member-state', m.enabled ? 'on' : 'off']">{{ m.enabled ? '正常' : '已停用' }}</span>
            </div>
            <p v-if="!deptMembers.length" class="empty-tip">该部门暂未关联成员，可在「用户权限」中调整成员所属部门</p>
          </div>
        </div>
        <div v-if="subDepts.length" class="detail-section">
          <div class="section-head"><b>下级部门</b><small>{{ subDepts.length }} 个</small></div>
          <div class="sub-list"><button v-for="c in subDepts" :key="c.id" @click="selectedId = c.id">{{ c.name }}<span>{{ c.members }}</span></button></div>
        </div>
      </section>
      <section v-else class="org-detail empty-detail">请选择左侧部门查看详情</section>
    </div>

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
.tab-head{display:flex;align-items:flex-start;justify-content:space-between;gap:16px}.tab-head h2{font-size:20px;line-height:1.3}.tab-head p{font-size:12px;color:#8d9baf;margin-top:6px;line-height:1.6}
.summary{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:20px 0 16px}.summary article{height:78px;border:1px solid #e3e9f2;border-radius:10px;background:#f8fafc;padding:14px 16px;position:relative}.summary strong,.summary span{display:block}.summary strong{font-size:24px;line-height:1.2}.summary span{font-size:12px;color:#7e8da2;margin-top:4px}.summary svg{position:absolute;right:15px;top:24px;color:#2563eb}

.org-layout{display:grid;grid-template-columns:260px minmax(0,1fr);gap:16px;align-items:start}
.org-tree{border:1px solid #e3e9f2;border-radius:12px;background:#fbfcfe;padding:8px;max-height:560px;overflow:auto}
.tree-title{display:flex;align-items:center;justify-content:space-between;padding:4px 8px 10px;font-size:12px;color:#8d9baf;border-bottom:1px solid #eef2f7;margin-bottom:6px}
.tree-title b{font-size:12px;color:#46536a}
.tree-item{width:100%;height:38px;border:0;border-radius:8px;background:transparent;display:flex;align-items:center;gap:6px;font-family:inherit;font-size:13px;color:#46536a;text-align:left;cursor:pointer}
.tree-item:hover{background:#f0f5fc}
.tree-item.active{background:#eaf1ff;color:#2563eb;font-weight:600}
.tree-item .chev{width:14px;height:14px;flex:none;color:#94a3b8;cursor:pointer}
.tree-item .name{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tree-item .count{margin-left:auto;font-size:11px;color:#8d9baf;background:#eef2f7;border-radius:999px;padding:1px 7px}
.tree-item.active .count{background:#dbe8ff;color:#2563eb}
.tree-empty{padding:24px 8px;text-align:center;font-size:12px;color:#9aa7b9}

.org-detail{border:1px solid #e3e9f2;border-radius:12px;padding:18px 20px;background:#fff;min-width:0}
.detail-head{display:flex;align-items:flex-start;justify-content:space-between;gap:14px;padding-bottom:14px;border-bottom:1px solid #eef2f7}
.detail-head h3{font-size:17px;display:flex;align-items:center;flex-wrap:wrap;gap:7px}
.detail-head p{font-size:12px;color:#8d9baf;margin-top:6px}
.status{font-size:11px;font-weight:500;padding:2px 8px;border-radius:999px}
.status.on{color:#067a55;background:#e7faf2}.status.off{color:#718096;background:#eef2f7}
.detail-ops{display:flex;gap:6px;flex-wrap:wrap}
.detail-meta{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:16px 0}
.detail-meta article{border:1px solid #edf1f7;border-radius:10px;background:#f8fafc;padding:11px 13px}
.detail-meta span{display:block;font-size:11px;color:#8d9baf}
.detail-meta strong{display:block;font-size:19px;margin-top:3px;color:#1f2d45}
.detail-section{margin-top:18px}
.section-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px}
.section-head b{font-size:13px;color:#334155}.section-head small{font-size:11px;color:#9aa7b9}
.member-row{display:grid;grid-template-columns:32px minmax(0,1fr) 76px 56px;gap:10px;align-items:center;padding:9px 4px;border-bottom:1px solid #f1f5f9;font-size:12.5px}
.member-row:last-child{border-bottom:0}
.avatar{width:30px;height:30px;border-radius:50%;background:#eaf1ff;color:#2563eb;display:grid;place-items:center;font-size:12px;font-weight:600}
.member-info{min-width:0}.member-info b{display:block;font-size:12.5px;color:#1f2d45;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.member-info small{display:block;font-size:11px;color:#9aa7b9;margin-top:2px}
.member-role{font-size:12px;color:#46536a}
.member-state{font-size:11px;padding:2px 7px;border-radius:999px;text-align:center}
.member-state.on{color:#067a55;background:#e7faf2}.member-state.off{color:#718096;background:#eef2f7}
.empty-tip{padding:20px 4px;text-align:center;font-size:12px;color:#9aa7b9;background:#fbfcfe;border-radius:8px}
.sub-list{display:flex;flex-wrap:wrap;gap:8px}
.sub-list button{height:32px;padding:0 12px;border:1px solid #e3e9f2;border-radius:8px;background:#fbfcfe;color:#46536a;font-family:inherit;font-size:12px;display:flex;align-items:center;gap:8px}
.sub-list button:hover{border-color:#b8ccf8;color:#2563eb;background:#f5f9ff}
.sub-list button span{font-size:11px;color:#9aa7b9}
.empty-detail{display:grid;place-items:center;min-height:240px;color:#9aa7b9;font-size:12px}

.form{display:flex;flex-direction:column;gap:12px}.form label{font-size:12px;color:#465b79;display:flex;flex-direction:column;gap:6px}.form input,.form select{height:36px;border:1px solid #dfe6ef;border-radius:8px;padding:0 10px;font-size:13px}
</style>
