import 'dart:async';

import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/token_store.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/auth_splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

class IntelligentInterviewerApp extends StatefulWidget {
  const IntelligentInterviewerApp({super.key, this.authController});

  final AuthController? authController;

  @override
  State<IntelligentInterviewerApp> createState() =>
      _IntelligentInterviewerAppState();
}

class _IntelligentInterviewerAppState extends State<IntelligentInterviewerApp> {
  late final ApiClient? _ownedClient;
  late final AuthController _authController;
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _unauthorizedSubscription;
  bool _handlingUnauthorized = false;

  @override
  void initState() {
    super.initState();
    if (widget.authController case final controller?) {
      _ownedClient = null;
      _authController = controller;
    } else {
      final client = ApiClient();
      _ownedClient = client;
      _authController = AuthController(
        api: AuthApi(client),
        tokenStore: const SecureTokenStore(),
      );
    }
    _authController.initialize();
    _unauthorizedSubscription = ApiClient.unauthorizedTokens.listen(
      _handleUnauthorized,
    );
  }

  Future<void> _handleUnauthorized(String token) async {
    if (!mounted ||
        _handlingUnauthorized ||
        _authController.session?.token != token) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    _handlingUnauthorized = true;
    try {
      final relogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('登录状态已过期'),
          content: const Text('请重新登录后继续查看投递和面试安排。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('暂不登录'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('重新登录'),
            ),
          ],
        ),
      );
      if (relogin == true &&
          mounted &&
          _authController.session?.token == token) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        await _authController.signOut();
      }
    } finally {
      _handlingUnauthorized = false;
    }
  }

  @override
  void dispose() {
    _unauthorizedSubscription?.cancel();
    _ownedClient?.close();
    if (widget.authController == null) _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: '智聘助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: ListenableBuilder(
        listenable: _authController,
        builder: (context, _) {
          if (!_authController.initialized) {
            return const AuthSplashScreen();
          }
          final session = _authController.session;
          if (session == null) {
            return LoginScreen(controller: _authController);
          }
          return MainShell(session: session, onLogout: _authController.signOut);
        },
      ),
    );
  }
}
