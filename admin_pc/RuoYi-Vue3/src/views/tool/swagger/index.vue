<template>
  <div class="app-container">
    <el-alert
      v-if="available === false"
      type="info"
      :closable="false"
      show-icon
      title="接口文档未启用"
    />
    <div v-if="available === false" class="doc-fallback">
      <p>当前后端未集成 Swagger/OpenAPI 文档页（访问 <code>/swagger-ui/index.html</code> 返回 404）。</p>
      <p>需要在线调试接口时，可在后端引入 springdoc-openapi 后重新部署；当前可直接查看 <code>deploy/full-deployment-guide.md</code> 中的接口清单。</p>
    </div>
    <i-frame v-else-if="available" v-model:src="url"></i-frame>
  </div>
</template>

<script setup name="ToolSwagger">
import iFrame from '@/components/iFrame'
import { ref } from 'vue'

const base = import.meta.env.VITE_APP_BASE_API
const url = ref(base + '/swagger-ui/index.html')
/** null=探测中，false=后端未启用，true=可正常打开 */
const available = ref(null)

fetch(url, { method: 'GET', credentials: 'include' })
  .then((r) => r.text())
  .then((t) => {
    // 代理在 404 时可能返回兜底页面，按内容特征判断更可靠
    available.value = /swagger-ui/i.test(t)
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
