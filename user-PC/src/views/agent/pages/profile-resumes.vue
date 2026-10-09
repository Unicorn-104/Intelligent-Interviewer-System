<template>
  <AgentTopbar active="" />
  <main class="main">
    <div class="breadcrumb">首页 / 账号功能 / 我的简历</div>
    <section class="page-head">
      <div>
        <h1>我的简历</h1>
        <p>管理不同求职方向的简历，投递时可以自由选择。</p>
      </div>
      <div class="head-actions">
        <button class="secondary" type="button" :disabled="uploading" @click="chooseNewFile">
          上传 PDF 简历
        </button>
        <button class="primary" type="button" @click="goEditor('new')">新建简历</button>
        <input ref="fileInput" type="file" accept="application/pdf,.pdf" hidden @change="handleFileChange">
      </div>
    </section>

    <div v-if="loading" class="state-panel">正在读取我的简历...</div>
    <div v-else-if="errorMessage" class="state-panel error-state">
      <strong>简历暂时无法读取</strong>
      <span>{{ errorMessage }}</span>
      <button class="secondary" type="button" @click="loadResumes">重新加载</button>
    </div>
    <div v-else-if="!resumes.length" class="state-panel empty-state">
      <span class="empty-icon">▤</span>
      <strong>还没有简历</strong>
      <span>新建简历或上传 PDF 后，投递岗位时就可以选择它。</span>
      <div class="empty-actions">
        <button class="secondary" type="button" @click="chooseNewFile">上传 PDF 简历</button>
        <button class="primary" type="button" @click="goEditor('new')">新建简历</button>
      </div>
    </div>
    <section v-else class="resume-list">
      <article v-for="resume in resumes" :key="resume.id" class="resume-card">
        <div class="resume-file-icon">PDF</div>
        <div class="resume-main">
          <div class="resume-title-row">
            <h2>{{ resume.name }}</h2>
            <span v-if="resume.isDefault" class="badge">默认简历</span>
          </div>
          <p class="resume-summary">{{ resume.jobDirection || '综合求职方向' }}</p>
          <div class="resume-meta">
            <span>完整度 {{ resume.completion || 0 }}%</span>
            <span>更新于 {{ formatDate(resume.updatedAt) }}</span>
            <span>已投递 {{ resume.usedApplicationCount || 0 }} 次</span>
            <span v-if="resume.fileName">{{ resume.fileName }} · {{ formatBytes(resume.fileSize) }}</span>
            <span v-else>尚未上传 PDF</span>
          </div>
          <div v-if="resume.fileUrl" class="file-link">
            <button class="file-link-button" type="button" :disabled="previewingId === resume.id" @click="previewResume(resume)">
              {{ previewingId === resume.id ? '正在打开...' : '查看 PDF' }}
            </button>
          </div>
        </div>
        <div class="resume-actions">
          <button class="icon-button" type="button" :disabled="uploading" title="上传或替换 PDF" @click="chooseExistingFile(resume.id)">
            ↥
          </button>
          <button class="text-button" type="button" @click="goEditor(resume.id)">编辑</button>
          <button class="text-button danger" type="button" @click="removeResume(resume)">删除</button>
        </div>
      </article>
    </section>

    <div v-if="resumes.length" class="list-foot">
      <span>最多可创建 10 份有效简历，当前已使用 {{ resumes.length }} 份</span>
      <a href="/agent/resume-select?job=1">体验投递选简历流程</a>
    </div>
  </main>
  <div v-if="toastMessage" class="toast" role="status">{{ toastMessage }}</div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import {
  createResume,
  deleteResume,
  downloadResumeFile,
  getResumes,
  uploadResumeFile
} from '@/api/agent/resume'
import { validateResumeFile } from '@/utils/agentValidation'

const resumes = ref([])
const loading = ref(false)
const uploading = ref(false)
const errorMessage = ref('')
const toastMessage = ref('')
const fileInput = ref(null)
const uploadTargetId = ref(null)
const previewingId = ref(null)
let toastTimer

async function loadResumes() {
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await getResumes()
    resumes.value = response.data || []
  } catch (error) {
    errorMessage.value = error?.message || '简历数据暂时无法读取'
  } finally {
    loading.value = false
  }
}

function chooseNewFile() {
  uploadTargetId.value = null
  fileInput.value?.click()
}

function chooseExistingFile(resumeId) {
  uploadTargetId.value = resumeId
  fileInput.value?.click()
}

async function handleFileChange(event) {
  const file = event.target.files?.[0]
  event.target.value = ''
  if (!file) return
  const validation = validateResumeFile(file)
  if (!validation.valid) {
    showToast(validation.message)
    return
  }

  uploading.value = true
  errorMessage.value = ''
  try {
    let resumeId = uploadTargetId.value
    if (!resumeId) {
      const name = file.name.replace(/\.pdf$/i, '').trim() || '我的 PDF 简历'
      const created = await createResume({ resumeName: name.slice(0, 100), jobDirection: '' })
      resumeId = created.data?.id
    }
    if (!resumeId) throw new Error('简历创建成功，但没有返回简历编号')
    await uploadResumeFile(resumeId, file)
    showToast('PDF 简历上传成功')
    await loadResumes()
  } catch (error) {
    errorMessage.value = error?.message || 'PDF 简历上传失败，请稍后重试'
  } finally {
    uploading.value = false
    uploadTargetId.value = null
  }
}

async function removeResume(resume) {
  if (!window.confirm(`确定删除“${resume.name}”吗？`)) return
  try {
    await deleteResume(resume.id)
    showToast('简历已删除')
    await loadResumes()
  } catch (error) {
    showToast(error?.message || '删除失败，请稍后重试')
  }
}

function goEditor(resumeId) {
  window.__agentNavigate(`/agent/resume-editor?id=${encodeURIComponent(resumeId)}`)
}

function formatDate(value) {
  return value ? String(value).slice(0, 10) : '最近更新'
}

function formatBytes(value) {
  const size = Number(value || 0)
  if (!size) return '大小未知'
  if (size < 1024 * 1024) return `${Math.max(1, Math.round(size / 1024))} KB`
  return `${(size / 1024 / 1024).toFixed(1)} MB`
}

async function previewResume(resume) {
  const previewWindow = window.open('', '_blank')
  if (!previewWindow) {
    showToast('浏览器阻止了新窗口，请允许弹窗后重试')
    return
  }

  previewingId.value = resume.id
  try {
    const resource = extractResource(resume.fileUrl)
    const data = await downloadResumeFile(resource)
    const pdf = new Blob([data], { type: 'application/pdf' })
    const objectUrl = URL.createObjectURL(pdf)
    previewWindow.location.href = objectUrl
    window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60 * 1000)
  } catch (error) {
    previewWindow.close()
    showToast(error?.message || '简历打开失败，请稍后重试')
  } finally {
    previewingId.value = null
  }
}

function extractResource(value) {
  const url = new URL(value, window.location.origin)
  return url.searchParams.get('resource') || value
}

function showToast(message) {
  toastMessage.value = message
  window.clearTimeout(toastTimer)
  toastTimer = window.setTimeout(() => {
    toastMessage.value = ''
  }, 2400)
}

onMounted(loadResumes)
</script>

<style scoped>
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}.main{width:min(1120px,calc(100% - 48px));margin:0 auto;padding:28px 0 60px}.breadcrumb{margin-bottom:12px;color:#96A3B5;font-size:11px}.page-head{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;margin-bottom:16px}.page-head h1{margin:0;color:#1A3C6E;font-size:25px}.page-head p{margin:6px 0 0;color:#6B7A90;font-size:12px}.head-actions,.empty-actions{display:flex;gap:8px}.primary,.secondary{height:38px;padding:0 15px;border-radius:6px;font-size:11px;font-weight:700;cursor:pointer}.primary{border:1px solid #2B7FFF;color:#fff;background:#2B7FFF}.primary:hover{background:#1D67D8}.secondary{border:1px solid #CBD9EA;color:#1A3C6E;background:#fff}.primary:disabled,.secondary:disabled,.icon-button:disabled,.file-link-button:disabled{cursor:not-allowed;opacity:.45}.resume-list{display:grid;gap:10px}.resume-card{display:grid;grid-template-columns:48px minmax(0,1fr) auto;align-items:center;gap:15px;padding:18px;border:1px solid #E5EAF1;border-radius:8px;background:#fff;box-shadow:0 6px 22px rgba(26,60,110,.055)}.resume-file-icon{width:46px;height:54px;display:grid;place-items:center;border:1px solid #BFD6F5;border-radius:6px;color:#2B7FFF;background:#F0F6FF;font-size:11px;font-weight:800}.resume-title-row{display:flex;align-items:center;gap:8px;flex-wrap:wrap}.resume-title-row h2{margin:0;color:#1A3C6E;font-size:15px}.badge{padding:3px 7px;border-radius:4px;color:#2B7FFF;background:#EAF2FF;font-size:10px}.resume-summary{margin:5px 0 0;color:#6B7A90;font-size:11px}.resume-meta{display:flex;flex-wrap:wrap;gap:5px 14px;margin-top:9px;color:#96A3B5;font-size:10px}.file-link{margin-top:8px;font-size:10px}.file-link a,.file-link-button,.list-foot a{color:#2B7FFF;text-decoration:none}.file-link-button{padding:0;border:0;background:transparent;font:inherit;cursor:pointer}.resume-actions{display:flex;align-items:center;gap:8px}.icon-button{width:32px;height:32px;border:1px solid #CBD9EA;border-radius:5px;color:#2B7FFF;background:#fff;font-size:16px;cursor:pointer}.text-button{border:0;color:#2B7FFF;background:transparent;font-size:11px;cursor:pointer}.text-button.danger{color:#CF3F4B}.list-foot{display:flex;justify-content:space-between;gap:12px;margin-top:12px;color:#96A3B5;font-size:10px}.state-panel{display:grid;place-items:center;gap:9px;min-height:250px;padding:30px;border:1px solid #E5EAF1;border-radius:8px;background:#fff;color:#6B7A90;text-align:center}.state-panel strong{color:#1A3C6E;font-size:16px}.error-state{color:#CF3F4B}.empty-icon{font-size:30px;color:#2B7FFF}.empty-actions{margin-top:6px}.toast{position:fixed;right:24px;bottom:24px;z-index:50;padding:11px 15px;border:1px solid #CDE7DD;border-radius:7px;color:#176B50;background:#F2FBF7}@media(max-width:700px){.main{width:calc(100% - 28px)}.page-head{display:block}.head-actions{margin-top:13px}.resume-card{grid-template-columns:40px minmax(0,1fr)}.resume-file-icon{width:38px;height:46px}.resume-actions{grid-column:2;justify-content:flex-start}.list-foot{display:block}.list-foot a{display:inline-block;margin-top:7px}}@media(max-width:460px){.head-actions button{flex:1}.resume-meta{display:grid}.empty-actions{width:100%}.empty-actions button{flex:1}}
</style>
