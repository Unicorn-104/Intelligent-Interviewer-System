<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { Bot, X } from '@/views/enterprise/components/icons'
import AssistantView from '@/views/enterprise/assistant/index.vue'

// 悬浮 AI 助手小球：可拖动、位置持久化、点击展开助手面板（拖动位移<6px视为点击）
const POS_KEY = 'enterprise-ai-ball-pos'
const SIZE = 56
const PANEL_W = 920
const PANEL_H = 660
const ball = ref({ x: 0, y: 0 })
const open = ref(false)
const dragging = ref(false)
let startPt = { x: 0, y: 0 }
let originPos = { x: 0, y: 0 }
let moved = 0

function clamp(p) {
  return {
    x: Math.min(Math.max(p.x, 8), window.innerWidth - SIZE - 8),
    y: Math.min(Math.max(p.y, 8), window.innerHeight - SIZE - 8)
  }
}

function loadPos() {
  let saved = null
  try { saved = JSON.parse(localStorage.getItem(POS_KEY) || 'null') } catch (e) { /* 忽略损坏值 */ }
  ball.value = clamp(saved && Number.isFinite(saved.x) && Number.isFinite(saved.y)
    ? saved
    : { x: window.innerWidth - SIZE - 28, y: window.innerHeight - 180 })
}

function onPointerDown(e) {
  dragging.value = true
  moved = 0
  startPt = { x: e.clientX, y: e.clientY }
  originPos = { ...ball.value }
  e.currentTarget.setPointerCapture(e.pointerId)
}
function onPointerMove(e) {
  if (!dragging.value) return
  const dx = e.clientX - startPt.x
  const dy = e.clientY - startPt.y
  moved = Math.max(moved, Math.abs(dx), Math.abs(dy))
  ball.value = clamp({ x: originPos.x + dx, y: originPos.y + dy })
}
function onPointerUp() {
  if (!dragging.value) return
  dragging.value = false
  localStorage.setItem(POS_KEY, JSON.stringify(ball.value))
  if (moved < 6) open.value = !open.value
}

// 面板优先展开在小球朝向屏幕中心的一侧，并整体收敛在视口内
const panelStyle = computed(() => {
  const left = ball.value.x > window.innerWidth / 2
    ? ball.value.x - PANEL_W - 14
    : ball.value.x + SIZE + 14
  const x = Math.min(Math.max(left, 8), Math.max(window.innerWidth - PANEL_W - 8, 8))
  const y = Math.min(Math.max(ball.value.y - 120, 8), Math.max(window.innerHeight - PANEL_H - 8, 8))
  return { left: x + 'px', top: y + 'px', width: PANEL_W + 'px', height: PANEL_H + 'px' }
})

function onResize() {
  ball.value = clamp(ball.value)
}
onMounted(() => { loadPos(); window.addEventListener('resize', onResize) })
onBeforeUnmount(() => window.removeEventListener('resize', onResize))
</script>

<template>
  <div
    class="ai-ball"
    :class="{ dragging }"
    :style="{ left: ball.x + 'px', top: ball.y + 'px' }"
    title="AI助手"
    @pointerdown="onPointerDown"
    @pointermove="onPointerMove"
    @pointerup="onPointerUp"
  >
    <Bot :size="26" />
  </div>
  <Transition name="ai-pop">
    <div v-if="open" class="ai-panel" :style="panelStyle">
      <button class="ai-panel-close" title="收起" @click="open = false"><X :size="14" /></button>
      <div class="ai-panel-body"><AssistantView /></div>
    </div>
  </Transition>
</template>

<style scoped>
.ai-ball {
  position: fixed; z-index: 2000; width: 56px; height: 56px; border-radius: 50%;
  display: grid; place-items: center; color: #fff; cursor: grab; user-select: none;
  background: linear-gradient(135deg, #3b82f6, #6d55d9);
  box-shadow: 0 10px 26px rgba(37, 99, 235, .38);
  touch-action: none; transition: transform .15s ease;
}
.ai-ball:hover { transform: scale(1.07); }
.ai-ball.dragging { cursor: grabbing; transform: scale(1.1); transition: none; }
.ai-panel {
  position: fixed; z-index: 2001; display: flex; flex-direction: column;
  background: #f5f8fc; border: 1px solid #dde6f1; border-radius: 14px;
  box-shadow: 0 24px 64px rgba(15, 34, 67, .28); overflow: hidden;
}
.ai-panel-close {
  position: absolute; top: 12px; right: 14px; z-index: 5; border: 0; background: none;
  padding: 4px; color: #94a3b8; display: grid; place-items: center; cursor: pointer;
}
.ai-panel-close:hover { color: #dc2626; }
.ai-panel-body { flex: 1; min-height: 0; }
.ai-panel-body :deep(.assistant-page) { height: 100%; padding: 14px; --pad: 14px; }
.ai-panel-body :deep(.chat-head) { padding-right: 40px; }
.ai-pop-enter-active, .ai-pop-leave-active { transition: opacity .18s ease, transform .18s ease; }
.ai-pop-enter-from, .ai-pop-leave-to { opacity: 0; transform: scale(.96); }
</style>
