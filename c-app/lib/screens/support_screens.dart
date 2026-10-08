import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/support/data/support_api.dart';
import '../features/support/domain/support_models.dart';
import '../theme/app_theme.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  late final ApiClient _client;
  late final SupportApi _api;
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<HelpArticle>? _articles;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _api = SupportApi(_client);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _client.close();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final articles = await _api.fetchHelpArticles(
        widget.session.token,
        keyword: _searchController.text,
      );
      if (mounted) setState(() => _articles = articles);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '帮助内容加载失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final articles = _articles;
    return Scaffold(
      appBar: AppBar(title: const Text('帮助中心')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索使用指南',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          _searchController.clear();
                          _load();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            if (articles == null && _error == null) ...[
              const SizedBox(height: 24),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (_error case final message?) ...[
              const SizedBox(height: 20),
              _SupportState(
                icon: Icons.cloud_off_outlined,
                title: '暂时无法加载帮助内容',
                message: message,
                action: '重试',
                onAction: _load,
              ),
            ] else if (articles != null && articles.isEmpty) ...[
              const SizedBox(height: 20),
              _SupportState(
                icon: Icons.search_off_outlined,
                title: '没有找到相关内容',
                message: '试试更换关键词，或通过问题反馈联系我们。',
              ),
            ] else if (articles != null) ...[
              const SizedBox(height: 20),
              Text('使用指南', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              for (final article in articles) ...[
                _HelpArticleCard(
                  article: article,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => HelpArticleScreen(article: article),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class HelpArticleScreen extends StatelessWidget {
  const HelpArticleScreen({super.key, required this.article});

  final HelpArticle article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用指南')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (article.category.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: _Label(
                text: article.category,
                color: AppColors.interactive,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            article.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (article.updatedAt.millisecondsSinceEpoch > 0) ...[
            const SizedBox(height: 8),
            Text(
              '更新于 ${_formatDate(article.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                article.content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '本文内容用于产品使用说明；涉及账号安全或异常情况时，请通过问题反馈联系工作人员。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    required this.session,
    this.customerService = false,
  });

  final AuthSession session;
  final bool customerService;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final ApiClient _client;
  late final SupportApi _api;
  late int _type;
  List<FeedbackRecord>? _records;
  String? _loadError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _api = SupportApi(_client);
    _type = widget.customerService ? 4 : 1;
    if (widget.customerService) _subjectController.text = '客服咨询';
    _load();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final records = await _api.fetchFeedback(widget.session.token);
      if (mounted) setState(() => _records = records);
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } catch (_) {
      if (mounted) setState(() => _loadError = '反馈记录加载失败，请稍后重试');
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await _api.submitFeedback(
        widget.session.token,
        type: _type,
        subject: _subjectController.text,
        description: _descriptionController.text,
      );
      if (!mounted) return;
      _descriptionController.clear();
      if (!widget.customerService) _subjectController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('反馈已提交，我们会尽快处理')));
      await _load();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('反馈提交失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      appBar: AppBar(title: Text(widget.customerService ? '客服咨询' : '问题反馈')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (widget.customerService) ...[
              const _ServiceHoursCard(),
              const SizedBox(height: 20),
            ],
            Text(
              widget.customerService ? '提交咨询工单' : '告诉我们遇到的问题',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: '反馈类型'),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('功能建议')),
                          DropdownMenuItem(value: 2, child: Text('Bug反馈')),
                          DropdownMenuItem(value: 3, child: Text('投诉')),
                          DropdownMenuItem(value: 4, child: Text('其他 / 客服咨询')),
                        ],
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _type = value ?? 4),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _subjectController,
                        enabled: !_submitting,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: '标题',
                          hintText: '请简要描述问题',
                        ),
                        validator: (value) =>
                            (value?.trim().isEmpty ?? true) ? '请填写反馈标题' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !_submitting,
                        minLines: 5,
                        maxLines: 8,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: '详细描述',
                          hintText: '请说明发生时间、操作步骤和期望结果',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) =>
                            (value?.trim().isEmpty ?? true) ? '请填写详细描述' : null,
                      ),
                      const SizedBox(height: 4),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(widget.customerService ? '提交客服咨询' : '提交反馈'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('我的反馈', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (records == null && _loadError == null)
              const LinearProgressIndicator(minHeight: 2)
            else if (_loadError case final message?)
              _SupportState(
                icon: Icons.cloud_off_outlined,
                title: '反馈记录加载失败',
                message: message,
                action: '重试',
                onAction: _load,
              )
            else if (records != null && records.isEmpty)
              const _SupportState(
                icon: Icons.inbox_outlined,
                title: '暂无反馈记录',
                message: '提交后可在这里查看处理状态和回复。',
              )
            else if (records != null)
              for (final record in records) ...[
                _FeedbackCard(record: record),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('联系客服')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _ServiceHoursCard(),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '需要人工协助？',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请提交客服咨询工单，并尽量写明问题发生时间、相关岗位或面试信息。工作人员会在服务时间内处理。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => FeedbackScreen(
                            session: session,
                            customerService: true,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.support_agent_outlined),
                      label: const Text('提交客服咨询'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '当前版本尚未接入实时人工或 AI 客服会话，不会自动生成客服回复。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HelpArticleCard extends StatelessWidget {
  const _HelpArticleCard({required this.article, required this.onTap});

  final HelpArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.article_outlined,
            color: AppColors.interactive,
            size: 20,
          ),
        ),
        title: Text(
          article.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: article.category.isEmpty ? null : Text(article.category),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.record});

  final FeedbackRecord record;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      1 => AppColors.warning,
      2 => AppColors.green,
      _ => AppColors.muted,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.subject,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                _Label(text: record.statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${record.typeLabel} · ${_formatDateTime(record.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(
              record.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (record.reply case final reply?) ...[
              const Divider(height: 24),
              Text('处理回复', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(reply, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceHoursCard extends StatelessWidget {
  const _ServiceHoursCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.support_agent_outlined,
                color: AppColors.brand,
                size: 25,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '客服工作时间',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '工作日 9:00–18:00',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SupportState extends StatelessWidget {
  const _SupportState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.muted),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return '';
  return '${date.year}年${date.month}月${date.day}日';
}

String _formatDateTime(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return '';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $hour:$minute';
}
