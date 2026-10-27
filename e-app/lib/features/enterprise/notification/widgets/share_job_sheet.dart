import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/message_data_source.dart';
import '../models/shared_job_card.dart';
import 'shared_job_card_view.dart';

String _encode(Map<String, dynamic> row) =>
    jsonEncode({...row, 'kind': 'job_card', 'version': 1});

class ShareJobSheet extends StatefulWidget {
  const ShareJobSheet({super.key, required this.source});
  final MessageDataSource source;
  @override
  State<ShareJobSheet> createState() => _ShareJobSheetState();
}

class _ShareJobSheetState extends State<ShareJobSheet> {
  final input = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  bool loading = true, more = false, loadingMore = false;
  String? error;
  int generation = 0, page = 1;
  String keyword = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load({bool next = false}) async {
    if (next && (loading || loadingMore || !more)) return;
    final request = ++generation;
    final current = next ? page + 1 : 1;
    if (!next) keyword = input.text.trim();
    setState(() {
      if (next) {
        loadingMore = true;
      } else {
        loading = true;
      }
      error = null;
    });
    try {
      final result = await widget.source.loadShareableJobs(
        keyword: keyword,
        page: current,
      );
      if (!mounted || request != generation) return;
      if (result.length > 20 ||
          result.any(
            (r) =>
                (int.tryParse('${r['positionId']}') ?? 0) <= 0 ||
                r['title'] is! String ||
                r['title'].toString().trim().isEmpty,
          )) {
        throw const FormatException('岗位数据不完整');
      }
      final combined = <int, Map<String, dynamic>>{
        if (next)
          for (final r in rows) int.parse('${r['positionId']}'): r,
        for (final r in result) int.parse('${r['positionId']}'): r,
      };
      if (next && result.isNotEmpty && combined.length == rows.length) {
        throw const FormatException('岗位分页未更新，请重试');
      }
      setState(() {
        rows = combined.values.toList();
        page = current;
        more = result.length == 20;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => error = messageError(e));
      }
    } finally {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  Future<void> select(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发送岗位'),
        content: Text('将“${row['title']}”岗位卡片发送给当前求职者？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认发送'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      Navigator.pop(context, int.parse('${row['positionId']}'));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '选择要发送的岗位',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: '关闭岗位选择',
              ),
            ],
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '仅显示本企业在招岗位；确认后发送卡片。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: input,
            maxLength: 100,
            onSubmitted: (_) => load(),
            decoration: InputDecoration(
              labelText: '搜索岗位',
              counterText: '',
              suffixIcon: IconButton(
                onPressed: () => load(),
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      if (error != null) ...[
                        Text(error!),
                        TextButton(
                          onPressed: () => load(),
                          child: const Text('重新读取岗位'),
                        ),
                      ],
                      if (rows.isEmpty && error == null)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '暂无可发送的在招岗位',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SharedJobCardView(
                            card: SharedJobCard.parse(6, _encode(row))!,
                            onTap: () => select(row),
                          ),
                        ),
                      if (more)
                        TextButton(
                          onPressed: loadingMore
                              ? null
                              : () => load(next: true),
                          child: Text(loadingMore ? '加载中…' : '加载更多岗位'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
