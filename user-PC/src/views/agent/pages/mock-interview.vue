<template>
  <div class="interview-practice-page">
    <AgentTopbar active="jobs" />
    <main class="interview-practice-main">
      <a :href="appHref('/jobs')">← 返回岗位浏览</a>
      <h1>AI 面试准备</h1>
      <p>选择自己的简历与已投递岗位，基于真实上下文生成面试问题、准备建议与回答反馈。不再使用固定题库，也不将答题完成率冒充能力评分。</p>
      <div class="interview-practice-assistant"><AiAssistant standalone initial-action="interview_preparation" /></div>
    </main>
  </div>
</template>
<script setup>
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import AiAssistant from '@/components/agent/AiAssistant.vue'
import { appHref } from '@/utils/agentNavigation'
</script>
<style scoped>
.interview-practice-page{min-height:100vh;background:#f5f7fa;color:#2a4464;font-family:"Microsoft YaHei",sans-serif}.interview-practice-main{width:min(1000px,calc(100% - 32px));margin:24px auto}.interview-practice-main>a{color:#6b829f;text-decoration:none}.interview-practice-main h1{font-size:25px}.interview-practice-main p{max-width:820px;color:#76899e;font-size:13px;line-height:1.9}.interview-practice-assistant{height:calc(100dvh - 290px);min-height:520px;margin:22px 0 40px}
</style>
