import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_match_radar.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [220.0, 320.0, 800.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('雷达图在宽度$width字号$scale下标注六项分数且无溢出', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: TalentMatchRadar(
                  result: const {
                    'skillMatch': 90,
                    'projectMatch': 81,
                    'educationMatch': 78,
                    'industryMatch': 85,
                    'researchMatch': null,
                    'awardMatch': null,
                  },
                ),
              ),
            ),
          ),
        );
        for (final key in TalentMatchRadar.dimensions.keys) {
          expect(find.byKey(ValueKey('radar-score-$key')), findsOneWidget);
        }
        expect(find.text('90.0'), findsOneWidget);
        expect(find.text('81.0'), findsOneWidget);
        expect(find.text('—'), findsNWidgets(2));
        expect(find.text('0.0'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
