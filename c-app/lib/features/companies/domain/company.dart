import '../../../core/network/api_exception.dart';

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.followed,
    this.logoUrl,
    this.industry,
    this.size,
    this.city,
    this.address,
    this.website,
    this.intro,
    this.verified = false,
  });

  final int id;
  final String name;
  final bool followed, verified;
  final String? logoUrl, industry, size, city, address, website, intro;

  factory Company.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! int ||
        (json['id'] as int) <= 0 ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty ||
        json['followed'] is! bool) {
      throw const ApiException('企业信息格式不正确，请重试');
    }
    String? text(String key) {
      final value = json[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return Company(
      id: json['id'] as int,
      name: json['name'] as String,
      followed: json['followed'] as bool,
      verified: json['verified'] == true,
      logoUrl: text('logoUrl'),
      industry: text('industry'),
      size: text('size'),
      city: text('city'),
      address: text('address'),
      website: text('website'),
      intro: text('intro'),
    );
  }

  Company withFollowed(bool value) => Company(
    id: id,
    name: name,
    followed: value,
    verified: verified,
    logoUrl: logoUrl,
    industry: industry,
    size: size,
    city: city,
    address: address,
    website: website,
    intro: intro,
  );
}

class CompanyPage {
  const CompanyPage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasNext,
  });
  final List<Company> items;
  final int page, total;
  final bool hasNext;

  factory CompanyPage.fromJson(Map<String, dynamic> json) {
    if (json['items'] is! List ||
        json['page'] is! int ||
        (json['page'] as int) < 1 ||
        json['total'] is! int ||
        (json['total'] as int) < 0 ||
        json['hasNext'] is! bool) {
      throw const ApiException('收藏列表格式不正确，请重试');
    }
    return CompanyPage(
      items: (json['items'] as List).map((item) {
        if (item is! Map) throw const ApiException('企业信息格式不正确，请重试');
        return Company.fromJson(Map<String, dynamic>.from(item));
      }).toList(),
      page: json['page'] as int,
      total: json['total'] as int,
      hasNext: json['hasNext'] as bool,
    );
  }
}
