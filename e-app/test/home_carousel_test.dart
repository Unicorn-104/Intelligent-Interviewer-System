import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_carousel.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('本地三卡轮播每五秒切换，隐藏时暂停，重新出现后恢复', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return TickerMode(
                  enabled: enabled,
                  child: const HomeCarousel(),
                );
              },
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('轮播图，第 1 页，共 3 页'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 4999));
      expect(find.bySemanticsLabel('轮播图，第 1 页，共 3 页'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('轮播图，第 2 页，共 3 页'), findsOneWidget);
      update(() => enabled = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(const Duration(seconds: 12));
      update(() => enabled = true);
      await tester.pump();
      expect(find.bySemanticsLabel('轮播图，第 2 页，共 3 页'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('轮播图，第 3 页，共 3 页'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-carousel-dot-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('轮播图，第 1 页，共 3 页'), findsOneWidget);
    } finally {
      try {
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    }
  });

  testWidgets('装饰动画持续播放，后台和减少动态效果时暂停，恢复后继续', (tester) async {
    var reducedMotion = false;
    late StateSetter update;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: reducedMotion),
                  child: const HomeCarousel(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      update(() => reducedMotion = true);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(const Duration(seconds: 6));
      expect(
        find.byKey(const ValueKey('home-carousel-page-0')),
        findsOneWidget,
      );
      update(() => reducedMotion = false);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
