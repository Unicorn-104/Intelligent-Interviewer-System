<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { match as pinyinMatch } from 'pinyin-pro'
import { Search, UsersRound, BriefcaseBusiness, MessageSquareText, ChevronRight } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import { listTalents } from '@/api/talent'
import { listJobs } from '@/api/system/job'
import { listSessions } from '@/api/system/im'

const route = useRoute()
const router = useRouter()
const keyword = ref('')
const input = ref('')
const loading = ref(false)
const candidates = ref([])
const jobs = ref([])
const sessions = ref([])

const totalCount = computed(() => candidates.value.length + jobs.value.length + sessions.value.length)
const isEmptyKeyword = computed(() => !keyword.value)

// 人才状态（t_tal.tal_status）
const TALENT_STATUS = {
  0: ['新入库', 'gray'], 1: ['初筛通过', 'green'], 2: ['面试中', 'purple'], 3: ['已淘汰', 'red'],
  4: ['已录用', 'green'], 5: ['待笔试', 'orange'], 6: ['笔试中', 'orange'], 7: ['笔试通过', 'green'],
  8: ['笔试未通过', 'red'], 9: ['笔试缺考', 'gray']
}
// 岗位状态（t_pos.pos_status）
const JOB_STATUS = { 1: ['招聘中', 'green'], 2: ['已暂停', 'gray'], 0: ['已下线', 'red'] }

function salaryText(row) {
  if (row.salaryMin == null || row.salaryMax == null) return '面议'
  return `${Math.round(row.salaryMin / 1000)}-${Math.round(row.salaryMax / 1000)}K`
}

function timeText(value) {
  return value ? String(value).slice(0, 16) : ''
}

function sessionMatches(name, summary, kw) {
  const text = `${name || ''} ${summary || ''}`
  if (text.includes(kw)) return true
  try {
    return pinyinMatch(text, kw).length > 0
  } catch (e) {
    return false
  }
}

async function run(rawKeyword) {
  const kw = String(rawKeyword || '').trim()
  keyword.value = kw
  input.value = kw
  if (!kw) {
    candidates.value = []
    jobs.value = []
    sessions.value = []
    return
  }
  loading.value = true
  try {
    const [candidateRes, jobRes, sessionRes] = await Promise.all([
      listTalents({ keyword: kw, pageNum: 1, pageSize: 20 }).catch(() => ({ rows: [] })),
      listJobs({ keyword: kw, pageNum: 1, pageSize: 20 }).catch(() => ({ rows: [] })),
      listSessions().catch(() => ({ data: [] }))
    ])
    candidates.value = (candidateRes.rows || []).map(row => ({
      talentId: row.talentId,
      name: row.name || `候选人${row.talentId}`,
      phone: row.phone,
      jobDirection: row.jobDirection,
      statusText: (TALENT_STATUS[row.status] || TALENT_STATUS[0])[0],
      statusTone: (TALENT_STATUS[row.status] || TALENT_STATUS[0])[1]
    }))
    jobs.value = (jobRes.rows || []).map(row => ({
      posId: row.posId,
      title: row.title || `岗位${row.posId}`,
      dept: row.dept || '未分配',
      city: row.city || '城市未填',
      salary: salaryText(row),
      statusText: (JOB_STATUS[row.status] || JOB_STATUS[0])[0],
      statusTone: (JOB_STATUS[row.status] || JOB_STATUS[0])[1],
      applicants: row.applicantCount || 0
    }))
    // 会话列表为全量数据，前端按姓名/摘要/拼音首字母过滤
    sessions.value = (sessionRes.data || [])
      .filter(s => sessionMatches(s.peerName, s.lastMessage, kw))
      .map(s => ({
        sessionId: s.sessionId,
        peerId: s.peerId,
        name: s.peerName || `用户${s.peerId}`,
        summary: s.lastMessage || '暂无消息',
        time: timeText(s.lastMessageAt),
        unread: s.unread || 0
      }))
  } finally {
    loading.value = false
  }
}

function doSearch() {
  const kw = input.value.trim()
  if (!kw) return
  if (kw === keyword.value) {
    run(kw)
    return
  }
  router.replace({ path: '/enterprise/search', query: { keyword: kw } })
}

function goCandidate(row) {
  router.push({ path: '/enterprise/talent', query: { keyword: row.name } })
}

function goJob(row) {
  router.push({ path: '/enterprise/jobs', query: { keyword: row.title } })
}

function goSession(row) {
  router.push({ path: '/enterprise/messages', query: { peerId: row.peerId, peerName: row.name } })
}

onMounted(() => run(route.query.keyword))
watch(() => route.query.keyword, kw => run(kw))
</script>

<template>
  <div class="page search-page">
    <div class="page-heading">
      <div>
        <h1>搜索结果</h1>
        <p v-if="keyword">
          关键词「{{ keyword }}」，共 {{ totalCount }} 条：候选人 {{ candidates.length }} · 岗位 {{ jobs.length }} · 消息 {{ sessions.length }}
        </p>
        <p v-else>输入关键词，同时检索候选人、岗位与消息</p>
      </div>
    </div>

    <div class="search-box">
      <Search :size="16" />
      <input v-model="input" placeholder="搜索候选人、岗位或消息" @keyup.enter="doSearch" />
      <button class="btn primary" @click="doSearch">搜索</button>
    </div>

    <section class="card result-card">
      <header class="rc-head">
        <div class="rc-title"><UsersRound :size="15" /><b>候选人</b><em>{{ candidates.length }}</em></div>
        <span class="source-chip">来自：人才库</span>
      </header>
      <div v-if="isEmptyKeyword" class="empty">输入关键词后展示匹配的候选人</div>
      <div v-else-if="loading" class="empty">搜索中…</div>
      <div v-else-if="!candidates.length" class="empty">没有匹配的候选人</div>
      <div v-else class="rows">
        <article v-for="row in candidates" :key="row.talentId" class="row" @click="goCandidate(row)">
          <MiniAvatar :name="row.name" :size="34" color="#2563eb" />
          <div class="main">
            <b>{{ row.name }}</b>
            <small>{{ row.phone || '手机号缺失' }} · {{ row.jobDirection || '求职方向未填' }}</small>
          </div>
          <span class="pill" :class="row.statusTone">{{ row.statusText }}</span>
          <span class="go">人才库详情</span><ChevronRight :size="14" />
        </article>
      </div>
    </section>

    <section class="card result-card">
      <header class="rc-head">
        <div class="rc-title"><BriefcaseBusiness :size="15" /><b>岗位</b><em>{{ jobs.length }}</em></div>
        <span class="source-chip">来自：岗位管理</span>
      </header>
      <div v-if="isEmptyKeyword" class="empty">输入关键词后展示匹配的岗位</div>
      <div v-else-if="loading" class="empty">搜索中…</div>
      <div v-else-if="!jobs.length" class="empty">没有匹配的岗位</div>
      <div v-else class="rows">
        <article v-for="row in jobs" :key="row.posId" class="row" @click="goJob(row)">
          <div class="job-badge"><BriefcaseBusiness :size="16" /></div>
          <div class="main">
            <b>{{ row.title }}</b>
            <small>{{ row.dept }} · {{ row.city }} · {{ row.salary }} · {{ row.applicants }} 位投递</small>
          </div>
          <span class="pill" :class="row.statusTone">{{ row.statusText }}</span>
          <span class="go">岗位详情</span><ChevronRight :size="14" />
        </article>
      </div>
    </section>

    <section class="card result-card">
      <header class="rc-head">
        <div class="rc-title"><MessageSquareText :size="15" /><b>消息</b><em>{{ sessions.length }}</em></div>
        <span class="source-chip">来自：消息中心</span>
      </header>
      <div v-if="isEmptyKeyword" class="empty">输入关键词后展示匹配的会话</div>
      <div v-else-if="loading" class="empty">搜索中…</div>
      <div v-else-if="!sessions.length" class="empty">没有匹配的会话</div>
      <div v-else class="rows">
        <article v-for="row in sessions" :key="row.sessionId || row.peerId" class="row" @click="goSession(row)">
          <MiniAvatar :name="row.name" :size="34" color="#356f65" />
          <div class="main">
            <b>{{ row.name }}<span v-if="row.unread" class="unread">{{ row.unread }}</span></b>
            <small>{{ row.summary }}</small>
          </div>
          <time>{{ row.time }}</time>
          <span class="go">进入会话</span><ChevronRight :size="14" />
        </article>
      </div>
    </section>
  </div>
</template>

<style scoped>
.search-box{display:flex;align-items:center;gap:10px;height:44px;padding:0 7px 0 14px;margin-bottom:14px;background:#fff;border:1px solid #e2e9f2;border-radius:11px;color:#8fa0b8}
.search-box input{flex:1;min-width:0;border:0;outline:0;background:transparent;font-size:13px;color:var(--text)}
.search-box .btn{height:32px;padding:0 18px}
.result-card{padding:0;margin-bottom:14px;overflow:hidden}
.rc-head{display:flex;align-items:center;justify-content:space-between;padding:13px 16px;border-bottom:1px solid #edf1f7;background:#f9fbfd}
.rc-title{display:flex;align-items:center;gap:7px;color:#2563eb}
.rc-title b{font-size:13px;color:#1e293b}
.rc-title em{font-style:normal;display:inline-flex;align-items:center;justify-content:center;box-sizing:border-box;min-width:20px;height:20px;padding:0 6px;border-radius:999px;background:#edf4ff;color:#2563eb;font-size:10px;font-weight:600;line-height:1;font-variant-numeric:tabular-nums}
.source-chip{font-size:10px;color:#7f8ea3;background:#f1f5fb;border-radius:6px;padding:3px 8px}
.rows{display:flex;flex-direction:column}
.row{display:flex;align-items:center;gap:11px;min-height:62px;padding:10px 16px;border-bottom:1px solid #f1f4f9;cursor:pointer;transition:background .15s}
.row:last-child{border-bottom:0}
.row:hover{background:#f8faff}
.main{flex:1;min-width:0}
.main b{display:flex;align-items:center;gap:6px;font-size:12px;color:#1e293b}
.main small{display:block;margin-top:4px;font-size:10px;color:#7f8ea3;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.row time{font-size:9px;color:#8d9aae}
.go{font-size:10px;color:#2563eb;white-space:nowrap}
.unread{display:inline-flex;align-items:center;justify-content:center;min-width:16px;height:16px;padding:0 4px;border-radius:999px;background:#ef4444;color:#fff;font-size:9px;font-weight:500}
.job-badge{width:34px;height:34px;border-radius:9px;background:#edf4ff;color:#2563eb;display:grid;place-items:center;flex:none}
.pill{display:inline-flex;align-items:center;height:20px;padding:0 8px;border-radius:999px;font-size:9px;white-space:nowrap}
.pill.green{background:#e9f9f0;color:#16a34a}
.pill.red{background:#feecec;color:#dc2626}
.pill.orange{background:#fff5e6;color:#d97706}
.pill.purple{background:#f3ecff;color:#7c3aed}
.pill.gray{background:#f1f4f8;color:#64748b}
.empty{padding:30px;text-align:center;color:#a4b0c2;font-size:11px}
</style>
