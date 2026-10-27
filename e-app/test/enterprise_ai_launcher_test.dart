import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/features/enterprise/assistant/enterprise_ai_launcher.dart';

void main() {
  testWidgets(
    'release in middle animates to nearest edge without another drag',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnterpriseAiLauncher(
              onPressed: () {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      final orb = find.byKey(const ValueKey('ai-assistant-orb'));
      final gesture = await tester.startGesture(tester.getCenter(orb));
      await gesture.moveBy(const Offset(-150, -80));
      await tester.pump(const Duration(milliseconds: 16));
      final draggedX = tester.getRect(orb).left;
      expect(draggedX, greaterThan(30));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final movingX = tester.getRect(orb).left;
      expect(movingX, lessThan(draggedX));
      expect(movingX, greaterThan(4));
      await tester.pumpAndSettle();
      expect(tester.getRect(orb).left, closeTo(4, 0.1));
      final rightGesture = await tester.startGesture(tester.getCenter(orb));
      await rightGesture.moveBy(const Offset(170, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final draggedY = tester.getRect(orb).top;
      await rightGesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(orb).right, closeTo(316, 0.1));
      expect(tester.getRect(orb).top, closeTo(draggedY, 0.1));
    },
  );
  testWidgets('orb drags, snaps to either edge, and only taps open assistant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnterpriseAiLauncher(
            onPressed: () => opens++,
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
    final orb = find.byKey(const ValueKey('ai-assistant-orb'));
    expect(tester.getSize(orb), const Size(64, 64));
    expect(find.text('AI 助手'), findsNothing);
    final initial = tester.getRect(orb);
    await tester.drag(orb, const Offset(-270, -180));
    await tester.pumpAndSettle();
    final left = tester.getRect(orb);
    expect(left.left, lessThanOrEqualTo(20));
    expect(left.top, lessThan(initial.top));
    expect(opens, 0);
    await tester.drag(orb, const Offset(800, 800));
    await tester.pumpAndSettle();
    final right = tester.getRect(orb);
    expect(right.right, inInclusiveRange(300, 320));
    expect(right.bottom, lessThanOrEqualTo(600));
    expect(opens, 0);
    await tester.tap(orb);
    expect(opens, 1);
  });

  testWidgets(
    'orb stays within resized viewport and cancellation still snaps',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnterpriseAiLauncher(
              onPressed: () => opens++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      final orb = find.byKey(const ValueKey('ai-assistant-orb'));
      final gesture = await tester.startGesture(tester.getCenter(orb));
      await gesture.moveBy(const Offset(-230, -80));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.getRect(orb).left, lessThanOrEqualTo(20));
      tester.view.physicalSize = const Size(240, 400);
      await tester.pumpAndSettle();
      final rect = tester.getRect(orb);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(240));
      expect(rect.bottom, lessThanOrEqualTo(400));
      expect(opens, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
