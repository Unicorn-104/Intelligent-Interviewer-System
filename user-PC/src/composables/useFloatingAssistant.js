import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

const positionKey = 'candidate-ai-floating-position:v1'
const margin = 8

export function clampFloatingPosition(position, size, viewport) {
  return {
    x: Math.max(margin, Math.min(position.x, Math.max(margin, viewport.width - size.width - margin))),
    y: Math.max(margin, Math.min(position.y, Math.max(margin, viewport.height - size.height - margin)))
  }
}

export function useFloatingAssistant(launcher, panel, enabled) {
  const launcherPosition = ref(null)
  const panelPosition = ref(null)
  const dragging = ref(false)
  let activeDrag = null
  let suppressClick = false
  let observer
  let storage
  let saved = {}
  let disposed = false
  const viewport = () => ({ width: window.innerWidth, height: window.visualViewport?.height || window.innerHeight })
  const elementFor = kind => kind === 'launcher' ? launcher.value : panel.value
  const positionFor = kind => kind === 'launcher' ? launcherPosition : panelPosition
  const styleFor = position => computed(() => enabled() && position.value
    ? { left: `${position.value.x}px`, top: `${position.value.y}px`, right: 'auto', bottom: 'auto' } : {})

  function savePosition(kind) {
    const element = elementFor(kind)
    const position = positionFor(kind).value
    if (!element || !position) return
    const bounds = element.getBoundingClientRect()
    const screen = viewport()
    saved[kind] = {
      x: (position.x - margin) / Math.max(1, screen.width - bounds.width - margin * 2),
      y: (position.y - margin) / Math.max(1, screen.height - bounds.height - margin * 2)
    }
    try { storage?.setItem(positionKey, JSON.stringify(saved)) } catch {}
  }

  function fit(kind) {
    const element = elementFor(kind)
    if (!enabled() || !element || disposed) return
    const bounds = element.getBoundingClientRect()
    const position = positionFor(kind)
    const screen = viewport()
    let next = position.value
    if (!next) {
      const restored = saved[kind]
      if (restored && [restored.x, restored.y].every(value => Number.isFinite(value) && value >= 0 && value <= 1)) {
        next = { x: margin + restored.x * Math.max(0, screen.width - bounds.width - margin * 2), y: margin + restored.y * Math.max(0, screen.height - bounds.height - margin * 2) }
      } else if (kind === 'panel' && launcherPosition.value) {
        next = { x: launcherPosition.value.x + (launcher.value?.offsetWidth || 0) - bounds.width, y: launcherPosition.value.y - bounds.height - 12 }
      } else next = { x: bounds.left, y: bounds.top }
    }
    position.value = clampFloatingPosition(next, bounds, screen)
  }

  function fitAll() {
    fit('launcher')
    fit('panel')
    savePosition('launcher')
    savePosition('panel')
  }

  function startDrag(event, kind) {
    if (!enabled() || !event.isPrimary || event.button !== 0 || activeDrag) return
    if (kind === 'panel' && event.target.closest('button, a, input, textarea, select')) return
    const element = elementFor(kind)
    if (!element) return
    fit(kind)
    suppressClick = false
    const start = positionFor(kind).value
    activeDrag = { kind, pointerId: event.pointerId, handle: event.currentTarget, start, clientX: event.clientX, clientY: event.clientY }
    event.currentTarget.setPointerCapture(event.pointerId)
  }

  function moveDrag(event) {
    if (!activeDrag || event.pointerId !== activeDrag.pointerId) return
    const deltaX = event.clientX - activeDrag.clientX
    const deltaY = event.clientY - activeDrag.clientY
    if (!dragging.value && Math.hypot(deltaX, deltaY) < 6) return
    dragging.value = true
    const element = elementFor(activeDrag.kind)
    if (!element) return
    positionFor(activeDrag.kind).value = clampFloatingPosition({ x: activeDrag.start.x + deltaX, y: activeDrag.start.y + deltaY }, element.getBoundingClientRect(), viewport())
  }

  function endDrag(event) {
    if (!activeDrag || event && event.pointerId !== activeDrag.pointerId) return
    const previous = activeDrag
    if (dragging.value) {
      suppressClick = previous.kind === 'launcher'
      savePosition(previous.kind)
    }
    activeDrag = null
    dragging.value = false
    if (previous.handle.hasPointerCapture(previous.pointerId)) previous.handle.releasePointerCapture(previous.pointerId)
  }

  function acceptClick(event) {
    if (event?.detail !== 0 && suppressClick) {
      suppressClick = false
      return false
    }
    suppressClick = false
    return true
  }

  function moveWithKeyboard(event, kind) {
    if (!enabled() || event.target !== event.currentTarget) return
    const direction = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }[event.key]
    if (!direction) return
    event.preventDefault()
    fit(kind)
    const position = positionFor(kind)
    const step = event.shiftKey ? 5 : 20
    position.value = clampFloatingPosition({ x: position.value.x + direction[0] * step, y: position.value.y + direction[1] * step }, elementFor(kind).getBoundingClientRect(), viewport())
    savePosition(kind)
  }

  watch([launcher, panel], async () => {
    await nextTick()
    if (disposed) return
    observer?.disconnect()
    if (launcher.value) observer?.observe(launcher.value)
    if (panel.value) observer?.observe(panel.value)
    fitAll()
  }, { flush: 'post' })

  onMounted(() => {
    if (!enabled()) return
    try {
      storage = window.sessionStorage
      const parsed = JSON.parse(storage.getItem(positionKey) || '{}')
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) saved = parsed
    } catch {}
    if (globalThis.ResizeObserver) observer = new ResizeObserver(fitAll)
    window.addEventListener('resize', fitAll)
    window.visualViewport?.addEventListener('resize', fitAll)
    fitAll()
    if (launcher.value) observer?.observe(launcher.value)
  })

  onBeforeUnmount(() => {
    disposed = true
    endDrag()
    observer?.disconnect()
    window.removeEventListener('resize', fitAll)
    window.visualViewport?.removeEventListener('resize', fitAll)
  })

  return { launcherStyle: styleFor(launcherPosition), panelStyle: styleFor(panelPosition), dragging, startDrag, moveDrag, endDrag, acceptClick, moveWithKeyboard }
}
