class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final int? code;
  final int? statusCode;

  @override
  String toString() => message;
}
