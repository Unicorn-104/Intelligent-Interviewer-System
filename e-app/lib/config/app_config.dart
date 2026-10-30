abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://114.55.175.79/prod-api',
  );

  /// 候选人端（user-PC / c-app）入口地址，用于拼接面试会议链接，
  /// 与 PC 端 VITE_CANDIDATE_APP_URL 保持一致；服务器包需显式传入。
  static const candidateAppUrl = String.fromEnvironment(
    'CANDIDATE_APP_URL',
    defaultValue: 'https://114.55.175.79/user',
  );

  /// 仅在显式构建私有CA服务器包时启用，信任限定在API主机与端口。
  static const trustBaotaCertificate = bool.fromEnvironment(
    'TRUST_BAOTA_CERTIFICATE',
    defaultValue: true,
  );

  static const requestTimeout = Duration(seconds: 15);
}
