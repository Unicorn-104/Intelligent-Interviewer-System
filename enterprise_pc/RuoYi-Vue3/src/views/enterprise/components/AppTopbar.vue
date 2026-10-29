<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { Search, Bell, ChevronDown, UserRound, UserX } from '@/views/enterprise/components/icons'
import MiniAvatar from './MiniAvatar.vue'
import useUserStore from '@/store/modules/user'
import { listSessions } from '@/api/system/im'
import { listInterviewerNotices } from '@/api/system/conference'
import { refreshUnread, totalUnread } from '@/views/enterprise/store/unread'

defineProps({ title: String })

const router = useRouter()
const userStore = useUserStore()

const searchKeyword = ref('')
// 全局搜索统一进入搜索结果页，聚合展示候选人、岗位、消息
function doSearch() {
  const kw = searchKeyword.value.trim()
  if (!kw) return
  router.push({ path: '/enterprise/search', query: { keyword: kw } })
  searchKeyword.value = ''
}

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
      // 必须落在 vite base(/enterprise/) 内，避免整页跳转到 /login 后被开发服务器/部署环境拦截
      location.href = '/enterprise/login'
    })
  }).catch(() => {})
}

// ---------- 消息中心未读联动：红圈 + 悬停浮层 + 点击定位 ----------
const bellOpen = ref(false)
const unreadConvs = ref([])
const pendingNotices = ref([])

// 未读总数 = 聊天未读 + 待确认面试邀约（与消息中心角标口径一致）
const unreadTotal = computed(() => totalUnread.value + pendingNotices.value.length)

async function loadUnread() {
  await refreshUnread()
  try {
    const res = await listSessions()
    unreadConvs.value = (res.data || [])
      .filter(s => (s.unread || 0) > 0)
      .map(s => ({
        sessionId: s.sessionId,
        peerId: s.peerId,
        name: s.peerName || ('用户' + s.peerId),
        summary: s.lastMessage || '',
        unread: s.unread || 0
      }))
  } catch (e) {
    unreadConvs.value = []
  }
  try {
    const res = await listInterviewerNotices()
    pendingNotices.value = (res.data || []).filter(n => Number(n.acceptStatus) === 0)
  } catch (e) {
    pendingNotices.value = []
  }
}

let bellCloseTimer = null
function openBell() {
  if (bellCloseTimer) { clearTimeout(bellCloseTimer); bellCloseTimer = null }
  if (bellOpen.value) return
  bellOpen.value = true
  loadUnread()
}

// 延迟关闭：鼠标从铃铛移向浮层时会穿过两者之间的空隙，
// 空隙区域触发的 mouseleave 不应立即关闭浮层，进入浮层后由 openBell 取消关闭
function closeBell() {
  if (bellCloseTimer) clearTimeout(bellCloseTimer)
  bellCloseTimer = setTimeout(() => { bellOpen.value = false; bellCloseTimer = null }, 150)
}

// 点击某条未读会话：定位到消息中心并打开该会话
function openConversation(item) {
  bellOpen.value = false
  router.push({ path: '/enterprise/messages', query: { peerId: item.peerId, peerName: item.name } })
}

// 点击面试邀约：定位到消息中心的「面试预约通知」系统会话
function openNotices() {
  bellOpen.value = false
  router.push({ path: '/enterprise/messages', query: { notices: 1 } })
}

function goMessages() {
  bellOpen.value = false
  router.push('/enterprise/messages')
}

let timer = null
onMounted(() => {
  loadUnread()
  // 每 30 秒刷新一次未读，保证红圈与消息中心实时一致
  timer = setInterval(() => { if (!bellOpen.value) loadUnread() }, 30000)
})
onUnmounted(() => { if (timer) clearInterval(timer); if (bellCloseTimer) clearTimeout(bellCloseTimer) })
</script>

<template>
  <header class="topbar">
    <div class="crumb"><span>工作台</span><b>/</b><strong>{{ title }}</strong></div>
    <div class="actions">
      <label class="search"><Search :size="17" /><input v-model="searchKeyword" placeholder="搜索候选人、岗位或消息" @keyup.enter="doSearch" /></label>
      <div class="bell-wrap" @mouseenter="openBell" @mouseover="openBell" @mouseleave="closeBell">
        <button class="bell" title="消息中心" @click="goMessages"><Bell :size="19" /><i v-if="unreadTotal > 0" /></button>
        <div v-show="bellOpen" class="bell-pop">
          <header class="bp-head"><span>未读消息</span><em v-if="unreadTotal">{{ unreadTotal }}</em></header>
          <div class="bp-list">
            <article v-for="item in unreadConvs" :key="'c' + item.sessionId" @click="openConversation(item)">
              <MiniAvatar :name="item.name" :size="34" color="#356f65" />
              <div class="bp-info"><h4>{{ item.name }}</h4><p>{{ item.summary || '暂无消息' }}</p></div>
              <em class="bp-count">{{ item.unread }}</em>
            </article>
            <article v-for="n in pendingNotices" :key="'n' + n.sessionId" class="bp-notice" @click="openNotices">
              <span class="bp-sys"><Bell :size="17" /></span>
              <div class="bp-info"><h4>面试预约通知</h4><p>{{ n.candidateName }} · {{ n.positionTitle }} 邀约待确认</p></div>
              <em class="bp-count">1</em>
            </article>
            <p v-if="!unreadConvs.length && !pendingNotices.length" class="bp-none">暂无未读消息</p>
          </div>
          <button class="bp-more" @click="goMessages">查看全部消息</button>
        </div>
      </div>
      <el-dropdown trigger="hover" class="account-dropdown">
        <div class="account">
          <MiniAvatar :name="nickName" :size="34" color="#8b5e83" :src="userStore.avatar" title="点击进入个人中心" @click="goProfile" />
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
.search { width: 280px; height: 38px; border-radius: 10px; display: flex; gap: 9px; align-items: center; padding: 0 13px; background: #f2f5f9; color: #8fa0b8; }
.search input { flex: 1; min-width: 0; border: 0; outline: 0; background: transparent; color: var(--text); font-size: 12px; }
.bell { position: relative; border: 0; background: #f3f6fa; color: #52637e; width: 38px; height: 38px; border-radius: 10px; display: grid; place-items: center; cursor: pointer; }
.bell i { position: absolute; right: 7px; top: 6px; width: 7px; height: 7px; border-radius: 50%; background: #ef4444; border: 1.5px solid white; }

.bell-wrap { position: relative; }
.bell-pop { position: absolute; right: 0; top: 46px; width: 320px; background: #fff; border: 1px solid #e8edf5; border-radius: 12px; box-shadow: 0 10px 30px rgba(30,41,59,.14); z-index: 30; overflow: hidden; }
.bp-head { display: flex; align-items: center; gap: 8px; padding: 12px 14px; border-bottom: 1px solid #eef2f7; font-size: 13px; font-weight: 600; color: #1f2937; }
.bp-head em { font-style: normal; min-width: 18px; height: 18px; padding: 0 5px; border-radius: 9px; background: #ef4444; color: #fff; font-size: 11px; font-weight: 500; display: grid; place-items: center; }
.bp-list { max-height: 320px; overflow: auto; }
.bp-list article { display: flex; align-items: center; gap: 10px; padding: 10px 14px; cursor: pointer; border-bottom: 1px solid #f4f7fb; }
.bp-list article:hover { background: #f4f8ff; }
.bp-info { flex: 1; min-width: 0; }
.bp-info h4 { font-size: 12px; color: #1f2937; font-weight: 600; }
.bp-info p { font-size: 11px; color: #8796ac; margin-top: 3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.bp-count { flex: none; min-width: 18px; height: 18px; padding: 0 5px; border-radius: 9px; background: #2563eb; color: #fff; font-style: normal; font-size: 11px; display: grid; place-items: center; }
.bp-sys { flex: none; width: 34px; height: 34px; border-radius: 50%; background: #edf4ff; color: #2563eb; display: grid; place-items: center; }
.bp-none { text-align: center; color: #98a5b7; font-size: 12px; padding: 26px 0; }
.bp-more { width: 100%; height: 38px; border: 0; border-top: 1px solid #eef2f7; background: #fff; color: #2563eb; font-size: 12px; cursor: pointer; }
.bp-more:hover { background: #f4f8ff; }

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
