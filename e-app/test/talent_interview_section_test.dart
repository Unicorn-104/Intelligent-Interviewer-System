import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_section.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/talent_detail_fixture.dart';

void main() {
  testWidgets('面试记录客户端按候选人过滤，刷新保留组件状态', (tester) async {
    final source = TalentFakeSource()
      ..interviewPages = [
        [
          {
            'candidateId': 11,
            'positionTitle': '本候选人岗位',
            'startTime': '2027-01-01 09:00:00',
          },
          {'candidateId': 12, 'positionTitle': '其他候选人岗位'},
        ],
      ];
    await pumpTalentWidget(
      tester,
      TalentInterviewSection(candidateId: 11, source: source),
    );
    expect(find.text('本候选人岗位'), findsOneWidget);
    expect(find.text('其他候选人岗位'), findsNothing);
    await tester.tap(find.byTooltip('刷新面试安排'));
    await tester.pumpAndSettle();
    expect(source.interviewQueries.length, 2);
    expect(source.interviewQueries.first['pageSize'], 50);
    expect(find.text('筛选日期'), findsOneWidget);
  });
  testWidgets('面试每页 50，探测第 101 条后提示缩小日期范围', (tester) async {
    final source = TalentFakeSource()
      ..interviewPages = [
        List.generate(50, (i) => {'candidateId': 11, 'positionTitle': '记录$i'}),
        List.generate(
          50,
          (i) => {'candidateId': 11, 'positionTitle': '记录${i + 50}'},
        ),
        [
          {'candidateId': 11, 'positionTitle': '超量记录'},
        ],
      ];
    await pumpTalentWidget(
      tester,
      TalentInterviewSection(candidateId: 11, source: source),
    );
    expect(source.interviewQueries.map((q) => q['pageNum']), [1, 2, 3]);
    expect(source.interviewQueries.every((q) => q['pageSize'] == 50), isTrue);
    expect(find.text('面试记录超过 100 条，请选择更短的日期范围'), findsOneWidget);
    expect(find.text('记录0'), findsNothing);
  });
}
