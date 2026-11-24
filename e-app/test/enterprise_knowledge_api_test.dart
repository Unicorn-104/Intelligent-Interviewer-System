import 'package:enterprise_recruiter/api/enterprise_knowledge_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnterpriseKnowledge', () {
    test('解析文档列表字段', () {
      final document = EnterpriseKnowledgeDocument.fromJson({
        'id': 'document-1',
        'name': '技术岗面试规范',
        'contentLength': '1280',
        'chunkCount': 2,
        'updatedAt': '2026-11-23T10:00:00',
      });
      expect(document.id, 'document-1');
      expect(document.name, '技术岗面试规范');
      expect(document.contentLength, 1280);
      expect(document.chunkCount, 2);
      expect(document.updatedAt, isNotNull);
    });

    test('兼容空值并提供默认文案', () {
      final document = EnterpriseKnowledgeDocument.fromJson(const {});
      expect(document.id, isEmpty);
      expect(document.name, '未命名文档');
      expect(document.contentLength, 0);
      expect(document.chunkCount, 0);
      expect(document.updatedAt, isNull);
    });

    test('解析知识检索引用', () {
      final result = EnterpriseKnowledgeResult.fromJson({
        'citation': 'K1',
        'fileName': '招聘流程',
        'content': '初试通过后安排复试。',
      });
      expect(result.citation, 'K1');
      expect(result.fileName, '招聘流程');
      expect(result.content, contains('复试'));
    });
  });
}
