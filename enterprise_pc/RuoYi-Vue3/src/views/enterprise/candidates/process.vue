<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ArrowLeft, CheckCircle2, Clock3, CircleX, CalendarPlus, FileText, GitBranch, History, Sparkles } from '@/views/enterprise/components/icons'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import { getTalentDetail, getTalentResume, updateTalentStatus, inviteInterview } from '@/api/talent'
import { listInterviews } from '@/api/interview'
import { listJobs } from '@/api/system/job'
import { listMembers } from '@/api/system/settings'

const router = useRouter()
const route = useRoute()
const toast = ref('')
const loading = ref(true)
const talentId = computed(() => route.params.id)
const detail = ref(null)
const resume = ref(null)
const interviews = ref([])

const STATUS = {
  0: ['新入库', 'gray'], 1: ['初筛通过', 'green'], 2: ['面试中', 'purple'], 3: ['已淘汰', 'red'],
  4: ['已录用', 'green'], 5: ['待笔试', 'orange'], 6: ['笔试中', 'orange'], 7: ['笔试通过', 'green'],
  8: ['笔试未通过', 'red'], 9: ['笔试缺考', 'gray']
}
const APT_STATUS = { 0: ['待确认', 'gray'], 1: ['已确认', 'green'], 2: ['已取消', 'gray'], 3: ['已完成', 'purple'] }
const STATUS_OPTIONS = Object.keys(STATUS).map(k => ({ value: Number(k), label: STATUS[k][0] }))

const statusInfo = computed(() => STATUS[detail.value?.status] || ['未知', 'gray'])
const mainPosition = computed(() => interviews.value.find(i => i.positionTitle)?.positionTitle || detail.value?.jobDirection || '—')

// 时间线：真实面试预约，按开始时间升序；最近一场视为当前环节
const timeline = computed(() => {
  const list = interviews.value.slice().sort((a, b) => String(a.startTime || '').localeCompare(String(b.startTime || '')))
  const activeIndex = list.reduce((acc, item, index) => (item.status !== 2 ? index : acc), -1)
  return list.map((item, index) => ({
    ...item,
    stage: item.status === 3 ? 'completed' : index === activeIndex ? 'active' : 'upcoming',
    statusText: APT_STATUS[item.status]?.[0] || '未知',
    statusCls: APT_STATUS[item.status]?.[1] || 'gray'
  }))
})

const completedCount = computed(() => timeline.value.filter(i => i.status === 3).length)

function notify(v) { toast.value = v; setTimeout(() => toast.value = '', 2200) }

async function load() {
  loading.value = true
  try {
    const [detailRes, resumeRes, interviewRes] = await Promise.all([
      getTalentDetail(talentId.value),
      getTalentResume(talentId.value),
      listInterviews({ candidateId: talentId.value, pageNum: 1, pageSize: 100 })
    ])
    detail.value = detailRes.data || null
    resume.value = resumeRes.data || null
    interviews.value = interviewRes.rows || []
  } catch (e) {
    detail.value = null
  } finally {
    loading.value = false
  }
}

// 简历详情
const resumeOpen = ref(false)

// 下一阶段排期
const inviteOpen = ref(false)
const inviteForm = ref({ positionId: '', interviewerId: '', startTime: '', durationMin: 45 })
const positions = ref([])
const members = ref([])

async function openInvite() {
  inviteForm.value = { positionId: '', interviewerId: '', startTime: '', durationMin: 45 }
  inviteOpen.value = true
  if (!positions.value.length) {
    try {
      const res = await listJobs({ pageNum: 1, pageSize: 200 })
      positions.value = res.rows || []
    } catch (e) { positions.value = [] }
  }
  if (!members.value.length) {
    try {
      const res = await listMembers()
      members.value = res.data || []
    } catch (e) { members.value = [] }
  }
}

async function submitInvite() {
  const f = inviteForm.value
  if (!f.positionId || !f.interviewerId || !f.startTime) return notify('请选择岗位、面试官并填写面试时间')
  try {
    const res = await inviteInterview({
      candidateId: Number(talentId.value),
      positionId: f.positionId,
      interviewerId: f.interviewerId,
      startTime: f.startTime.replace('T', ' ') + ':00',
      durationMin: f.durationMin
    })
    notify(res.data?.message || res.msg || '下一阶段已排期')
    inviteOpen.value = false
    await load()
  } catch (e) { /* 拦截器已提示 */ }
}

// 阶段流转
const advanceOpen = ref(false)
const nextStatus = ref('')

function openAdvance() {
  nextStatus.value = detail.value?.status != null ? String(detail.value.status) : ''
  advanceOpen.value = true
}

async function submitAdvance() {
  if (nextStatus.value === '') return notify('请选择目标阶段状态')
  try {
    const res = await updateTalentStatus([Number(talentId.value)], Number(nextStatus.value))
    notify(res.data?.message || '阶段已更新')
    advanceOpen.value = false
    await load()
  } catch (e) { /* 拦截器已提示 */ }
}

onMounted(load)
</script>

<template>
  <div class="page process-page">
    <button class="back" @click="router.push('/enterprise/candidates')"><ArrowLeft :size="15"/>返回候选人列表</button>

    <div v-if="loading" class="card state-card">正在加载候选人流程数据…</div>

    <div v-else-if="!detail" class="card state-card empty">
      <FileText :size="28"/>
      <b>候选人不存在</b>
      <p>该候选人可能已被归档或不属于当前企业。</p>
      <button class="btn" @click="router.push('/enterprise/candidates')">返回候选人列表</button>
    </div>

    <template v-else>
      <section class="card candidate-head">
        <div>
          <h1>
            <MiniAvatar :name="detail.name" :size="30" color="#635b9b"/>
            {{ detail.name || '未知候选人' }}
            <span class="pill" :class="statusInfo[1]">{{ statusInfo[0] }}</span>
          </h1>
          <p>
            {{ mainPosition }} · 投递编号 TAL-{{ detail.talentId }}
            <template v-if="detail.matchedScore != null"> · 匹配度 {{ Math.round(Number(detail.matchedScore)) }}%</template>
          </p>
        </div>
        <div class="head-actions">
          <button class="btn" @click="resumeOpen = true"><FileText :size="15"/>查看简历</button>
          <button class="btn" @click="router.push('/enterprise/screening')"><Sparkles :size="15"/>AI 初筛</button>
          <button class="btn primary" @click="openInvite"><CalendarPlus :size="15"/>安排当前阶段</button>
        </div>
      </section>

      <div class="process-grid">
        <section class="card timeline-card">
          <header>
            <div>
              <h2>面试流程时间线</h2>
              <p>共 {{ timeline.length }} 场面试安排，已完成 {{ completedCount }} 场</p>
            </div>
            <button class="btn sm" @click="openAdvance"><GitBranch :size="14"/>推进流程</button>
          </header>

          <div v-if="!timeline.length" class="timeline-empty">
            <Clock3 :size="22"/>
            <b>暂无面试安排</b>
            <p>点击「安排当前阶段」为候选人创建第一场面试。</p>
          </div>

          <div v-else class="timeline">
            <article v-for="(item, index) in timeline" :key="item.appointmentId" :class="['timeline-item', item.stage]">
              <span class="node">
                <CheckCircle2 v-if="item.stage === 'completed'" :size="15"/>
                <Clock3 v-else-if="item.stage === 'active'" :size="15"/>
                <span v-else>{{ index + 1 }}</span>
              </span>
              <div class="timeline-content">
                <div class="item-title">
                  <h3>{{ item.stageName || '面试' }}</h3>
                  <span class="pill" :class="item.statusCls">{{ item.statusText }}</span>
                </div>
                <p>{{ item.startTime || '待定' }}<template v-if="item.endTime"> - {{ item.endTime }}</template> · 面试官 {{ item.interviewerName || '待定' }}</p>
                <div class="focus"><b>{{ item.positionTitle || '—' }}</b><span v-if="item.sessionId">会话 SES-{{ item.sessionId }}</span></div>
              </div>
            </article>
          </div>
        </section>

        <aside class="right-stack">
          <section class="card snapshot-card">
            <div class="section-title"><span>当前阶段状态</span><span class="pill">{{ detail.currentRound ? `第 ${detail.currentRound} 轮` : '未开始' }}</span></div>
            <strong>{{ statusInfo[0] }}</strong>
            <p>{{ mainPosition }}</p>
            <div class="status-box">
              <Clock3 :size="15"/>
              <div>
                <b>{{ timeline.find(i => i.stage === 'active')?.stageName || '等待安排面试' }}</b>
                <small>{{ timeline.find(i => i.stage === 'active')?.startTime || '暂无待进行的面试场次' }}</small>
              </div>
            </div>
          </section>

          <section class="card transfer-card">
            <div class="section-title"><span>简历与联系方式</span><History :size="16"/></div>
            <div class="transfer-item"><span>手机号</span><b>{{ detail.phone || '未填写' }}</b></div>
            <div class="transfer-item"><span>邮箱</span><b>{{ detail.email || '未填写' }}</b></div>
            <div class="transfer-item"><span>简历完整度</span><b>{{ resume?.integrity != null ? resume.integrity + '%' : '—' }}</b><small v-if="resume?.missingFields?.length">缺失：{{ resume.missingFields.join('、') }}</small></div>
            <div class="transfer-item muted"><span>技能标签</span><b>{{ (resume?.skills || []).map(s => s.name).join('、') || '暂无技能标签' }}</b></div>
          </section>

          <section class="card history-card">
            <div class="section-title"><span>候选人标签</span><span class="pill gray">{{ (detail.tags || []).length }} 个</span></div>
            <ul v-if="(detail.tags || []).length">
              <li v-for="tag in detail.tags" :key="tag.name"><CheckCircle2 :size="14"/><span>{{ tag.name }}</span><time>来源 {{ tag.source ?? '—' }}</time></li>
            </ul>
            <p v-else class="tags-empty">该候选人暂无标签</p>
          </section>
        </aside>
      </div>
    </template>

    <BaseModal v-if="resumeOpen" title="简历详情" width="560px" @close="resumeOpen = false">
      <div class="resume-body">
        <template v-if="resume">
          <div class="resume-block">
            <b>教育经历</b>
            <div v-for="(edu, i) in resume.educationList" :key="'edu' + i" class="resume-row">
              <span>{{ edu.school }} · {{ edu.major }} · {{ edu.degree }}</span>
              <small>{{ edu.startDate || '—' }} ~ {{ edu.endDate || '—' }}</small>
            </div>
            <p v-if="!resume.educationList?.length" class="resume-empty">暂无教育经历</p>
          </div>
          <div class="resume-block">
            <b>工作经历</b>
            <div v-for="(work, i) in resume.workList" :key="'work' + i" class="resume-row">
              <span>{{ work.company }} · {{ work.position }}</span>
              <small>{{ work.startDate || '—' }} ~ {{ work.endDate || '—' }}</small>
              <p v-if="work.summary">{{ work.summary }}</p>
            </div>
            <p v-if="!resume.workList?.length" class="resume-empty">暂无工作经历</p>
          </div>
          <div class="resume-block">
            <b>项目经历</b>
            <div v-for="(prj, i) in resume.projectList" :key="'prj' + i" class="resume-row">
              <span>{{ prj.name }}<template v-if="prj.role"> · {{ prj.role }}</template></span>
              <small>{{ prj.techStack || '—' }}</small>
              <p v-if="prj.summary">{{ prj.summary }}</p>
            </div>
            <p v-if="!resume.projectList?.length" class="resume-empty">暂无项目经历</p>
          </div>
          <div class="resume-block">
            <b>技能</b>
            <div class="skill-tags">
              <span v-for="(skl, i) in resume.skills" :key="'skl' + i">{{ skl.name }}</span>
            </div>
            <p v-if="!resume.skills?.length" class="resume-empty">暂无技能标签</p>
          </div>
        </template>
        <p v-else class="resume-empty">简历数据加载失败</p>
      </div>
      <template #footer><button class="btn primary" @click="resumeOpen = false">关闭</button></template>
    </BaseModal>

    <BaseModal v-if="inviteOpen" title="安排下一阶段面试" width="480px" @close="inviteOpen = false">
      <div class="form-grid">
        <label>目标岗位</label>
        <select v-model="inviteForm.positionId" class="input">
          <option value="">请选择岗位</option>
          <option v-for="p in positions" :key="p.posId" :value="p.posId">{{ p.title }}</option>
        </select>
        <label>面试官</label>
        <select v-model="inviteForm.interviewerId" class="input">
          <option value="">请选择面试官</option>
          <option v-for="m in members" :key="m.userId" :value="m.userId">{{ m.nickName || m.userName }}</option>
        </select>
        <label>面试时间</label>
        <input v-model="inviteForm.startTime" class="input" type="datetime-local"/>
        <label>面试时长</label>
        <select v-model.number="inviteForm.durationMin" class="input">
          <option :value="30">30 分钟</option>
          <option :value="45">45 分钟</option>
          <option :value="60">60 分钟</option>
        </select>
      </div>
      <template #footer>
        <button class="btn" @click="inviteOpen = false">取消</button>
        <button class="btn primary" @click="submitInvite">确认排期</button>
      </template>
    </BaseModal>

    <BaseModal v-if="advanceOpen" title="推进候选人流程阶段" width="400px" @close="advanceOpen = false">
      <div class="form-grid">
        <label>目标阶段</label>
        <select v-model="nextStatus" class="input">
          <option value="">请选择目标阶段</option>
          <option v-for="s in STATUS_OPTIONS" :key="s.value" :value="String(s.value)">{{ s.label }}</option>
        </select>
      </div>
      <template #footer>
        <button class="btn" @click="advanceOpen = false">取消</button>
        <button class="btn primary" @click="submitAdvance">确认推进</button>
      </template>
    </BaseModal>

    <ToastMessage :message="toast"/>
  </div>
</template>

<style scoped>
.process-page{padding-bottom:28px}.back{border:0;background:transparent;color:#6f7f99;display:flex;align-items:center;gap:5px;font-size:11px;padding:0;margin-bottom:9px}.candidate-head{padding:19px 21px;display:flex;align-items:center;justify-content:space-between;margin-bottom:15px}.candidate-head h1{font-size:22px;display:flex;gap:9px;align-items:center}.candidate-head p{font-size:10px;color:#7a8ba3;margin-top:7px}.head-actions{display:flex;gap:8px}.process-grid{display:grid;grid-template-columns:minmax(650px,1.35fr) minmax(320px,.65fr);gap:15px}.timeline-card{padding:19px}.timeline-card header{display:flex;justify-content:space-between;align-items:flex-start}.timeline-card h2{font-size:18px}.timeline-card header p{font-size:9px;color:#95a3b6;margin-top:5px}.timeline{margin-top:20px;position:relative}.timeline:before{content:'';position:absolute;left:18px;top:22px;bottom:22px;border-left:1px dashed #bfd0e8}.timeline-item{display:flex;gap:14px;position:relative;padding-bottom:19px}.node{width:37px;height:37px;border-radius:50%;display:grid;place-items:center;flex:none;background:#eef2f7;color:#8a9ab0;z-index:1;font-size:11px}.timeline-item.completed .node{background:#e4f8ef;color:#0b9c6c}.timeline-item.active .node{background:#2563eb;color:#fff;box-shadow:0 0 0 5px #eaf1ff}.timeline-content{flex:1;border:1px solid #e3eaf3;border-radius:10px;padding:11px 13px}.timeline-item.active .timeline-content{border-color:#b8d2ff;background:#f8fbff}.item-title{display:flex;align-items:center;gap:8px}.item-title h3{font-size:13px}.timeline-content>p{font-size:9px;color:#8594a9;margin-top:5px}.focus{display:flex;gap:7px;align-items:center;margin-top:9px;padding:6px 8px;background:#edf4ff;border-radius:6px;font-size:9px;color:#587093}.focus b{color:#2563eb}.timeline-empty{display:flex;flex-direction:column;align-items:center;gap:6px;padding:40px 0;color:#8291a5}.timeline-empty b{font-size:13px;color:#334155}.timeline-empty p{font-size:10px}.state-card{padding:34px;text-align:center;color:#64748b;font-size:12px}.state-card.empty{display:flex;flex-direction:column;align-items:center;gap:8px}.state-card.empty b{font-size:14px;color:#334155}.state-card.empty p{font-size:10px;color:#8291a5}.right-stack{display:flex;flex-direction:column;gap:15px}.snapshot-card,.transfer-card,.history-card{padding:17px}.snapshot-card>.section-title{margin-bottom:14px}.snapshot-card>strong{font-size:19px}.snapshot-card>p{font-size:9px;color:#7d8da4;margin-top:5px}.status-box{display:flex;gap:8px;align-items:center;margin-top:15px;padding:10px;background:#fff4df;border:1px solid #fde3b7;border-radius:9px;color:#ed8506}.status-box b,.status-box small{display:block}.status-box b{font-size:11px}.status-box small{font-size:8px;color:#8e795d;margin-top:3px}.transfer-card>.section-title svg{color:#2563eb}.transfer-item{padding:10px 0;border-bottom:1px solid #e8edf4}.transfer-item:last-child{border-bottom:0}.transfer-item span,.transfer-item b,.transfer-item small{display:block}.transfer-item span{font-size:9px;color:#91a0b4}.transfer-item b{font-size:11px;margin-top:4px;word-break:break-all}.transfer-item small{font-size:8px;color:#a0adbd;margin-top:4px}.transfer-item.muted{opacity:.58}.history-card ul{list-style:none;padding:0;margin:12px 0 0}.history-card li{display:grid;grid-template-columns:20px 1fr auto;gap:6px;align-items:center;padding:9px 0;border-bottom:1px solid #e8edf4;color:#627690;font-size:9px}.history-card li svg{color:#2563eb}.history-card time{color:#9ba8b9;font-size:8px}.tags-empty{font-size:10px;color:#9ba8b9;margin-top:12px}.resume-body{display:flex;flex-direction:column;gap:14px;max-height:52vh;overflow:auto}.resume-block b{font-size:11px;color:#334155}.resume-row{padding:8px 0;border-bottom:1px solid #eef2f7;font-size:10px;color:#5f7089}.resume-row span{display:block}.resume-row small{display:block;font-size:9px;color:#95a3b6;margin-top:3px}.resume-row p{font-size:9px;color:#7b8ba3;line-height:1.6;margin-top:5px;white-space:pre-line}.resume-empty{font-size:10px;color:#9ba8b9;margin-top:8px}.skill-tags{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px}.skill-tags span{padding:3px 8px;background:#edf4ff;color:#2563eb;border-radius:6px;font-size:9px}.form-grid{display:flex;flex-direction:column;gap:6px}.form-grid label{font-size:10px;color:#63758f;margin-top:6px}
</style>
