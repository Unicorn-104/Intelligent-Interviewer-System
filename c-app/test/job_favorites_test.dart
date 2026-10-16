import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/jobs/data/job_favorite_api.dart';
import 'package:intelligent_interviewer/features/jobs/domain/job_favorites_page.dart';
import 'package:intelligent_interviewer/features/jobs/presentation/job_favorite_controller.dart';
import 'package:intelligent_interviewer/features/jobs/presentation/job_favorites_controller.dart';
import 'job_favorites_test_support.dart';

void main() {
  test(
    'API uses bearer identity, explicit desired state and backend pagination',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final api = JobFavoriteApi(client);
      final calls = <String>[];
      final subscription = server.listen((request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer synthetic',
        );
        calls.add('${request.method} ${request.uri}');
        Object data = {'favorited': false};
        if (request.method == 'PUT') {
          final body = jsonDecode(await utf8.decoder.bind(request).join());
          expect(body, {'favorited': true});
          data = {'favorited': true};
        } else if (request.uri.path.endsWith('/favorites')) {
          data = {
            'items': [
              {'positionId': 91, 'companyId': 7, 'available': false},
            ],
            'page': 2,
            'size': 20,
            'total': 21,
            'hasNext': false,
          };
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'code': 200, 'data': data}));
        await request.response.close();
      });
      try {
        expect(await api.state('synthetic', 91), false);
        expect(await api.setFavorited('synthetic', 91, true), true);
        final page = await api.favorites('synthetic', page: 2);
        expect(page.items.single.positionId, 91);
        expect(page.items.single.copyWith(applied: true).available, false);
        expect(page.items.single.matchAvailable, false);
        expect(page.total, 21);
        expect(calls, [
          'GET /app/jobs/91/favorite',
          'PUT /app/jobs/91/favorite',
          'GET /app/jobs/favorites?page=2&size=20',
        ]);
      } finally {
        client.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );

  test(
    'API masks diagnostics, rejects unconfirmed state and preserves expired-session handling',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final api = JobFavoriteApi(client);
      var response = <String, dynamic>{
        'code': 500,
        'msg': 'SQL internal path and diagnostic',
      };
      final subscription = server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      try {
        await expectLater(
          api.state('synthetic', 91),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              '服务暂时不可用，请稍后重试',
            ),
          ),
        );
        response = {
          'code': 200,
          'data': {'favorited': 'true'},
        };
        await expectLater(
          api.state('synthetic', 91),
          throwsA(isA<ApiException>()),
        );
        response = {'code': 401, 'msg': '登录已失效'};
        final expired = ApiClient.unauthorizedTokens.first;
        await expectLater(
          api.state('synthetic', 91),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 401)),
        );
        expect(await expired, 'synthetic');
      } finally {
        client.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );

  test(
    'malformed favorite items and paging fail instead of appearing empty',
    () {
      for (final data in [
        {'items': [], 'page': 0, 'total': 0, 'hasNext': false},
        {
          'items': [{}],
          'page': 1,
          'total': 1,
          'hasNext': false,
        },
        {'items': [], 'page': 1, 'total': 0},
      ]) {
        expect(
          () => JobFavoritesPage.fromJson(data),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );

  test(
    'detail blocks unknown state and double taps, preserves state on failure and reloads persisted state',
    () async {
      final api = FakeJobFavoriteApi();
      addTearDown(api.client.close);
      final controller = JobFavoriteController(api, 'synthetic', 91);
      addTearDown(controller.dispose);
      expect(await controller.toggle(), isNull);
      api.onState = () async => throw const ApiException('稍后重试');
      await controller.load();
      expect(controller.loaded, false);
      expect(controller.error, '稍后重试');
      api.onState = () async => true;
      await controller.load();
      expect(controller.favorited, true);
      final save = Completer<bool>();
      api.onSave = (_, _) => save.future;
      final pending = controller.toggle();
      expect(await controller.toggle(), isNull);
      expect(api.saves, [(91, false)]);
      save.completeError(const ApiException('网络失败'));
      expect(await pending, '网络失败');
      expect(controller.favorited, true);
      api.onSave = null;
      expect(await controller.toggle(), '已取消收藏');
      expect(controller.favorited, false);
      final reopened = JobFavoriteController(api, 'synthetic', 91);
      api.onState = null;
      await reopened.load();
      expect(reopened.favorited, false);
      reopened.dispose();
    },
  );

  test(
    'refresh ignores stale next-page response, and failed next page retries same offset',
    () async {
      final api = FakeJobFavoriteApi();
      addTearDown(api.client.close);
      final controller = JobFavoritesController(api, 'synthetic');
      addTearDown(controller.dispose);
      api.onPage = (_) async => favoritePage([favoriteJob(91)], next: true);
      await controller.load();
      final older = Completer<JobFavoritesPage>();
      api.onPage = (_) => older.future;
      final pending = controller.load(more: true);
      api.onPage = (_) async => favoritePage([favoriteJob(92)], next: true);
      await controller.load();
      older.complete(favoritePage([favoriteJob(93)], page: 2));
      await pending;
      expect(controller.items.map((j) => j.positionId), [92]);
      api.onPage = (_) async => throw const ApiException('重试');
      await controller.load(more: true);
      expect(controller.page, 1);
      expect(controller.failedMore, true);
      api.onPage = (_) async =>
          favoritePage([favoriteJob(92), favoriteJob(94)], page: 2);
      await controller.load(more: true);
      expect(controller.items.map((j) => j.positionId), [92, 94]);
      expect(api.pages, [1, 2, 1, 2, 2]);
    },
  );

  test(
    'cancellation invalidates old reads and resets paging while preventing concurrent removals',
    () async {
      final api = FakeJobFavoriteApi();
      addTearDown(api.client.close);
      final controller = JobFavoritesController(api, 'synthetic');
      addTearDown(controller.dispose);
      api.onPage = (_) async => favoritePage([favoriteJob(91)], next: true);
      await controller.load();
      final oldPage = Completer<JobFavoritesPage>();
      api.onPage = (_) => oldPage.future;
      final more = controller.load(more: true);
      final refresh = Completer<JobFavoritesPage>();
      api.onPage = (_) => refresh.future;
      final removal = controller.remove(favoriteJob(91));
      await Future<void>.delayed(Duration.zero);
      expect(controller.removingId, 91);
      expect(await controller.remove(favoriteJob(92)), isNull);
      oldPage.complete(favoritePage([favoriteJob(91)], page: 2));
      await more;
      expect(controller.items, isEmpty);
      refresh.complete(favoritePage([favoriteJob(92)], next: true));
      expect(await removal, '已取消收藏');
      expect(controller.items.map((j) => j.positionId), [92]);
      expect(controller.page, 1);
      expect(api.pages, [1, 2, 1]);
    },
  );

  test(
    'failed cancellation keeps item and disposed controllers ignore late responses',
    () async {
      final api = FakeJobFavoriteApi();
      addTearDown(api.client.close);
      final controller = JobFavoritesController(api, 'synthetic');
      api.onPage = (_) async => favoritePage([favoriteJob(91)]);
      await controller.load();
      api.onSave = (_, _) async => throw const ApiException('网络失败');
      expect(await controller.remove(favoriteJob(91)), '网络失败');
      expect(controller.items.single.positionId, 91);
      final late = Completer<JobFavoritesPage>();
      api.onPage = (_) => late.future;
      final pending = controller.load();
      controller.dispose();
      late.complete(favoritePage([]));
      await pending;
    },
  );
}
