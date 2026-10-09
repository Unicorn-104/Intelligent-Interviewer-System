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
          <span v-if="resume.fileName">已上传 {{ resume.fileName }}</span>
          <span v-else>尚未上传 PDF 简历</span>
          <button class="link-button" type="button" :disabled="uploading" @click="choosePdf">上传或替换 PDF</button>
          <input ref="pdfInput" type="file" accept="application/pdf,.pdf" hidden @change="handlePdfChange">
        </div>
      </section>

      <form @submit.prevent="saveResume">
        <section class="section">
          <div class="section-head"><h2>基本信息</h2><span>以下信息将同步至投递简历</span></div>
          <div class="section-body grid">
            <div class="field"><label>姓名</label><input v-model.trim="resume.realName" maxlength="50" required></div>
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
            <div class="field"><label>期望职位</label><input v-model.trim="resume.targetRole" maxlength="50" required></div>
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
              <div class="field"><label>学历</label><select v-model.number="education.degree"><option :value="3">本科</option><option :value="4">硕士</option><option :value="5">博士</option></select></div>
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
          <button class="primary" type="submit" :disabled="saving">{{ saving ? '保存中...' : '保存修改' }}</button>
        </div>
      </form>
    </template>
  </main>
  <div v-if="toastMessage" class="toast" role="status">{{ toastMessage }}</div>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { createResume, getResume, updateResume, uploadResumeFile } from '@/api/agent/resume'
import { validateResumeFile } from '@/utils/agentValidation'

const queryId = new URLSearchParams(window.location.search).get('id')
const resumeId = ref(queryId && queryId !== 'new' ? Number(queryId) : null)
const loading = ref(Boolean(resumeId.value))
const saving = ref(false)
const uploading = ref(false)
const errorMessage = ref('')
const toastMessage = ref('')
const skillInput = ref('')
const pdfInput = ref(null)
let localId = 0
let toastTimer

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
    educations: [],
    works: [],
    projects: [],
    skills: []
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
  } catch (error) {
    errorMessage.value = error?.message || '简历数据暂时无法读取'
  } finally {
    loading.value = false
  }
}

function applyResume(data) {
  Object.assign(resume, blankResume(), data || {})
  resume.educations = (data?.educations || []).map(item => ({ ...item, localId: `education-${++localId}` }))
  resume.works = (data?.works || []).map(item => ({ ...item, localId: `work-${++localId}` }))
  resume.projects = (data?.projects || []).map(item => ({ ...item, localId: `project-${++localId}` }))
  resume.skills = (data?.skills || []).map(item => ({ ...item, localId: `skill-${++localId}` }))
}

async function ensureResumeId() {
  if (resumeId.value) return resumeId.value
  const response = await createResume({
    resumeName: resume.resumeName.trim(),
    jobDirection: resume.jobDirection.trim()
  })
  resumeId.value = response.data?.id
  if (!resumeId.value) throw new Error('创建简历成功，但没有返回简历编号')
  return resumeId.value
}

async function saveResume() {
  if (saving.value) return
  if (!resume.resumeName.trim() || !resume.realName.trim() || !resume.targetRole.trim()) {
    showToast('请填写简历名称、姓名和期望职位')
    return
  }
  if (resume.skills.length > 30) {
    showToast('技能标签不能超过 30 个')
    return
  }
  saving.value = true
  try {
    const id = await ensureResumeId()
    const response = await updateResume(id, buildPayload())
    applyResume(response.data)
    showToast('简历已保存')
  } catch (error) {
    showToast(error?.message || '保存失败，请稍后重试')
  } finally {
    saving.value = false
  }
}

function buildPayload() {
  return {
    resumeName: resume.resumeName.trim(),
    jobDirection: resume.jobDirection.trim(),
    realName: resume.realName.trim(),
    gender: resume.gender,
    workStatus: resume.workStatus,
    currentCity: resume.currentCity.trim(),
    phone: resume.phone.trim(),
    email: resume.email.trim(),
    targetRole: resume.targetRole.trim(),
    salaryExpectation: resume.salaryExpectation.trim(),
    targetCity: resume.targetCity.trim(),
    arrivalTime: resume.arrivalTime,
    educations: resume.educations.map(({ localId, ...item }) => item),
    works: resume.works.map(({ localId, ...item }) => item),
    projects: resume.projects.map(({ localId, ...item }) => item),
    skills: resume.skills.map(({ localId, ...item }) => item)
  }
}

function choosePdf() {
  pdfInput.value?.click()
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
  uploading.value = true
  try {
    const id = await ensureResumeId()
    const response = await uploadResumeFile(id, file)
    applyResume(response.data)
    showToast('PDF 简历上传成功')
  } catch (error) {
    showToast(error?.message || 'PDF 简历上传失败，请稍后重试')
  } finally {
    uploading.value = false
  }
}

function addEducation() {
  resume.educations.push({ localId: `education-${++localId}`, school: '', major: '', degree: 3, startDate: '', endDate: '', description: '' })
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
:global(*){box-sizing:border-box}:global(body){margin:0;color:#172B4D;background:#F5F7FA;font-family:"PingFang SC","Microsoft YaHei",system-ui,sans-serif;font-size:14px}.main{width:min(1240px,calc(100% - 48px));margin:0 auto;padding:24px 0 105px}.breadcrumb{margin-bottom:12px;color:#96A3B5;font-size:11px}.breadcrumb a{color:#2B7FFF;text-decoration:none}.resume-overview,.section{border:1px solid #E5EAF1;border-radius:8px;background:#fff;box-shadow:0 5px 18px rgba(26,60,110,.045)}.resume-overview{display:grid;grid-template-columns:minmax(0,1fr) 320px 220px;align-items:center;gap:24px;padding:19px 22px}.resume-title-row{display:flex;align-items:center;gap:8px}.resume-title-input{width:min(380px,100%);padding:0;border:0;color:#1A3C6E;background:transparent;font-size:21px;font-weight:800}.resume-title-input:focus{outline:0;border-bottom:1px solid #2B7FFF}.resume-badge{padding:3px 7px;border-radius:4px;color:#2B7FFF;background:#EAF2FF;font-size:10px}.update-time{margin-top:6px;color:#96A3B5;font-size:10px}.progress-head{display:flex;justify-content:space-between;color:#6B7A90;font-size:10px}.progress-head strong{color:#2B7FFF;font-size:18px}.progress-track{height:7px;margin-top:8px;border-radius:99px;background:#E5ECF5}.progress-value{height:100%;border-radius:inherit;background:#2B7FFF;transition:width .2s}.progress-note{margin-top:7px;color:#96A3B5;font-size:9px}.usage{text-align:right;color:#96A3B5;font-size:10px}.usage strong{display:block;color:#16845B;font-size:11px}.usage span{display:block;margin-top:5px}.link-button{margin-top:7px;padding:0;border:0;color:#2B7FFF;background:transparent;font-size:10px;cursor:pointer}.section{margin-top:13px;overflow:hidden}.section-head{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:15px 20px 9px}.section-head h2{margin:0;color:#1A3C6E;font-size:15px}.section-head span{color:#96A3B5;font-size:10px}.section-body{padding:9px 20px 18px}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:13px}.grid.four{grid-template-columns:repeat(4,minmax(0,1fr))}.field.full{grid-column:1/-1}.field label{display:block;margin-bottom:5px;color:#586A81;font-size:10px}.field input,.field select,.field textarea{width:100%;min-height:37px;padding:8px 10px;border:1px solid #D7E0EC;border-radius:5px;color:#172B4D;background:#fff;font-size:11px}.field textarea{min-height:75px;resize:vertical}.field input:focus,.field select:focus,.field textarea:focus{border-color:#2B7FFF;outline:3px solid rgba(43,127,255,.1)}.entry{padding:13px 20px 17px;border-top:1px solid #EDF1F6;background:#FBFCFE}.entry-head{display:flex;justify-content:space-between;margin-bottom:9px;color:#96A3B5;font-size:10px}.remove-button{border:0;color:#CF3F4B;background:transparent;font-size:10px;cursor:pointer}.add-button{padding:4px 0;border:0;color:#2B7FFF;background:transparent;font-size:10px;cursor:pointer}.section-empty{padding:8px 20px 18px;color:#96A3B5;font-size:11px}.check-field{display:flex;align-items:center;gap:6px;align-self:end;min-height:37px;color:#586A81;font-size:10px}.check-field input{accent-color:#2B7FFF}.skill-wrap{display:flex;flex-wrap:wrap;gap:7px}.skill-tag{display:inline-flex;align-items:center;gap:5px;padding:5px 8px;border-radius:5px;color:#2B7FFF;background:#EAF2FF;font-size:10px}.skill-tag button{padding:0;border:0;color:inherit;background:transparent;cursor:pointer}.skill-add{display:flex;gap:8px;margin-top:12px}.skill-add input{width:min(280px,100%);height:36px;padding:0 10px;border:1px solid #D7E0EC;border-radius:5px}.primary,.secondary{height:38px;padding:0 16px;border-radius:6px;font-size:11px;font-weight:700;cursor:pointer}.primary{border:1px solid #2B7FFF;color:#fff;background:#2B7FFF}.primary:disabled,.secondary:disabled{cursor:not-allowed;opacity:.45}.secondary{border:1px solid #CBD9EA;color:#1A3C6E;background:#fff}.savebar{position:fixed;right:0;bottom:0;left:0;z-index:20;display:flex;justify-content:flex-end;gap:8px;padding:13px max(24px,calc((100% - 1240px) / 2));border-top:1px solid #E5EAF1;background:rgba(255,255,255,.97);backdrop-filter:blur(10px)}.savebar a{display:grid;place-items:center;text-decoration:none}.state{display:grid;place-items:center;gap:9px;min-height:250px;padding:30px;border:1px solid #E5EAF1;border-radius:8px;background:#fff;color:#6B7A90;text-align:center}.state strong{color:#1A3C6E;font-size:16px}.error-state{color:#CF3F4B}.toast{position:fixed;right:24px;bottom:80px;z-index:50;padding:11px 15px;border:1px solid #CDE7DD;border-radius:7px;color:#176B50;background:#F2FBF7}@media(max-width:900px){.main{width:calc(100% - 32px)}.resume-overview{grid-template-columns:1fr 1fr}.usage{grid-column:1/-1;text-align:left}.grid.four{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:620px){.main{width:calc(100% - 28px)}.resume-overview{grid-template-columns:1fr}.grid,.grid.four{grid-template-columns:1fr}.section-head,.section-body{padding-inline:14px}.entry{padding-inline:14px}.savebar{padding-inline:14px}.savebar button,.savebar a{flex:1}.skill-add{flex-direction:column}.skill-add input{width:100%}}
</style>
