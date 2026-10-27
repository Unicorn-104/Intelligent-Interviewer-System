<template>
  <div class="app-container">
    <el-row :gutter="16" v-loading="loading">
      <el-col :span="4" v-for="v in overviewList" :key="v.label">
        <el-card shadow="hover" class="ov-card">
          <div class="ov-num">{{ v.value }}</div>
          <div class="ov-label">{{ v.label }}</div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16" style="margin-top:16px">
      <el-col :span="8">
        <el-card shadow="never">
          <template #header><b>岗位投递漏斗</b></template>
          <el-select v-model="jobId" placeholder="选岗位" style="width:100%" @change="loadJob">
            <el-option v-for="j in jobList" :key="j.pos_id" :label="j.pos_title" :value="j.pos_id" />
          </el-select>
          <div v-if="jobFunnel.length" style="margin-top:16px">
            <div v-for="s in jobFunnel" :key="s.stage" class="funnel-row">
              <span class="funnel-name">{{ s.stage }}</span>
              <el-progress :percentage="funnelPct(s.count)" :striped striped-flow />
              <span class="funnel-num">{{ s.count }}</span>
            </div>
          </div>
          <el-empty v-else description="选岗位查看漏斗" :image-size="60" />
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="never">
          <template #header><b>企业用量</b></template>
          <el-select v-model="companyId" placeholder="选企业" style="width:100%" @change="loadCompany">
            <el-option v-for="c in companyList" :key="c.company_id" :label="c.company_name" :value="c.company_id" />
          </el-select>
          <el-descriptions v-if="companyData" :column="1" border size="small" style="margin-top:16px">
            <el-descriptions-item label="员工数">{{ companyData.employees }}</el-descriptions-item>
            <el-descriptions-item label="在招岗位">{{ companyData.jobs }}</el-descriptions-item>
            <el-descriptions-item label="候选人">{{ companyData.candidates }}</el-descriptions-item>
            <el-descriptions-item label="面试记录">{{ companyData.interviews }}</el-descriptions-item>
          </el-descriptions>
          <el-empty v-else description="选企业查看用量" :image-size="60" />
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="never">
          <template #header><b>候选人全链路</b></template>
          <el-select v-model="talId" placeholder="选候选人" style="width:100%" @change="loadTalent">
            <el-option v-for="t in talList" :key="t.tal_id" :label="t.tal_name" :value="t.tal_id" />
          </el-select>
          <el-descriptions v-if="talData" :column="1" border size="small" style="margin-top:16px">
            <el-descriptions-item label="姓名">{{ talData.info.tal_name }}</el-descriptions-item>
            <el-descriptions-item label="状态">{{ talData.info.tal_status }}</el-descriptions-item>
            <el-descriptions-item label="面试次数">{{ (talData.interviews || []).length }}</el-descriptions-item>
          </el-descriptions>
          <el-timeline v-if="talData && talData.interviews && talData.interviews.length" style="margin-top:16px">
            <el-timeline-item
              v-for="(iv, i) in talData.interviews"
              :key="i"
              :timestamp="parseTime(iv.created_at || iv.iv_created_at)"
              placement="top"
            >
              面试记录 #{{ i + 1 }}
            </el-timeline-item>
          </el-timeline>
          <el-empty v-else description="选候选人查看链路" :image-size="60" />
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup name="OpsProbe">
import request from '@/utils/request'
const loading = ref(false)
const overview = ref({})
const jobList = ref([])
const companyList = ref([])
const talList = ref([])
const jobId = ref(null)
const companyId = ref(null)
const talId = ref(null)
const jobFunnel = ref([])
const companyData = ref(null)
const talData = ref(null)

const overviewList = computed(() => [
  { label: '在招岗位', value: overview.value.jobs || 0 },
  { label: '候选人总数', value: overview.value.talents || 0 },
  { label: '企业数', value: overview.value.companies || 0 },
  { label: '面试记录', value: overview.value.interviews || 0 },
  { label: '今日新增候选人', value: overview.value.todayNewTalents || 0 },
  { label: '待审核企业', value: overview.value.pendingVerify || 0 }
])

function loadOverview() {
  request({ url: '/admin/probe/overview' }).then((r) => (overview.value = r.data || {}))
}
function loadJobList() { request({ url: '/admin/probe/jobFunnel' }).then((r) => (jobList.value = r.data || [])) }
function loadCompanyList() { request({ url: '/admin/probe/companyUsage' }).then((r) => (companyList.value = r.data || [])) }
function loadTalList() { request({ url: '/admin/probe/talentTrace' }).then((r) => (talList.value = r.data || [])) }
function loadJob() { request({ url: '/admin/probe/jobFunnel', params: { posId: jobId.value } }).then((r) => (jobFunnel.value = r.data || [])) }
function loadCompany() { request({ url: '/admin/probe/companyUsage', params: { companyId: companyId.value } }).then((r) => (companyData.value = r.data)) }
function loadTalent() { request({ url: '/admin/probe/talentTrace', params: { talId: talId.value } }).then((r) => (talData.value = r.data)) }
function funnelPct(n) {
  const max = Math.max(...jobFunnel.value.map((x) => x.count), 1)
  return Math.round((n / max) * 100)
}
onMounted(() => {
  loading.value = true
  Promise.all([loadOverview(), loadJobList(), loadCompanyList(), loadTalList()]).finally(() => (loading.value = false))
})
</script>

<style scoped>
.ov-card { text-align: center; }
.ov-num { font-size: 28px; font-weight: bold; color: #4f6ef7; }
.ov-label { font-size: 13px; color: #999; margin-top: 4px; }
.funnel-row { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }
.funnel-name { width: 50px; font-size: 13px; }
.funnel-num { width: 40px; text-align: right; font-weight: bold; }
.funnel-row :deep(.el-progress) { flex: 1; }
</style>
