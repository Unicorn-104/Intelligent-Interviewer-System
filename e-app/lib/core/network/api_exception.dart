class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final int? code;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || code == 401;

  @override
  String toString() => message;
}
