<template>
  <div class="app-container">
    <el-alert
      v-if="available === false"
      type="info"
      :closable="false"
      show-icon
      title="Druid 监控视图未启用"
    />
    <div v-if="available === false" class="doc-fallback">
      <p>当前后端未开启 Druid 的 stat-view-servlet（<code>spring.datasource.druid.stat-view-servlet.enabled=false</code>），没有可嵌入的监控页。</p>
      <p>连接池与 SQL 指标可在「系统监控 → 缓存监控」或服务器日志中查看；如需本页，请在部署环境开启该配置并放行 <code>/druid/**</code> 访问。</p>
    </div>
    <i-frame v-else-if="available" v-model:src="url"></i-frame>
  </div>
</template>

<script setup name="MonitorData">
import iFrame from '@/components/iFrame'
import { ref } from 'vue'

const base = import.meta.env.VITE_APP_BASE_API
const url = ref(base + '/druid/login.html')
/** null=探测中，false=后端未启用，true=可正常打开 */
const available = ref(null)

fetch(url, { method: 'GET', credentials: 'include' })
  .then((r) => r.text())
  .then((t) => {
    // 代理在 404 时可能返回兜底页面，按内容特征判断更可靠
    available.value = /druid/i.test(t)
  })
  .catch(() => {
    available.value = false
  })
</script>

<style scoped>
.doc-fallback {
  padding: 12px 4px;
  color: var(--el-text-color-regular);
  line-height: 1.9;
}
</style>
