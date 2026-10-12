<script setup>
import { ref, computed, reactive } from 'vue'
import { schedule as rawSchedule } from '@/views/enterprise/data/mock'

const schedule = reactive(rawSchedule.map(item => ({...item})))

const emit = defineEmits(['day-click', 'block-click'])
const days = ['周一','周二','周三','周四','周五','周六','周日']
const dates = [7,8,9,10,11,12,13]
const blocked = ref(false)
const dayCols = ref([])
defineExpose({ toggleBlocked: () => blocked.value = !blocked.value, schedule })

// 日历时间范围：09:00-18:00 = 540分钟 = 9小时
const TOTAL_MIN = 540
function minToTime(startMin, durMin) {
  const s = 9*60 + startMin
  const e = s + durMin
  const fmt = m => String(Math.floor(m/60)).padStart(2,'0') + ':' + String(m%60).padStart(2,'0')
  return fmt(s) + '-' + fmt(e)
}
function posStyle(item) {
  return {
    top: (item.startMin / TOTAL_MIN * 100) + '%',
    height: (item.durMin / TOTAL_MIN * 100) + '%'
  }
}

// 每天面试场次数
const dayCounts = computed(() => {
  const counts = [0,0,0,0,0,0,0]
  schedule.forEach(s => counts[s.day]++)
  return counts
})

const statusClass = {
  pending:   'st-pending',
  confirmed: 'st-confirmed',
  completed: 'st-completed',
  conflict:  'st-conflict',
  cancelled: 'st-cancelled'
}

function openBlock(item) {
  emit('block-click', item)
}

// === 拖拽调整时间 ===
function onMouseDown(e, item, colEl) {
  const startY = e.clientY
  const startMin = item.startMin
  const colH = colEl.clientHeight
  e.preventDefault()

  const onMove = (ev) => {
    const deltaY = ev.clientY - startY
    const deltaMin = Math.round(deltaY / colH * TOTAL_MIN / 15) * 15
    let newMin = startMin + deltaMin
    newMin = Math.max(0, Math.min(TOTAL_MIN - item.durMin, newMin))
    item.startMin = newMin
    item.time = minToTime(newMin, item.durMin)
  }
  const onUp = () => {
    document.removeEventListener('mousemove', onMove)
    document.removeEventListener('mouseup', onUp)
  }
  document.addEventListener('mousemove', onMove)
  document.addEventListener('mouseup', onUp)
}
</script>

<template>
  <div class="calendar">
    <!-- 顶部日期行 -->
    <div class="cal-header">
      <div class="corner"></div>
      <button v-for="(day,i) in days" :key="day" class="day-head" :class="{ today:i===2, weekend:i>=5 }" @click="$emit('day-click',i)">
        <span>{{ day }}</span>
        <b>{{ dates[i] }}</b>
        <em v-if="dayCounts[i]" class="count-badge">{{ dayCounts[i] }}</em>
      </button>
    </div>
    <!-- 内容区：时间列 + 7天列 -->
    <div class="cal-body">
      <div class="times">
        <span class="tlabel" style="top:0;transform:none;padding-top:2px">09:00</span>
        <span v-for="h in 9" :key="h" class="tlabel" :class="{last:h===9}" :style="{ top: (h/9*100)+'%' }">{{ String(h+9).padStart(2,'0') }}:00</span>
      </div>
      <div v-for="day in 7" :key="day" class="day-col" :class="{ weekend: day>=6 }" :ref="el => dayCols[day-1] = el">
        <!-- 每小时网格线：absolute 定位，和面试块同一坐标系（含09:00线） -->
        <div class="hour-line line-0"></div>
        <div v-for="h in 9" :key="h" class="hour-line" :style="{ top: (h/9*100)+'%' }"></div>
        <div v-if="blocked" class="blocked"><span>非空闲时间</span></div>
        <article
          v-for="item in schedule.filter(x=>x.day===day-1)"
          :key="item.id"
          class="event"
          :class="[statusClass[item.status], { compact: item.durMin < 30 }]"
          :style="posStyle(item)"
          @click="openBlock(item)"
          @mousedown="onMouseDown($event, item, dayCols[day-1])"
        >
          <i v-if="item.notify==='failed'" class="notify-icon fail" title="通知发送失败">!</i>
          <i v-else-if="item.notify==='unsent'" class="notify-icon unsent" title="通知未发送">◔</i>
          <i v-else-if="item.notify==='sending'" class="notify-icon sending" title="发送中">◌</i>
          <div class="ev-line ev-name">{{ item.candidate }} · {{ item.position }}</div>
          <div class="ev-line ev-sub">{{ item.interviewer }} · {{ item.stage }}</div>
        </article>
      </div>
    </div>
  </div>
</template>

<style scoped>
.calendar{display:flex;flex-direction:column;border:1px solid #e2e9f2;border-radius:9px;overflow:hidden;flex:1;min-height:0;background:#fff}

/* 顶部日期行 */
.cal-header{display:flex;height:58px;flex-shrink:0;border-bottom:1px solid #e5ebf3}
.corner{width:48px;background:#f8fafc;border-right:1px solid #e5ebf3;flex-shrink:0}
.day-head{flex:1;border:0;border-right:1px solid #e5ebf3;background:#fff;color:#7b8ba1;position:relative;padding:6px 0 4px;cursor:pointer}
.day-head span,.day-head b{display:block}
.day-head span{font-size:10px}
.day-head b{font-size:14px;margin-top:2px}
.day-head.weekend{background:#fafbfc;color:#94a3b8}
.day-head.today{color:#2563eb;background:#f4f8ff}
.day-head.today b{width:28px;height:28px;line-height:28px;margin:2px auto 0;border-radius:50%;background:#2563eb;color:#fff}
.count-badge{position:absolute;top:5px;right:6px;font-size:9px;background:#e2e8f0;color:#64748b;border-radius:8px;padding:1px 5px;font-style:normal}
.day-head.today .count-badge{background:#dbeafe;color:#2563eb}

/* 内容区 */
.cal-body{display:flex;flex:1;min-height:0;position:relative}

/* 时间标签列 */
.times{width:48px;flex-shrink:0;position:relative;background:#f8fafc;color:#475569;font-size:10px;font-weight:500}
.tlabel{position:absolute;right:5px;transform:translateY(-50%);line-height:1}
.tlabel.last{transform:translateY(-100%);padding-bottom:2px}

/* 每天列 */
.day-col{flex:1;position:relative;border-left:1px solid #e2e8f0;background:#fff}
.day-col.weekend{background-color:#fafbfc}

/* 每小时网格线：absolute，和 event 同一坐标系 */
.hour-line{position:absolute;left:0;right:0;border-top:1px solid #e2e8f0}
.line-0{top:0;border-top-color:#cbd5e1}

/* 面试块 */
.event{position:absolute;left:6px;right:6px;border-radius:6px;padding:4px 8px;overflow:hidden;z-index:2;cursor:grab;transition:filter .12s,transform .12s;border-left:3px solid transparent}
.event:active{cursor:grabbing}
.event.dragging{opacity:.7;z-index:10}
.event:hover{filter:brightness(.95);transform:translateY(-1px)}
.ev-line{font-size:10px;line-height:1.3;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ev-name{font-weight:600}
.ev-sub{font-size:9px;opacity:.85;margin-top:1px}

/* 状态颜色 */
.st-pending{background:#fef3c7;color:#92400e;border-left-color:#f59e0b}
.st-pending .ev-sub{color:#b45309}
.st-confirmed{background:#dbeafe;color:#1e40af;border-left-color:#2563eb}
.st-confirmed .ev-sub{color:#3b82f6}
.st-completed{background:#e2e8f0;color:#64748b;border-left-color:#94a3b8}
.st-conflict{background:#fee2e2;color:#991b1b;border:1.5px solid #dc2626;border-left:3px solid #dc2626}
.st-conflict .ev-sub{color:#dc2626}
.st-cancelled{background:#f1f5f9;color:#94a3b8;text-decoration:line-through;border-left-color:#cbd5e1}

/* 紧凑块 */
.event.compact .ev-sub{display:none}
.event.compact{padding:2px 6px}
.event.compact .ev-name{font-size:10px}

/* 通知微标识 */
.notify-icon{position:absolute;top:3px;right:4px;font-style:normal;font-size:9px;font-weight:700;width:13px;height:13px;line-height:13px;text-align:center;border-radius:50%}
.notify-icon.fail{background:#dc2626;color:#fff}
.notify-icon.unsent{background:#94a3b8;color:#fff}
.notify-icon.sending{background:#3b82f6;color:#fff;animation:spin 1s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}

.blocked{position:absolute;inset:200px 0 0;background:repeating-linear-gradient(135deg,#f2f4f8,#f2f4f8 8px,#e9edf3 8px,#e9edf3 16px);opacity:.9;z-index:1;display:flex;align-items:center;justify-content:center;color:#7e8da2;font-size:9px}
.blocked span{background:white;padding:4px 8px;border-radius:6px}
</style>
