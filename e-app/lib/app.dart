import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/enterprise/enterprise_repository.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

class EnterpriseApp extends StatefulWidget {
  const EnterpriseApp({super.key});

  @override
  State<EnterpriseApp> createState() => _EnterpriseAppState();
}

class _EnterpriseAppState extends State<EnterpriseApp> {
  late final ApiClient _client;
  late final AuthController _auth;
  late final EnterpriseRepository _repository;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _auth = AuthController(_client)..initialize();
    _repository = EnterpriseRepository(_client, () => _auth.token);
  }

  @override
  void dispose() {
    _auth.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '企业招聘工作台',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: AnimatedBuilder(
          animation: _auth,
          builder: (_, _) {
            if (!_auth.initialized) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return _auth.authenticated
                ? MainShell(auth: _auth, repository: _repository)
                : LoginScreen(controller: _auth);
          },
        ),
      );
}
