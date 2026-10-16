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
  TalentPoolDataSource get source => TalentPoolDataSource(loader: load);

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
  Widget Function(Map<String, dynamic>)? detailBuilder,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
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
  final chip = find.byKey(
    ValueKey(status == null ? 'talent-status-all' : 'talent-status-$status'),
  );
  await tester.ensureVisible(chip);
  await tester.pump();
  await tester.tap(chip);
  await tester.pump();
  // Advance chip selection without waiting for an intentionally pending page request.
  for (var frame = 0; frame < 3; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> choosePoolTag(WidgetTester tester, String tag) async {
  await tester.tap(find.byKey(const ValueKey('talent-tag-filter')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('talent-tag-input')), tag);
  await tester.tap(find.byKey(const ValueKey('talent-tag-apply')));
  await tester.pumpAndSettle();
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
  testWidgets('全部及0到9状态chips横向滚动，蓝白选中态及状态图标映射正确', (tester) async {
    final fixture = _PoolFixture([candidateRow(11, status: 1)]);
    await _openPool(tester, fixture);
    expect(find.byType(ChoiceChip), findsNWidgets(11));
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('talent-status')),
          )
          .scrollDirection,
      Axis.horizontal,
    );
    final allFinder = find.byKey(const ValueKey('talent-status-all'));
    final all = tester.widget<ChoiceChip>(allFinder);
    expect(
      find.descendant(of: allFinder, matching: find.text('全部')),
      findsOneWidget,
    );
    expect(all.selected, isTrue);
    expect(all.selectedColor, AppColors.interactive);
    expect(all.labelStyle?.color, AppColors.canvas);
    for (var status = 0; status <= 9; status++) {
      final finder = find.byKey(ValueKey('talent-status-$status'));
      final chip = tester.widget<ChoiceChip>(finder);
      final visual = TalentStatusBadge.visualFor(status);
      expect(
        find.descendant(of: finder, matching: find.text(talentStatus(status))),
        findsOneWidget,
      );
      expect(chip.selected, isFalse);
      expect(chip.backgroundColor, AppColors.interactiveSoft);
      expect(chip.labelStyle?.color, AppColors.interactive);
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: finder, matching: find.byIcon(visual.$1)),
            )
            .color,
        visual.$2,
      );
    }
    await choosePoolStatus(tester, 1);
    final selected = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('talent-status-1')),
    );
    expect(selected.selected, isTrue);
    expect(selected.selectedColor, AppColors.interactive);
    expect(selected.labelStyle?.color, AppColors.canvas);
    expect(find.byKey(const ValueKey('talent-card-11')), findsOneWidget);
    await choosePoolStatus(tester, null);
    expect(tester.widget<ChoiceChip>(allFinder).selected, isTrue);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('talent-status-1')))
          .selected,
      isFalse,
    );
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
        matching: find.text('面试中'),
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

  testWidgets('关键词标签服务端组合过滤，状态客户端过滤，清除恢复第一页', (tester) async {
    final fixture = _PoolFixture([
      candidateRow(1, status: 1, name: '目标甲', tags: '前端'),
      candidateRow(2, status: 2, name: '目标乙', tags: '前端'),
      candidateRow(3, status: 1, name: '其他', tags: 'Java'),
    ]);
    await _openPool(tester, fixture);
    await searchPool(tester, ' 目标 ');
    expect(fixture.calls.last['keyword'], '目标');
    await choosePoolTag(tester, ' 前端 ');
    await choosePoolStatus(tester, 1);
    expect(fixture.calls.last, {
      'keyword': '目标',
      'tag': '前端',
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
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('talent-status-all')))
          .selected,
      isTrue,
    );
  });

  testWidgets('标签可手输，空结果保留选中标签，取消标签面板不请求', (tester) async {
    final fixture = _PoolFixture([candidateRow(11, tags: 'Java')]);
    await _openPool(tester, fixture);
    final before = fixture.calls.length;
    await tester.tap(find.byKey(const ValueKey('talent-tag-filter')));
    await tester.pumpAndSettle();
    expect(find.text('已加载记录中的标签建议'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(fixture.calls.length, before);
    await choosePoolTag(tester, '未出现过的标签');
    expect(fixture.calls.last['tag'], '未出现过的标签');
    expect(find.text('当前条件无匹配'), findsOneWidget);
    expect(find.text('标签：未出现过的标签'), findsOneWidget);
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
      List.generate(70, (i) => candidateRow(i + 1, status: 1)),
    );
    await _openPool(tester, fixture);
    await choosePoolStatus(tester, 1);
    expect(fixture.calls.skip(1).map((call) => call['pageNum']), [1, 2, 3]);
    await reachPool(tester, find.text('结果较多，请补充关键词'));
    expect(find.text('已加载 60 位候选人'), findsOneWidget);
    expect(find.text('仅检查前3页，当前结果可能不完整'), findsOneWidget);
    expect(find.byKey(const ValueKey('talent-load-more')), findsNothing);
  });

  testWidgets('三页扫描无匹配不得误报全局空结果，状态模式无加载更多', (tester) async {
    final fixture = _PoolFixture(List.generate(70, (i) => candidateRow(i + 1)));
    await _openPool(tester, fixture);
    await choosePoolStatus(tester, 1);
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
    fixture.rows = [candidateRow(300, status: 1, name: '新状态结果')];
    await choosePoolStatus(tester, 1);
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
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('talent-status-2')))
          .selected,
      isTrue,
    );
    expect(fixture.calls.length, 2);
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('候选人列表和筛选在 $size 无溢出', (tester) async {
      const longTag = '用于合成测试的长标签名称用于核对窄屏展示';
      final fixture = _PoolFixture([
        candidateRow(11, status: 9, name: '合成的较长候选人名称用于核对布局', tags: longTag),
      ]);
      await _openPool(tester, fixture, size: size);
      await choosePoolTag(tester, longTag);
      expect(find.byType(TalentStatusBadge), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('talent-card-11')),
          matching: find.text('流程挂起'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
