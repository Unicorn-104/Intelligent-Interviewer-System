import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('企业名读取 publishing options，昵称读取用户字段', () async {
    final source = HomeDataSource(
      userLoader: () async => {'nickName': '示例经理'},
      companyLoader: () async => {
        'company': {'name': '示例企业'},
      },
    );
    final result = await source.loadIdentity();
    expect(result.company, '示例企业');
    expect(result.nickname, '示例经理');
  });

  test('统计保留真实零值，缺失待终审不补零，不根据待办条数推算', () async {
    final source = HomeDataSource(
      overviewLoader: () async => {
        'stats': {
          'activePositions': 0,
          'pendingInterviews': 2,
          'weeklyCompleted': 3,
        },
        'todos': [{}, {}],
      },
    );
    final stats = await source.loadStats();
    expect(stats.activePositions, 0);
    expect(stats.pendingReview, isNull);
    expect(stats.weeklyCompleted, 3);
    expect(homeCount(-1), isNull);
    expect(homeCount('1.5'), isNull);
  });

  test('面试传递 from，下界/取消/完成过滤后跨页补足预览，时间升序', () async {
    final pages = <int>[];
    final boundary = DateTime.utc(2030, 1, 2, 1);
    final source = HomeDataSource(
      clock: () => boundary,
      interviewsLoader:
          ({
            int? status,
            String? from,
            String? to,
            required int pageNum,
            required int pageSize,
          }) async {
            pages.add(pageNum);
            expect(from, '2030-01-02 09:00:00');
            expect(pageSize, 20);
            if (pageNum == 1) {
              return List.generate(
                20,
                (index) => {
                  'appointmentId': index,
                  'status': 2,
                  'startTime': '2030-01-02 11:00',
                },
              );
            }
            return [
              {
                'appointmentId': 30,
                'status': 1,
                'startTime': '2030-01-02 12:00',
              },
              {
                'appointmentId': 31,
                'status': 0,
                'startTime': '2030-01-02 10:00',
              },
              {
                'appointmentId': 32,
                'status': 3,
                'startTime': '2030-01-02 11:00',
              },
              {
                'appointmentId': 33,
                'status': 1,
                'startTime': '2030-01-01 12:00',
              },
              {'appointmentId': 34, 'status': 1, 'startTime': 'invalid'},
            ];
          },
    );
    final result = await source.loadInterviews();
    expect(pages, [1, 2]);
    expect(result.items.map((row) => row.id), ['31', '30']);
    expect(result.nextPage, isNull);
  });

  for (final sample in <(DateTime, String)>[
    (DateTime.utc(2026, 10, 15, 14, 32, 26), '2026-10-15 22:32:26'),
    (DateTime.utc(2026, 10, 15, 20, 5, 9), '2026-10-16 04:05:09'),
    (DateTime.utc(2026, 12, 31, 20), '2027-01-01 04:00:00'),
    (DateTime.parse('2026-10-15T22:32:26+08:00'), '2026-10-15 22:32:26'),
  ]) {
    test('已知 UTC 时刻与本地表示发送相同 UTC+8 下界 ${sample.$2}', () async {
      final sent = <String?>[];
      final source = HomeDataSource(
        clock: () => sample.$1,
        interviewsLoader:
            ({
              int? status,
              String? from,
              String? to,
              required int pageNum,
              required int pageSize,
            }) async {
              sent.add(from);
              return [];
            },
      );
      await source.loadInterviews();
      await source.loadInterviews(from: sample.$1.toLocal());
      expect(sent, [sample.$2, sample.$2]);
    });
  }

  test('UTC+8 响应按真实时刻筛选并排序，过去八小时内记录不会误显示', () async {
    final source = HomeDataSource(
      clock: () => DateTime.utc(2026, 10, 15, 14, 32, 26),
      interviewsLoader:
          ({
            int? status,
            String? from,
            String? to,
            required int pageNum,
            required int pageSize,
          }) async {
            expect(from, '2026-10-15 22:32:26');
            return [
              {
                'appointmentId': 1,
                'status': 1,
                'startTime': '2026-10-15 18:00',
              },
              {
                'appointmentId': 2,
                'status': 0,
                'startTime': '2026-10-16 09:00',
              },
              {
                'appointmentId': 3,
                'status': 1,
                'startTime': '2026-10-15 23:00',
              },
            ];
          },
    );
    final result = await source.loadInterviews();
    expect(result.items.map((row) => row.id), ['3', '2']);
    expect(result.items.first.startTime, DateTime.utc(2026, 10, 15, 15));
    expect(result.items.first.timeLabel, '10-15 23:00');
    expect(result.items.last.timeLabel, '10-16 09:00');
  });

  test('带时区与不带时区的同一预约解析结果一致', () {
    final boundary = DateTime.utc(2026, 10, 15, 14);
    final results =
        [
          '2026-10-15 23:00',
          '2026-10-15T23:00:00+08:00',
          '2026-10-15T15:00:00Z',
        ].map(
          (time) => HomeInterview.upcoming({
            'appointmentId': 1,
            'status': 1,
            'startTime': time,
          }, boundary)!,
        );
    for (final result in results) {
      expect(result.startTime, DateTime.utc(2026, 10, 15, 15));
      expect(result.timeLabel, '10-15 23:00');
    }
  });

  test('重复分页响应有界失败，不把第一页反复当成新数据', () async {
    final source = HomeDataSource(
      clock: () => DateTime(2030),
      interviewsLoader:
          ({
            int? status,
            String? from,
            String? to,
            required int pageNum,
            required int pageSize,
          }) async => List.generate(
            20,
            (index) => {
              'appointmentId': index,
              'status': 2,
              'startTime': '2030-01-03 10:00',
            },
          ),
    );
    await expectLater(source.loadInterviews(), throwsA(isA<ApiException>()));
  });

  test('岗位保留服务端顺序、累计数和分页，不伪造新投递时间', () async {
    final source = HomeDataSource(
      jobsLoader:
          ({
            String? keyword,
            String? dept,
            int? status,
            required int pageNum,
            required int pageSize,
          }) async {
            expect(pageNum, 2);
            return List.generate(
              20,
              (index) => {
                'posId': index,
                'title': '岗位 $index',
                'applicantCount': index == 0 ? null : 0,
              },
            );
          },
    );
    final result = await source.loadApplications(page: 2);
    expect(result.nextPage, 3);
    expect(result.items.first.positionId, 0);
    expect(result.items.first.applicants, isNull);
    expect(result.items[1].applicants, 0);
    expect(result.items.first.detail.containsKey('appliedAt'), isFalse);
  });

  test('服务端错误由数据源继续抛出，页面负责独立区块重试', () async {
    final source = HomeDataSource(
      overviewLoader: () async => throw const ApiException('服务错误', code: 500),
    );
    await expectLater(
      source.loadStats(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 500)),
    );
  });
}
