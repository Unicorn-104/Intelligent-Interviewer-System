import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_config.dart';
import 'core/network/backend_http_overrides.dart';

import 'features/enterprise/enterprise_shell.dart';
import 'features/enterprise/login_page.dart';
import 'theme/app_theme.dart';

export 'features/enterprise/enterprise_shell.dart' show EnterpriseModuleShell;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.trustBaotaCertificate) {
    final certificate = await rootBundle.load(
      'assets/certificates/baota_root.pem',
    );
    HttpOverrides.global = BackendHttpOverrides(
      origin: Uri.parse(AppConfig.apiBaseUrl),
      certificate: certificate.buffer.asUint8List(
        certificate.offsetInBytes,
        certificate.lengthInBytes,
      ),
    );
  }
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
