import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/features/ai/data/ai_api.dart';
import 'package:intelligent_interviewer/features/ai/domain/ai_models.dart';
import 'package:intelligent_interviewer/features/ai/presentation/ai_sessions_panel.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

class HistoryApi extends AiApi {
  HistoryApi() : super(ApiClient());
  String? renamed;
  final pinned = <String, bool>{};
  final deleted = <String>[];
  @override
  Future<Map<String, dynamic>> sessions(String token, {String? before}) async {
    final now = DateTime.now();
    return {
      'items': [
        if (before == null) ...[
          {
            'id': 'today',
            'title': renamed ?? '当前对话',
            'pinned': pinned['today'] ?? false,
            'createdAt': now.toUtc().toIso8601String(),
          },
          {
            'id': 'week',
            'title': '上周的问题',
            'createdAt': DateTime(
              now.year,
              now.month,
              now.day - 2,
            ).toUtc().toIso8601String(),
          },
        ] else
          {
            'id': 'old',
            'title': '较早的问题',
            'createdAt': DateTime(
              now.year,
              now.month,
              now.day - 10,
            ).toUtc().toIso8601String(),
          },
      ],
      'nextCursor': before == null ? 'week' : null,
    };
  }

  @override
  Future<Map<String, dynamic>> renameSession(
    String token,
    String id,
    String title,
  ) async {
    renamed = title;
    return {'id': id, 'title': title};
  }

  @override
  Future<Map<String, dynamic>> pinSession(
    String token,
    String id,
    bool value,
  ) async {
    pinned[id] = value;
    return {'id': id, 'pinned': value};
  }

  @override
  Future<void> deleteSessions(String token, List<String> ids) async {
    deleted.addAll(ids);
  }
}

void main() {
  testWidgets(
    'history groups pages by local creation day and resumes selected conversation',
    (tester) async {
      final api = HistoryApi();
      addTearDown(api.client.close);
      AiSession? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AiSessionsPanel(
              session: const AuthSession(
                token: 'synthetic',
                userId: 17,
                userName: 'test',
                nickName: 'test',
              ),
              api: api,
              selectedId: 'today',
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('对话历史'), findsOneWidget);
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('最近一周'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, '当前对话')).selected,
        isTrue,
      );
      expect(find.byTooltip('会话操作'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, '上周的问题'))
            .trailing,
        isNull,
      );
      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      expect(find.text('更早'), findsOneWidget);
      expect(find.text('较早的问题'), findsOneWidget);
      await tester.tap(find.text('上周的问题'));
      expect(selected?.id, 'week');
    },
  );

  testWidgets(
    'only selected conversation shows actions and batch delete persists',
    (tester) async {
      final api = HistoryApi();
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AiSessionsPanel(
              session: const AuthSession(
                token: 'synthetic',
                userId: 17,
                userName: 'test',
                nickName: 'test',
              ),
              api: api,
              selectedId: 'today',
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('会话操作'), findsOneWidget);
      await tester.tap(find.byTooltip('会话操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('批量管理'));
      await tester.pumpAndSettle();
      expect(find.text('选择对话'), findsOneWidget);
      await tester.tap(find.text('上周的问题'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除已选 (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(api.deleted, containsAll(['today', 'week']));
      expect(find.text('当前对话'), findsNothing);
    },
  );

  testWidgets(
    'history menu renames through API and preserves group after refresh',
    (tester) async {
      final api = HistoryApi();
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AiSessionsPanel(
              session: const AuthSession(
                token: 'synthetic',
                userId: 17,
                userName: 'test',
                nickName: 'test',
              ),
              api: api,
              selectedId: 'today',
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('会话操作').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('修改标题'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '新的标题');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(api.renamed, '新的标题');
      expect(find.text('新的标题'), findsOneWidget);
      expect(find.text('今天'), findsOneWidget);
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
      await tester.pumpAndSettle();
      expect(find.text('新的标题'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pinned conversations use a separate section above date groups', (
    tester,
  ) async {
    final api = HistoryApi();
    addTearDown(api.client.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AiSessionsPanel(
            session: const AuthSession(
              token: 'synthetic',
              userId: 17,
              userName: 'test',
              nickName: 'test',
            ),
            api: api,
            selectedId: 'today',
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('会话操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();
    expect(api.pinned['today'], isTrue);
    expect(find.text('置顶'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    expect(find.text('今天'), findsNothing);
    expect(find.text('上周的问题'), findsOneWidget);
  });

  testWidgets('unsent new conversation appears once and is highlighted', (
    tester,
  ) async {
    final api = HistoryApi();
    addTearDown(api.client.close);
    AiSession? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiSessionsPanel(
            session: const AuthSession(
              token: 'synthetic',
              userId: 17,
              userName: 'test',
              nickName: 'test',
            ),
            api: api,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('新对话'), findsOneWidget);
    final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, '新对话'));
    expect(tile.selected, true);
    await tester.tap(find.text('新对话'));
    expect(selected?.id, AiSessionsPanel.draftId);
    expect(tester.takeException(), isNull);
  });
}
