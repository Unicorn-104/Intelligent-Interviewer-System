<template>
  <div class="interview-practice-page">
    <AgentTopbar active="jobs" />
    <main class="interview-practice-main">
      <a :href="appHref('/jobs')">← 返回岗位浏览</a>
      <h1>AI 面试准备</h1>
      <p>选择自己的简历与已投递岗位，基于真实上下文生成面试问题、准备建议与回答反馈。不再使用固定题库，也不将答题完成率冒充能力评分。</p>
      <div class="interview-practice-assistant"><h2>使用悬浮助手准备面试</h2><p>选择已投递岗位，助手会关联投递时使用的简历。拖动标题栏可移动窗口，浏览其他页面时也能继续准备。</p><button type="button" @click="openCandidateAssistant('interview_preparation')">打开面试准备助手</button></div>
    </main>
  </div>
</template>
<script setup>
import AgentTopbar from '@/components/agent/AgentTopbar.vue'
import { openCandidateAssistant } from '@/utils/agentAssistantEntry'
import { appHref } from '@/utils/agentNavigation'
</script>
<style scoped>
.interview-practice-page{min-height:100vh;background:#f5f7fa;color:#2a4464;font-family:"Microsoft YaHei",sans-serif}.interview-practice-main{width:min(1000px,calc(100% - 32px));margin:24px auto}.interview-practice-main>a{color:#6b829f;text-decoration:none}.interview-practice-main h1{font-size:25px}.interview-practice-main p{max-width:820px;color:#76899e;font-size:13px;line-height:1.9}.interview-practice-assistant{height:calc(100dvh - 290px);min-height:520px;margin:22px 0 40px}
</style>

<style scoped>
.interview-practice-assistant{height:auto;min-height:0;padding:24px;border:1px solid #dae7fa;border-radius:16px;background:#fff}.interview-practice-assistant h2{margin-top:0;font-size:20px}.interview-practice-assistant button{padding:12px 20px;border:0;border-radius:10px;background:#2b7fff;color:#fff;cursor:pointer}
</style>
