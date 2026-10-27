<template>
  <router-view />
  <AiAssistant v-if="!isLoginPage" />
</template>

<script setup>
import useSettingsStore from '@/store/modules/settings'
import { handleThemeStyle } from '@/utils/theme'
import { useRouter, useRoute } from 'vue-router'
import AiAssistant from '@/components/AiAssistant/index.vue'

const router = useRouter()
const route = useRoute()
const isLoginPage = computed(() => route.path === '/login')

// Close all Element Plus popper/dropdown/select overlays before routing
// This prevents "Cannot read properties of null (reading 'parentNode')" errors
router.beforeEach(() => {
  const closers = document.querySelectorAll(
    '.el-popper.is-hint, .el-select-dropdown, .el-tooltip__popper, .el-picker__popper, .el-autocomplete-popover'
  )
  closers.forEach((el) => {
    if (el.parentNode) {
      // Trigger destroy before removal
      const vm = el.__vueParentComponent || el._vnode
      try {
        el.parentNode.removeChild(el)
      } catch (e) {}
    }
  })
})

onMounted(() => {
  nextTick(() => {
    handleThemeStyle(useSettingsStore().theme)
  })
})
</script>
