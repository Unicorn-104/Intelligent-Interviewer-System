<template>
  <router-view />
  <AiAssistant :key="assistantIdentity" />
</template>

<script setup>
import useSettingsStore from '@/store/modules/settings'
import { handleThemeStyle } from '@/utils/theme'
import { computed } from 'vue'
import AiAssistant from '@/components/agent/AiAssistant.vue'
import useUserStore from '@/store/modules/user'

const userStore = useUserStore()
const assistantIdentity = computed(() => userStore.token ? `user-${userStore.id || 'pending'}` : 'guest')

onMounted(() => {
  nextTick(() => {
    // 初始化主题样式
    handleThemeStyle(useSettingsStore().theme)
  })
})
</script>
