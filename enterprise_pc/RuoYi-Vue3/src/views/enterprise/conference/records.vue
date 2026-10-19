<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  Search, Download, Play, Eye, Archive, KeyRound, Database,
  AlertTriangle, ShieldCheck, Clock3, Video
} from '@/views/enterprise/components/icons'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import {
  listRecordings, getStorageUsage, getStoragePolicy, saveStoragePolicy,
  sendDownloadCode, verifyDownloadCode, getPlayback, updateRecordingAccess
} from '@/api/system/conference'

const router = useRouter()
const route = useRoute()
// 来自消息中心「查看录制」时携带的候选人用户ID，用于按候选人精确筛选其全部面试录制
const candidateUserId = ref(route.query.candidateUserId || null)
const toast = ref('')

const filters = ref({ id: '', candidate: '', from: '', to: '' })
const applied = ref({ id: '', candidate: '', from: '', to: '' })

// 录制列表：全部来自后端真实数据
const records = ref([])

const filtered = computed(() => records.value.filter((item) => {
  const f = applied.value
  if (f.id && !item.id.toLowerCase().includes(f.id.toLowerCase())) return false
  if (f.candidate && !item.candidate.includes(f.candidate)) return false
  if (f.from && item.date < f.from) return false
  if (f.to && item.date > f.to) return false
  return true
}))

const storage = ref({ used: 0, total: 0 })
const storagePercent = computed(() => storage.value.total ? Math.round((storage.value.used / storage.value.total) * 100) : 0)

// 已用/剩余容量按量级自适应显示，避免不足 1GB 时恒显示为 0 GB
function fmtStorage(gb) {
  const n = Number(gb) || 0
  if (n >= 1) return `${n.toFixed(1)} GB`
  const mb = n * 1024
  return mb >= 1 ? `${mb.toFixed(1)} MB` : `${Math.round(mb * 1024)} KB`
}

// 已用容量优先用真实字节数（与列表「占用」列口径一致），无字节数时回落到 GB 值
function fmtUsed() {
  const bytes = storage.value.usedBytes
  return bytes > 0 ? fmtSize(0, bytes) : fmtStorage(storage.value.used)
}

const verifyVisible = ref(false)
const policyVisible = ref(false)
const authVisible = ref(false)
const pendingDownload = ref(null)
const smsCode = ref('')
// 后端未接入短信通道时会返回 devCode，暂在弹窗内提示以便本地联调（接入短信后删除）
const devCode = ref('')

const policy = ref({ keepDays: 0, maxStorage: 0 })
// 访问级别取值与后端 ses_rec_access_level 一致：1-仅HR/面试官，2-含管理员，3-候选人可见
const auth = ref({ validDays: 7, level: 1 })

const detailVisible = ref(false)
const detailLoading = ref(false)
const detail = ref(null)

const STATUS_TEXT = { 0: '录制中', 1: '已完成', 2: '异常终止' }
// 面试模式与后端 ses_mode 一致：1-纯AI，2-AI+单面试官，3-AI+多面试官，4-无AI纯人工
const MODE_TEXT = { 1: '纯 AI 面试', 2: 'AI + HR 协同', 3: 'AI + HR 协同', 4: '无 AI 纯人工' }
const ACCESS_TEXT = { 1: '仅HR/面试官', 2: '含管理员', 3: '候选人可见' }

// 录制地址可能是后端相对路径（/profile/...），补上接口前缀后才能被浏览器直接访问
function resolveRecUrl(u) {
  if (!u) return ''
  return /^https?:\/\//i.test(u) ? u : import.meta.env.VITE_APP_BASE_API + u
}

function downloadFile(url, filename) {
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.target = '_blank'
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
}

// 详情弹窗内直接下载（详情接口已做录制访问校验，无需再走短信验证）
function downloadDetail() {
  const url = resolveRecUrl(detail.value?.recUrl)
  if (!url) return notify('该场次暂无录制地址，无法下载')
  const ext = (url.split('?')[0].split('.').pop() || 'mp4').toLowerCase()
  downloadFile(url, `${detail.value.sessionId}.${ext}`)
}

function fmtDuration(sec) {
  const v = Math.max(0, Math.floor(sec || 0))
  if (!v) return '—'
  const m = String(Math.floor(v / 60)).padStart(2, '0')
  const s = String(v % 60).padStart(2, '0')
  return `${m}:${s}`
}

// 真实字节数格式化；无字节数（历史数据）时按 1500 Kbps 码率由时长估算
function fmtSize(sec, bytes) {
  if (bytes > 0) {
    const gb = bytes / 1024 ** 3
    if (gb >= 1) return `${gb.toFixed(1)} GB`
    const mb = bytes / 1024 ** 2
    return mb >= 1 ? `${mb.toFixed(1)} MB` : `${Math.round(bytes / 1024)} KB`
  }
  if (!sec) return '—'
  const gb = (sec * 1500 * 1000 / 8) / 1024 ** 3
  return `${gb.toFixed(1)} GB`
}

// 后端录制数据 -> 页面展示结构（每条录制记录对应一次录制，编号由后端生成且唯一）
function mapRecord(item) {
  const date = item.interviewDate || ''
  return {
    rid: item.recordingId,
    sid: item.sessionId,
    id: item.code || `REC-${date.replaceAll('-', '')}-${String(item.sessionId).padStart(3, '0')}`,
    candidate: item.candidateName,
    position: item.positionTitle,
    date,
    duration: fmtDuration(item.durationSec),
    size: fmtSize(item.durationSec, item.recSizeBytes),
    status: STATUS_TEXT[item.status] || '已完成',
    mode: MODE_TEXT[item.mode] || '—'
  }
}

function notify(msg) {
  toast.value = msg
  setTimeout(() => (toast.value = ''), 2200)
}

// 初始化拉取录制列表 / 存储用量 / 存储策略，无数据时保持空态
async function initPage() {
  // 从消息中心跳转进入时，候选人输入框回显姓名作为提示，实际筛选以后端候选人ID为准
  if (candidateUserId.value && route.query.candidateName) filters.value.candidate = String(route.query.candidateName)
  try {
    const res = await listRecordings(candidateUserId.value ? { candidateUserId: candidateUserId.value } : {})
    if (Array.isArray(res.data)) records.value = res.data.map(mapRecord)
  } catch (e) {
    // 后端未就绪时保持空态
  }
  try {
    const u = await getStorageUsage()
    if (u.data && u.data.maxGb) storage.value = { used: u.data.usedGb, total: u.data.maxGb, usedBytes: u.data.usedBytes || 0 }
  } catch (e) {
    // 后端未就绪时保持空态
  }
  try {
    const p = await getStoragePolicy()
    if (p.data) {
      policy.value.keepDays = p.data.keepDays
      policy.value.maxStorage = p.data.maxStorageGb
      if (p.data.defaultAccessLevel) auth.value.level = p.data.defaultAccessLevel
    }
  } catch (e) {
    // 后端未就绪时保持空态
  }
}

onMounted(() => {
  initPage()
})

async function query() {
  // 按候选人ID筛选时，姓名仅作展示提示，实际筛选由后端候选人ID完成，避免姓名口径差异导致漏筛
  applied.value = { ...filters.value, candidate: candidateUserId.value ? '' : filters.value.candidate }
  try {
    // 面试 ID 是页面展示编号（REC-*），后端 sessionId 为数字主键，故只做本地过滤
    const params = {
      candidate: candidateUserId.value ? '' : filters.value.candidate,
      from: filters.value.from,
      to: filters.value.to
    }
    if (candidateUserId.value) params.candidateUserId = candidateUserId.value
    const res = await listRecordings(params)
    if (Array.isArray(res.data)) records.value = res.data.map(mapRecord)
  } catch (e) {
    // 查询失败时保留现有列表
  }
  notify(`查询完成，共 ${filtered.value.length} 条记录`)
}

function reset() {
  filters.value = { id: '', candidate: '', from: '', to: '' }
  applied.value = { ...filters.value }
  candidateUserId.value = null
}

// 按当前筛选结果导出真实 CSV（带 BOM，Excel 中文不乱码）
function exportList() {
  const rows = filtered.value
  if (!rows.length) return notify('当前没有可导出的记录')
  const header = ['面试 ID', '候选人', '岗位', '日期', '时长', '占用', '状态', '模式']
  const lines = rows.map((r) => [r.id, r.candidate, r.position, r.date, r.duration, r.size, r.status, r.mode])
  const csv = [header, ...lines]
    .map((cols) => cols.map((c) => `"${String(c ?? '').replaceAll('"', '""')}"`).join(','))
    .join('\r\n')
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  downloadFile(url, `录制文件列表_${new Date().toISOString().slice(0, 10)}.csv`)
  // 延迟释放，避免在下载真正开始前撤销 Blob URL 导致下载被取消
  setTimeout(() => URL.revokeObjectURL(url), 5000)
  notify(`已导出 ${rows.length} 条记录（CSV）`)
}

// 拉取该条录制的真实详情（含面试官、访问级别、时间轴打点）
async function openDetail(item) {
  if (item.rid == null) return notify('该记录没有对应的录制记录，无法查看详情')
  detail.value = null
  detailLoading.value = true
  detailVisible.value = true
  try {
    const res = await getPlayback(item.rid)
    detail.value = res.data || null
  } catch (e) {
    // 详情拉取失败时展示失败占位
  } finally {
    detailLoading.value = false
  }
}

function openDownload(item) {
  if (item.status === '录制中') return notify('该录制尚未完成，暂不可下载')
  if (item.status === '已过期') return notify('该录制已超过保留期限，已归档删除')
  pendingDownload.value = item
  smsCode.value = ''
  devCode.value = ''
  verifyVisible.value = true
  if (item.rid) {
    sendDownloadCode(item.rid)
      .then((res) => { devCode.value = res.data?.devCode || '' })
      .catch(() => {})
  }
}

async function confirmDownload() {
  if (smsCode.value.trim().length !== 6) return notify('请输入 6 位短信验证码')
  if (pendingDownload.value?.rid == null) return notify('该记录没有对应的录制记录，无法下载')
  try {
    const res = await verifyDownloadCode(pendingDownload.value.rid, smsCode.value.trim())
    const url = resolveRecUrl(res.data?.url)
    if (!url) return notify('后端未返回录制地址，无法下载')
    const ext = (url.split('?')[0].split('.').pop() || 'mp4').toLowerCase()
    downloadFile(url, `${pendingDownload.value.id}.${ext}`)
    verifyVisible.value = false
    notify(`验证通过，开始下载 ${pendingDownload.value.id}`)
  } catch (e) {
    notify('验证失败，请检查短信验证码')
  }
}

function openPlayback(item) {
  if (item.rid == null) return notify('该记录没有对应的录制记录，无法回放')
  router.push(`/enterprise/conference/playback?id=${item.rid}`)
}

async function savePolicy() {
  notify(`存储策略已更新：保留 ${policy.value.keepDays} 天`)
  policyVisible.value = false
  try {
    await saveStoragePolicy({ keepDays: policy.value.keepDays, maxStorageGb: policy.value.maxStorage })
  } catch (e) {
    // 保存失败静默，保留原有提示
  }
}

// 页面级批量授权：对当前列表每条录制逐条写入访问级别与有效期
async function saveAuth() {
  const targets = filtered.value.filter((r) => r.rid != null)
  if (!targets.length) {
    notify('当前没有可授权的录制，请先确认列表中已有记录')
    return
  }
  const payload = { validDays: auth.value.validDays, level: auth.value.level }
  const results = await Promise.allSettled(targets.map((r) => updateRecordingAccess(r.rid, payload)))
  const ok = results.filter((r) => r.status === 'fulfilled').length
  const failed = results.length - ok
  authVisible.value = false
  if (failed) {
    notify(`授权完成：成功 ${ok} 条，失败 ${failed} 条`)
  } else {
    notify(`已为 ${ok} 条录制设置授权：${auth.value.validDays} 天 / ${ACCESS_TEXT[auth.value.level]}`)
  }
  initPage()
}

const statusClass = (status) => ({
  已完成: 'green',
  录制中: 'orange',
  异常终止: 'red',
  已过期: 'gray',
  待审核: 'orange'
}[status] || 'gray')
</script>

<template>
  <div class="page">
    <div class="page-heading">
      <div><h1>录制回放与存储管理</h1><p>企业端 · HR / 管理员</p></div>
    </div>

    <main>
      <section class="card filter">
        <div class="field">
          <label>面试 ID</label>
          <input v-model="filters.id" class="input" placeholder="如 REC-20260618-001" />
        </div>
        <div class="field">
          <label>候选人</label>
          <input v-model="filters.candidate" class="input" placeholder="输入候选人姓名" />
        </div>
        <div class="field">
          <label>日期范围</label>
          <div class="range">
            <input v-model="filters.from" type="date" class="input" />
            <span>至</span>
            <input v-model="filters.to" type="date" class="input" />
          </div>
        </div>
        <div class="filter-actions">
          <button class="btn ghost-primary" @click="reset">重置</button>
          <button class="btn primary" @click="query"><Search :size="15" />查询</button>
          <button class="btn" @click="exportList"><Download :size="15" />导出</button>
        </div>
      </section>

      <section class="card table-card">
        <div class="table-head">
          <h2>录制文件列表</h2>
          <span class="muted tiny">共 {{ filtered.length }} 条 · 按面试时间倒序</span>
        </div>
        <table class="record-table">
          <thead>
            <tr>
              <th>面试 ID</th><th>候选人</th><th>岗位</th><th>日期</th>
              <th>时长</th><th>占用</th><th>状态</th><th class="op">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in filtered" :key="item.id">
              <td class="mono">{{ item.id }}</td>
              <td>
                <strong>{{ item.candidate }}</strong>
                <small class="muted">{{ item.mode }}</small>
              </td>
              <td>{{ item.position }}</td>
              <td>{{ item.date }}</td>
              <td class="mono">{{ item.duration }}</td>
              <td class="mono">{{ item.size }}</td>
              <td><span class="pill" :class="statusClass(item.status)"><i class="dot" />{{ item.status }}</span></td>
              <td class="op">
                <button class="link" :disabled="item.status !== '已完成'" @click="openPlayback(item)"><Play :size="14" />回放</button>
                <button class="link" @click="openDownload(item)"><Download :size="14" />下载</button>
                <button class="link" @click="openDetail(item)"><Eye :size="14" />查看</button>
              </td>
            </tr>
            <tr v-if="!filtered.length">
              <td colspan="8" class="empty">没有符合条件的录制文件</td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="card storage">
        <div class="storage-head">
          <div class="storage-title">
            <span class="storage-icon"><Database :size="18" /></span>
            <div>
              <h2>存储空间</h2>
              <small class="muted">企业级录制文件采用加密存储，支持按策略自动清理</small>
            </div>
          </div>
          <div class="storage-actions">
            <button class="btn" @click="policyVisible = true"><Archive :size="15" />存储策略</button>
            <button class="btn" @click="authVisible = true"><KeyRound :size="15" />访问授权</button>
          </div>
        </div>
        <div class="storage-bar">
          <div class="bar-track"><u :style="{ width: storagePercent + '%' }" /></div>
          <div class="bar-meta">
            <span>已用 <b>{{ fmtUsed() }}</b> / {{ storage.total }} GB</span>
            <span class="muted">剩余 {{ fmtStorage(storage.total - storage.used) }} · 使用率 {{ storagePercent }}%</span>
          </div>
        </div>
        <div class="storage-tips">
          <span><Clock3 :size="13" />当前保留策略：{{ policy.keepDays }} 天</span>
          <span><ShieldCheck :size="13" />下载需短信二次验证</span>
        </div>
      </section>
    </main>

    <BaseModal v-if="verifyVisible" title="下载二次验证" width="440px" @close="verifyVisible = false">
      <div class="download-target">
        <Video :size="16" />
        <div>
          <strong>{{ pendingDownload?.id }}</strong>
          <small class="muted">{{ pendingDownload?.candidate }} · {{ pendingDownload?.position }}</small>
        </div>
      </div>
      <p class="tip-text"><AlertTriangle :size="14" />下载行为将被记录至审计日志，请确认已完成候选人授权。</p>
      <div class="field">
        <label>短信验证码</label>
        <input v-model="smsCode" class="input" maxlength="6" placeholder="请输入发送至手机号的 6 位验证码" />
        <small v-if="devCode" class="muted">本地联调：后端未接入短信通道，本次验证码为 {{ devCode }}</small>
      </div>
      <template #footer>
        <button class="btn" @click="verifyVisible = false">取消</button>
        <button class="btn primary" @click="confirmDownload">确认下载</button>
      </template>
    </BaseModal>

    <BaseModal v-if="policyVisible" title="存储策略" width="480px" @close="policyVisible = false">
      <div class="field">
        <label>录制保留天数</label>
        <input v-model.number="policy.keepDays" type="number" min="7" max="3650" class="input" />
        <small class="muted">超期录制将自动归档并删除，范围 7 - 3650 天</small>
      </div>
      <div class="field">
        <label>总存储上限（GB）</label>
        <input v-model.number="policy.maxStorage" type="number" min="100" max="10000" class="input" />
        <small class="muted">达到 90% 时系统将通知管理员清理</small>
      </div>
      <template #footer>
        <button class="btn" @click="policyVisible = false">取消</button>
        <button class="btn primary" @click="savePolicy">保存策略</button>
      </template>
    </BaseModal>

    <BaseModal v-if="authVisible" title="访问授权" width="480px" @close="authVisible = false">
      <div class="field">
        <label>访问有效期</label>
        <div class="range">
          <input v-model.number="auth.validDays" type="number" min="1" max="365" class="input" />
          <span>天</span>
        </div>
        <small class="muted">到期后授权链接自动失效，需重新申请</small>
      </div>
      <div class="field">
        <label>权限级别</label>
        <select v-model.number="auth.level" class="select">
          <option :value="1">仅HR/面试官</option>
          <option :value="2">含管理员</option>
          <option :value="3">候选人可见</option>
        </select>
      </div>
      <p class="tip-text"><ShieldCheck :size="14" />授权对象默认包含：面试官、HRBP、招聘负责人。</p>
      <template #footer>
        <button class="btn" @click="authVisible = false">取消</button>
        <button class="btn primary" @click="saveAuth">保存授权</button>
      </template>
    </BaseModal>

    <BaseModal v-if="detailVisible" title="录制详情" width="560px" @close="detailVisible = false">
      <div v-if="detailLoading" class="tip-text">正在加载录制详情…</div>
      <template v-else-if="detail">
        <div class="detail-grid">
          <span>候选人</span><b>{{ detail.candidateName || '—' }}</b>
          <span>岗位</span><b>{{ detail.positionTitle || '—' }}</b>
          <span>面试日期</span><b>{{ detail.interviewDate || '—' }}</b>
          <span>录制时长</span><b>{{ fmtDuration(detail.durationSec) }}</b>
          <span>文件占用</span><b>{{ fmtSize(detail.durationSec, detail.recSizeBytes) }}</b>
          <span>面试模式</span><b>{{ MODE_TEXT[detail.mode] || '—' }}</b>
          <span>访问级别</span><b>{{ ACCESS_TEXT[detail.recAccessLevel] || '—' }}</b>
          <span>授权有效期</span><b>{{ detail.recExpiresAt || '—' }}</b>
          <span>面试官</span>
          <b>{{ (detail.interviewers || []).map(i => i.userName).filter(Boolean).join('、') || detail.primaryInterviewerName || '—' }}</b>
          <span>录制地址</span>
          <b class="mono break">{{ resolveRecUrl(detail.recUrl) || '—' }}</b>
        </div>
        <div v-if="detail.chapters?.length" class="detail-block">
          <h3>时间轴打点（{{ detail.chapters.length }}）</h3>
          <p v-for="c in detail.chapters.slice(0, 8)" :key="c.second" class="detail-line">
            <span class="mono">{{ fmtDuration(c.second) }}</span>{{ c.title }}
          </p>
        </div>
        <p v-else class="tip-text">该场次暂无时间轴打点数据。</p>
      </template>
      <p v-else class="tip-text"><AlertTriangle :size="14" />录制详情加载失败，请稍后重试。</p>
      <template #footer>
        <button class="btn" @click="detailVisible = false">关闭</button>
        <button class="btn primary" :disabled="!detail?.recUrl" @click="downloadDetail">
          <Download :size="14" />下载录制
        </button>
      </template>
    </BaseModal>

    <ToastMessage :message="toast" />
  </div>
</template>

<style src="../enterprise.css"></style>

<style scoped>
.filter { display: grid; grid-template-columns: 1fr 1fr 1.4fr auto; gap: 16px; align-items: end; padding: 18px 20px; }
.range { display: flex; align-items: center; gap: 8px; }
.range span { color: var(--muted); font-size: 12px; }
.filter-actions { display: flex; gap: 8px; }
.field small { display: block; margin-top: 6px; font-size: 11px; }

.table-card { margin-top: 16px; padding: 18px 20px 6px; }
.table-head { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 12px; }
.table-head h2 { font-size: 16px; }
.record-table { width: 100%; border-collapse: collapse; }
.record-table th, .record-table td { text-align: left; padding: 13px 10px; border-bottom: 1px solid var(--line); font-size: 13px; }
.record-table th { color: var(--muted); font-weight: 600; font-size: 12px; background: #fafcff; }
.record-table tbody tr:hover { background: #f7fbff; }
.record-table td strong { display: block; font-weight: 600; }
.record-table td small { display: block; font-size: 11px; }
.mono { font-variant-numeric: tabular-nums; font-family: 'DM Sans', monospace; }
.pill i.dot { background: currentColor; }
.op { text-align: right; white-space: nowrap; }
.link {
  border: 0; background: transparent; color: var(--primary);
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 12px; padding: 0 6px;
}
.link:disabled { color: #b6c2d4; cursor: not-allowed; }
.link:not(:disabled):hover { text-decoration: underline; }

.storage { margin-top: 16px; padding: 20px; }
.storage-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.storage-title { display: flex; align-items: center; gap: 12px; }
.storage-icon {
  width: 38px; height: 38px; border-radius: 10px;
  display: grid; place-items: center;
  color: var(--primary); background: var(--primary-soft);
}
.storage-title h2 { font-size: 16px; }
.storage-title small { font-size: 12px; }
.storage-actions { display: flex; gap: 9px; }
.storage-bar { margin-top: 18px; }
.bar-track { height: 12px; border-radius: 999px; background: #eef2f8; overflow: hidden; }
.bar-track u { display: block; height: 100%; border-radius: inherit; background: linear-gradient(90deg, var(--primary), #3b82f6); }
.bar-meta { display: flex; justify-content: space-between; margin-top: 9px; font-size: 12px; }
.storage-tips { display: flex; flex-wrap: wrap; gap: 18px; margin-top: 16px; padding-top: 14px; border-top: 1px dashed var(--line); color: var(--muted); font-size: 12px; }
.storage-tips span { display: inline-flex; align-items: center; gap: 6px; }

.download-target { display: flex; align-items: center; gap: 11px; padding: 12px 14px; border-radius: 10px; background: #f5f8fd; margin-bottom: 14px; }
.download-target svg { color: var(--primary); }
.download-target strong { display: block; font-size: 13px; }
.download-target small { font-size: 12px; }
.tip-text { display: flex; align-items: flex-start; gap: 7px; margin: 14px 0 12px; padding: 10px 12px; border-radius: 9px; background: #fff8e8; color: #96650a; font-size: 12px; line-height: 1.6; }
.field + .field { margin-top: 16px; }

.detail-grid { display: grid; grid-template-columns: 92px 1fr; gap: 10px 14px; font-size: 13px; }
.detail-grid > span { color: var(--muted); font-size: 12px; }
.detail-grid > b { font-weight: 600; }
.detail-grid .break { word-break: break-all; font-size: 12px; font-weight: 400; }
.detail-block { margin-top: 16px; }
.detail-block h3 { font-size: 13px; margin-bottom: 8px; }
.detail-line { display: flex; gap: 10px; padding: 5px 0; font-size: 12px; color: var(--text-2, #334155); }
.detail-line .mono { flex: 0 0 52px; color: var(--muted); }

@media (max-width: 1080px) {
  .filter { grid-template-columns: 1fr 1fr; }
  .filter-actions { grid-column: 1 / -1; }
}
@media (max-width: 760px) {
  .bar, .page { width: calc(100% - 28px); }
  .filter { grid-template-columns: 1fr; }
  .table-card { overflow-x: auto; }
  .storage-head { flex-direction: column; align-items: flex-start; }
}
</style>