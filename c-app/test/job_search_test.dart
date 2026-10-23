import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/jobs/data/job_search_api.dart';
import 'package:intelligent_interviewer/features/jobs/domain/job_search.dart';
import 'package:intelligent_interviewer/features/jobs/presentation/job_search_controller.dart';

Map<String, dynamic> jobJson(int id) => {
  'id': id,
  'title': '客户端工程师$id',
  'companyName': '示例科技',
  'workCity': '杭州',
  'salaryMin': 22000,
  'salaryMax': 38000,
  'educationRequired': 1,
  'educationText': '学历不限',
  'experienceRequired': '3-5年',
  'skills': ['Flutter'],
  'appliedFlag': 1,
  'matchScore': 88.5,
  'jdJson': '{"description":"开发客户端"}',
};

JobSearchPage page(
  int number,
  List<int> ids, {
  bool hasNext = false,
  int total = 3,
}) => JobSearchPage.fromJson({
  'items': ids.map((id) => {...jobJson(id), 'appliedFlag': 0}).toList(),
  'page': number,
  'size': 50,
  'total': total,
  'hasNext': hasNext,
});

class PendingSearchApi extends JobSearchApi {
  PendingSearchApi() : super(ApiClient());
  final requests = <(JobSearchQuery, int, Completer<JobSearchPage>)>[];
  @override
  Future<JobSearchPage> list(
    String token,
    JobSearchQuery query, {
    int page = 1,
    int size = 50,
  }) {
    final pending = Completer<JobSearchPage>();
    requests.add((query, page, pending));
    return pending.future;
  }
}

void main() {
  test(
    'PC endpoints, combined parameters, auth and dynamic options match the wire contract',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final requests = <Uri>[];
      final listener = server.listen((request) async {
        requests.add(request.uri);
        expect(request.method, 'GET');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer synthetic-session',
        );
        final Object data;
        if (request.uri.path == '/agent/v1/jobs/filter-options') {
          data = {
            'cities': ['杭州'],
            'categories': ['技术'],
            'experiences': ['3-5年'],
            'industries': ['互联网'],
            'companySizes': ['100-499人'],
            'employmentTypes': [1],
            'educations': [3],
          };
        } else {
          expect(request.uri.path, '/agent/v1/jobs');
          data = {
            'items': [jobJson(7)],
            'page': 2,
            'size': 50,
            'total': 51,
            'hasNext': false,
          };
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'code': 200, 'data': data}));
        await request.response.close();
      });
      try {
        final api = JobSearchApi(client);
        final result = await api.list(
          'synthetic-session',
          const JobSearchQuery(
            keyword: ' Flutter ',
            sort: 'salary',
            city: '杭州',
            category: '技术',
            experienceMin: '3-5年',
            industry: '互联网',
            companySize: '100-499人',
          ),
          page: 2,
        );
        expect(requests.last.queryParameters, {
          'keyword': 'Flutter',
          'sort': 'salary',
          'city': '杭州',
          'category': '技术',
          'experienceMin': '3-5年',
          'industry': '互联网',
          'companySize': '100-499人',
          'page': '2',
          'size': '50',
        });
        expect(result.total, 51);
        final job = result.items.single;
        expect(job.positionId, 7);
        expect(job.salary, '22–38K');
        expect(job.educationLabel, '学历不限');
        expect(job.copyWith(applied: true).educationLabel, '学历不限');
        expect(job.applied, true);
        expect(job.match, 89);
        expect(job.description, '开发客户端');
        final unscored = SearchJobDto.fromJson({
          ...jobJson(9),
          'matchScore': null,
        }).toJob();
        expect(unscored.matchLabel, '待评估');
        expect(unscored.copyWith(applied: true).matchAvailable, false);
        final options = await api.filterOptions('synthetic-session');
        expect(options.experiences, ['3-5年']);
        await api.list('synthetic-session', const JobSearchQuery());
        expect(requests.last.queryParameters, {
          'sort': 'match',
          'page': '1',
          'size': '50',
        });
      } finally {
        client.close();
        await listener.cancel();
        await server.close(force: true);
      }
    },
  );

  test(
    'incomplete responses fail explicitly; optional invalid JD cannot discard a job',
    () {
      expect(
        () => JobSearchPage.fromJson({'items': []}),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => JobFilterOptions.fromJson({
          'cities': ['杭州'],
        }),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => SearchJobDto.fromJson({'title': '缺少标识'}),
        throwsA(isA<ApiException>()),
      );
      final job = SearchJobDto.fromJson({
        ...jobJson(1),
        'jdJson': 'invalid',
        'responsibilities': ['开发', '维护'],
      }).toJob();
      expect(job.description, '开发\n维护');
    },
  );

  test(
    'a newer condition invalidates an old response during keyword debounce',
    () async {
      final api = PendingSearchApi();
      final controller = JobSearchController(api, 'synthetic');
      addTearDown(() {
        controller.dispose();
        api.client.close();
      });
      final old = controller.refresh();
      controller.prepare(const JobSearchQuery(keyword: '新关键词', city: '杭州'));
      api.requests[0].$3.complete(page(1, [1]));
      await old;
      expect(controller.items, isEmpty);
      expect(controller.loading, true);
      final current = controller.refresh();
      api.requests[1].$3.complete(page(1, [2]));
      await current;
      expect(controller.items.single.positionId, 2);
      expect(api.requests[1].$1.keyword, '新关键词');
    },
  );

  test(
    'pagination retries the failed page, refresh retries page one and retains conditions',
    () async {
      final api = PendingSearchApi();
      final controller = JobSearchController(
        api,
        'synthetic',
        query: const JobSearchQuery(city: '杭州'),
      );
      addTearDown(() {
        controller.dispose();
        api.client.close();
      });
      var pending = controller.refresh();
      api.requests.last.$3.complete(page(1, [1], hasNext: true, total: 21));
      await pending;
      pending = controller.loadMore();
      api.requests.last.$3.completeError(const ApiException('网络中断'));
      await pending;
      expect(controller.items.length, 1);
      pending = controller.retry();
      expect(api.requests.last.$2, 2);
      expect(api.requests.last.$1.city, '杭州');
      api.requests.last.$3.complete(page(2, [1, 2], hasNext: true));
      await pending;
      expect(controller.items.map((job) => job.positionId), [1, 2]);
      pending = controller.refresh();
      api.requests.last.$3.completeError(const ApiException('刷新失败'));
      await pending;
      pending = controller.retry();
      expect(api.requests.last.$2, 1);
      api.requests.last.$3.complete(page(1, [3]));
      await pending;
      expect(controller.items.single.positionId, 3);
    },
  );

  test(
    'filter changes discard pending pagination and keep successful local application updates',
    () async {
      final api = PendingSearchApi();
      final controller = JobSearchController(api, 'synthetic');
      addTearDown(api.client.close);
      var pending = controller.refresh();
      api.requests.last.$3.complete(page(1, [1], hasNext: true));
      await pending;
      final more = controller.loadMore();
      pending = controller.refresh(next: const JobSearchQuery(industry: '互联网'));
      expect(api.requests.last.$2, 1);
      controller.markApplied(2);
      api.requests.last.$3.complete(page(1, [2]));
      await pending;
      api.requests[1].$3.complete(page(2, [3]));
      await more;
      expect(controller.items.single.positionId, 2);
      expect(controller.items.single.applied, true);
      final disposed = controller.refresh();
      controller.dispose();
      api.requests.last.$3.complete(page(1, [4]));
      await disposed;
    },
  );
}
