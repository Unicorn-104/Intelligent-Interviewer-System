/// 模块二：AI 初筛与智能匹配 - 本地模拟数据（Mock Data）。
///
/// 依据《业务功能分析》UC-04（硬性条件自动过滤）、
/// UC-05（AI 多维度匹配与评分排序）、UC-06（短名单 HR 复核）：
/// - 维度权重：技能标签重合度 30% / 项目经验相关性 30% /
///   教育背景匹配度 20% / 行业/领域经验匹配 20%（UC-05 步骤3）
/// - 百分制综合评分 + 各维度明细（步骤4）
/// - 降序排序 + Top N 短名单（步骤5）
/// - Top 3 触发 LLM 深度分析（核心优势/潜在风险/待面试验证点，步骤6-7）
/// - Top 3 个性化招呼语（步骤8）
///
/// TODO: P7阶段替换为真实接口（lib/api/screening_api.dart 的全部函数）。
library;

/// 各维度权重（UC-05 步骤3），展示用。
const Map<String, double> screeningWeights = {
  '技能匹配度': 0.30,
  '项目相关性': 0.30,
  '教育背景': 0.20,
  '行业经验': 0.20,
};

/// 筛选任务列表模拟数据。
/// status: done=已完成（可进入结果）/ running=进行中 / failed=失败（可重试）
const List<Map<String, dynamic>> mockScreeningTasks = [
  {
    'taskId': 501,
    'positionName': '高级 Flutter 开发工程师',
    'candidateCount': 46,
    'passedCount': 18,
    'topN': 20,
    'status': 'done',
    'createdAt': '2026-10-09 09:20',
    'completedAt': '2026-10-09 09:26',
    'progress': 1.0,
  },
  {
    'taskId': 502,
    'positionName': 'Java 后端开发工程师',
    'candidateCount': 82,
    'passedCount': 0,
    'topN': 20,
    'status': 'running',
    'createdAt': '2026-10-09 10:02',
    'completedAt': null,
    'progress': 0.62,
  },
  {
    'taskId': 503,
    'positionName': 'AI 产品经理',
    'candidateCount': 31,
    'passedCount': 0,
    'topN': 15,
    'status': 'failed',
    'createdAt': '2026-10-08 16:40',
    'completedAt': null,
    'progress': 0,
  },
];

/// 匹配度评分与短名单模拟数据（按综合评分降序，对应任务 501）。
/// - dims：技能/项目/教育/行业四维得分（步骤3-4）
/// - totalScore：百分制综合评分
/// - top3：是否触发 LLM 深度分析（步骤6）
/// - report：可解释性推荐报告（匹配点/风险点/待核实点 + 原文引用 + 面试建议，步骤7）
/// - greeting：个性化招呼语（步骤8）
/// - reviewStatus：HR 复核状态（UC-06）
const List<Map<String, dynamic>> mockScreeningResults = [
  {
    'candidateId': 201,
    'name': '陈思远',
    'education': '硕士·浙江大学',
    'years': '6年经验',
    'totalScore': 92.5,
    'rank': 1,
    'dims': {'技能匹配度': 95.0, '项目相关性': 90.0, '教育背景': 88.0, '行业经验': 93.0},
    'top3': true,
    'report': {
      'strengths': [
        'Flutter 跨端架构经验与岗位画像高度吻合，主导过交易链路 Flutter 化改造，渲染性能提升 40%',
        '具备完整组件库建设经验，30+ 业务组件沉淀与岗位软性要求"技术分享"匹配',
      ],
      'risks': [
        '近两年无独立带团队经历，管理潜质待验证',
      ],
      'toVerify': [
        '简历中"性能提升 40%"缺乏量化口径，需在面试中追问测量方法',
      ],
      'quotes': [
        '原文引用："负责 App 核心交易链路 Flutter 化改造，页面渲染性能提升 40%"',
      ],
      'interviewAdvice': '建议重点考察：跨端架构选型理由、性能优化方法论，追问组件库的双端一致性治理。',
    },
    'greeting':
        '尊敬的陈思远，您好！我们在招聘平台看到您的简历，您在 Flutter 跨端架构与性能优化上的经验与我们的"高级 Flutter 开发工程师"岗位非常匹配，特此邀请您进一步沟通，期待您的回复！',
    'reviewStatus': 'confirmed',
  },
  {
    'candidateId': 205,
    'name': '孙铭泽',
    'education': '本科·华中科技大学',
    'years': '7年经验',
    'totalScore': 88.2,
    'rank': 2,
    'dims': {'技能匹配度': 88.0, '项目相关性': 92.0, '教育背景': 79.0, '行业经验': 85.0},
    'top3': true,
    'report': {
      'strengths': [
        '7 年后端经验，Spring Cloud 生态熟练，项目经验与岗位 JD 关键词重合度高',
      ],
      'risks': [
        '简历中未见高并发场景的专项描述，抗压能力存疑',
      ],
      'toVerify': [
        '教育背景为本科，与岗位画像"本科即可"要求一致，但需核实是否为统招学历',
      ],
      'quotes': [
        '原文引用："负责订单中心微服务拆分，支撑日订单量 300 万"',
      ],
      'interviewAdvice': '建议重点考察：分布式事务落地细节、消息队列选型与降级方案。',
    },
    'greeting':
        '尊敬的孙铭泽，您好！您的后端微服务项目经验引起了我们的注意，与"Java 后端开发工程师"岗位高度契合。我们正在寻找像您这样有大规模系统实战经验的人才，期待与您交流！',
    'reviewStatus': 'confirmed',
  },
  {
    'candidateId': 203,
    'name': '王浩然',
    'education': '硕士·复旦大学',
    'years': '5年经验',
    'totalScore': 85.6,
    'rank': 3,
    'dims': {'技能匹配度': 86.0, '项目相关性': 84.0, '教育背景': 90.0, '行业经验': 82.0},
    'top3': true,
    'report': {
      'strengths': [
        'NLP 方向硕士背景 + RAG/LLM 应用落地经验，与 AI 实验室岗位画像契合',
      ],
      'risks': [
        '工程化深度不足，未见大规模线上服务部署经验',
      ],
      'toVerify': [
        'RAG 项目描述偏概念，需核实检索策略与效果评估细节',
      ],
      'quotes': [
        '原文引用："主导企业知识库 RAG 问答系统从 0 到 1 建设"',
      ],
      'interviewAdvice': '建议重点考察：向量检索选型、embedding 效果评估方法、LLM 幻觉治理。',
    },
    'greeting':
        '尊敬的王浩然，您好！您在 NLP 与 RAG 方向的实践与我们的"算法工程师（NLP）"岗位要求高度匹配，特别是知识库问答系统的落地经验非常难得，期待与您深入交流！',
    'reviewStatus': 'pending',
  },
  {
    'candidateId': 207,
    'name': '周雨桐',
    'education': '硕士·同济大学',
    'years': '3年经验',
    'totalScore': 79.4,
    'rank': 4,
    'dims': {'技能匹配度': 82.0, '项目相关性': 76.0, '教育背景': 85.0, '行业经验': 72.0},
    'top3': false,
    'report': {
      'strengths': [
        'Flutter 基础扎实，教育背景为计算机硕士，学习能力强',
      ],
      'risks': [
        '项目复杂度偏低，缺乏大型项目架构经验',
      ],
      'toVerify': [
        '期望薪资与岗位预算区间有差距，需核实期望',
      ],
      'quotes': <String>[],
      'interviewAdvice': '建议二轮评估，先考察基础能力与潜力。',
    },
    'greeting': null,
    'reviewStatus': 'pending',
  },
  {
    'candidateId': 209,
    'name': '吴子昂',
    'education': '本科·西安电子科技大学',
    'years': '4年经验',
    'totalScore': 72.8,
    'rank': 5,
    'dims': {'技能匹配度': 74.0, '项目相关性': 70.0, '教育背景': 76.0, '行业经验': 70.0},
    'top3': false,
    'report': {
      'strengths': [
        '有 Android 原生开发经验，可快速迁移 Flutter',
      ],
      'risks': [
        '无 Flutter 实际项目经历，技术栈切换成本高',
      ],
      'toVerify': [
        '工作稳定性：近 3 年更换 2 次工作，需核实离职原因',
      ],
      'quotes': <String>[],
      'interviewAdvice': '如岗位急招可作为备选，建议先线上笔试。',
    },
    'greeting': null,
    'reviewStatus': 'pending',
  },
  {
    'candidateId': 211,
    'name': '郑凯文',
    'education': '本科·杭州电子科技大学',
    'years': '2年经验',
    'totalScore': 68.1,
    'rank': 6,
    'dims': {'技能匹配度': 70.0, '项目相关性': 64.0, '教育背景': 72.0, '行业经验': 65.0},
    'top3': false,
    'report': {
      'strengths': [
        '学习意愿强，有个人开源项目',
      ],
      'risks': [
        '经验年限未达岗位硬性门槛边缘，需 HR 确认是否放宽',
      ],
      'toVerify': [
        '开源项目贡献真实性',
      ],
      'quotes': <String>[],
      'interviewAdvice': '建议暂不进入面试，保留人才库观察。',
    },
    'greeting': null,
    'reviewStatus': 'pending',
  },
];
