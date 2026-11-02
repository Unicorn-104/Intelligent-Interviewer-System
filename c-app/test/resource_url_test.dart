import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/resource_url.dart';

void main() {
  const api = 'https://recruit.example.com/prod-api/';
  const files = [
    '/profile/storage/avatars/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png',
    '/profile/storage/uploads/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf',
    '/profile/upload/legacy.png',
  ];
  test(
    'RustFS and legacy resource URLs retain the API gateway prefix once',
    () {
      for (final path in files) {
        for (final value in [
          path,
          '/prod-api$path',
          '/dev-api$path',
          'http://old-backend:8080$path',
        ]) {
          expect(
            resolveResourceUrl(value, apiBaseUrl: api),
            'https://recruit.example.com/prod-api$path',
          );
        }
      }
    },
  );
  test(
    'External public images remain usable and private paths stay rejected',
    () {
      const cdn = 'https://cdn.example.com/logo.png?v=2';
      expect(resolveResourceUrl(cdn, apiBaseUrl: api), cdn);
      expect(
        resolveResourceUrl(cdn, apiBaseUrl: api, profileOnly: true),
        isNull,
      );
      for (final invalid in [
        's3:bucket/private-resume/17/file.pdf',
        'javascript:alert(1)',
        '//other/profile/a.png',
        'https://synthetic:credential@other/profile/a.png',
        '/profile/../private.pdf',
        '/profile/%2e%2e/private.pdf',
        '/profile/%2fprivate.pdf',
        '/profile/a.png#fragment',
      ]) {
        expect(resolveResourceUrl(invalid, apiBaseUrl: api), isNull);
      }
    },
  );
}
