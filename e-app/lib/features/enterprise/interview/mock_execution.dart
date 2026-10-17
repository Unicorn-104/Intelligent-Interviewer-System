/// 模块五：多模式面试执行与级联评估 - 本地模拟数据（Mock Data）。
///
/// 依据《业务功能分析》UC-12（多模式 AI 面试执行与级联评估）、
/// UC-14（HR 协同面试与实时提词）、UC-15（级联面试自动流转）：
/// - 面试工作台：进度、实时字幕（ASR 转写）、AI 提词建议（考察维度+评分要点）
/// - 评估产出：五维能力评分卡（技术理论/动手实践/逻辑思维/沟通表达/文化匹配度）
///   + 200-300 字结构化评语（概述/核心优势/待改进/录用建议）
/// - HR 终审：确认通过/调整后通过/驳回淘汰
/// - 流转：终面→Offer 触发；非终面→级联下一轮；驳回→人才库归档+感谢信
///
/// TODO: P7阶段替换为真实接口（lib/api/interview_room_api.dart 的
/// getCaptions / getCopilotSuggestions / getSessionResult，
/// lib/api/review_api.dart 与 lib/api/offer_api.dart 的全部函数）。
library;

/// 面试工作台：场次进度（UC-12 步骤1-3）。
const Map<String, dynamic> mockExecutionSession = {
  'sessionId': 8801,
  'candidateName': '陈思远',
  'positionName': '高级 Flutter 开发工程师',
  'mode': 'AI+HR 协同',
  'round': '一轮',
  'totalMinutes': 45,
  'elapsedMinutes': 18,
  'questionIndex': 3,
  'totalQuestions': 8,
};

/// 实时字幕流（ASR 转写，UC-12 步骤 A2）。
/// speaker: AI=面试官Agent / HR=HR本人 / CAND=候选人
const List<Map<String, dynamic>> mockCaptionQueue = [
  {'seq': 9, 'speaker': 'AI', 'text': '请具体说一下你在交易链路 Flutter 化改造中，渲染性能提升 40% 是怎么测量的？'},
  {'seq': 10, 'speaker': 'CAND', 'text': '我们主要用 FPS 与首屏耗时两个指标，改造前平均首屏 2.1 秒，改造后稳定在 1.2 秒左右。'},
  {'seq': 11, 'speaker': 'AI', 'text': '很好，追问一下：跨端架构里状态管理选型是怎么考虑的？'},
  {'seq': 12, 'speaker': 'CAND', 'text': '核心页面用 Riverpod，简单页面保持 setState，避免过度设计。'},
  {'seq': 13, 'speaker': 'HR', 'text': '那组件库的双端一致性是怎么保证的？'},
  {'seq': 14, 'speaker': 'CAND', 'text': '我们沉淀了 30 多个业务组件，视觉走查用同一套 Golden Test 基线。'},
  {'seq': 15, 'speaker': 'AI', 'text': '如果线上出现大面积白屏，你的排查思路是什么？'},
];

/// AI 提词建议队列（UC-14 步骤 B2-B3：实时生成下一个最佳提问建议 + 评分要点）。
const List<Map<String, dynamic>> mockCopilotQueue = [
  {
    'id': 101,
    'dimension': '项目深度',
    'question': '追问：性能优化方案中，首屏耗时与 FPS 的取舍你是怎么平衡的？',
    'scoringPoints': [
      '是否区分启动/运行时两类指标（1 分）',
      '是否有量化前后对比数据（1 分）',
      '是否提及帧率稳定性的权衡（1 分）',
    ],
    'reference': '优秀回答需包含：指标口径定义、对比基线、取舍与兜底策略。',
  },
  {
    'id': 102,
    'dimension': '架构能力',
    'question': '追问：组件库的双端一致性治理中，遇到最难的一个兼容问题是什么？',
    'scoringPoints': [
      '是否给出具体平台差异案例（1 分）',
      '是否有统一抽象层的思路（1 分）',
    ],
    'reference': '优秀回答需包含：平台差异抽象、Golden Test 基线、发布节奏控制。',
  },
  {
    'id': 103,
    'dimension': '问题排查',
    'question': '追问：白屏问题排查中，你如何快速定位是引擎问题还是业务代码问题？',
    'scoringPoints': [
      '是否提到分层定位思路（1 分）',
      '是否提到线上监控/日志体系（1 分）',
    ],
    'reference': '优秀回答需包含：引擎与业务分层、埋点与日志、灰度与回滚预案。',
  },
];

/// 面试录制列表（UC-12 后置条件1：音视频录制与合规存档）。
const List<Map<String, dynamic>> mockRecordings = [
  {
    'sessionId': 8801,
    'candidateName': '陈思远',
    'positionName': '高级 Flutter 开发工程师',
    'date': '2026-10-08',
    'duration': '44 分钟',
    'size': '386 MB',
    'mode': 'AI+HR 协同',
  },
  {
    'sessionId': 8755,
    'candidateName': '王浩然',
    'positionName': '算法工程师（NLP）',
    'date': '2026-10-07',
    'duration': '45 分钟',
    'size': '412 MB',
    'mode': 'AI 面试',
  },
  {
    'sessionId': 8702,
    'candidateName': '孙铭泽',
    'positionName': 'Java 后端开发工程师',
    'date': '2026-10-06',
    'duration': '38 分钟',
    'size': '358 MB',
    'mode': 'AI 面试',
  },
];

/// 五维能力评分卡维度（UC-12 步骤5）。
const List<String> mockEvaluationDims = ['技术理论', '动手实践', '逻辑思维', '沟通表达', '文化匹配度'];

/// 待终审列表（UC-12 步骤7-8）。
/// isFinal: true=终面（通过后触发 Offer）；false=非终面（通过后级联下一轮，UC-15）
const List<Map<String, dynamic>> mockPendingReviews = [
  {
    'sessionId': 8801,
    'candidateName': '陈思远',
    'positionName': '高级 Flutter 开发工程师',
    'round': '终面',
    'isFinal': true,
    'totalScore': 91.2,
    'dims': {'技术理论': 93.0, '动手实践': 95.0, '逻辑思维': 90.0, '沟通表达': 88.0, '文化匹配度': 90.0},
    'comment': {
      'overview': '候选人整体表现优秀，技术功底扎实，项目经验与岗位画像高度匹配，沟通清晰有条理。',
      'strengths': ['跨端性能优化方法论成熟，量化意识强', '组件库治理经验丰富，具备平台化思维'],
      'improvements': ['对大规模团队协作场景的描述偏少', '白屏排查思路可进一步体系化'],
      'suggestion': '强烈推荐',
      'recordingUrl': 'https://meeting.example.com/playback/8801',
    },
    'status': 'pending',
  },
  {
    'sessionId': 8755,
    'candidateName': '王浩然',
    'positionName': '算法工程师（NLP）',
    'round': '一轮',
    'isFinal': false,
    'totalScore': 84.5,
    'dims': {'技术理论': 88.0, '动手实践': 78.0, '逻辑思维': 86.0, '沟通表达': 84.0, '文化匹配度': 85.0},
    'comment': {
      'overview': 'NLP 理论基础扎实，RAG 实践有真实落地经验，动手环节代码完成度中等。',
      'strengths': ['知识库 RAG 从 0 到 1 的完整经验', '对 embedding 效果评估有方法意识'],
      'improvements': ['工程化部署经验不足', '实操环节未完成单元测试覆盖'],
      'suggestion': '推荐',
      'recordingUrl': 'https://meeting.example.com/playback/8755',
    },
    'status': 'pending',
  },
  {
    'sessionId': 8702,
    'candidateName': '孙铭泽',
    'positionName': 'Java 后端开发工程师',
    'round': '二轮',
    'isFinal': false,
    'totalScore': 86.8,
    'dims': {'技术理论': 89.0, '动手实践': 82.0, '逻辑思维': 87.0, '沟通表达': 85.0, '文化匹配度': 88.0},
    'comment': {
      'overview': '后端工程经验丰富，分布式事务理解到位，沟通中能主动对齐业务目标。',
      'strengths': ['高并发场景实战经验充分', '业务理解能力强，方案讲解清晰'],
      'improvements': ['对云原生生态了解一般'],
      'suggestion': '推荐',
      'recordingUrl': 'https://meeting.example.com/playback/8702',
    },
    'status': 'pending',
  },
];

/// Offer 列表（UC-12 步骤9 终面分支）。
/// status: sent=已发送 / accepted=已接受 / rejected=已拒绝
const List<Map<String, dynamic>> mockOffers = [
  {
    'offerId': 901,
    'candidateName': '林晓雨',
    'positionName': 'Java 后端开发工程师',
    'salary': '25-35K·14薪',
    'onboardDate': '2026-11-03',
    'status': 'sent',
    'sentAt': '2026-10-07 15:20',
  },
  {
    'offerId': 902,
    'candidateName': '周雨桐',
    'positionName': '高级 Flutter 开发工程师',
    'salary': '30-40K·14薪',
    'onboardDate': '2026-11-10',
    'status': 'accepted',
    'sentAt': '2026-10-05 10:12',
  },
  {
    'offerId': 903,
    'candidateName': '郑凯文',
    'positionName': 'UI 设计师',
    'salary': '15-20K·13薪',
    'onboardDate': '2026-11-17',
    'status': 'rejected',
    'sentAt': '2026-10-04 16:45',
  },
];
