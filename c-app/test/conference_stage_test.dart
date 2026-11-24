import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/conference_stage.dart';

List<ConferenceStageFeed> feeds(int count) => List.generate(
  count,
  (i) => ConferenceStageFeed(
    id: 'p$i',
    name: i == count - 1 ? '我 · 求职者' : '面试官 ${i + 1}',
    local: i == count - 1,
    microphone: i.isEven,
    speaking: i == 1,
  ),
);

void main() {
  Future<void> mount(
    WidgetTester tester,
    List<ConferenceStageFeed> people, {
    Size size = const Size(390, 640),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D12),
          body: ConferenceStage(feeds: people),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('点击顶部缩略图切换主画面，双向滑动保留选择', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, feeds(3));
    expect(
      find.byKey(const ValueKey('conference-featured-p0')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('conference-thumbnail-p2')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('conference-featured-p2')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const ValueKey('conference-stage-pages')),
      const Offset(-340, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('conference-grid-p2')).hitTestable(),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const ValueKey('conference-stage-pages')),
      const Offset(340, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('conference-featured-p2')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final count in [2, 3, 4]) {
    testWidgets('$count 人宫格的尺寸和位置，点击宫格回主画面', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, feeds(count));
      await tester.tap(find.byTooltip('宫格视图 1'));
      await tester.pumpAndSettle();
      Rect rect(int i) =>
          tester.getRect(find.byKey(ValueKey('conference-grid-p$i')));
      if (count == 2) {
        expect(rect(0).width, closeTo(rect(1).width, 1));
        expect(rect(0).bottom, lessThanOrEqualTo(rect(1).top));
      } else {
        expect(rect(0).top, closeTo(rect(1).top, 1));
        expect(rect(0).right, lessThanOrEqualTo(rect(1).left));
        expect(rect(2).top, greaterThan(rect(0).top));
        if (count == 3) expect(rect(2).center.dx, closeTo(195, 1));
        if (count == 4) expect(rect(2).top, closeTo(rect(3).top, 1));
      }
      await tester.tap(find.byKey(const ValueKey('conference-grid-p1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('conference-featured-p1')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('选中成员退出回退，五人以上分页和人数减少不出现空页', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, feeds(6));
    await tester.tap(find.byTooltip('宫格视图 2'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('conference-grid-p5')).hitTestable(),
      findsOneWidget,
    );
    await mount(tester, feeds(2));
    expect(
      find.byKey(const ValueKey('conference-grid-p0')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('主画面'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conference-thumbnail-p1')));
    await tester.pumpAndSettle();
    await mount(tester, [feeds(2).first]);
    expect(
      find.byKey(const ValueKey('conference-featured-p0')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('屏幕共享默认主画面，双人横屏左右排列', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, [
      const ConferenceStageFeed(
        id: 'share',
        name: '面试官 · 屏幕共享',
        screenShare: true,
      ),
      feeds(2).last,
    ], size: const Size(740, 340));
    expect(
      find.byKey(const ValueKey('conference-featured-share')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('宫格视图 1'));
    await tester.pumpAndSettle();
    final a = tester.getRect(
      find.byKey(const ValueKey('conference-grid-share')),
    );
    final b = tester.getRect(find.byKey(const ValueKey('conference-grid-p1')));
    expect(a.top, closeTo(b.top, 1));
    expect(a.right, lessThanOrEqualTo(b.left));
    expect(tester.takeException(), isNull);
  });
}
