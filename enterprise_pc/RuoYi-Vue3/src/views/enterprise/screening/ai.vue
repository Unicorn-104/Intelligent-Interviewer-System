<script setup>
import AiScreeningPanel from './AiScreeningPanel.vue'
</script>

<template>
  <div class="page ai-screening-page">
    <div class="page-heading">
      <div>
        <h1>AI 初筛详情</h1>
        <p>按综合分 60 分阈值展示通过、未通过与待人工评分的候选人，可查看报告或人工评分</p>
      </div>
    </div>

    <AiScreeningPanel />
  </div>
</template>
