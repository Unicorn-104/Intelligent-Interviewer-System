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

class _IntelligentInterviewerAppState
    extends State<IntelligentInterviewerApp> {
  late final ApiClient? _ownedClient;
  late final AuthController _authController;

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
  }

  @override
  void dispose() {
    _ownedClient?.close();
    if (widget.authController == null) _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
          return MainShell(
            session: session,
            onLogout: _authController.signOut,
          );
        },
      ),
    );
  }
}
