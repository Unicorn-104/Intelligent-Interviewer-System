<template>
  <div class="pending-page">
    <div class="pending-card">
      <div class="brand">
        <span class="brand-mark">AI</span>
        <span>慧科智聘</span>
      </div>
      <div v-loading="loading" class="status-body">
        <template v-if="status">
          <template v-if="bindingStatus === 1">
            <h1>企业已通过审核</h1>
            <p>您的企业账号已激活，可以进入企业招聘中心。</p>
            <el-button type="primary" @click="goDashboard">进入企业中心</el-button>
          </template>
          <template v-else-if="bindingStatus === 2">
            <h1>入驻申请未通过</h1>
            <p>审核意见：{{ status.rejectReason || '暂无说明，请联系平台管理员' }}</p>
            <p class="hint">您可以修正企业资料后联系平台重新审核。</p>
          </template>
          <template v-else-if="bindingStatus === 0">
            <h1>入驻申请审核中</h1>
            <p>企业「{{ status.companyName || '—' }}」的入驻申请已提交，请等待平台审核。</p>
            <p class="hint">审核通过后，重新登录即可进入企业招聘中心。</p>
          </template>
          <template v-else>
            <h1>账号尚未绑定企业</h1>
            <p>当前账号没有企业绑定记录，请联系平台管理员处理。</p>
          </template>
        </template>
        <template v-else-if="!loading">
          <h1>暂时无法获取审核状态</h1>
          <p>请稍后刷新，或重新登录后再试。</p>
        </template>

        <div class="actions">
          <el-button @click="load" :loading="loading">刷新状态</el-button>
          <el-button type="primary" plain @click="goPortal">浏览公开岗位</el-button>
          <el-button text type="danger" @click="handleLogout">退出登录</el-button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { getAccountStatus } from '@/api/portal'
import useUserStore from '@/store/modules/user'

const router = useRouter()
const userStore = useUserStore()
const status = ref(null)
const loading = ref(false)

const bindingStatus = computed(() => (status.value ? status.value.bindingStatus : null))

function load() {
  loading.value = true
  getAccountStatus()
    .then(res => {
      status.value = res.data || null
    })
    .catch(() => {
      status.value = null
    })
    .finally(() => {
      loading.value = false
    })
}

function goDashboard() {
  router.push('/enterprise/dashboard')
}

function goPortal() {
  router.push('/enterprise/portal')
}

function handleLogout() {
  userStore.logOut().finally(() => {
    router.push('/enterprise/login')
  })
}

onMounted(load)
</script>

<style lang="scss" scoped>
.pending-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40px 20px;
  background: linear-gradient(135deg, #1e3fae 0%, #2f6bff 55%, #6b9bff 100%);
}
.pending-card {
  width: 520px;
  max-width: 100%;
  background: #fff;
  border-radius: 14px;
  padding: 30px 34px 26px;
  box-shadow: 0 18px 48px rgba(11, 39, 110, 0.24);
}
.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  font-weight: 600;
  color: #1f2733;
  margin-bottom: 22px;
}
.brand-mark {
  width: 30px;
  height: 30px;
  border-radius: 8px;
  background: linear-gradient(135deg, #2f6bff, #5a8bff);
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}
.status-body {
  min-height: 120px;
  h1 {
    margin: 0 0 12px;
    font-size: 21px;
    color: #1f2733;
  }
  p {
    margin: 0 0 10px;
    color: #5a6577;
    line-height: 1.7;
  }
  .hint {
    color: #8a94a6;
    font-size: 13px;
  }
}
.actions {
  margin-top: 22px;
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}
</style>
