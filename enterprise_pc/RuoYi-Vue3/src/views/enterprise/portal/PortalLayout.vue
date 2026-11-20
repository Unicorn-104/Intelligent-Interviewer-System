<template>
  <div class="portal">
    <header class="portal-header">
      <div class="portal-header-inner">
        <router-link class="brand" to="/enterprise/portal">
          <span class="brand-mark">AI</span>
          <span class="brand-text">慧科智聘</span>
        </router-link>
        <nav class="nav">
          <router-link to="/enterprise/portal" exact-active-class="active">首页</router-link>
          <router-link to="/enterprise/portal/features" active-class="active">平台能力</router-link>
          <router-link to="/enterprise/portal/onboarding" active-class="active">入驻流程</router-link>
        </nav>
        <div class="actions">
          <template v-if="loggedIn">
            <router-link class="btn primary" to="/enterprise/dashboard">进入企业中心</router-link>
          </template>
          <template v-else>
            <router-link class="btn" to="/enterprise/login">登录</router-link>
            <router-link class="btn primary" to="/enterprise/register">企业注册</router-link>
          </template>
        </div>
      </div>
    </header>
    <main class="portal-main">
      <router-view />
    </main>
    <footer class="portal-footer">
      © 2026 智能面试官系统 · 企业招聘管理平台
    </footer>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { getToken } from '@/utils/auth'

const loggedIn = computed(() => !!getToken())
</script>

<style lang="scss" scoped>
.portal {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background: #f5f7fb;
  color: #1f2733;
}
.portal-header {
  position: sticky;
  top: 0;
  z-index: 10;
  background: #fff;
  border-bottom: 1px solid #e8ecf2;
}
.portal-header-inner {
  max-width: 1180px;
  margin: 0 auto;
  height: 64px;
  padding: 0 20px;
  display: flex;
  align-items: center;
  gap: 40px;
}
.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  text-decoration: none;
  color: #1f2733;
}
.brand-mark {
  width: 32px;
  height: 32px;
  border-radius: 9px;
  background: linear-gradient(135deg, #2f6bff, #5a8bff);
  color: #fff;
  font-size: 13px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}
.brand-text {
  font-size: 17px;
  font-weight: 600;
}
.nav {
  display: flex;
  gap: 24px;
  flex: 1;
  a {
    color: #5a6577;
    text-decoration: none;
    font-size: 15px;
    padding: 6px 0;
    border-bottom: 2px solid transparent;
    &.active {
      color: #2f6bff;
      border-bottom-color: #2f6bff;
    }
  }
}
.actions {
  display: flex;
  gap: 12px;
  align-items: center;
}
.btn {
  padding: 8px 18px;
  border-radius: 8px;
  font-size: 14px;
  text-decoration: none;
  color: #2f6bff;
  border: 1px solid #c8d7ff;
  background: #fff;
  &.primary {
    background: #2f6bff;
    border-color: #2f6bff;
    color: #fff;
  }
}
.portal-main {
  flex: 1;
  width: 100%;
}
.portal-footer {
  padding: 24px 20px;
  text-align: center;
  color: #9aa4b2;
  font-size: 13px;
}
</style>
