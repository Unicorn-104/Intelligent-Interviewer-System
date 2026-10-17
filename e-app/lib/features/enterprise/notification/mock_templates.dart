/// 模块六：反馈与通知 - 通知模板本地模拟数据（Mock Data）。
///
/// 依据《业务功能分析》UC-16（全流程状态通知与模板化管理）E1：
/// HR 可新增/编辑通知模板，支持多语言版本管理；模板场景覆盖
/// "简历投递成功/初筛通过/初筛淘汰/面试邀约/面试提醒/评估完成"等全流程节点。
///
/// TODO: P7阶段替换为真实接口（lib/api/notification_api.dart 的
/// listNotificationTemplates / addNotificationTemplate 等）。
library;

/// 通知模板列表模拟数据。字段说明：
/// - scene：通知场景（sceneType）
/// - channels：发送渠道（邮件/短信/APP 推送等）
/// - languages：已维护的语言版本
/// - enabled：启用状态
/// - placeholders：模板支持的占位符（如 {{candidateName}}、{{jobTitle}}）
const List<Map<String, dynamic>> mockNotificationTemplates = [
  {
    'tplId': 301,
    'name': '简历投递成功确认',
    'scene': '简历投递成功',
    'channels': ['邮件'],
    'languages': ['中文', '英文'],
    'enabled': true,
    'updatedAt': '2026-10-06 10:20',
    'placeholders': ['{{candidateName}}', '{{jobTitle}}'],
  },
  {
    'tplId': 302,
    'name': '初筛通过通知',
    'scene': '初筛通过',
    'channels': ['邮件', '短信'],
    'languages': ['中文', '英文'],
    'enabled': true,
    'updatedAt': '2026-10-06 10:22',
    'placeholders': ['{{candidateName}}', '{{jobTitle}}', '{{nextStep}}'],
  },
  {
    'tplId': 303,
    'name': '初筛淘汰告知',
    'scene': '初筛淘汰',
    'channels': ['邮件'],
    'languages': ['中文'],
    'enabled': true,
    'updatedAt': '2026-10-06 10:24',
    'placeholders': ['{{candidateName}}', '{{jobTitle}}'],
  },
  {
    'tplId': 304,
    'name': '面试邀约通知',
    'scene': '面试邀约',
    'channels': ['邮件', '短信', 'APP 推送'],
    'languages': ['中文', '英文'],
    'enabled': true,
    'updatedAt': '2026-10-07 16:40',
    'placeholders': ['{{candidateName}}', '{{jobTitle}}', '{{interviewTime}}', '{{meetingLink}}'],
  },
  {
    'tplId': 305,
    'name': '面试前 1 小时提醒',
    'scene': '面试提醒',
    'channels': ['短信', 'APP 推送'],
    'languages': ['中文', '英文'],
    'enabled': true,
    'updatedAt': '2026-10-07 16:42',
    'placeholders': ['{{candidateName}}', '{{interviewTime}}', '{{meetingLink}}'],
  },
  {
    'tplId': 306,
    'name': '评估完成通知',
    'scene': '评估完成',
    'channels': ['邮件'],
    'languages': ['中文'],
    'enabled': false,
    'updatedAt': '2026-10-05 09:15',
    'placeholders': ['{{candidateName}}', '{{jobTitle}}'],
  },
];
