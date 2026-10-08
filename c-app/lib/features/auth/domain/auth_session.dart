class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.userName,
    required this.nickName,
    this.avatar,
    this.phoneNumber,
  });

  final String token;
  final int userId;
  final String userName;
  final String nickName;
  final String? avatar;
  final String? phoneNumber;
}
