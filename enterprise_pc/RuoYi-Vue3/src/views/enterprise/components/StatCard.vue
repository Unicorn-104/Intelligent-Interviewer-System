<script setup>
defineProps({ title: String, value: [String, Number], note: String, tone: { type: String, default: 'blue' }, icon: [Object, Function] })
</script>

<template>
  <article class="stat-card card" :class="tone">
    <div class="stat-top"><span>{{ title }}</span><span class="stat-icon"><component :is="icon" :size="18" /></span></div>
    <strong>{{ value }}</strong>
    <small>{{ note }}</small>
  </article>
</template>

<style scoped>
.stat-card { min-height: 126px; padding: 19px 21px; }
.stat-top { display: flex; align-items: center; justify-content: space-between; color: #667791; font-size: 13px; font-weight: 500; }
.stat-icon { width: 33px; height: 33px; border-radius: 10px; display: grid; place-items: center; color: var(--primary); background: #eaf1ff; }
strong { display: block; margin: 7px 0 1px; font-size: 29px; letter-spacing: -.8px; }
small { font-size: 11px; color: #8291a7; }.blue small{color:#1781d7}.green small{color:#08a978}.orange strong,.orange small{color:#ed7a08}.orange .stat-icon{color:#d97706;background:#fff3df}.green .stat-icon{color:#059669;background:#def7ec}
</style>



