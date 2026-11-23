import '../core/network/enterprise_api_client.dart';

/// 企业端长期记忆：服务端按「企业 + 招聘者」隔离，页面只负责展示与按 revision 修改。
const Map<String, String> enterpriseMemoryKeyLabels = {
  'recruiting_focus': '招聘重点',
  'target_profile': '目标人选',
  'salary_policy': '薪资策略',
  'process_preference': '流程偏好',
  'interview_style': '面试风格',
  'jd_style': 'JD 风格',
  'other': '其他',
};

class EnterpriseMemoryItem {
  final String key;
  final String value;
  final DateTime? updatedAt;

  const EnterpriseMemoryItem({
    required this.key,
    required this.value,
    this.updatedAt,
  });

  factory EnterpriseMemoryItem.fromJson(Map<String, dynamic> json) =>
      EnterpriseMemoryItem(
        key: json['memoryKey']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );

  String get label => enterpriseMemoryKeyLabels[key] ?? '其他';
}

class EnterpriseMemory {
  final bool enabled;
  final int revision;
  final List<EnterpriseMemoryItem> items;

  const EnterpriseMemory({
    required this.enabled,
    required this.revision,
    required this.items,
  });

  factory EnterpriseMemory.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <EnterpriseMemoryItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(
            EnterpriseMemoryItem.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return EnterpriseMemory(
      enabled: json['enabled'] == true,
      revision: _revision(json['revision']),
      items: items,
    );
  }

  static int _revision(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
}

Future<EnterpriseMemory> getEnterpriseMemory() async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/assistant/memory',
  );
  final data = response['data'];
  return EnterpriseMemory.fromJson(
    data is Map ? Map<String, dynamic>.from(data) : const {},
  );
}

Future<EnterpriseMemory> changeEnterpriseMemory({
  required String action,
  required int revision,
  String? key,
  String? value,
  bool? enabled,
  int? sessionId,
}) async {
  final body = <String, Object?>{'action': action, 'revision': revision};
  if (key != null) body['key'] = key;
  if (value != null) body['value'] = value;
  if (enabled != null) body['enabled'] = enabled;
  if (sessionId != null) body['sessionId'] = sessionId;
  final response = await EnterpriseApiClient().post(
    '/enterprise/assistant/memory',
    body: body,
  );
  final data = response['data'];
  return EnterpriseMemory.fromJson(
    data is Map ? Map<String, dynamic>.from(data) : const {},
  );
}
