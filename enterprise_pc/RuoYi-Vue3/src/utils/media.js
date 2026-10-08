// 本机音视频设备访问的公共封装：统一处理超时、授权状态与错误文案。
// 与候选人端 user-PC/src/utils/media.js 保持同一份实现（两个独立工程各自持有）。

// getUserMedia 在授权框不响应、或设备被其它程序独占时可能长时间挂起，
// 统一加超时兜底，避免页面一直卡在等待状态。
const MEDIA_TIMEOUT_MS = 8000

// 申请媒体流；超时后若流最终仍返回，立即释放，避免摄像头被长期占用
export function requestMedia(constraints, timeout = MEDIA_TIMEOUT_MS) {
  const pending = navigator.mediaDevices.getUserMedia(constraints)
  let timer = null
  const expired = new Promise((resolve, reject) => {
    timer = setTimeout(() => {
      pending.then((stream) => stream.getTracks().forEach((track) => track.stop())).catch(() => {})
      const error = new Error('设备响应超时')
      error.name = 'TimeoutError'
      reject(error)
    }, timeout)
  })
  return Promise.race([pending, expired]).finally(() => clearTimeout(timer))
}

// 查询浏览器对该源的授权状态：granted / denied / prompt / unknown（浏览器不支持时）
export async function queryMediaPermission(kind) {
  try {
    const status = await navigator.permissions?.query?.({ name: kind })
    return status?.state || 'unknown'
  } catch (error) {
    return 'unknown'
  }
}

// 把设备异常翻译成可操作的中文提示
export function describeMediaError(error, kind = 'device') {
  const label = { camera: '摄像头', microphone: '麦克风' }[kind] || '设备'
  switch (error?.name) {
    case 'NotAllowedError':
    case 'SecurityError':
      return `未获得${label}权限，请在浏览器地址栏允许访问`
    case 'NotFoundError':
      return `未检测到${label}，请检查设备连接`
    case 'NotReadableError':
      return `${label}被其它程序占用，请关闭占用后重新检测`
    case 'OverconstrainedError':
      return `所选${label}不可用，请重新选择设备`
    case 'TimeoutError':
      return `${label}响应超时，请检查设备是否被占用或断开`
    default:
      return `${label}暂时不可用，请稍后重试`
  }
}

// 在错误文案基础上，若该源已被浏览器屏蔽则补充「去设置解除」的操作指引
export async function describeMediaNotice(error, kind) {
  const message = describeMediaError(error, kind)
  if (error?.name !== 'NotAllowedError') return message
  const state = await queryMediaPermission(kind)
  return state === 'denied' ? `${message}；浏览器已屏蔽该权限，请到网站设置中改为「允许」` : message
}

// 用户选定的音视频设备 ID 持久化：会议内切换设备后再次进入仍沿用；
// deviceId 按「来源+页面」隔离，跨页不保证有效，采集失败时调用方需回退默认设备。
const DEVICE_PREF_KEY = 'conferenceDevicePrefs'

export function savePreferredDevice(kind, deviceId) {
  if (!deviceId) return
  try {
    const prefs = JSON.parse(localStorage.getItem(DEVICE_PREF_KEY) || '{}')
    prefs[kind] = deviceId
    localStorage.setItem(DEVICE_PREF_KEY, JSON.stringify(prefs))
  } catch (error) {
    // 隐私模式下仅保留当前页面状态
  }
}

export function getPreferredDevice(kind) {
  try {
    return JSON.parse(localStorage.getItem(DEVICE_PREF_KEY) || '{}')[kind] || ''
  } catch (error) {
    return ''
  }
}

// 清除偏好，交回浏览器自动选择设备（对应设置里的「系统默认」）
export function clearPreferredDevice(kind) {
  try {
    const prefs = JSON.parse(localStorage.getItem(DEVICE_PREF_KEY) || '{}')
    delete prefs[kind]
    localStorage.setItem(DEVICE_PREF_KEY, JSON.stringify(prefs))
  } catch (error) {
    // 隐私模式下无需清理
  }
}

// 按偏好设备采集：先 exact 指定设备，失败（设备拔出/被占用/ID 过期）回退系统默认；
// 回退成功时把实际设备 ID 写回偏好，供后续页面沿用。kind 取 'video' / 'audio'。
export async function requestMediaWithFallback(kind, deviceId) {
  if (deviceId) {
    try {
      const stream = await requestMedia({ [kind]: { deviceId: { exact: deviceId } } })
      return { stream, fallback: false }
    } catch (error) {
      // 指定设备不可用，继续尝试默认设备
    }
  }
  try {
    const stream = await requestMedia({ [kind]: true })
    const track = kind === 'video' ? stream.getVideoTracks()[0] : stream.getAudioTracks()[0]
    const actual = track?.getSettings?.().deviceId
    if (actual) savePreferredDevice(kind, actual)
    return { stream, fallback: true }
  } catch (error) {
    return { error }
  }
}

// 授权后枚举真实设备（未授权时 label 为空，用占位名）；kind 取 'video' / 'audio'。
export async function listMediaDevices(kind) {
  const kindMap = { video: 'videoinput', audio: 'audioinput' }
  const nameMap = { video: '摄像头', audio: '麦克风' }
  try {
    const devices = await navigator.mediaDevices.enumerateDevices()
    return devices
      .filter((item) => item.kind === kindMap[kind])
      .map((item, index) => ({ deviceId: item.deviceId, label: item.label || `${nameMap[kind]} ${index + 1}` }))
  } catch (error) {
    return []
  }
}