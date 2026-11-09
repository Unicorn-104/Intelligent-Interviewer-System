<template>
  <div v-if="active" class="face-guide" :class="`is-${state}`" aria-live="polite">
    <div class="guide-head"></div>
    <div class="guide-shoulder"></div>
    <div class="guide-tip">{{ tipText }}</div>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { FaceDetector, FilesetResolver } from '@mediapipe/tasks-vision'

const props = defineProps({
  videoEl: { type: Object, default: null },
  active: { type: Boolean, default: false },
  model: { type: String, default: 'blaze_face_short_range' },
  minRatio: { type: Number, default: 0.22 },
  maxRatio: { type: Number, default: 0.55 }
})

const TIPS = {
  ok: '位置合适',
  far: '距离过远，请靠近镜头',
  near: '距离过近，请后退一些',
  none: '未检测到人脸，请正对镜头'
}
const state = ref('ok')
const tipText = computed(() => TIPS[state.value])

const ASSET = `${import.meta.env.BASE_URL}mediapipe`
const detectorCache = new Map()

async function getDetector(model) {
  if (!detectorCache.has(model)) {
    detectorCache.set(model, (async () => {
      const fileset = await FilesetResolver.forVisionTasks(`${ASSET}/wasm`)
      const options = {
        baseOptions: { modelAssetPath: `${ASSET}/${model}.tflite`, delegate: 'GPU' },
        runningMode: 'VIDEO',
        minDetectionConfidence: 0.5
      }
      try {
        return await FaceDetector.createFromOptions(fileset, options)
      } catch {
        options.baseOptions.delegate = 'CPU'
        return await FaceDetector.createFromOptions(fileset, options)
      }
    })())
  }
  return detectorCache.get(model)
}

let timer = null
let busy = false
let lastRaw = ''
let stable = 0

async function tick() {
  const video = props.videoEl
  if (busy || !video || video.readyState < 2 || !video.videoWidth) return
  busy = true
  try {
    const detector = await getDetector(props.model)
    const box = detector.detectForVideo(video, performance.now())?.detections?.[0]?.boundingBox
    let next = 'none'
    if (box) {
      const ratio = box.height / video.videoHeight
      next = ratio < props.minRatio ? 'far' : ratio > props.maxRatio ? 'near' : 'ok'
    }
    stable = next === lastRaw ? stable + 1 : 0
    lastRaw = next
    if (stable >= 1) state.value = next
  } catch {
    // 检测异常不打断答题，保持上一次提示
  } finally {
    busy = false
  }
}

function start() {
  stop()
  if (!props.active || !props.videoEl) return
  timer = setInterval(tick, 400)
  tick()
}

function stop() {
  if (timer) {
    clearInterval(timer)
    timer = null
  }
}

watch(() => [props.active, props.videoEl], start, { immediate: true })
onBeforeUnmount(stop)
</script>

<style scoped>
.face-guide{position:absolute;inset:0;pointer-events:none;overflow:hidden;font-family:inherit}
.guide-head{position:absolute;left:50%;top:14%;transform:translateX(-50%);width:36%;aspect-ratio:3/4;border:2px dashed rgba(255,255,255,.55);border-radius:50%;box-sizing:border-box;transition:border-color .25s}
.guide-shoulder{position:absolute;left:50%;top:56%;transform:translateX(-50%);width:64%;height:28%;border:2px dashed rgba(255,255,255,.55);border-bottom:none;border-radius:50% 50% 0 0/100% 100% 0 0;box-sizing:border-box;transition:border-color .25s}
.guide-tip{position:absolute;left:50%;bottom:6%;transform:translateX(-50%);max-width:88%;padding:3px 8px;border-radius:999px;font-size:11px;line-height:1.4;white-space:nowrap;color:#fff;background:rgba(15,23,42,.72);transition:background .25s}
.is-ok .guide-head,.is-ok .guide-shoulder{border-color:rgba(34,197,94,.9)}
.is-ok .guide-tip{background:rgba(22,101,52,.82)}
.is-far .guide-head,.is-far .guide-shoulder{border-color:rgba(245,158,11,.95)}
.is-far .guide-tip{background:rgba(146,64,14,.88)}
.is-near .guide-head,.is-near .guide-shoulder{border-color:rgba(239,68,68,.95)}
.is-near .guide-tip{background:rgba(153,27,27,.9)}
.is-none .guide-head,.is-none .guide-shoulder{border-color:rgba(148,163,184,.7)}
.is-none .guide-tip{background:rgba(51,65,85,.8)}
</style>
