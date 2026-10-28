import 'dart:io';

/// 将私有 CA 限定到后端的 HTTPS 主机（任意端口），不改变系统信任库。
class BackendHttpOverrides extends HttpOverrides {
  BackendHttpOverrides({required Uri origin, required List<int> certificate})
    : _origin = origin,
      _context = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificatesBytes(certificate) {
    if (origin.scheme != 'https' || origin.host.isEmpty) {
      throw ArgumentError.value(origin, 'origin', '必须是 HTTPS 后端地址');
    }
  }

  final Uri _origin;
  final SecurityContext _context;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    if (context != null) return super.createHttpClient(context);
    return BackendHttpClient(
      origin: _origin,
      systemClient: super.createHttpClient(null),
      backendClient: super.createHttpClient(_context),
    );
  }
}

class BackendHttpClient implements HttpClient {
  BackendHttpClient({
    required this.origin,
    required HttpClient systemClient,
    required HttpClient backendClient,
  }) : _system = systemClient,
       _backend = backendClient;

  final Uri origin;
  final HttpClient _system;
  final HttpClient _backend;

  // 信任边界保持「同一主机 + TLS」：LiveKit 入会地址（如 wss://同主机:8444/livekit）
  // 与 API 端口不同，但同一服务器上的站点均由同一宝塔私有 CA 签发；
  // 不覆盖其他主机、明文 HTTP/WS 或用户信息伪装。
  bool _isBackend(Uri uri) =>
      (uri.scheme == 'https' || uri.scheme == 'wss') && uri.host == origin.host;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (!_isBackend(url)) return _system.openUrl(method, url);
    final request = await _backend.openUrl(method, url);
    // 自动重定向会沿用当前客户端，禁止把私有 CA 信任带到其他地址。
    request.followRedirects = false;
    return request;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  // 不带 URL 的 HttpClient 方法使用 HTTP，沿用系统客户端。
  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) => _system.open(method, host, port, path);
  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  bool get autoUncompress => _system.autoUncompress;
  @override
  set autoUncompress(bool value) {
    _system.autoUncompress = value;
    _backend.autoUncompress = value;
  }

  @override
  Duration get idleTimeout => _system.idleTimeout;
  @override
  set idleTimeout(Duration value) {
    _system.idleTimeout = value;
    _backend.idleTimeout = value;
  }

  @override
  Duration? get connectionTimeout => _system.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) {
    _system.connectionTimeout = value;
    _backend.connectionTimeout = value;
  }

  @override
  int? get maxConnectionsPerHost => _system.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) {
    _system.maxConnectionsPerHost = value;
    _backend.maxConnectionsPerHost = value;
  }

  @override
  String? get userAgent => _system.userAgent;
  @override
  set userAgent(String? value) {
    _system.userAgent = value;
    _backend.userAgent = value;
  }

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? callback,
  ) {
    _system.authenticate = callback;
    _backend.authenticate = callback;
  }

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) {
    (_isBackend(url) ? _backend : _system).addCredentials(
      url,
      realm,
      credentials,
    );
  }

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
    callback,
  ) {
    _system.connectionFactory = callback;
    _backend.connectionFactory = callback;
  }

  @override
  set findProxy(String Function(Uri url)? callback) {
    _system.findProxy = callback;
    _backend.findProxy = callback;
  }

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
    callback,
  ) {
    _system.authenticateProxy = callback;
    _backend.authenticateProxy = callback;
  }

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) {
    _system.addProxyCredentials(host, port, realm, credentials);
    _backend.addProxyCredentials(host, port, realm, credentials);
  }

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) {
    if (callback != null) {
      throw UnsupportedError('不允许绕过服务器证书校验');
    }
    _system.badCertificateCallback = null;
    _backend.badCertificateCallback = null;
  }

  @override
  set keyLog(void Function(String line)? callback) {
    _system.keyLog = callback;
    _backend.keyLog = callback;
  }

  @override
  void close({bool force = false}) {
    _system.close(force: force);
    _backend.close(force: force);
  }
}
