import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/backend_http_overrides.dart';

class _Request implements HttpClientRequest {
  @override
  bool followRedirects = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport implements HttpClient {
  final requests = <(String, Uri)>[];
  final request = _Request();
  bool closed = false;
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests.add((method, url));
    return request;
  }

  @override
  void close({bool force = false}) => closed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final origin = Uri.parse('https://backend.example:8443/prod-api');
  late _Transport system;
  late _Transport backend;
  late BackendHttpClient client;

  setUp(() {
    system = _Transport();
    backend = _Transport();
    client = BackendHttpClient(
      origin: origin,
      systemClient: system,
      backendClient: backend,
    );
  });

  test(
    'private CA covers backend API, uploads and same-origin images',
    () async {
      await client.getUrl(origin.resolve('/prod-api/captchaImage'));
      await client.postUrl(origin.resolve('/prod-api/app/resumes/import'));
      await client.getUrl(origin.resolve('/profile/avatar.png'));
      expect(backend.requests.map((r) => r.$1), ['GET', 'POST', 'GET']);
      expect(system.requests, isEmpty);
      expect(backend.request.followRedirects, isFalse);
    },
  );

  test('private CA never applies to other hosts, ports or HTTP', () async {
    for (final url in [
      'https://other.example:8443/file',
      'https://backend.example/file',
      'http://backend.example:8443/file',
      'https://backend.example.attacker.test:8443/file',
      'https://backend.example@attacker.test:8443/file',
    ]) {
      await client.getUrl(Uri.parse(url));
    }
    expect(backend.requests, isEmpty);
    expect(system.requests, hasLength(5));
    expect(system.request.followRedirects, isTrue);
  });

  test('all URL verbs use the same origin boundary', () async {
    await client.putUrl(origin);
    await client.deleteUrl(origin);
    await client.patchUrl(origin);
    await client.headUrl(origin);
    expect(backend.requests.map((r) => r.$1), [
      'PUT',
      'DELETE',
      'PATCH',
      'HEAD',
    ]);
    expect(system.requests, isEmpty);
  });

  test('transport configuration and shutdown reach both clients', () {
    client.autoUncompress = false;
    client.connectionTimeout = const Duration(seconds: 3);
    expect(system.autoUncompress, isFalse);
    expect(backend.autoUncompress, isFalse);
    expect(system.connectionTimeout, const Duration(seconds: 3));
    expect(backend.connectionTimeout, const Duration(seconds: 3));
    client.close(force: true);
    expect(system.closed, isTrue);
    expect(backend.closed, isTrue);
  });

  test('certificate verification cannot be replaced with accept-all', () {
    expect(
      () => client.badCertificateCallback = (_, _, _) => true,
      throwsUnsupportedError,
    );
  });

  test(
    'bundled asset contains a readable public CA and no private key',
    () async {
      final pem = await rootBundle.loadString(
        'assets/certificates/baota_root.pem',
      );
      expect('-----BEGIN CERTIFICATE-----'.allMatches(pem), hasLength(1));
      expect(pem, isNot(contains('PRIVATE KEY')));
      expect(
        () => BackendHttpOverrides(origin: origin, certificate: pem.codeUnits),
        returnsNormally,
      );
      expect(
        () => BackendHttpOverrides(
          origin: Uri.parse('http://backend.example'),
          certificate: pem.codeUnits,
        ),
        throwsArgumentError,
      );
      expect(
        () => BackendHttpOverrides(origin: origin, certificate: [1, 2, 3]),
        throwsA(isA<TlsException>()),
      );
    },
  );
}
