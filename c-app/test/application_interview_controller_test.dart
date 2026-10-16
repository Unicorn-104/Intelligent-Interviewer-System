import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/applications/data/application_api.dart';
import 'package:intelligent_interviewer/features/applications/presentation/application_controller.dart';
import 'package:intelligent_interviewer/features/interviews/data/interview_api.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/interview_controller.dart';

class ControlledClient extends ApiClient {
  final paths = <Uri>[];
  final responses = <Completer<Map<String, dynamic>>>[];
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Duration timeout = const Duration(seconds: 30),
  }) {
    paths.add(Uri.parse(path));
    final response = Completer<Map<String, dynamic>>();
    responses.add(response);
    return response.future;
  }
}

Map<String, dynamic> page(
  List<int> ids, {
  int number = 1,
  bool hasNext = false,
}) => {
  'data': {
    'items': ids
        .map((id) => {'id': id, 'status': 'active', 'statusText': '待处理'})
        .toList(),
    'page': number,
    'size': 10,
    'total': 30,
    'hasNext': hasNext,
  },
};

void main() {
  test('filter changes discard a slow previous response', () async {
    final client = ControlledClient();
    final controller = ApplicationController(
      ApplicationApi(client),
      'test-session',
    );
    final first = controller.refresh();
    final second = controller.refresh(filter: 'closed', changeFilter: true);
    client.responses[1].complete(page([2]));
    await second;
    client.responses[0].complete(page([1]));
    await first;
    expect(controller.items.single.id, 2);
    expect(controller.status, 'closed');
    expect(controller.loading, false);
    controller.dispose();
    client.close();
  });

  test(
    'pagination retries the failed page, deduplicates and stops at hasNext false',
    () async {
      final client = ControlledClient();
      final controller = ApplicationController(
        ApplicationApi(client),
        'test-session',
      );
      final first = controller.refresh();
      client.responses[0].complete(page([1], hasNext: true));
      await first;
      final more = controller.loadMore();
      await controller.loadMore();
      expect(client.responses.length, 2);
      client.responses[1].completeError(const ApiException('网络中断'));
      await more;
      expect(controller.items.single.id, 1);
      final retry = controller.retry();
      expect(client.paths.last.queryParameters['page'], '2');
      client.responses[2].complete(page([1, 2], number: 2));
      await retry;
      expect(controller.items.map((item) => item.id), [1, 2]);
      await controller.loadMore();
      expect(client.responses.length, 3);
      controller.dispose();
      client.close();
    },
  );

  test(
    'failed refresh retries page one even when previous items remain',
    () async {
      final client = ControlledClient();
      final controller = ApplicationController(
        ApplicationApi(client),
        'test-session',
      );
      final first = controller.refresh();
      client.responses[0].complete(page([1]));
      await first;
      final refresh = controller.refresh();
      client.responses[1].completeError(const ApiException('超时'));
      await refresh;
      final retry = controller.retry();
      expect(client.paths.last.queryParameters['page'], '1');
      client.responses[2].complete(page([3]));
      await retry;
      expect(controller.items.single.id, 3);
      controller.dispose();
      client.close();
    },
  );

  test(
    'calendar uses month boundaries, ignores stale month, sorts and groups',
    () async {
      final client = ControlledClient();
      final controller = InterviewController(
        InterviewApi(client),
        'test-session',
        now: () => DateTime(2026, 12, 31, 8),
      );
      final first = controller.load();
      final second = controller.changeMonth(1);
      expect(client.paths.last.queryParameters, {
        'from': '2027-01-01',
        'to': '2027-02-01',
      });
      client.responses[1].complete({
        'data': [
          {
            'appointmentId': 2,
            'startAt': '2027-01-01 10:00',
            'statusText': '已结束',
          },
          {
            'appointmentId': 1,
            'startAt': '2027-01-01 09:00',
            'statusText': '待面试',
          },
          {
            'appointmentId': 3,
            'startAt': '2027-01-02 08:00',
            'statusText': '待面试',
          },
        ],
      });
      await second;
      client.responses[0].complete({'data': []});
      await first;
      expect(controller.selectedDate, '2027-01-01');
      expect(controller.selectedItems.map((i) => i.appointmentId), [1, 2]);
      expect(controller.upcoming.map((i) => i.appointmentId), [1, 3]);
      expect(controller.markedDates, {'2027-01-01', '2027-01-02'});
      controller.select(DateTime(2027, 1, 2));
      expect(controller.selectedItems.single.appointmentId, 3);
      final today = controller.today();
      expect(controller.selectedDate, '2026-12-31');
      client.responses[2].complete({'data': []});
      await today;
      expect(controller.items, isEmpty);
      controller.dispose();
      client.close();
    },
  );

  test('late responses after dispose do not notify dead controllers', () async {
    final client = ControlledClient();
    final applications = ApplicationController(
      ApplicationApi(client),
      'test-session',
    );
    final pending = applications.refresh();
    applications.dispose();
    client.responses[0].complete(page([1]));
    await pending;
    final interviews = InterviewController(
      InterviewApi(client),
      'test-session',
    );
    final calendar = interviews.load();
    interviews.dispose();
    client.responses[1].complete({'data': []});
    await calendar;
    client.close();
  });
}
