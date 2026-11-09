<template>
  <div v-if="active" class="face-guide" :class="`is-${state}`" aria-live="polite">
    <svg class="guide-svg" viewBox="0 0 100 100" preserveAspectRatio="none">
      <defs>
        <mask :id="maskId">
          <rect width="100" height="100" fill="#fff" />
          <path :d="outline" fill="#000" />
        </mask>
      </defs>
      <!-- 框外压暗、框内保持原画面，轮廓为固定的头肩剪影，便于判断人是否站在位置里 -->
      <rect width="100" height="100" class="guide-dim" :mask="`url(#${maskId})`" />
      <path :d="outline" class="guide-line" vector-effect="non-scaling-stroke" />
    </svg>
    <div class="guide-tip">{{ tipText }}</div>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { FaceDetector, FilesetResolver } from '@mediapipe/tasks-vision'

const maskId = `face-guide-${Math.random().toString(36).slice(2, 8)}`
// 固定头肩剪影（按实际取景对齐）：头部椭圆约 19%~60%，最宽处 30%~69%，颈部在 66% 收窄，肩线 75% 起外扩到画面两下角
const outline =
  'M1 100 C4 87 13 79 25 75 C31 72 34 70 35 66 C36 62 37 59 38 56 ' +
  'A19.5 20.5 0 1 1 61 56 C62 59 63 62 64 66 C65 70 68 72 74 75 ' +
  'C86 79 95 87 98 100 Z'

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
.guide-svg{position:absolute;inset:0;width:100%;height:100%;display:block}
.guide-dim{fill:rgba(8,13,24,.66)}
.guide-line{fill:none;stroke:rgba(203,213,225,.9);stroke-width:1.5;stroke-dasharray:4 3;transition:stroke .25s}
.guide-tip{position:absolute;left:50%;bottom:6%;transform:translateX(-50%);max-width:88%;padding:3px 8px;border-radius:999px;font-size:11px;line-height:1.4;white-space:nowrap;color:#fff;background:rgba(15,23,42,.72);transition:background .25s}
.is-ok .guide-line{stroke:rgba(34,197,94,.95)}
.is-ok .guide-tip{background:rgba(22,101,52,.82)}
.is-far .guide-line{stroke:rgba(245,158,11,.95)}
.is-far .guide-tip{background:rgba(146,64,14,.88)}
.is-near .guide-line{stroke:rgba(239,68,68,.95)}
.is-near .guide-tip{background:rgba(153,27,27,.9)}
.is-none .guide-line{stroke:rgba(148,163,184,.8)}
.is-none .guide-tip{background:rgba(51,65,85,.8)}
</style>
