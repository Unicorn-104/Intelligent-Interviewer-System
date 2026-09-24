<template>
  <div class="notification-bell">
    <button class="icon-button" type="button" aria-label="打开消息通知" :aria-expanded="String(open)" @click.stop="toggle">
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" /></svg>
      <span v-if="unreadCount" class="notification-dot"></span>
    </button>
    <div v-if="open" class="notification-popover" role="dialog" aria-label="消息通知">
      <div class="popover-head"><strong>消息通知</strong><button type="button" @click="markAllRead">全部标为已读</button></div>
      <button v-for="item in notifications" :key="item.id" class="notification-item" type="button" @click="openNotification(item.id)">
        <span class="notification-icon">{{ item.icon }}</span>
        <span class="notification-copy"><span class="notification-title">{{ item.title }}</span><time>{{ item.time }}</time></span>
      </button>
    </div>
  </div>
</template>

<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const storageKey = 'zhipin-ai-unread-notifications'
const notifications = [
  { id: 'notice-interview-invite', icon: '面', title: '极氪智能科技邀请你参加线上面试', time: '今天 09:12' },
  { id: 'notice-job-match', icon: '荐', title: 'AI 为你发现 6 个高匹配新岗位', time: '今天 08:35' },
  { id: 'notice-company-update', icon: '企', title: '你关注的企业小红书发布了招聘动态', time: '昨天 18:20' }
]
const open = ref(false)
const unreadCount = ref(notifications.length)

function readUnreadIds() {
  try {
    const stored = JSON.parse(localStorage.getItem(storageKey) || 'null')
    return Array.isArray(stored) ? stored : notifications.map((item) => item.id)
  } catch {
    return notifications.map((item) => item.id)
  }
}

function syncUnreadCount() {
  unreadCount.value = readUnreadIds().length
  document.querySelectorAll('[data-unread-badge]').forEach((badge) => {
    badge.textContent = unreadCount.value
    badge.style.display = unreadCount.value ? '' : 'none'
  })
}

function saveUnreadIds(ids) {
  try { localStorage.setItem(storageKey, JSON.stringify(ids)) } catch { /* 隐私模式下保留当前页面状态 */ }
  syncUnreadCount()
  window.dispatchEvent(new CustomEvent('agent-notifications-updated'))
}

function toggle() { open.value = !open.value }

function markAllRead() {
  saveUnreadIds([])
  open.value = false
}

function openNotification(id) {
  const ids = readUnreadIds().filter((item) => item !== id)
  saveUnreadIds(ids)
  open.value = false
  router.push({ path: '/agent/messages', query: { view: 'system' }, hash: `#${id}` })
}

function closeOnOutsideClick(event) {
  if (open.value && !event.target.closest('.notification-bell')) open.value = false
}

onMounted(() => {
  syncUnreadCount()
  document.addEventListener('click', closeOnOutsideClick)
  window.addEventListener('agent-notifications-updated', syncUnreadCount)
})

onBeforeUnmount(() => {
  document.removeEventListener('click', closeOnOutsideClick)
  window.removeEventListener('agent-notifications-updated', syncUnreadCount)
})
</script>

<style>
.notification-bell{position:relative;display:flex;align-items:center}
.notification-bell .icon-button{position:relative;width:40px;height:40px;display:grid;place-items:center;border:0;border-radius:9px;color:var(--muted,#6B7A90);background:transparent}
.notification-bell .icon-button:hover,.notification-bell .icon-button:focus-visible{color:var(--primary,#1A3C6E);background:var(--blue-soft,#EAF2FF);outline:none}
.notification-bell .icon-button svg{width:19px;height:19px;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}
.notification-bell .notification-dot{position:absolute;top:7px;right:7px;width:7px;height:7px;border:2px solid #fff;border-radius:50%;background:var(--red,#D94B55)}
.notification-bell .notification-popover{position:fixed;z-index:30;top:63px;right:max(24px,calc((100vw - 1240px) / 2));width:320px;display:block;border:1px solid var(--line,#E6EBF2);border-radius:10px;background:#fff;box-shadow:0 16px 38px rgba(23,43,77,.16);overflow:hidden;animation:notification-pop-in .16s ease-out}
@keyframes notification-pop-in{from{opacity:0;transform:translateY(-5px)}to{opacity:1;transform:translateY(0)}}
.notification-bell .popover-head{display:flex;align-items:center;justify-content:space-between;padding:15px 16px;border-bottom:1px solid var(--line,#E6EBF2)}
.notification-bell .popover-head strong{color:var(--primary,#1A3C6E);font-size:14px}
.notification-bell .popover-head button{padding:0;border:0;color:var(--blue,#2B7FFF);background:transparent;font-size:11px}
.notification-bell .notification-item{width:100%;display:flex;gap:10px;padding:13px 16px;border:0;border-bottom:1px solid #F1F3F7;text-align:left;background:#fff}
.notification-bell .notification-item:hover{background:#F7FAFF}
.notification-bell .notification-icon{width:28px;height:28px;display:grid;place-items:center;flex:0 0 auto;border-radius:7px;color:var(--blue,#2B7FFF);background:var(--blue-soft,#EAF2FF);font-size:12px;font-weight:800}
.notification-bell .notification-copy{min-width:0;display:block}
.notification-bell .notification-title{display:block;color:var(--text,#172B4D);font-size:12px;line-height:1.45;overflow-wrap:anywhere}
.notification-bell time{display:block;margin-top:4px;color:var(--light,#96A3B5);font-size:10px;line-height:1.4}
@media(max-width:640px){.notification-bell .notification-popover{top:57px;right:14px;width:min(320px,calc(100vw - 28px))}}
</style>
