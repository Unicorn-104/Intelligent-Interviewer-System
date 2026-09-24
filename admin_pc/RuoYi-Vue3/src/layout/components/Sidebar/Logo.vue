<template>
  <div class="sidebar-logo-container" :class="{ collapse: collapse }">
    <transition name="sidebarLogoFade">
      <router-link v-if="collapse" key="collapse" class="sidebar-logo-link" to="/">
        <img v-if="logo" :src="logo" class="sidebar-logo" alt="智聘 Agent" />
        <h1 v-else class="sidebar-title">{{ title }}</h1>
      </router-link>
      <router-link v-else key="expand" class="sidebar-logo-link" to="/">
        <img v-if="logo" :src="logo" class="sidebar-logo" alt="智聘 Agent" />
        <h1 class="sidebar-title">{{ title }}</h1>
      </router-link>
    </transition>
  </div>
</template>

<script setup>
import useSettingsStore from '@/store/modules/settings'
import variables from '@/assets/styles/variables.module.scss'

const logo = '/zhpin-agent-mark.svg'

defineProps({
  collapse: {
    type: Boolean,
    required: true
  }
})

const title = '智聘 Agent'
const settingsStore = useSettingsStore()

// 获取Logo背景色
const getLogoBackground = computed(() => {
  if (settingsStore.navType == 3 && !settingsStore.isDark) {
    return variables.menuLightBg
  }
  return 'var(--brand-navy-deep)'
})

// 获取Logo文字颜色
const getLogoTextColor = computed(() => {
  if (settingsStore.navType == 3 && !settingsStore.isDark) {
    return variables.menuLightText
  }
  return '#ffffff'
})
</script>

<style lang="scss" scoped>
.sidebarLogoFade-enter-active {
  transition: opacity 1.5s;
}

.sidebarLogoFade-enter,
.sidebarLogoFade-leave-to {
  opacity: 0;
}

.sidebar-logo-container {
  position: relative;
  height: 58px;
  line-height: 58px;
  background: v-bind(getLogoBackground);
  overflow: hidden;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);

  & .sidebar-logo-link {
    display: flex;
    align-items: center;
    gap: 10px;
    height: 100%;
    width: 100%;
    padding: 0 16px;
    transition: background-color 0.18s ease;

    &:hover {
      background: rgba(255, 255, 255, 0.06);
    }

    & .sidebar-logo {
      flex: 0 0 auto;
      width: 34px;
      height: 34px;
      border-radius: 9px;
      box-shadow: 0 3px 10px rgba(0, 0, 0, 0.18);
    }

    & .sidebar-title {
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      margin: 0;
      color: v-bind(getLogoTextColor);
      font-weight: 600;
      line-height: 1;
      font-size: 15px;
      font-family:
        Avenir,
        Helvetica Neue,
        Arial,
        Helvetica,
        sans-serif;
    }
  }

  &.collapse {
    .sidebar-logo-link {
      justify-content: center;
      padding: 0;
    }

    .sidebar-logo {
      width: 32px;
      height: 32px;
    }
  }
}
</style>
