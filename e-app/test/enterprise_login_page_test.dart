import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_client.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/login_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoginClient extends ApiClient {
  final calls = <({String method, String path, Map<String, Object?>? body})>[];
  Completer<Map<String, dynamic>>? loginGate;
  Object? loginError;
  Object? sessionError;
  Object? captchaError;
  bool captchaEnabled = false;
  String captchaUuid = 'synthetic-captcha-1';
  String captchaImage =
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAADklEQVR4nGP4DwYMEAoAU7oL9ZisIGcAAAAASUVORK5CYII=';
  Completer<Map<String, dynamic>>? captchaGate;
  Map<String, dynamic>? captchaResponse;
  List<({String method, String path, Map<String, Object?>? body})>
  get authCalls => calls.where((call) => call.path != '/captchaImage').toList();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Map<String, Object?>? query,
  }) async {
    calls.add((method: 'GET', path: path, body: null));
    if (path == '/captchaImage') {
      if (captchaError != null) throw captchaError!;
      if (captchaGate != null) return captchaGate!.future;
      return captchaResponse ??
          {
            'code': 200,
            'captchaEnabled': captchaEnabled,
            if (captchaEnabled) 'uuid': captchaUuid,
            if (captchaEnabled) 'img': captchaImage,
          };
    }
    if (sessionError != null) throw sessionError!;
    return {'code': 200};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    calls.add((method: 'POST', path: path, body: body));
    if (path == '/logout') return {'code': 200};
    if (loginError != null) throw loginError!;
    if (loginGate != null) return loginGate!.future;
    return {'code': 200, 'token': 'synthetic-session'};
  }
}

Future<void> _settleLogin(WidgetTester tester) async {
  await tester.pump();
  // Image codecs complete on the engine's real event loop, outside fake time.
  for (var attempt = 0; attempt < 100; attempt++) {
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _mount(
  WidgetTester tester,
  _LoginClient client, {
  Size size = const Size(420, 900),
  double scale = 1,
  double keyboard = 0,
  Map<String, String> stored = const {},
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues(Map<String, String>.of(stored));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: LoginPage(
          client: client,
          authenticatedBuilder: (context, onLogout) => Scaffold(
            body: TextButton(
              onPressed: onLogout,
              child: const Text('合成工作台：退出'),
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await _settleLogin(tester);
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('enterprise-login-username')),
    '  synthetic-hr  ',
  );
  await tester.enterText(
    find.byKey(const ValueKey('enterprise-login-password')),
    'synthetic-password',
  );
}

Future<void> _submit(WidgetTester tester) async {
  final submit = find.byKey(const ValueKey('enterprise-login-submit'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pump();
}

void main() {
  late _LoginClient client;
  setUp(() => client = _LoginClient());
  tearDown(() => client.close());

  testWidgets('展示企业品牌与双模式入口，默认密码登录且遵循验证码关闭状态', (tester) async {
    await _mount(tester, client);
    expect(find.text('智能面试官'), findsOneWidget);
    expect(find.text('企业招聘服务'), findsOneWidget);
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('密码登录'), findsOneWidget);
    expect(find.text('验证码登录'), findsOneWidget);
    expect(client.calls.single.path, '/captchaImage');
    expect(
      find.byKey(const ValueKey('enterprise-login-captcha')),
      findsNothing,
    );
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(Card), findsOneWidget);
    expect(client.authCalls, isEmpty);
  });

  testWidgets('空表单保持原校验，不发送登录请求', (tester) async {
    await _mount(tester, client);
    await _submit(tester);
    await _settleLogin(tester);
    expect(find.text('请输入企业账号'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
    expect(client.authCalls, isEmpty);
  });

  testWidgets('密码默认隐藏，显隐切换保留已输入内容', (tester) async {
    await _mount(tester, client);
    await _fill(tester);
    final password = find.byKey(const ValueKey('enterprise-login-password'));
    TextField field() => tester.widget<TextField>(
      find.descendant(of: password, matching: find.byType(TextField)),
    );
    expect(field().obscureText, isTrue);
    await tester.tap(find.byTooltip('显示密码'));
    await tester.pump();
    expect(field().obscureText, isFalse);
    expect(field().controller!.text, 'synthetic-password');
    await tester.tap(find.byTooltip('隐藏密码'));
    await tester.pump();
    expect(field().obscureText, isTrue);
    expect(client.authCalls, isEmpty);
  });

  testWidgets('提交中禁止重复登录，参数和登录后验证保存流程不变', (tester) async {
    client.loginGate = Completer<Map<String, dynamic>>();
    await _mount(tester, client);
    await _fill(tester);
    await _submit(tester);
    final submit = find.byKey(const ValueKey('enterprise-login-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(submit);
    await tester.pump();
    expect(client.authCalls, hasLength(1));
    expect(client.authCalls.single.body, {
      'loginType': 'account_password',
      'username': 'synthetic-hr',
      'password': 'synthetic-password',
    });
    client.loginGate!.complete({'code': 200, 'token': 'synthetic-session'});
    await _settleLogin(tester);
    expect(client.authCalls.map((call) => call.path), ['/login', '/getInfo']);
    expect(find.text('合成工作台：退出'), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(key: 'enterprise_access_token'),
      'synthetic-session',
    );
  });

  testWidgets('登录失败显示原错误信息，账号密码保留且可重试', (tester) async {
    client.loginError = const ApiException('合成账号或密码错误');
    await _mount(tester, client);
    await _fill(tester);
    await _submit(tester);
    await _settleLogin(tester);
    expect(find.text('合成账号或密码错误'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('enterprise-login-submit')),
          )
          .onPressed,
      isNotNull,
    );
    client.loginError = null;
    await _submit(tester);
    await _settleLogin(tester);
    expect(find.text('合成工作台：退出'), findsOneWidget);
  });

  testWidgets('恢复已有会话并退出，保留原验证与本地清理行为', (tester) async {
    await _mount(
      tester,
      client,
      stored: {'enterprise_access_token': 'synthetic-existing-session'},
    );
    expect(find.text('合成工作台：退出'), findsOneWidget);
    expect(client.authCalls.single.path, '/getInfo');
    await tester.tap(find.text('合成工作台：退出'));
    await _settleLogin(tester);
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(client.authCalls.last.path, '/logout');
    expect(
      await const FlutterSecureStorage().read(key: 'enterprise_access_token'),
      isNull,
    );
  });

  testWidgets('恢复会话网络失败保留令牌，重试成功恢复工作台', (tester) async {
    client.sessionError = const ApiException('合成连接超时');
    await _mount(
      tester,
      client,
      stored: {'enterprise_access_token': 'synthetic-existing-session'},
    );
    expect(find.text('合成连接超时'), findsOneWidget);
    expect(find.text('使用其他账号登录'), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(key: 'enterprise_access_token'),
      'synthetic-existing-session',
    );
    client.sessionError = null;
    await tester.tap(find.text('重试'));
    await _settleLogin(tester);
    expect(find.text('合成工作台：退出'), findsOneWidget);
  });

  for (final sample in [
    (const Size(320, 640), 1.0, 0.0),
    (const Size(320, 640), 2.0, 0.0),
    (const Size(320, 640), 1.0, 260.0),
    (const Size(900, 420), 1.0, 180.0),
  ]) {
    testWidgets('登录页在 ${sample.$1} 字号 ${sample.$2} 键盘 ${sample.$3} 不溢出', (
      tester,
    ) async {
      await _mount(
        tester,
        client,
        size: sample.$1,
        scale: sample.$2,
        keyboard: sample.$3,
      );
      await _fill(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('enterprise-login-submit')),
      );
      await _settleLogin(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('enterprise-login-submit')).hitTestable(),
        findsOneWidget,
      );
    });
  }
  testWidgets('验证码开启时显示真实图片，校验必填并提交 code 和 uuid', (tester) async {
    client.captchaEnabled = true;
    await _mount(tester, client);
    await _fill(tester);
    await _submit(tester);
    await _settleLogin(tester);
    expect(find.text('请输入图形验证码'), findsOneWidget);
    expect(client.authCalls, isEmpty);
    expect(find.byType(Image), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('enterprise-login-captcha')),
      '  7  ',
    );
    await _submit(tester);
    await _settleLogin(tester);
    expect(client.authCalls.first.body, {
      'loginType': 'password',
      'username': 'synthetic-hr',
      'password': 'synthetic-password',
      'code': '7',
      'uuid': 'synthetic-captcha-1',
    });
    expect(find.text('合成工作台：退出'), findsOneWidget);
  });

  testWidgets('点击图形验证码刷新并清空旧答案，登录失败后重新获取新验证码', (tester) async {
    client.captchaEnabled = true;
    await _mount(tester, client);
    await _fill(tester);
    final captcha = find.byKey(const ValueKey('enterprise-login-captcha'));
    await tester.enterText(captcha, 'old-answer');
    client.captchaUuid = 'synthetic-captcha-2';
    final image = find.byKey(
      const ValueKey('enterprise-login-captcha-refresh'),
    );
    await tester.ensureVisible(image);
    await tester.tap(image);
    await _settleLogin(tester);
    final field = tester.widget<TextField>(
      find.descendant(of: captcha, matching: find.byType(TextField)),
    );
    expect(field.controller!.text, isEmpty);
    client.loginError = const ApiException('合成验证码错误');
    await tester.enterText(captcha, '2');
    await _submit(tester);
    await _settleLogin(tester);
    expect(client.authCalls.single.body!['uuid'], 'synthetic-captcha-2');
    expect(find.text('合成验证码错误'), findsOneWidget);
    expect(
      client.calls.where((call) => call.path == '/captchaImage'),
      hasLength(3),
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: captcha, matching: find.byType(TextField)),
          )
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('验证码加载失败时禁止绕过，重试后按服务端开关恢复登录', (tester) async {
    client.captchaError = const ApiException('合成验证码请求超时');
    await _mount(tester, client);
    await _fill(tester);
    expect(find.text('合成验证码请求超时'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('enterprise-login-submit')),
          )
          .onPressed,
      isNull,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(client.authCalls, isEmpty);
    client.captchaError = null;
    final retry = find.byKey(const ValueKey('enterprise-login-captcha-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await _settleLogin(tester);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('enterprise-login-submit')),
          )
          .onPressed,
      isNotNull,
    );
    await _submit(tester);
    await _settleLogin(tester);
    expect(client.authCalls.first.body!['loginType'], 'account_password');
  });

  for (final invalid in <Map<String, dynamic>>[
    {'captchaEnabled': true},
    {'captchaEnabled': true, 'uuid': 'synthetic', 'img': 'bad-base64'},
    {'captchaEnabled': true, 'uuid': 'synthetic', 'img': 'aGVsbG8='},
    {'captchaEnabled': 'false'},
  ]) {
    testWidgets('验证码响应异常保持禁止登录：${invalid.keys}', (tester) async {
      client.captchaResponse = invalid;
      await _mount(tester, client);
      expect(find.text('图形验证码加载失败，请重试'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('enterprise-login-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(client.authCalls, isEmpty);
    });
  }

  testWidgets('验证码请求未完成时按钮禁用，响应完成才可提交', (tester) async {
    client.captchaGate = Completer<Map<String, dynamic>>();
    await _mount(tester, client, settle: false);
    expect(find.text('正在加载登录验证…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('enterprise-login-submit')),
          )
          .onPressed,
      isNull,
    );
    client.captchaGate!.complete({'code': 200, 'captchaEnabled': false});
    await _settleLogin(tester);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('enterprise-login-submit')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('短信登录仅UI，获取验证码不请求，密码输入切换后保留', (tester) async {
    await _mount(tester, client);
    await _fill(tester);
    final before = client.calls.length;
    await tester.tap(find.byKey(const ValueKey('login-mode-sms')));
    await _settleLogin(tester);
    expect(
      find.byKey(const ValueKey('enterprise-login-phone')),
      findsOneWidget,
    );
    expect(find.text('短信验证码登录功能开发中，请使用密码登录。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('enterprise-login-sms-submit')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('enterprise-login-phone')),
      '13800000000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('enterprise-login-sms-code')),
      '123456',
    );
    final send = find.byKey(const ValueKey('enterprise-login-sms-send'));
    final codeField = find.byKey(const ValueKey('enterprise-login-sms-code'));
    expect(find.descendant(of: codeField, matching: send), findsOneWidget);
    await tester.ensureVisible(send);
    await tester.tap(send);
    await _settleLogin(tester);
    expect(find.text('短信验证码登录功能开发中'), findsOneWidget);
    expect(client.calls.length, before);
    final passwordTab = find.byKey(const ValueKey('login-mode-password'));
    await tester.ensureVisible(passwordTab);
    await tester.tap(passwordTab);
    await _settleLogin(tester);
    final password = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('enterprise-login-password')),
        matching: find.byType(TextField),
      ),
    );
    expect(password.controller!.text, 'synthetic-password');
    expect(client.calls.length, before);
  });

  for (final sample in [
    (const Size(320, 640), 1.0, 0.0),
    (const Size(320, 640), 2.0, 0.0),
    (const Size(320, 640), 1.0, 260.0),
    (const Size(900, 420), 1.0, 180.0),
  ]) {
    testWidgets('验证码和短信UI在 ${sample.$1} 字号 ${sample.$2} 键盘 ${sample.$3} 不溢出', (
      tester,
    ) async {
      client.captchaEnabled = true;
      await _mount(
        tester,
        client,
        size: sample.$1,
        scale: sample.$2,
        keyboard: sample.$3,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('enterprise-login-captcha')),
      );
      await _settleLogin(tester);
      expect(tester.takeException(), isNull);
      final sms = find.byKey(const ValueKey('login-mode-sms'));
      await tester.ensureVisible(sms);
      await tester.tap(sms);
      await _settleLogin(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('enterprise-login-sms-send')),
      );
      await _settleLogin(tester);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('协议在图形验证码下方，勾选与弹窗仅 UI 不影响登录', (tester) async {
    client.captchaEnabled = true;
    await _mount(tester, client);
    final agreement = find.byKey(const ValueKey('enterprise-login-agreement'));
    final captcha = find.byKey(const ValueKey('enterprise-login-captcha'));
    expect(
      tester.getTopLeft(agreement).dy,
      greaterThan(tester.getTopLeft(captcha).dy),
    );
    expect(tester.widget<Checkbox>(agreement).value, isFalse);
    await tester.ensureVisible(agreement);
    await tester.tap(agreement);
    await _settleLogin(tester);
    expect(tester.widget<Checkbox>(agreement).value, isTrue);
    final requests = client.calls.length;
    for (final entry in [
      ('enterprise-login-user-agreement', '用户协议'),
      ('enterprise-login-privacy', '隐私政策'),
    ]) {
      final link = find.byKey(ValueKey(entry.$1));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await _settleLogin(tester);
      expect(find.text(entry.$2), findsOneWidget);
      expect(find.text('协议内容功能开发中，当前仅展示界面。'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await _settleLogin(tester);
    }
    expect(client.calls.length, requests);
    await tester.ensureVisible(agreement);
    await tester.tap(agreement);
    await _settleLogin(tester);
    await _fill(tester);
    await tester.enterText(captcha, '7');
    await _submit(tester);
    await _settleLogin(tester);
    expect(find.text('合成工作台：退出'), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(
        key: 'enterprise_remembered_username',
      ),
      isNull,
    );
  });

  testWidgets('不再展示记住我或回填历史保存账号，登录只保存会话', (tester) async {
    await _mount(
      tester,
      client,
      stored: {'enterprise_remembered_username': 'previous-hr'},
    );
    expect(find.text('记住我'), findsNothing);
    expect(find.text('下次自动填入企业账号'), findsNothing);
    expect(find.byType(Checkbox), findsOneWidget);
    final username = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('enterprise-login-username')),
        matching: find.byType(TextField),
      ),
    );
    expect(username.controller!.text, isEmpty);
    await _fill(tester);
    await _submit(tester);
    await _settleLogin(tester);
    expect(find.text('合成工作台：退出'), findsOneWidget);
    // 旧版本账号记录不读取也不更新，不影响原有登录会话存储。
    expect(await const FlutterSecureStorage().readAll(), {
      'enterprise_remembered_username': 'previous-hr',
      'enterprise_access_token': 'synthetic-session',
    });
  });

  testWidgets('注册入口位于卡片下方，仅提示开发中且不请求或跳转', (tester) async {
    await _mount(tester, client);
    final register = find.byKey(const ValueKey('enterprise-login-register'));
    expect(find.text('还没有账号？'), findsOneWidget);
    expect(
      tester.getTopLeft(register).dy,
      greaterThan(tester.getBottomLeft(find.byType(Card)).dy),
    );
    final calls = client.calls.length;
    await tester.ensureVisible(register);
    await tester.tap(register);
    await _settleLogin(tester);
    expect(find.text('企业账号注册功能开发中'), findsOneWidget);
    expect(client.calls.length, calls);
    expect(
      find.byKey(const ValueKey('enterprise-login-submit')),
      findsOneWidget,
    );
    expect(
      Navigator.of(tester.element(find.byType(LoginPage))).canPop(),
      isFalse,
    );
    final sms = find.byKey(const ValueKey('login-mode-sms'));
    await tester.ensureVisible(sms);
    await tester.tap(sms);
    await _settleLogin(tester);
    expect(register, findsOneWidget);
    expect(client.calls.length, calls);
  });
}
