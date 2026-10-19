/// 模块六：反馈与通知 - 本地模拟数据（Mock Data）。
///
/// 依据《业务功能分析》UC-16（全流程状态通知与模板化管理）E2、
/// UC-17（候选人体验调研与数据分析）、UC-18（AI 助手 7×24 自动应答）：
/// - 通知发送日志（渠道/状态/送达率/打开率/点击率）
/// - 满意度调研（流程便捷度/面试官专业度/系统易用性评分 + 文字反馈）
/// - 消息中心（IM 会话/快捷回复）
/// - 公告（置顶 listTop + 已读/未读）
///
/// TODO: P7阶段替换为真实接口（lib/api/notification_api.dart、
/// lib/api/survey_api.dart、lib/api/message_api.dart 的全部函数）。
library;

/// 通知发送日志（UC-16 E2：按候选人/场景/渠道检索，记录送达状态）。
/// status: success=送达 / failed=失败（降级）
const List<Map<String, dynamic>> mockNotificationLogs = [
  {'logId': 1, 'candidateName': '陈思远', 'scene': '面试邀约', 'channel': '邮件', 'status': 'success', 'sentAt': '2026-10-09 09:02', 'opened': true, 'clicked': true},
  {'logId': 2, 'candidateName': '陈思远', 'scene': '面试提醒', 'channel': '短信', 'status': 'success', 'sentAt': '2026-10-09 08:05', 'opened': true, 'clicked': true},
  {'logId': 3, 'candidateName': '王浩然', 'scene': '面试邀约', 'channel': '邮件', 'status': 'success', 'sentAt': '2026-10-08 18:40', 'opened': true, 'clicked': false},
  {'logId': 4, 'candidateName': '林晓雨', 'scene': '评估完成', 'channel': '邮件', 'status': 'failed', 'sentAt': '2026-10-08 17:15', 'opened': false, 'clicked': false},
  {'logId': 5, 'candidateName': '孙铭泽', 'scene': '简历投递成功', 'channel': '邮件', 'status': 'success', 'sentAt': '2026-10-08 11:30', 'opened': true, 'clicked': false},
  {'logId': 6, 'candidateName': '周雨桐', 'scene': '面试提醒', 'channel': 'APP 推送', 'status': 'success', 'sentAt': '2026-10-08 09:00', 'opened': true, 'clicked': true},
  {'logId': 7, 'candidateName': '郑凯文', 'scene': '初筛淘汰', 'channel': '邮件', 'status': 'success', 'sentAt': '2026-10-07 16:20', 'opened': false, 'clicked': false},
];

/// 送达率/打开率/点击率统计（UC-16 E2）。
const Map<String, dynamic> mockNotificationStats = {
  'totalSent': 1284,
  'deliveryRate': 96.4,
  'openRate': 71.8,
  'clickRate': 38.2,
};

/// 满意度调研结果汇总（UC-17：流程便捷度/面试官专业度/系统易用性 + 文字反馈）。
const Map<String, dynamic> mockSurveySummary = {
  'avgScore': 4.6,
  'responseCount': 87,
  'dims': [
    {'name': '流程便捷度', 'score': 4.8},
    {'name': '面试官专业度', 'score': 4.5},
    {'name': '系统易用性', 'score': 4.4},
  ],
  // 1-5 星评分分布（counts 下标 0 对应 1 星）
  'distribution': [2, 3, 8, 42, 32],
};

/// 文字反馈列表（UC-17 步骤：采集评分与文字反馈）。
const List<Map<String, dynamic>> mockSurveyFeedbacks = [
  {
    'candidateName': '陈思远',
    'positionName': '高级 Flutter 开发工程师',
    'rating': 5,
    'content': '面试流程很顺畅，AI 面试官的追问很有深度，能感受到被尊重。',
    'date': '2026-10-08',
  },
  {
    'candidateName': '王浩然',
    'positionName': '算法工程师（NLP）',
    'rating': 5,
    'content': '预约改期很方便，提醒也很及时，整体体验超出预期。',
    'date': '2026-10-08',
  },
  {
    'candidateName': '林晓雨',
    'positionName': 'Java 后端开发工程师',
    'rating': 4,
    'content': '面试官很专业，但设备检测阶段网络提示有些吓人，建议优化话术。',
    'date': '2026-10-07',
  },
  {
    'candidateName': '郑凯文',
    'positionName': 'UI 设计师',
    'rating': 3,
    'content': '通知邮件里的时间时区显示有歧义，差点错过面试。',
    'date': '2026-10-06',
  },
];

/// IM 会话列表（消息中心）。
const List<Map<String, dynamic>> mockImSessions = [
  {'sessionId': 1, 'name': '陈思远', 'role': '候选人', 'lastMessage': '好的，明天下午 4 点半准时参加面试，谢谢！', 'time': '10:02', 'unread': 2},
  {'sessionId': 2, 'name': '王浩然', 'role': '候选人', 'lastMessage': '请问面试主要考察哪些方向？', 'time': '昨天', 'unread': 0},
  {'sessionId': 3, 'name': '李娜', 'role': '面试官', 'lastMessage': '这场面试我来协同，评分卡晚点同步给你', 'time': '昨天', 'unread': 1},
  {'sessionId': 4, 'name': '孙铭泽', 'role': '候选人', 'lastMessage': '收到，感谢通知！', 'time': '周二', 'unread': 0},
];

/// 某会话的历史消息（from: me=我方 / them=对方）。
const List<Map<String, dynamic>> mockImMessages = [
  {'id': 1, 'from': 'them', 'text': '您好，收到面试邀约了，想确认一下面试形式是线上视频面试吗？', 'time': '09:58'},
  {'id': 2, 'from': 'me', 'text': '是的，通过专属会议链接进入，面试前 30 分钟系统会再次提醒。', 'time': '09:59'},
  {'id': 3, 'from': 'them', 'text': '好的，明天下午 4 点半准时参加面试，谢谢！', 'time': '10:02'},
];

/// 快捷回复（IM 快速回复，可复用）。
const List<String> mockQuickReplies = [
  '好的，收到',
  '面试安排已确认，请准时参加',
  '如有变动请提前告知',
  '感谢您的关注',
];

/// 公告列表（pinned=true 为 listTop 置顶公告）。
const List<Map<String, dynamic>> mockNotices = [
  {'noticeId': 1, 'title': '系统维护通知：本周六 02:00-04:00 升级', 'content': '为提升面试体验，系统将于本周六凌晨进行升级维护，期间预约与面试功能暂停使用。', 'pinned': true, 'read': false, 'publishTime': '2026-10-09 08:00'},
  {'noticeId': 2, 'title': '面试评分卡模板更新说明', 'content': '五维评分卡新增"文化匹配度"维度的评分要点指引，请各位面试官查阅。', 'pinned': true, 'read': true, 'publishTime': '2026-10-07 14:00'},
  {'noticeId': 3, 'title': 'AI 初筛功能灰度上线', 'content': 'AI 初筛与短名单功能已对企业开放，可在筛选任务中发起体验。', 'pinned': false, 'read': false, 'publishTime': '2026-10-06 10:30'},
  {'noticeId': 4, 'title': '关于候选人隐私数据合规的提醒', 'content': '候选人简历与面试数据仅限招聘流程使用，请勿外传。', 'pinned': false, 'read': true, 'publishTime': '2026-10-05 09:00'},
  {'noticeId': 5, 'title': '国庆假期值班安排', 'content': '假期期间消息中心值班回复，紧急事项请联系管理员。', 'pinned': false, 'read': true, 'publishTime': '2026-09-30 17:00'},
];
