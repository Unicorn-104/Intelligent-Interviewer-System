import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/app.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/features/auth/data/auth_api.dart';
import 'package:intelligent_interviewer/features/auth/data/token_store.dart';
import 'package:intelligent_interviewer/features/auth/presentation/auth_controller.dart';

class _MemoryTokenStore implements TokenStore {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

void main() {
  testWidgets('shows the password login experience by default', (tester) async {
    final client = ApiClient();
    final controller = AuthController(
      api: AuthApi(client),
      tokenStore: _MemoryTokenStore(),
      autoLoadCaptcha: false,
    );

    await tester.pumpWidget(
      IntelligentInterviewerApp(authController: controller),
    );
    await tester.pumpAndSettle();

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('密码登录'), findsOneWidget);
    expect(find.text('手机号 / 登录账号'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    client.close();
  });
}
