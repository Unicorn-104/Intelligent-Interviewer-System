<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { Search, Bell, ChevronDown, UserRound, UserX } from '@/views/enterprise/components/icons'
import MiniAvatar from './MiniAvatar.vue'
import useUserStore from '@/store/modules/user'

defineProps({ title: String })

const router = useRouter()
const userStore = useUserStore()

const nickName = computed(() => userStore.nickName || userStore.name || '未登录')
const account = computed(() => userStore.name || '--')

function goProfile() {
  router.push('/enterprise/profile')
}

function handleLogout() {
  ElMessageBox.confirm('确定要退出登录吗？', '提示', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(() => {
    userStore.logOut().then(() => {
      location.href = '/login'
    })
  }).catch(() => {})
}
</script>

<template>
  <header class="topbar">
    <div class="crumb"><span>工作台</span><b>/</b><strong>{{ title }}</strong></div>
    <div class="actions">
      <label class="search"><Search :size="17" /><input placeholder="搜索候选人、岗位或消息" /></label>
      <button class="bell"><Bell :size="19" /><i /></button>
      <el-dropdown trigger="hover" class="account-dropdown">
        <div class="account">
          <MiniAvatar :name="nickName" :size="34" color="#8b5e83" :src="userStore.avatar" />
          <div><b>{{ nickName }}</b><small>招聘管理员</small></div>
          <ChevronDown :size="14" />
        </div>
        <template #dropdown>
          <el-dropdown-menu class="account-menu">
            <div class="menu-user-info">
              <MiniAvatar :name="nickName" :size="40" color="#8b5e83" :src="userStore.avatar" />
              <div class="menu-user-meta">
                <div class="menu-user-name">{{ nickName }}</div>
                <div class="menu-user-account">账号：{{ account }}</div>
              </div>
            </div>
            <el-dropdown-item @click="goProfile">
              <UserRound :size="16" />
              <span>个人中心 / 修改密码</span>
            </el-dropdown-item>
            <el-dropdown-item divided @click="handleLogout">
              <UserX :size="16" />
              <span>退出登录</span>
            </el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>
    </div>
  </header>
</template>

<style scoped>
.topbar { position: fixed; z-index: 15; left: 220px; right: 0; top: 0; height: 64px; padding: 0 28px; background: rgba(255,255,255,.94); backdrop-filter: blur(10px); border-bottom: 1px solid #e8edf5; display: flex; justify-content: space-between; align-items: center; }
.crumb { display: flex; align-items: center; gap: 9px; font-size: 14px; }.crumb span,.crumb b{color:#a0acc0;font-weight:400}.crumb strong{font-size:16px}
.actions { display: flex; align-items: center; gap: 14px; }
.search { width: 260px; height: 38px; border-radius: 10px; display: flex; gap: 9px; align-items: center; padding: 0 13px; background: #f2f5f9; color: #8fa0b8; }
.search input { flex: 1; border: 0; outline: 0; background: transparent; color: var(--text); font-size: 12px; }
.bell { position: relative; border: 0; background: #f3f6fa; color: #52637e; width: 38px; height: 38px; border-radius: 10px; display: grid; place-items: center; }
.bell i { position: absolute; right: 7px; top: 6px; width: 7px; height: 7px; border-radius: 50%; background: #ef4444; border: 1.5px solid white; }

.account-dropdown { display: inline-block; }
.account { display: flex; align-items: center; gap: 9px; cursor: pointer; padding: 4px 8px; border-radius: 10px; transition: background .2s; }
.account:hover { background: #f2f5f9; }
.account b{display:block;font-size:12px;color:#1f2937}.account small{display:block;font-size:10px;color:#8796ac;margin-top:2px}

:deep(.account-menu) { padding: 0; min-width: 220px; border-radius: 12px; box-shadow: 0 8px 24px rgba(30,41,59,.12); border: 1px solid #e8edf5; }
:deep(.menu-user-info) { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-bottom: 1px solid #edf1f6; }
:deep(.menu-user-meta) { line-height: 1.5; }
:deep(.menu-user-name) { font-size: 14px; font-weight: 600; color: #1f2937; }
:deep(.menu-user-account) { font-size: 12px; color: #8796ac; margin-top: 2px; }
:deep(.el-dropdown-menu__item) { display: flex; align-items: center; gap: 10px; padding: 10px 16px; font-size: 13px; color: #374151; }
:deep(.el-dropdown-menu__item:hover) { background: #f2f5f9; color: #2563eb; }
:deep(.el-dropdown-menu__item .el-icon) { margin-right: 0; color: inherit; }
</style>
