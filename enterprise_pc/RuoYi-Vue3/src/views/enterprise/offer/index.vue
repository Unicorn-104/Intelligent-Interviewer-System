<script setup>
import { ref, onMounted } from 'vue'
import { Plus, Send, FileText, Mail, CircleCheck, Timer, Users, Building2, UserRound, ChevronRight, AlertTriangle, BriefcaseBusiness } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listOffers, getOffer, createOffer, sendOffer, listCandidateOptions, getMailProfile } from '@/api/offer'
import { listJobs } from '@/api/system/job'

const toast = ref('')
const loading = ref(false)
const offers = ref([])
const total = ref(0)
const pageNum = ref(1)
const pageSize = 10
const statusFilter = ref('')

// Offer 状态（t_off_offer.ofr_status）：0-已发送，1-已接受，2-已拒绝，3-已过期，4-草稿，5-审批中，6-已撤回
const STATUS = { 0: ['已发送', ''], 1: ['已接受', 'green'], 2: ['已拒绝', 'red'], 3: ['已过期', 'gray'], 4: ['草稿', 'orange'], 5: ['审批中', 'purple'], 6: ['已撤回', 'gray'] }
// 审批状态（t_off_offer.ofr_approval_status）：0-未审批，1-审批中，2-已通过，3-已拒绝
const APPROVAL = { 0: ['未审批', 'gray'], 1: ['审批中', 'purple'], 2: ['已通过', 'green'], 3: ['已拒绝', 'red'] }
// 审批节点状态（t_offer_approval.oap_status）：0-待审批，1-已通过，2-已拒绝，3-已转交
const NODE = { 0: ['待审批', 'orange'], 1: ['已通过', 'green'], 2: ['已拒绝', 'red'], 3: ['已转交', 'gray'] }

const detail = ref(null)
const createOpen = ref(false)
const candidates = ref([])
const positions = ref([])
const form = ref({ candidateId: '', positionId: '', salaryOffer: '', jobGrade: '', benefits: '', onboardDate: '', deadline: '' })
const sending = ref(0)

// 发送前选择发信账号（企业邮箱 / 个人邮箱）
const senderOpen = ref(false)
const senderRow = ref(null)
const senderType = ref('company')
const mailProfile = ref(null)

function notify(msg) { toast.value = msg; setTimeout(() => toast.value = '', 2600) }

async function load() {
  loading.value = true
  try {
    const query = { pageNum: pageNum.value, pageSize }
    if (statusFilter.value !== '') query.status = statusFilter.value
    const res = await listOffers(query)
    offers.value = res.rows || []
    total.value = res.total || 0
  } catch (e) {
    offers.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

function changeStatus() { pageNum.value = 1; load() }
function step(delta) {
  const next = pageNum.value + delta
  if (next < 1 || (next - 1) * pageSize >= total.value) return
  pageNum.value = next
  load()
}

async function openDetail(row) {
  try {
    const res = await getOffer(row.offerId)
    detail.value = res.data
  } catch (e) { /* 拦截器已提示 */ }
}

async function openSender(row) {
  senderRow.value = row
  senderType.value = 'company'
  senderOpen.value = true
  if (!mailProfile.value) {
    try {
      const res = await getMailProfile()
      mailProfile.value = res.data
    } catch (e) { mailProfile.value = null }
  }
}

async function confirmSend() {
  const row = senderRow.value
  sending.value = row.offerId
  senderOpen.value = false
  try {
    const res = await sendOffer(row.offerId, senderType.value)
    notify(res.data?.message || res.msg || '发送完成')
    await load()
  } catch (e) { /* 拦截器已提示 */ } finally {
    sending.value = 0
  }
}

async function openCreate() {
  createOpen.value = true
  if (!candidates.value.length) {
    try {
      const res = await listCandidateOptions()
      candidates.value = res.data || []
    } catch (e) { candidates.value = [] }
  }
  if (!positions.value.length) {
    try {
      const res = await listJobs({ pageNum: 1, pageSize: 200 })
      positions.value = res.rows || []
    } catch (e) { positions.value = [] }
  }
}

async function submitCreate() {
  if (!form.value.candidateId || !form.value.positionId) return notify('请选择候选人与岗位')
  if (!form.value.salaryOffer) return notify('请填写薪资报价')
  try {
    const res = await createOffer({ ...form.value, deadline: form.value.deadline ? form.value.deadline.replace('T', ' ') : '' })
    notify(res.data?.message || 'Offer 草稿已创建')
    createOpen.value = false
    form.value = { candidateId: '', positionId: '', salaryOffer: '', jobGrade: '', benefits: '', onboardDate: '', deadline: '' }
    pageNum.value = 1
    await load()
  } catch (e) { /* 拦截器已提示 */ }
}

onMounted(load)
</script>

<template>
  <div class="page offer-page">
    <div class="page-heading">
      <div><h1>Offer 管理</h1><p>录用意向书创建、审批状态跟踪与入职指引发送 · 共 {{ total }} 条 Offer</p></div>
      <button class="btn primary" @click="openCreate"><Plus :size="15" />创建 Offer</button>
    </div>

    <section class="card list-card">
      <div class="toolbar">
        <select v-model="statusFilter" class="select status-select" @change="changeStatus">
          <option value="">全部状态</option>
          <option value="0">已发送</option>
          <option value="1">已接受</option>
          <option value="2">已拒绝</option>
          <option value="3">已过期</option>
          <option value="4">草稿</option>
          <option value="5">审批中</option>
          <option value="6">已撤回</option>
        </select>
        <span class="toolbar-tip"><Timer :size="13" />数据按当前企业隔离展示</span>
      </div>

      <div v-if="loading" class="empty">加载中…</div>
      <div v-else-if="!offers.length" class="empty">
        <FileText :size="26" />
        <p>暂无 Offer 数据，点击右上角「创建 Offer」发起录用意向</p>
      </div>
      <div v-else class="offer-table">
        <div class="table-head"><span>候选人</span><span>录用岗位</span><span>薪资 / 职级</span><span>入职日期</span><span>回复截止</span><span>Offer 状态</span><span>审批状态</span><span>时间</span><span>操作</span></div>
        <article v-for="row in offers" :key="row.offerId" class="table-row">
          <div class="person">
            <MiniAvatar :name="row.candidateName || '?'" :size="32" color="#635bff" />
            <div><b>{{ row.candidateName || '未知候选人' }}</b><small>Offer #{{ row.offerId }}</small></div>
          </div>
          <span class="pos-cell"><BriefcaseBusiness :size="12" />{{ row.positionTitle || '岗位已删除' }}</span>
          <div class="salary-cell"><strong>{{ row.salaryOffer || '—' }}</strong><small v-if="row.jobGrade">{{ row.jobGrade }}</small></div>
          <span>{{ row.onboardDate || '—' }}</span>
          <span>{{ row.deadline || '—' }}</span>
          <span class="pill" :class="STATUS[row.status]?.[1]">{{ STATUS[row.status]?.[0] || '未知' }}</span>
          <span class="pill" :class="APPROVAL[row.approvalStatus]?.[1]">{{ APPROVAL[row.approvalStatus]?.[0] || '未审批' }}</span>
          <time>{{ row.sentAt }}</time>
          <div class="ops">
            <button @click="openDetail(row)"><FileText :size="13" />详情</button>
            <button v-if="row.status === 4" :disabled="sending === row.offerId" @click="openSender(row)">
              <Mail :size="13" />{{ sending === row.offerId ? '发送中' : '发送' }}
            </button>
          </div>
        </article>
      </div>

      <div v-if="total > pageSize" class="pager">
        <button class="btn sm" :disabled="pageNum <= 1" @click="step(-1)"><ChevronRight :size="13" style="transform:rotate(180deg)" />上一页</button>
        <span>{{ pageNum }} / {{ Math.ceil(total / pageSize) }} 页 · 共 {{ total }} 条</span>
        <button class="btn sm" :disabled="pageNum * pageSize >= total" @click="step(1)">下一页<ChevronRight :size="13" /></button>
      </div>
    </section>

    <!-- 详情：基本信息 + 审批节点跟踪（t_offer_approval） -->
    <BaseModal v-if="detail" title="Offer 详情与审批跟踪" width="560px" @close="detail = null">
      <div class="detail-grid">
        <div class="d-item"><label><UserRound :size="12" />候选人</label><b>{{ detail.candidateName || '—' }}</b></div>
        <div class="d-item"><label><BriefcaseBusiness :size="12" />录用岗位</label><b>{{ detail.positionTitle || '—' }}</b></div>
        <div class="d-item"><label><Users :size="12" />薪资报价</label><b>{{ detail.salaryOffer || '—' }}</b></div>
        <div class="d-item"><label><Building2 :size="12" />职级</label><b>{{ detail.jobGrade || '—' }}</b></div>
        <div class="d-item"><label><Timer :size="12" />预计入职</label><b>{{ detail.onboardDate || '—' }}</b></div>
        <div class="d-item"><label><Timer :size="12" />回复截止</label><b>{{ detail.deadline || '—' }}</b></div>
        <div class="d-item full"><label>福利说明</label><b>{{ detail.benefits || '—' }}</b></div>
        <div class="d-item"><label>Offer 状态</label><span class="pill" :class="STATUS[detail.status]?.[1]">{{ STATUS[detail.status]?.[0] }}</span></div>
        <div class="d-item"><label>审批状态</label><span class="pill" :class="APPROVAL[detail.approvalStatus]?.[1]">{{ APPROVAL[detail.approvalStatus]?.[0] || '未审批' }}</span></div>
        <div v-if="detail.withdrawReason" class="d-item full"><label><AlertTriangle :size="12" />撤回原因</label><b>{{ detail.withdrawReason }}</b></div>
      </div>
      <div class="approval-block">
        <h3><CircleCheck :size="15" />审批节点跟踪</h3>
        <div v-if="!detail.approvals || !detail.approvals.length" class="empty sm">暂无审批节点</div>
        <ol v-else>
          <li v-for="node in detail.approvals" :key="node.approvalId">
            <i :class="'dot-' + node.status"></i>
            <div class="node-main"><b>{{ node.nodeName }}</b><span class="pill sm" :class="NODE[node.status]?.[1]">{{ NODE[node.status]?.[0] }}</span></div>
            <small>{{ node.approverName || '待指派' }} · {{ node.approvedAt || '未处理' }}<template v-if="node.comment"> · {{ node.comment }}</template></small>
          </li>
        </ol>
      </div>
      <template #footer>
        <button v-if="detail.status === 4" class="btn primary" @click="openSender(detail); detail = null"><Send :size="14" />发送录用意向书与入职指引</button>
        <button class="btn" @click="detail = null">关闭</button>
      </template>
    </BaseModal>

    <!-- 创建 Offer 草稿 -->
    <BaseModal v-if="createOpen" title="创建 Offer" width="520px" @close="createOpen = false">
      <div class="form-grid">
        <div class="f-item"><label>候选人 *</label>
          <select v-model="form.candidateId" class="select">
            <option value="">请选择候选人</option>
            <option v-for="c in candidates" :key="c.talentId" :value="c.talentId">{{ c.name }}（ID {{ c.talentId }}）</option>
          </select>
        </div>
        <div class="f-item"><label>录用岗位 *</label>
          <select v-model="form.positionId" class="select">
            <option value="">请选择岗位</option>
            <option v-for="p in positions" :key="p.posId" :value="p.posId">{{ p.title }}</option>
          </select>
        </div>
        <div class="f-item"><label>薪资报价 *</label><input v-model="form.salaryOffer" class="input" placeholder="如 15-20K·14薪" /></div>
        <div class="f-item"><label>职级</label><input v-model="form.jobGrade" class="input" placeholder="如 P6" /></div>
        <div class="f-item"><label>预计入职日期</label><input v-model="form.onboardDate" type="date" class="input" /></div>
        <div class="f-item"><label>回复截止时间</label><input v-model="form.deadline" type="datetime-local" class="input" /></div>
        <div class="f-item full"><label>福利说明</label><textarea v-model="form.benefits" class="textarea" rows="3" placeholder="五险一金、年度体检、补充商业保险等"></textarea></div>
      </div>
      <template #footer>
        <button class="btn" @click="createOpen = false">取消</button>
        <button class="btn primary" @click="submitCreate"><Plus :size="14" />创建草稿</button>
      </template>
    </BaseModal>

    <!-- 发送前选择发信账号 -->
    <BaseModal v-if="senderOpen" title="选择发信账号" width="460px" @close="senderOpen = false">
      <p class="sender-tip">向候选人 {{ senderRow?.candidateName }} 发送录用意向书与入职指引，请选择使用哪个邮箱发出：</p>
      <div class="sender-options">
        <label class="sender-opt" :class="{ active: senderType === 'company' }">
          <input v-model="senderType" type="radio" value="company" />
          <div>
            <b>企业邮箱</b>
            <small>{{ mailProfile?.companyEmail || '读取中…' }}</small>
            <small class="sub">使用企业统一 SMTP 通道发送</small>
          </div>
        </label>
        <label class="sender-opt" :class="{ active: senderType === 'personal', disabled: mailProfile && !mailProfile.configured }">
          <input v-model="senderType" type="radio" value="personal" :disabled="mailProfile && !mailProfile.configured" />
          <div>
            <b>个人邮箱</b>
            <small v-if="mailProfile?.configured">{{ mailProfile.username }}（{{ mailProfile.smtpHost }}:{{ mailProfile.smtpPort }}）</small>
            <small v-else-if="mailProfile">未配置，请先到「个人资料 → 邮箱与发信设置」完成 SMTP 配置</small>
            <small v-else>读取配置中…</small>
          </div>
        </label>
      </div>
      <template #footer>
        <button class="btn" @click="senderOpen = false">取消</button>
        <button class="btn primary" @click="confirmSend"><Send :size="14" />确认发送</button>
      </template>
    </BaseModal>

    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.offer-page{padding-bottom:25px}
.list-card{padding:17px}
.toolbar{display:flex;align-items:center;gap:10px;padding-bottom:13px;border-bottom:1px solid #e5ebf3}
.status-select{width:150px}
.toolbar-tip{display:flex;align-items:center;gap:5px;color:#8da0ba;font-size:10px;margin-left:auto}
.offer-table{margin-top:10px}
.table-head,.table-row{display:grid;grid-template-columns:1.5fr 1.25fr 1fr .85fr .95fr .72fr .72fr .9fr .95fr;gap:8px;align-items:center}
.table-head{height:34px;padding:0 8px;background:#f6f8fb;color:#8593a7;font-size:9px}
.table-row{min-height:64px;padding:8px;border-bottom:1px solid #e8edf4;font-size:10px;color:#5e718c}
.person{display:flex;align-items:center;gap:8px;min-width:0}
.person b,.person small{display:block}
.person b{font-size:12px;color:#1e293b}
.person small{color:#7f8ea3;font-size:9px;margin-top:3px}
.pos-cell{display:flex;align-items:center;gap:4px;color:#334155}
.salary-cell strong{display:block;color:#2563eb;font-size:11px}
.salary-cell small{color:#7f8ea3;font-size:9px}
.table-row time{color:#8d9aae;font-size:9px}
.ops{display:flex;gap:6px}
.ops button{border:0;background:transparent;color:#2563eb;font-size:9px;display:flex;gap:3px;align-items:center;padding:3px 0;cursor:pointer}
.ops button:disabled{color:#a4b0c2}
.pager{display:flex;align-items:center;justify-content:center;gap:14px;padding-top:14px;color:#718198;font-size:10px}
.pager .btn{gap:4px}
.pager button:disabled{opacity:.5}
.empty{color:#a4b0c2;text-align:center;padding:40px;font-size:11px}
.empty.sm{padding:14px;font-size:10px}
.empty svg{display:block;margin:0 auto 8px}
.detail-grid{display:grid;grid-template-columns:1fr 1fr;gap:11px}
.d-item{background:#f7f9fc;border-radius:9px;padding:10px 12px}
.d-item.full{grid-column:1/-1}
.d-item label{display:flex;align-items:center;gap:4px;font-size:9px;color:#8da0ba;margin-bottom:4px}
.d-item b{font-size:12px;color:#1e293b;font-weight:500;line-height:1.5}
.approval-block{margin-top:16px;border-top:1px dashed #e2e8f0;padding-top:13px}
.approval-block h3{display:flex;align-items:center;gap:6px;font-size:13px;color:#334155;margin-bottom:10px}
.approval-block ol{list-style:none;display:flex;flex-direction:column;gap:9px}
.approval-block li{display:flex;align-items:flex-start;gap:9px;position:relative;padding-left:2px}
.approval-block li i{width:9px;height:9px;border-radius:50%;background:#cbd5e1;margin-top:5px;flex-shrink:0}
.approval-block li i.dot-0{background:#f59e0b}
.approval-block li i.dot-1{background:#10b981}
.approval-block li i.dot-2{background:#ef4444}
.approval-block li i.dot-3{background:#94a3b8}
.node-main{display:flex;align-items:center;gap:8px}
.node-main b{font-size:12px;color:#1e293b}
.pill.sm{height:19px;font-size:9px;padding:0 7px}
.approval-block li small{display:block;color:#8d9aae;font-size:9px;margin-top:2px}
.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.f-item.full{grid-column:1/-1}
.f-item label{display:block;font-size:10px;color:#718198;margin-bottom:5px}
.textarea{padding:9px 12px;font-size:12px;resize:vertical;font-family:inherit}
.sender-tip{font-size:11px;color:#5e718c;margin-bottom:12px}
.sender-options{display:flex;flex-direction:column;gap:10px}
.sender-opt{display:flex;gap:10px;align-items:flex-start;border:1px solid #e2e8f0;border-radius:10px;padding:12px 14px;cursor:pointer}
.sender-opt.active{border-color:#2563eb;background:#f5f8ff}
.sender-opt.disabled{opacity:.6;cursor:not-allowed}
.sender-opt input{margin-top:3px;accent-color:#2563eb}
.sender-opt b{display:block;font-size:12px;color:#1e293b}
.sender-opt small{display:block;color:#7f8ea3;font-size:10px;margin-top:3px}
.sender-opt small.sub{color:#a4b0c2}
</style>
