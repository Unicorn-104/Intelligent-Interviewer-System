import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 10, 16);

  test('按整天查询，保留早于当前时刻、取消和完成的真实面试', () async {
    final source = HomeDataSource(
      clock: () => DateTime.utc(2026, 10, 16, 10),
      interviewsLoader:
          ({
            int? status,
            String? from,
            String? to,
            required int pageNum,
            required int pageSize,
          }) async {
            expect(status, isNull);
            expect(from, '2026-10-16 00:00:00');
            expect(to, '2026-10-16 23:59:59');
            expect(pageNum, 1);
            return [
              {
                'appointmentId': 4,
                'status': 1,
                'startTime': '2026-10-16 23:59',
              },
              {
                'appointmentId': 1,
                'status': 3,
                'startTime': '2026-10-16 08:00',
              },
              {
                'appointmentId': 2,
                'status': 2,
                'startTime': '2026-10-16 09:00',
              },
              {
                'appointmentId': 3,
                'status': 0,
                'startTime': '2026-10-16 10:00',
              },
              {
                'appointmentId': 5,
                'status': 1,
                'startTime': '2026-10-17 00:00',
              },
              {'appointmentId': 6, 'status': 1, 'startTime': 'invalid'},
            ];
          },
    );
    final rows = await source.loadInterviewsOn(day);
    expect(rows.map((item) => item.id), ['1', '2', '3', '4']);
    expect(rows.map((item) => item.status), [3, 2, 0, 1]);
  });

  test('带偏移时间按 UTC+8 判断日期，午夜边界不串日', () {
    expect(
      HomeInterview.onDay({
        'startTime': '2026-10-15T16:00:00Z',
        'status': 3,
      }, day),
      isNotNull,
    );
    expect(
      HomeInterview.onDay({
        'startTime': '2026-10-16T15:59:59Z',
        'status': 0,
      }, day),
      isNotNull,
    );
    expect(
      HomeInterview.onDay({
        'startTime': '2026-10-16T16:00:00Z',
        'status': 1,
      }, day),
      isNull,
    );
    expect(
      HomeInterview.onDay({
        'startTime': '2026-10-15 23:59:59',
        'status': 1,
      }, day),
      isNull,
    );
    expect(
      HomeInterview.onDay({
        'startTime': '2026-10-16 08:00',
        'status': 9,
      }, day)!.status,
      9,
    );
  });

  test('读取全部分页并去重，场次数量不只统计第一页', () async {
    final pages = <int>[];
    final source = HomeDataSource(
      interviewsLoader:
          ({
            int? status,
            String? from,
            String? to,
            required int pageNum,
            required int pageSize,
          }) async {
            pages.add(pageNum);
            expect(from, '2026-10-16 00:00:00');
            expect(to, '2026-10-16 23:59:59');
            Map<String, dynamic> row(int id) => {
              'appointmentId': id,
              'status': 1,
              'startTime': '2026-10-16 10:${id.toString().padLeft(2, '0')}',
            };
            return pageNum == 1
                ? List.generate(pageSize, row)
                : [row(19), row(20)];
          },
    );
    final rows = await source.loadInterviewsOn(day);
    expect(pages, [1, 2]);
    expect(rows, hasLength(21));
    expect(rows.last.id, '20');
  });

  test('分页重复时明确报错，不无限请求或展示不完整的场次数量', () async {
    var calls = 0;
    final source = HomeDataSource(
      interviewsLoader:
          ({
            int? status,
            String? from,
            String? to,
            required int pageNum,
            required int pageSize,
          }) async {
            calls++;
            return List.generate(
              pageSize,
              (index) => {
                'appointmentId': index,
                'status': 1,
                'startTime': '2026-10-16 10:00',
              },
            );
          },
    );
    await expectLater(
      source.loadInterviewsOn(day),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 2);
  });
}
