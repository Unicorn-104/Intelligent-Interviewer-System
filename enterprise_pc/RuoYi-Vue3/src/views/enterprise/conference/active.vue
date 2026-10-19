<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Video, CalendarClock, RotateCw, Users, Clock3, ChevronRight } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { getCurrentSession } from '@/api/system/conference'

const router = useRouter()
const session = ref(null)
const loading = ref(true)
const toast = ref('')
// ses_status：0 待开始 / 1 进行中
const statusText = { 0: '待开始', 1: '进行中' }

function notify(v) { toast.value = v; setTimeout(() => toast.value = '', 2200) }

async function load() {
  loading.value = true
  try {
    const res = await getCurrentSession()
    session.value = res.data && res.data.sessionId ? res.data : null
  } catch (e) {
    session.value = null
    notify('场次信息加载失败')
  } finally {
    loading.value = false
  }
}

function enterWaiting() { router.push({ path: '/enterprise/conference/waiting', query: { sessionId: session.value.sessionId } }) }
function enterMeeting() { router.push({ path: '/enterprise/conference/ongoing', query: { sessionId: session.value.sessionId } }) }

onMounted(load)
</script>

<template>
  <div class="page active-page">
    <div class="page-heading">
      <div><h1>正在进行的面试</h1><p>当前账号作为候选人或面试官的待开始 / 进行中视频面试场次</p></div>
      <div class="heading-actions"><button class="btn" @click="load"><RotateCw :size="15"/>刷新</button></div>
    </div>

    <div v-if="loading" class="card empty-card">场次加载中…</div>
    <div v-else-if="!session" class="card empty-card">
      <div class="empty-icon"><Video :size="26"/></div>
      <b>暂无进行中或待开始的面试场次</b>
      <p>可在面试安排中心发起视频面试后，回到此页进入会议</p>
      <button class="btn primary" @click="router.push('/enterprise/interviews')">前往面试安排中心</button>
    </div>
    <div v-else class="card session-card">
      <div class="sc-head">
        <MiniAvatar :name="session.candidateName || '候选人'" :size="46" color="#2563eb"/>
        <div class="sc-info">
          <h3>{{ session.candidateName || '候选人' }} <span class="pill" :class="Number(session.status) === 1 ? 'green' : 'orange'">{{ statusText[session.status] || '—' }}</span></h3>
          <p>{{ session.positionTitle || '未关联岗位' }}<template v-if="session.companyName"> · {{ session.companyName }}</template></p>
        </div>
        <div class="sc-round">第 {{ session.roundNo || 1 }} 轮</div>
      </div>
      <div class="sc-meta">
        <span><Clock3 :size="13"/>开始时间 {{ session.startAt || '未定' }}</span>
        <span><Users :size="13"/>场次 #{{ session.sessionId }}</span>
        <span><CalendarClock :size="13"/>我的角色 {{ session.role === 'CANDIDATE' ? '候选人' : '面试官' }}</span>
      </div>
      <div class="sc-actions">
        <button v-if="Number(session.status) === 0" class="btn" @click="enterWaiting">进入等候室<ChevronRight :size="14"/></button>
        <button class="btn primary" @click="enterMeeting"><Video :size="15"/>进入会议室</button>
      </div>
    </div>

    <ToastMessage :message="toast"/>
  </div>
</template>

<style scoped>
.active-page{padding-bottom:25px}
.heading-actions{display:flex;gap:9px}
.empty-card{padding:70px 20px;text-align:center;color:#64748b;font-size:12px}
.empty-icon{width:56px;height:56px;border-radius:16px;background:#eaf1ff;color:#2563eb;display:grid;place-items:center;margin:0 auto 14px}
.empty-card b{display:block;font-size:15px;color:#1e293b;margin-bottom:6px}
.empty-card p{margin:0 0 16px;color:#8593a7}
.session-card{padding:22px;max-width:720px}
.sc-head{display:flex;align-items:center;gap:13px}
.sc-info{flex:1;min-width:0}
.sc-info h3{font-size:16px;margin:0;display:flex;align-items:center;gap:8px}
.sc-info p{font-size:11px;color:#7f8ea3;margin:4px 0 0}
.sc-round{font-size:11px;color:#2563eb;background:#edf4ff;border-radius:8px;padding:6px 11px;flex:none}
.sc-meta{display:flex;gap:18px;flex-wrap:wrap;margin:16px 0;padding:12px 14px;background:#f6f8fb;border-radius:10px;font-size:11px;color:#5b6b82}
.sc-meta span{display:flex;align-items:center;gap:5px}
.sc-meta svg{color:#8593a7}
.sc-actions{display:flex;gap:10px;justify-content:flex-end}
.sc-actions .btn{display:inline-flex;align-items:center;gap:5px}
</style>
