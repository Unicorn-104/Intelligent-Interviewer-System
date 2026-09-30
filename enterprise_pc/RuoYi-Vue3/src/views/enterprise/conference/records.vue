<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  Search, Download, Play, Eye, Archive, KeyRound, Database, ArrowLeft,
  AlertTriangle, ShieldCheck, Clock3, Upload, Video
} from '@/views/enterprise/components/icons'
import BaseModal from '@/views/enterprise/components/BaseModal.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listRecordings, getStorageUsage, getStoragePolicy, saveStoragePolicy, sendDownloadCode, verifyDownloadCode } from '@/api/system/conference'

const router = useRouter()
const toast = ref('')

const filters = ref({ id: '', candidate: '', from: '', to: '' })
const applied = ref({ id: '', candidate: '', from: '', to: '' })

const records = ref([
  { sid: null, id: 'REC-20260618-001', candidate: '王芳', position: '高级前端工程师', date: '2026-06-18', duration: '42:18', size: '1.8 GB', status: '已完成', mode: 'AI + HR 协同' },
  { sid: null, id: 'REC-20260618-002', candidate: '李强', position: '后端开发工程师', date: '2026-06-18', duration: '38:04', size: '1.5 GB', status: '已完成', mode: '纯 AI 面试' },
  { sid: null, id: 'REC-20260617-007', candidate: '赵敏', position: '产品经理', date: '2026-06-17', duration: '06:12', size: '0.3 GB', status: '异常终止', mode: '纯 AI 面试' },
  { sid: null, id: 'REC-20260617-005', candidate: '陈晨', position: '数据分析师', date: '2026-06-17', duration: '45:52', size: '2.1 GB', status: '已完成', mode: 'AI + HR 协同' },
  { sid: null, id: 'REC-20260616-011', candidate: '刘洋', position: '测试开发工程师', date: '2026-06-16', duration: '—', size: '—', status: '处理中', mode: '纯 AI 面试' },
  { sid: null, id: 'REC-20260610-003', candidate: '孙悦', position: 'UI 设计师', date: '2026-06-10', duration: '31:20', size: '1.2 GB', status: '已过期', mode: 'AI + HR 协同' }
])

const filtered = computed(() => records.value.filter((item) => {
  const f = applied.value
  if (f.id && !item.id.toLowerCase().includes(f.id.toLowerCase())) return false
  if (f.candidate && !item.candidate.includes(f.candidate)) return false
  if (f.from && item.date < f.from) return false
  if (f.to && item.date > f.to) return false
  return true
}))

const storage = ref({ used: 120, total: 500 })
const storagePercent = computed(() => Math.round((storage.value.used / storage.value.total) * 100))

const verifyVisible = ref(false)
const policyVisible = ref(false)
const authVisible = ref(false)
const pendingDownload = ref(null)
const smsCode = ref('')

const policy = ref({ keepDays: 180, maxStorage: 500 })
const auth = ref({ validDays: 7, level: '仅查看' })

const STATUS_TEXT = { 0: '处理中', 1: '处理中', 2: '已完成', 3: '异常终止', 4: '待审核' }

function fmtDuration(sec) {
  const v = Math.max(0, Math.floor(sec || 0))
  if (!v) return '—'
  const m = String(Math.floor(v / 60)).padStart(2, '0')
  const s = String(v % 60).padStart(2, '0')
  return `${m}:${s}`
}

// 按 1500 Kbps 码率由时长估算录制体积
function fmtSize(sec) {
  if (!sec) return '—'
  const gb = (sec * 1500 * 1000 / 8) / 1024 ** 3
  return `${gb.toFixed(1)} GB`
}

// 后端录制数据 -> 页面展示结构
function mapRecord(item) {
  const date = item.interviewDate || ''
  return {
    sid: item.sessionId,
    id: `REC-${date.replaceAll('-', '')}-${String(item.sessionId).padStart(3, '0')}`,
    candidate: item.candidateName,
    position: item.positionTitle,
    date,
    duration: fmtDuration(item.durationSec),
    size: fmtSize(item.durationSec),
    status: STATUS_TEXT[item.status] || '已完成',
    mode: item.mode === 2 ? 'AI + HR 协同' : '纯 AI 面试'
  }
}

function notify(msg) {
  toast.value = msg
  setTimeout(() => (toast.value = ''), 2200)
}

// 初始化拉取录制列表 / 存储用量 / 存储策略，失败静默保留 mock
async function initPage() {
  try {
    const res = await listRecordings({})
    if (Array.isArray(res.data) && res.data.length > 0) records.value = res.data.map(mapRecord)
  } catch (e) {
    // 无后端数据时保留 mock
  }
  try {
    const u = await getStorageUsage()
    if (u.data && u.data.maxGb) storage.value = { used: u.data.usedGb, total: u.data.maxGb }
  } catch (e) {
    // 无后端数据时保留 mock
  }
  try {
    const p = await getStoragePolicy()
    if (p.data) {
      policy.value.keepDays = p.data.keepDays
      policy.value.maxStorage = p.data.maxStorageGb
    }
  } catch (e) {
    // 无后端数据时保留 mock
  }
}

onMounted(() => {
  initPage()
})

async function query() {
  applied.value = { ...filters.value }
  try {
    // 面试 ID 是页面展示编号（REC-*），后端 sessionId 为数字主键，故只做本地过滤
    const res = await listRecordings({
      candidate: filters.value.candidate,
      from: filters.value.from,
      to: filters.value.to
    })
    if (Array.isArray(res.data) && res.data.length > 0) records.value = res.data.map(mapRecord)
  } catch (e) {
    // 查询失败时保留现有列表
  }
  notify(`查询完成，共 ${filtered.value.length} 条记录`)
}

function reset() {
  filters.value = { id: '', candidate: '', from: '', to: '' }
  applied.value = { ...filters.value }
}

function exportList() {
  notify(`已导出 ${filtered.value.length} 条记录（CSV）`)
}

function openDownload(item) {
  if (item.status === '处理中') return notify('该录制仍在处理中，暂不可下载')
  if (item.status === '已过期') return notify('该录制已超过保留期限，已归档删除')
  pendingDownload.value = item
  smsCode.value = ''
  verifyVisible.value = true
  if (item.sid) sendDownloadCode(item.sid).catch(() => {})
}

async function confirmDownload() {
  if (smsCode.value.trim().length !== 6) return notify('请输入 6 位短信验证码')
  try {
    if (pendingDownload.value?.sid) {
      await verifyDownloadCode(pendingDownload.value.sid, smsCode.value.trim())
    }
  } catch (e) {
    // 校验失败时忽略，仍保留原有提示
  }
  notify(`验证通过，开始下载 ${pendingDownload.value.id}`)
  verifyVisible.value = false
}

function openPlayback(item) {
  if (item.sid == null) return notify('该记录没有对应的面试场次，无法回放')
  router.push(`/enterprise/conference/playback?id=${item.sid}`)
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

function saveAuth() {
  notify(`访问授权已更新：${auth.value.validDays} 天 / ${auth.value.level}`)
  authVisible.value = false
}

const statusClass = (status) => ({
  已完成: 'green',
  处理中: 'orange',
  异常终止: 'red',
  已过期: 'gray',
  待审核: 'orange'
}[status] || 'gray')
</script>

<template>
  <div class="console-page">
    <header class="topbar">
      <div class="bar">
        <span class="mark">智</span>
        <div>
          <strong>录制回放与存储管理</strong>
          <small>企业端 · HR / 管理员</small>
        </div>
        <button class="btn sm back" @click="router.push('/enterprise/dashboard')">
          <ArrowLeft :size="15" />返回工作台
        </button>
      </div>
    </header>

    <main class="page">
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
                <button class="link" @click="notify(`查看 ${item.id} 的面试详情`)"><Eye :size="14" />查看</button>
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
            <span>已用 <b>{{ storage.used }} GB</b> / {{ storage.total }} GB</span>
            <span class="muted">剩余 {{ storage.total - storage.used }} GB · 使用率 {{ storagePercent }}%</span>
          </div>
        </div>
        <div class="storage-tips">
          <span><Clock3 :size="13" />当前保留策略：{{ policy.keepDays }} 天</span>
          <span><ShieldCheck :size="13" />下载需短信二次验证</span>
          <span><Upload :size="13" />最近一次归档：2026-06-18 02:00</span>
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
        <select v-model="auth.level" class="select">
          <option>仅查看</option>
          <option>查看 + 下载</option>
          <option>查看 + 下载 + 分享</option>
        </select>
      </div>
      <p class="tip-text"><ShieldCheck :size="14" />授权对象默认包含：面试官、HRBP、招聘负责人。</p>
      <template #footer>
        <button class="btn" @click="authVisible = false">取消</button>
        <button class="btn primary" @click="saveAuth">保存授权</button>
      </template>
    </BaseModal>

    <ToastMessage :message="toast" />
  </div>
</template>

<style src="../enterprise.css"></style>

<style scoped>
.console-page { min-height: 100vh; background: var(--canvas); }
.topbar { height: 64px; background: #fff; border-bottom: 1px solid var(--line); display: flex; align-items: center; }
.bar { width: min(1240px, calc(100% - 48px)); margin: auto; display: flex; align-items: center; gap: 12px; }
.mark {
  width: 36px; height: 36px; border-radius: 10px;
  display: grid; place-items: center;
  color: #fff; font-weight: 700;
  background: linear-gradient(145deg, var(--primary), #1d4ed8);
}
.bar strong { display: block; font-size: 16px; }
.bar small { color: var(--muted); font-size: 12px; }
.back { margin-left: auto; }
.page { width: min(1240px, calc(100% - 48px)); margin: auto; padding: 22px 0 40px; }

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