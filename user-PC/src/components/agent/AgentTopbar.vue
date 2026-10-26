<template>
  <header class="agent-topbar">
    <div class="agent-topbar-inner">
      <a class="agent-brand" href="/agent/index" aria-label="智聘 AI 首页">
        <span class="agent-brand-mark">智</span>
        <span class="agent-brand-name">智聘 AI</span>
        <span class="agent-brand-tag">求职者工作台</span>
      </a>

      <nav class="agent-main-nav" aria-label="主导航">
        <a v-for="item in navItems" :key="item.path" class="agent-nav-link" :class="{ active: active === item.key }" :href="item.path">
          {{ item.label }}<span v-if="item.badge" class="agent-nav-badge" data-unread-badge>{{ item.badge }}</span>
        </a>
      </nav>

      <div class="agent-profile-menu">
        <button class="agent-profile-button" type="button" aria-haspopup="true">
          <span class="agent-avatar">{{ avatarText }}</span>
          <span class="agent-profile-meta"><span class="agent-profile-name">{{ displayName }}</span><span class="agent-profile-role">候选人</span></span>
        </button>
        <div class="agent-profile-popover" role="menu" aria-label="账号功能">
          <a href="/agent/profile-basic" role="menuitem">基础资料</a>
          <a href="/agent/profile-resumes" role="menuitem">我的简历</a>
          <a href="/agent/profile-security" role="menuitem">账号安全</a>
          <div class="agent-profile-divider"></div>
          <button class="agent-profile-action" type="button" @click="handleSwitchAccount">切换账号</button>
          <button class="agent-profile-action danger" type="button" @click="handleLogout">退出登录</button>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { ElMessageBox } from 'element-plus'
import { clearCandidateSession } from '@/utils/agentSession'
import { removeToken } from '@/utils/auth'
import useUserStore from '@/store/modules/user'
import { getNoticeUnreadCount } from '@/api/system/notice'

defineProps({
  active: {
    type: String,
    default: 'index'
  }
})

const router = useRouter()
const userStore = useUserStore()
const unreadCount = ref(0)
const displayName = computed(() => userStore.nickName || userStore.name || '求职者')
const avatarText = computed(() => displayName.value.slice(0, 1))

const baseNavItems = [
  { key: 'index', label: '首页', path: '/agent/index' },
  { key: 'jobs', label: '岗位浏览', path: '/agent/jobs' },
  { key: 'applications', label: '投递跟踪', path: '/agent/applications' },
  { key: 'messages', label: '消息通知', path: '/agent/messages' }
]
const navItems = computed(() => baseNavItems.map(item => ({
  ...item,
  badge: item.key === 'messages' && unreadCount.value ? String(unreadCount.value) : ''
})))

// 候选人端不调用企业端专属的 /system/im/**（求职者角色会被 403），仅统计系统通知未读
async function loadUnreadCount() {
  try {
    const noticeResponse = await getNoticeUnreadCount()
    unreadCount.value = Number(noticeResponse.data || 0)
  } catch {
    unreadCount.value = 0
  }
}

function handleNotificationUpdate() {
  loadUnreadCount()
}

async function clearAuthAndRedirect(target) {
  try {
    await userStore.logOut()
  } catch {
    userStore.$reset()
    removeToken()
  } finally {
    clearCandidateSession()
    await router.push(target)
  }
}

async function handleSwitchAccount() {
  await clearAuthAndRedirect({ path: '/agent/login', query: { switch: '1' } })
}

async function handleLogout() {
  try {
    await ElMessageBox.confirm('确定退出当前账号吗？', '提示', {
      confirmButtonText: '退出登录',
      cancelButtonText: '取消',
      type: 'warning'
    })
    await clearAuthAndRedirect('/agent/login')
  } catch {
    // 用户取消确认时保持当前页面与会话不变。
  }
}

onMounted(() => {
  loadUnreadCount()
  window.addEventListener('agent-notifications-updated', handleNotificationUpdate)
})

onBeforeUnmount(() => {
  window.removeEventListener('agent-notifications-updated', handleNotificationUpdate)
})
</script>

<style scoped>
.agent-topbar{position:sticky;top:0;z-index:40;height:72px;border-bottom:1px solid #E6EBF2;background:rgba(255,255,255,.97);backdrop-filter:blur(12px)}
.agent-topbar-inner{width:min(1240px,calc(100% - 48px));height:100%;display:grid;grid-template-columns:auto minmax(0,1fr) auto;align-items:center;gap:24px;margin:0 auto}
.agent-brand{display:inline-flex;align-items:center;gap:10px;color:#1A3C6E;text-decoration:none;white-space:nowrap}
.agent-brand-mark{width:34px;height:34px;display:grid;place-items:center;border-radius:9px;color:#fff;background:linear-gradient(145deg,#2B7FFF,#1A3C6E);box-shadow:0 5px 12px rgba(43,127,255,.22);font-size:17px;font-weight:800}
.agent-brand-name{font-size:18px;font-weight:800}
.agent-brand-tag{color:#6B7A90;font-size:11px}
.agent-main-nav{min-width:0;justify-self:center;height:72px;display:flex;align-items:center;gap:6px}
.agent-nav-link{position:relative;height:72px;display:inline-flex;align-items:center;padding:0 18px;color:#6B7A90;text-decoration:none;white-space:nowrap}
.agent-nav-link:hover,.agent-nav-link.active{color:#1A3C6E}
.agent-nav-link.active{font-weight:700}
.agent-nav-link.active::after{content:"";position:absolute;right:18px;bottom:0;left:18px;height:3px;border-radius:3px 3px 0 0;background:#2B7FFF}
.agent-nav-badge{min-width:17px;height:17px;margin-left:6px;padding:0 5px;display:inline-grid;place-items:center;border-radius:99px;color:#fff;background:#D94B55;font-size:10px;line-height:1}
.agent-profile-menu{position:relative;justify-self:end;min-width:0}
.agent-profile-button{height:48px;display:flex;align-items:center;gap:9px;min-width:0;padding:0;border:0;color:#172B4D;background:transparent}
.agent-avatar{width:34px;height:34px;display:grid;place-items:center;border-radius:50%;color:#fff;background:#7894BE;font-size:13px;font-weight:800}
.agent-profile-meta{display:block;min-width:max-content;text-align:left;line-height:1.25}
.agent-profile-name{display:block;white-space:nowrap;font-weight:700}
.agent-profile-role{display:block;margin-top:2px;color:#6B7A90;font-size:11px;white-space:nowrap}
.agent-profile-popover{position:absolute;top:48px;right:0;z-index:45;min-width:150px;padding:7px;border:1px solid #E1E8F2;border-radius:8px;background:#fff;box-shadow:0 16px 38px rgba(23,43,77,.14);opacity:0;visibility:hidden;transform:translateY(-4px);transition:.16s}
.agent-profile-menu:hover .agent-profile-popover,.agent-profile-menu:focus-within .agent-profile-popover{opacity:1;visibility:visible;transform:translateY(0)}
.agent-profile-popover a{height:36px;display:flex;align-items:center;padding:0 10px;border-radius:6px;color:#52647D;text-decoration:none;font-size:12px;font-weight:700}
.agent-profile-popover a:hover,.agent-profile-popover a:focus-visible{color:#1A3C6E;background:#EAF2FF;outline:none}
.agent-profile-divider{height:1px;margin:6px 4px;background:#E7EDF5}
.agent-profile-action{width:100%;height:36px;padding:0 10px;border:0;border-radius:6px;color:#52647D;background:transparent;text-align:left;font-size:12px;font-weight:700;cursor:pointer}
.agent-profile-action:hover,.agent-profile-action:focus-visible{color:#1A3C6E;background:#EAF2FF;outline:none}
.agent-profile-action.danger:hover,.agent-profile-action.danger:focus-visible{color:#C34B55;background:#FFF1F2}
@media(max-width:900px){.agent-topbar-inner{width:calc(100% - 32px);gap:14px}.agent-brand-tag,.agent-profile-meta{display:none}.agent-nav-link{padding:0 10px}.agent-nav-link.active::after{right:10px;left:10px}}
@media(max-width:640px){.agent-topbar{height:64px}.agent-topbar-inner{width:calc(100% - 28px);grid-template-columns:auto 1fr auto;gap:8px}.agent-brand-name{font-size:16px}.agent-main-nav{height:64px;gap:0}.agent-nav-link{height:64px;padding:0 5px;font-size:11px}.agent-nav-link.active::after{right:5px;left:5px}.agent-nav-badge{position:absolute;top:14px;right:0}.agent-profile-button{height:44px}.agent-profile-popover{top:44px}}
</style>
