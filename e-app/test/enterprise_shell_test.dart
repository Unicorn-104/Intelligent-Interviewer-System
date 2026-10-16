import 'package:enterprise_recruiter/features/enterprise/enterprise_shell.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> verifyBatch(
  WidgetTester tester,
  List<String> labels, {
  bool allDemo = false,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: EnterpriseModuleShell(onLogout: () {}),
    ),
  );
  await tester.tap(find.byTooltip('更多功能'));
  await pumpFrames(tester);
  for (final label in labels) {
    final entry = find.byKey(ValueKey('feature-$label'));
    await tester.scrollUntilVisible(
      entry,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    if (allDemo) {
      expect(
        find.descendant(of: entry, matching: find.text('演示数据')),
        findsOneWidget,
      );
    }
    if (label == '候选人管理') {
      expect(
        find.descendant(of: entry, matching: find.text('人才库')),
        findsOneWidget,
      );
    }
    await tester.tap(entry);
    await pumpFrames(tester);
    if (allDemo) expect(find.textContaining('演示数据'), findsWidgets);
    expect(tester.takeException(), isNull, reason: '入口 $label');
    await tester.binding.handlePopRoute();
    await pumpFrames(tester);
    expect(find.byKey(ValueKey('feature-$label')), findsOneWidget);
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpFrames(tester);
}

void main() {
  testWidgets('第一批七个入口可打开并返回', (tester) async {
    await verifyBatch(tester, [
      '招聘概览',
      '候选人管理',
      '面试日程',
      '终审',
      'Offer',
      '通知',
      '公告',
    ]);
  });

  testWidgets('第二批三个入口可打开并返回且保留演示标识', (tester) async {
    await verifyBatch(tester, ['筛选任务', '短名单', '招呼语'], allDemo: true);
  });

  testWidgets('第三批八个入口可打开并返回且全部标注演示数据', (tester) async {
    await verifyBatch(tester, [
      '工作台',
      '设备检测',
      '录播',
      '预加载',
      '改期审批',
      '模板',
      '调研',
      'AI 助手',
    ], allDemo: true);
  });

  testWidgets('四 Tab 保留导航栈，系统返回只退出当前详情，重复点击回到首屏', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: EnterpriseModuleShell(
          onLogout: () {},
          tabBuilders: [
            for (var i = 0; i < 4; i++) (context) => _TestRoot(index: i),
          ],
        ),
      ),
    );
    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byType(NavigationDestination).at(index));
      await pumpFrames(tester);
      await tester.tap(find.text('打开详情 $index'));
      await pumpFrames(tester);
      expect(find.text('详情 $index'), findsOneWidget);
      final other = (index + 1) % 4;
      await tester.tap(find.byType(NavigationDestination).at(other));
      await pumpFrames(tester);
      expect(find.text('详情 $index'), findsNothing);
      await tester.tap(find.byType(NavigationDestination).at(index));
      await pumpFrames(tester);
      expect(find.text('详情 $index'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await pumpFrames(tester);
      expect(find.text('打开详情 $index'), findsOneWidget);
      await tester.tap(find.text('打开详情 $index'));
      await pumpFrames(tester);
      await tester.tap(find.byType(NavigationDestination).at(index));
      await pumpFrames(tester);
      expect(find.text('打开详情 $index'), findsOneWidget);
      expect(find.text('详情 $index'), findsNothing);
    }
  });
}

class _TestRoot extends StatelessWidget {
  const _TestRoot({required this.index});
  final int index;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('根页面 $index')),
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
