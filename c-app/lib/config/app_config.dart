abstract final class AppConfig {
  /// Android 模拟器通过 10.0.2.2 访问宿主机。
  /// 真机或其他环境可使用 --dart-define=API_BASE_URL=https://api.example.com 覆盖。
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const requestTimeout = Duration(seconds: 12);
}
