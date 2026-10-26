<template>
  <AgentTopbar active="" />
  <main class="main">
    <div class="breadcrumb"><a href="/agent/profile-resumes">我的简历</a> / 编辑简历</div>
    <div v-if="loading" class="state">正在读取简历...</div>
    <div v-else-if="errorMessage" class="state error-state">
      <strong>简历暂时无法读取</strong>
      <span>{{ errorMessage }}</span>
      <button class="secondary" type="button" @click="loadResume">重新加载</button>
    </div>
    <template v-else>
      <section class="resume-overview">
        <div>
          <div class="resume-title-row">
            <input v-model.trim="resume.resumeName" class="resume-title-input" maxlength="100" aria-label="简历名称">
            <span v-if="resume.isDefault" class="resume-badge">默认</span>
          </div>
          <div class="update-time">最近保存：{{ formatDate(resume.updatedAt) }}</div>
        </div>
        <div>
          <div class="progress-head"><span>简历完整度</span><strong>{{ resume.completion || 0 }}%</strong></div>
          <div class="progress-track"><div class="progress-value" :style="{ width: `${resume.completion || 0}%` }"></div></div>
          <div class="progress-note">完善项目成果与技能标签，可进一步提升完整度</div>
        </div>
        <div class="usage">
          <strong>● 已投递 {{ resume.usedApplicationCount || 0 }} 次</strong>
          <span v-if="parsing">正在扫描 PDF 并生成结构化简历...</span>
          <span v-else-if="pendingPdf">已解析 {{ pendingPdf.name }}，保存后将作为附件保留</span>
          <span v-else-if="resume.fileName">已上传 {{ resume.fileName }}</span>
          <span v-else>尚未上传 PDF 简历</span>
          <div class="usage-actions">
            <button v-if="pendingPdf || resume.fileUrl" class="link-button" type="button" :disabled="parsing || previewingPdf" @click="previewPdf">
              {{ previewingPdf ? '正在打开...' : '查看 PDF' }}
            </button>
          </div>
        </div>
      </section>
      <section class="attachment-panel">
        <div class="attachment-head">
          <div>
            <h2>简历附件</h2>
            <p>主 PDF 用于解析简历，其他材料可以一次添加多个附件。</p>
          </div>
          <div class="attachment-head-actions">
            <button class="secondary" type="button" :disabled="parsing || saving" @click="choosePdf">
              {{ parsing ? '解析中...' : '上传 PDF 简历' }}
            </button>
            <button class="secondary" type="button" :disabled="uploadingAttachments || saving || !resumeId" @click="chooseAttachments">
              {{ uploadingAttachments ? '上传中...' : '添加附件' }}
            </button>
          </div>
        </div>
        <div class="attachment-list">
          <div v-if="pendingPdf || resume.fileUrl" class="attachment-item">
            <div class="attachment-file-icon">PDF</div>
            <div class="attachment-file-main">
              <strong v-if="pendingPdf">{{ pendingPdf.name }}</strong>
              <strong v-else>{{ resume.fileName || '原始 PDF 简历' }}</strong>
              <span v-if="pendingPdf">已选择 {{ formatBytes(pendingPdf.size) }}，保存后替换主 PDF</span>
              <span v-else>主简历 PDF · {{ formatBytes(resume.fileSize) }}</span>
            </div>
            <button class="link-button" type="button" :disabled="parsing || previewingPdf" @click="previewPdf">
              {{ previewingPdf ? '正在打开...' : '查看 PDF' }}
            </button>
          </div>
          <div v-for="attachment in resume.attachments" :key="attachment.id" class="attachment-item">
            <div class="attachment-file-icon">{{ attachmentLabel(attachment.fileName) }}</div>
            <div class="attachment-file-main">
              <strong :title="attachment.fileName">{{ attachment.fileName }}</strong>
              <span>{{ formatBytes(attachment.fileSize) }} · {{ attachment.contentType || '附件' }}</span>
            </div>
            <div class="attachment-actions">
              <button class="link-button" type="button" :disabled="previewingAttachmentId === attachment.id" @click="previewAttachment(attachment)">
                {{ previewingAttachmentId === attachment.id ? '正在打开...' : '查看' }}
              </button>
              <button class="remove-button" type="button" :disabled="uploadingAttachments" @click="removeAttachment(attachment)">删除</button>
            </div>
          </div>
          <div v-if="!pendingPdf && !resume.fileUrl && !resume.attachments.length" class="attachment-empty-panel">
            暂无附件，可上传 PDF 简历或添加其他材料。
          </div>
        </div>
        <input ref="pdfInput" type="file" accept="application/pdf,.pdf" hidden @change="handlePdfChange">
        <input ref="attachmentInput" type="file" accept=".pdf,.doc,.docx,.jpg,.jpeg,.png" multiple hidden @change="handleAttachmentsChange">
      </section>
      <div v-if="resume.parseWarnings?.length" class="parse-warning">
        <strong>解析提示</strong>
        <span>{{ resume.parseWarnings.join('；') }}</span>
      </div>
      <section v-if="resume.unmappedText" class="unmapped-panel">
        <div class="unmapped-head">
          <strong>未自动归类的内容</strong>
          <span>以下内容仍保留在原 PDF 附件中，请核对后按需补充到结构化简历。</span>
        </div>
        <pre>{{ resume.unmappedText }}</pre>
      </section>

      <form novalidate @submit.prevent="saveResume">
        <section class="section">
          <div class="section-head"><h2>基本信息</h2><span>以下信息将同步至投递简历</span></div>
          <div class="section-body grid">
            <div class="field"><label>姓名</label><input v-model.trim="resume.realName" maxlength="50"></div>
            <div class="field"><label>性别</label><select v-model="resume.gender"><option value="">不公开</option><option value="女">女</option><option value="男">男</option></select></div>
            <div class="field"><label>当前状态</label><select v-model="resume.workStatus"><option value="">请选择</option><option>离职-随时到岗</option><option>在职-考虑机会</option><option>在校-寻找实习</option><option>暂不考虑</option></select></div>
            <div class="field"><label>所在城市</label><input v-model.trim="resume.currentCity" maxlength="50"></div>
            <div class="field"><label>手机号</label><input v-model.trim="resume.phone" maxlength="20" inputmode="tel"></div>
            <div class="field"><label>联系邮箱</label><input v-model.trim="resume.email" type="email" maxlength="100"></div>
          </div>
        </section>

        <section class="section">
          <div class="section-head"><h2>求职意向</h2><span>用于职位匹配与智能推荐</span></div>
          <div class="section-body grid">
            <div class="field"><label>求职方向</label><input v-model.trim="resume.jobDirection" maxlength="50"></div>
            <div class="field"><label>期望职位</label><input v-model.trim="resume.targetRole" maxlength="50"></div>
            <div class="field"><label>期望薪资</label><input v-model.trim="resume.salaryExpectation" maxlength="50" placeholder="例如：25-35K · 14薪"></div>
            <div class="field"><label>期望城市</label><input v-model.trim="resume.targetCity" maxlength="100"></div>
            <div class="field"><label>到岗时间</label><select v-model="resume.arrivalTime"><option value="">请选择</option><option>随时到岗</option><option>2 周内</option><option>1 个月内</option></select></div>
          </div>
        </section>

        <section class="section">
          <div class="section-head"><h2>教育经历</h2><button class="add-button" type="button" @click="addEducation">＋ 添加经历</button></div>
          <div v-if="!resume.educations.length" class="section-empty">暂未添加教育经历</div>
          <div v-for="(education, index) in resume.educations" :key="education.localId" class="entry">
            <div class="entry-head"><span>教育经历 {{ index + 1 }}</span><button class="remove-button" type="button" @click="removeItem(resume.educations, index)">删除</button></div>
            <div class="grid four">
              <div class="field"><label>学校</label><input v-model.trim="education.school" maxlength="100"></div>
              <div class="field"><label>专业</label><input v-model.trim="education.major" maxlength="50"></div>
              <div class="field"><label>学历</label><select v-model.number="education.degree"><option :value="3">本科</option><option :value="4">硕士</option><option :value="5">博士</option></select></div><div class="field"><label>绩点</label><input v-model.number="education.gpa" type="number" min="0" max="5" step="0.01" placeholder="可选"></div>
              <div class="field"><label>开始时间</label><input v-model="education.startDate" type="date"></div>
              <div class="field"><label>结束时间</label><input v-model="education.endDate" type="date"></div>
              <div class="field full"><label>补充说明</label><textarea v-model.trim="education.description" maxlength="500"></textarea></div>
            </div>
          </div>
        </section>

        <section class="section">
          <div class="section-head"><h2>工作经历</h2><button class="add-button" type="button" @click="addWork">＋ 添加经历</button></div>
          <div v-if="!resume.works.length" class="section-empty">暂未添加工作经历</div>
          <div v-for="(work, index) in resume.works" :key="work.localId" class="entry">
            <div class="entry-head"><span>工作经历 {{ index + 1 }}</span><button class="remove-button" type="button" @click="removeItem(resume.works, index)">删除</button></div>
            <div class="grid four">
              <div class="field"><label>公司</label><input v-model.trim="work.company" maxlength="100"></div>
              <div class="field"><label>职位</label><input v-model.trim="work.position" maxlength="50"></div>
              <div class="field"><label>开始时间</label><input v-model="work.startDate" type="date"></div>
              <div class="field"><label>结束时间</label><input v-model="work.endDate" type="date" :disabled="work.current"></div>
              <label class="check-field"><input v-model="work.current" type="checkbox">目前在职</label>
              <div class="field full"><label>工作描述</label><textarea v-model.trim="work.description" maxlength="2000" placeholder="描述职责与量化成果"></textarea></div>
            </div>
          </div>
        </section>

        <section class="section">
          <div class="section-head"><h2>项目经历</h2><button class="add-button" type="button" @click="addProject">＋ 添加项目</button></div>
          <div v-if="!resume.projects.length" class="section-empty">暂未添加项目经历</div>
          <div v-for="(project, index) in resume.projects" :key="project.localId" class="entry">
            <div class="entry-head"><span>项目经历 {{ index + 1 }}</span><button class="remove-button" type="button" @click="removeItem(resume.projects, index)">删除</button></div>
            <div class="grid four">
              <div class="field"><label>项目名称</label><input v-model.trim="project.name" maxlength="100"></div>
              <div class="field"><label>担任角色</label><input v-model.trim="project.role" maxlength="50"></div>
              <div class="field"><label>开始时间</label><input v-model="project.startDate" type="date"></div>
              <div class="field"><label>结束时间</label><input v-model="project.endDate" type="date"></div>
              <div class="field"><label>技术或工具</label><input v-model.trim="project.techStack" maxlength="200"></div>
              <div class="field full"><label>项目描述</label><textarea v-model.trim="project.description" maxlength="2000"></textarea></div>
            </div>
          </div>
        </section>

        <section class="section">
          <div class="section-head"><h2>技能标签</h2><span>最多添加 30 个</span></div>
          <div class="section-body">
            <div class="skill-wrap">
              <span v-for="(skill, index) in resume.skills" :key="skill.localId" class="skill-tag">
                {{ skill.name }} <button type="button" aria-label="删除技能" @click="removeItem(resume.skills, index)">×</button>
              </span>
            </div>
            <div class="skill-add"><input v-model.trim="skillInput" maxlength="50" placeholder="输入技能名称" @keydown.enter.prevent="addSkill"><button class="secondary" type="button" @click="addSkill">添加技能</button></div>
          </div>
        </section>

        <div class="savebar">
          <a class="secondary" href="/agent/profile-resumes">取消</a>
          <button class="primary" type="submit" :disabled="saving || parsing">{{ saving ? '保存中...' : '保存修改' }}</button>
        </div>
      </form>
    </template>
  </main>
  <div v-if="toastMessage" class="toast" role="status">{{ toastMessage }}</div>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { createResume, deleteResumeAttachment, getResume, getResumeAttachmentFile, getResumeAttachments, getResumeFile, importResumePdf, parseResumePdf, updateResume, uploadResumeAttachments } from '@/api/agent/resume'
import { validateResumeAttachment, validateResumeFile } from '@/utils/agentValidation'

const queryId = new URLSearchParams(window.location.search).get('id')
const resumeId = ref(queryId && queryId !== 'new' ? Number(queryId) : null)
const loading = ref(Boolean(resumeId.value))
const saving = ref(false)
const parsing = ref(false)
const previewingPdf = ref(false)
const pendingPdf = ref(null)
const errorMessage = ref('')
const toastMessage = ref('')
const skillInput = ref('')
const pdfInput = ref(null)
const attachmentInput = ref(null)
const uploadingAttachments = ref(false)
const previewingAttachmentId = ref(null)
let localId = 0
let toastTimer

const resumeTextFields = ['resumeName', 'jobDirection', 'realName', 'gender', 'workStatus', 'currentCity', 'phone', 'email', 'targetRole', 'salaryExpectation', 'targetCity', 'arrivalTime']

function toText(value) {
  return value == null ? '' : String(value)
}

function normalizeEntry(item, fields, idPrefix) {
  const normalized = { ...(item || {}), localId: `${idPrefix}-${++localId}` }
  fields.forEach(field => {
    normalized[field] = toText(normalized[field])
  })
  return normalized
}

function blankResume() {
  return {
    id: null,
    resumeName: '我的简历',
    jobDirection: '',
    realName: '',
    gender: '',
    workStatus: '',
    currentCity: '',
    phone: '',
    email: '',
    targetRole: '',
    salaryExpectation: '',
    targetCity: '',
    arrivalTime: '',
    isDefault: false,
    completion: 0,
    usedApplicationCount: 0,
    updatedAt: '',
    fileName: '',
    fileSize: 0,
    fileUrl: '',
    parseMethod: '',
    structureMethod: '',
    unmappedText: '',
    parseWarnings: [],
    educations: [],
    works: [],
    projects: [],
    skills: [],
    attachments: []
  }
}

const resume = reactive(blankResume())

async function loadResume() {
  if (!resumeId.value) {
    loading.value = false
    return
  }
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await getResume(resumeId.value)
    applyResume(response.data)
    await loadAttachments()
  } catch (error) {
    errorMessage.value = error?.message || '简历数据暂时无法读取'
  } finally {
    loading.value = false
  }
}

function applyResume(data) {
  const next = data || {}
  Object.assign(resume, blankResume(), next, {
    parseWarnings: Array.isArray(next.parseWarnings) ? next.parseWarnings : [],
    unmappedText: next.unmappedText || '',
    attachments: Array.isArray(next.attachments) ? next.attachments : []
  })
  resumeTextFields.forEach(field => {
    resume[field] = toText(resume[field])
  })
  resume.unmappedText = toText(resume.unmappedText)
  resume.educations = (data?.educations || []).map(item => normalizeEntry(item, ['school', 'major', 'description', 'startDate', 'endDate'], 'education'))
  resume.works = (data?.works || []).map(item => normalizeEntry(item, ['company', 'position', 'department', 'startDate', 'endDate', 'salaryRange', 'description'], 'work'))
  resume.projects = (data?.projects || []).map(item => normalizeEntry(item, ['name', 'role', 'startDate', 'endDate', 'techStack', 'description'], 'project'))
  resume.skills = (data?.skills || []).map(item => normalizeEntry(item, ['name'], 'skill'))
}

async function ensureResumeId() {
  if (resumeId.value) return resumeId.value
  const response = await createResume({
    resumeName: toText(resume.resumeName).trim(),
    jobDirection: toText(resume.jobDirection).trim()
  })
  resumeId.value = response.data?.id
  resume.id = resumeId.value
  if (!resumeId.value) throw new Error('创建简历成功，但没有返回简历编号')
  return resumeId.value
}

async function saveResume() {
  if (saving.value || parsing.value) return
  if (!toText(resume.resumeName).trim()) {
    showToast('请填写简历名称')
    return
  }
  if (resume.skills.length > 30) {
    showToast('技能标签不能超过 30 个')
    return
  }
  if (resume.educations.some(item => !String(item.school || '').trim()) ||
      resume.works.some(item => !String(item.company || '').trim() || !String(item.position || '').trim()) ||
      resume.projects.some(item => !String(item.name || '').trim()) ||
      resume.skills.some(item => !String(item.name || '').trim())) {
    showToast('请补全教育、工作、项目或技能中的必填信息')
    return
  }
  saving.value = true
  try {
    const payload = buildPayload()
    const response = pendingPdf.value
      ? await importResumePdf(resumeId.value, payload, pendingPdf.value)
      : await updateResume(await ensureResumeId(), payload)
    resumeId.value = response.data?.id || resumeId.value
    pendingPdf.value = null
    applyResume({ ...(response.data || {}), attachments: resume.attachments })
    await loadAttachments()
    showToast('简历及附件已保存')
  } catch (error) {
    showToast(error?.message || '保存失败，请稍后重试')
  } finally {
    saving.value = false
  }
}

function buildPayload() {
  return {
    resumeName: toText(resume.resumeName).trim(),
    jobDirection: toText(resume.jobDirection).trim(),
    realName: toText(resume.realName).trim(),
    gender: toText(resume.gender).trim(),
    workStatus: toText(resume.workStatus).trim(),
    currentCity: toText(resume.currentCity).trim(),
    phone: toText(resume.phone).trim(),
    email: toText(resume.email).trim(),
    targetRole: toText(resume.targetRole).trim(),
    salaryExpectation: toText(resume.salaryExpectation).trim(),
    targetCity: toText(resume.targetCity).trim(),
    arrivalTime: toText(resume.arrivalTime).trim(),
    educations: resume.educations.map(item => buildEntryPayload(item, ['school', 'major', 'description', 'startDate', 'endDate'])),
    works: resume.works.map(item => buildEntryPayload(item, ['company', 'position', 'department', 'startDate', 'endDate', 'salaryRange', 'description'])),
    projects: resume.projects.map(item => buildEntryPayload(item, ['name', 'role', 'startDate', 'endDate', 'techStack', 'description'])),
    skills: resume.skills.map(item => buildEntryPayload(item, ['name']))
  }
}

function buildEntryPayload(item, fields) {
  const { localId, ...payload } = item || {}
  fields.forEach(field => {
    payload[field] = toText(payload[field]).trim()
  })
  return payload
}
function choosePdf() {
  pdfInput.value?.click()
}

function chooseAttachments() {
  if (!resumeId.value) {
    showToast('请先保存简历后再添加附件')
    return
  }
  attachmentInput.value?.click()
}

async function previewPdf() {
  if (previewingPdf.value) return
  const previewWindow = window.open('', '_blank')
  if (!previewWindow) {
    showToast('浏览器阻止了新窗口，请允许弹窗后重试')
    return
  }
  previewingPdf.value = true
  let objectUrl = ''
  try {
    const data = pendingPdf.value || await getResumeFile(resume.id)
    const pdf = data instanceof Blob ? data : new Blob([data], { type: 'application/pdf' })
    objectUrl = URL.createObjectURL(pdf)
    previewWindow.location.href = objectUrl
    window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60 * 1000)
  } catch (error) {
    previewWindow.close()
    showToast(error?.message || '简历打开失败，请稍后重试')
  } finally {
    previewingPdf.value = false
  }
}

async function handlePdfChange(event) {
  const file = event.target.files?.[0]
  event.target.value = ''
  if (!file) return
  const validation = validateResumeFile(file)
  if (!validation.valid) {
    showToast(validation.message)
    return
  }
  parsing.value = true
  try {
    const response = await parseResumePdf(file)
    applyParsedDraft(response.data, file)
    showToast('PDF 已解析，请核对内容后保存')
  } catch (error) {
    showToast(error?.message || 'PDF 解析失败，请稍后重试')
  } finally {
    parsing.value = false
  }
}

function applyParsedDraft(data, file) {
  const fallbackName = file.name.replace(/\.pdf$/i, '').trim() || '我的简历'
  const preserved = {
    id: resume.id,
    resumeName: toText(resume.resumeName).trim() || toText(data?.resumeName).trim() || fallbackName,
    realName: resume.realName,
    gender: resume.gender,
    workStatus: resume.workStatus,
    currentCity: resume.currentCity,
    phone: resume.phone,
    email: resume.email,
    targetRole: resume.targetRole,
    salaryExpectation: resume.salaryExpectation,
    targetCity: resume.targetCity,
    arrivalTime: resume.arrivalTime,
    isDefault: resume.isDefault,
    usedApplicationCount: resume.usedApplicationCount,
    updatedAt: resume.updatedAt,
    fileUrl: resume.fileUrl,
    attachments: resume.attachments
  }
  applyResume({ ...data, ...preserved, fileName: file.name, fileSize: file.size })
  pendingPdf.value = file
}

function addEducation() {
  resume.educations.push({ localId: `education-${++localId}`, school: '', major: '', degree: 3, gpa: null, startDate: '', endDate: '', description: '' })
}

function addWork() {
  resume.works.push({ localId: `work-${++localId}`, company: '', position: '', startDate: '', endDate: '', current: false, salaryRange: '', description: '' })
}

function addProject() {
  resume.projects.push({ localId: `project-${++localId}`, name: '', role: '', startDate: '', endDate: '', description: '', techStack: '' })
}

function addSkill() {
  const name = skillInput.value.trim()
  if (!name || resume.skills.some(item => item.name === name)) return
  if (resume.skills.length >= 30) {
    showToast('技能标签不能超过 30 个')
    return
  }
  resume.skills.push({ localId: `skill-${++localId}`, name, level: 2 })
  skillInput.value = ''
}

function removeItem(list, index) {
  list.splice(index, 1)
}

function formatDate(value) {
  return value ? String(value).slice(0, 10) : '尚未保存'
}

async function loadAttachments() {
  if (!resumeId.value) return
  const response = await getResumeAttachments(resumeId.value)
  resume.attachments = response.data || []
}

async function handleAttachmentsChange(event) {
  const files = Array.from(event.target.files || [])
  event.target.value = ''
  if (!files.length) return
  for (const file of files) {
    const validation = validateResumeAttachment(file)
    if (!validation.valid) {
      showToast(validation.message)
      return
    }
  }
  uploadingAttachments.value = true
  try {
    const response = await uploadResumeAttachments(resumeId.value, files)
    resume.attachments = response.data || []
    showToast(`已添加 ${files.length} 个附件`)
  } catch (error) {
    showToast(error?.message || '附件上传失败，请稍后重试')
  } finally {
    uploadingAttachments.value = false
  }
}

async function previewAttachment(attachment) {
  if (previewingAttachmentId.value) return
  const previewWindow = window.open('', '_blank')
  if (!previewWindow) {
    showToast('浏览器阻止了新窗口，请允许弹窗后重试')
    return
  }
  previewingAttachmentId.value = attachment.id
  try {
    const data = await getResumeAttachmentFile(resume.id, attachment.id)
    const blob = data instanceof Blob ? data : new Blob([data], { type: attachment.contentType || 'application/octet-stream' })
    const objectUrl = URL.createObjectURL(blob)
    previewWindow.location.href = objectUrl
    window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60 * 1000)
  } catch (error) {
    previewWindow.close()
    showToast(error?.message || '附件打开失败，请稍后重试')
  } finally {
    previewingAttachmentId.value = null
  }
}

async function removeAttachment(attachment) {
  if (uploadingAttachments.value) return
  try {
    const response = await deleteResumeAttachment(resume.id, attachment.id)
    resume.attachments = response.data || []
    showToast('附件已删除')
  } catch (error) {
    showToast(error?.message || '附件删除失败，请稍后重试')
  }
}

function attachmentLabel(fileName) {
  const extension = String(fileName || '').split('.').pop().toUpperCase()
  return extension.length <= 4 ? extension : 'FILE'
}

function formatBytes(value) {
  const size = Number(value || 0)
  if (!size) return '大小未知'
  if (size < 1024 * 1024) return `${Math.max(1, Math.round(size / 1024))} KB`
  return `${(size / 1024 / 1024).toFixed(1)} MB`
}

function showToast(message) {
  toastMessage.value = message
  window.clearTimeout(toastTimer)
  toastTimer = window.setTimeout(() => {
    toastMessage.value = ''
  }, 2600)
}

onMounted(loadResume)
</script>

<style scoped>
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif;font-size:14px}.main{width:min(1240px,calc(100% - 48px));margin:0 auto;padding:24px 0 105px}.breadcrumb{margin-bottom:12px;color:#96A3B5;font-size:11px}.breadcrumb a{color:#2B7FFF;text-decoration:none}.resume-overview,.section{border:1px solid #E5EAF1;border-radius:8px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045)}.resume-overview{display:grid;grid-template-columns:minmax(0,1fr) 320px 220px;align-items:center;gap:24px;padding:19px 22px}.resume-title-row{display:flex;align-items:center;gap:8px}.resume-title-input{width:min(380px,100%);padding:0;border:0;color:#1A3C6E;background:transparent;font-size:21px;font-weight:800}.resume-title-input:focus{outline:0;border-bottom:1px solid #2B7FFF}.resume-badge{padding:3px 7px;border-radius:4px;color:#2B7FFF;background:#EAF2FF;font-size:10px}.update-time{margin-top:6px;color:#96A3B5;font-size:10px}.progress-head{display:flex;justify-content:space-between;color:#6B7A90;font-size:10px}.progress-head strong{color:#2B7FFF;font-size:18px}.progress-track{height:7px;margin-top:8px;border-radius:99px;background:#E5ECF5}.progress-value{height:100%;border-radius:inherit;background:#2B7FFF;transition:width .2s}.progress-note{margin-top:7px;color:#96A3B5;font-size:9px}.parse-warning{display:flex;gap:8px;align-items:flex-start;margin-top:10px;padding:10px 14px;border:1px solid #F0D9A8;border-radius:6px;color:#8A621D;background:#FFF9EC;font-size:11px}.parse-warning strong{white-space:nowrap}.usage{text-align:right;color:#96A3B5;font-size:10px}.usage strong{display:block;color:#16845B;font-size:11px}.usage span{display:block;margin-top:5px}.link-button{margin-top:7px;padding:0;border:0;color:#2B7FFF;background:transparent;font-size:10px;cursor:pointer}.section{margin-top:13px;overflow:hidden}.section-head{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:15px 20px 9px}.section-head h2{margin:0;color:#1A3C6E;font-size:15px}.section-head span{color:#96A3B5;font-size:10px}.section-body{padding:9px 20px 18px}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:13px}.grid.four{grid-template-columns:repeat(4,minmax(0,1fr))}.field.full{grid-column:1/-1}.field label{display:block;margin-bottom:5px;color:#586A81;font-size:10px}.field input,.field select,.field textarea{width:100%;min-height:37px;padding:8px 10px;border:1px solid #D7E0EC;border-radius:5px;color:#172B4D;background:#fff;font-size:11px}.field textarea{min-height:75px;resize:vertical}.field input:focus,.field select:focus,.field textarea:focus{border-color:#2B7FFF;outline:3px solid rgba(43,127,255,.1)}.entry{padding:13px 20px 17px;border-top:1px solid #EDF1F6;background:#FBFCFE}.entry-head{display:flex;justify-content:space-between;margin-bottom:9px;color:#96A3B5;font-size:10px}.remove-button{border:0;color:#CF3F4B;background:transparent;font-size:10px;cursor:pointer}.add-button{padding:4px 0;border:0;color:#2B7FFF;background:transparent;font-size:10px;cursor:pointer}.section-empty{padding:8px 20px 18px;color:#96A3B5;font-size:11px}.check-field{display:flex;align-items:center;gap:6px;align-self:end;min-height:37px;color:#586A81;font-size:10px}.check-field input{accent-color:#2B7FFF}.skill-wrap{display:flex;flex-wrap:wrap;gap:7px}.skill-tag{display:inline-flex;align-items:center;gap:5px;padding:5px 8px;border-radius:5px;color:#2B7FFF;background:#EAF2FF;font-size:10px}.skill-tag button{padding:0;border:0;color:inherit;background:transparent;cursor:pointer}.skill-add{display:flex;gap:8px;margin-top:12px}.skill-add input{width:min(280px,100%);height:36px;padding:0 10px;border:1px solid #D7E0EC;border-radius:5px}.primary,.secondary{height:38px;padding:0 16px;border-radius:6px;font-size:11px;font-weight:700;cursor:pointer}.primary{border:1px solid #2B7FFF;color:#fff;background:#2B7FFF}.primary:disabled,.secondary:disabled{cursor:not-allowed;opacity:.45}.secondary{border:1px solid #CBD9EA;color:#1A3C6E;background:#fff}.savebar{position:fixed;right:0;bottom:0;left:0;z-index:20;display:flex;justify-content:flex-end;gap:8px;padding:13px max(24px,calc((100% - 1240px) / 2));border-top:1px solid #E5EAF1;background:rgba(255,255,255,.97);backdrop-filter:blur(10px)}.savebar a{display:grid;place-items:center;text-decoration:none}.state{display:grid;place-items:center;gap:9px;min-height:250px;padding:30px;border:1px solid #E5EAF1;border-radius:8px;background:#fff;color:#6B7A90;text-align:center}.state strong{color:#1A3C6E;font-size:16px}.error-state{color:#CF3F4B}.toast{position:fixed;right:24px;bottom:80px;z-index:50;max-width:min(520px,calc(100vw - 48px));padding:11px 15px;overflow-wrap:anywhere;border:1px solid #CDE7DD;border-radius:7px;color:#176B50;background:#F2FBF7}@media(max-width:900px){.main{width:calc(100% - 32px)}.resume-overview{grid-template-columns:1fr 1fr}.usage{grid-column:1/-1;text-align:left}.grid.four{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:620px){.main{width:calc(100% - 28px)}.resume-overview{grid-template-columns:1fr}.grid,.grid.four{grid-template-columns:1fr}.section-head,.section-body{padding-inline:14px}.entry{padding-inline:14px}.savebar{padding-inline:14px}.savebar button,.savebar a{flex:1}.skill-add{flex-direction:column}.skill-add input{width:100%}}
 .usage-actions{display:flex;justify-content:flex-end;gap:10px}.unmapped-panel{margin-top:10px;padding:12px 14px;border:1px solid #D8E5F5;border-radius:6px;background:#F7FAFE;color:#586A81;font-size:11px}.unmapped-head{display:flex;flex-direction:column;gap:4px}.unmapped-head strong{color:#1A3C6E}.unmapped-head span{color:#7A8AA0}.unmapped-panel pre{max-height:180px;margin:10px 0 0;padding:10px;overflow:auto;border-radius:5px;white-space:pre-wrap;word-break:break-word;color:#3D506B;background:#fff;font:inherit;line-height:1.6}
.attachment-panel{margin-top:13px;padding:16px 20px;border:1px solid #E5EAF1;border-radius:8px;background:#fff;box-shadow:0 6px 22px rgba(26,60,110,.04)}.attachment-head{display:flex;align-items:center;justify-content:space-between;gap:16px}.attachment-head h2{margin:0;color:#1A3C6E;font-size:15px}.attachment-head p{margin:5px 0 0;color:#96A3B5;font-size:10px}.attachment-item{display:flex;align-items:center;gap:12px;margin-top:13px;padding:12px;border:1px solid #E7EDF5;border-radius:6px;background:#F8FAFD}.attachment-file-icon{display:grid;width:40px;height:46px;place-items:center;flex:0 0 auto;border:1px solid #BFD6F5;border-radius:5px;color:#2B7FFF;background:#F0F6FF;font-size:10px;font-weight:800}.attachment-file-main{display:flex;min-width:0;flex:1;flex-direction:column;gap:4px}.attachment-file-main strong{overflow:hidden;color:#1A3C6E;font-size:11px;text-overflow:ellipsis;white-space:nowrap}.attachment-file-main span{color:#96A3B5;font-size:10px}.attachment-item .link-button{margin-top:0;white-space:nowrap}@media(max-width:900px){.attachment-head{align-items:flex-start}.attachment-item{align-items:flex-start}}@media(max-width:620px){.attachment-panel{padding:14px}.attachment-head{display:block}.attachment-head .secondary{width:100%;margin-top:10px}}
.attachment-head-actions{display:flex;gap:8px;flex-wrap:wrap}.attachment-list{display:grid;gap:8px}.attachment-actions{display:flex;align-items:center;gap:10px;flex:0 0 auto}.attachment-empty-panel{padding:14px;border:1px dashed #D7E0EC;border-radius:6px;color:#96A3B5;background:#FBFCFE;font-size:11px}.attachment-item .remove-button{white-space:nowrap}.attachment-item .link-button{margin-top:0}.attachment-file-icon{overflow:hidden;max-width:48px;white-space:nowrap;text-overflow:ellipsis;text-align:center}@media(max-width:620px){.attachment-head-actions{display:grid;grid-template-columns:1fr}.attachment-head-actions button{width:100%}.attachment-item{align-items:flex-start;flex-wrap:wrap}.attachment-actions{width:100%;padding-left:52px}.attachment-file-main{min-width:calc(100% - 60px)}}</style>
