<template>
  <router-view />
</template>

<script setup>
import useSettingsStore from '@/store/modules/settings'
import { handleThemeStyle } from '@/utils/theme'
import { useRouter } from 'vue-router'

const router = useRouter()

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
