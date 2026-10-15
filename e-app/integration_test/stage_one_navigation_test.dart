import 'package:enterprise_recruiter/features/enterprise/enterprise_shell.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'stage_one_device_test.dart' show frames, bridge, capture;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final batches = [
    ['招聘概览', '人才库', '面试日程', '终审', 'Offer', '通知', '公告'],
    ['筛选任务', '短名单', '招呼语'],
    ['工作台', '设备检测', '录播', '预加载', '改期审批', '模板', '调研', 'AI 助手'],
  ];
  for (var batch = 0; batch < batches.length; batch++) {
    testWidgets('Pixel_10a 第 ${batch + 1} 批入口逐项验证', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: EnterpriseModuleShell(onLogout: () {}),
        ),
      );
      await frames(tester, 200);
      await tester.tap(find.byTooltip('更多功能'));
      await frames(tester, 200);
      for (var i = 0; i < batches[batch].length; i++) {
        final label = batches[batch][i];
        final entry = find.byKey(ValueKey('feature-$label'));
        await tester.scrollUntilVisible(
          entry,
          240,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(entry);
        await frames(tester);
        if (batch > 0) expect(find.textContaining('演示数据'), findsWidgets);
        expect(tester.takeException(), isNull, reason: label);
        await capture('batch_${batch + 1}_entry_$i');
        await tester.binding.handlePopRoute();
        await frames(tester, 200);
        expect(entry, findsOneWidget);
      }
      binding.reportData ??= {};
      binding.reportData!['batch${batch + 1}'] = 'passed';
    });
  }
  testWidgets('Pixel_10a 物理窄屏横屏安全区与四 Tab', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    try {
      for (final layout in ['narrow', 'landscape', 'portrait']) {
        await bridge('layout/$layout');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: EnterpriseModuleShell(onLogout: () {}),
          ),
        );
        await frames(tester, 1000);
        for (var tab = 0; tab < 4; tab++) {
          await tester.tap(find.byType(NavigationDestination).at(tab));
          await frames(tester, 500);
          expect(tester.takeException(), isNull, reason: '$layout tab $tab');
          await capture('layout_${layout}_tab_$tab');
        }
      }
      binding.reportData ??= {};
      binding.reportData!['physicalLayoutsAllFourTabs'] = 'passed';
    } finally {
      await bridge('layout/reset');
    }
  });
}
