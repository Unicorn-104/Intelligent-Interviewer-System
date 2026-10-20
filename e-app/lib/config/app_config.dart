abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://114.55.175.79/prod-api',
  );
  static const requestTimeout = Duration(seconds: 15);
}
