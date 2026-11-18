import '../core/network/api_exception.dart';
import '../core/network/enterprise_api_client.dart';

Map<String, dynamic> _mapData(Map<String, dynamic> response, String name) {
  final data = response['data'];
  if (data is! Map) {
    throw ApiException('$name响应格式不正确');
  }
  return Map<String, dynamic>.from(data);
}

List<Map<String, dynamic>> _listData(
  Map<String, dynamic> response,
  String name,
) {
  final data = response['data'];
  if (data is! List) {
    throw ApiException('$name响应格式不正确');
  }
  return data
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Future<Map<String, dynamic>> loadDepartmentOverview() async => _mapData(
  await EnterpriseApiClient().get('/system/enterprise/settings/depts'),
  '部门列表',
);

Future<void> addDepartment(Map<String, Object?> body) async {
  await EnterpriseApiClient().post(
    '/system/enterprise/settings/depts',
    body: body,
  );
}

Future<void> updateDepartment(int id, Map<String, Object?> body) async {
  await EnterpriseApiClient().put(
    '/system/enterprise/settings/depts/$id',
    body: body,
  );
}

Future<void> removeDepartment(int id) async {
  await EnterpriseApiClient().delete('/system/enterprise/settings/depts/$id');
}

Future<List<Map<String, dynamic>>> loadEnterpriseMembers() async => _listData(
  await EnterpriseApiClient().get('/system/enterprise/settings/members'),
  '成员列表',
);

Future<void> updateMemberRole(int userId, int roleId) async {
  await EnterpriseApiClient().put(
    '/system/enterprise/settings/members/$userId/role',
    body: {'roleId': roleId},
  );
}

Future<void> updateMemberStatus(int userId, bool enabled) async {
  await EnterpriseApiClient().put(
    '/system/enterprise/settings/members/$userId/status',
    body: {'enabled': enabled},
  );
}

Future<Map<String, dynamic>> inviteEnterpriseMember(
  Map<String, Object?> body,
) async => _mapData(
  await EnterpriseApiClient().post(
    '/system/enterprise/settings/members/invite',
    body: body,
  ),
  '邀请成员',
);
