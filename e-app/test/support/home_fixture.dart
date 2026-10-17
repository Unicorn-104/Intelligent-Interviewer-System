import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_models.dart';

class HomeFixture extends HomeDataSource {
  final failures = <String>{};
  bool empty = false;
  int unread = 4;
  int interviewCalls = 0;
  int calendarCalls = 0;
  final calendarDates = <DateTime>[];
  Completer<HomePageSlice<HomeInterview>>? pendingInterviews;
  @override
  DateTime get now => DateTime(2030, 1, 2, 9);
  void check(String part) {
    if (failures.contains(part)) throw const ApiException('连接超时，请稍后重试');
  }

  @override
  Future<HomeIdentity> loadIdentity() async {
    check('identity');
    return const HomeIdentity(company: '示例企业', nickname: '示例招聘经理');
  }

  @override
  Future<int> loadUnread() async {
    check('unread');
    return unread;
  }

  @override
  Future<HomeStats> loadStats() async {
    check('stats');
    return empty
        ? const HomeStats()
        : const HomeStats(
            activePositions: 0,
            pendingInterviews: 4,
            weeklyCompleted: 2,
          );
  }

  @override
  Future<HomePageSlice<HomeApplication>> loadApplications({
    int page = 1,
  }) async {
    check('applications');
    return HomePageSlice(
      empty || page > 1
          ? []
          : List.generate(
              5,
              (index) => HomeApplication({
                'posId': index + 1,
                'title': '示例岗位 ${index + 1}',
                'dept': '研发',
                'city': '示例城市',
                'applicantCount': index,
                'salaryMin': 10000,
                'salaryMax': 20000,
              }),
            ),
    );
  }

  @override
  Future<List<HomeInterview>> loadInterviewsOn(DateTime day) async {
    calendarCalls++;
    calendarDates.add(day);
    check('interviews');
    if (pendingInterviews != null) {
      return (await pendingInterviews!.future).items;
    }
    return empty
        ? []
        : List.generate(4, (index) {
            final start = DateTime.utc(day.year, day.month, day.day, index + 2);
            return HomeInterview(
              raw: {
                'appointmentId': index + 1,
                'positionId': 100 + index,
                'candidateName': '示例候选人 ${index + 1}',
                'positionTitle': '示例面试岗位 ${index + 1}',
                'startTime': HomeInterview.formatServerTime(start),
                'status': 1,
              },
              startTime: start,
              status: 1,
            );
          });
  }

  @override
  Future<HomePageSlice<HomeInterview>> loadInterviews({
    int page = 1,
    int minimum = 3,
    DateTime? from,
  }) async {
    interviewCalls++;
    check('interviews');
    if (pendingInterviews != null) return pendingInterviews!.future;
    return HomePageSlice(
      empty || page > 1
          ? []
          : List.generate(
              4,
              (index) => HomeInterview(
                raw: {
                  'appointmentId': index + 1,
                  'positionId': 100 + index,
                  'candidateName': '示例候选人 ${index + 1}',
                  'positionTitle': '示例面试岗位 ${index + 1}',
                  'startTime': '2030-01-02 10:00',
                  'status': 1,
                },
                startTime: now.add(Duration(hours: index + 1)),
                status: 1,
              ),
            ),
    );
  }
}
