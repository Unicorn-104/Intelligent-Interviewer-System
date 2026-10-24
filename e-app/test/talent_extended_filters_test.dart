import 'package:enterprise_recruiter/api/talent_api.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_pool_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_http_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('高级筛选传递精确参数，旧调用不发送新增筛选参数', () async {
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-test-token',
    });
    final http = JdHttpFixture();
    addTearDown(http.close);
    http.adapter.body = {'code': 200, 'rows': []};
    await searchAdvancedTalentPool(
      client: http.client,
      pageNum: 2,
      pageSize: 20,
      minimumEducation: 3,
      experienceRange: '3to5',
      city: '合成杭州',
      cityType: 'target',
      loginWithinDays: 7,
    );
    final query = http.adapter.requests.single.queryParameters;
    expect(query['minimumEducation'], 3);
    expect(query['experienceRange'], '3to5');
    expect(query['city'], '合成杭州');
    expect(query['cityType'], 'target');
    expect(query['loginWithinDays'], 7);
    await searchAdvancedTalentPool(
      client: http.client,
      pageNum: 1,
      pageSize: 20,
    );
    expect(
      http.adapter.requests.last.queryParameters.containsKey(
        'minimumEducation',
      ),
      isFalse,
    );
    expect(
      http.adapter.requests.last.queryParameters.containsKey('cityType'),
      isFalse,
    );
  });
  test('城市选项兼容老版本，缺失不伪造，城市和教育筛选计数正确', () {
    final old = TalentPoolOptions.fromJson({'directions': [], 'tags': []});
    expect(old.currentCities, isEmpty);
    expect(old.searchFilterVersion, 1);
    final updated = TalentPoolOptions.fromJson({
      'directions': [],
      'tags': [],
      'currentCities': ['合成杭州', '合成杭州'],
      'targetCities': ['合成上海'],
      'searchFilterVersion': 2,
    });
    expect(updated.currentCities, ['合成杭州']);
    expect(updated.targetCities, ['合成上海']);
    expect(
      const TalentPoolFilters(
        minimumEducation: 3,
        experienceRange: '1to3',
        city: '合成杭州',
        loginWithinDays: 7,
      ).count,
      4,
    );
    expect(const TalentPoolFilters(cityType: 'current').count, 0);
  });
  test('高级条件不支持时明确报错，不能在第一页客户端假筛选', () async {
    final source = TalentPoolDataSource(
      optionsLoader: () async => {
        'directions': [],
        'tags': [],
        'searchFilterVersion': 1,
      },
      advancedLoader:
          ({
            keyword,
            tag,
            direction,
            archiveSource,
            status,
            minimumEducation,
            experienceRange,
            city,
            cityType,
            loginWithinDays,
            required pageNum,
            required pageSize,
          }) async => [
            {'talentId': 11},
          ],
    );
    await expectLater(
      source.load(extended: const TalentPoolFilters(minimumEducation: 3)),
      throwsFormatException,
    );
    final legacy = TalentPoolDataSource(
      loader: ({keyword, tag, required pageNum, required pageSize}) async => [],
    );
    await expectLater(
      legacy.load(extended: const TalentPoolFilters(city: '合成杭州')),
      throwsFormatException,
    );
    for (final criteria in [
      const TalentPoolFilters(minimumEducation: 9),
      const TalentPoolFilters(experienceRange: 'fake'),
      const TalentPoolFilters(city: ' '),
      const TalentPoolFilters(cityType: 'table'),
      const TalentPoolFilters(loginWithinDays: 99),
    ]) {
      await expectLater(source.load(extended: criteria), throwsFormatException);
    }
  });

  for (final size in [
    const Size(430, 900),
    const Size(320, 700),
    const Size(900, 420),
  ]) {
    testWidgets('六类筛选在$size支持同页定位、组合提交、重开保持和清除', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <Map<String, Object?>>[];
      final source = TalentPoolDataSource(
        advancedLoader:
            ({
              keyword,
              tag,
              direction,
              archiveSource,
              status,
              minimumEducation,
              experienceRange,
              city,
              cityType,
              loginWithinDays,
              required pageNum,
              required pageSize,
            }) async {
              calls.add({
                'minimumEducation': minimumEducation,
                'experienceRange': experienceRange,
                'city': city,
                'cityType': cityType,
                'loginWithinDays': loginWithinDays,
                'pageNum': pageNum,
              });
              return [
                {
                  'talentId': 11,
                  'name': '合成候选人',
                  'status': 1,
                  'searchFilterVersion': 2,
                },
              ];
            },
        optionsLoader: () async => {
          'directions': ['合成Java'],
          'tags': ['Java'],
          'currentCities': ['合成杭州'],
          'targetCities': ['合成上海'],
          'searchFilterVersion': 2,
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: TalentPage(source: source),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String key) async {
        final finder = find.byKey(Key(key));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap('talent-filter-open');
      for (var i = 0; i < 6; i++) {
        expect(
          find.byKey(ValueKey('talent-filter-section-$i')),
          findsOneWidget,
        );
      }
      await tap('talent-filter-category-2');
      await tap('talent-filter-education-3');
      await tap('talent-filter-category-3');
      await tap('talent-filter-experience-3to5');
      await tap('talent-filter-category-4');
      await tap('talent-filter-city-option-合成上海');
      await tap('talent-filter-category-5');
      await tap('talent-filter-login-7');
      expect(calls, hasLength(1));
      await tap('talent-filter-apply');
      expect(calls.last, {
        'minimumEducation': 3,
        'experienceRange': '3to5',
        'city': '合成上海',
        'cityType': 'target',
        'loginWithinDays': 7,
        'pageNum': 1,
      });
      expect(find.byTooltip('筛选(4)'), findsOneWidget);
      await tap('talent-filter-open');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('talent-filter-city')))
            .controller!
            .text,
        '合成上海',
      );
      final education = tester.widget<OutlinedButton>(
        find.byKey(const Key('talent-filter-education-3')),
      );
      expect(
        education.style!.foregroundColor!.resolve({}),
        AppColors.interactive,
      );
      await tap('talent-filter-category-4');
      await tap('talent-filter-city-type-current');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('talent-filter-city')))
            .controller!
            .text,
        isEmpty,
      );
      await tap('talent-filter-city-option-合成杭州');
      await tap('talent-filter-apply');
      expect(calls.last['cityType'], 'current');
      expect(calls.last['city'], '合成杭州');
      await tap('talent-filter-open');
      await tap('talent-filter-clear');
      await tap('talent-filter-apply');
      expect(calls.last['minimumEducation'], isNull);
      expect(calls.last['experienceRange'], isNull);
      expect(calls.last['city'], isNull);
      expect(calls.last['loginWithinDays'], isNull);
      expect(find.byTooltip('筛选'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
