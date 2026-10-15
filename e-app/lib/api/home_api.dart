import '../core/network/enterprise_api_client.dart';

/// Homepage-only wrappers; existing overview and profile callers stay unchanged.
Future<Map<String, dynamic>> getOverview() async {
  final response = await EnterpriseApiClient().get(
    '/system/dashboard/overview',
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

Future<Map<String, dynamic>> getCurrentUserInfo() async {
  final response = await EnterpriseApiClient().get('/getInfo');
  return Map<String, dynamic>.from(response['user'] as Map? ?? const {});
}

Future<int> getNoticeUnreadCount() async {
  final response = await EnterpriseApiClient().get(
    '/system/notice/unreadCount',
  );
  final value = response['data'];
  if (value == null) return 0;
  final count = int.tryParse('$value');
  if (count == null || count < 0) {
    throw const FormatException('公告未读数格式不正确');
  }
  return count;
}
