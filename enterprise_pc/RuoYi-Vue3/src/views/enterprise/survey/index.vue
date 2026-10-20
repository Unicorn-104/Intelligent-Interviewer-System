<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { MessageSquareText, Smile, Send, Target, Plus, Pencil, Trash2, X, Lightbulb, Copy } from '@/views/enterprise/components/icons'
import StatCard from '@/views/enterprise/components/StatCard.vue'
import SwitchToggle from '@/views/enterprise/components/SwitchToggle.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import {
  listSurveyTemplates, createSurveyTemplate, updateSurveyTemplate,
  updateSurveyTemplateStatus, deleteSurveyTemplate, getSurveyResults
} from '@/api/survey'

// 触发场景口径与后端 svt_trigger_scene 保持一致
const SCENES = [
  { value: 1, label: '面试后' },
  { value: 2, label: '初筛后' },
  { value: 3, label: '录用后' },
  { value: 4, label: '淘汰后' },
  { value: 5, label: '投递简历后' }
]
const sceneLabel = (v) => SCENES.find(s => s.value === Number(v))?.label || '—'
const QUESTION_TYPES = [
  { value: 'rating', label: '评分题' },
  { value: 'single', label: '单选题' },
  { value: 'multi', label: '多选题' },
  { value: 'text', label: '文本题' }
]

const tab = ref('config')
const loading = ref(false)
const templates = ref([])

// ---------- 问卷配置 ----------
const editorOpen = ref(false)
const saving = ref(false)
const form = reactive({ templateId: null, name: '', triggerScene: 1, status: 1, questions: [] })

function ownerText(t) { return t.companyId == null ? '平台通用' : '企业自有' }
function canEdit(t) { return t.companyId != null }

// 类别筛选：全部 / 平台通用（无企业归属）/ 企业自有
const catFilter = ref('all')
const CATEGORY_TABS = [
  { value: 'all', label: '全部' },
  { value: 'platform', label: '平台通用' },
  { value: 'own', label: '企业自有' }
]
const filteredTemplates = computed(() => {
  if (catFilter.value === 'platform') return templates.value.filter(t => t.companyId == null)
  if (catFilter.value === 'own') return templates.value.filter(t => t.companyId != null)
  return templates.value
})

async function loadTemplates() {
  loading.value = true
  try {
    const res = await listSurveyTemplates(true)
    templates.value = res.data || []
  } catch (e) {
    templates.value = []
    ElMessage.error(e?.message || '加载问卷模板失败')
  } finally {
    loading.value = false
  }
}

function nextQid() {
  return form.questions.reduce((max, q) => Math.max(max, Number(q.qid) || 0), 0) + 1
}

function openCreate() {
  form.templateId = null
  form.name = ''
  form.triggerScene = 1
  form.status = 1
  form.questions = [{ qid: 1, type: 'rating', title: '' }]
  editorOpen.value = true
}

// 模板题目 -> 编辑表单行；空题目时给一行默认评分题
function mapQuestions(list) {
  const rows = (list || []).map(q => ({
    qid: q.qid,
    type: q.type || 'rating',
    title: q.title || '',
    options: Array.isArray(q.options) ? q.options.join('、') : ''
  }))
  return rows.length ? rows : [{ qid: 1, type: 'rating', title: '' }]
}

function openEdit(t) {
  form.templateId = t.templateId
  form.name = t.name
  form.triggerScene = Number(t.triggerScene)
  form.status = Number(t.status)
  form.questions = mapQuestions(t.questions)
  editorOpen.value = true
}

// 平台通用模板对企业只读：一键复制为本企业可编辑的自有模板（走新建接口落库）
function duplicateTemplate(t) {
  form.templateId = null
  form.name = t.name
  form.triggerScene = Number(t.triggerScene)
  form.status = 1
  form.questions = mapQuestions(t.questions)
  editorOpen.value = true
}

function addQuestion() {
  form.questions.push({ qid: nextQid(), type: 'rating', title: '', options: '' })
}

function removeQuestion(index) {
  form.questions.splice(index, 1)
}

function buildQuestions() {
  return form.questions.map(q => {
    const item = { qid: q.qid, type: q.type, title: (q.title || '').trim() }
    if (q.type === 'single' || q.type === 'multi') {
      item.options = (q.options || '').split(/[、,，]/).map(s => s.trim()).filter(Boolean)
    }
    return item
  })
}

async function saveTemplate() {
  const name = form.name.trim()
  if (!name) { ElMessage.warning('请填写问卷名称'); return }
  if (!form.questions.length) { ElMessage.warning('至少添加一道题目'); return }
  if (form.questions.some(q => !(q.title || '').trim())) { ElMessage.warning('题目标题不能为空'); return }
  const payload = {
    name,
    triggerScene: Number(form.triggerScene),
    status: Number(form.status),
    questions: JSON.stringify(buildQuestions())
  }
  saving.value = true
  try {
    if (form.templateId == null) await createSurveyTemplate(payload)
    else await updateSurveyTemplate(form.templateId, payload)
    ElMessage.success(form.templateId == null ? '问卷已创建' : '问卷已更新')
    editorOpen.value = false
    await loadTemplates()
  } catch (e) {
    ElMessage.error(e?.message || '保存失败')
  } finally {
    saving.value = false
  }
}

async function toggleStatus(t, value) {
  try {
    await updateSurveyTemplateStatus(t.templateId, value ? 1 : 0)
    t.status = value ? 1 : 0
    ElMessage.success(value ? '已启用' : '已停用')
  } catch (e) {
    ElMessage.error(e?.message || '操作失败')
    await loadTemplates()
  }
}

async function removeTemplate(t) {
  try {
    await ElMessageBox.confirm(`确定删除问卷《${t.name}》？`, '删除确认', { type: 'warning' })
  } catch { return }
  try {
    await deleteSurveyTemplate(t.templateId)
    ElMessage.success('已删除')
    await loadTemplates()
  } catch (e) {
    ElMessage.error(e?.message || '删除失败')
  }
}

// ---------- 触发规则 ----------
const rules = computed(() => SCENES.map(s => ({
  ...s,
  templates: templates.value.filter(t => Number(t.triggerScene) === s.value)
})))

// ---------- 回收统计 ----------
const filters = reactive({ templateId: null, from: '', to: '' })
const stats = ref({ responseCount: 0, avgScore: null, sentCount: 0, pendingCount: 0, distribution: [], responses: [], dispatches: [] })
const statsLoading = ref(false)

const templateQuestions = computed(() => {
  const map = {}
  templates.value.forEach(t => { map[t.templateId] = t.questions || [] })
  return map
})

const recycleRate = computed(() => {
  const sent = Number(stats.value.sentCount) || 0
  if (!sent) return '—'
  return Math.round((Number(stats.value.responseCount) || 0) / sent * 100) + '%'
})

const distributionRows = computed(() => {
  const map = {}
  ;(stats.value.distribution || []).forEach(d => { map[Number(d.bucket)] = Number(d.count) })
  const max = Math.max(1, ...Object.values(map))
  return [1, 2, 3, 4, 5].map(star => ({ star, count: map[star] || 0, percent: (map[star] || 0) / max * 100 }))
})

async function loadResults() {
  statsLoading.value = true
  try {
    const params = {}
    if (filters.templateId != null) params.templateId = filters.templateId
    if (filters.from) params.from = filters.from
    if (filters.to) params.to = filters.to + ' 23:59:59'
    const res = await getSurveyResults(params)
    stats.value = res.data || stats.value
  } catch (e) {
    ElMessage.error(e?.message || '加载统计失败')
  } finally {
    statsLoading.value = false
  }
}

// 回收明细里按题目渲染答案，文本反馈与选项直接展示
function answerLines(r) {
  const questions = templateQuestions.value[r.templateId] || []
  const answers = r.answers || {}
  const lines = []
  questions.forEach(q => {
    const value = answers[String(q.qid)]
    if (value == null || value === '' || (Array.isArray(value) && !value.length)) return
    lines.push({ title: q.title, text: Array.isArray(value) ? value.join('、') : String(value) })
  })
  return lines
}

function starText(score) {
  if (score == null) return '—'
  const n = Math.round(Number(score))
  return '★'.repeat(Math.max(0, n)) + '☆'.repeat(Math.max(0, 5 - n))
}

const DISPATCH_STATUS = { 0: { label: '待填写', cls: 'orange' }, 1: { label: '已填写', cls: 'green' }, 2: { label: '已失效', cls: 'gray' } }
function dispatchStatus(v) { return DISPATCH_STATUS[Number(v)] || { label: '—', cls: 'gray' } }

function switchTab(name) {
  tab.value = name
  if (name === 'stats') loadResults()
}

onMounted(loadTemplates)
</script>

<template>
  <div class="page">
    <header class="page-heading">
      <div>
        <h1>满意度调研</h1>
        <p>问卷配置、触发场景与回收结果统计 · 共 {{ templates.length }} 份问卷</p>
      </div>
      <button class="btn primary" @click="openCreate"><Plus :size="16"/>新建问卷</button>
    </header>

    <div class="tabs">
      <button :class="{ on: tab === 'config' }" @click="switchTab('config')">问卷配置</button>
      <button :class="{ on: tab === 'rules' }" @click="switchTab('rules')">触发规则</button>
      <button :class="{ on: tab === 'stats' }" @click="switchTab('stats')">回收统计</button>
    </div>

    <!-- 问卷配置 -->
    <section v-if="tab === 'config'" class="panel">
      <div class="cat-tabs">
        <button v-for="c in CATEGORY_TABS" :key="c.value" :class="{ on: catFilter === c.value }" @click="catFilter = c.value">{{ c.label }}</button>
      </div>
      <div v-if="loading" class="empty">加载中…</div>
      <div v-else-if="!filteredTemplates.length" class="empty">{{ templates.length ? '该类别下暂无问卷' : '暂无问卷，点击右上角「新建问卷」创建第一份调研问卷' }}</div>
      <div v-else class="tpl-grid">
        <article v-for="t in filteredTemplates" :key="t.templateId" class="tpl-card card">
          <div class="tpl-head">
            <h3>{{ t.name }}</h3>
            <span class="pill" :class="canEdit(t) ? 'purple' : 'gray'">{{ ownerText(t) }}</span>
          </div>
          <p class="tpl-meta">
            <span class="pill green">{{ sceneLabel(t.triggerScene) }}</span>
            <span>{{ (t.questions || []).length }} 道题目</span>
          </p>
          <div class="tpl-foot">
            <label class="tpl-switch">
              <SwitchToggle :model-value="Number(t.status) === 1" :disabled="!canEdit(t)" @update:modelValue="(v) => toggleStatus(t, v)" />
              <span>{{ Number(t.status) === 1 ? '已启用' : '已停用' }}</span>
            </label>
            <div class="tpl-ops">
              <button v-if="!canEdit(t)" class="btn sm ghost-primary" @click="duplicateTemplate(t)"><Copy :size="14"/>复制为自有</button>
              <button class="btn sm" :disabled="!canEdit(t)" @click="openEdit(t)"><Pencil :size="14"/>编辑</button>
              <button class="btn sm danger-ghost" :disabled="!canEdit(t)" @click="removeTemplate(t)"><Trash2 :size="14"/>删除</button>
            </div>
          </div>
        </article>
      </div>
    </section>

    <!-- 触发规则 -->
    <section v-else-if="tab === 'rules'" class="panel">
      <p class="rules-tip"><Lightbulb :size="15"/>问卷模板按触发场景绑定；HR 在「消息中心」选择「发送调研文件」，按场景挑选对应问卷发送给候选人。</p>
      <div class="rule-grid">
        <article v-for="r in rules" :key="r.value" class="rule-card card">
          <header class="rule-head">
            <span class="pill green">{{ r.label }}</span>
            <small>{{ r.templates.length }} 份问卷</small>
          </header>
          <p v-if="!r.templates.length" class="rule-empty">暂无绑定到该场景的问卷</p>
          <div v-for="t in r.templates" :key="t.templateId" class="rule-row">
            <span>{{ t.name }}</span>
            <label class="tpl-switch">
              <SwitchToggle :model-value="Number(t.status) === 1" :disabled="!canEdit(t)" @update:modelValue="(v) => toggleStatus(t, v)" />
              <em>{{ Number(t.status) === 1 ? '启用' : '停用' }}</em>
            </label>
          </div>
        </article>
      </div>
    </section>

    <!-- 回收统计 -->
    <section v-else class="panel">
      <div class="filters card">
        <label class="sel-row">
          <span>问卷</span>
          <select v-model="filters.templateId" class="sel">
            <option :value="null">全部问卷</option>
            <option v-for="t in templates" :key="t.templateId" :value="t.templateId">{{ t.name }}</option>
          </select>
        </label>
        <label class="sel-row">
          <span>开始日期</span>
          <input v-model="filters.from" class="sel" type="date" />
        </label>
        <label class="sel-row">
          <span>结束日期</span>
          <input v-model="filters.to" class="sel" type="date" />
        </label>
        <button class="btn sm ghost-primary" @click="loadResults">查询</button>
      </div>

      <div class="stat-grid">
        <StatCard title="回收量" :value="stats.responseCount || 0" note="已提交的调研问卷份数" tone="blue" :icon="MessageSquareText" />
        <StatCard title="平均满意度" :value="stats.avgScore == null ? '—' : stats.avgScore + ' / 5'" note="满意度评分均值" tone="green" :icon="Smile" />
        <StatCard title="发送量" :value="stats.sentCount || 0" note="已发出的调研邀请数" :icon="Send" />
        <StatCard title="回收率" :value="recycleRate" note="回收量 / 发送量" tone="orange" :icon="Target" />
      </div>

      <div class="stat-body">
        <article class="card dist-card">
          <h3>评分分布</h3>
          <p v-if="!stats.responseCount" class="mini-empty">暂无回收数据</p>
          <div v-else class="dist">
            <div v-for="d in distributionRows" :key="d.star" class="dist-row">
              <span class="dist-star">{{ d.star }} 星</span>
              <div class="dist-bar"><i :style="{ width: d.percent + '%' }" /></div>
              <b>{{ d.count }} 份</b>
            </div>
          </div>
        </article>

        <article class="card resp-card">
          <h3>回收明细</h3>
          <p v-if="statsLoading" class="mini-empty">加载中…</p>
          <p v-else-if="!stats.responses.length" class="mini-empty">暂无回收记录</p>
          <div v-else class="resp-list">
            <article v-for="r in stats.responses" :key="r.responseId" class="resp-item">
              <header>
                <b>{{ r.candidateName || '候选人' + r.candidateId }}</b>
                <span class="pill gray">{{ r.templateName }}</span>
                <em class="resp-star" :title="'满意度 ' + r.satisfactionScore">{{ starText(r.satisfactionScore) }}</em>
                <time>{{ r.submittedAt }}</time>
              </header>
              <ul>
                <li v-for="(line, i) in answerLines(r)" :key="i"><b>{{ line.title }}</b><span>{{ line.text }}</span></li>
              </ul>
            </article>
          </div>
        </article>
      </div>

      <article class="card dispatch-card">
        <h3>发送记录</h3>
        <p v-if="!stats.dispatches.length" class="mini-empty">暂无发送记录，可在「消息中心」向候选人发送调研问卷</p>
        <table v-else class="dispatch-table">
          <thead><tr><th>候选人</th><th>问卷</th><th>状态</th><th>发送时间</th></tr></thead>
          <tbody>
            <tr v-for="d in stats.dispatches" :key="d.dispatchId">
              <td>{{ d.candidateName || '候选人' + d.candidateId }}</td>
              <td>{{ d.templateName }}</td>
              <td><span class="pill" :class="dispatchStatus(d.status).cls">{{ dispatchStatus(d.status).label }}</span></td>
              <td>{{ d.sentAt }}</td>
            </tr>
          </tbody>
        </table>
      </article>
    </section>

    <BaseModal v-if="editorOpen" :title="form.templateId == null ? '新建调研问卷' : '编辑调研问卷'" width="680px" @close="editorOpen = false">
      <div class="editor">
        <label class="ed-row"><span>问卷名称</span><input v-model="form.name" class="sel" maxlength="50" placeholder="如：AI面试体验调研（面试后）" /></label>
        <label class="ed-row">
          <span>触发场景</span>
          <select v-model.number="form.triggerScene" class="sel">
            <option v-for="s in SCENES" :key="s.value" :value="s.value">{{ s.label }}</option>
          </select>
        </label>
        <label class="ed-row">
          <span>启用状态</span>
          <SwitchToggle :model-value="form.status === 1" @update:modelValue="(v) => (form.status = v ? 1 : 0)" />
          <em>{{ form.status ? '启用后可在消息中心发送' : '停用后不可发送' }}</em>
        </label>

        <div class="ed-questions">
          <div class="ed-q-head"><span>题目设置</span><button class="btn sm ghost-primary" @click="addQuestion"><Plus :size="14"/>添加题目</button></div>
          <p v-if="!form.questions.length" class="mini-empty">暂无题目，请添加</p>
          <div v-for="(q, index) in form.questions" :key="index" class="q-row">
            <span class="q-no">{{ index + 1 }}</span>
            <select v-model="q.type" class="sel q-type">
              <option v-for="qt in QUESTION_TYPES" :key="qt.value" :value="qt.value">{{ qt.label }}</option>
            </select>
            <input v-model="q.title" class="sel q-title" placeholder="题目标题" maxlength="100" />
            <input v-if="q.type === 'single' || q.type === 'multi'" v-model="q.options" class="sel q-opt" placeholder="选项，用、分隔" />
            <button class="q-del" title="删除题目" @click="removeQuestion(index)"><X :size="15"/></button>
          </div>
        </div>

        <div class="ed-foot">
          <button class="btn" @click="editorOpen = false">取消</button>
          <button class="btn primary" :disabled="saving" @click="saveTemplate">{{ saving ? '保存中…' : '保存' }}</button>
        </div>
      </div>
    </BaseModal>
  </div>
</template>

<style scoped>
.tabs{display:flex;gap:6px;margin-bottom:18px}
.tabs button{height:36px;padding:0 18px;border:1px solid var(--line);border-radius:9px;background:white;color:#5b6b83;font-size:13px;cursor:pointer}
.tabs button.on{background:linear-gradient(135deg,var(--primary),#3b82f6);color:#fff;border-color:transparent;box-shadow:0 5px 14px rgba(37,99,235,.2)}
.panel{display:flex;flex-direction:column;gap:18px}
.cat-tabs{display:flex;gap:6px}
.cat-tabs button{height:32px;padding:0 14px;border:1px solid var(--line);border-radius:8px;background:#fff;color:#5b6b83;font-size:12px;cursor:pointer}
.cat-tabs button.on{background:#eaf1ff;color:#2563eb;border-color:#c7dcff;font-weight:600}
.sel{height:34px;border:1px solid var(--line);border-radius:8px;padding:0 10px;font-size:12px;background:#fff;color:#40516a;outline:none}
.sel:focus{border-color:var(--primary)}

.tpl-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:16px}
.tpl-card{padding:18px 20px;display:flex;flex-direction:column;gap:12px}
.tpl-head{display:flex;align-items:flex-start;justify-content:space-between;gap:10px}
.tpl-head h3{font-size:15px;line-height:1.35}
.tpl-meta{display:flex;align-items:center;gap:10px;color:#8291a7;font-size:12px}
.tpl-foot{display:flex;align-items:center;flex-wrap:wrap;gap:10px;border-top:1px solid #eef2f7;padding-top:12px}
.tpl-switch{display:flex;align-items:center;gap:8px;flex:none;white-space:nowrap;font-size:12px;color:#5b6b83}
.tpl-switch em{font-style:normal;color:#8291a7;font-size:11px}
.tpl-ops{display:flex;gap:8px;flex-wrap:wrap;margin-left:auto}
.btn:disabled{opacity:.45;cursor:not-allowed;transform:none;box-shadow:none}

.rules-tip{display:flex;align-items:center;gap:8px;color:#2563eb;background:#edf4ff;border-radius:10px;padding:12px 14px;font-size:12px}
.rule-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px}
.rule-card{padding:16px 18px}
.rule-head{display:flex;align-items:center;justify-content:space-between}
.rule-head small{color:#8291a7;font-size:11px}
.rule-empty{color:#98a5b7;font-size:12px;padding:14px 0}
.rule-row{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:10px 0;border-top:1px solid #f2f5f9;font-size:12px}
.rule-row span{color:#40516a}

.filters{display:flex;flex-wrap:wrap;gap:14px;align-items:center;padding:16px 18px}
.sel-row{display:flex;align-items:center;gap:8px;font-size:12px;color:#8291a7}
.stat-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:16px}
.stat-body{display:grid;grid-template-columns:300px 1fr;gap:18px}
.dist-card,.resp-card,.dispatch-card{padding:18px 20px}
.dist-card h3,.resp-card h3,.dispatch-card h3{font-size:14px;margin-bottom:14px}
.mini-empty{color:#98a5b7;font-size:12px;padding:16px 0;text-align:center}
.dist{display:flex;flex-direction:column;gap:12px}
.dist-row{display:grid;grid-template-columns:44px 1fr 44px;align-items:center;gap:10px;font-size:12px;color:#5b6b83}
.dist-star{color:#8291a7}
.dist-bar{height:10px;border-radius:6px;background:#eff3f9;overflow:hidden}
.dist-bar i{display:block;height:100%;background:linear-gradient(90deg,#60a5fa,#2563eb);border-radius:6px}
.dist-row b{text-align:right;color:#40516a}
.resp-list{display:flex;flex-direction:column;gap:12px;max-height:420px;overflow:auto}
.resp-item{border:1px solid #eef2f7;border-radius:10px;padding:12px 14px}
.resp-item header{display:flex;align-items:center;gap:10px;font-size:12px}
.resp-item header b{font-size:13px}
.resp-item header time{margin-left:auto;color:#9aa7b8;font-size:11px}
.resp-star{color:#f59e0b;font-style:normal;letter-spacing:1px}
.resp-item ul{list-style:none;margin-top:10px;display:flex;flex-direction:column;gap:7px}
.resp-item li{display:flex;gap:8px;font-size:12px;color:#5b6b83;line-height:1.5}
.resp-item li b{color:#8291a7;flex:none;max-width:44%}
.dispatch-table{width:100%;border-collapse:collapse;font-size:12px}
.dispatch-table th,.dispatch-table td{text-align:left;padding:10px 8px;border-bottom:1px solid #f2f5f9}
.dispatch-table th{color:#8291a7;font-weight:500}

.editor{display:flex;flex-direction:column;gap:14px}
.ed-row{display:flex;align-items:center;gap:10px;font-size:12px;color:#8291a7}
.ed-row>span{width:66px;flex:none}
.ed-row .sel{flex:1;min-width:0}
.ed-row em{font-style:normal;color:#8291a7;font-size:11px}
.ed-questions{border:1px solid #eef2f7;border-radius:10px;padding:12px 14px}
.ed-q-head{display:flex;align-items:center;justify-content:space-between;font-size:12px;color:#8291a7;margin-bottom:10px}
.q-row{display:flex;align-items:center;gap:8px;margin-bottom:8px}
.q-no{width:20px;height:20px;flex:none;border-radius:50%;background:#eaf1ff;color:#2563eb;font-size:11px;display:grid;place-items:center}
.q-type{width:104px;flex:none}
.q-title{flex:1;min-width:0}
.q-opt{width:190px;flex:none}
.q-del{width:28px;height:28px;flex:none;border:0;background:none;color:#ef4444;cursor:pointer;display:grid;place-items:center}
.ed-foot{display:flex;justify-content:flex-end;gap:10px}
</style>
