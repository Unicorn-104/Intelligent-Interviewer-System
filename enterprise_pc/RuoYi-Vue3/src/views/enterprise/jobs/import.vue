<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Archive, CloudUpload, Eye, Pencil, Send, Trash2 } from '@/views/enterprise/components/icons'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import JobImportPanel from '@/views/enterprise/components/JobImportPanel.vue'
import JobContentFields from '@/views/enterprise/components/JobContentFields.vue'
import { listJobs, jobDetail, updateJob, changeJobStatus, deleteDraftJob } from '@/api/system/job'

const router = useRouter()
const drafts = ref([])
const editOpen = ref(false)
const editing = ref(null)
const saving = ref(false)

function emptyForm() {
  return { title: '', dept: '', city: '', salaryMin: '', salaryMax: '', experience: '', education: null, jobType: 1, description: '', responsibilities: '', requirements: '' }
}
const form = ref(emptyForm())

function parseJd(value) {
  try { return JSON.parse(value || '{}') } catch (e) { return {} }
}
function splitLines(value) { return String(value || '').split('\n').map(s => s.trim()).filter(Boolean) }

// 草稿箱口径复用岗位状态 0（已下线/未发布），仅展示当前企业的草稿
async function fetchDrafts() {
  const res = await listJobs({ pageNum: 1, pageSize: 100, status: 0 })
  drafts.value = (res.rows || []).map(row => {
    const jd = parseJd(row.jdJson)
    return {
      id: row.posId, title: row.title, dept: row.dept || '未分配', city: row.city || '—',
      salary: row.salaryMin != null ? `${Math.round(row.salaryMin / 1000)}-${Math.round(row.salaryMax / 1000)}K` : '面议',
      date: row.publishTime || row.date || '—',
      responsibilities: jd.responsibilities || [], requirements: jd.requirements || []
    }
  })
}

function onImported(result) {
  fetchDrafts()
  const parts = [`导入完成：新建 ${result.created} 个草稿`]
  if (result.updated) parts.push(`覆盖更新 ${result.updated} 个`)
  if (result.failed) parts.push(`失败 ${result.failed} 个`)
  if (result.skipped) parts.push(`跳过 ${result.skipped} 个`)
  ElMessage.success(parts.join('，'))
}

async function openEdit(row) {
  try {
    const res = await jobDetail(row.id)
    const job = res.data?.job || {}
    const jd = parseJd(job.jdJson)
    form.value = {
      title: job.title || '', dept: job.dept || '', city: job.city || '',
      salaryMin: job.salaryMin == null ? '' : job.salaryMin,
      salaryMax: job.salaryMax == null ? '' : job.salaryMax,
      experience: job.experience || '',
      education: job.education == null ? null : job.education,
      jobType: job.jobType == null ? 1 : job.jobType,
      description: jd.description || '',
      responsibilities: (jd.responsibilities || []).join('\n'),
      requirements: (jd.requirements || []).join('\n')
    }
    editing.value = { id: row.id, title: row.title }
    editOpen.value = true
  } catch (e) { ElMessage.error(e?.message || '加载岗位内容失败') }
}

// 保存草稿内容：不传 skills，保持原岗位技能标签不变，状态仍为草稿
async function saveEdit() {
  saving.value = true
  try {
    await updateJob(editing.value.id, {
      title: form.value.title, dept: form.value.dept, city: form.value.city,
      salaryMin: form.value.salaryMin === '' ? null : Number(form.value.salaryMin),
      salaryMax: form.value.salaryMax === '' ? null : Number(form.value.salaryMax),
      experience: form.value.experience, education: form.value.education, jobType: form.value.jobType,
      description: form.value.description,
      responsibilities: splitLines(form.value.responsibilities),
      requirements: splitLines(form.value.requirements)
    })
    editOpen.value = false
    ElMessage.success('草稿内容已更新')
    fetchDrafts()
  } catch (e) { ElMessage.error(e?.message || '保存失败') }
  finally { saving.value = false }
}

async function publishDraft(row) {
  if (!confirm(`确定发布草稿「${row.title}」？发布后该岗位进入招聘中。`)) return
  try {
    await changeJobStatus(row.id, 1)
    ElMessage.success('草稿已发布')
    fetchDrafts()
  } catch (e) { ElMessage.error(e?.message || '发布失败') }
}

async function removeDraft(row) {
  if (!confirm(`确定删除草稿「${row.title}」？删除后不可恢复。`)) return
  try {
    await deleteDraftJob(row.id)
    ElMessage.success('草稿已删除')
    fetchDrafts()
  } catch (e) { ElMessage.error(e?.message || '删除失败') }
}

onMounted(fetchDrafts)
</script>

<template>
  <div class="page import-page">
    <div class="page-heading">
      <div><h1>岗位导入与草稿</h1><p>上传 JD 文档由 AI 解析生成岗位草稿，并在此集中管理未发布的草稿岗位</p></div>
    </div>

    <section class="card import-card">
      <div class="card-head"><h2><CloudUpload :size="17" />导入岗位文件</h2><p>支持 .pdf / .docx 格式的 JD 文档，解析后可核对字段并确认生成岗位草稿</p></div>
      <div class="panel-wrap"><JobImportPanel @done="onImported" /></div>
    </section>

    <section class="card draft-card">
      <div class="card-head"><h2><Archive :size="17" />草稿箱<span class="count">{{ drafts.length }}</span></h2><p>查看、编辑、发布或删除未发布的岗位草稿</p></div>
      <div v-if="drafts.length" class="draft-table">
        <div class="draft-row head"><span>岗位名称</span><span>部门</span><span>城市</span><span>薪资</span><span>创建时间</span><span>操作</span></div>
        <div v-for="row in drafts" :key="row.id" class="draft-row">
          <span class="name">{{ row.title }}</span>
          <span>{{ row.dept }}</span>
          <span>{{ row.city }}</span>
          <span class="num">{{ row.salary }}</span>
          <span class="num">{{ row.date }}</span>
          <span class="ops">
            <button class="btn sm" @click="router.push(`/enterprise/jobs/${row.id}`)"><Eye :size="14" />详情</button>
            <button class="btn sm" @click="openEdit(row)"><Pencil :size="14" />编辑</button>
            <button class="btn sm ghost-primary" @click="publishDraft(row)"><Send :size="14" />发布</button>
            <button class="btn sm danger-ghost" @click="removeDraft(row)"><Trash2 :size="14" />删除</button>
          </span>
        </div>
      </div>
      <p v-else class="empty">暂无草稿岗位，可通过上方导入 JD 文档生成，或在「岗位列表」发布新岗位时选择保存草稿</p>
    </section>

    <BaseModal v-if="editOpen" title="编辑草稿岗位" width="720px" @close="editOpen = false">
      <p class="edit-tip">正在编辑草稿「{{ editing?.title }}」，保存后仍保持草稿状态。</p>
      <JobContentFields :form="form" />
      <template #footer>
        <button class="btn" :disabled="saving" @click="editOpen = false">取消</button>
        <button class="btn primary" :disabled="saving" @click="saveEdit">{{ saving ? '保存中…' : '保存' }}</button>
      </template>
    </BaseModal>
  </div>
</template>

<style scoped>
.import-page{display:flex;flex-direction:column;gap:18px}
.card-head{padding:18px 20px 0}
.card-head h2{display:flex;align-items:center;gap:8px;font-size:17px;color:#1f2d46}
.card-head h2 svg{color:var(--primary)}
.card-head p{margin-top:6px;font-size:12px;color:var(--muted)}
.count{margin-left:2px;font-size:11px;font-weight:600;color:#2563eb;background:#eaf1ff;border-radius:11px;padding:3px 9px}
.panel-wrap{padding:16px 20px 20px}
.draft-table{margin:14px 20px 20px;border:1px solid #e8eef7;border-radius:10px;overflow:hidden}
.draft-row{display:grid;grid-template-columns:minmax(150px,1.7fr) 1fr .7fr .85fr 1.15fr 260px;gap:14px;align-items:center;padding:9px 14px;font-size:12px;border-top:1px solid #f0f4fa}
.draft-row .name{font-weight:600;color:#1f2d46;font-size:13px}
.draft-row .num{font-variant-numeric:tabular-nums;color:#4a5b73}
.draft-row.head{border-top:0;background:#f7f9fc;color:#8e9db3;font-size:11px;font-weight:600}
.draft-row:not(.head):hover{background:#fafcff}
.ops{display:flex;gap:5px;flex-wrap:nowrap}
.ops :deep(.btn.sm){height:27px;padding:0 8px;font-size:11px;gap:4px;border-radius:6px}
.edit-tip{margin-bottom:14px;font-size:12px;color:var(--muted)}
</style>
