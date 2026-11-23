import 'package:flutter/material.dart';

import '../../../api/enterprise_knowledge_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';

/// 企业知识库管理：文档新增、删除与检索验证。
class EnterpriseKnowledgePage extends StatefulWidget {
  const EnterpriseKnowledgePage({super.key});

  @override
  State<EnterpriseKnowledgePage> createState() =>
      _EnterpriseKnowledgePageState();
}

class _EnterpriseKnowledgePageState extends State<EnterpriseKnowledgePage> {
  List<EnterpriseKnowledgeDocument> _documents = const [];
  bool _loading = true;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final documents = await getEnterpriseKnowledgeDocuments();
      if (mounted) setState(() => _documents = documents);
    } catch (error) {
      if (mounted) showCompactError(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addDocument() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => const _KnowledgeEditor(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(compactSnackBar('知识文档已添加'));
      await _load();
    }
  }

  Future<void> _delete(EnterpriseKnowledgeDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除知识文档'),
        content: Text('确定删除“${document.name}”吗？AI 助手将不再检索这份资料。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingId = document.id);
    try {
      await deleteEnterpriseKnowledgeDocument(document.id);
      if (mounted) {
        setState(() => _documents.removeWhere((row) => row.id == document.id));
        ScaffoldMessenger.of(context).showSnackBar(compactSnackBar('文档已删除'));
      }
    } catch (error) {
      if (mounted) showCompactError(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  Future<void> _openSearch() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => const _KnowledgeSearch(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text(
        '企业知识库',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.brand,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _openSearch,
          icon: const Icon(Icons.search),
          tooltip: '检索知识库',
        ),
        IconButton(
          onPressed: _addDocument,
          icon: const Icon(Icons.add),
          tooltip: '添加知识文档',
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  '知识文档（${_documents.length}）',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                if (_documents.isEmpty)
                  _empty()
                else
                  _card([
                    for (var index = 0; index < _documents.length; index++) ...[
                      if (index > 0) _divider,
                      _documentRow(_documents[index]),
                    ],
                  ]),
              ],
            ),
          ),
  );

  Widget _documentRow(EnterpriseKnowledgeDocument document) => ListTile(
    contentPadding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
    minVerticalPadding: 8,
    visualDensity: VisualDensity.compact,
    leading: const Icon(
      Icons.description_outlined,
      size: 18,
      color: AppColors.interactive,
    ),
    title: Text(
      document.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    subtitle: Text(
      '${document.chunkCount} 段 · ${_lengthLabel(document.contentLength)}'
      '${document.updatedAt == null ? '' : ' · ${_shortTime(document.updatedAt!)}'}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
    ),
    trailing: _deletingId == document.id
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : IconButton(
            onPressed: _deletingId == null ? () => _delete(document) : null,
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AppColors.textMuted,
            ),
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            tooltip: '删除',
          ),
  );

  Widget _empty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        const Icon(
          Icons.menu_book_outlined,
          size: 28,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 10),
        const Text(
          '还没有知识文档',
          style: TextStyle(fontSize: 14, color: AppColors.body),
        ),
        const SizedBox(height: 4),
        const Text(
          '添加企业资料，供 AI 检索引用',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _addDocument,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('添加文档', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );

  Widget _card(List<Widget> children) => Container(
    decoration: _cardDecoration(),
    child: Column(children: children),
  );

  Widget get _divider => const Divider(
    height: 1,
    indent: 12,
    endIndent: 12,
    color: AppColors.hairline,
  );

  static BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.hairline),
  );

  static String _lengthLabel(int length) {
    if (length < 1000) return '$length 字';
    return '${(length / 1000).toStringAsFixed(1)}k 字';
  }

  static String _shortTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }
}

class _KnowledgeEditor extends StatefulWidget {
  const _KnowledgeEditor();

  @override
  State<_KnowledgeEditor> createState() => _KnowledgeEditorState();
}

class _KnowledgeEditorState extends State<_KnowledgeEditor> {
  final _name = TextEditingController();
  final _content = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final content = _content.text.trim();
    if (name.isEmpty || content.isEmpty) {
      setState(() => _error = '请填写文档名称和内容');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await createEnterpriseKnowledgeDocument(name: name, content: content);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '添加知识文档',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '录入企业制度、流程或面试标准',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            enabled: !_saving,
            maxLength: 80,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: '文档名称',
              hintText: '例如：技术岗面试规范',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _content,
            enabled: !_saving,
            minLines: 6,
            maxLines: 11,
            maxLength: 200000,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: '文档内容',
              hintText: '粘贴企业资料',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 42),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: Text(_saving ? '保存中…' : '保存文档'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _KnowledgeSearch extends StatefulWidget {
  const _KnowledgeSearch();

  @override
  State<_KnowledgeSearch> createState() => _KnowledgeSearchState();
}

class _KnowledgeSearchState extends State<_KnowledgeSearch> {
  final _query = TextEditingController();
  List<EnterpriseKnowledgeResult> _results = const [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().isEmpty) {
      setState(() => _error = '请输入要检索的内容');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final results = await searchEnterpriseKnowledge(_query.text);
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .82,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '检索知识库',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  maxLength: 300,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '输入关键词',
                    counterText: '',
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search, size: 18),
                style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                tooltip: '检索',
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 11),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? Center(
                    child: Text(
                      _searched ? '未检索到相关内容' : '输入关键词验证资料',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[${result.citation}] ${result.fileName}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              result.content,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

String _friendlyError(Object error) {
  if (error is ApiException) {
    final message = error.message;
    if (message.contains('No static resource')) return '知识库接口未部署';
    if (message.contains('disabled')) return '知识库未开启';
    if (message.contains('migration') || message.contains('doesn\'t exist')) {
      return '知识库未初始化';
    }
    if (error.isUnauthorized) return '登录已过期，请重新登录';
    return message;
  }
  return '操作失败，请检查网络后重试';
}
