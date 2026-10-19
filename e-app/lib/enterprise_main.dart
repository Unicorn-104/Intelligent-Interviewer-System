import 'package:flutter/material.dart';

import 'features/enterprise/enterprise_shell.dart';
import 'features/enterprise/login_page.dart';
import 'theme/app_theme.dart';

export 'features/enterprise/enterprise_shell.dart' show EnterpriseModuleShell;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EnterpriseMainApp());
}

class EnterpriseMainApp extends StatelessWidget {
  const EnterpriseMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智能面试官 · 企业端',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: LoginPage(
        authenticatedBuilder: (context, onLogout) =>
            EnterpriseModuleShell(onLogout: onLogout),
      ),
    );
  }
}
