<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ShieldCheck, RotateCw, Video } from '@/views/enterprise/components/icons'
import MiniAvatar from '@/views/enterprise/components/MiniAvatar.vue'
import ToastMessage from '@/views/enterprise/components/ToastMessage.vue'
import { listOngoingExams } from '@/api/exam'

const router = useRouter()
const toast = ref('')
function notify(m) { toast.value = m; setTimeout(() => { toast.value = '' }, 2400) }

const list = ref([])
const loading = ref(false)
let pollTimer = null

async function loadList() {
  loading.value = true
  try {
    const res = await listOngoingExams()
    list.value = res.data || []
  } catch (e) {
    notify('加载监考列表失败')
  } finally {
    loading.value = false
  }
}

function fmt(t) { return t ? String(t).replace('T', ' ').slice(5, 16) : '--' }

function openProctor(row) {
  router.push({ path: '/enterprise/exam/proctor/room', query: { recordId: row.recordId } })
}

onMounted(() => {
  loadList()
  pollTimer = setInterval(loadList, 8000)
})
onBeforeUnmount(() => {
  if (pollTimer) clearInterval(pollTimer)
})
</script>

<template>
  <div class="page proctor-page">
    <div class="page-heading">
      <div>
        <h1><ShieldCheck :size="20" /> 双机位监考</h1>
        <p>进行中的考试列表，点击「进入监考」在新页面查看考试详情与双机位画面</p>
      </div>
      <div class="head-ops">
        <button class="btn" @click="loadList"><RotateCw :size="15" />刷新</button>
      </div>
    </div>

    <section class="card table-card">
      <div class="table-head">
        <span>考生</span><span>应聘岗位</span><span>考试试卷</span><span>开考时间</span><span>截止时间</span><span>双机位要求</span><span>副机位</span><span class="ta-r">操作</span>
      </div>
      <div v-if="loading && !list.length" class="empty">正在加载...</div>
      <div v-else-if="!list.length" class="empty">
        <Video :size="26" />
        <p>当前没有进行中的笔试</p>
      </div>
      <div v-for="row in list" v-else :key="row.recordId" class="table-row">
        <span class="cell-name"><MiniAvatar :name="row.candidateName" :size="30" color="#2563eb" />{{ row.candidateName }}</span>
        <span>{{ row.positionTitle }}</span>
        <span class="cell-ellipsis">{{ row.paperName }}</span>
        <span>{{ fmt(row.startAt) }}</span>
        <span>{{ fmt(row.deadlineAt) }}</span>
        <span><em v-if="Number(row.forceDualCamera) === 1" class="force">强制开启</em><em v-else class="noforce">不强制</em></span>
        <span><i :class="['dot', row.subOnline ? 'on' : '']"></i>{{ row.subOnline ? '在线' : '未接入' }}</span>
        <span class="ta-r"><button class="btn enter" @click="openProctor(row)"><ShieldCheck :size="13" />进入监考</button></span>
      </div>
    </section>

    <ToastMessage :message="toast" />
  </div>
</template>

<style scoped>
.proctor-page{padding-bottom:30px}
.page-heading{display:flex;justify-content:space-between;align-items:flex-end;gap:16px;margin-bottom:18px}
.page-heading h1{font-size:22px;display:flex;align-items:center;gap:8px}
.page-heading p{font-size:12px;color:var(--muted);margin-top:5px}
.head-ops{display:flex;gap:8px}
.table-card{padding:6px 20px 14px}
.table-head,.table-row{display:grid;grid-template-columns:1.1fr 1.2fr 1.4fr .9fr .9fr .9fr .8fr .9fr;align-items:center;gap:10px}
.table-head{height:44px;font-size:11px;color:var(--subtle);font-weight:600;border-bottom:1px solid var(--line)}
.table-row{min-height:58px;font-size:12.5px;color:#33415c;border-bottom:1px solid #f0f4f9}
.table-row:last-child{border-bottom:none}
.cell-name{display:flex;align-items:center;gap:9px;font-weight:600;color:#1a3c6e}
.cell-ellipsis{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.ta-r{text-align:right}
.force{font-style:normal;color:var(--red);font-size:11px;font-weight:600}
.noforce{font-style:normal;color:var(--subtle);font-size:11px}
.dot{display:inline-block;width:8px;height:8px;border-radius:50%;background:#b3c0d4;margin-right:6px}
.dot.on{background:#22c55e;box-shadow:0 0 0 3px rgba(34,197,94,.15)}
.enter{height:30px;padding:0 13px;font-size:12px;display:inline-flex;align-items:center;gap:5px;border-color:var(--primary);color:var(--primary);background:#fff}
.enter:hover{background:var(--primary);color:#fff}
.empty{padding:60px 12px;text-align:center;color:var(--subtle);font-size:13px;display:flex;flex-direction:column;align-items:center;gap:10px}
.empty p{margin:0}
</style>
