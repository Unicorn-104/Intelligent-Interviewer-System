<script setup>
import { ref, inject, onMounted } from 'vue'
import { FileText, Plus } from '@/views/enterprise/components/icons'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import { listTemplates, addTemplate, updateTemplate, delTemplate } from '@/api/system/settings'
const notify = inject('settingsNotify')
const templates = ref([])
const modal = ref(null)
const form = ref({})
const channels = [{ v: 1, n: '站内信' }, { v: 2, n: '邮件' }, { v: 3, n: '短信' }]
const channelName = (c) => (channels.find(x => x.v === Number(c)) || { n: '站内信' }).n

async function load() { const res = await listTemplates(); templates.value = res.data }
function openAdd() { form.value = { title: '', content: '', channel: 1 }; modal.value = 'add' }
function openEdit(t) { form.value = { id: t.id, title: t.title, content: t.content, channel: t.channel, status: t.status, readonly: t.readonly }; modal.value = 'edit' }
async function submit() {
  if (!form.value.title || !form.value.content) { notify('标题与内容不能为空'); return }
  if (modal.value === 'add') await addTemplate({ title: form.value.title, content: form.value.content, channel: form.value.channel })
  else await updateTemplate(form.value.id, { title: form.value.title, content: form.value.content, channel: form.value.channel, status: form.value.status })
  notify('保存成功'); modal.value = null; load()
}
async function toggle(t) { await updateTemplate(t.id, { title: t.title, content: t.content, channel: t.channel, status: t.status ? 0 : 1 }); load() }
async function remove(t) {
  if (!confirm(`确定删除模板「${t.title}」？`)) return
  await delTemplate(t.id); notify('删除成功'); load()
}
onMounted(load)
</script>

<template>
  <div><header class="tab-head"><div><h2>通知模板</h2><p>编辑招聘各节点的候选人通知内容</p></div><button class="btn primary" @click="openAdd"><Plus :size="15"/>新增模板</button></header>
    <div class="templates">
      <article v-for="t in templates" :key="t.id">
        <FileText :size="18"/>
        <div><h3>{{t.title}}<span class="tag" v-if="t.readonly">平台</span></h3><p>{{t.content}}</p><small class="ch">渠道：{{channelName(t.channel)}}</small></div>
        <span class="pill" :class="t.status?'green':'gray'">{{t.status?'已启用':'已停用'}}</span>
        <div class="acts">
          <button @click="openEdit(t)">编辑</button>
          <button v-if="!t.readonly" @click="toggle(t)">{{t.status?'停用':'启用'}}</button>
          <button v-if="!t.readonly" class="del" @click="remove(t)">删除</button>
        </div>
      </article>
      <p v-if="!templates.length" class="empty">暂无模板</p>
    </div>
    <BaseModal v-if="modal" :title="modal==='add'?'新增模板':'编辑模板'" width="560px" @close="modal=null">
      <div class="form">
        <label>模板标题<input v-model="form.title" placeholder="如：面试提醒：${position_name}"/></label>
        <label>模板正文<textarea v-model="form.content" rows="6" placeholder="支持 ${candidate_name} 等变量占位符"></textarea></label>
        <label>发送渠道<select v-model.number="form.channel"><option v-for="c in channels" :key="c.v" :value="c.v">{{c.n}}</option></select></label>
      </div>
      <template #footer><button class="btn" @click="modal=null">取消</button><button class="btn primary" @click="submit">保存</button></template>
    </BaseModal>
  </div>
</template>

<style scoped>
.tab-head{display:flex;align-items:flex-start;justify-content:space-between}.tab-head h2{font-size:19px}.tab-head p{font-size:10px;color:#8d9baf;margin-top:5px}
.templates{margin-top:20px;display:flex;flex-direction:column;gap:10px}.templates article{min-height:78px;border:1px solid #e1e8f1;border-radius:11px;padding:13px;display:flex;align-items:center;gap:12px}.templates article>svg{color:#2563eb}.templates article>div{flex:1}.templates h3{font-size:12px}.templates p{font-size:9px;color:#8796ab;margin-top:5px;overflow:hidden;text-overflow:ellipsis;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical}.ch{font-size:8px;color:#9aa7b9;margin-top:3px;display:block}.tag{font-size:8px;color:#2563eb;background:#eaf1ff;border-radius:4px;padding:1px 5px;margin-left:6px}.acts{display:flex;gap:8px}.acts button{border:0;background:none;color:#2563eb;font-size:10px;cursor:pointer}.acts button.del{color:#ef4444}.empty{height:60px;display:grid;place-items:center;color:#9aa7b9;font-size:10px}
.form{display:flex;flex-direction:column;gap:12px}.form label{font-size:11px;color:#465b79;display:flex;flex-direction:column;gap:5px}.form input,.form select,.form textarea{border:1px solid #dfe6ef;border-radius:8px;padding:8px 10px;font-size:12px;font-family:inherit}.form input,.form select{height:34px;padding:0 10px}
</style>
