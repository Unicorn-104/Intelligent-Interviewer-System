<template>
  <router-view />
</template>

<script setup>
const router = useRouter()

window.__agentNavigate = (target) => {
  const url = new URL(target, window.location.origin)
  router.push(`${url.pathname}${url.search}${url.hash}`)
}

function handleInternalLink(event) {
  if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
    return
  }

  const link = event.target.closest('a')
  if (!link || link.target === '_blank' || link.hasAttribute('download')) {
    return
  }

  const href = link.getAttribute('href')
  if (!href || !href.startsWith('/agent')) {
    return
  }

  event.preventDefault()
  router.push(href)
}

onMounted(() => document.addEventListener('click', handleInternalLink))
onBeforeUnmount(() => document.removeEventListener('click', handleInternalLink))
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
