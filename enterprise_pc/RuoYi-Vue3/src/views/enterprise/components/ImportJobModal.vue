<script setup>
import { ref } from 'vue'
import { CloudUpload, FileText, RotateCw, CircleCheck, Trash2 } from '@/views/enterprise/components/icons'
import BaseModal from './BaseModal.vue'
const emit = defineEmits(['close', 'done'])
const parsing = ref(false)
const files = ref([
  { name: '高级前端工程师JD.docx', done: false },
  { name: '产品经理JD.pdf', done: true }
])
function remove(index) { files.value.splice(index, 1) }
function parse() { parsing.value = true; setTimeout(() => { files.value.forEach(f => f.done = true); parsing.value = false; emit('done') }, 900) }
</script>

<template>
  <BaseModal title="导入岗位文件" width="570px" @close="$emit('close')">
    <p class="intro">支持上传 JD 文档，AI 将自动解析生成岗位画像，无需手动填写。</p>
    <label class="dropzone"><input type="file" hidden multiple /><CloudUpload :size="36"/><b>拖拽文件到此处或点击上传</b><small>支持 .docx / .pdf / .txt 格式，单个文件不超过 10MB</small></label>
    <div class="file-list">
      <div v-for="(file,index) in files" :key="file.name"><FileText :size="18"/><span>{{ file.name }}</span><em :class="{ done: file.done }"><CircleCheck v-if="file.done" :size="15"/><RotateCw v-else :size="15"/>{{ file.done ? '已解析' : '解析中' }}</em><button @click="remove(index)"><Trash2 :size="15"/></button></div>
    </div>
    <template #footer><button class="btn" @click="$emit('close')">取消</button><button class="btn primary" :disabled="parsing" @click="parse"><RotateCw v-if="parsing" class="spinning" :size="15"/>{{ parsing ? '正在解析' : '开始解析' }}</button></template>
  </BaseModal>
</template>

<style scoped>
.intro{font-size:13px;color:#6f7f99;margin-bottom:16px}.dropzone{height:145px;border:1.5px dashed #a9c8ff;border-radius:12px;background:#f8fbff;display:flex;flex-direction:column;align-items:center;justify-content:center;color:#2870ef}.dropzone b{color:#26364f;font-size:13px;margin-top:9px}.dropzone small{color:#96a4b8;margin-top:6px;font-size:11px}.file-list{display:flex;flex-direction:column;gap:8px;margin-top:16px}.file-list>div{height:45px;border:1px solid #e0e7f1;border-radius:9px;background:#f8fafc;display:flex;align-items:center;gap:9px;padding:0 12px;color:#2563eb}.file-list span{flex:1;color:#26364f;font-size:12px}.file-list em{display:flex;align-items:center;gap:5px;font-style:normal;color:#2970ed;font-size:11px}.file-list em:not(.done) svg{animation:spin 1s linear infinite}.file-list em.done{color:#08a775}.file-list button{border:0;background:transparent;color:#a0aec0}.spinning{animation:spin 1s linear infinite}
</style>



