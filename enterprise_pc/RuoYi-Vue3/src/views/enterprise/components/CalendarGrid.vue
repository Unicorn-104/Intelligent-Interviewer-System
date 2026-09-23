<script setup>
import { ref } from 'vue'
import { schedule } from '@/views/enterprise/data/mock'
defineEmits(['day-click'])
const days = ['周一','周二','周三','周四','周五','周六','周日']
const dates = [7,8,9,10,11,12,13]
const blocked = ref(false)
defineExpose({ toggleBlocked: () => blocked.value = !blocked.value })
</script>

<template>
  <div class="calendar">
    <div class="corner"></div>
    <button v-for="(day,i) in days" :key="day" class="day-head" :class="{ today:i===2 }" @click="$emit('day-click',i)"><span>{{ day }}</span><b>{{ dates[i] }}</b></button>
    <div class="times"><span v-for="h in 10" :key="h">{{ String(h+8).padStart(2,'0') }}:00</span></div>
    <div v-for="day in 7" :key="day" class="day-col">
      <i v-for="n in 10" :key="n" class="line"></i>
      <div v-if="blocked" class="blocked"><span>非空闲时间</span></div>
      <article v-for="item in schedule.filter(x=>x.day===day-1)" :key="item.time+item.name" class="event" :class="`level-${item.level}`" :style="{ top:`${item.top}px`,height:`${item.duration}px` }"><small>{{ item.time }}</small><b>{{ item.name }}</b></article>
    </div>
  </div>
</template>

<style scoped>
.calendar{display:grid;grid-template-columns:48px repeat(7,1fr);grid-template-rows:58px 500px;border:1px solid #e2e9f2;border-radius:9px;overflow:hidden}.corner{background:#f8fafc;border-right:1px solid #e5ebf3}.day-head{border:0;border-right:1px solid #e5ebf3;border-bottom:1px solid #e5ebf3;background:#fff;color:#7b8ba1}.day-head span,.day-head b{display:block}.day-head span{font-size:10px}.day-head b{font-size:14px;margin-top:3px}.day-head.today{color:#2563eb;background:#f4f8ff}.day-head.today b{width:28px;height:28px;line-height:28px;margin:2px auto 0;border-radius:50%;background:#2563eb;color:#fff}.times{display:flex;flex-direction:column;justify-content:space-around;background:#fff;color:#7b8ba1;font-size:9px;text-align:center}.day-col{position:relative;border-left:1px solid #e5ebf3;background:#fff;display:flex;flex-direction:column}.line{flex:1;border-bottom:1px solid #edf1f6}.event{position:absolute;left:3px;right:3px;border-radius:6px;padding:5px 6px;color:#174584;background:#d9e9ff;border-left:3px solid #72aaff;overflow:hidden;z-index:2}.event small,.event b{display:block;font-size:8px}.event b{font-size:10px;margin-top:2px}.event.level-2{color:white;background:#3d82f6;border-color:#3d82f6}.event.level-3{color:white;background:#2151d8;border-color:#2151d8}.blocked{position:absolute;inset:200px 0 0;background:repeating-linear-gradient(135deg,#f2f4f8,#f2f4f8 8px,#e9edf3 8px,#e9edf3 16px);opacity:.9;z-index:1;display:flex;align-items:center;justify-content:center;color:#7e8da2;font-size:9px}.blocked span{background:white;padding:4px 8px;border-radius:6px}
</style>



