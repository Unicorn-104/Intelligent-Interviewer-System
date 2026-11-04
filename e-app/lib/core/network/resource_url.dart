/// Resolve public backend assets through the configured API gateway.
/// Object storage endpoints and credentials remain on the backend.
String? resolveResourceUrl(
  String? value, {
  required String apiBaseUrl,
  bool profileOnly = false,
}) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty ||
      raw.startsWith('//') ||
      RegExp(r'[\x00-\x1f\x7f\\]').hasMatch(raw)) {
    return null;
  }
  final rawPath = raw.split(RegExp(r'[?#]')).first;
  if (RegExp(r'%2e|%2f|%5c', caseSensitive: false).hasMatch(rawPath) ||
      RegExp(r'/\.{1,2}(?:/|$)').hasMatch(rawPath)) {
    return null;
  }
  final base = Uri.tryParse(apiBaseUrl);
  final parsed = Uri.tryParse(raw);
  if (base == null ||
      parsed == null ||
      !['http', 'https'].contains(base.scheme) ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment ||
      parsed.userInfo.isNotEmpty ||
      parsed.hasFragment ||
      (parsed.hasScheme &&
          (!['http', 'https'].contains(parsed.scheme) ||
              parsed.host.isEmpty))) {
    return null;
  }
  final basePath = base.path.replaceAll(RegExp(r'/+$'), '');
  for (final prefix in {
    '/profile/',
    '/dev-api/profile/',
    '/prod-api/profile/',
    '$basePath/profile/',
  }) {
    if (parsed.path.startsWith(prefix)) {
      return base
          .replace(
            path: '$basePath/profile/${parsed.path.substring(prefix.length)}',
            query: parsed.hasQuery ? parsed.query : null,
          )
          .toString();
    }
  }
  if (profileOnly) return null;
  if (parsed.hasScheme) return parsed.toString();
  return base
      .replace(
        path: '$basePath/${parsed.path.replaceFirst(RegExp(r'^/+'), '')}',
        query: parsed.hasQuery ? parsed.query : null,
      )
      .toString();
}
