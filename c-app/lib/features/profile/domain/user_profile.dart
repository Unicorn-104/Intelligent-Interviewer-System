import '../../auth/domain/auth_session.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.userName,
    required this.nickName,
    this.realName,
    this.avatar,
    this.email,
    this.phoneNumber,
    this.sex,
    this.bio,
    this.currentCity,
    this.currentStatus,
    this.targetDirection,
    this.targetCity,
    this.verifyStatus = 0,
    this.applicationCount = 0,
    this.interviewCount = 0,
    this.favoriteCount = 0,
    this.workYears = 0,
  });

  final int userId;
  final String userName;
  final String nickName;
  final String? realName;
  final String? avatar;
  final String? email;
  final String? phoneNumber;
  final String? sex;
  final String? bio;
  final String? currentCity;
  final int? currentStatus;
  final String? targetDirection;
  final String? targetCity;
  final int verifyStatus;
  final int applicationCount;
  final int interviewCount;
  final int favoriteCount;
  final int workYears;

  factory UserProfile.fromSession(AuthSession session) {
    return UserProfile(
      userId: session.userId,
      userName: session.userName,
      nickName: session.nickName,
      avatar: session.avatar,
      phoneNumber: session.phoneNumber,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: _asInt(json['userId']),
      userName: json['userName']?.toString() ?? '',
      nickName: json['nickName']?.toString() ?? '',
      realName: _nullableText(json['realName']),
      avatar: _nullableText(json['avatar']),
      email: _nullableText(json['email']),
      phoneNumber: _nullableText(json['phonenumber']),
      sex: _nullableText(json['sex']),
      bio: _nullableText(json['remark']),
      currentCity: _nullableText(json['currentCity']),
      currentStatus: _asNullableInt(json['currentStatus']),
      targetDirection: _nullableText(json['targetDirection']),
      targetCity: _nullableText(json['targetCity']),
      verifyStatus: _asInt(json['verifyStatus']),
      applicationCount: _asInt(json['applicationCount']),
      interviewCount: _asInt(json['interviewCount']),
      favoriteCount: _asInt(json['favoriteCount']),
      workYears: _asInt(json['workYears']),
    );
  }

  UserProfile copyWith({
    String? nickName,
    String? realName,
    String? avatar,
    String? email,
    String? phoneNumber,
    String? sex,
    String? bio,
    String? currentCity,
    int? currentStatus,
    String? targetDirection,
    String? targetCity,
  }) {
    return UserProfile(
      userId: userId,
      userName: userName,
      nickName: nickName ?? this.nickName,
      realName: realName ?? this.realName,
      avatar: avatar ?? this.avatar,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      sex: sex ?? this.sex,
      bio: bio ?? this.bio,
      currentCity: currentCity ?? this.currentCity,
      currentStatus: currentStatus ?? this.currentStatus,
      targetDirection: targetDirection ?? this.targetDirection,
      targetCity: targetCity ?? this.targetCity,
      verifyStatus: verifyStatus,
      applicationCount: applicationCount,
      interviewCount: interviewCount,
      favoriteCount: favoriteCount,
      workYears: workYears,
    );
  }

  Map<String, dynamic> toUpdateJson() => {
    'nickName': nickName.trim(),
    'realName': _emptyToNull(realName),
    'email': _emptyToNull(email),
    'phonenumber': _emptyToNull(phoneNumber),
    'sex': sex ?? '2',
    'remark': _emptyToNull(bio),
    'currentCity': _emptyToNull(currentCity),
    'currentStatus': currentStatus,
    'targetDirection': _emptyToNull(targetDirection),
    'targetCity': _emptyToNull(targetCity),
  };

  int get completionPercent {
    final fields = <String?>[
      nickName,
      realName,
      phoneNumber,
      email,
      bio,
      currentCity,
      targetDirection,
      targetCity,
    ];
    final completed = fields
        .where((value) => value?.trim().isNotEmpty == true)
        .length;
    return (completed / fields.length * 100).round();
  }

  String get statusLabel => switch (currentStatus) {
    1 => '在职，考虑新机会',
    2 => '离职，随时到岗',
    3 => '应届生',
    _ => '求职状态待完善',
  };

  String get verificationLabel => switch (verifyStatus) {
    1 => '实名认证',
    2 => '认证未通过',
    _ => '未实名认证',
  };

  static int _asInt(Object? value) =>
      int.tryParse(value?.toString() ?? '') ?? 0;

  static int? _asNullableInt(Object? value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _emptyToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
