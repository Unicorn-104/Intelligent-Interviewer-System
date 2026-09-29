import request from '@/utils/request'

// 平台运营统计
export const listStats = () => request({ url: '/dashboard/stats', method: 'get' })
// 近30天趋势
export const listTrend = () => request({ url: '/dashboard/trend', method: 'get' })
// 套餐分布
export const listPackageDist = () => request({ url: '/dashboard/packageDist', method: 'get' })
// 企业 API 调用量 TOP10
export const listApiTop = () => request({ url: '/dashboard/apiTop', method: 'get' })
// 最近操作动态
export const listRecentLogs = () => request({ url: '/dashboard/recentLogs', method: 'get' })
// 招聘闭环工作台数据：后续接入真实服务时保持返回结构不变
export const listRecruitmentOverview = () => request({ url: '/dashboard/recruitmentOverview', method: 'get' })
