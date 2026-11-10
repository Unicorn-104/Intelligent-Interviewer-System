<template>
  <div ref="container" class="application-progress">
    <svg v-if="layout.edges.length" class="application-progress-lines" :viewBox="`0 0 ${layout.width} ${layout.height}`" preserveAspectRatio="none" aria-hidden="true">
      <path v-for="edge in layout.edges" :key="edge.to" :d="edge.path" :class="{ reached: edge.reached }" />
    </svg>
    <ol class="application-progress-list" aria-label="投递流程进度" :style="{ gridTemplateColumns: `repeat(${layout.columns}, minmax(0, 1fr))`, gridAutoRows: `${layout.rowHeight}px` }">
      <li v-for="step in layout.steps" :key="step.index" class="application-progress-node" :class="step.node.state" :style="{ gridColumn: step.column + 1, gridRow: step.row + 1 }" :aria-current="['current', 'processing'].includes(step.node.state) ? 'step' : undefined">
        <span class="application-progress-dot" aria-hidden="true">{{ step.node.state === 'done' ? '✓' : step.index + 1 }}</span>
        <span class="application-progress-title"><span class="application-progress-sr">第 {{ step.index + 1 }} 步：</span>{{ step.node.title }}</span>
        <time class="application-progress-time" :datetime="step.node.occurredAt || undefined">{{ formatTime(step.node.occurredAt) }}</time>
      </li>
    </ol>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { applicationProgressLayout } from '@/utils/applicationProgress'

const props = defineProps({
  nodes: { type: Array, required: true },
  formatTime: { type: Function, required: true }
})
const container = ref(null)
const width = ref(800)
const layout = computed(() => applicationProgressLayout(props.nodes, width.value))
let observer

function measure() {
  const measured = container.value?.getBoundingClientRect().width
  if (measured > 0) width.value = measured
}

onMounted(() => {
  measure()
  if (typeof ResizeObserver !== 'undefined') {
    observer = new ResizeObserver(measure)
    observer.observe(container.value)
  } else {
    window.addEventListener('resize', measure)
  }
})

onBeforeUnmount(() => {
  observer?.disconnect()
  window.removeEventListener('resize', measure)
})
</script>

<style scoped>
.application-progress { position: relative; width: 100%; min-width: 0; }
.application-progress-lines { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; pointer-events: none; }
.application-progress-lines path { fill: none; stroke: #DDE6F2; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; vector-effect: non-scaling-stroke; }
.application-progress-lines path.reached { stroke: #20A36F; }
.application-progress-list { position: relative; display: grid; margin: 0; padding: 0 24px; list-style: none; }
.application-progress-node { display: flex; flex-direction: column; align-items: center; min-width: 0; padding: 0 6px; text-align: center; }
.application-progress-dot { display: flex; align-items: center; justify-content: center; flex: 0 0 32px; width: 32px; height: 32px; margin: 0 0 8px; padding: 0; box-sizing: border-box; border: 1px solid #D8E1ED; border-radius: 50%; color: #9AA7B7; background: #fff; font-size: 12px; font-weight: 800; line-height: 1; }
.application-progress-node.done .application-progress-dot,.application-progress-node.closed .application-progress-dot { border-color: #20A36F; color: #fff; background: #20A36F; }
.application-progress-node.current .application-progress-dot,.application-progress-node.processing .application-progress-dot { border-color: #2B7FFF; color: #fff; background: #2B7FFF; }
.application-progress-title { max-width: 100%; color: #687A91; font-size: 11px; line-height: 18px; overflow-wrap: anywhere; }
.application-progress-time { max-width: 100%; margin-top: 4px; color: #A1ADBC; font-size: 10px; line-height: 16px; font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }
.application-progress-node.current .application-progress-title,.application-progress-node.current .application-progress-time,.application-progress-node.processing .application-progress-title,.application-progress-node.processing .application-progress-time { color: #2B7FFF; font-weight: 700; }
.application-progress-sr { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
</style>
