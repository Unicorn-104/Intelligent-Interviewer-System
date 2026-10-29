<template>
  <router-view />
</template>

<script setup>
import { toAppRoute } from '@/utils/agentNavigation'

const router = useRouter()

function navigate(target) {
  const route = toAppRoute(target)
  if (route !== null) return router.push(route)
}

window.__agentNavigate = navigate

function handleInternalLink(event) {
  if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
    return
  }

  const link = event.target.closest?.('a')
  if (!link || link.target === '_blank' || link.hasAttribute('download')) {
    return
  }

  const href = link.getAttribute('href')
  if (!href || href.startsWith('#') || /^https?:\/\//i.test(href)) {
    return
  }

  const route = toAppRoute(href)
  if (route === null || !router.resolve(route).meta.candidate) return

  event.preventDefault()
  router.push(route)
}

onMounted(() => {
  document.addEventListener('click', handleInternalLink)
})
onBeforeUnmount(() => {
  document.removeEventListener('click', handleInternalLink)
  if (window.__agentNavigate === navigate) delete window.__agentNavigate
})
</script>

<style scoped>
:global(html),
:global(body),
:global(#app) {
  min-height: 100%;
  height: 100%;
  margin: 0;
}
</style>
