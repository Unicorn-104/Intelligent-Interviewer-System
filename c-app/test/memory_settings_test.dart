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
  testWidgets(
    'memory switch persists server state and retains value after rejected save',
    (tester) async {
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
      final tile = find.widgetWithText(SwitchListTile, '记忆');
      await tester.scrollUntilVisible(tile, 350);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(api.enabled, isFalse);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      api.reject = true;
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect(find.text('请先停止正在生成的回答，再修改记忆'), findsOneWidget);
      expect(find.text('长期记忆'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
