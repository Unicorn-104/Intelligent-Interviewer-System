/// 企业 APP - 模块六（反馈与通知）：消息中心（IM + 公告）接口。
///
/// 依据《业务功能分析》UC-16 及全流程通用沟通能力。
///
/// P7 联调状态：已对接真实后端接口（ImController /system/im
/// + SysNoticeController /system/notice）
/// 请求统一走 lib/core/network/enterprise_api_client.dart。
library;

import '../../core/network/enterprise_api_client.dart';

/// IM：会话列表。
/// 已对接：GET /system/im/sessions
Future<List<Map<String, dynamic>>> listImSessions() async {
  final response = await EnterpriseApiClient().get('/system/im/sessions');
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// IM：会话消息记录。
/// 已对接：GET /system/im/sessions/{sessionId}/messages
Future<List<Map<String, dynamic>>> listImMessages(int sessionId) async {
  final response = await EnterpriseApiClient().get(
    '/system/im/sessions/$sessionId/messages',
  );
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// IM：发送消息。
/// 已对接：POST /system/im/messages
Future<void> sendImMessage(Map<String, Object?> body) async {
  await EnterpriseApiClient().post('/system/im/messages', body: body);
}

/// IM：会话标记已读。
/// 已对接：PUT /system/im/sessions/{sessionId}/read
Future<void> markImSessionRead(int sessionId) async {
  await EnterpriseApiClient().put('/system/im/sessions/$sessionId/read');
}

/// IM：全部标记已读。
/// 已对接：PUT /system/im/read-all
Future<void> markAllImRead() async {
  await EnterpriseApiClient().put('/system/im/read-all');
}

/// IM：未读消息数。
/// 已对接：GET /system/im/unread-count
/// 容错：无数据时返回 0。
Future<int> getImUnreadCount() async {
  final response = await EnterpriseApiClient().get('/system/im/unread-count');
  return int.tryParse('${response['count']}') ??
      int.tryParse('${response['data']}') ??
      0;
}

/// IM：快捷回复列表。
/// 已对接：GET /system/im/quick-replies
Future<List<Map<String, dynamic>>> listQuickReplies() async {
  final response = await EnterpriseApiClient().get('/system/im/quick-replies');
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// IM：保存快捷回复。
/// 已对接：POST /system/im/quick-replies
Future<void> saveQuickReply(Map<String, Object?> body) async {
  await EnterpriseApiClient().post('/system/im/quick-replies', body: body);
}

/// IM：删除快捷回复。
/// 已对接：DELETE /system/im/quick-replies/{id}
Future<void> deleteQuickReply(int id) async {
  await EnterpriseApiClient().delete('/system/im/quick-replies/$id');
}

/// 公告：首页顶部公告（含未读数）。
/// 已对接：GET /system/notice/listTop
Future<Map<String, dynamic>> listTopNotices() async {
  final response = await EnterpriseApiClient().get('/system/notice/listTop');
  return {
    'data':
        (response['data'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item as Map))
            .toList() ??
        const <Map<String, dynamic>>[],
    'unreadCount': int.tryParse('${response['unreadCount']}') ?? 0,
  };
}

/// 公告：标记已读（noticeId 以查询参数传递，与后端无注解参数绑定一致）。
/// 已对接：POST /system/notice/markRead?noticeId=
Future<void> markNoticeRead(int noticeId) async {
  await EnterpriseApiClient().post(
    '/system/notice/markRead?noticeId=$noticeId',
  );
}
