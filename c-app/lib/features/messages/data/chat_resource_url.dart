/// 聊天附件沿用 E-App 的公开 /profile/ 地址；仅允许当前 API 主机。
String? chatResourceUrl(String? value, String apiBaseUrl) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty ||
      raw.startsWith('//') ||
      RegExp(r'[\x00-\x20\x7f\\]').hasMatch(raw)) {
    return null;
  }
  final base = Uri.tryParse(apiBaseUrl);
  final uri = Uri.tryParse(raw);
  if (base == null ||
      uri == null ||
      !['http', 'https'].contains(base.scheme) ||
      base.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      RegExp(r'%2f|%5c|%2e', caseSensitive: false).hasMatch(raw) ||
      uri.pathSegments.any((part) => part == '.' || part == '..') ||
      RegExp(r'/\.{1,2}(?:/|$)').hasMatch(raw)) {
    return null;
  }
  if (uri.hasScheme &&
      (!['http', 'https'].contains(uri.scheme) || uri.origin != base.origin)) {
    return null;
  }
  final prefix = base.path.replaceAll(RegExp(r'/+$'), '');
  var path = uri.path;
  if (!path.startsWith('/')) path = '/$path';
  if (prefix.isNotEmpty && path.startsWith('$prefix/profile/')) {
    path = path.substring(prefix.length);
  }
  if (!path.startsWith('/profile/')) return null;
  return base
      .replace(path: '$prefix$path', query: null, fragment: null)
      .toString();
}
