import 'dart:convert';

class EnterpriseProfile {
  EnterpriseProfile._(this.user, this.roleGroup, this.postGroup);
  factory EnterpriseProfile.fromResponse(Map<String, dynamic> response) {
    final raw = response['data'];
    if (raw is! Map || (int.tryParse('${raw['userId']}') ?? 0) <= 0) {
      throw const FormatException('个人资料响应不完整，请重试');
    }
    return EnterpriseProfile._(
      Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(raw)),
      profileText(response['roleGroup'], ''),
      profileText(response['postGroup'], ''),
    );
  }
  final Map<String, dynamic> user;
  final String roleGroup, postGroup;
  int get id => int.parse('${user['userId']}');
  String get name =>
      profileText(user['nickName'], profileText(user['userName'], '当前用户'));
  String get account => profileText(user['userName']);
  String get department => user['dept'] is Map
      ? profileText(user['dept']['deptName'], '未分配部门')
      : '未分配部门';
  String get role => roleGroup.isNotEmpty ? roleGroup : '角色未提供';
  String get position => postGroup.isNotEmpty ? postGroup : '职位未填写';
  String get phone => profileText(user['phonenumber'], '');
  String get email => profileText(user['email'], '');
  String get avatar => profileText(user['avatar'], '');
  String get sex => switch ('${user['sex']}') {
    '0' => '男',
    '1' => '女',
    _ => '未填写',
  };
  Map<String, Object?> get editable => {
    'nickName': profileText(user['nickName'], ''),
    'phonenumber': phone,
    'email': email,
    'sex': ['0', '1', '2'].contains('${user['sex']}') ? '${user['sex']}' : '2',
    'remark': profileText(user['remark'], ''),
  };
}

String profileText(Object? raw, [String fallback = '—']) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

class ProfilePreferences {
  const ProfilePreferences({
    this.duration = 45,
    this.calendar = 'both',
    this.frequency = 'realtime',
    this.notices = const {
      'interview': true,
      'resume': true,
      'message': true,
      'system': false,
    },
  });
  final int duration;
  final String calendar, frequency;
  final Map<String, bool> notices;
  static const calendarOptions = {
    'both': '双向同步',
    'import': '仅导入日程',
    'none': '不同步',
  };
  static const frequencyOptions = {
    'realtime': '实时通知',
    'daily': '每日汇总',
    'none': '不通知',
  };
  ProfilePreferences copyWith({
    int? duration,
    String? calendar,
    String? frequency,
    Map<String, bool>? notices,
  }) => ProfilePreferences(
    duration: duration ?? this.duration,
    calendar: calendar ?? this.calendar,
    frequency: frequency ?? this.frequency,
    notices: Map.unmodifiable(notices ?? this.notices),
  );
  Map<String, Object> toJson() => {
    'duration': duration,
    'calendar': calendar,
    'frequency': frequency,
    'notices': notices,
  };
  factory ProfilePreferences.decode(String? raw) {
    if (raw == null) return const ProfilePreferences();
    final value = jsonDecode(raw);
    if (value is! Map) throw const FormatException('偏好设置读取失败');
    final saved = value['notices'];
    return ProfilePreferences(
      duration: [30, 45, 60].contains(value['duration'])
          ? value['duration'] as int
          : 45,
      calendar: calendarOptions.containsKey(value['calendar'])
          ? value['calendar'] as String
          : 'both',
      frequency: frequencyOptions.containsKey(value['frequency'])
          ? value['frequency'] as String
          : 'realtime',
      notices: Map.unmodifiable({
        for (final entry in const ProfilePreferences().notices.entries)
          entry.key: saved is Map && saved[entry.key] is bool
              ? saved[entry.key] as bool
              : entry.value,
      }),
    );
  }
}
