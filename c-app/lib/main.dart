import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'core/network/backend_http_overrides.dart';

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
  runApp(const IntelligentInterviewerApp());
}
