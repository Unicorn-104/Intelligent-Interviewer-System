// 候选人状态（t_tal.tal_status）11 码口径，与后端 TalStatusService 保持一致
// 0 新入库 / 1 初筛通过 / 2 面试中 / 3 已淘汰 / 4 已录用 / 5 待笔试 /
// 6 笔试中 / 7 笔试通过 / 8 笔试未通过 / 9 笔试缺考 / 10 待发Offer
// 注意：本模块只服务 t_tal.tal_status；t_app_record.app_status 见 appStatus.js，两者不要混用。
export const TAL_STATUS = {
  0: ['新入库', 'gray'],
  1: ['初筛通过', 'green'],
  2: ['面试中', 'purple'],
  3: ['已淘汰', 'red'],
  4: ['已录用', 'green'],
  5: ['待笔试', 'orange'],
  6: ['笔试中', 'orange'],
  7: ['笔试通过', 'green'],
  8: ['笔试未通过', 'red'],
  9: ['笔试缺考', 'gray'],
  10: ['待发Offer', 'orange']
}

export const TAL_STATUS_OPTIONS = Object.keys(TAL_STATUS).map(k => ({ value: Number(k), label: TAL_STATUS[k][0] }))

// 取状态 [文案, 颜色]，未知码兜底
export function talStatusInfo(code) {
  return TAL_STATUS[Number(code)] || ['未知', 'gray']
}
