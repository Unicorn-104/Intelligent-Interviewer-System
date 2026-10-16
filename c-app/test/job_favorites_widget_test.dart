import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/jobs/presentation/job_favorites_screen.dart';
import 'package:intelligent_interviewer/screens/job_detail_screen.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';
import 'company_test_support.dart' show session;
import 'job_favorites_test_support.dart';

void main() {
  testWidgets(
    'detail bookmark loads, saves, cancels and retries unavailable state without changing application',
    (tester) async {
      final api = FakeJobFavoriteApi();
      addTearDown(api.client.close);
      api.onState = () async => throw const ApiException('请重试');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: JobDetailScreen(
            job: favoriteJob(91).copyWith(applied: true),
            session: session,
            favoriteApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('收藏状态加载失败'), findsOneWidget);
      api.onState = null;
      await tester.tap(find.byTooltip('重试加载收藏状态'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('收藏职位'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('取消收藏职位'), findsOneWidget);
      await tester.tap(find.byTooltip('取消收藏职位'));
      await tester.pumpAndSettle();
      expect(api.saves, [(91, true), (91, false)]);
      expect(find.text('已投递'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'favorites fits narrow large text, refreshes after detail cancellation, then shows empty state',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeJobFavoriteApi()..favorited = true;
      addTearDown(api.client.close);
      api.onPage = (_) async => favoritePage(
        api.favorited ? [favoriteJob(91, available: false)] : [],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: JobFavoritesScreen(session: session, api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂不可投递'), findsOneWidget);
      await tester.tap(find.text('合成岗位 91'));
      await tester.pumpAndSettle();
      expect(find.text('该职位暂不可投递'), findsOneWidget);
      final apply = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '暂不可投递'),
      );
      expect(apply.onPressed, isNull);
      await tester.tap(find.byTooltip('取消收藏职位'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('还没有收藏职位'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
