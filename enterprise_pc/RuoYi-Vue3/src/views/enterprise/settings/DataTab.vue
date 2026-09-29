<script setup>
import { ref, inject, onMounted } from 'vue'
import { Download, Archive, Trash2 } from '@/views/enterprise/components/icons'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import { dataOverview, exportResumes, backupNow, cleanupPreview, cleanupExecute } from '@/api/system/settings'
const notify = inject('settingsNotify')
const info = ref({ lastBackup: null, cleanupCount: 0 })
const busy = ref('')
const showCleanup = ref(false)
const cleanupList = ref([])

async function load() { const res = await dataOverview(); info.value = { lastBackup: res.lastBackup, cleanupCount: res.cleanupCount } }
async function doExport() {
  busy.value = 'export'
  try {
    const res = await exportResumes()
    const a = document.createElement('a')
    a.href = import.meta.env.VITE_APP_BASE_API + res.data.url
    a.download = res.data.url.split('/').pop()
    a.click()
    notify(`导出成功，共 ${res.data.count} 条`)
  } finally { busy.value = '' }
}
async function doBackup() {
  busy.value = 'backup'
  try { const res = await backupNow(); notify(`备份完成：${res.data.fileName}`); load() }
  finally { busy.value = '' }
}
async function openCleanup() {
  const res = await cleanupPreview()
  cleanupList.value = res.data
  showCleanup.value = true
}
async function doCleanup() {
  if (!cleanupList.value.length) { notify('没有符合条件的数据'); return }
  busy.value = 'cleanup'
  try {
    const res = await cleanupExecute(cleanupList.value.map(r => r.talId))
    notify(`已清理 ${res.deleted} 条数据`)
    showCleanup.value = false
    load()
  } finally { busy.value = '' }
}
onMounted(load)
</script>

<template>
  <div><header class="tab-head"><div><h2>数据管理</h2><p>导出、备份与清理招聘业务数据</p></div></header>
    <div class="data-actions">
      <article><span><Download :size="22"/></span><div><h3>简历数据导出</h3><p>导出本公司全部候选人数据（CSV：姓名/岗位/状态/入库时间）</p></div><button class="btn" :disabled="busy==='export'" @click="doExport">{{busy==='export'?'导出中…':'开始导出'}}</button></article>
      <article><span><Archive :size="22"/></span><div><h3>系统数据备份</h3><p>最近备份：{{info.lastBackup||'暂无备份'}} · 备份本公司核心业务数据</p></div><button class="btn" :disabled="busy==='backup'" @click="doBackup">{{busy==='backup'?'备份中…':'立即备份'}}</button></article>
      <article class="danger-zone"><span><Trash2 :size="22"/></span><div><h3>历史数据清理</h3><p>清理两年以上且已结束流程（淘汰/录用）的数据，当前可清理 {{info.cleanupCount}} 条，此操作不可撤销</p></div><button class="btn danger-ghost" @click="openCleanup">进入清理</button></article>
    </div>
    <BaseModal v-if="showCleanup" title="历史数据清理" width="520px" @close="showCleanup=false">
      <p class="tip">以下 {{cleanupList.length}} 条候选人数据将被永久删除（流程结束超过 2 年）：</p>
      <div class="clean-list"><div v-for="r in cleanupList" :key="r.talId"><b>{{r.candidateName}}</b><span>#{{r.talId}}</span></div></div>
      <p v-if="!cleanupList.length" class="tip">暂无符合清理条件的数据</p>
      <template #footer><button class="btn" @click="showCleanup=false">取消</button><button class="btn danger-ghost" :disabled="!cleanupList.length||busy==='cleanup'" @click="doCleanup">{{busy==='cleanup'?'清理中…':'确认清理'}}</button></template>
    </BaseModal>
  </div>
</template>

<style scoped>
.tab-head{display:flex;align-items:flex-start;justify-content:space-between}.tab-head h2{font-size:19px}.tab-head p{font-size:10px;color:#8d9baf;margin-top:5px}
.data-actions{margin-top:20px;display:flex;flex-direction:column;gap:10px}.data-actions article{min-height:78px;border:1px solid #e1e8f1;border-radius:11px;padding:13px;display:flex;align-items:center;gap:12px}.data-actions article>span{width:42px;height:42px;border-radius:11px;background:#eef4ff;color:#2563eb;display:grid;place-items:center}.data-actions article>div{flex:1}.data-actions h3{font-size:12px}.data-actions p{font-size:9px;color:#8796ab;margin-top:5px}.data-actions article.danger-zone{border-color:#fed7d7;background:#fffafa}.data-actions article.danger-zone>span{background:#feecec;color:#ef4444}
.tip{font-size:11px;color:#465b79}.clean-list{margin-top:10px;max-height:260px;overflow:auto;border:1px solid #e8edf4;border-radius:8px}.clean-list div{display:flex;justify-content:space-between;padding:8px 12px;font-size:11px;border-bottom:1px solid #f0f4f9}.clean-list span{color:#9aa7b9}
</style>
