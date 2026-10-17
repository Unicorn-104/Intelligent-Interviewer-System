/// 模块三：智能预约调度 - 本地模拟数据（Mock Data）。
///
/// 依据《业务功能分析》UC-07（候选人自主预约与智能排期）、
/// UC-08（面试官日历同步与冲突检测）、UC-09（候选人自助改期）：
/// - 面试记录含时间、会议链接、状态（已预约/待面试等）
/// - 面试官日历忙闲时段（冲突检测）
/// - 候选人自助改期记录（原时段释放回退可用池）
///
/// TODO: P7阶段替换为真实接口（lib/api/schedule_api.dart 的全部函数）。
library;

/// 面试日程模拟数据。
/// status: upcoming=已预约（未来）/ today=待面试（今天）/ done=已完成 / rescheduled=已改期
const List<Map<String, dynamic>> mockInterviews = [
  {
    'aptId': 601,
    'candidateName': '王浩然',
    'positionName': '算法工程师（NLP）',
    'interviewerName': '张伟',
    'date': '2026-10-09',
    'time': '14:00',
    'duration': 45,
    'mode': 'AI 面试',
    'meetingLink': 'https://meeting.example.com/982301',
    'status': 'today',
    'round': '一轮',
  },
  {
    'aptId': 602,
    'candidateName': '陈思远',
    'positionName': '高级 Flutter 开发工程师',
    'interviewerName': '李娜',
    'date': '2026-10-09',
    'time': '16:30',
    'duration': 45,
    'mode': 'AI+HR 协同',
    'meetingLink': 'https://meeting.example.com/982445',
    'status': 'today',
    'round': '一轮',
  },
  {
    'aptId': 603,
    'candidateName': '孙铭泽',
    'positionName': 'Java 后端开发工程师',
    'interviewerName': '张伟',
    'date': '2026-10-10',
    'time': '10:00',
    'duration': 60,
    'mode': 'AI 面试',
    'meetingLink': 'https://meeting.example.com/982712',
    'status': 'upcoming',
    'round': '一轮',
  },
  {
    'aptId': 604,
    'candidateName': '林晓雨',
    'positionName': 'Java 后端开发工程师',
    'interviewerName': '王强',
    'date': '2026-10-11',
    'time': '15:00',
    'duration': 45,
    'mode': 'AI+HR 协同',
    'meetingLink': 'https://meeting.example.com/982910',
    'status': 'upcoming',
    'round': '二轮',
  },
  {
    'aptId': 605,
    'candidateName': '周雨桐',
    'positionName': '高级 Flutter 开发工程师',
    'interviewerName': '李娜',
    'date': '2026-10-11',
    'time': '09:30',
    'duration': 45,
    'mode': 'AI 面试',
    'meetingLink': 'https://meeting.example.com/983021',
    'status': 'rescheduled',
    'round': '一轮',
  },
];

/// 面试官列表及各自日历忙闲时段（UC-08 冲突检测用）。
/// busy 为 "HH:mm-HH:mm" 时间段数组，occupied 为已被面试占用的时段。
const List<Map<String, dynamic>> mockInterviewers = [
  {
    'interviewerId': 1,
    'name': '张伟',
    'title': '技术总监',
    'busy': ['09:00-10:30', '13:30-14:00', '17:00-18:00'],
    'occupied': ['14:00-14:45', '16:00-17:00'],
  },
  {
    'interviewerId': 2,
    'name': '李娜',
    'title': '高级工程师',
    'busy': ['10:00-12:00', '15:00-15:30'],
    'occupied': ['16:30-17:15'],
  },
];

/// 候选人自助改期记录（UC-09）：原时段自动释放并回退可用池。
/// status: pending=待审批 / approved=已通过 / rejected=已驳回
const List<Map<String, dynamic>> mockReschedules = [
  {
    'reqId': 701,
    'candidateName': '周雨桐',
    'positionName': '高级 Flutter 开发工程师',
    'interviewerName': '李娜',
    'originalSlot': '2026-10-10 09:30',
    'newSlot': '2026-10-11 09:30',
    'reason': '临时有工作安排冲突，希望改到周六上午',
    'status': 'pending',
    'requestedAt': '2026-10-09 08:15',
  },
  {
    'reqId': 702,
    'candidateName': '郑凯文',
    'positionName': 'UI 设计师',
    'interviewerName': '王强',
    'originalSlot': '2026-10-09 11:00',
    'newSlot': '2026-10-09 15:00',
    'reason': '网络环境不佳，申请调整到下午',
    'status': 'approved',
    'requestedAt': '2026-10-08 20:02',
  },
  {
    'reqId': 703,
    'candidateName': '吴子昂',
    'positionName': '高级 Flutter 开发工程师',
    'interviewerName': '张伟',
    'originalSlot': '2026-10-10 14:00',
    'newSlot': '2026-10-10 17:30',
    'reason': '期望薪资沟通会冲突，申请顺延',
    'status': 'rejected',
    'requestedAt': '2026-10-08 18:40',
  },
];
