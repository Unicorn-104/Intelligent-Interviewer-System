import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/features/jobs/data/job_search_api.dart';
import 'package:intelligent_interviewer/features/jobs/domain/job_search.dart';

void main() {
  test(
    'guest search preserves filters, real paging and anonymous headers',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final requests = <Uri>[];
      final listener = server.listen((request) async {
        requests.add(request.uri);
        expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
        request.response.headers.contentType = ContentType.json;
        final options = request.uri.path.endsWith('filter-options');
        request.response.write(
          jsonEncode({
            'code': 200,
            'data': options
                ? {
                    'cities': ['杭州'],
                    'categories': [],
                    'experiences': [],
                    'industries': [],
                    'companySizes': [],
                  }
                : {
                    'items': [],
                    'page': 2,
                    'size': 10,
                    'total': 31,
                    'hasNext': true,
                  },
          }),
        );
        await request.response.close();
      });
      try {
        final api = JobSearchApi(client);
        final page = await api.list(
          '',
          const JobSearchQuery(
            keyword: 'Java',
            city: '杭州',
            sort: 'salary',
            industry: '互联网',
          ),
          page: 2,
          size: 10,
        );
        expect(page.page, 2);
        expect(page.total, 31);
        expect(page.hasNext, isTrue);
        expect(requests.first.path, '/app/jobs/search');
        expect(requests.first.queryParameters, containsPair('city', '杭州'));
        expect(requests.first.queryParameters, containsPair('industry', '互联网'));
        expect(requests.first.queryParameters, containsPair('sort', 'salary'));
        expect(requests.first.queryParameters, containsPair('page', '2'));
        expect((await api.filterOptions('')).cities, ['杭州']);
        expect(requests.last.path, '/app/jobs/filter-options');
      } finally {
        client.close();
        await listener.cancel();
        await server.close(force: true);
      }
    },
  );
}
