import 'package:enterprise_recruiter/api/enterprise_memory_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnterpriseMemory', () {
    test('解析开关、revision 与记忆条目', () {
      final memory = EnterpriseMemory.fromJson({
        'enabled': true,
        'revision': 3,
        'items': [
          {'memoryKey': 'jd_style', 'value': 'JD 保持简洁', 'updatedAt': '2026-11-23T10:00:00'},
          {'memoryKey': 'interview_style', 'value': '一轮技术面', 'updatedAt': null},
        ],
      });
      expect(memory.enabled, isTrue);
      expect(memory.revision, 3);
      expect(memory.items, hasLength(2));
      expect(memory.items.first.key, 'jd_style');
      expect(memory.items.first.label, 'JD 风格');
      expect(memory.items.first.updatedAt, isNotNull);
      expect(memory.items.last.label, '面试风格');
    });

    test('兼容空列表、字符串 revision 与未知 key', () {
      final memory = EnterpriseMemory.fromJson({
        'enabled': false,
        'revision': '7',
        'items': [
          {'memoryKey': 'custom_key', 'value': '自定义偏好'},
        ],
      });
      expect(memory.enabled, isFalse);
      expect(memory.revision, 7);
      expect(memory.items.single.label, '其他');
    });

    test('空响应不会抛异常', () {
      final memory = EnterpriseMemory.fromJson(const {});
      expect(memory.enabled, isFalse);
      expect(memory.revision, 0);
      expect(memory.items, isEmpty);
    });
  });
}
