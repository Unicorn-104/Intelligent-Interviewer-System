// 岗位投递状态六态口径（与后端 com.ruoyi.common.enums.ApplicationStatus 保持一致）
// 0 APPLIED 已投递 / 1 IN_PROGRESS 招聘中 / 2 PENDING_OFFER 待发Offer /
// 3 OFFER_PENDING_CONFIRMATION 待确认Offer / 4 HIRED 已录用 / 5 NOT_HIRED 未录用
// 注意：本模块只服务 t_app_record.app_status；t_tal.tal_status 为人才库内部状态，口径独立，不要混用。
export const APP_STATUS = {
  0: ['已投递', 'gray'],
  1: ['招聘中', 'blue'],
  2: ['待发Offer', 'orange'],
  3: ['待确认Offer', 'purple'],
  4: ['已录用', 'green'],
  5: ['未录用', 'red']
}

export const APP_STATUS_OPTIONS = Object.keys(APP_STATUS).map(k => ({ value: Number(k), label: APP_STATUS[k][0] }))

// 终态码：已录用/未录用，普通业务操作不可推进
export const TERMINAL_APP_STATUS = [4, 5]
export function isTerminalAppStatus(code) {
  return TERMINAL_APP_STATUS.includes(Number(code))
}

// 终止原因 end_reason（与后端 com.ruoyi.common.enums.ApplicationEndReason 一致，落库字符串）
export const END_REASON_OPTIONS = [
  { value: 'HR_REJECTED', label: 'HR 淘汰' },
  { value: 'CANDIDATE_WITHDRAWN', label: '候选人撤回' },
  { value: 'OFFER_REJECTED', label: '候选人拒绝 Offer' },
  { value: 'OFFER_EXPIRED', label: 'Offer 过期' },
  { value: 'OFFER_CANCELLED', label: 'Offer 取消' },
  { value: 'LEGACY_SCREENING_REJECTED', label: '历史初筛淘汰' }
]

export function endReasonLabel(code) {
  const hit = END_REASON_OPTIONS.find(r => r.value === code)
  return hit ? hit.label : (code || '—')
}

// 取状态 [文案, 颜色]，未知码兜底
export function appStatusInfo(code) {
  return APP_STATUS[Number(code)] || ['未知', 'gray']
}

// 招聘中旁注当前环节（仅展示）：优先取后端节点字段 currentNodeLabel，
// 其次 currentStage；接口未提供时只显示主状态，不猜测环节名。
export function statusTextWithStage(row) {
  const [label] = appStatusInfo(row?.appStatus)
  if (Number(row?.appStatus) === 1) {
    const stage = row?.currentNodeLabel || row?.currentStage || ''
    return stage ? `${label} · ${stage}` : label
  }
  return label
}
