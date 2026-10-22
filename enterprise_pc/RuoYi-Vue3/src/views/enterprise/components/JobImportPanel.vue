<script setup>
import { computed, onMounted, ref } from 'vue'
import { AlertTriangle, ChevronRight, CircleCheck, CloudUpload, FileText, RotateCw, Sparkles, Trash2 } from '@/views/enterprise/components/icons'
import JobContentFields from './JobContentFields.vue'
import { createJob, listJobs, parseJdDocument, updateJob } from '@/api/system/job'

const emit = defineEmits(['done'])

// 与后端 /enterprise/jd/parse-document 的校验口径保持一致
const MAX_SIZE = 10 * 1024 * 1024
const MAX_FILES = 10
const EXTENSIONS = ['.pdf', '.docx']
const REQUIRED_FIELDS = [
  { key: 'title', label: '岗位名称' }, { key: 'dept', label: '所属部门' }, { key: 'city', label: '工作城市' },
  { key: 'responsibilities', label: '工作职责' }, { key: 'requirements', label: '任职要求' }
]
const SUGGESTED_FIELDS = [
  { key: 'salary', label: '薪资范围' }, { key: 'experience', label: '经验要求' },
  { key: 'education', label: '学历要求' }, { key: 'description', label: '岗位概述' }
]

const phase = ref('upload')
const parsing = ref(false)
const submitting = ref(false)
const tip = ref('')
const files = ref([])
const existingJobs = ref([])
const totals = ref({ created: 0, updated: 0, failed: 0 })
let keySeed = 0

const parseTargets = computed(() => files.value.filter(f => f.status === 'pending' || f.status === 'error'))
const parsedFiles = computed(() => files.value.filter(f => f.status === 'done'))
const importTargets = computed(() => parsedFiles.value.filter(f => f.action !== 'skip' && !f.imported))
const skippedCount = computed(() => parsedFiles.value.filter(f => f.action === 'skip').length)

function text(value) { return value == null ? '' : String(value).trim() }
function lines(value) { return text(value).split('\n').map(s => s.trim()).filter(Boolean) }
function sameText(a, b) { return text(a).toLowerCase() === text(b).toLowerCase() }

function fromDraft(draft) {
  return {
    title: text(draft.title), dept: text(draft.dept), city: text(draft.city),
    salaryMin: draft.salaryMin == null ? '' : draft.salaryMin,
    salaryMax: draft.salaryMax == null ? '' : draft.salaryMax,
    experience: text(draft.experience),
    education: draft.education == null ? null : draft.education,
    jobType: draft.jobType == null ? 1 : draft.jobType,
    description: text(draft.summary),
    responsibilities: (draft.responsibilities || []).join('\n'),
    requirements: (draft.requirements || []).join('\n')
  }
}

function statusText(file) {
  return { done: '已解析', parsing: '解析中', error: '解析失败', invalid: '不可解析' }[file.status] || '待解析'
}

function addFiles(list) {
  let overflow = false
  list.forEach(raw => {
    if (files.value.length >= MAX_FILES) { overflow = true; return }
    const name = raw.name.toLowerCase()
    const item = { key: ++keySeed, name: raw.name, raw, status: 'pending', message: '', imported: false, action: 'create', match: null, warnings: [], skills: [], form: fromDraft({}) }
    if (!EXTENSIONS.some(ext => name.endsWith(ext))) { item.status = 'invalid'; item.message = '仅支持 .pdf / .docx 格式' }
    else if (raw.size > MAX_SIZE) { item.status = 'invalid'; item.message = '文件超过 10MB' }
    files.value.push(item)
  })
  tip.value = overflow ? `一次最多上传 ${MAX_FILES} 个文件` : ''
}

function onPick(event) {
  addFiles(Array.from(event.target.files || []))
  event.target.value = ''
}

function onDrop(event) { addFiles(Array.from(event.dataTransfer.files || [])) }

function remove(index) { files.value.splice(index, 1); tip.value = '' }

function refreshMatch(item) {
  const title = text(item.form.title)
  const hit = title ? existingJobs.value.find(job => sameText(job.title, title) && sameText(job.dept, item.form.dept)) : null
  item.match = hit || null
  item.action = hit && item.action !== 'overwrite' ? 'skip' : hit ? 'overwrite' : 'create'
}

function isFilled(item, key) {
  const form = item.form
  if (key === 'salary') return form.salaryMin !== '' && form.salaryMin != null && form.salaryMax !== '' && form.salaryMax != null
  if (key === 'education') return form.education != null
  return text(form[key]) !== ''
}

function missingFields(item) { return REQUIRED_FIELDS.filter(field => !isFilled(item, field.key)).map(field => field.label) }
function suggestedFields(item) { return SUGGESTED_FIELDS.filter(field => !isFilled(item, field.key)).map(field => field.label) }
function scoreOf(item) {
  const all = REQUIRED_FIELDS.concat(SUGGESTED_FIELDS)
  return Math.round(all.filter(field => isFilled(item, field.key)).length / all.length * 100)
}

async function loadExistingJobs() {
  try {
    const res = await listJobs({ pageNum: 1, pageSize: 200 })
    existingJobs.value = (res.rows || []).map(row => ({ id: row.posId, title: text(row.title), dept: text(row.dept) }))
  } catch (e) { existingJobs.value = [] }
}

async function startParse() {
  const targets = parseTargets.value
  if (!targets.length) { tip.value = '请先选择需要解析的 JD 文件'; return }
  tip.value = ''
  totals.value = { created: 0, updated: 0, failed: 0 }
  parsing.value = true
  for (const item of targets) {
    item.status = 'parsing'
    item.message = ''
    try {
      const res = await parseJdDocument(item.raw)
      const draft = res.data || {}
      item.form = fromDraft(draft)
      item.warnings = draft.warnings || []
      item.skills = draft.skills || []
      item.status = 'done'
      item.imported = false
      refreshMatch(item)
    } catch (e) {
      item.status = 'error'
      item.message = (e && e.message) || '解析失败，请重试'
    }
  }
  parsing.value = false
  if (parsedFiles.value.length) phase.value = 'preview'
  else tip.value = '没有文件解析成功，请检查文档内容后重试'
}

function validate(item) {
  const form = item.form
  if (!text(form.title)) return '请填写岗位名称'
  if (!text(form.dept)) return '请填写所属部门'
  if (!text(form.city)) return '请填写工作城市'
  const duties = lines(form.responsibilities)
  const demands = lines(form.requirements)
  if (!duties.length) return '请至少填写一条工作职责'
  if (!demands.length) return '请至少填写一条任职要求'
  if (duties.length > 30 || demands.length > 30) return '工作职责与任职要求最多各 30 条'
  if (text(form.experience).length > 20) return '经验要求最多 20 个字'
  const min = form.salaryMin === '' ? null : Number(form.salaryMin)
  const max = form.salaryMax === '' ? null : Number(form.salaryMax)
  if ((min == null) !== (max == null)) return '薪资范围需同时填写最低与最高月薪'
  if (min != null && (min <= 0 || max <= 0 || min > max || max >= 100000000)) return '薪资范围不合法，请填写正确的元/月数值'
  return ''
}

async function submitAll() {
  const targets = importTargets.value
  if (!targets.length) { tip.value = '请至少选择一个需要导入的岗位'; return }
  for (const item of targets) {
    const message = validate(item)
    if (message) { tip.value = `${item.name}：${message}`; item.message = message; return }
    item.message = ''
  }
  tip.value = ''
  submitting.value = true
  for (const item of targets) {
    const form = item.form
    const payload = {
      title: text(form.title), dept: text(form.dept), city: text(form.city),
      salaryMin: form.salaryMin === '' ? null : Number(form.salaryMin),
      salaryMax: form.salaryMax === '' ? null : Number(form.salaryMax),
      experience: text(form.experience) || '经验不限',
      education: form.education, jobType: form.jobType, description: text(form.description),
      responsibilities: lines(form.responsibilities), requirements: lines(form.requirements),
      skills: item.skills.map(skill => ({ name: skill.name, required: skill.required }))
    }
    try {
      // 命中重复岗位且选择覆盖更新时走更新接口，否则按草稿新建（状态 0）
      if (item.match && item.action === 'overwrite') { await updateJob(item.match.id, payload); totals.value.updated += 1 }
      else { await createJob({ ...payload, status: 0 }); totals.value.created += 1 }
      item.imported = true
      item.message = ''
    } catch (e) {
      totals.value.failed += 1
      item.message = (e && e.message) || '导入失败'
    }
  }
  submitting.value = false
  if (importTargets.value.length) tip.value = `已导入 ${totals.value.created + totals.value.updated} 个，${importTargets.value.length} 个未完成，请修正后重试`
  else emit('done', { ...totals.value, skipped: skippedCount.value })
}

onMounted(loadExistingJobs)
</script>

<template>
  <div class="import-panel">
    <template v-if="phase === 'upload'">
      <label class="dropzone" @dragover.prevent @drop="onDrop">
        <input type="file" hidden multiple accept=".pdf,.docx" @change="onPick" />
        <CloudUpload :size="36" />
        <b>拖拽文件到此处或点击上传</b>
        <small>支持 .pdf / .docx 格式，单个文件不超过 10MB，一次最多 10 个</small>
      </label>
      <div v-if="tip" class="tip">{{ tip }}</div>
      <div v-if="files.length" class="file-list">
        <div v-for="(file, index) in files" :key="file.key">
          <FileText :size="18" />
          <span>{{ file.name }}</span>
          <i v-if="file.message" class="file-msg">{{ file.message }}</i>
          <em :class="file.status">
            <CircleCheck v-if="file.status === 'done'" :size="15" />
            <AlertTriangle v-else-if="file.status === 'error' || file.status === 'invalid'" :size="15" />
            <RotateCw v-else :size="15" />
            {{ statusText(file) }}
          </em>
          <button @click="remove(index)"><Trash2 :size="15" /></button>
        </div>
      </div>
      <div class="panel-actions">
        <span class="summary">{{ files.length ? `已选择 ${files.length} 个文件` : '尚未选择文件' }}</span>
        <button v-if="parsedFiles.length" class="btn" @click="phase = 'preview'">查看解析结果（{{ parsedFiles.length }}）<ChevronRight :size="14" /></button>
        <button class="btn primary" :disabled="parsing || !parseTargets.length" @click="startParse">
          <RotateCw v-if="parsing" class="spinning" :size="15" />{{ parsing ? '正在解析' : '开始解析' }}
        </button>
      </div>
    </template>

    <template v-else>
      <div class="preview-head">
        <div><h3>解析结果确认</h3><p>共 {{ parsedFiles.length }} 个文档解析完成，核对完整度与重复岗位后确认导入为岗位草稿。</p></div>
        <button class="btn sm" @click="phase = 'upload'">返回文件列表</button>
      </div>
      <div v-if="tip" class="tip">{{ tip }}</div>
      <div class="preview-list">
        <article v-for="item in parsedFiles" :key="item.key" class="preview-card">
          <header>
            <FileText :size="17" />
            <b>{{ item.name }}</b>
            <span class="score" :class="{ ok: scoreOf(item) >= 80 }">完整度 {{ scoreOf(item) }}%</span>
            <span v-if="item.imported" class="tag-ok"><CircleCheck :size="13" />已导入</span>
          </header>
          <p v-if="item.match" class="dup">
            <AlertTriangle :size="14" />
            <span>疑似重复岗位：已有「{{ item.match.title }}」（{{ item.match.dept || '未分配' }}）同名同部门</span>
            <label><input type="radio" value="overwrite" v-model="item.action" />覆盖更新</label>
            <label><input type="radio" value="skip" v-model="item.action" />跳过</label>
          </p>
          <p v-if="missingFields(item).length" class="miss">缺失必填：{{ missingFields(item).join('、') }}</p>
          <p v-else-if="suggestedFields(item).length" class="hint">建议补充：{{ suggestedFields(item).join('、') }}</p>
          <JobContentFields :form="item.form" @change="refreshMatch(item)" />
          <div v-if="item.skills.length" class="skills">
            <span v-for="skill in item.skills" :key="skill.name" :class="{ bonus: !skill.required }">{{ skill.name }}{{ skill.required ? '' : '（加分）' }}</span>
          </div>
          <ul v-if="item.warnings.length" class="warnings">
            <li v-for="warning in item.warnings" :key="warning"><AlertTriangle :size="13" />{{ warning }}</li>
          </ul>
          <p v-if="item.message" class="err">{{ item.message }}</p>
        </article>
      </div>
      <div class="panel-actions">
        <span class="summary">待导入 {{ importTargets.length }} 个，跳过 {{ skippedCount }} 个</span>
        <button class="btn primary" :disabled="submitting || !importTargets.length" @click="submitAll">
          <Sparkles v-if="submitting" class="spinning" :size="15" />{{ submitting ? '正在导入' : '确认导入为草稿' }}
        </button>
      </div>
    </template>
  </div>
</template>

<style scoped>
.dropzone{height:145px;border:1.5px dashed #a9c8ff;border-radius:12px;background:#f8fbff;display:flex;flex-direction:column;align-items:center;justify-content:center;color:#2870ef;cursor:pointer}
.dropzone b{color:#26364f;font-size:13px;margin-top:9px}.dropzone small{color:#96a4b8;margin-top:6px;font-size:11px}
.tip{margin-top:12px;padding:9px 12px;border-radius:8px;background:#fff7ed;color:#b45309;font-size:12px}
.file-list{display:flex;flex-direction:column;gap:8px;margin-top:16px}
.file-list>div{min-height:45px;border:1px solid #e0e7f1;border-radius:9px;background:#f8fafc;display:flex;align-items:center;gap:9px;padding:0 12px;color:#2563eb}
.file-list span{flex:1;color:#26364f;font-size:12px}.file-msg{font-style:normal;color:#dc2626;font-size:11px}
.file-list em{display:flex;align-items:center;gap:5px;font-style:normal;color:#2970ed;font-size:11px}
.file-list em:not(.done):not(.error):not(.invalid) svg{animation:spin 1s linear infinite}
.file-list em.done{color:#08a775}.file-list em.error,.file-list em.invalid{color:#dc2626}
.file-list button{border:0;background:transparent;color:#a0aec0}
.spinning{animation:spin 1s linear infinite}
.panel-actions{display:flex;align-items:center;gap:10px;margin-top:16px}
.panel-actions .summary{flex:1;font-size:12px;color:#6f7f99}
.preview-head{display:flex;justify-content:space-between;align-items:flex-start;gap:16px;margin-bottom:14px}
.preview-head h3{font-size:15px}.preview-head p{margin-top:5px;font-size:12px;color:#6f7f99}
.preview-list{display:flex;flex-direction:column;gap:14px}
.preview-card{border:1px solid #e5ebf3;border-radius:12px;padding:14px 16px;background:#fff}
.preview-card>header{display:flex;align-items:center;gap:8px;color:#2563eb}
.preview-card>header b{flex:1;color:#1f2d46;font-size:13px}
.score{padding:3px 8px;border-radius:999px;background:#fff1f0;color:#dc2626;font-size:11px}
.score.ok{background:#ecfdf5;color:#059669}
.tag-ok{display:flex;align-items:center;gap:4px;padding:3px 8px;border-radius:999px;background:#ecfdf5;color:#059669;font-size:11px}
.dup,.miss,.hint{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-top:10px;padding:8px 11px;border-radius:8px;font-size:12px}
.dup{background:#fff7ed;color:#b45309}.dup label{display:flex;align-items:center;gap:4px;color:#7c4a03;font-size:12px}
.miss{background:#fff1f0;color:#dc2626}.hint{background:#f1f5f9;color:#64748b}
.skills{display:flex;flex-wrap:wrap;gap:6px;margin-top:12px}
.skills span{padding:4px 8px;border-radius:6px;background:#eaf1ff;color:#2563eb;font-size:11px}
.skills span.bonus{background:#f1f5f9;color:#64748b}
.warnings{margin-top:10px;padding-left:0;list-style:none;display:flex;flex-direction:column;gap:5px}
.warnings li{display:flex;gap:6px;align-items:flex-start;font-size:11px;color:#6f7f99}
.err{margin-top:10px;font-size:12px;color:#dc2626}
</style>
