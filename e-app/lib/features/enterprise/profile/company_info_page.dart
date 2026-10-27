import 'package:flutter/material.dart';

import '../../../api/enterprise_settings_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';

/// 企业信息管理：查看并编辑求职者可见的企业对外展示资料。
///
/// 字段与 C-APP 企业主页（GET /app/companies/{id}）同源；
/// 认证状态、信用代码等认证类字段由管理员维护，本页不可修改。
class CompanyInfoPage extends StatefulWidget {
  const CompanyInfoPage({super.key, this.load, this.save});

  final Future<Map<String, dynamic>> Function()? load;
  final Future<Map<String, dynamic>> Function(Map<String, Object?> body)? save;

  @override
  State<CompanyInfoPage> createState() => _CompanyInfoPageState();
}

class _CompanyInfoPageState extends State<CompanyInfoPage> {
  Map<String, dynamic>? _info;
  String? _error;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  int _request = 0;
  final _name = TextEditingController();
  final _industry = TextEditingController();
  final _size = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _website = TextEditingController();
  final _intro = TextEditingController();
  final _logoUrl = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _name,
      _industry,
      _size,
      _city,
      _address,
      _website,
      _intro,
      _logoUrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> reload() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await (widget.load ?? getCompanyInfo)();
      if (!mounted || request != _request) return;
      setState(() => _info = info);
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = _friendlyError(error));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    reload();
  }

  static String _friendlyError(Object error) => switch (error) {
    ApiException() => error.message,
    _ => '企业信息加载失败，请稍后重试',
  };

  String _text(Object? value, {String fallback = '未填写'}) {
    final raw = value?.toString().trim() ?? '';
    return raw.isEmpty ? fallback : raw;
  }

  bool get _verified =>
      _info?['verifyStatus'] == 1 || _info?['verified'] == true;

  void _startEdit() {
    if (_info == null) return;
    _name.text = _text(_info!['name'], fallback: '');
    _industry.text = _text(_info!['industry'], fallback: '');
    _size.text = _text(_info!['size'], fallback: '');
    _city.text = _text(_info!['city'], fallback: '');
    _address.text = _text(_info!['address'], fallback: '');
    _website.text = _text(_info!['website'], fallback: '');
    _intro.text = _text(_info!['intro'], fallback: '');
    _logoUrl.text = _text(_info!['logoUrl'], fallback: '');
    setState(() => _editing = true);
  }

  void _cancelEdit() => setState(() => _editing = false);

  String? _trim(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('企业名称不能为空')));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, Object?>{
        'name': _name.text.trim(),
        'industry': _trim(_industry),
        'size': _trim(_size),
        'city': _trim(_city),
        'address': _trim(_address),
        'website': _trim(_website),
        'intro': _trim(_intro),
        'logoUrl': _trim(_logoUrl),
      };
      await (widget.save ?? updateCompanyInfo)(body);
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('企业信息已更新')));
      await reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('企业信息'),
      backgroundColor: AppColors.canvas,
      actions: [
        if (!_editing && !_loading && _info != null)
          TextButton.icon(
            key: const Key('company-info-edit'),
            onPressed: _saving ? null : _startEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('编辑'),
          ),
        const SizedBox(width: 8),
      ],
    ),
    body: _editing ? _editBody() : _viewBody(),
  );

  Widget _viewBody() {
    if (_loading) return const SkeletonList(rows: 3);
    if (_error != null || _info == null) {
      return PageMessage(
        icon: Icons.business_outlined,
        title: '企业信息加载失败',
        message: _error ?? '暂无企业信息',
        onAction: reload,
      );
    }
    final info = _info!;
    final name = _text(info['name'], fallback: '未命名企业');
    final logo = _text(info['logoUrl'], fallback: '');
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        key: const PageStorageKey('company-info-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.interactive,
                      foregroundImage: logo.isNotEmpty
                          ? NetworkImage(logo)
                          : null,
                      child: Text(
                        name.isEmpty ? '企' : name.substring(0, 1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            key: const Key('company-info-name'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _badge(
                                _verified ? '已认证' : '未认证',
                                _verified
                                    ? AppColors.success
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              _badge('求职者可见', AppColors.interactive),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _fieldRow(
                  Icons.category_outlined,
                  '所属行业',
                  _text(info['industry']),
                ),
                _fieldRow(Icons.groups_outlined, '企业规模', _text(info['size'])),
                _fieldRow(
                  Icons.location_on_outlined,
                  '所在城市',
                  _text(info['city']),
                ),
                _fieldRow(Icons.map_outlined, '详细地址', _text(info['address'])),
                _fieldRow(
                  Icons.language_outlined,
                  '官网',
                  _text(info['website']),
                ),
                _fieldRow(Icons.article_outlined, '企业简介', _text(info['intro'])),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '以上信息将展示在求职者的企业主页与岗位详情中；认证状态由平台审核维护。',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _editBody() => ListView(
    key: const PageStorageKey('company-info-edit-scroll'),
    padding: const EdgeInsets.all(20),
    children: [
      _field(
        key: const Key('company-info-field-name'),
        controller: _name,
        label: '企业名称',
        hint: '必填，最长 100 字',
        maxLength: 100,
      ),
      _field(
        key: const Key('company-info-field-industry'),
        controller: _industry,
        label: '所属行业',
        hint: '如 互联网、人工智能',
        maxLength: 50,
      ),
      _field(
        key: const Key('company-info-field-size'),
        controller: _size,
        label: '企业规模',
        hint: '如 100-499人',
        maxLength: 20,
      ),
      _field(
        key: const Key('company-info-field-city'),
        controller: _city,
        label: '所在城市',
        hint: '如 杭州',
        maxLength: 50,
      ),
      _field(
        key: const Key('company-info-field-address'),
        controller: _address,
        label: '详细地址',
        maxLength: 200,
      ),
      _field(
        key: const Key('company-info-field-website'),
        controller: _website,
        label: '官网',
        maxLength: 255,
      ),
      _field(
        key: const Key('company-info-field-logo'),
        controller: _logoUrl,
        label: 'Logo 地址',
        hint: '图片 URL，留空使用默认头像',
        maxLength: 255,
      ),
      _field(
        key: const Key('company-info-field-intro'),
        controller: _intro,
        label: '企业简介',
        maxLines: 5,
        maxLength: 4000,
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('company-info-cancel'),
              onPressed: _saving ? null : _cancelEdit,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              key: const Key('company-info-save'),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color)),
  );

  Widget _fieldRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    int? maxLength,
  }) => Padding(
    key: key,
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: maxLength == null ? '' : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
  );
}
