// 业务模块 mock 数据（租户 / AI / 内容 / 广告 / 仪表盘）
import { ok, paginate, nextId } from './db'

// ===== 租户管理 =====
export const companies = [
  {
    companyId: 1,
    companyName: '贵州慧科未来科技有限公司',
    contactName: '张伟',
    contactPhone: '13908510001',
    packageType: 'flag',
    status: '0',
    candidateCount: 3260,
    apiUsed: 8462,
    apiQuota: 10000,
    expireTime: '2027-03-15',
    createTime: '2024-03-15 10:00:00'
  },
  {
    companyId: 2,
    companyName: '贵阳数联信息技术有限公司',
    contactName: '李娜',
    contactPhone: '13908510002',
    packageType: 'pro',
    status: '0',
    candidateCount: 1820,
    apiUsed: 5230,
    apiQuota: 5000,
    expireTime: '2026-09-28',
    createTime: '2024-05-20 14:30:00'
  },
  {
    companyId: 3,
    companyName: '贵州云智大数据服务有限公司',
    contactName: '王强',
    contactPhone: '13908510003',
    packageType: 'basic',
    status: '0',
    candidateCount: 640,
    apiUsed: 980,
    apiQuota: 2000,
    expireTime: '2026-12-01',
    createTime: '2024-08-11 09:12:45'
  },
  {
    companyId: 4,
    companyName: '遵义人才发展集团有限公司',
    contactName: '刘洋',
    contactPhone: '13908510004',
    packageType: 'pro',
    status: '2',
    candidateCount: 310,
    apiUsed: 120,
    apiQuota: 5000,
    expireTime: '2026-10-15',
    createTime: '2026-08-05 16:40:22'
  },
  {
    companyId: 5,
    companyName: '贵阳高新区人力资源产业园',
    contactName: '杨帆',
    contactPhone: '13908510006',
    packageType: 'flag',
    status: '0',
    candidateCount: 4520,
    apiUsed: 6720,
    apiQuota: 10000,
    expireTime: '2027-06-30',
    createTime: '2025-03-22 08:55:10'
  }
]

export function companyDetail(id) {
  const c = companies.find((x) => x.companyId === Number(id))
  if (!c) return ok(null)
  return ok({
    company: c,
    creditCode: '91520100MA6DXXXX0' + c.companyId,
    industry: '人力资源服务',
    scale: c.companyId % 2 === 0 ? '100-499人' : '500-999人',
    address: '贵州省贵阳市观山湖区',
    contactEmail: 'contact' + c.companyId + '@example.com',
    contactPosition: 'HRD',
    resetDate: '2026-10-01',
    quotaList: [
      { name: 'AI 面试次数', quota: Math.round(c.apiQuota / 2), used: Math.round(c.apiUsed / 2), unit: '次/月' },
      { name: '简历解析次数', quota: Math.round(c.apiQuota / 2), used: Math.round(c.apiUsed / 3), unit: '次/月' }
    ],
    accounts: [
      {
        userId: c.companyId * 100 + 1,
        userName: 'hr' + c.companyId + '01',
        nickName: 'HR管理员-' + c.contactName,
        dept: '人事部',
        status: '0',
        createTime: '2025-02-01 09:00:00'
      },
      {
        userId: c.companyId * 100 + 2,
        userName: 'hr' + c.companyId + '02',
        nickName: '招聘专员-小刘',
        dept: '人事部',
        status: '0',
        createTime: '2025-03-10 14:20:00'
      }
    ],
    logs: [
      { content: '管理员 admin 续期套餐至 ' + c.expireTime, operName: 'admin', operTime: '2026-08-15 10:24:31' },
      { content: '调整 AI 调用配额至 ' + c.apiQuota, operName: 'ops01', operTime: '2026-08-10 15:02:11' },
      { content: '新增企业入驻资料审核通过', operName: 'ops02', operTime: c.createTime }
    ]
  })
}

// ===== 套餐管理 =====
export const packages = [
  {
    packageId: 1,
    packageName: '基础版',
    price: 999,
    aiInterviewQuota: 1000,
    resumeParseQuota: 1000,
    maxAccounts: 5,
    functions: ['ai_interview', 'resume_parse', 'im_chat'],
    status: '0',
    remark: '初创团队首选'
  },
  {
    packageId: 2,
    packageName: '专业版',
    price: 2999,
    aiInterviewQuota: 5000,
    resumeParseQuota: 5000,
    maxAccounts: 20,
    functions: [
      'ai_interview',
      'resume_parse',
      'ai_screening',
      'video_interview',
      'dashboard',
      'im_chat',
      'calendar_sync'
    ],
    status: '0',
    remark: '成长型企业推荐'
  },
  {
    packageId: 3,
    packageName: '旗舰版',
    price: 6999,
    aiInterviewQuota: 10000,
    resumeParseQuota: 10000,
    maxAccounts: 100,
    functions: [
      'ai_interview',
      'resume_parse',
      'ai_screening',
      'video_interview',
      'dashboard',
      'custom_prompt',
      'im_chat',
      'calendar_sync',
      'cascade_mode',
      'collab_mode',
      'online_exam',
      'talent_pool',
      'survey'
    ],
    status: '0',
    remark: '集团级客户专属'
  },
  {
    packageId: 4,
    packageName: '试用版',
    price: 0,
    aiInterviewQuota: 200,
    resumeParseQuota: 200,
    maxAccounts: 3,
    functions: ['ai_interview', 'resume_parse', 'im_chat'],
    status: '0',
    remark: '30天全功能试用'
  }
]

// ===== AI 配置：模型管理 =====
export const models = [
  {
    modelId: 1,
    modelName: '通义千问-VL-Max',
    provider: 'aliyun',
    modelTypes: ['vl'],
    apiUrl: 'https://dashscope.aliyuncs.com/api/v1/**/**',
    unitPrice: 0.02,
    status: '0',
    lastCallTime: '2026-09-06 21:30:11',
    apiKey: 'sk-************9f3d',
    timeout: 30000,
    maxConcurrency: 50
  },
  {
    modelId: 2,
    modelName: '通义千问-Plus',
    provider: 'aliyun',
    modelTypes: ['text'],
    apiUrl: 'https://dashscope.aliyuncs.com/api/v1/**/**',
    unitPrice: 0.004,
    status: '0',
    lastCallTime: '2026-09-06 20:18:32',
    apiKey: 'sk-************9f3d',
    timeout: 15000,
    maxConcurrency: 100
  },
  {
    modelId: 3,
    modelName: '通义千问-Audio',
    provider: 'aliyun',
    modelTypes: ['voice'],
    apiUrl: 'https://dashscope.aliyuncs.com/api/v1/**/**',
    unitPrice: 0.008,
    status: '0',
    lastCallTime: '2026-09-06 18:55:03',
    apiKey: 'sk-************9f3d',
    timeout: 30000,
    maxConcurrency: 30
  },
  {
    modelId: 4,
    modelName: 'GPT-4o（备用）',
    provider: 'other',
    modelTypes: ['vl', 'text'],
    apiUrl: 'https://api.openai.com/v1/**/**',
    unitPrice: 0.15,
    status: '1',
    lastCallTime: '2026-08-30 10:02:11',
    apiKey: 'sk-************ab21',
    timeout: 30000,
    maxConcurrency: 20
  }
]

// ===== AI 配置：API 配额 =====
export const quotas = [
  {
    quotaId: 1,
    companyId: 1,
    companyName: '贵州慧科未来科技有限公司',
    modelName: '通义千问-VL-Max',
    monthlyQuota: 5000,
    used: 4231,
    resetDate: '2026-10-01'
  },
  {
    quotaId: 2,
    companyId: 1,
    companyName: '贵州慧科未来科技有限公司',
    modelName: '通义千问-Plus',
    monthlyQuota: 5000,
    used: 1836,
    resetDate: '2026-10-01'
  },
  {
    quotaId: 3,
    companyId: 2,
    companyName: '贵阳数联信息技术有限公司',
    modelName: '通义千问-VL-Max',
    monthlyQuota: 2500,
    used: 2286,
    resetDate: '2026-10-01'
  },
  {
    quotaId: 4,
    companyId: 5,
    companyName: '贵阳高新区人力资源产业园',
    modelName: '通义千问-VL-Max',
    monthlyQuota: 5000,
    used: 3360,
    resetDate: '2026-10-01'
  },
  {
    quotaId: 5,
    companyId: 3,
    companyName: '贵州云智大数据服务有限公司',
    modelName: '通义千问-Plus',
    monthlyQuota: 1000,
    used: 928,
    resetDate: '2026-10-01'
  }
]

export function quotaUsage(id) {
  const days = 30
  const daily = []
  let base = 60 + ((Number(id) * 13) % 40)
  for (let i = days; i >= 0; i--) {
    const d = new Date(2026, 8, 4)
    d.setDate(d.getDate() - i)
    const m = String(d.getMonth() + 1).padStart(2, '0')
    const day = String(d.getDate()).padStart(2, '0')
    base += (Math.sin(i * 2.7) * 25) | 0
    daily.push({ date: m + '-' + day, count: Math.max(10, base) })
  }
  return ok({ daily })
}

const promptContent1 =
  '你是资深技术面试官，负责面试候选人{候选人姓名}应聘的【{岗位名称}】岗位（第{面试轮次}）。\n\n要求：\n1. 围绕岗位核心技能栈提问，由浅入深，每次只问一个问题\n2. 根据候选人回答进行追问，考察真实理解深度\n3. 保持专业、礼貌的语气\n4. 当候选人回答完毕后，先给出简短点评再提出下一个问题\n5. 面试共{题目数量}个问题，结束后输出结构化评价报告'

const promptContent2 =
  '你是AI招聘助手，候选人{候选人姓名}正在进行行为面试（第{面试轮次}）。\n\n要求：\n1. 使用 STAR 法则追问情境、任务、行动、结果\n2. 关注沟通协作、抗压能力、成长型思维等软素质\n3. 语气亲切自然，营造轻松氛围\n4. 每次只问一个问题，根据回答深入挖掘'

// ===== AI 配置：提示词模板 =====
export const prompts = [
  {
    promptId: 1,
    promptName: '技术面试官-通用版',
    scene: 'candidate',
    interviewType: 'tech',
    version: 'v3.2',
    status: '1',
    updateBy: 'tech01',
    updateTime: '2026-09-01 10:22:31',
    content: promptContent1
  },
  {
    promptId: 2,
    promptName: '行为面试官-STAR版',
    scene: 'candidate',
    interviewType: 'behavior',
    version: 'v2.0',
    status: '1',
    updateBy: 'tech01',
    updateTime: '2026-08-28 15:40:12',
    content: promptContent2
  },
  {
    promptId: 3,
    promptName: '面试评价报告生成',
    scene: 'hr',
    interviewType: 'mixed',
    version: 'v4.1',
    status: '0',
    updateBy: 'ops01',
    updateTime: '2026-09-03 16:35:20',
    content: '请根据以下面试对话记录，为候选人{候选人姓名}生成结构化面试评价报告……'
  },
  {
    promptId: 4,
    promptName: '综合面试官-管理层专用',
    scene: 'candidate',
    interviewType: 'mixed',
    version: 'v1.5',
    status: '1',
    updateBy: 'admin',
    updateTime: '2026-08-20 09:11:45',
    content: promptContent1
  }
]

export function promptVersions(id) {
  return ok([
    {
      versionId: 1,
      promptId: Number(id),
      version: 'v1.0',
      updateBy: 'tech01',
      updateTime: '2026-06-01 10:00:00',
      changeSummary: '初始版本'
    },
    {
      versionId: 2,
      promptId: Number(id),
      version: 'v2.0',
      updateBy: 'tech01',
      updateTime: '2026-07-10 14:30:00',
      changeSummary: '增加追问策略，优化语气约束'
    },
    {
      versionId: 3,
      promptId: Number(id),
      version: 'v3.0',
      updateBy: 'admin',
      updateTime: '2026-08-12 09:20:00',
      changeSummary: '引入岗位知识库检索增强'
    },
    {
      versionId: 4,
      promptId: Number(id),
      version: 'v3.2',
      updateBy: 'tech01',
      updateTime: '2026-09-01 10:22:31',
      changeSummary: '修复追问死循环问题，增加输出评价报告约束'
    }
  ])
}

// ===== 内容管理：职位分类 =====
export const categories = [
  { categoryId: 1, parentId: 0, categoryName: '技术类', orderNum: 1, status: '0', jobCount: 128 },
  { categoryId: 2, parentId: 1, categoryName: '后端开发', orderNum: 1, status: '0', jobCount: 52 },
  { categoryId: 3, parentId: 1, categoryName: '前端开发', orderNum: 2, status: '0', jobCount: 36 },
  { categoryId: 4, parentId: 0, categoryName: '产品类', orderNum: 2, status: '0', jobCount: 45 },
  { categoryId: 5, parentId: 4, categoryName: '产品经理', orderNum: 1, status: '0', jobCount: 32 },
  { categoryId: 6, parentId: 0, categoryName: '设计类', orderNum: 3, status: '0', jobCount: 28 },
  { categoryId: 7, parentId: 6, categoryName: 'UI 设计师', orderNum: 1, status: '0', jobCount: 18 }
]

// ===== 内容管理：面试题库 =====
const q = (questionId, content, questionType, scene, difficulty, useCount, status) => ({
  questionId,
  content,
  questionType,
  scene,
  difficulty,
  useCount,
  status,
  createTime: '2026-0' + (1 + (questionId % 8)) + '-1' + (questionId % 9) + ' 10:00:00'
})

export const questions = [
  q(1, '请介绍一下你在项目中遇到过的最难的技术问题，以及你是如何解决的？', 'open', 'tech', 'medium', 1582, '0'),
  q(2, 'HTTP 与 HTTPS 的主要区别是什么？', 'single', 'tech', 'easy', 3241, '0'),
  q(3, '以下哪些属于 JVM 垃圾回收算法？', 'multiple', 'tech', 'medium', 1893, '0'),
  q(4, '请描述一次你与团队成员产生分歧的经历，你是如何处理的？', 'open', 'behavior', 'medium', 2210, '0'),
  q(5, '谈谈你对微服务架构中分布式事务的理解。', 'open', 'tech', 'hard', 986, '0'),
  q(6, '在 React/Vue 中，虚拟 DOM 的作用是什么？', 'single', 'tech', 'easy', 2764, '0'),
  q(7, '数据库索引的底层实现通常使用什么数据结构？', 'single', 'tech', 'easy', 2938, '0'),
  q(8, '如果产品经理提出一个你不认同的需求，你会怎么做？', 'open', 'behavior', 'medium', 1740, '0')
]
questions[0].options = []
questions[2].options = [
  { key: 'A', text: '标记-清除', isCorrect: true },
  { key: 'B', text: '复制算法', isCorrect: true },
  { key: 'C', text: '快速排序', isCorrect: false },
  { key: 'D', text: '分代收集', isCorrect: true }
]
questions[5].options = [
  { key: 'A', text: '减少真实 DOM 操作', isCorrect: true },
  { key: 'B', text: '实现跨平台渲染', isCorrect: true },
  { key: 'C', text: '替代浏览器渲染引擎', isCorrect: false },
  { key: 'D', text: '提升复杂页面更新性能', isCorrect: true }
]
questions[6].options = [
  { key: 'A', text: 'B+ 树', isCorrect: true },
  { key: 'B', text: '红黑树', isCorrect: false },
  { key: 'C', text: '哈希表', isCorrect: false },
  { key: 'D', text: '跳表', isCorrect: false }
]
questions.forEach((x) => {
  if (!x.options) x.options = []
  x.analysis = '开放题无标准答案，参考评分要点见题库管理规范。'
})

// ===== 广告管理：广告位管理 =====
export const adSlots = [
  {
    slotId: 1,
    slotName: '候选人端 App 开屏广告',
    slotType: 'splash',
    target: 'candidate',
    ruleDesc: '启动时展示 5s，可跳过（右上角）',
    adCount: 2,
    status: '0'
  },
  {
    slotId: 2,
    slotName: '候选人端首页弹窗',
    slotType: 'popup',
    target: 'candidate',
    ruleDesc: '登录后首次进入展示，24h 最多 1 次，可关闭',
    adCount: 1,
    status: '0'
  },
  {
    slotId: 3,
    slotName: '候选人端职位列表信息流',
    slotType: 'feed',
    target: 'candidate',
    ruleDesc: '列表第 5 条后插入',
    adCount: 3,
    status: '0'
  },
  {
    slotId: 4,
    slotName: 'HR 端首页 Banner',
    slotType: 'banner',
    target: 'hr',
    ruleDesc: '轮播间隔 5s，自动播放',
    adCount: 2,
    status: '0'
  },
  {
    slotId: 5,
    slotName: '小程序开屏广告',
    slotType: 'splash',
    target: 'candidate',
    ruleDesc: '启动时展示 3s，不可跳过',
    adCount: 1,
    status: '1'
  }
]

export function adSlotDetail(id) {
  const s = adSlots.find((x) => x.slotId === Number(id))
  if (!s) return ok(null)
  const rule =
    s.slotType === 'splash'
      ? { showDuration: s.slotId === 5 ? 3 : 5, skippable: s.slotId !== 5, skipPosition: 'right-top' }
      : s.slotType === 'popup'
        ? { triggerMode: 'first', popupInterval: 24, closable: true, closeStyle: 'icon' }
        : s.slotType === 'banner'
          ? { carouselInterval: 5, autoPlay: true }
          : { feedPosition: 5 }
  return ok(Object.assign({ slot: s, rule }, {}))
}

// ===== 广告管理：广告投放管理 =====
export const adverts = [
  {
    advertId: 1,
    title: '秋季招聘旺季企业优惠活动',
    slotId: 1,
    slotName: '候选人端 App 开屏广告',
    adType: 'image',
    target: 'candidate',
    startTime: '2026-09-01 00:00:00',
    endTime: '2026-10-31 23:59:59',
    exposure: 152300,
    clicks: 9140,
    ctr: '6.0%',
    status: '1'
  },
  {
    advertId: 2,
    title: 'AI 模拟面试新功能上线',
    slotId: 2,
    slotName: '候选人端首页弹窗',
    adType: 'image',
    target: 'candidate',
    startTime: '2026-08-15 00:00:00',
    endTime: '2026-09-15 23:59:59',
    exposure: 88460,
    clicks: 7050,
    ctr: '8.0%',
    status: '1'
  },
  {
    advertId: 3,
    title: '名企直通专栏推广',
    slotId: 3,
    slotName: '候选人端职位列表信息流',
    adType: 'rich',
    target: 'candidate',
    startTime: '2026-09-01 00:00:00',
    endTime: '2026-09-30 23:59:59',
    exposure: 42310,
    clicks: 1690,
    ctr: '4.0%',
    status: '1'
  },
  {
    advertId: 4,
    title: '企业版会员续费 8 折',
    slotId: 4,
    slotName: 'HR 端首页 Banner',
    adType: 'image',
    target: 'hr',
    startTime: '2026-08-01 00:00:00',
    endTime: '2026-08-31 23:59:59',
    exposure: 30120,
    clicks: 1520,
    ctr: '5.0%',
    status: '3'
  },
  {
    advertId: 5,
    title: '简历代优化服务',
    slotId: 3,
    slotName: '候选人端职位列表信息流',
    adType: 'video',
    target: 'candidate',
    startTime: '2026-09-10 00:00:00',
    endTime: '2026-10-10 23:59:59',
    exposure: 12300,
    clicks: 480,
    ctr: '3.9%',
    status: '2'
  }
]

export function advertDetail(id) {
  const a = adverts.find((x) => x.advertId === Number(id))
  if (!a) return ok(null)
  return ok(
    Object.assign({}, a, {
      mediaUrl: '',
      jumpType: a.advertId % 2 === 0 ? 'h5' : 'miniapp',
      jumpUrl: 'https://example.com/promo/' + a.advertId,
      dailyLimit: 10000,
      totalLimit: 500000,
      packageTarget: []
    })
  )
}

export function advertStats(id) {
  const days = 15
  const exposureDaily = []
  const clickDaily = []
  let base = 3000 + ((Number(id) * 371) % 2000)
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(2026, 8, 4)
    d.setDate(d.getDate() - i)
    const m = String(d.getMonth() + 1).padStart(2, '0')
    const day = String(d.getDate()).padStart(2, '0')
    base += (Math.sin(i * 1.9) * 320) | 0
    const exp = Math.max(500, base)
    exposureDaily.push({ date: m + '-' + day, count: exp })
    clickDaily.push({ date: m + '-' + day, count: Math.round(exp * (0.03 + (Number(id) % 5) * 0.01)) })
  }
  return ok({ exposureDaily, clickDaily })
}

// ===== 仪表盘 =====
export const dashboardStats = {
  companyTotal: 128,
  companyGrowth: 12,
  companyActive: 96,
  activeRate: '75%',
  candidateTotal: 15680,
  candidateGrowth: 230,
  todayApiCalls: 8432,
  apiQuotaUsage: '67%',
  applicationTotal: 45230,
  applicationGrowth: 418,
  todayApplications: 318,
  todayResumes: 1024,
  resumeSuccessRate: '97.2%',
  todayInterviews: 286,
  screenPassRate: '38.5%'
}

export function dashboardTrend() {
  const dates = []
  const comps = []
  const cands = []
  const itvs = []
  const apps = []
  for (let i = 29; i >= 0; i--) {
    const d = new Date(2026, 8, 4)
    d.setDate(d.getDate() - i)
    dates.push(String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'))
    comps.push((2 + (Math.sin(i / 3) + 1) * 3) | 0)
    cands.push((320 + (Math.sin(i / 2.5) + 1) * 160) | 0)
    itvs.push((180 + (Math.cos(i / 2.2) + 1) * 120) | 0)
    apps.push((1100 + (Math.sin(i / 1.8) + 1) * 350) | 0)
  }
  return { dates, companies: comps, candidates: cands, interviews: itvs, applications: apps }
}

export const packageDist = [
  { name: '基础版', value: 68 },
  { name: '专业版', value: 42 },
  { name: '旗舰版', value: 18 }
]

export const apiTop = [
  { companyName: '贵州慧科未来科技有限公司', calls: 8462, quota: 10000, percent: 85 },
  { companyName: '贵阳高新区人力资源产业园', calls: 6720, quota: 10000, percent: 67 },
  { companyName: '贵阳数联信息技术有限公司', calls: 5230, quota: 5000, percent: 100 },
  { companyName: '贵州黔程人力资源服务有限公司', calls: 2210, quota: 5000, percent: 44 },
  { companyName: '贵州云智大数据服务有限公司', calls: 980, quota: 2000, percent: 49 }
]

export const recentLogs = [
  {
    operName: 'admin',
    content: '管理员 admin 续期企业「贵州慧科未来」旗舰版套餐至 2027-03-15',
    operTime: '2026-09-06 15:21:12',
    level: 'warn'
  },
  {
    operName: 'ops01',
    content: '上架广告「AI 模拟面试新功能上线」至候选人端首页弹窗',
    operTime: '2026-09-06 14:47:21',
    level: 'info'
  },
  {
    operName: 'tech01',
    content: '修改提示词模板「技术面试官-通用版」并发布 v3.2',
    operTime: '2026-09-06 14:03:44',
    level: 'info'
  },
  {
    operName: 'ops02',
    content: '调整「贵阳数联」通义千问-VL 配额：2500 → 3000（原因：旺季扩量）',
    operTime: '2026-09-06 11:02:05',
    level: 'warn'
  },
  {
    operName: 'admin',
    content: '停用企业「贵州人才大市场运营」：合同到期未续费',
    operTime: '2026-09-06 10:15:33',
    level: 'danger'
  }
]

// 招聘闭环工作台：页面只依赖该聚合接口，避免前端拼接多个业务列表
export const recruitmentOverview = {
  asOf: '2026-09-07 10:30:00',
  pipeline: [
    {
      key: 'jobs',
      label: '岗位发布',
      value: 42,
      detail: '18 个岗位招聘中',
      route: '/supervise/job',
      icon: 'Briefcase',
      tone: 'blue'
    },
    {
      key: 'applications',
      label: '简历投递',
      value: 318,
      detail: '今日新增投递',
      route: '/biz/resume',
      icon: 'Document',
      tone: 'green'
    },
    {
      key: 'screening',
      label: 'AI 初筛',
      value: 86,
      detail: '待人工复核',
      route: '/biz/aiScreen',
      icon: 'DataAnalysis',
      tone: 'orange'
    },
    {
      key: 'scheduling',
      label: '面试预约',
      value: 24,
      detail: '待候选人确认',
      route: '/biz/schedule',
      icon: 'Calendar',
      tone: 'purple'
    },
    {
      key: 'interviews',
      label: '面试执行',
      value: 12,
      detail: '今日进行中',
      route: '/supervise/interview',
      icon: 'VideoCamera',
      tone: 'red'
    },
    {
      key: 'evaluations',
      label: '结果评估',
      value: 17,
      detail: '待 HR 终审',
      route: '/biz/interviewEval',
      icon: 'CircleCheckFilled',
      tone: 'teal'
    }
  ],
  todos: [
    {
      id: 'job-audit',
      title: '岗位审核',
      count: 3,
      detail: '含 1 条高风险岗位',
      route: '/supervise/job',
      tone: 'danger'
    },
    {
      id: 'screen-review',
      title: 'AI 初筛复核',
      count: 86,
      detail: '建议今日完成',
      route: '/biz/aiScreen',
      tone: 'warning'
    },
    {
      id: 'eval-review',
      title: '面试结果终审',
      count: 17,
      detail: '等待 HR 确认',
      route: '/biz/interviewEval',
      tone: 'primary'
    },
    {
      id: 'schedule-confirm',
      title: '预约待确认',
      count: 24,
      detail: '候选人尚未选择时间',
      route: '/biz/schedule',
      tone: 'info'
    }
  ],
  funnel: [
    { name: '简历投递', value: 3180 },
    { name: '进入初筛', value: 2460 },
    { name: '通过初筛', value: 942 },
    { name: '完成面试', value: 286 },
    { name: '通过终审', value: 74 }
  ]
}
