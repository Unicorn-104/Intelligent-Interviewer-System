import { ref } from 'vue'
import { getAsrStatus, issueAsrTicket } from '@/api/system/conference'
import { getPreferredDevice } from '@/utils/media'

// 腾讯云实时语音识别要求：16k 采样、16bit、单声道 PCM，每 200ms 一帧（3200 样本 / 6400 字节）
const SAMPLE_RATE = 16000
const FRAME_SAMPLES = 3200

/**
 * 实时字幕：后端 WS 代理模式。
 *
 * 前端只连本项目的 /ws/conference-asr（一次性票据鉴权），音频帧由后端转发给识别服务，
 * 稳定句由后端落库并回推；另一端通过字幕增量接口获取。
 * 仅 AI 面试（模式 1-3）后端才会返回 enabled，模式 4 纯人工面试直接降级为不可用。
 */
export function useRealtimeAsr({ getSessionId, getMicEnabled, getMicTrack, onFinal }) {
  const status = ref({ enabled: false, reason: '', mode: null })
  const running = ref(false)
  const supported = typeof window !== 'undefined'
    && typeof window.WebSocket !== 'undefined'
    && !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia)

  let socket = null
  let audioContext = null
  let processor = null
  let source = null
  let stream = null
  let pending = []
  let pendingSamples = 0
  let starting = false
  // 每次停止都会递增，用于丢弃停止前发起、停止后才返回的票据请求
  let generation = 0

  async function refresh() {
    const sessionId = getSessionId()
    if (!sessionId) {
      status.value = { enabled: false, reason: '', mode: null }
      stop()
      return
    }
    try {
      const res = await getAsrStatus(sessionId)
      const data = res && res.data ? res.data : {}
      status.value = {
        enabled: !!data.enabled && supported,
        reason: data.enabled && !supported ? '当前浏览器不支持实时字幕' : (data.reason || ''),
        mode: data.mode != null ? Number(data.mode) : null
      }
    } catch (e) {
      status.value = { enabled: false, reason: '字幕状态获取失败', mode: null }
    }
    if (!status.value.enabled) stop()
  }

  // 开启识别流：取一次性票据 -> 建 WS -> 采集麦克风并推送 PCM 帧
  async function start() {
    const sessionId = getSessionId()
    if (!sessionId || !status.value.enabled || running.value || starting) return
    if (!getMicEnabled || !getMicEnabled()) return
    starting = true
    const gen = ++generation
    try {
      const res = await issueAsrTicket(sessionId)
      const ticket = res && res.data ? res.data.ticket : null
      if (gen !== generation) return
      if (!ticket) {
        status.value = { ...status.value, enabled: false, reason: '字幕票据获取失败' }
        return
      }
      const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
      const ws = new WebSocket(`${proto}//${window.location.host}/ws/conference-asr?ticket=${encodeURIComponent(ticket)}`)
      ws.binaryType = 'arraybuffer'
      socket = ws
      ws.onopen = async () => {
        try {
          await startCapture()
          running.value = true
        } catch (e) {
          status.value = { ...status.value, enabled: false, reason: '麦克风不可用，无法生成实时字幕' }
          stop()
        }
      }
      ws.onmessage = (event) => {
        let payload = null
        try {
          payload = JSON.parse(event.data)
        } catch (e) {
          return
        }
        if (!payload) return
        if (payload.type === 'final' && payload.content && typeof onFinal === 'function') {
          onFinal({ text: payload.content, sequence: payload.sequence, role: payload.role })
        } else if (payload.type === 'error') {
          status.value = { ...status.value, enabled: false, reason: payload.message || '实时字幕服务异常' }
          stop()
        }
      }
      ws.onclose = (event) => {
        if (socket === ws) socket = null
        stopCapture()
        running.value = false
        // 非主动关闭时给出可读原因，避免字幕面板只显示「暂无字幕」
        if (gen === generation && event && event.code !== 1000) {
          status.value = { ...status.value, enabled: false, reason: '实时字幕连接已断开' }
        }
      }
    } catch (e) {
      status.value = { ...status.value, enabled: false, reason: (e && e.message) || '实时字幕开启失败' }
      stop()
    } finally {
      starting = false
    }
  }

  async function startCapture() {
    // 优先克隆 LiveKit 已发布的麦克风轨：避免二次 getUserMedia 抢占同一设备导致静音
    const published = typeof getMicTrack === 'function' ? getMicTrack() : null
    if (published && published.readyState === 'live') {
      stream = new MediaStream([published.clone()])
    } else {
      const deviceId = getPreferredDevice('audio')
      stream = await navigator.mediaDevices.getUserMedia({
        audio: deviceId ? { deviceId: { exact: deviceId } } : true
      })
    }
    audioContext = new AudioContext({ sampleRate: SAMPLE_RATE })
    source = audioContext.createMediaStreamSource(stream)
    processor = audioContext.createScriptProcessor(4096, 1, 1)
    // 采集节点必须接入输出才会持续触发，GainNode 静音避免本机回声
    const mute = audioContext.createGain()
    mute.gain.value = 0
    processor.onaudioprocess = handleAudio
    source.connect(processor)
    processor.connect(mute)
    mute.connect(audioContext.destination)
    if (audioContext.state === 'suspended') await audioContext.resume()
  }

  function handleAudio(event) {
    if (!socket || socket.readyState !== WebSocket.OPEN) return
    const input = event.inputBuffer.getChannelData(0)
    const samples = audioContext.sampleRate === SAMPLE_RATE ? input : resample(input, audioContext.sampleRate)
    pending.push(samples)
    pendingSamples += samples.length
    while (pendingSamples >= FRAME_SAMPLES) {
      const frame = takeSamples(FRAME_SAMPLES)
      socket.send(toPcm16(frame).buffer)
    }
  }

  function takeSamples(count) {
    const frame = new Float32Array(count)
    let offset = 0
    while (offset < count && pending.length) {
      const chunk = pending[0]
      const need = count - offset
      if (chunk.length <= need) {
        frame.set(chunk, offset)
        offset += chunk.length
        pending.shift()
      } else {
        frame.set(chunk.subarray(0, need), offset)
        pending[0] = chunk.subarray(need)
        offset += need
      }
    }
    pendingSamples -= count
    return frame
  }

  // 线性重采样到 16k
  function resample(input, fromRate) {
    const ratio = fromRate / SAMPLE_RATE
    const length = Math.floor(input.length / ratio)
    const output = new Float32Array(length)
    for (let i = 0; i < length; i++) {
      const pos = i * ratio
      const left = Math.floor(pos)
      const right = Math.min(left + 1, input.length - 1)
      const weight = pos - left
      output[i] = input[left] * (1 - weight) + input[right] * weight
    }
    return output
  }

  function toPcm16(input) {
    const output = new Int16Array(input.length)
    for (let i = 0; i < input.length; i++) {
      const s = Math.max(-1, Math.min(1, input[i]))
      output[i] = s < 0 ? s * 0x8000 : s * 0x7fff
    }
    return output
  }

  function stopCapture() {
    if (processor) {
      processor.onaudioprocess = null
      processor.disconnect()
      processor = null
    }
    if (source) {
      source.disconnect()
      source = null
    }
    if (stream) {
      stream.getTracks().forEach((track) => track.stop())
      stream = null
    }
    if (audioContext) {
      audioContext.close().catch(() => {})
      audioContext = null
    }
    pending = []
    pendingSamples = 0
  }

  function stop() {
    generation += 1
    stopCapture()
    running.value = false
    const ws = socket
    socket = null
    if (ws) {
      try {
        if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ type: 'end' }))
        ws.onopen = null
        ws.onmessage = null
        ws.onclose = null
        ws.close()
      } catch (e) {
        // 忽略关闭异常
      }
    }
  }

  async function restart() {
    stop()
    await start()
  }

  return { status, running, supported, refresh, start, stop, restart }
}
