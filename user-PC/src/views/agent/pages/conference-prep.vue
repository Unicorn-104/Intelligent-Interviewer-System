<template>
  <div class="cp-page">
    <header class="cp-topbar">
      <div class="cp-bar">
        <a class="cp-brand" href="/agent/index"><span class="cp-mark">智</span>智聘 AI</a>
        <span class="cp-user">候选人 · 王芳</span>
        <button class="cp-quit" @click="quit">退出</button>
      </div>
    </header>

    <main class="cp-main">
      <section class="cp-head">
        <h1>面试准备</h1>
        <p>请确认面试信息并完成设备检测，检测通过后即可进入面试</p>
      </section>

      <div class="cp-grid">
        <section class="cp-card">
          <h2>面试信息</h2>
          <div class="cp-info">
            <div class="cp-row"><span>应聘岗位</span><b>{{ interview.positionTitle }}</b></div>
            <div class="cp-row"><span>面试时间</span><b>{{ interview.time }}</b></div>
            <div class="cp-row"><span>面试官</span><b>{{ interview.interviewer }}</b></div>
            <div class="cp-row"><span>面试时长</span><b>{{ interview.duration }}</b></div>
            <div class="cp-row"><span>面试模式</span><b>{{ interview.mode }}</b></div>
            <div class="cp-row"><span>面试轮次</span><b>{{ interview.round }}</b></div>
          </div>
          <div class="cp-note">请提前 10 分钟进入准备页，避免因设备授权耽误面试。</div>
        </section>

        <section class="cp-card">
          <div class="cp-card-head">
            <h2>设备检测</h2>
            <button class="cp-weak" :class="{ on: simWeak }" title="演示用：切换至弱网状态查看风险提示" @click="toggleWeak">
              弱网模拟
            </button>
          </div>

          <div class="cp-preview" :class="{ off: cam !== 'ok' }">
            <video ref="previewVideo" autoplay playsinline muted />
            <div v-if="cam !== 'ok'" class="cp-preview-fallback">
              <Icon name="camera" :size="22" />
              <span>摄像头未开启</span>
            </div>
            <span class="cp-preview-tag">画面预览</span>
          </div>

          <div class="cp-checks">
            <div class="cp-check" :class="cam">
              <span class="cp-icon"><Icon name="camera" /></span>
              <div>
                <strong>摄像头</strong>
                <small>{{ camDetail }}</small>
              </div>
              <span class="cp-light" :class="cam" />
              <span class="cp-state">{{ stateText(cam) }}</span>
            </div>

            <div class="cp-check" :class="mic">
              <span class="cp-icon"><Icon name="mic" /></span>
              <div>
                <strong>麦克风</strong>
                <small>{{ micDetail }}</small>
              </div>
              <span class="cp-light" :class="mic" />
              <span class="cp-state">{{ stateText(mic) }}</span>
            </div>

            <div class="cp-check" :class="net">
              <span class="cp-icon"><Icon name="wifi" /></span>
              <div>
                <strong>网络连接</strong>
                <small>{{ netDetail }}</small>
              </div>
              <span class="cp-light" :class="net" />
              <span class="cp-state">{{ stateText(net) }}</span>
            </div>

            <div class="cp-check" :class="speaker">
              <span class="cp-icon"><Icon name="speaker" /></span>
              <div>
                <strong>扬声器</strong>
                <small>{{ speakerDetail }}</small>
              </div>
              <span class="cp-light" :class="speaker" />
              <span class="cp-state">{{ stateText(speaker) }}</span>
            </div>
          </div>

          <div class="cp-devices">
            <label class="cp-device">
              <span>摄像头</span>
              <select v-model="camDeviceId" @change="switchDevice">
                <option v-if="!cameraDevices.length" value="">未检测到设备</option>
                <option v-for="item in cameraDevices" :key="item.deviceId" :value="item.deviceId">{{ item.label }}</option>
              </select>
            </label>
            <label class="cp-device">
              <span>麦克风</span>
              <select v-model="micDeviceId" @change="switchDevice">
                <option v-if="!microphoneDevices.length" value="">未检测到设备</option>
                <option v-for="item in microphoneDevices" :key="item.deviceId" :value="item.deviceId">{{ item.label }}</option>
              </select>
            </label>
            <label class="cp-device">
              <span>扬声器</span>
              <select v-model="speakerDeviceId">
                <option v-if="!speakerDevices.length" value="">未检测到设备</option>
                <option v-for="item in speakerDevices" :key="item.deviceId" :value="item.deviceId">{{ item.label }}</option>
              </select>
            </label>
          </div>

          <ul v-if="problems.length" class="cp-fixes">
            <li v-for="(item, index) in problems" :key="index">{{ item }}</li>
          </ul>

          <div class="cp-actions">
            <button class="cp-retry" :disabled="checking" @click="runCheck">
              <Icon name="refresh" :size="15" />{{ checking ? '检测中…' : '重新检测' }}
            </button>
            <button class="cp-guide" @click="guideTip">
              <Icon name="help" :size="15" />调试指引
            </button>
          </div>
        </section>
      </div>

      <section class="cp-card cp-guide-card">
        <h2>面试前引导</h2>
        <div class="cp-guides">
          <div class="cp-guide-item">
            <span class="cp-g-icon"><Icon name="wifi" :size="17" /></span>
            <div>
              <strong>网络建议</strong>
              <p>建议使用有线网络或稳定的 Wi-Fi，关闭下载、直播等占用带宽的程序，保持带宽不低于 500Kbps。</p>
            </div>
          </div>
          <div class="cp-guide-item">
            <span class="cp-g-icon"><Icon name="record" :size="17" /></span>
            <div>
              <strong>录制告知</strong>
              <p>本次面试将全程录音录像，用于招聘评估与合规存档，未经授权不会对外披露。</p>
            </div>
            <button class="cp-agree" :class="{ done: agreed }" @click="openConsent">
              {{ agreed ? '已同意录制' : '查看并同意' }}
            </button>
          </div>
          <div class="cp-guide-item">
            <span class="cp-g-icon"><Icon name="shield" :size="17" /></span>
            <div>
              <strong>禁止协助</strong>
              <p>面试全程需独立作答，禁止他人代为回答、使用实时提示或第二设备检索资料，违规将取消面试资格。</p>
            </div>
          </div>
        </div>
        <button class="cp-more" @click="showNotice = true">查看完整须知 ›</button>
      </section>
    </main>

    <footer class="cp-footer">
      <div class="cp-hint">
        <strong>{{ hint.title }}</strong>
        <span>{{ hint.text }}</span>
      </div>
      <div class="cp-footer-actions">
        <button v-if="netRisk" class="cp-risk" :disabled="!canIgnore" @click="ignoreRisk">忽略风险，继续进入</button>
        <button class="cp-start" :disabled="!canStart" @click="enter">准备就绪，进入面试</button>
      </div>
    </footer>

    <div v-if="showConsent" class="cp-mask">
      <section class="cp-modal">
        <h3>知情同意</h3>
        <p class="cp-modal-lead">本次面试将被录制，用于招聘评估与合规存档。</p>
        <ul class="cp-modal-list">
          <li>录制内容包含您的视频画面、语音及面试过程中的屏幕共享内容。</li>
          <li>录制文件仅对本次招聘相关的面试官、HR 与招聘负责人可见。</li>
          <li>录制文件按企业存储策略保留，到期自动归档删除，不会用于其他用途。</li>
          <li>您可随时联系 HR 查询录制的使用与保留情况。</li>
        </ul>
        <div class="cp-modal-actions">
          <button class="cp-refuse" @click="refuseConsent">拒绝</button>
          <button class="cp-accept" @click="acceptConsent">同意并继续</button>
        </div>
      </section>
    </div>

    <div v-if="showNotice" class="cp-mask">
      <section class="cp-modal">
        <h3>面试完整须知</h3>
        <ul class="cp-modal-list">
          <li>请确保处于安静、光线充足且网络稳定的环境，全程本人独立作答。</li>
          <li>进入面试后请保持摄像头开启，如需离开请提前说明，连续无有效语音超过 2 分钟将判定异常终止。</li>
          <li>请提前准备好简历中的项目细节，面试官可能就项目经历进行追问。</li>
          <li>如遇断网或设备异常，页面会自动重连；超过 30 秒未恢复将自动挂断并通知 HR 人工复核。</li>
          <li>面试结束后可在「面试记录」中查看本次面试的评估状态。</li>
        </ul>
        <div class="cp-modal-actions">
          <button class="cp-accept" @click="showNotice = false">我知道了</button>
        </div>
      </section>
    </div>

    <div class="cp-toast" :class="{ show: toast }">{{ toast }}</div>
  </div>
</template>

<script setup>
import { computed, defineComponent, h, onBeforeUnmount, onMounted, ref } from 'vue'
import { getCurrentSession, reportEnvironmentCheck, startSession, submitConsent } from '@/api/system/conference'
import { describeMediaNotice, queryMediaPermission, requestMedia } from '@/utils/media'

const PATHS = {
  camera: ['M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z', 'M12 13m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0'],
  mic: ['M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z', 'M19 10v2a7 7 0 0 1-14 0v-2', 'M12 19v3', 'M8 22h8'],
  wifi: ['M5 12.55a11 11 0 0 1 14.08 0', 'M1.42 9a16 16 0 0 1 21.16 0', 'M8.53 16.11a6 6 0 0 1 6.95 0', 'M12 20h.01'],
  speaker: ['M11 4.7a.7.7 0 0 0-1.2-.5L6 7.4H3a1 1 0 0 0-1 1v7.2a1 1 0 0 0 1 1h3l3.8 3.2a.7.7 0 0 0 1.2-.5z', 'M16 9a4 4 0 0 1 0 6'],
  refresh: ['M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8', 'M3 3v5h5'],
  help: ['M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z', 'M9.1 9a3 3 0 0 1 5.8 1c0 2-3 2.4-3 2.4V14', 'M12 17.5h.01'],
  record: ['M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Z', 'M12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7Z'],
  shield: ['M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z', 'm9 12 2 2 4-4']
}

const Icon = defineComponent({
  props: { name: { type: String, required: true }, size: { type: Number, default: 18 } },
  setup(props) {
    return () => h('svg', {
      width: props.size, height: props.size, viewBox: '0 0 24 24',
      fill: 'none', stroke: 'currentColor', 'stroke-width': 1.8,
      'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'aria-hidden': 'true'
    }, PATHS[props.name].map((d) => h('path', { d })))
  }
})

const cam = ref('idle')
const mic = ref('idle')
const net = ref('idle')
const speaker = ref('idle')
const camInfo = ref('')
const micInfo = ref('')
const netInfo = ref({ rtt: null, bandwidth: null })
const checking = ref(false)
const agreed = ref(false)
const risk = ref(false)
const simWeak = ref(false)
const showConsent = ref(false)
const showNotice = ref(false)
const toast = ref('')
const sessionId = ref(null)
// 本机设备：预览视频与设备选择
const previewVideo = ref(null)
const cameraDevices = ref([])
const microphoneDevices = ref([])
const speakerDevices = ref([])
const camDeviceId = ref('')
const micDeviceId = ref('')
const speakerDeviceId = ref('')
// 权限被浏览器屏蔽的标记，用于给出「去设置解除」的具体指引
const camDenied = ref(false)
const micDenied = ref(false)
// 记录最近一次可用的设备，切换失败时用于回退
const lastCamDeviceId = ref('')
const lastMicDeviceId = ref('')
// 面试信息：默认文案用于无后端时演示，接口返回后覆盖
const interview = ref({
  positionTitle: '高级前端工程师',
  time: '06月18日 14:30 - 15:15',
  interviewer: '林晓雯（HR）· 张伟（技术）',
  duration: '45 分钟',
  mode: 'AI + HR 协同面试',
  round: '第 1 轮 / 共 2 轮'
})
let toastTimer = null
let stream = null

const netRisk = computed(() => net.value === 'risk')
const allGreen = computed(() => cam.value === 'ok' && mic.value === 'ok' && speaker.value === 'ok' && net.value === 'ok')
const canIgnore = computed(() => agreed.value && cam.value === 'ok' && mic.value === 'ok' && speaker.value === 'ok')
const canStart = computed(() => allGreen.value && agreed.value)

const camDetail = computed(() => (cam.value === 'ok' ? `已授权 · ${camInfo.value || '画面清晰'}` : cam.value === 'idle' ? '尚未检测，点击「重新检测」授权' : '未获得摄像头权限，无法进入面试'))
const micDetail = computed(() => (mic.value === 'ok' ? `已授权 · ${micInfo.value || '输入正常'}` : mic.value === 'idle' ? '尚未检测，点击「重新检测」授权' : '未检测到麦克风输入，请检查设备'))
const netDetail = computed(() => {
  if (net.value === 'idle') return '尚未检测网络质量'
  if (netInfo.value.rtt === null) return '网络检测失败，请检查连接'
  return `延迟 ${netInfo.value.rtt}ms · 可用带宽 ${netInfo.value.bandwidth}Kbps`
})
const speakerDetail = computed(() => (speaker.value === 'ok' ? '输出正常，可听到面试官语音' : speaker.value === 'idle' ? '尚未检测扬声器输出' : '未检测到音频输出设备'))

const problems = computed(() => {
  const list = []
  if (cam.value === 'bad') list.push(camDenied.value
    ? '摄像头：已被浏览器屏蔽（不会再弹授权框）。请点击地址栏左侧图标 → 网站设置 → 摄像头 → 改为「允许」，再重新检测。'
    : '摄像头：请在浏览器地址栏允许摄像头权限，或更换设备后重新检测。')
  if (mic.value === 'bad') list.push(micDenied.value
    ? '麦克风：已被浏览器屏蔽（不会再弹授权框）。请点击地址栏左侧图标 → 网站设置 → 麦克风 → 改为「允许」，再重新检测。'
    : '麦克风：请允许麦克风权限，并确认设备未被其他程序占用。')
  if (speaker.value === 'bad') list.push('扬声器：请连接耳机或音箱后重新检测。')
  if (netRisk.value) list.push(`网络：当前延迟 ${netInfo.value.rtt}ms、带宽 ${netInfo.value.bandwidth}Kbps，低于面试要求（RTT ≤ 500ms 且带宽 ≥ 500Kbps）。`)
  return list
})

const hint = computed(() => {
  if (netRisk.value) return { title: '网络质量较差', text: '低于面试推荐标准，可点击「忽略风险，继续进入」并在面试中可能自动降低画质。' }
  if (!allGreen.value) return { title: '设备尚未全部就绪', text: '请按修复建议处理后重新检测，全部通过才可进入面试。' }
  if (!agreed.value) return { title: '待同意录制告知', text: '请在「面试前引导」中查看并同意录制告知后继续。' }
  return { title: '设备检测通过', text: '一切就绪，点击右侧按钮进入面试。' }
})

function stateText(status) {
  return { idle: '待检测', ok: '正常', warn: '较差', bad: '异常', risk: '较差' }[status] || '待检测'
}

function notify(message) {
  toast.value = message
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => (toast.value = ''), 2400)
}

// 打开本机摄像头与麦克风（分开申请，任一失败不影响另一项），并把画面接入预览
async function openLocalMedia() {
  const [camResult, micResult] = await Promise.all([
    requestMedia({ video: camDeviceId.value ? { deviceId: { exact: camDeviceId.value } } : true })
      .then((stream) => ({ stream })).catch((error) => ({ error })),
    requestMedia({ audio: micDeviceId.value ? { deviceId: { exact: micDeviceId.value } } : true })
      .then((stream) => ({ stream })).catch((error) => ({ error }))
  ])

  const video = camResult.stream?.getVideoTracks()[0] || null
  const audio = micResult.stream?.getAudioTracks()[0] || null
  const tracks = [...(camResult.stream?.getVideoTracks() || []), ...(micResult.stream?.getAudioTracks() || [])]

  stream = tracks.length ? new MediaStream(tracks) : null
  cam.value = video ? 'ok' : 'bad'
  mic.value = audio ? 'ok' : 'bad'

  const settings = video?.getSettings?.() || {}
  const audioSettings = audio?.getSettings?.() || {}
  camInfo.value = settings.width ? `${settings.width}×${settings.height}` : ''
  micInfo.value = audio?.label ? audio.label.slice(0, 18) : ''
  // 回显当前实际使用的设备，供下拉框选中；同时记录可用设备用于失败回退
  if (video && settings.deviceId) {
    camDeviceId.value = settings.deviceId
    lastCamDeviceId.value = settings.deviceId
  }
  if (audio && audioSettings.deviceId) {
    micDeviceId.value = audioSettings.deviceId
    lastMicDeviceId.value = audioSettings.deviceId
  }
  if (previewVideo.value) previewVideo.value.srcObject = stream

  return { camError: camResult.error || null, micError: micResult.error || null }
}

// 列举本机真实设备：摄像头 / 麦克风 / 扬声器
async function listDevices() {
  const devices = await navigator.mediaDevices.enumerateDevices()
  const pick = (kind, name) =>
    devices.filter((item) => item.kind === kind).map((item, index) => ({
      deviceId: item.deviceId,
      label: item.label || `${name} ${index + 1}`
    }))
  cameraDevices.value = pick('videoinput', '摄像头')
  microphoneDevices.value = pick('audioinput', '麦克风')
  speakerDevices.value = pick('audiooutput', '扬声器')
}

async function detectDevices() {
  if (!navigator.mediaDevices?.getUserMedia) {
    cam.value = 'bad'
    mic.value = 'bad'
    speaker.value = 'bad'
    camDenied.value = false
    micDenied.value = false
    notify('当前浏览器不支持设备检测，请在 127.0.0.1 或 localhost 下使用最新版 Chrome / Edge')
    return { camError: null, micError: null }
  }
  // denied 表示此前已被浏览器屏蔽：此时不会再弹授权框、请求必然失败，需引导用户去设置里解除
  const [camPerm, micPerm] = await Promise.all([
    queryMediaPermission('camera'),
    queryMediaPermission('microphone')
  ])
  camDenied.value = camPerm === 'denied'
  micDenied.value = micPerm === 'denied'
  return openLocalMedia()
}

// 扬声器：基于 enumerateDevices 的实际音频输出设备判定
async function detectSpeaker() {
  try {
    await listDevices()
    speaker.value = speakerDevices.value.length ? 'ok' : 'bad'
  } catch (error) {
    speaker.value = 'bad'
  }
}

// 切换设备后按新选择的 deviceId 重建本地流；失败则回退到上一个可用设备
async function switchDevice() {
  if (!navigator.mediaDevices?.getUserMedia) return
  const prevCam = lastCamDeviceId.value
  const prevMic = lastMicDeviceId.value
  stream?.getTracks().forEach((track) => track.stop())
  stream = null
  if (previewVideo.value) previewVideo.value.srcObject = null
  cam.value = 'idle'
  mic.value = 'idle'
  const { camError, micError } = await openLocalMedia()
  await listDevices()
  if (camError || micError) {
    // 切到了不可用设备：回退到上一次可用设备，避免停留在无画面的状态
    camDeviceId.value = prevCam
    micDeviceId.value = prevMic
    await openLocalMedia()
    notify('该设备不可用，已回退到上一个可用设备')
  } else {
    notify('已切换设备')
  }
  reportEnv()
}

async function detectNetwork() {
  if (simWeak.value) {
    netInfo.value = { rtt: 618, bandwidth: 420 }
    net.value = 'risk'
    return
  }
  const started = performance.now()
  let rtt = null
  try {
    await fetch(`${window.location.origin}/favicon.ico?t=${Date.now()}`, { method: 'HEAD', cache: 'no-store' })
    rtt = Math.max(1, Math.round(performance.now() - started))
  } catch (error) {
    rtt = null
  }
  const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection
  const bandwidth = connection?.downlink ? Math.round(connection.downlink * 1000) : 18600
  if (rtt === null) {
    netInfo.value = { rtt: null, bandwidth: null }
    net.value = 'bad'
    return
  }
  netInfo.value = { rtt, bandwidth }
  net.value = rtt > 500 || bandwidth < 500 ? 'risk' : 'ok'
}

// 环境检测状态映射：idle→0(未检测) ok→1(正常) risk→2(警告) bad→3(异常)
const ENV_STATUS = { idle: 0, ok: 1, risk: 2, bad: 3 }

async function reportEnv() {
  if (!sessionId.value) return
  try {
    await reportEnvironmentCheck(sessionId.value, {
      camStatus: ENV_STATUS[cam.value],
      micStatus: ENV_STATUS[mic.value],
      speakerStatus: ENV_STATUS[speaker.value],
      netStatus: ENV_STATUS[net.value],
      rttMs: netInfo.value.rtt,
      bandwidthKbps: netInfo.value.bandwidth,
      riskFlag: risk.value ? 1 : 0
    })
  } catch (error) {
    // 上报失败静默保留本地检测态
  }
}

async function runCheck() {
  if (checking.value) return
  checking.value = true
  cam.value = 'idle'
  mic.value = 'idle'
  net.value = 'idle'
  speaker.value = 'idle'
  stream?.getTracks().forEach((track) => track.stop())
  stream = null
  if (previewVideo.value) previewVideo.value.srcObject = null
  const { camError, micError } = await detectDevices()
  await Promise.all([detectSpeaker(), detectNetwork()])
  checking.value = false
  const error = camError || micError
  notify(error ? await describeMediaNotice(error, camError ? 'camera' : 'microphone') : '检测完成')
  reportEnv()
}

function toggleWeak() {
  simWeak.value = !simWeak.value
  detectNetwork().then(() => reportEnv())
  notify(simWeak.value ? '已切换至弱网状态，用于查看风险提示' : '已恢复网络检测')
}

function openConsent() {
  if (agreed.value) {
    notify('您已同意录制告知')
    return
  }
  showConsent.value = true
}

function acceptConsent() {
  agreed.value = true
  showConsent.value = false
  notify('已同意录制，可继续进入面试')
  if (sessionId.value) submitConsent(sessionId.value, 1).catch(() => {})
}

function refuseConsent() {
  showConsent.value = false
  notify('已拒绝录制，无法进入面试；如有疑问请联系 HR')
  if (sessionId.value) submitConsent(sessionId.value, 2).catch(() => {})
}

function ignoreRisk() {
  risk.value = true
  localStorage.setItem('interviewRiskFlag', JSON.stringify({ rtt: netInfo.value.rtt, bandwidth: netInfo.value.bandwidth, at: Date.now() }))
  notify('已记录网络风险标记，HR 将收到提示')
  setTimeout(enter, 600)
}

async function enter() {
  if (!canStart.value) return
  localStorage.setItem('interviewReady', '1')
  stream?.getTracks().forEach((track) => track.stop())
  if (sessionId.value && agreed.value) {
    try {
      await startSession(sessionId.value)
    } catch (error) {
      // 开考接口失败不阻塞进入面试
    }
  }
  window.__agentNavigate('/agent/conference-ai?job=ai-product')
}

function guideTip() {
  notify('调试指引：检查浏览器权限 → 确认设备未被占用 → 更换浏览器或设备后重试')
}

function quit() {
  stream?.getTracks().forEach((track) => track.stop())
  window.__agentNavigate('/agent/interview-schedule')
}

// 后端时间格式 '2026-06-18 14:30' → '06月18日 14:30 - 15:15'
function formatAppointment(startAt, endAt) {
  if (!startAt) return ''
  const [date, startTime] = startAt.split(' ')
  const parts = (date || '').split('-')
  if (parts.length < 3) return startAt
  const endTime = endAt ? endAt.split(' ')[1] : ''
  return `${parts[1]}月${parts[2]}日 ${startTime}${endTime ? ` - ${endTime}` : ''}`
}

function fillInterview(data) {
  if (data.positionTitle) interview.value.positionTitle = data.positionTitle
  const time = formatAppointment(data.appointmentStartAt, data.appointmentEndAt)
  if (time) interview.value.time = time
  if (data.interviewerName) interview.value.interviewer = data.interviewerName
  if (data.durationMinutes) interview.value.duration = `${data.durationMinutes} 分钟`
  if (data.mode != null) interview.value.mode = Number(data.mode) === 2 ? 'AI + HR 协同面试' : '纯 AI 面试'
  if (data.roundNo || data.totalRounds) {
    interview.value.round = `第 ${data.roundNo || 1} 轮 / 共 ${data.totalRounds || 1} 轮`
  }
}

onMounted(async () => {
  // 设备检测不依赖后端：先立即开始，避免接口异常或 401 弹窗导致检测一直停在「待检测」
  const detected = runCheck()
  try {
    const res = await getCurrentSession()
    if (res.data && res.data.sessionId) {
      sessionId.value = res.data.sessionId
      fillInterview(res.data)
      // 拿到场次后再补报一次环境检测结果（runCheck 开始时还没有 sessionId）
      await detected
      reportEnv()
    }
  } catch (error) {
    // 无后端时保留本地演示
  }
})

onBeforeUnmount(() => {
  clearTimeout(toastTimer)
  stream?.getTracks().forEach((track) => track.stop())
  stream = null
})
</script>

<style scoped>
.cp-page {
  --p: #1A3C6E;
  --b: #2B7FFF;
  --bg: #F5F7FA;
  --card: #fff;
  --text: #172B4D;
  --muted: #6B7A90;
  --line: #E6EBF2;
  --soft: #EAF2FF;
  --green: #52C41A;
  --green-bg: #EDFAE5;
  --warn: #FAAD14;
  --warn-bg: #FFF7E6;
  --red: #FF4D4F;
  --red-bg: #FFF1F0;
  min-height: 100vh;
  padding-bottom: 92px;
  background: var(--bg);
  color: var(--text);
  font: 14px/1.6 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
.cp-page * { box-sizing: border-box; }
.cp-page button { font: inherit; cursor: pointer; }
.cp-page h1, .cp-page h2, .cp-page h3, .cp-page p { margin: 0; }

.cp-topbar { height: 72px; display: flex; align-items: center; background: #fff; border-bottom: 1px solid var(--line); }
.cp-bar, .cp-main, .cp-footer { width: min(1120px, calc(100% - 48px)); margin: auto; }
.cp-bar { display: flex; align-items: center; }
.cp-brand { display: flex; align-items: center; gap: 10px; color: var(--p); font-size: 18px; font-weight: 800; text-decoration: none; }
.cp-mark { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 9px; color: #fff; background: linear-gradient(145deg, #2B7FFF, #1A3C6E); }
.cp-user { margin-left: auto; color: var(--muted); font-size: 12px; }
.cp-quit { margin-left: 16px; height: 32px; padding: 0 14px; border: 1px solid var(--line); border-radius: 8px; background: #fff; color: var(--muted); }
.cp-quit:hover { color: var(--red); border-color: #ffccc7; }

.cp-main { padding: 26px 0 40px; }
.cp-head h1 { font-size: 24px; color: var(--p); }
.cp-head p { margin-top: 6px; color: var(--muted); font-size: 13px; }

.cp-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.08fr); gap: 16px; margin-top: 16px; }
.cp-card { padding: 22px; border: 1px solid var(--line); border-radius: 12px; background: #fff; box-shadow: 0 6px 20px rgba(26, 60, 110, .05); }
.cp-card h2 { font-size: 16px; color: var(--p); }
.cp-card-head { display: flex; align-items: center; justify-content: space-between; }
.cp-weak { height: 26px; padding: 0 10px; border: 1px dashed var(--line); border-radius: 7px; background: #fff; color: var(--muted); font-size: 11px; }
.cp-weak.on { color: var(--b); border-color: var(--b); background: var(--soft); }

.cp-info { margin-top: 14px; }
.cp-row { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 12px 0; border-bottom: 1px dashed var(--line); }
.cp-row:last-child { border-bottom: 0; }
.cp-row span { color: var(--muted); font-size: 13px; }
.cp-row b { font-weight: 600; font-size: 13px; text-align: right; }
.cp-note { margin-top: 14px; padding: 11px 13px; border-radius: 9px; background: #F6F9FD; color: #52647D; font-size: 12px; }

.cp-preview { position: relative; margin-top: 14px; aspect-ratio: 16 / 9; border-radius: 10px; overflow: hidden; background: #0B0F16; }
.cp-preview video { width: 100%; height: 100%; object-fit: cover; display: block; transform: scaleX(-1); }
.cp-preview.off video { display: none; }
.cp-preview-fallback { position: absolute; inset: 0; display: grid; place-content: center; justify-items: center; gap: 6px; background: #EEF2F8; color: var(--muted); font-size: 12px; }
.cp-preview-tag { position: absolute; left: 10px; top: 9px; padding: 3px 9px; border-radius: 999px; background: rgba(8, 12, 20, .55); color: #fff; font-size: 11px; }

.cp-devices { display: grid; gap: 8px; margin-top: 12px; }
.cp-device { display: grid; grid-template-columns: 58px 1fr; align-items: center; gap: 10px; }
.cp-device > span { color: var(--muted); font-size: 12px; }
.cp-device select { width: 100%; height: 34px; padding: 0 10px; border: 1px solid var(--line); border-radius: 8px; background: #fff; color: var(--text); font: inherit; font-size: 12px; }
.cp-device select:focus { outline: none; border-color: var(--b); }

.cp-checks { display: grid; gap: 10px; margin-top: 14px; }
.cp-check {
  display: grid; grid-template-columns: 38px 1fr 10px 52px;
  align-items: center; gap: 11px;
  padding: 12px 13px;
  border: 1px solid var(--line); border-radius: 10px;
  transition: .18s;
}
.cp-check.ok { border-color: #d3f0c5; background: #fcfffa; }
.cp-check.bad { border-color: #ffd3d2; background: #fffafa; }
.cp-icon { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 9px; color: var(--b); background: var(--soft); }
.cp-check.ok .cp-icon { color: #3f9e1f; background: var(--green-bg); }
.cp-check.bad .cp-icon { color: var(--red); background: var(--red-bg); }
.cp-check.risk .cp-icon { color: #c98a00; background: var(--warn-bg); }
.cp-check strong { display: block; font-size: 13px; }
.cp-check small { display: block; margin-top: 2px; color: var(--muted); font-size: 11px; }
.cp-light { width: 10px; height: 10px; border-radius: 50%; background: var(--warn); box-shadow: 0 0 0 4px rgba(250, 173, 20, .16); }
.cp-light.ok { background: var(--green); box-shadow: 0 0 0 4px rgba(82, 196, 26, .16); }
.cp-light.bad { background: var(--red); box-shadow: 0 0 0 4px rgba(255, 77, 79, .16); }
.cp-state { text-align: right; font-size: 11px; font-weight: 700; color: #c98a00; }
.cp-check.ok .cp-state { color: #3f9e1f; }
.cp-check.bad .cp-state { color: var(--red); }

.cp-fixes { list-style: none; margin: 12px 0 0; padding: 11px 13px; border-radius: 9px; background: var(--warn-bg); }
.cp-fixes li { position: relative; padding-left: 14px; color: #96650a; font-size: 12px; line-height: 1.7; }
.cp-fixes li:before { content: ''; position: absolute; left: 0; top: 8px; width: 5px; height: 5px; border-radius: 50%; background: var(--warn); }

.cp-actions { display: flex; gap: 10px; margin-top: 16px; }
.cp-retry, .cp-guide { height: 38px; padding: 0 15px; display: inline-flex; align-items: center; gap: 7px; border-radius: 9px; font-weight: 600; }
.cp-retry { border: 0; color: #fff; background: var(--b); }
.cp-retry:disabled { opacity: .6; cursor: progress; }
.cp-guide { border: 1px solid var(--line); background: #fff; color: var(--p); }
.cp-guide:hover { border-color: var(--b); color: var(--b); }

.cp-guide-card { margin-top: 16px; }
.cp-guides { display: grid; gap: 12px; margin-top: 14px; }
.cp-guide-item { display: grid; grid-template-columns: 38px 1fr auto; align-items: center; gap: 12px; padding: 14px; border: 1px solid var(--line); border-radius: 10px; }
.cp-g-icon { width: 36px; height: 36px; display: grid; place-items: center; border-radius: 50%; color: var(--b); background: var(--soft); }
.cp-guide-item strong { display: block; font-size: 13px; }
.cp-guide-item p { margin-top: 3px; color: var(--muted); font-size: 12px; line-height: 1.65; }
.cp-agree { height: 32px; padding: 0 13px; border: 1px solid var(--b); border-radius: 8px; background: #fff; color: var(--b); font-size: 12px; font-weight: 600; white-space: nowrap; }
.cp-agree.done { color: #3f9e1f; border-color: #b7e3a4; background: var(--green-bg); }
.cp-more { margin-top: 14px; border: 0; background: transparent; color: var(--b); font-size: 12px; padding: 0; }
.cp-more:hover { text-decoration: underline; }

.cp-footer {
  position: fixed; left: 0; right: 0; bottom: 0;
  height: 76px; padding: 0;
  display: flex; align-items: center; justify-content: space-between; gap: 16px;
  background: #fff; border-top: 1px solid var(--line);
  padding-left: max(24px, calc((100% - 1120px) / 2));
  padding-right: max(24px, calc((100% - 1120px) / 2));
  box-shadow: 0 -6px 22px rgba(26, 60, 110, .06);
}
.cp-hint strong { display: block; font-size: 13px; color: var(--p); }
.cp-hint span { color: var(--muted); font-size: 12px; }
.cp-footer-actions { display: flex; gap: 10px; }
.cp-risk { height: 44px; padding: 0 18px; border: 1px solid var(--warn); border-radius: 10px; background: var(--warn-bg); color: #96650a; font-weight: 600; }
.cp-risk:disabled { opacity: .5; cursor: not-allowed; }
.cp-start { height: 44px; padding: 0 26px; border: 0; border-radius: 10px; color: #fff; font-size: 15px; font-weight: 700; background: linear-gradient(135deg, #2B7FFF, #1A3C6E); box-shadow: 0 8px 20px rgba(43, 127, 255, .28); }
.cp-start:disabled { background: #C9D3DF; box-shadow: none; cursor: not-allowed; }

.cp-mask { position: fixed; inset: 0; z-index: 60; display: grid; place-items: center; padding: 20px; background: rgba(15, 30, 55, .5); }
.cp-modal { width: min(520px, 100%); padding: 24px; border-radius: 12px; background: #fff; box-shadow: 0 24px 60px rgba(15, 30, 55, .25); animation: cp-pop .2s ease; }
@keyframes cp-pop { from { opacity: 0; transform: translateY(8px) scale(.98); } to { opacity: 1; transform: none; } }
.cp-modal h3 { font-size: 17px; color: var(--p); }
.cp-modal-lead { margin-top: 10px; font-size: 14px; font-weight: 600; }
.cp-modal-list { margin: 14px 0 0; padding-left: 18px; }
.cp-modal-list li { color: var(--muted); font-size: 13px; line-height: 1.8; }
.cp-modal-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 22px; }
.cp-refuse { height: 40px; padding: 0 20px; border: 1px solid var(--line); border-radius: 9px; background: #fff; color: var(--muted); }
.cp-refuse:hover { color: var(--red); border-color: #ffccc7; }
.cp-accept { height: 40px; padding: 0 22px; border: 0; border-radius: 9px; color: #fff; font-weight: 700; background: var(--b); }

.cp-toast { position: fixed; left: 50%; bottom: 96px; transform: translate(-50%, 8px); z-index: 80; padding: 11px 16px; border-radius: 9px; background: #122A4E; color: #fff; font-size: 13px; opacity: 0; pointer-events: none; transition: .2s; }
.cp-toast.show { opacity: 1; transform: translate(-50%, 0); }

@media (max-width: 960px) {
  .cp-grid { grid-template-columns: 1fr; }
  .cp-footer { height: auto; flex-direction: column; align-items: stretch; padding: 14px 20px; gap: 12px; }
  .cp-footer-actions { flex-direction: column; }
  .cp-risk, .cp-start { width: 100%; }
  .cp-page { padding-bottom: 180px; }
}
@media (max-width: 620px) {
  .cp-bar, .cp-main { width: calc(100% - 28px); }
  .cp-check { grid-template-columns: 34px 1fr 10px; }
  .cp-state { display: none; }
}
</style>