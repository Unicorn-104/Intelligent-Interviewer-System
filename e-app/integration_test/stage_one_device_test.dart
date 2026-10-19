import 'dart:convert';
import 'dart:io';
import 'package:enterprise_recruiter/enterprise_main.dart' as app;
import 'package:enterprise_recruiter/features/enterprise/enterprise_shell.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/existing_pages.dart';

Future<void> frames(WidgetTester tester, [int milliseconds = 900]) async {
  await tester.pump();
  await Future<void>.delayed(Duration(milliseconds: milliseconds));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<bool> until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 30; i++) {
    await frames(tester, 300);
    if (ready()) return true;
  }
  return false;
}

Future<void> bridge(String path) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse('http://10.0.2.2:18989/$path'))
        .timeout(const Duration(seconds: 15));
    final response = await request.close().timeout(const Duration(seconds: 15));
    await response.drain<void>();
    if (response.statusCode != 200) {
      throw StateError('Device capture bridge failed: ${response.statusCode}');
    }
  } finally {
    client.close(force: true);
  }
}

Future<void> capture(String name) => bridge('capture/$name');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Pixel_10a 全页面主题回归及真实登录态导航', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await frames(tester, 100);

    final report = <String, Object?>{};
    final visualErrors = <String, List<String>>{};
    final originalErrorHandler = FlutterError.onError;
    final catalog = ExistingPages();
    try {
      for (final entry in catalog.builders.entries) {
        for (final baseline in [true, false]) {
          final key = '${entry.key}_${baseline ? 'before' : 'after'}';
          final errors = <String>[];
          FlutterError.onError = (details) =>
              errors.add(details.exceptionAsString());
          final theme = baseline
              ? AppTheme.light.copyWith(
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  iconButtonTheme: const IconButtonThemeData(),
                )
              : AppTheme.light;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(body: entry.value()),
            ),
          );
          await frames(tester, 1200);
          await capture(key);
          await tester.pumpWidget(const SizedBox.shrink());
          await frames(tester, 200);
          if (errors.isNotEmpty) visualErrors[key] = errors.toSet().toList();
        }
        debugPrint('PAGE_REVIEWED: ${entry.key}');
      }
      FlutterError.onError = originalErrorHandler;
      report['pagesOpenedBeforeAndAfter'] = catalog.builders.length;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: EnterpriseModuleShell(
            onLogout: () {},
            tabBuilders: [
              for (var i = 0; i < 4; i++)
                (context) => _NavigationProbe(index: i),
            ],
          ),
        ),
      );
      await frames(tester, 200);
      for (var index = 0; index < 4; index++) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await frames(tester, 200);
        await tester.tap(find.text('打开详情 $index'));
        await frames(tester, 200);
        await tester.tap(
          find.byType(NavigationDestination).at((index + 1) % 4),
        );
        await frames(tester, 200);
        await tester.tap(find.byType(NavigationDestination).at(index));
        await frames(tester, 200);
        expect(find.text('详情 $index'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await frames(tester, 200);
        expect(find.text('打开详情 $index'), findsOneWidget);
        await tester.tap(find.text('打开详情 $index'));
        await frames(tester, 200);
        await tester.tap(find.byType(NavigationDestination).at(index));
        await frames(tester, 200);
        expect(find.text('打开详情 $index'), findsOneWidget);
      }
      report['allTabStacksBackAndReselect'] = true;
      report['visualErrors'] = visualErrors;
      final token = await const FlutterSecureStorage().read(
        key: 'enterprise_access_token',
      );
      report['existingSessionAvailable'] = token != null && token.isNotEmpty;
      if (token != null && token.isNotEmpty) {
        app.main();
        final restored = await until(
          tester,
          () => find.byType(EnterpriseModuleShell).evaluate().isNotEmpty,
        );
        report['realSessionRestored'] = restored;
        if (restored) {
          await capture('stage1_home');
          for (final layout in ['narrow', 'landscape', 'portrait']) {
            await bridge('layout/$layout');
            await frames(tester, 1200);
            expect(tester.takeException(), isNull);
            await capture('stage1_home_$layout');
          }
          report['physicalNarrowLandscapeSafeArea'] = true;
          for (var index = 0; index < 4; index++) {
            await tester.tap(find.byType(NavigationDestination).at(index));
            await frames(tester);
            expect(find.byType(NavigationBar), findsOneWidget);
          }
          report['realFourTabs'] = true;
          await tester.tap(find.byType(NavigationDestination).at(0));
          await frames(tester);
          await tester.tap(find.byTooltip('更多功能'));
          await frames(tester);
          expect(find.text('更多功能'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await frames(tester);
          expect(find.text('企业信息待接入'), findsOneWidget);
          await tester.tap(find.byTooltip('更多功能'));
          await frames(tester);
          await tester.tap(find.byType(NavigationDestination).at(0));
          await frames(tester);
          expect(find.text('企业信息待接入'), findsOneWidget);
          report['realHomeBackAndReselect'] = true;
          // Logout is verified last so existing authenticated data stays available for the page audit.
          await tester.tap(find.byType(NavigationDestination).at(3));
          await frames(tester);
          final logout = find.text('退出登录');
          if (logout.evaluate().isNotEmpty) {
            await tester.ensureVisible(logout.first);
            await tester.tap(logout.first);
            final loggedOut = await until(
              tester,
              () => find.text('企业账号').evaluate().isNotEmpty,
            );
            report['realLogout'] = loggedOut;
            expect(loggedOut, isTrue);
          } else {
            report['realLogout'] = false;
          }
        }
      }
      report['freshPasswordLogin'] = 'requires user-provided test credentials';
      binding.reportData ??= {};
      binding.reportData!['stageOne'] = report;
      debugPrint('STAGE_ONE_DEVICE_REPORT: ${jsonEncode(report)}');
      final introduced = visualErrors.entries
          .where(
            (e) =>
                e.key.endsWith('_after') &&
                !visualErrors.containsKey(
                  e.key.replaceFirst('_after', '_before'),
                ),
          )
          .toList();
      expect(
        introduced,
        isEmpty,
        reason: 'No new rendering errors after the theme change',
      );
    } finally {
      FlutterError.onError = originalErrorHandler;
      await bridge('layout/reset');
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester, 200);
      catalog.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}

class _NavigationProbe extends StatelessWidget {
  const _NavigationProbe({required this.index});
  final int index;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('测试页面 $index')),
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => Scaffold(appBar: AppBar(title: Text('详情 $index'))),
          ),
        ),
        child: Text('打开详情 $index'),
      ),
    ),
  );
}
