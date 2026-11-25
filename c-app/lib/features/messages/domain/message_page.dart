import '../../../core/network/api_exception.dart';
import 'app_message.dart';

String messageCategoryKey(AppMessageCategory category) => switch (category) {
  AppMessageCategory.hr => 'HR',
  AppMessageCategory.company => 'COMPANY',
  AppMessageCategory.system => 'SYSTEM',
};

class MessagePage {
  const MessagePage({
    required this.items,
    required this.hasMore,
    this.unreadCounts = const {},
  });

  final List<AppMessage> items;
  final bool hasMore;
  final Map<String, int> unreadCounts;

  factory MessagePage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map || data['items'] is! List || data['hasMore'] is! bool) {
      throw const ApiException('消息记录格式不正确，请重试');
    }
    final items = <AppMessage>[];
    for (final row in data['items'] as List) {
      if (row is! Map) throw const ApiException('消息记录格式不正确，请重试');
      final item = AppMessage.fromJson(Map<String, dynamic>.from(row));
      if (item.sourceId <= 0 ||
          !['HR', 'COMPANY', 'INTERVIEW', 'SYSTEM'].contains(item.threadType) ||
          item.threadId == null ||
          (item.threadType == 'SYSTEM'
              ? item.threadId != 0
              : item.threadId! <= 0)) {
        throw const ApiException('消息分组格式不正确，请重试');
      }
      items.add(item);
    }
    final counts = <String, int>{};
    final rawCounts = data['unreadCounts'];
    if (rawCounts is Map) {
      for (final key in ['HR', 'COMPANY', 'SYSTEM']) {
        final count = int.tryParse('${rawCounts[key]}');
        if (count == null || count < 0) {
          throw const ApiException('未读消息数量格式不正确，请重试');
        }
        counts[key] = count;
      }
    }
    if (items.isEmpty && data['hasMore'] == true) {
      throw const ApiException('消息分页格式不正确，请重试');
    }
    return MessagePage(
      items: items,
      hasMore: data['hasMore'] as bool,
      unreadCounts: counts,
    );
  }
}
