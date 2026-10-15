import 'package:enterprise_recruiter/features/enterprise/dashboard/home_page.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_section.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(900, 420),
    const Size(420, 900),
  ]) {
    testWidgets('首页骨架与占位在 $size 和安全区内不溢出', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var notifications = 0;
      var features = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            ),
            child: HomePage(
              onNotifications: () => notifications++,
              onFeatures: () => features++,
              onInterviews: () {},
              onJobs: () {},
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('home-carousel-placeholder')),
        findsOneWidget,
      );
      expect(find.byType(HomeSkeleton), findsWidgets);
      expect(find.text('企业信息待接入'), findsOneWidget);
      expect(find.text('更多信息正在接入'), findsWidgets);
      await tester.tap(find.byTooltip('通知与公告'));
      await tester.tap(find.byTooltip('更多功能'));
      expect(notifications, 1);
      expect(features, 1);
      await tester.scrollUntilVisible(find.text('在招岗位'), 240);
      expect(find.text('—'), findsNWidgets(4));
      expect(find.text('0'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
