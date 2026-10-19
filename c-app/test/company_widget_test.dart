import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/companies/presentation/company_screen.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';
import 'company_test_support.dart';

void main() {
  testWidgets(
    'company page fits narrow large-text screen and follows/unfollows without losing content',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeCompanyApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: CompanyScreen(session: session, companyId: 7, api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(company.name), findsOneWidget);
      expect(find.text('收藏企业'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('收藏企业'));
      await tester.pumpAndSettle();
      expect(find.text('已收藏'), findsOneWidget);
      await tester.tap(find.text('已收藏'));
      await tester.pumpAndSettle();
      expect(api.followValues, [true, false]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      api.client.close();
    },
  );
}
