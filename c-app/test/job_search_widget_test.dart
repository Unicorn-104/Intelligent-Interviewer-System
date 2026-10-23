import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/jobs/data/job_search_api.dart';
import 'package:intelligent_interviewer/features/jobs/domain/job_search.dart';
import 'package:intelligent_interviewer/screens/search_screen.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';
import 'package:intelligent_interviewer/widgets/job_card.dart';

const session = AuthSession(
  token: 'synthetic',
  userId: 1,
  userName: 'synthetic',
  nickName: '示例',
);

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class ScenarioSearchApi extends JobSearchApi {
  ScenarioSearchApi() : super(ApiClient());
  final requests = <(JobSearchQuery, int)>[];
  bool failList = false, failOptions = false, many = false;

  @override
  Future<JobSearchPage> list(
    String token,
    JobSearchQuery query, {
    int page = 1,
    int size = 50,
  }) async {
    requests.add((query, page));
    if (failList) throw const ApiException('连接超时，请重试');
    final ids = query.keyword == '无结果'
        ? <int>[]
        : many
        ? (page == 1 ? List.generate(10, (index) => index + 1) : [11, 12])
        : [1];
    return JobSearchPage.fromJson({
      'items': [
        for (final id in ids)
          {
            'id': id,
            'title': '客户端工程师$id',
            'companyName': '示例科技',
            'workCity': '杭州',
            'salaryMin': 22000,
            'salaryMax': 38000,
            'educationRequired': 3,
            'educationText': '本科',
            'experienceRequired': '3-5年',
            'skills': ['Flutter', 'Dart'],
            'appliedFlag': 1,
            'matchScore': 85,
          },
      ],
      'page': page,
      'size': size,
      'total': ids.isEmpty
          ? 0
          : many
          ? 12
          : 1,
      'hasNext': many && page == 1,
    });
  }

  @override
  Future<JobFilterOptions> filterOptions(String token) async {
    if (failOptions) throw const ApiException('筛选服务暂不可用');
    return const JobFilterOptions(
      cities: ['杭州', '北京'],
      categories: ['技术', '产品'],
      experiences: ['3-5年', '5-10年'],
      industries: ['互联网', '制造业'],
      companySizes: ['100-499人', '500-999人'],
    );
  }
}

Future<void> mount(
  WidgetTester tester,
  ScenarioSearchApi api, {
  double width = 390,
  double scale = 1,
  String? keyword,
  bool openFilters = false,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(api.client.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: SearchScreen(
        session: session,
        searchApi: api,
        initialKeyword: keyword,
        openFilters: openFilters,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'filter selections are drafts; confirm combines, cancel and reset stay local',
    (tester) async {
      final api = ScenarioSearchApi();
      await mount(tester, api);
      await tester.tap(find.text('城市'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '杭州'));
      expect(api.requests.length, 1);
      await tester.tap(find.byTooltip('取消筛选'));
      await tester.pumpAndSettle();
      expect(api.requests.length, 1);
      await tester.tap(find.text('城市'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '北京'));
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(api.requests.last.$1.city, '北京');
      await tapVisible(tester, find.text('筛选(1)'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, '3-5年'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, '100-499人'), findsNothing);
      await tapVisible(tester, find.text('工作经验'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '3-5年'));
      await tapVisible(tester, find.text('工作经验').first);
      expect(find.text('3-5年'), findsOneWidget);
      await tapVisible(tester, find.text('所属行业'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '互联网'));
      await tapVisible(tester, find.text('所属行业'));
      await tapVisible(tester, find.text('公司规模'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '100-499人'));
      await tapVisible(tester, find.text('公司规模').first);
      expect(find.text('100-499人'), findsOneWidget);
      expect(api.requests.length, 2);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(api.requests.last.$1.city, '北京');
      expect(api.requests.last.$1.experienceMin, '3-5年');
      expect(api.requests.last.$1.industry, '互联网');
      expect(api.requests.last.$1.companySize, '100-499人');
      expect(find.text('筛选(4)'), findsOneWidget);
      await tapVisible(tester, find.text('筛选(4)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重置'));
      await tester.tap(find.byTooltip('取消筛选'));
      await tester.pumpAndSettle();
      expect(api.requests.last.$1.industry, '互联网');
      await tapVisible(tester, find.text('排序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('薪资优先'));
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(api.requests.last.$1.sort, 'salary');
      expect(api.requests.last.$1.city, '北京');
      await tapVisible(tester, find.text('清空全部'));
      await tester.pumpAndSettle();
      expect(api.requests.last.$1.conditions, isEmpty);
      expect(api.requests.last.$1.sort, 'salary');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyword debounce, options retry, list retry and empty state preserve controls',
    (tester) async {
      final api = ScenarioSearchApi()..failOptions = true;
      await mount(tester, api);
      await tester.tap(find.text('城市'));
      await tester.pumpAndSettle();
      expect(find.text('部分筛选选项加载失败'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '杭州'), findsOneWidget);
      api.failOptions = false;
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '杭州'));
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '无结果');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('共找到 0 个相关职位'), findsOneWidget);
      expect(find.text('没有找到相关职位'), findsOneWidget);
      expect(api.requests.last.$1.city, '杭州');
      api.failList = true;
      await tester.tap(find.byTooltip('清空'));
      await tester.pumpAndSettle();
      expect(find.text('职位加载失败'), findsOneWidget);
      api.failList = false;
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(find.byType(JobCard), findsOneWidget);
      expect(api.requests.last.$1.city, '杭州');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'server total, scroll pagination, detail return and refresh retain search state',
    (tester) async {
      final api = ScenarioSearchApi()..many = true;
      await mount(tester, api);
      expect(find.text('共找到 12 个相关职位'), findsOneWidget);
      final list = find.byType(ListView).first;
      final searchPosition = tester.getTopLeft(find.byType(TextField));
      await tester.drag(list, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(TextField)), searchPosition);
      final scroll = tester.widget<ListView>(list).controller!;
      final offset = scroll.offset;
      await tester.tap(find.byType(JobCard).hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.text('职位详情'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(scroll.offset, offset);
      for (var i = 0; i < 8 && !api.requests.any((r) => r.$2 == 2); i++) {
        await tester.drag(list, const Offset(0, -650));
        await tester.pumpAndSettle();
      }
      expect(api.requests.any((r) => r.$2 == 2), true);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.drag(list, const Offset(0, 450));
      await tester.pumpAndSettle();
      expect(api.requests.last.$2, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow screen and larger text keep filters, cards and sheet usable',
    (tester) async {
      final api = ScenarioSearchApi();
      await mount(tester, api, width: 320, scale: 1.4);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('筛选'));
      await tester.pumpAndSettle();
      expect(find.text('确定').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PC role catalog uses keyword, all-clear removes keyword and selected experience toggles off',
    (tester) async {
      final api = ScenarioSearchApi();
      await mount(tester, api);
      await tapVisible(tester, find.text('职位类别'));
      final roleSearch = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == '查找职位',
      );
      await tester.enterText(roleSearch, 'Java');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('互联网/AI'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Java'));
      await tapVisible(tester, find.text('确定'));
      expect(api.requests.last.$1.keyword, 'Java');
      expect(api.requests.last.$1.category, isEmpty);
      expect(
        api.requests.last.$1.parameters(1, 50).containsKey('positionLabel'),
        false,
      );
      expect(find.byTooltip('移除Java'), findsOneWidget);
      await tapVisible(tester, find.text('清空全部'));
      expect(api.requests.last.$1.keyword, isEmpty);
      expect(api.requests.last.$1.selectedConditions, isEmpty);
      await tapVisible(tester, find.text('经验'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '3-5年'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '3-5年'));
      await tapVisible(tester, find.text('确定'));
      expect(api.requests.last.$1.experienceMin, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'entry opens complete filter sheet; fallback and native back preserve unapplied drafts',
    (tester) async {
      final api = ScenarioSearchApi()..failOptions = true;
      await mount(tester, api, openFilters: true);
      expect(find.text('更多筛选'), findsOneWidget);
      expect(find.text('部分筛选选项加载失败'), findsOneWidget);
      await tapVisible(tester, find.text('工作经验'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '应届生'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(api.requests.length, 1);
      expect(api.requests.single.$1.experienceMin, isEmpty);
      expect(find.text('更多筛选'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
