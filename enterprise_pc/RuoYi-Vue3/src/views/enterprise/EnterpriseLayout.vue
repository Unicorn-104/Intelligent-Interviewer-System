<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import AppSidebar from '@/views/enterprise/components/AppSidebar.vue'
import AppTopbar from '@/views/enterprise/components/AppTopbar.vue'
import AiAssistantBall from '@/views/enterprise/components/AiAssistantBall.vue'

const route = useRoute()
const title = computed(() => route.meta.title || 'TalentFlow')
</script>

<template>
  <div class="enterprise-layout">
    <AppSidebar />
    <AppTopbar :title="title" />
    <main><RouterView /></main>
    <AiAssistantBall />
  </div>
</template>

<style src="./enterprise.css"></style>

<style scoped>
main { min-height: 100vh; padding-left: 220px; padding-top: 64px; }
</style>




