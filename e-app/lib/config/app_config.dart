abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// 仅在显式构建私有CA服务器包时启用，信任限定在API主机与端口。
  static const trustBaotaCertificate = bool.fromEnvironment(
    'TRUST_BAOTA_CERTIFICATE',
  );

  static const requestTimeout = Duration(seconds: 15);
}
