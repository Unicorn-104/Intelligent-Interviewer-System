import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_pool_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_detail_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_page.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_status_badge.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:enterprise_recruiter/widgets/page_states.dart';
import 'package:enterprise_recruiter/widgets/skeleton_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/talent_detail_fixture.dart';

Map<String, dynamic> candidateRow(
  int id, {
  int status = 2,
  String? name,
  String tags = '',
}) => {
  'talentId': id,
  'name': name ?? '合成候选人$id',
  'status': status,
  'tags': tags,
  'matchedScore': 88,
  'jobDirection': '合成求职方向',
};

class _PoolFixture {
  _PoolFixture(this.rows);
  List<Map<String, dynamic>> rows;
  int? failPage;
  Completer<List<Map<String, dynamic>>>? moreGate;
  final pending = <String, Completer<List<Map<String, dynamic>>>>{};
  final calls = <Map<String, Object?>>[];
  TalentPoolDataSource get source => TalentPoolDataSource(
    loader: load,
    optionsLoader: () async => {
      'directions': ['合成求职方向'],
      'tags': rows
          .expand((row) => talentPoolTags(row['tags']))
          .toSet()
          .toList(),
    },
  );

  Future<List<Map<String, dynamic>>> load({
    String? keyword,
    String? tag,
    required int pageNum,
    required int pageSize,
  }) async {
    calls.add({
      'keyword': keyword,
      'tag': tag,
      'pageNum': pageNum,
      'pageSize': pageSize,
    });
    if (pending[keyword] case final gate?) {
      return gate.future;
    }
    if (pageNum == failPage) {
      throw const ApiException('合成加载失败');
    }
    if (pageNum == 2 && moreGate != null) {
      return moreGate!.future;
    }
    final filtered = rows
        .where(
          (row) =>
              (keyword == null ||
                  keyword.isEmpty ||
                  row['name'].toString().contains(keyword)) &&
              (tag == null ||
                  tag.isEmpty ||
                  talentPoolTags(row['tags']).contains(tag)),
        )
        .toList();
    return filtered.skip((pageNum - 1) * pageSize).take(pageSize).toList();
  }
}

Future<void> _openPool(
  WidgetTester tester,
  _PoolFixture fixture, {
  bool settle = true,
  Size size = const Size(430, 900),
  double textScale = 1,
  Widget Function(Map<String, dynamic>)? detailBuilder,
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
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: TalentPage(source: fixture.source, detailBuilder: detailBuilder),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  }
}

Future<void> reachPool(
  WidgetTester tester,
  Finder finder, {
  double delta = 380,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('talent-list')),
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 65,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> choosePoolStatus(WidgetTester tester, int? status) async {
  await tester.tap(find.byKey(const ValueKey('talent-filter-open')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.byKey(const ValueKey('talent-filter-category-1')));
  await tester.pump(const Duration(milliseconds: 100));
  final option = find.byKey(
    ValueKey(
      status == null
          ? 'talent-filter-status-all'
          : 'talent-filter-status-$status',
    ),
  );
  await tester.ensureVisible(option);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(option);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('talent-filter-apply')));
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> searchPool(
  WidgetTester tester,
  String keyword, {
  bool settle = true,
}) async {
  await tester.enterText(find.byKey(const ValueKey('talent-search')), keyword);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('搜索栏使用一体化青绿描边和右侧搜索按钮，只有一个搜索图标', (tester) async {
    await _openPool(tester, _PoolFixture([]));
    final bar = find.byKey(const Key('talent-search-bar'));
    final decoration =
        tester.widget<DecoratedBox>(bar).decoration as BoxDecoration;
    expect((decoration.border! as Border).top.color, const Color(0xFF00B8B0));
    expect(decoration.borderRadius, BorderRadius.circular(8));
    final field = tester.widget<TextField>(
      find.byKey(const Key('talent-search')),
    );
    expect(field.decoration!.prefixIcon, isNull);
    expect(field.decoration!.enabledBorder, InputBorder.none);
    expect(field.decoration!.focusedBorder, InputBorder.none);
    expect(
      find.descendant(of: bar, matching: find.byIcon(Icons.search)),
      findsOneWidget,
    );
    final button = tester.widget<IconButton>(
      find.byKey(const Key('talent-search-submit')),
    );
    expect(button.style!.backgroundColor!.resolve({}), const Color(0xFF00B8B0));
    expect(button.style!.foregroundColor!.resolve({}), AppColors.canvas);
    final shape = button.style!.shape!.resolve({})! as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      const BorderRadius.horizontal(right: Radius.circular(6.5)),
    );
    expect(decoration.color, const Color(0xFF00B8B0));
    final inputShape = tester.widget<ClipRRect>(
      find.byKey(const Key('talent-search-input-shape')),
    );
    final inputRadius = inputShape.borderRadius.resolve(TextDirection.ltr);
    expect(inputRadius.topLeft, inputRadius.topRight);
    expect(inputRadius.bottomLeft, inputRadius.bottomRight);
    expect(inputRadius, const BorderRadius.all(Radius.circular(6.5)));
    expect(find.byKey(const Key('talent-filter-open')), findsOneWidget);
    final fieldRect = tester.getRect(find.byKey(const Key('talent-search')));
    final buttonRect = tester.getRect(
      find.byKey(const Key('talent-search-submit')),
    );
    expect(fieldRect.right, lessThanOrEqualTo(buttonRect.left));
    expect(buttonRect.right, lessThan(tester.getRect(bar).right));
  });

  testWidgets('新搜索按钮与键盘继续使用原查询逻辑，保留已选筛选条件', (tester) async {
    final fixture = _PoolFixture([
      candidateRow(11, status: 0, name: '合成目标'),
      candidateRow(12, status: 2, name: '合成其他'),
    ]);
    await _openPool(tester, fixture);
    await choosePoolStatus(tester, 0);
    final before = fixture.calls.length;
    await tester.enterText(find.byKey(const Key('talent-search')), ' 目标 ');
    await tester.tap(find.byKey(const Key('talent-search-submit')));
    await tester.pumpAndSettle();
    expect(fixture.calls.length, before + 1);
    expect(fixture.calls.last['keyword'], '目标');
    expect(find.byTooltip('筛选(1)'), findsOneWidget);
    expect(find.byKey(const Key('talent-card-11')), findsOneWidget);
    expect(find.byKey(const Key('talent-card-12')), findsNothing);
    await searchPool(tester, ' 合成 ');
    expect(fixture.calls.last['keyword'], '合成');
    expect(find.byTooltip('筛选(1)'), findsOneWidget);
    expect(find.byKey(const Key('talent-card-12')), findsNothing);
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('一体化搜索栏在$size双倍字号及键盘下不遮挡筛选入口', (tester) async {
      await _openPool(tester, _PoolFixture([]), size: size, textScale: 2);
      final bar = tester.getRect(find.byKey(const Key('talent-search-bar')));
      final filter = tester.getRect(
        find.byKey(const Key('talent-filter-open')),
      );
      expect(bar.right, lessThan(filter.left));
      expect(
        tester.getSize(find.byKey(const Key('talent-search-submit'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('talent-search')));
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 100 : 220,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byKey(const Key('talent-search')), '合成搜索输入');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('talent-filter-open')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('统一筛选入口展开后提供全部招聘状态，取消不应用草稿', (tester) async {
    final fixture = _PoolFixture([candidateRow(11, status: 2)]);
    await _openPool(tester, fixture);
    expect(find.byKey(const Key('talent-filter-open')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.byKey(const Key('talent-filter-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('talent-filter-category-1')));
    await tester.pumpAndSettle();
    for (final status in const [0, 2, 3, 4]) {
      final finder = find.byKey(ValueKey('talent-filter-status-$status'));
      expect(finder, findsOneWidget);
      expect(
        find.descendant(of: finder, matching: find.text(talentStatus(status))),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const Key('talent-filter-status-2')));
    await tester.tap(find.byKey(const Key('talent-filter-close')));
    await tester.pumpAndSettle();
    expect(fixture.calls, hasLength(1));
    await choosePoolStatus(tester, 2);
    expect(find.byKey(const Key('talent-card-11')), findsOneWidget);
    expect(find.byTooltip('筛选(1)'), findsOneWidget);
    await choosePoolStatus(tester, null);
    expect(find.byTooltip('筛选'), findsOneWidget);
    expect(fixture.calls.map((call) => call['pageNum']), [1, 1, 1]);
  });

  testWidgets('候选人管理保留人才库别名，复用状态组件并使用20条API分页', (tester) async {
    final fixture = _PoolFixture([candidateRow(11)]);
    await _openPool(tester, fixture);
    expect(find.text('候选人管理'), findsOneWidget);
    expect(find.text('人才库 · 当前企业全部候选人'), findsOneWidget);
    expect(find.byType(TalentStatusBadge), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('talent-card-11')),
        matching: find.text('待面试'),
      ),
      findsOneWidget,
    );
    expect(find.text('通用评分：88 分'), findsOneWidget);
    expect(find.text('通用评分，非岗位维度'), findsOneWidget);
    expect(fixture.calls.single, {
      'keyword': '',
      'tag': null,
      'pageNum': 1,
      'pageSize': 20,
    });
  });

  testWidgets('关键词与状态组合筛选，不发送标签条件，清除恢复第一页', (tester) async {
    final fixture = _PoolFixture([
      candidateRow(1, status: 2, name: '目标甲', tags: '前端'),
      candidateRow(2, status: 3, name: '目标乙', tags: '前端'),
      candidateRow(3, status: 0, name: '其他', tags: 'Java'),
    ]);
    await _openPool(tester, fixture);
    await searchPool(tester, ' 目标 ');
    expect(fixture.calls.last['keyword'], '目标');
    await choosePoolStatus(tester, 2);
    expect(fixture.calls.last, {
      'keyword': '目标',
      'tag': null,
      'pageNum': 1,
      'pageSize': 20,
    });
    expect(find.byKey(const ValueKey('talent-card-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('talent-card-2')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('talent-clear')));
    await tester.pumpAndSettle();
    expect(fixture.calls.last, {
      'keyword': '',
      'tag': null,
      'pageNum': 1,
      'pageSize': 20,
    });
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('talent-search')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.byTooltip('筛选'), findsOneWidget);
  });

  testWidgets('移除标签和归档入口，空结果保留选中状态，取消不请求', (tester) async {
    final fixture = _PoolFixture([candidateRow(11, tags: 'Java')]);
    await _openPool(tester, fixture);
    final before = fixture.calls.length;
    await tester.tap(find.byKey(const ValueKey('talent-filter-open')));
    await tester.pumpAndSettle();
    expect(find.text('筛选人才'), findsOneWidget);
    await tester.tap(find.byKey(const Key('talent-filter-close')));
    await tester.pumpAndSettle();
    expect(fixture.calls.length, before);
    expect(find.byKey(const Key('talent-filter-tag')), findsNothing);
    await choosePoolStatus(tester, 3);
    expect(fixture.calls.last['tag'], isNull);
    expect(find.text('当前条件无匹配'), findsOneWidget);
    expect(find.textContaining('状态：${talentStatus(3)}'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('talent-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('talent-card-11')), findsOneWidget);
  });

  testWidgets('初始骨架、空态、失败和重试均可达', (tester) async {
    final gate = Completer<List<Map<String, dynamic>>>();
    final fixture = _PoolFixture([])..pending[''] = gate;
    await _openPool(tester, fixture, settle: false);
    expect(find.byType(SkeletonList), findsOneWidget);
    fixture.pending.clear();
    gate.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('暂无候选人'), findsOneWidget);
    fixture.failPage = 1;
    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();
    expect(find.byType(PageMessage), findsOneWidget);
    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('合成加载失败'), findsOneWidget);
    fixture.failPage = null;
    fixture.rows = [candidateRow(11)];
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('talent-card-11')), findsOneWidget);
  });

  testWidgets('加载更多失败保留已有列表，底部重试仍请求同一页', (tester) async {
    final fixture = _PoolFixture(List.generate(23, (i) => candidateRow(i + 1)))
      ..failPage = 2;
    await _openPool(tester, fixture);
    await reachPool(tester, find.byKey(const ValueKey('talent-load-more')));
    await tester.tap(find.byKey(const ValueKey('talent-load-more')));
    await tester.pumpAndSettle();
    expect(find.text('合成加载失败'), findsOneWidget);
    expect(find.text('已加载 20 位候选人'), findsOneWidget);
    expect(fixture.calls.last['pageNum'], 2);
    await reachPool(
      tester,
      find.byKey(const ValueKey('talent-card-1')),
      delta: -380,
    );
    expect(find.text('合成候选人1'), findsOneWidget);
    await reachPool(tester, find.byKey(const ValueKey('talent-page-retry')));
    fixture.failPage = null;
    await tester.tap(find.byKey(const ValueKey('talent-page-retry')));
    await tester.pumpAndSettle();
    await reachPool(tester, find.text('已显示全部'));
    expect(find.text('已加载 23 位候选人'), findsOneWidget);
    expect(fixture.calls.map((call) => call['pageNum']), [1, 2, 2]);
  });

  testWidgets('分页加载有底部loading，重复点击不重复请求，跨页去重', (tester) async {
    final gate = Completer<List<Map<String, dynamic>>>();
    final fixture = _PoolFixture(List.generate(20, (i) => candidateRow(i + 1)))
      ..moreGate = gate;
    await _openPool(tester, fixture);
    await reachPool(tester, find.byKey(const ValueKey('talent-load-more')));
    await tester.tap(find.byKey(const ValueKey('talent-load-more')));
    await tester.pump();
    expect(find.byKey(const ValueKey('talent-page-loading')), findsOneWidget);
    expect(find.text('已加载 20 位候选人'), findsOneWidget);
    expect(fixture.calls.length, 2);
    gate.complete([candidateRow(20, name: '重复行不得替换'), candidateRow(21)]);
    await tester.pumpAndSettle();
    await reachPool(tester, find.text('已显示全部'));
    expect(find.text('已加载 21 位候选人'), findsOneWidget);
    expect(find.text('重复行不得替换'), findsNothing);
    expect(fixture.calls.length, 2);
    expect(find.byKey(const ValueKey('talent-load-more')), findsNothing);
  });

  testWidgets('状态筛选三页上限有明确提示且不能继续加载', (tester) async {
    final fixture = _PoolFixture(
      List.generate(70, (i) => candidateRow(i + 1, status: 2)),
    );
    await _openPool(tester, fixture);
    await choosePoolStatus(tester, 2);
    expect(fixture.calls.skip(1).map((call) => call['pageNum']), [1, 2, 3]);
    await reachPool(tester, find.text('结果较多，请补充关键词'));
    expect(find.text('已加载 60 位候选人'), findsOneWidget);
    expect(find.text('仅检查前3页，当前结果可能不完整'), findsOneWidget);
    expect(find.byKey(const ValueKey('talent-load-more')), findsNothing);
  });

  testWidgets('三页扫描无匹配不得误报全局空结果，状态模式无加载更多', (tester) async {
    final fixture = _PoolFixture(List.generate(70, (i) => candidateRow(i + 1)));
    await _openPool(tester, fixture);
    await choosePoolStatus(tester, 0);
    expect(fixture.calls.skip(1).map((call) => call['pageNum']), [1, 2, 3]);
    expect(find.text('结果较多，请补充关键词'), findsOneWidget);
    expect(find.text('当前条件无匹配'), findsNothing);
    expect(find.byKey(const ValueKey('talent-load-more')), findsNothing);
  });

  testWidgets('新关键词结果不被旧搜索迟到响应覆盖', (tester) async {
    final slow = Completer<List<Map<String, dynamic>>>();
    final fixture = _PoolFixture([candidateRow(11)])..pending['慢'] = slow;
    await _openPool(tester, fixture);
    await searchPool(tester, '慢', settle: false);
    fixture.rows = [candidateRow(12, name: '快结果')];
    await searchPool(tester, '快');
    expect(find.text('快结果'), findsOneWidget);
    slow.complete([candidateRow(99, name: '慢结果')]);
    await tester.pumpAndSettle();
    expect(find.text('快结果'), findsOneWidget);
    expect(find.text('慢结果'), findsNothing);
  });

  testWidgets('分页迟到响应不污染新状态筛选结果', (tester) async {
    final gate = Completer<List<Map<String, dynamic>>>();
    final fixture = _PoolFixture(List.generate(25, (i) => candidateRow(i + 1)))
      ..moreGate = gate;
    await _openPool(tester, fixture);
    await reachPool(tester, find.byKey(const ValueKey('talent-load-more')));
    await tester.tap(find.byKey(const ValueKey('talent-load-more')));
    await tester.pump();
    fixture.rows = [candidateRow(300, status: 2, name: '新状态结果')];
    await choosePoolStatus(tester, 2);
    expect(find.text('新状态结果'), findsOneWidget);
    gate.complete([candidateRow(21)]);
    await tester.pumpAndSettle();
    expect(find.text('新状态结果'), findsOneWidget);
    expect(find.byKey(const ValueKey('talent-card-21')), findsNothing);
  });

  testWidgets('退出后迟到响应不更新已销毁的TalentPage', (tester) async {
    final gate = Completer<List<Map<String, dynamic>>>();
    final fixture = _PoolFixture([])..pending[''] = gate;
    await _openPool(tester, fixture, settle: false);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    gate.complete([candidateRow(11)]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击候选人进入原详情页且无岗位上下文，返回保留筛选', (tester) async {
    final fixture = _PoolFixture([candidateRow(11)]);
    await _openPool(
      tester,
      fixture,
      detailBuilder: (talent) =>
          TalentDetailPage(talent: talent, source: TalentFakeSource()),
    );
    await choosePoolStatus(tester, 2);
    await tester.tap(find.byKey(const ValueKey('talent-card-11')));
    await tester.pumpAndSettle();
    final detail = tester.widget<TalentDetailPage>(
      find.byType(TalentDetailPage),
    );
    expect(detail.talent['talentId'], 11);
    expect(detail.jobContext, isNull);
    expect(find.text('未指定岗位，暂无岗位招聘阶段'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byTooltip('筛选(1)'), findsOneWidget);
    expect(fixture.calls.length, 2);
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('候选人列表和筛选在 $size 无溢出', (tester) async {
      const longTag = '用于合成测试的长标签名称用于核对窄屏展示';
      final fixture = _PoolFixture([
        candidateRow(11, status: 3, name: '合成的较长候选人名称用于核对布局', tags: longTag),
      ]);
      await _openPool(tester, fixture, size: size);
      await choosePoolStatus(tester, 3);
      expect(find.byType(TalentStatusBadge), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('talent-card-11')),
          matching: find.text('已淘汰'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
