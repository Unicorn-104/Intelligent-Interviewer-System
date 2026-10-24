import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_pool_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_filter_sheet.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(430, 900),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: TalentFilterSheet(
            initial: const TalentPoolFilters(),
            loadOptions: () async => TalentPoolOptions(
              directions: List.generate(14, (i) => '合成方向$i'),
              tags: const ['Java', 'Flutter'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ScrollController controller(WidgetTester tester) => tester
      .widget<SingleChildScrollView>(
        find.byKey(const Key('talent-filter-scroll')),
      )
      .controller!;
  Future<void> category(WidgetTester tester, int index) async {
    final finder = find.byKey(ValueKey('talent-filter-category-$index'));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  void allSectionsExist() {
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('talent-filter-section-$i')), findsOneWidget);
    }
  }

  testWidgets('筛选仅保留六类，活跃度明确使用最近登录口径', (tester) async {
    await mount(tester);
    expect(find.text('候选人标签'), findsNothing);
    expect(find.text('归档来源'), findsNothing);
    expect(find.text('最近登录'), findsNothing);
    expect(find.text('活跃度'), findsOneWidget);
    expect(find.byKey(const Key('talent-filter-tag')), findsNothing);
    expect(find.byKey(const Key('talent-filter-archive-all')), findsNothing);
    for (final days in [1, 3, 7, 14, 30, 90]) {
      expect(find.byKey(Key('talent-filter-login-$days')), findsOneWidget);
    }
    expect(find.textContaining('按最近登录时间筛选'), findsOneWidget);
    expect(find.textContaining('功能开发中'), findsNothing);
    await category(tester, 5);
    final all = tester.getRect(
      find.byKey(const Key('talent-filter-login-all')),
    );
    final day = tester.getRect(find.byKey(const Key('talent-filter-login-1')));
    expect(all.top, day.top);
    expect(all.width, day.width);
    expect(day.left, greaterThan(all.right));
  });

  testWidgets('历史标签和归档条件不会成为隐藏筛选，提交只包含保留条件', (tester) async {
    TalentPoolFilters? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                submitted = await showModalBottomSheet<TalentPoolFilters>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => TalentFilterSheet(
                    initial: const TalentPoolFilters(
                      tag: '合成旧标签',
                      archiveSource: 3,
                      minimumEducation: 3,
                      loginWithinDays: 7,
                    ),
                    loadOptions: () async => const TalentPoolOptions(),
                  ),
                );
              },
              child: const Text('打开筛选'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('talent-filter-apply')));
    await tester.pumpAndSettle();
    expect(submitted, isNotNull);
    expect(submitted!.tag, isNull);
    expect(submitted!.archiveSource, isNull);
    expect(submitted!.minimumEducation, 3);
    expect(submitted!.loginWithinDays, 7);
    expect(submitted!.count, 2);
  });

  testWidgets('全部筛选区块同时存在于同一个滚动页面，分类点击只定位不替换内容', (tester) async {
    await mount(tester);
    allSectionsExist();
    final original = tester.element(
      find.byKey(const Key('talent-filter-section-0')),
    );
    final scroll = controller(tester);
    expect(scroll.offset, 0);
    for (final index in [1, 2, 3, 4, 5, 0]) {
      await category(tester, index);
      allSectionsExist();
      expect(
        tester.element(find.byKey(const Key('talent-filter-section-0'))),
        same(original),
      );
      expect(controller(tester), same(scroll));
      if (index == 0) {
        expect(scroll.offset, lessThanOrEqualTo(16.1));
      } else {
        expect(scroll.offset, greaterThan(0));
      }
      expect(find.byType(TalentFilterSheet), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.byKey(ValueKey('talent-filter-category-$index')),
      );
      expect(button.style!.foregroundColor!.resolve({}), AppColors.interactive);
    }
  });

  testWidgets('手动滚动联动左侧高亮，城市和其他筛选草稿不丢失', (tester) async {
    await mount(tester);
    await category(tester, 4);
    await tester.enterText(find.byKey(const Key('talent-filter-city')), '合成城市');
    await tester.pumpAndSettle();
    await category(tester, 3);
    await category(tester, 0);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('talent-filter-city')))
          .controller!
          .text,
      '合成城市',
    );
    final scroll = controller(tester);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('talent-filter-category-5')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('talent-filter-category-5')))
          .style!
          .foregroundColor!
          .resolve({}),
      AppColors.interactive,
    );
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('talent-filter-category-0')))
          .style!
          .foregroundColor!
          .resolve({}),
      AppColors.interactive,
    );
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('同页筛选在$size二倍字号与键盘场景可滚动，底部操作固定', (tester) async {
      await mount(tester, size: size, scale: 2);
      final bottom = tester.getRect(
        find.byKey(const Key('talent-filter-apply')),
      );
      for (var index = 0; index < 6; index++) {
        await category(tester, index);
        allSectionsExist();
        expect(
          tester.getRect(find.byKey(const Key('talent-filter-apply'))),
          bottom,
        );
        expect(tester.takeException(), isNull);
      }
      await category(tester, 4);
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 100 : 220,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.byKey(const Key('talent-filter-city')),
        '合成键盘输入',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      allSectionsExist();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
