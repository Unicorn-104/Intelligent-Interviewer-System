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