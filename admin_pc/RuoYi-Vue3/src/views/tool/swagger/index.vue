<template>
  <i-frame v-model:src="url"></i-frame>
</template>

<script setup name="ToolSwagger">
import iFrame from '@/components/iFrame'

const url = ref(import.meta.env.VITE_APP_BASE_API + '/swagger-ui/index.html')
</script>
