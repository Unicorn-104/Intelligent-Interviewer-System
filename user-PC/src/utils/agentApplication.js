import { listApplications } from '@/api/agent/application'

export const legacyJobTitles = Object.freeze({
  'ai-product': '高级产品经理（AI 招聘方向）',
  'smart-cockpit': '智能座舱产品经理',
  'ai-commerce': '产品负责人 · AI 电商',
  growth: '用户增长负责人 · 社区',
  'experience-design': '体验设计负责人 · 游戏事业群',
  commercial: '商业产品经理 · 抖音电商',
  strategy: '策略产品经理 · 本地生活',
  'frontend-react': '前端开发工程师（React）',
  'nlp-algorithm': 'NLP 算法工程师',
  'llm-evaluation': '大模型评测工程师',
  'ai-infra': 'AI Infra 工程师',
  'saas-ux': 'UI/UX 设计师'
})

export function isApplicationId(value) {
  return /^\d+$/.test(String(value || ''))
}

function getApplicationItems(response) {
  return response?.data?.items || response?.items || []
}

export async function resolveApplicationId(value) {
  const rawValue = String(value || '').trim()
  if (isApplicationId(rawValue)) {
    return Number(rawValue)
  }

  const title = legacyJobTitles[rawValue]
  if (!title) {
    return null
  }

  const response = await listApplications({ page: 1, size: 100 })
  const applications = getApplicationItems(response)
  const matched = applications.find((item) => {
    const jobTitle = String(item.jobTitle || '')
    return jobTitle === title || jobTitle.includes(title) || title.includes(jobTitle)
  })
  return matched?.id && isApplicationId(matched.id) ? Number(matched.id) : null
}

export function applicationDetailPath(applicationId) {
  return isApplicationId(applicationId)
    ? `/application-detail?id=${encodeURIComponent(Number(applicationId))}`
    : '/applications'
}

export async function resolveApplicationDetailPath(value) {
  try {
    return applicationDetailPath(await resolveApplicationId(value))
  } catch {
    return '/applications'
  }
}
