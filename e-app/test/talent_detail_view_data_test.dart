import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_detail_view_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UTC+8 选择跨日转 UTC 瞬间，提交保持无偏移本地字符串', () {
    final instant = TalentUtc8.fromSelection(DateTime(2026, 10, 16), 0, 15);
    expect(instant, DateTime.utc(2026, 10, 15, 16, 15));
    expect(TalentUtc8.serverTime(instant), '2026-10-16 00:15:00');
    expect(instant.isAfter(DateTime.utc(2026, 10, 15, 16, 14)), isTrue);
    expect(instant.isAfter(DateTime.utc(2026, 10, 15, 16, 16)), isFalse);
  });
  test('UTC+8 跨年和显式偏移均按 UTC 瞬间处理', () {
    final instant = TalentUtc8.fromSelection(DateTime(2027, 1, 1), 0, 5);
    expect(instant, DateTime.utc(2026, 12, 31, 16, 5));
    expect(TalentUtc8.serverTime(instant), '2027-01-01 00:05:00');
    for (final text in [
      '2027-01-01 00:05:00',
      '2027-01-01T00:05:00+08:00',
      '2026-12-31T16:05:00Z',
    ]) {
      expect(TalentUtc8.parseServer(text), instant);
    }
    expect(TalentUtc8.parseServer('invalid'), isNull);
    expect(TalentUtc8.parseServer(null), isNull);
  });
  test('忙闲重叠覆盖跨日、相邻不冲突、空闲槽不占用', () {
    final start = DateTime.utc(2026, 12, 31, 16, 15),
        end = DateTime.utc(2026, 12, 31, 17);
    Map<String, dynamic> slot(int status, String from, String to) => {
      'status': status,
      'startTime': from,
      'endTime': to,
    };
    expect(
      TalentUtc8.isBusy(
        [slot(0, '2026-12-31 23:30:00', '2027-01-01 00:30:00')],
        start,
        end,
      ),
      isTrue,
    );
    expect(
      TalentUtc8.isBusy(
        [
          slot(0, '2027-01-01 00:00:00', '2027-01-01 00:15:00'),
          slot(0, '2027-01-01 01:00:00', '2027-01-01 02:00:00'),
        ],
        start,
        end,
      ),
      isFalse,
    );
    expect(
      TalentUtc8.isBusy(
        [slot(1, '2027-01-01 00:00:00', '2027-01-01 02:00:00')],
        start,
        end,
      ),
      isFalse,
    );
    for (final data in [
      <String, dynamic>{},
      slot(9, '2027-01-01 00:00:00', '2027-01-01 02:00:00'),
      slot(0, 'bad', '2027-01-01 02:00:00'),
    ]) {
      expect(
        () => TalentUtc8.isBusy([data], start, end),
        throwsFormatException,
      );
    }
  });
  test('岗位技能只取必备，候选人归属匹配才读取对应评分', () {
    final detail = {
      'candidates': [
        {'talId': 11, 'currentStage': '技术面'},
      ],
    };
    final profile = {
      'skills': [
        {'name': 'Dart', 'required': 1},
        {'name': 'Git', 'required': null},
        {'name': 'Java', 'required': 0},
      ],
    };
    final scores = [
      {'resultId': 12, 'totalScore': 99},
      {'resultId': 11, 'skillMatch': 80, 'projectMatch': null},
    ];
    final result = TalentMatchData.fromResponses(11, detail, profile, scores);
    expect(result.requiredSkills, ['Dart']);
    expect(result.currentStage, '技术面');
    expect(result.result?['skillMatch'], 80);
    expect(result.result?['projectMatch'], isNull);
    expect(
      TalentMatchData.fromResponses(12, detail, profile, scores).result,
      isNull,
    );
    expect(
      TalentMatchData.fromResponses(11, detail, {}, []).requiredSkills,
      isEmpty,
    );
  });
  test('无效列表和非有限分数不能被解释为零', () {
    expect(() => talentRows({}, '技能'), throwsFormatException);
    expect(() => talentRows([null], '技能'), throwsFormatException);
    for (final value in [null, 'NaN', 'Infinity', 'bad']) {
      expect(talentNumber(value), isNull);
    }
    expect(talentNumber(0), 0);
  });
  test('本地模板只使用实际姓名及可选岗位，不捏造匹配结论', () {
    expect(talentGreetingTemplate(name: '合成姓名'), contains('合成姓名'));
    expect(
      talentGreetingTemplate(
        name: '合成姓名',
        job: const TalentJobContext(positionId: 7, title: '测试岗位'),
      ),
      contains('测试岗位'),
    );
    expect(talentReportValue({'a': null}), contains('"a": null'));
  });
}
