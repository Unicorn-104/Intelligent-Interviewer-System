import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/ai/data/ai_api.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/screens/settings_screen.dart';

class _MemoryApi extends AiApi {
  _MemoryApi(super.client);
  bool enabled = true;
  bool reject = false;
  int revision = 4;
  bool rejectDelete = false;
  final List<Map<String, dynamic>> items = [
    {'id': 'synthetic-memory', 'content': '我主要使用 Java 开发', 'revision': 1},
  ];
  @override
  Future<List<Map<String, dynamic>>> longTermMemories(String token) async =>
      List.unmodifiable(items);
  @override
  Future<void> deleteLongTermMemory(String token, String id) async {
    expect(token, 'synthetic');
    if (rejectDelete) throw const ApiException('记忆删除失败，请重试');
    items.removeWhere((row) => row['id'] == id);
  }

  @override
  Future<Map<String, dynamic>> memorySettings(String token) async => {
    'enabled': enabled,
    'revision': revision,
  };
  @override
  Future<Map<String, dynamic>> setMemoryEnabled(
    String token,
    bool next,
    int version,
  ) async {
    expect(token, 'synthetic');
    expect(version, revision);
    if (reject) throw const ApiException('请先停止正在生成的回答，再修改记忆');
    enabled = next;
    revision++;
    return {'enabled': enabled, 'revision': revision};
  }
}

void main() {
  testWidgets('memory arrow opens full screen with right switch and deletion', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = ApiClient();
    addTearDown(client.close);
    final api = _MemoryApi(client);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          session: const AuthSession(
            token: 'synthetic',
            userId: 17,
            userName: 'test',
            nickName: 'test',
          ),
          onLogout: () async {},
          memoryApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.text('记忆');
    await tester.scrollUntilVisible(tile, 350);
    expect(find.widgetWithText(SwitchListTile, '记忆'), findsNothing);
    final entry = find.ancestor(of: tile, matching: find.byType(ListTile));
    expect(
      find.descendant(of: entry, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    final toggle = find.byType(Switch).last;
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(
      tester.getCenter(toggle).dx,
      greaterThan(tester.getCenter(find.text('记忆').last).dx),
    );
    expect(find.text('我主要使用 Java 开发'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(api.enabled, isFalse);
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(find.text('我主要使用 Java 开发'), findsOneWidget);
    api.reject = true;
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(find.text('请先停止正在生成的回答，再修改记忆'), findsOneWidget);
    await tester.tap(find.byTooltip('删除记忆'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.items, hasLength(1));
    api.rejectDelete = true;
    await tester.tap(find.byTooltip('删除记忆'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('记忆删除失败，请重试'), findsOneWidget);
    expect(find.text('我主要使用 Java 开发'), findsOneWidget);
    api.rejectDelete = false;
    await tester.tap(find.byTooltip('删除记忆'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(api.items, isEmpty);
    expect(find.text('暂无已存储的记忆'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
