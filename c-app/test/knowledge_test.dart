import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/ai/data/knowledge_api.dart';
import 'package:intelligent_interviewer/features/ai/domain/ai_models.dart';
import 'package:intelligent_interviewer/features/ai/presentation/knowledge_screen.dart';

class FakeKnowledgeApi extends KnowledgeApi {
  FakeKnowledgeApi() : super(ApiClient());
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> documents(String token) async {
    if (fail) throw const ApiException('资料加载失败');
    return [
      {
        'id': 'doc1',
        'name': '项目说明.md',
        'extension': 'md',
        'status': 'READY',
        'category': 'FILE',
        'source': 'UPLOAD',
        'createdAt': '2026-11-09T12:00:00Z',
      },
    ];
  }
}

void main() {
  testWidgets('knowledge library fits narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: KnowledgeScreen(token: 'synthetic', api: FakeKnowledgeApi()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('我的上传'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'fixed categories manage uploads without manual knowledge selection',
    (tester) async {
      final api = FakeKnowledgeApi();
      await tester.pumpWidget(
        MaterialApp(
          home: KnowledgeScreen(token: 'synthetic', api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('知识空间'), findsOneWidget);
      expect(find.text('已生成'), findsOneWidget);
      expect(find.text('创作'), findsOneWidget);
      expect(find.text('音频'), findsOneWidget);
      await tester.tap(find.text('我的上传'));
      await tester.pumpAndSettle();
      expect(find.text('项目说明.md'), findsOneWidget);
      expect(find.text('上传资料'), findsOneWidget);
      expect(find.text('不使用知识库'), findsNothing);
      expect(find.text('选择用于对话的知识库'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await tester.tap(find.text('文件'));
      await tester.pumpAndSettle();
      expect(find.text('项目说明.md'), findsOneWidget);
      await tester.tap(find.text('音频'));
      await tester.pumpAndSettle();
      expect(find.text('项目说明.md'), findsNothing);
      expect(find.text('暂无音频'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('library failure remains an error with retry and no fake files', (
    tester,
  ) async {
    final api = FakeKnowledgeApi()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeScreen(token: 'synthetic', api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('资料加载失败'), findsOneWidget);
    expect(find.text('项目说明.md'), findsNothing);
    api.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的上传'));
    await tester.pumpAndSettle();
    expect(find.text('项目说明.md'), findsOneWidget);
  });
  test('history retains server-provided citation metadata', () {
    final message = AiMessage.fromJson({
      'role': 'assistant',
      'content': '使用快照 [K1]',
      'sources': [
        {
          'citation': 'K1',
          'fileName': 'notes.pdf',
          'page': 2,
          'content': '合成证据',
        },
      ],
    });
    expect(message.sources.single['page'], 2);
    expect(aiRunError('KNOWLEDGE_UNAVAILABLE'), contains('资料检索'));
  });
}
