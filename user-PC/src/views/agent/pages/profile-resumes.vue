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
        <button class="secondary upload-resume-button" type="button" :disabled="uploading" @click="chooseNewFile">{{ uploading ? '上传中...' : '上传 PDF 简历' }}</button>
        <input ref="fileInput" type="file" accept="application/pdf,.pdf" hidden @change="handleFileChange">
        <button class="primary" type="button" @click="goEditor('new')">新建简历</button>
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
        <button class="secondary" type="button" :disabled="uploading" @click="chooseNewFile">{{ uploading ? '上传中...' : '上传 PDF 简历' }}</button>
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
          <div class="attachment-row">
            <span class="attachment-label">附件</span>
            <template v-if="resume.fileUrl">
              <button class="file-link-button" type="button" :disabled="previewingId === resume.id" @click="previewResume(resume)">
                <span class="attachment-icon">PDF</span>
                {{ previewingId === resume.id ? '正在打开...' : (resume.fileName || '原始 PDF 简历') }}
                <span class="attachment-size">{{ formatBytes(resume.fileSize) }}</span>
              </button>
            </template>
            <span v-else class="attachment-empty">暂无附件</span>
          </div>
        </div>
        <div class="resume-actions">
          <button class="attachment-action" type="button" title="编辑并添加附件" @click="goEditor(resume.id)">
            添加附件
          </button>
          <button class="text-button" type="button" @click="goEditor(resume.id)">编辑</button>
          <button class="text-button danger" type="button" :disabled="deletingId === resume.id" @click="removeResume(resume)">{{ deletingId === resume.id ? '删除中...' : '删除' }}</button>
        </div>
      </article>
    </section>

    <div v-if="resumes.length" class="list-foot">
      <span>最多可创建 10 份有效简历，当前已使用 {{ resumes.length }} 份</span>
      <a :href="appHref('/resume-select?job=1')">体验投递选简历流程</a>
    </div>
  </main>
  <div v-if="previewUrl" class="resume-preview-mask" role="dialog" aria-modal="true" :aria-label="`预览 ${previewName}`" @click.self="closePreview">
    <section class="resume-preview-panel">
      <header class="resume-preview-head">
        <strong>{{ previewName }}</strong>
        <button class="preview-close" type="button" aria-label="关闭简历预览" @click="closePreview">×</button>
      </header>
      <iframe class="resume-preview-frame" :src="previewUrl" :title="previewName"></iframe>
    </section>
  </div>
  <div v-if="toastMessage" class="toast" role="status">{{ toastMessage }}</div>
</template>

<script setup>
import { appHref } from '@/utils/agentNavigation'
import { onBeforeUnmount, onMounted, ref } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { deleteResume, getResumes, getResumeFile, importResumePdf, parseResumePdf } from '@/api/agent/resume'
import { validateResumeFile } from '@/utils/agentValidation'
import { getAppProfile } from '@/api/system/user'
import { mergeParsedResume, profileResumeDefaults } from '@/utils/agentResume'

const resumes = ref([])
const loading = ref(false)
const uploading = ref(false)
const fileInput = ref(null)
const errorMessage = ref('')
const toastMessage = ref('')
const previewingId = ref(null)
const previewUrl = ref('')
const previewName = ref('原始 PDF 简历')
const deletingId = ref(null)
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
  try {
    let defaults = {}
    try {
      const profile = await getAppProfile()
      defaults = profileResumeDefaults(profile.data || {})
    } catch {
      showToast('基础资料读取失败，将使用 PDF 识别信息，请上传后核对')
    }
    const parsed = await parseResumePdf(file)
    const data = mergeParsedResume(defaults, parsed.data || {})
    const response = await importResumePdf(null, buildImportedResume(data, file), file)
    if (!response.data?.id) throw new Error('简历上传成功，但没有返回简历编号')
    showToast('PDF 简历上传成功')
    await loadResumes()
  } catch (error) {
    showToast(error?.message || 'PDF 简历上传失败，请稍后重试')
  } finally {
    uploading.value = false
  }
}

function buildImportedResume(data, file) {
  const fallbackName = file.name.replace(/\.pdf$/i, '').trim() || '我的 PDF 简历'
  return {
    resumeName: String(data.resumeName || fallbackName).trim().slice(0, 100),
    jobDirection: String(data.jobDirection || '').trim(),
    realName: String(data.realName || '').trim(),
    gender: data.gender || '',
    workStatus: data.workStatus || '',
    currentCity: String(data.currentCity || '').trim(),
    phone: String(data.phone || '').trim(),
    email: String(data.email || '').trim(),
    targetRole: String(data.targetRole || '').trim(),
    salaryExpectation: String(data.salaryExpectation || '').trim(),
    targetCity: String(data.targetCity || '').trim(),
    arrivalTime: data.arrivalTime || '',
    educations: data.educations || [],
    works: data.works || [],
    projects: data.projects || [],
    skills: data.skills || []
  }
}
async function removeResume(resume) {
  if (deletingId.value) return
  if (!window.confirm(`确定删除“${resume.name}”吗？`)) return
  deletingId.value = resume.id
  try {
    await deleteResume(resume.id)
    showToast('简历已删除')
    await loadResumes()
  } catch (error) {
    showToast(error?.message || '删除失败，请稍后重试')
  } finally {
    deletingId.value = null
  }
}

function goEditor(resumeId) {
  window.__agentNavigate(`/resume-editor?id=${encodeURIComponent(resumeId)}`)
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
  previewingId.value = resume.id
  try {
    const data = await getResumeFile(resume.id)
    const pdf = new Blob([data], { type: 'application/pdf' })
    closePreview()
    previewUrl.value = URL.createObjectURL(pdf)
    previewName.value = resume.fileName || '原始 PDF 简历'
  } catch (error) {
    showToast(error?.message || '简历打开失败，请稍后重试')
  } finally {
    previewingId.value = null
  }
}

function closePreview() {
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value)
  previewUrl.value = ''
}

function showToast(message) {
  toastMessage.value = message
  window.clearTimeout(toastTimer)
  toastTimer = window.setTimeout(() => {
    toastMessage.value = ''
  }, 2400)
}

onMounted(loadResumes)
onBeforeUnmount(closePreview)
</script>

<style scoped>
.head-actions > button,.empty-actions > button{flex:0 0 auto;width:auto;margin:0;white-space:nowrap}
@media(max-width:460px){.head-actions > button,.empty-actions > button{flex:1 1 0;min-width:0;padding-inline:12px}}
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif}.main{width:min(1120px,calc(100% - 48px));margin:0 auto;padding:28px 0 60px}.breadcrumb{margin-bottom:12px;color:#96A3B5;font-size:11px}.page-head{display:flex;align-items:center;justify-content:space-between;gap:20px;margin-bottom:16px}.page-head h1{margin:0;color:#1A3C6E;font-size:25px}.page-head p{margin:6px 0 0;color:#6B7A90;font-size:12px}.head-actions,.empty-actions{display:flex;align-items:center;gap:8px}.primary,.secondary{display:inline-flex;align-items:center;justify-content:center;height:38px;min-height:38px;padding:0 15px;border-radius:6px;font-size:11px;font-weight:700;line-height:1;cursor:pointer}.primary{border:1px solid #2B7FFF;color:#fff;background:#2B7FFF}.primary:hover{background:#1D67D8}.secondary{border:1px solid #CBD9EA;color:#1A3C6E;background:#fff}.primary:disabled,.secondary:disabled,.icon-button:disabled,.file-link-button:disabled{cursor:not-allowed;opacity:.45}.resume-list{display:grid;gap:10px}.resume-card{display:grid;grid-template-columns:48px minmax(0,1fr) auto;align-items:center;gap:15px;padding:18px;border:1px solid #E5EAF1;border-radius:8px;background:#fff;box-shadow:0 6px 22px rgba(26,60,110,.055)}.resume-file-icon{width:46px;height:54px;display:grid;place-items:center;border:1px solid #BFD6F5;border-radius:6px;color:#2B7FFF;background:#F0F6FF;font-size:11px;font-weight:800}.resume-title-row{display:flex;align-items:center;gap:8px;flex-wrap:wrap}.resume-title-row h2{margin:0;color:#1A3C6E;font-size:15px}.badge{padding:3px 7px;border-radius:4px;color:#2B7FFF;background:#EAF2FF;font-size:10px}.resume-summary{margin:5px 0 0;color:#6B7A90;font-size:11px}.resume-meta{display:flex;flex-wrap:wrap;gap:5px 14px;margin-top:9px;color:#96A3B5;font-size:10px}.file-link{margin-top:8px;font-size:10px}.file-link a,.file-link-button,.list-foot a{color:#2B7FFF;text-decoration:none}.file-link-button{padding:0;border:0;background:transparent;font:inherit;cursor:pointer}.resume-actions{display:flex;align-items:center;gap:8px}.icon-button{width:32px;height:32px;border:1px solid #CBD9EA;border-radius:5px;color:#2B7FFF;background:#fff;font-size:16px;cursor:pointer}.text-button{border:0;color:#2B7FFF;background:transparent;font-size:11px;cursor:pointer}.text-button.danger{color:#CF3F4B}.list-foot{display:flex;justify-content:space-between;gap:12px;margin-top:12px;color:#96A3B5;font-size:10px}.state-panel{display:grid;place-items:center;gap:9px;min-height:250px;padding:30px;border:1px solid #E5EAF1;border-radius:8px;background:#fff;color:#6B7A90;text-align:center}.state-panel strong{color:#1A3C6E;font-size:16px}.error-state{color:#CF3F4B}.empty-icon{font-size:30px;color:#2B7FFF}.empty-actions{margin-top:6px}.toast{position:fixed;right:24px;bottom:24px;z-index:50;padding:11px 15px;border:1px solid #CDE7DD;border-radius:7px;color:#176B50;background:#F2FBF7}@media(max-width:700px){.main{width:calc(100% - 28px)}.page-head{display:block}.head-actions{margin-top:13px}.resume-card{grid-template-columns:40px minmax(0,1fr)}.resume-file-icon{width:38px;height:46px}.resume-actions{grid-column:2;justify-content:flex-start}.list-foot{display:block}.list-foot a{display:inline-block;margin-top:7px}}@media(max-width:460px){.head-actions button{flex:1}.resume-meta{display:grid}.empty-actions{width:100%}.empty-actions button{flex:1}}
.upload-resume-button{min-width:136px;flex:0 0 auto;padding-right:18px;padding-left:18px;white-space:nowrap}.attachment-row{display:flex;align-items:center;flex-wrap:wrap;gap:7px;margin-top:9px;color:#6B7A90;font-size:10px}.attachment-label,.attachment-empty{color:#96A3B5}.attachment-icon{display:inline-grid;width:22px;height:25px;margin-right:5px;place-items:center;border:1px solid #BFD6F5;border-radius:3px;color:#2B7FFF;background:#F0F6FF;font-size:7px;font-weight:800;vertical-align:middle}.attachment-size{margin-left:3px;color:#96A3B5}.file-link-button{padding:0;border:0;color:#2B7FFF;background:transparent;font:inherit;cursor:pointer;text-align:left}.attachment-action{height:32px;padding:0 10px;border:1px solid #CBD9EA;border-radius:5px;color:#2B7FFF;background:#fff;font-size:11px;white-space:nowrap;cursor:pointer}.attachment-action:hover{border-color:#2B7FFF;background:#F8FBFF}@media(max-width:460px){.upload-resume-button{min-width:0}}
.resume-preview-mask{position:fixed;inset:0;z-index:40;display:grid;place-items:center;padding:24px;background:rgba(23,43,77,.58)}.resume-preview-panel{display:flex;flex-direction:column;width:min(960px,100%);height:min(760px,100%);overflow:hidden;border-radius:10px;background:#fff;box-shadow:0 18px 50px rgba(23,43,77,.28)}.resume-preview-head{display:flex;align-items:center;justify-content:space-between;gap:12px;min-height:48px;padding:0 16px;border-bottom:1px solid #E5EAF1;color:#1A3C6E;font-size:13px}.preview-close{width:28px;height:28px;border:0;border-radius:5px;color:#6B7A90;background:#F3F6FA;font-size:22px;line-height:1;cursor:pointer}.resume-preview-frame{width:100%;height:100%;border:0;background:#F5F7FA}
</style>
