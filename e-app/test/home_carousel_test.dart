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
      await tester.pump(const Duration(milliseconds: 4999));
      expect(find.bySemanticsLabel('轮播图，第 1 页，共 3 页'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('轮播图，第 2 页，共 3 页'), findsOneWidget);
      update(() => enabled = false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));
      update(() => enabled = true);
      await tester.pump();
      expect(find.bySemanticsLabel('轮播图，第 2 页，共 3 页'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('轮播图，第 3 页，共 3 页'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-carousel-dot-0')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('轮播图，第 1 页，共 3 页'), findsOneWidget);
    } finally {
      try {
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    }
  });
}
