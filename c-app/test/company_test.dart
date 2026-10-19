import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/companies/data/company_api.dart';
import 'package:intelligent_interviewer/features/companies/domain/company.dart';
import 'package:intelligent_interviewer/features/companies/presentation/company_controller.dart';
import 'package:intelligent_interviewer/features/jobs/domain/job_search.dart';
import 'package:intelligent_interviewer/features/messages/domain/app_message.dart';
import 'company_test_support.dart';

void main() {
  test(
    'company API hides server diagnostics and preserves error codes',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final subscription = server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'code': 500,
            'msg': '### SQLSyntaxErrorException: private server path',
          }),
        );
        await request.response.close();
      });
      try {
        await expectLater(
          CompanyApi(client).detail(session.token, 7),
          throwsA(
            isA<ApiException>()
                .having((error) => error.code, 'code', 500)
                .having((error) => error.message, 'message', '服务暂时不可用，请稍后重试'),
          ),
        );
      } finally {
        client.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
  test(
    'company identity survives job adapters and company messages use target URL, not interest ID',
    () {
      final mapped = SearchJobDto.fromJson({
        'id': 9,
        'companyId': 7,
        'companyName': 'Synthetic',
      }).toJob();
      expect(mapped.companyId, 7);
      expect(mapped.copyWith(applied: true).companyId, 7);
      AppMessage message(String? target, {String category = 'COMPANY'}) =>
          AppMessage.fromJson({
            'sourceId': 999,
            'category': category,
            'targetUrl': target,
          });
      expect(message('/companies/7').companyId, 7);
      expect(message('/companies/7?positionId=99').companyId, 7);
      expect(message('/companies/7', category: 'SYSTEM').companyId, isNull);
      for (final invalid in [
        null,
        '/companies/0',
        '/companies/not-an-id',
        'https://example.com/companies/7',
        '//example.com/companies/7',
        '/companies/7/jobs',
      ]) {
        expect(message(invalid).companyId, isNull);
      }
    },
  );

  test(
    'API uses authenticated company paths, explicit follow state and server paging',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final requests = <String>[];
      final subscription = server.listen((request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer synthetic-session',
        );
        requests.add('${request.method} ${request.uri}');
        Object data;
        if (request.method == 'PUT') {
          expect(jsonDecode(await utf8.decoder.bind(request).join()), {
            'followed': true,
          });
          data = {'followed': true};
        } else if (request.uri.path.endsWith('/jobs')) {
          expect(request.uri.queryParameters, {'page': '2', 'size': '10'});
          data = {
            'items': [
              {'id': 9, 'companyId': 7},
            ],
            'page': 2,
            'size': 10,
            'total': 12,
            'hasNext': false,
          };
        } else if (request.uri.path.endsWith('/favorites')) {
          data = {
            'items': [
              {'id': 7, 'name': 'Synthetic', 'followed': true},
            ],
            'page': 1,
            'total': 1,
            'hasNext': false,
          };
        } else {
          data = {'id': 7, 'name': 'Synthetic', 'followed': false};
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'code': 200, 'data': data}));
        await request.response.close();
      });
      try {
        final api = CompanyApi(client);
        expect((await api.detail(session.token, 7)).followed, false);
        expect(await api.setFollowed(session.token, 7, true), true);
        expect(
          (await api.jobs(session.token, 7, page: 2)).items.single.companyId,
          7,
        );
        expect((await api.favorites(session.token)).items.single.id, 7);
        expect(requests, [
          'GET /app/companies/7',
          'PUT /app/companies/7/follow',
          'GET /app/companies/7/jobs?page=2&size=10',
          'GET /app/companies/favorites?page=1&size=20',
        ]);
      } finally {
        client.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );

  test(
    'follow prevents duplicate writes and keeps server-confirmed state on failure',
    () async {
      final api = FakeCompanyApi();
      final controller = CompanyController(api, session.token, 7);
      await controller.refresh();
      final pending = Completer<bool>();
      api.onFollow = (_) => pending.future;
      final save = controller.toggleFollow();
      expect(controller.saving, true);
      await controller.toggleFollow();
      expect(api.followValues, [true]);
      expect(controller.company!.followed, false);
      pending.complete(true);
      await save;
      expect(controller.company!.followed, true);
      api.onFollow = (_) => Future.error(const ApiException('收藏失败，请重试'));
      expect(await controller.toggleFollow(), '收藏失败，请重试');
      expect(controller.company!.followed, true);
      expect(controller.saving, false);
      controller.dispose();
      api.client.close();
    },
  );

  test(
    'paging retries the same page, deduplicates and ignores stale refresh responses',
    () async {
      final api = FakeCompanyApi();
      api.onJobs = (number) async => page([job(1)], number, true);
      final controller = CompanyController(api, session.token, 7);
      await controller.refresh();
      api.onJobs = (_) => Future.error(const ApiException('重试'));
      await controller.loadMore();
      expect(controller.jobs.single.positionId, 1);
      expect(controller.failedLoadMore, true);
      api.onJobs = (number) async => page([job(1), job(2)], number, false);
      await controller.loadMore();
      expect(api.jobPages, [1, 2, 2]);
      expect(controller.jobs.map((j) => j.positionId), [1, 2]);
      controller.markApplied(2);
      expect(controller.jobs.last.applied, true);
      final old = Completer<Company>();
      api.onDetail = () => old.future;
      final first = controller.refresh();
      api.onDetail = () async => company.withFollowed(true);
      await controller.refresh();
      old.complete(company);
      await first;
      expect(controller.company!.followed, true);
      final disposed = Completer<Company>();
      api.onDetail = () => disposed.future;
      final loading = controller.refresh();
      controller.dispose();
      disposed.complete(company);
      await loading;
      api.client.close();
    },
  );
}
