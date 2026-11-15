import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../data/knowledge_api.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key, required this.token, this.api});
  final String token;
  final KnowledgeApi? api;
  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  final _client = ApiClient();
  late final KnowledgeApi _api = widget.api ?? KnowledgeApi(_client);
  List<Map<String, dynamic>> _documents = [];
  String? _error;
  bool _loading = true, _busy = false;
  int _tab = 0, _filter = 0, _epoch = 0;
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _epoch++;
    _poll?.cancel();
    _client.close();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    final epoch = ++_epoch;
    _poll?.cancel();
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final documents = await _api.documents(widget.token);
      if (!mounted || epoch != _epoch) return;
      documents.sort(
        (a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'),
      );
      setState(() {
        _documents = documents;
        _error = null;
        _loading = false;
      });
      if (documents.any(
        (d) => ['QUEUED', 'PROCESSING'].contains(d['status']),
      )) {
        _poll = Timer(const Duration(seconds: 5), () => _load(quiet: true));
      }
    } catch (e) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = e is ApiException ? e.message : '资料加载失败，请重试';
          _loading = false;
        });
      }
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : '操作失败，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (!mounted) return;
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('上传个人资料'),
        content: const Text(
          '支持文字型 PDF、DOCX、TXT 和 Markdown，单个文件不超过 20 MB。\n\n资料仅本人可用。用于问答时，命中的片段会发送给当前配置的 AI 服务。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('选择文件'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    await _action(() async {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'docx', 'txt', 'md'],
      );
      if (file == null) return;
      if ((await file.length() ?? 0) > 20 * 1024 * 1024) {
        throw const ApiException('文件不能超过 20 MB');
      }
      // Android document providers can return content:// without a local path.
      // Copy only this explicit selection to a bounded private temporary file.
      final temporary = await Directory.systemTemp.createTemp(
        'capp-knowledge-',
      );
      try {
        final name = file.name.replaceAll(RegExp(r'[/\\\r\n"]'), '_');
        if (name.isEmpty || name == '.' || name == '..') {
          throw const ApiException('文件名称无效，请重新选择');
        }
        final target = File('${temporary.path}/$name');
        final sink = target.openWrite();
        var size = 0;
        try {
          await for (final bytes in file.readAsByteStream()) {
            size += bytes.length;
            if (size > 20 * 1024 * 1024) {
              throw const ApiException('文件不能超过 20 MB');
            }
            sink.add(bytes);
          }
        } finally {
          await sink.close();
        }
        await _api.upload(widget.token, target.path);
        if (mounted) {
          setState(() {
            _filter = 1;
            _tab = 0;
          });
        }
      } finally {
        await temporary.delete(recursive: true);
      }
    });
  }

  Future<bool> _confirm(String title, String description) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除', style: TextStyle(color: AppColors.red)),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) {
    final visible = _documents.where((d) {
      final generated = d['source'] == 'GENERATED';
      final audio = [
        'mp3',
        'wav',
        'm4a',
        'aac',
        'ogg',
      ].contains(d['extension']);
      final category = switch (_tab) {
        1 => generated,
        2 => !audio,
        3 => audio,
        _ => true,
      };
      return category && (_filter == 0 ? generated : !generated);
    }).toList();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('知识空间'),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多操作',
            enabled: !_busy,
            onSelected: (_) => _load(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'refresh', child: Text('??')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  for (final (index, title) in ['最近', '创作', '文件', '音频'].indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xl),
                      child: InkWell(
                        onTap: () => setState(() => _tab = index),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                width: 2,
                                color: _tab == index
                                    ? AppColors.ink
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: _tab == index
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _tab == index
                                  ? AppColors.body
                                  : AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final (index, title) in ['已生成', '我的上传'].indexed)
                    ChoiceChip(
                      label: Text(title),
                      selected: _filter == index,
                      showCheckmark: false,
                      selectedColor: AppColors.ink,
                      labelStyle: TextStyle(
                        color: _filter == index ? Colors.white : AppColors.body,
                      ),
                      onSelected: (_) => setState(() => _filter = index),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: visible.isEmpty
                          ? _empty()
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(20),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 24),
                              itemBuilder: (_, index) =>
                                  _document(visible[index]),
                            ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _upload,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('上传资料'),
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _empty() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(height: 80),
      Icon(Icons.folder_open_outlined, size: 48, color: AppColors.muted),
      SizedBox(height: 16),
      Center(
        child: Text(
          _tab == 3
              ? '暂无音频'
              : _filter == 0 || _tab == 1
              ? '暂无生成内容'
              : '把资料变成回答的依据',
        ),
      ),
      if (_tab == 3 || (_filter != 0 && _tab != 1))
        Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            _tab == 3 ? '当前支持文档资料，音频导入将在后续提供。' : '上传面试笔记或项目文档，AI 会自动查找相关资料来回答。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
    ],
  );
  Widget _document(Map<String, dynamic> doc) {
    final status = switch (doc['status']) {
      'READY' => '可用于问答',
      'FAILED' => '处理失败',
      'PROCESSING' => '正在处理',
      _ => '等待处理',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${doc['extension']}'.toUpperCase(),
          style: const TextStyle(fontSize: 11, color: AppColors.brand),
        ),
      ),
      title: Text(
        doc['name'] as String,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${doc['baseName']} · $status${doc['errorCode'] == 'NO_TEXT_OCR_REQUIRED' ? '\n未提取到文字，请上传文字型文档' : ''}',
      ),
      trailing: PopupMenuButton<String>(
        tooltip: '资料操作',
        enabled: !_busy,
        itemBuilder: (_) => [
          if (['READY', 'FAILED'].contains(doc['status']))
            const PopupMenuItem(value: 'retry', child: Text('重新处理')),
          const PopupMenuItem(value: 'delete', child: Text('删除资料')),
        ],
        onSelected: (value) async {
          if (value == 'retry') {
            await _action(() => _api.retry(widget.token, doc['id'] as String));
          } else if (await _confirm('删除资料？', '删除后立即停止检索，历史回答中的正文仍保留。')) {
            await _action(
              () => _api.deleteDocument(widget.token, doc['id'] as String),
            );
          }
        },
      ),
    );
  }
}
