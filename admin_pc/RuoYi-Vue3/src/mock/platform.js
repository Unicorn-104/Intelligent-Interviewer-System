// 平台运营扩展模块 mock 数据（用户中心/企业认证/消息管理/帮助反馈/评估配置/业务监管）
import { ok } from './db'

// ===== 用户中心：C 端用户 =====
export const memberUsers = [
  {
    userId: 1,
    userName: '林晓同学',
    account: 'linxiao01',
    phone: '13810001001',
    email: 'linxiao01@163.com',
    identity: '0',
    companyName: '杭州电子科技大学',
    realName: '林晓',
    realStatus: '1',
    status: '0',
    resumeCount: 3,
    applyCount: 12,
    registerTime: '2026-07-02 10:21:33',
    lastLoginTime: '2026-09-06 21:40:12'
  },
  {
    userId: 2,
    userName: 'Kevin-Wang',
    account: 'kevin_w',
    phone: '13810001002',
    email: 'kevin.wang@qq.com',
    identity: '0',
    companyName: '未认证',
    realName: '王凯',
    realStatus: '1',
    status: '0',
    resumeCount: 2,
    applyCount: 27,
    registerTime: '2026-07-05 14:02:10',
    lastLoginTime: '2026-09-06 19:22:45'
  },
  {
    userId: 3,
    userName: 'HR-张敏',
    account: 'zhangmin_hr',
    phone: '13920002001',
    email: 'zhangmin@beyondsoft.com',
    identity: '1',
    companyName: '博彦科技',
    realName: '张敏',
    realStatus: '1',
    status: '0',
    resumeCount: 0,
    applyCount: 0,
    registerTime: '2026-07-11 16:44:51',
    lastLoginTime: '2026-09-06 18:05:37'
  },
  {
    userId: 4,
    userName: '面试官-老周',
    account: 'zhou_interview',
    phone: '13920002002',
    email: 'zhou@ihep.ac.cn',
    identity: '1',
    companyName: '中科院软件所',
    realName: '周正',
    realStatus: '1',
    status: '0',
    resumeCount: 0,
    applyCount: 0,
    registerTime: '2026-07-25 10:10:40',
    lastLoginTime: '2026-09-06 09:30:22'
  },
  {
    userId: 5,
    userName: '阿离',
    account: 'ali_lee',
    phone: '13810001004',
    email: 'ali.lee@gmail.com',
    identity: '0',
    companyName: '未认证',
    realName: '',
    realStatus: '0',
    status: '1',
    resumeCount: 1,
    applyCount: 3,
    registerTime: '2026-07-15 22:30:16',
    lastLoginTime: '2026-08-02 11:12:54'
  },
  {
    userId: 6,
    userName: '考研二战选手',
    account: 'kaoyan2nd',
    phone: '13810001007',
    email: 'kaoyan2nd@126.com',
    identity: '0',
    companyName: '武汉大学',
    realName: '赵启明',
    realStatus: '1',
    status: '3',
    resumeCount: 1,
    applyCount: 2,
    registerTime: '2026-08-05 13:41:20',
    lastLoginTime: '2026-09-01 08:22:17'
  },
  {
    userId: 7,
    userName: '产品小萌新',
    account: 'pm_xin',
    phone: '13810001008',
    email: 'pm.xin@foxmail.com',
    identity: '0',
    companyName: '南京大学',
    realName: '孙悦',
    realStatus: '1',
    status: '0',
    resumeCount: 3,
    applyCount: 21,
    registerTime: '2026-08-12 11:05:55',
    lastLoginTime: '2026-09-06 22:18:03'
  }
]

const devicePool = {
  1: [
    {
      deviceId: 101,
      deviceName: 'Chrome 132 / Windows 11',
      ip: '117.136.8.11',
      location: '浙江省杭州市',
      loginTime: '2026-09-06 21:40:12',
      current: '0'
    },
    {
      deviceId: 102,
      deviceName: 'AI招聘APP / iPhone 15',
      ip: '117.136.8.11',
      location: '浙江省杭州市',
      loginTime: '2026-09-05 08:12:40',
      current: '1'
    }
  ],
  3: [
    {
      deviceId: 101,
      deviceName: 'Edge 132 / Windows 10',
      ip: '111.20.4.88',
      location: '湖北省武汉市',
      loginTime: '2026-09-06 23:01:09',
      current: '0'
    },
    {
      deviceId: 102,
      deviceName: 'AI招聘APP / 小米13',
      ip: '223.104.5.7',
      location: '湖北省武汉市',
      loginTime: '2026-08-20 09:02:14',
      current: '1'
    }
  ],
  5: [
    {
      deviceId: 101,
      deviceName: 'Safari / iPad Air',
      ip: '183.221.6.40',
      location: '四川省成都市',
      loginTime: '2026-08-02 11:12:54',
      current: '1'
    }
  ],
  7: [
    {
      deviceId: 101,
      deviceName: 'Chrome 132 / Windows 11',
      ip: '58.192.2.31',
      location: '江苏省南京市',
      loginTime: '2026-09-06 22:18:03',
      current: '0'
    },
    {
      deviceId: 102,
      deviceName: '微信小程序',
      ip: '58.192.2.31',
      location: '江苏省南京市',
      loginTime: '2026-09-03 10:20:55',
      current: '1'
    }
  ]
}

export function memberDetail(id) {
  const user = memberUsers.find((u) => u.userId === id)
  if (!user) return { user: {}, devices: [], loginLogs: [] }
  const loginLogs = [
    { time: user.lastLoginTime, ip: '117.136.8.11', location: '浙江省杭州市', result: '成功' },
    { time: '2026-09-05 08:12:40', ip: '117.136.8.11', location: '浙江省杭州市', result: '成功' },
    { time: '2026-09-03 19:44:02', ip: '112.17.40.9', location: '浙江省宁波市', result: '成功' }
  ]
  return {
    user,
    devices: devicePool[id] || [
      {
        deviceId: 900 + id,
        deviceName: 'Chrome 132 / Windows 10',
        ip: '61.135.2.8',
        location: '北京市',
        loginTime: user.lastLoginTime,
        current: '0'
      }
    ],
    loginLogs
  }
}

// ===== 用户中心：企业认证审核 =====
export const verifyApps = [
  {
    verifyId: 1,
    userName: 'Kevin-Wang',
    phone: '13810001002',
    companyName: '北京字节跳动科技有限公司',
    creditCode: '91110108MA01K7XK8Q',
    position: '应届实习生',
    material: '实习合同及在职证明.pdf',
    applyTime: '2026-09-05 10:22:31',
    status: '0',
    reason: '',
    auditTime: '',
    auditor: ''
  },
  {
    verifyId: 2,
    userName: '林晓同学',
    phone: '13810001001',
    companyName: '杭州电子科技大学',
    creditCode: '123300004705199A2B',
    position: '在校学生',
    material: '学信网备案表.pdf',
    applyTime: '2026-09-04 09:15:40',
    status: '1',
    reason: '材料齐全，审核通过',
    auditTime: '2026-09-04 15:02:11',
    auditor: 'ops01'
  },
  {
    verifyId: 3,
    userName: '阿离',
    phone: '13810001004',
    companyName: '深圳市腾讯计算机系统有限公司',
    creditCode: '91440300708461136T',
    position: '求职者',
    material: '离职证明.pdf',
    applyTime: '2026-09-03 20:31:08',
    status: '2',
    reason: '证明材料模糊，无法核验企业信息，请重新上传',
    auditTime: '2026-09-04 10:12:45',
    auditor: 'ops01'
  },
  {
    verifyId: 4,
    userName: '产品小萌新',
    phone: '13810001008',
    companyName: '南京大学',
    creditCode: '121000004661573X2J',
    position: '在校学生',
    material: '学生证照片.jpg',
    applyTime: '2026-09-05 14:40:12',
    status: '0',
    reason: '',
    auditTime: '',
    auditor: ''
  },
  {
    verifyId: 5,
    userName: 'HR-张敏',
    phone: '13920002001',
    companyName: '博彦科技',
    creditCode: '91110000710934562X',
    position: '人力资源专员',
    material: '劳动合同扫描件.pdf',
    applyTime: '2026-09-01 11:30:22',
    status: '1',
    reason: '企业归属认证成功',
    auditTime: '2026-09-01 16:15:33',
    auditor: 'ops02'
  }
]

// ===== 消息管理：消息模板 =====
export const msgTemplates = [
  {
    templateId: 1,
    templateName: '面试提醒-短信',
    templateCode: 'INTERVIEW_REMIND_SMS',
    channel: 'sms',
    msgType: '0',
    variables: ['候选人姓名', '面试时间', '岗位名称'],
    content: '【AI招聘】${候选人姓名}您好，您应聘的${岗位名称}将于${面试时间}进行AI面试，请提前15分钟完成设备检测。',
    status: '0',
    updateBy: 'ops01',
    updateTime: '2026-08-28 10:20:11'
  },
  {
    templateId: 2,
    templateName: '面试邀请-邮件',
    templateCode: 'INTERVIEW_INVITE_EMAIL',
    channel: 'email',
    msgType: '0',
    variables: ['候选人姓名', '岗位名称', '面试链接'],
    content: '尊敬的${候选人姓名}：恭喜您通过${岗位名称}的简历初筛，请点击 ${面试链接} 进入面试准备页面。',
    status: '0',
    updateBy: 'ops01',
    updateTime: '2026-08-28 10:25:36'
  },
  {
    templateId: 3,
    templateName: '录用通知-邮件',
    templateCode: 'OFFER_EMAIL',
    channel: 'email',
    msgType: '2',
    variables: ['候选人姓名', '岗位名称', '入职时间'],
    content: '亲爱的${候选人姓名}：诚挚邀请您加入我们，担任${岗位名称}，入职时间为${入职时间}，详见附件录用意向书。',
    status: '0',
    updateBy: 'admin',
    updateTime: '2026-08-30 09:18:20'
  },
  {
    templateId: 4,
    templateName: '淘汰关怀通知',
    templateCode: 'REJECT_CARE_SITE',
    channel: 'site',
    msgType: '3',
    variables: ['候选人姓名', '岗位名称'],
    content:
      '${候选人姓名}，感谢您参与${岗位名称}的面试。本次未能进入下一环节，但您的表现已被记录至人才库，期待未来合作。',
    status: '0',
    updateBy: 'ops02',
    updateTime: '2026-08-31 14:02:33'
  },
  {
    templateId: 5,
    templateName: '面试体验调研',
    templateCode: 'SURVEY_MINIAPP',
    channel: 'miniapp',
    msgType: '4',
    variables: ['候选人姓名', '岗位名称', '调研链接'],
    content: '${候选人姓名}，您参与的${岗位名称}面试已结束，诚邀您填写体验问卷（2分钟）：${调研链接}',
    status: '0',
    updateBy: 'ops02',
    updateTime: '2026-09-01 11:30:08'
  }
]

// ===== 消息管理：通知渠道配置 =====
export const msgChannels = [
  {
    channelId: 1,
    channelType: 'sms',
    channelName: '短信通道',
    provider: '阿里云短信服务',
    config: 'AccessKey: LTAI5t****Hq2 / SignName: AI招聘',
    dailyLimit: 50000,
    todayUsed: 12368,
    status: '0',
    remark: '主通道'
  },
  {
    channelId: 2,
    channelType: 'email',
    channelName: '邮件通道',
    provider: 'SMTP 邮件服务',
    config: 'smtp://mailer.aihire.com:465',
    dailyLimit: 20000,
    todayUsed: 3120,
    status: '0',
    remark: ''
  },
  {
    channelId: 3,
    channelType: 'miniapp',
    channelName: '小程序订阅消息',
    provider: '微信小程序',
    config: 'AppID: wx8a2c****9f / TemplateID 已配置 6 个',
    dailyLimit: 100000,
    todayUsed: 8455,
    status: '0',
    remark: ''
  },
  {
    channelId: 4,
    channelType: 'site',
    channelName: '站内推送',
    provider: '平台自建 WebSocket',
    config: '网关: wss://push.aihire.com',
    dailyLimit: 0,
    todayUsed: 45210,
    status: '0',
    remark: '无频控限制，0 表示不限'
  }
]

// ===== 消息管理：发送记录 =====
export const msgRecords = [
  {
    recordId: 1,
    sendTime: '2026-09-06 21:35:12',
    channel: 'sms',
    templateName: '面试提醒-短信',
    receiver: '林晓同学',
    contact: '138****1001',
    content: '【AI招聘】林晓您好，您应聘的Java开发工程师将于明日10:00进行AI面试…',
    status: '0',
    failReason: ''
  },
  {
    recordId: 2,
    sendTime: '2026-09-06 21:35:15',
    channel: 'miniapp',
    templateName: '面试官提醒-小程序',
    receiver: '面试官-老周',
    contact: 'wxo_9f2k3l',
    content: '周正，您担任面试官的场次（候选人：林晓）将于明日10:00开始…',
    status: '0',
    failReason: ''
  },
  {
    recordId: 3,
    sendTime: '2026-09-06 18:02:40',
    channel: 'email',
    templateName: '面试邀请-邮件',
    receiver: 'Kevin-Wang',
    contact: 'kev***@qq.com',
    content: '尊敬的Kevin-Wang：恭喜您通过产品经理的简历初筛…',
    status: '1',
    failReason: '收件邮箱不存在（550 User not found）'
  },
  {
    recordId: 4,
    sendTime: '2026-09-06 16:44:08',
    channel: 'site',
    templateName: '录用通知-邮件',
    receiver: '产品小萌新',
    contact: '站内信',
    content: '孙悦，您投递的数据分析师已通过终面评估（综合得分88分），HR将在24小时内联系…',
    status: '0',
    failReason: ''
  },
  {
    recordId: 5,
    sendTime: '2026-09-06 15:20:33',
    channel: 'sms',
    templateName: '面试提醒-短信',
    receiver: 'HR-张敏',
    contact: '139****2001',
    content: '【AI招聘】张敏您好，您今日16:00有一场AI+HR协同面试，候选人信息已推送…',
    status: '0',
    failReason: ''
  },
  {
    recordId: 6,
    sendTime: '2026-09-05 22:12:55',
    channel: 'miniapp',
    templateName: '面试体验调研',
    receiver: '阿离',
    contact: 'wxo_3k9d2m',
    content: '阿离，您参与的算法工程师面试已结束，诚邀您填写体验问卷（2分钟）…',
    status: '1',
    failReason: '用户未订阅该模板消息'
  }
]

// ===== 内容管理：帮助文章 =====
export const helpArticles = [
  {
    articleId: 1,
    categoryName: '新手指引',
    title: '三分钟完成注册与身份认证',
    summary: '手把手完成账号注册、身份选择与企业归属认证。',
    views: 12840,
    usefulCount: 921,
    status: '0',
    updateBy: 'ops01',
    updateTime: '2026-08-20 10:00:00'
  },
  {
    articleId: 2,
    categoryName: '面试指南',
    title: 'AI 面试前设备检测与环境准备',
    summary: '摄像头、麦克风、网络检测方法与常见问题。',
    views: 15230,
    usefulCount: 1204,
    status: '0',
    updateBy: 'tech01',
    updateTime: '2026-08-30 16:40:22'
  },
  {
    articleId: 3,
    categoryName: '账号安全',
    title: '如何修改手机号 / 邮箱 / 密码',
    summary: '账号敏感信息修改流程与安全验证说明。',
    views: 8105,
    usefulCount: 640,
    status: '0',
    updateBy: 'ops02',
    updateTime: '2026-08-22 14:30:00'
  },
  {
    articleId: 4,
    categoryName: '企业端帮助',
    title: '企业 HR 如何配置招聘流程',
    summary: '面试模式选择、级联规则与评分阈值配置说明。',
    views: 5120,
    usefulCount: 402,
    status: '0',
    updateBy: 'ops01',
    updateTime: '2026-09-02 15:33:47'
  }
]

// ===== 内容管理：反馈工单 =====
export const feedbacks = [
  {
    feedbackId: 1,
    userName: '林晓同学',
    type: '0',
    content: 'AI 面试进行到第 12 分钟时画面卡顿，声音正常，重连后恢复正常。',
    contact: '13810001001',
    images: 2,
    createTime: '2026-09-06 21:52:10',
    status: '0',
    reply: '',
    handler: '',
    handleTime: ''
  },
  {
    feedbackId: 2,
    userName: '产品小萌新',
    type: '1',
    content: '建议简历导出支持一键投递时自动选择匹配度最高的简历。',
    contact: 'pm.xin@foxmail.com',
    images: 0,
    createTime: '2026-09-06 15:30:44',
    status: '1',
    reply: '',
    handler: '',
    handleTime: ''
  },
  {
    feedbackId: 3,
    userName: 'Kevin-Wang',
    type: '0',
    content: '面试邀请邮件进了垃圾箱，建议提醒用户添加白名单。',
    contact: 'kevin.wang@qq.com',
    images: 1,
    createTime: '2026-09-05 19:20:08',
    status: '2',
    reply: '已采纳，将在通知偏好中增加邮箱白名单提示。',
    handler: 'ops01',
    handleTime: '2026-09-06 09:40:12'
  },
  {
    feedbackId: 4,
    userName: '阿离',
    type: '0',
    content: '企业认证上传材料一直提示格式错误，PDF 和 JPG 都不行。',
    contact: 'ali.lee@gmail.com',
    images: 3,
    createTime: '2026-09-02 09:25:16',
    status: '2',
    reply: '已定位为文件大小校验误判，已修复。',
    handler: 'tech01',
    handleTime: '2026-09-02 15:02:33'
  },
  {
    feedbackId: 5,
    userName: '考研二战选手',
    type: '2',
    content: '注销账号后简历数据会保留多久？',
    contact: 'kaoyan2nd@126.com',
    images: 0,
    createTime: '2026-09-03 11:40:29',
    status: '2',
    reply: '注销后个人数据将在 7 天冷静期后彻底删除。',
    handler: 'ops02',
    handleTime: '2026-09-03 13:15:40'
  }
]

// ===== 内容管理：客服配置 =====
export const serviceConfig = {
  workTime: '工作日 9:00 - 18:00',
  phone: '400-888-9999',
  email: 'support@aihire.com',
  robotEnabled: true,
  robotWelcome: '您好，我是平台智能客服小智，面试进度、岗位详情、常见操作问题都可以直接问我，转人工请回复"人工"。',
  responseTimeout: 30,
  manualGuide: '工作时间外请留言，客服将在 1 个工作日内回复。'
}

// ===== AI 配置：评估评分卡 =====
export const scorecards = [
  {
    cardId: 1,
    cardName: '通用技术面试评分卡',
    jobDirection: '技术研发',
    dimensions: [
      { name: '技术理论', weight: 25 },
      { name: '动手实践', weight: 25 },
      { name: '逻辑思维', weight: 20 },
      { name: '沟通表达', weight: 15 },
      { name: '文化匹配度', weight: 15 }
    ],
    totalScore: 100,
    status: '0',
    remark: '默认启用，适用于全部研发类岗位',
    createTime: '2026-06-10 10:00:00'
  },
  {
    cardId: 2,
    cardName: '算法岗位评分卡',
    jobDirection: '算法工程',
    dimensions: [
      { name: '数学基础', weight: 20 },
      { name: '动手实践', weight: 25 },
      { name: '逻辑思维', weight: 25 },
      { name: '沟通表达', weight: 15 },
      { name: '文化匹配度', weight: 15 }
    ],
    totalScore: 100,
    status: '0',
    remark: '偏重逻辑与数学基础',
    createTime: '2026-06-15 14:30:00'
  },
  {
    cardId: 3,
    cardName: '产品经理评分卡',
    jobDirection: '产品运营',
    dimensions: [
      { name: '行业理解', weight: 25 },
      { name: '逻辑思维', weight: 20 },
      { name: '沟通表达', weight: 25 },
      { name: '文档能力', weight: 15 },
      { name: '文化匹配度', weight: 15 }
    ],
    totalScore: 100,
    status: '0',
    remark: '',
    createTime: '2026-06-20 09:12:40'
  },
  {
    cardId: 4,
    cardName: '校招通用评分卡（轻量版）',
    jobDirection: '不限',
    dimensions: [
      { name: '学习能力', weight: 30 },
      { name: '逻辑思维', weight: 25 },
      { name: '沟通表达', weight: 25 },
      { name: '文化匹配度', weight: 20 }
    ],
    totalScore: 100,
    status: '0',
    remark: '面向校招初面，维度精简',
    createTime: '2026-07-01 11:40:22'
  }
]

// ===== AI 配置：级联规则模板 =====
export const cascadeRules = [
  {
    ruleId: 1,
    ruleName: '两阶段筛选-标准版',
    roughTopN: 20,
    deepTopN: 3,
    scoreThreshold: 70,
    autoFlow: '1',
    interviewRounds: '初面-终面',
    status: '0',
    remark: '规则引擎粗排 Top20，LLM 深度分析 Top3',
    createTime: '2026-06-10 10:00:00'
  },
  {
    ruleId: 2,
    ruleName: '两阶段筛选-严选版',
    roughTopN: 30,
    deepTopN: 5,
    scoreThreshold: 75,
    autoFlow: '1',
    interviewRounds: '初面-复面-终面',
    status: '0',
    remark: '适用于高竞争岗位',
    createTime: '2026-06-15 10:20:00'
  },
  {
    ruleId: 3,
    ruleName: '校招批量初筛-宽松版',
    roughTopN: 50,
    deepTopN: 10,
    scoreThreshold: 60,
    autoFlow: '0',
    interviewRounds: '初面-复面',
    status: '0',
    remark: '校招大批量场景，需 HR 复核后流转',
    createTime: '2026-07-01 09:00:00'
  },
  {
    ruleId: 4,
    ruleName: '社招直通-快速版',
    roughTopN: 10,
    deepTopN: 3,
    scoreThreshold: 80,
    autoFlow: '1',
    interviewRounds: '初面-终面',
    status: '0',
    remark: '适合内推与紧急岗位',
    createTime: '2026-07-20 14:40:33'
  }
]

// ===== 业务监管：岗位审核 =====
export const platformJobs = [
  {
    jobId: 1,
    jobName: 'Java开发工程师（2026校招）',
    companyName: '博彦科技',
    salary: '12K-18K',
    city: '北京',
    status: '1',
    riskLevel: '0',
    riskWords: [],
    publishTime: '2026-09-01 10:20:00',
    auditTime: '2026-09-01 11:02:15',
    reason: ''
  },
  {
    jobId: 2,
    jobName: '产品经理（校招）',
    companyName: '字节跳动',
    salary: '20K-30K',
    city: '北京',
    status: '1',
    riskLevel: '0',
    riskWords: [],
    publishTime: '2026-09-02 09:15:33',
    auditTime: '2026-09-02 10:40:02',
    reason: ''
  },
  {
    jobId: 3,
    jobName: '前端开发工程师',
    companyName: '米哈游',
    salary: '15K-25K',
    city: '上海',
    status: '0',
    riskLevel: '0',
    riskWords: [],
    publishTime: '2026-09-06 14:20:11',
    auditTime: '',
    reason: ''
  },
  {
    jobId: 4,
    jobName: '高薪急聘-月入过万不是梦',
    companyName: '未认证企业-星达传媒',
    salary: '面议',
    city: '广州',
    status: '0',
    riskLevel: '2',
    riskWords: ['急聘', '月入过万', '疑似夸大'],
    publishTime: '2026-09-06 11:05:47',
    auditTime: '',
    reason: ''
  },
  {
    jobId: 5,
    jobName: '培训生（先交押金培训）',
    companyName: '未认证企业-启航教育',
    salary: '8K-12K',
    city: '郑州',
    status: '2',
    riskLevel: '2',
    riskWords: ['收取押金', '违规收费'],
    publishTime: '2026-09-05 20:12:08',
    auditTime: '2026-09-06 09:30:41',
    reason: '涉嫌违规收费，予以下架并冻结企业发布权限'
  },
  {
    jobId: 6,
    jobName: 'AI产品实习生',
    companyName: '科大讯飞',
    salary: '6K-8K',
    city: '合肥',
    status: '0',
    riskLevel: '0',
    riskWords: [],
    publishTime: '2026-09-06 18:30:25',
    auditTime: '',
    reason: ''
  }
]

// ===== 业务监管：面试监控 =====
export const interviews = [
  {
    interviewId: 1,
    candidate: '林晓同学',
    jobName: 'Java开发工程师（2026校招）',
    companyName: '博彦科技',
    roundName: '初面',
    mode: '0',
    status: '1',
    startTime: '2026-09-06 21:30:00',
    duration: '18分钟',
    score: 0,
    authFail: 0,
    terminateReason: ''
  },
  {
    interviewId: 2,
    candidate: 'Kevin-Wang',
    jobName: '产品经理（校招）',
    companyName: '字节跳动',
    roundName: '初面',
    mode: '0',
    status: '2',
    startTime: '2026-09-06 19:00:00',
    duration: '35分钟',
    score: 82,
    authFail: 1,
    terminateReason: ''
  },
  {
    interviewId: 3,
    candidate: '产品小萌新',
    jobName: '数据分析师',
    companyName: '网易有道',
    roundName: '复面',
    mode: '1',
    status: '2',
    startTime: '2026-09-06 16:00:00',
    duration: '42分钟',
    score: 88,
    authFail: 0,
    terminateReason: ''
  },
  {
    interviewId: 4,
    candidate: 'salty_fish',
    jobName: '测试开发工程师',
    companyName: '博彦科技',
    roundName: '初面',
    mode: '0',
    status: '3',
    startTime: '2026-09-06 14:30:00',
    duration: '8分钟',
    score: 0,
    authFail: 2,
    terminateReason: 'AI 检测长时间无应答，自动结束并标记待定'
  },
  {
    interviewId: 5,
    candidate: '产品小萌新',
    jobName: 'AI产品实习生',
    companyName: '科大讯飞',
    roundName: '初面',
    mode: '0',
    status: '3',
    startTime: '2026-09-05 09:30:00',
    duration: '5分钟',
    score: 0,
    authFail: 3,
    terminateReason: '会话鉴权连续失败 3 次，疑似越权访问，已拦截'
  }
]

const authLogPool = {
  1: [
    {
      time: '2026-09-06 21:25:12',
      event: '会话 Token 校验',
      ip: '117.136.8.11',
      device: 'Chrome 132 / Windows 11',
      result: '通过'
    },
    {
      time: '2026-09-06 21:25:13',
      event: '场次归属校验',
      ip: '117.136.8.11',
      device: 'Chrome 132 / Windows 11',
      result: '通过'
    },
    {
      time: '2026-09-06 21:26:40',
      event: '设备与环境检测',
      ip: '117.136.8.11',
      device: 'Chrome 132 / Windows 11',
      result: '通过'
    },
    {
      time: '2026-09-06 21:30:00',
      event: '进入面试间',
      ip: '117.136.8.11',
      device: 'Chrome 132 / Windows 11',
      result: '通过'
    }
  ],
  2: [
    {
      time: '2026-09-06 18:55:02',
      event: '会话 Token 校验',
      ip: '58.34.102.11',
      device: 'Firefox 135 / Windows 10',
      result: '通过'
    },
    {
      time: '2026-09-06 18:55:03',
      event: '场次归属校验',
      ip: '58.34.102.11',
      device: 'Firefox 135 / Windows 10',
      result: '拦截',
      detail: 'Token 与场次不匹配，已要求重新获取'
    },
    {
      time: '2026-09-06 18:56:10',
      event: '会话 Token 校验（重试）',
      ip: '58.34.102.11',
      device: 'Firefox 135 / Windows 10',
      result: '通过'
    },
    {
      time: '2026-09-06 19:00:00',
      event: '进入面试间',
      ip: '58.34.102.11',
      device: 'Firefox 135 / Windows 10',
      result: '通过'
    }
  ],
  5: [
    {
      time: '2026-09-05 09:20:11',
      event: '会话 Token 校验',
      ip: '221.192.8.66',
      device: '未知设备 / Linux',
      result: '拦截',
      detail: 'Token 无效'
    },
    {
      time: '2026-09-05 09:24:35',
      event: '会话 Token 校验（重试）',
      ip: '221.192.8.66',
      device: '未知设备 / Linux',
      result: '拦截',
      detail: 'Token 无效'
    },
    {
      time: '2026-09-05 09:28:02',
      event: '会话 Token 校验（第 3 次）',
      ip: '221.192.8.66',
      device: '未知设备 / Linux',
      result: '拦截',
      detail: '连续失败 3 次，账号临时锁定'
    },
    {
      time: '2026-09-05 09:30:00',
      event: '风险处置',
      ip: '-',
      device: '-',
      result: '拦截',
      detail: '标记为异常会话，通知安全审计'
    }
  ]
}

export function interviewDetail(id) {
  const interview = interviews.find((i) => i.interviewId === id)
  if (!interview) return { interview: {}, authLogs: [] }
  const authLogs = authLogPool[id] || [
    {
      time: interview.startTime,
      event: '会话 Token 校验',
      ip: '10.20.30.40',
      device: 'Chrome 132 / Windows 11',
      result: '通过'
    },
    {
      time: interview.startTime,
      event: '场次归属校验',
      ip: '10.20.30.40',
      device: 'Chrome 132 / Windows 11',
      result: '通过'
    },
    {
      time: interview.startTime,
      event: '设备与环境检测',
      ip: '10.20.30.40',
      device: 'Chrome 132 / Windows 11',
      result: '通过'
    }
  ]
  return { interview, authLogs }
}

// ===== 业务监管：在线考核环境 =====
export const examConfig = {
  languages: ['Java', 'Python', 'JavaScript', 'C++', 'Go', 'SQL'],
  editorTheme: 'vs-dark',
  timeLimit: 60,
  memoryLimit: 256,
  autoSubmit: true,
  plagiarismCheck: true,
  status: '0',
  remark: '全局默认配置，企业可在套餐允许范围内覆盖'
}

export const examRecords = [
  {
    recordId: 1,
    candidate: '林晓同学',
    jobName: 'Java开发工程师（2026校招）',
    companyName: '博彦科技',
    language: 'Java',
    duration: '45分钟',
    score: 90,
    status: '0',
    submitTime: '2026-09-06 11:20:18'
  },
  {
    recordId: 2,
    candidate: '产品小萌新',
    jobName: '数据分析师',
    companyName: '网易有道',
    language: 'SQL',
    duration: '26分钟',
    score: 78,
    status: '0',
    submitTime: '2026-09-06 16:05:44'
  },
  {
    recordId: 3,
    candidate: 'salty_fish',
    jobName: '测试开发工程师',
    companyName: '博彦科技',
    language: 'Python',
    duration: '18分钟',
    score: 0,
    status: '2',
    submitTime: '-',
    remark: '浏览器切屏 5 次，判定异常终止'
  },
  {
    recordId: 4,
    candidate: 'Kevin-Wang',
    jobName: 'AI产品实习生',
    companyName: '科大讯飞',
    language: 'SQL',
    duration: '-',
    score: 0,
    status: '1',
    submitTime: '-'
  }
]
