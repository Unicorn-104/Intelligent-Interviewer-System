import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../applications/data/application_api.dart';
import '../../applications/domain/job_application.dart';
import '../../applications/presentation/application_controller.dart';

class AiApplicationPicker extends StatefulWidget {
  const AiApplicationPicker({
    super.key,
    required this.api,
    required this.token,
  });
  final ApplicationApi api;
  final String token;

  @override
  State<AiApplicationPicker> createState() => _AiApplicationPickerState();
}

class _AiApplicationPickerState extends State<AiApplicationPicker> {
  late final ApplicationController _controller;
  bool _selecting = false;
  String? _selectionError;

  @override
  void initState() {
    super.initState();
    _controller = ApplicationController(widget.api, widget.token)..refresh();
  }

  Future<void> _select(JobApplication item) async {
    if (_selecting) return;
    setState(() {
      _selecting = true;
      _selectionError = null;
    });
    try {
      final detail = await widget.api.detail(widget.token, item.id);
      if (!mounted) return;
      if (detail.resumeId == null || detail.resumeId! <= 0) {
        setState(() => _selectionError = '该投递缺少关联简历，请选择其他岗位');
        return;
      }
      Navigator.pop(context, detail);
    } catch (error) {
      if (mounted) {
        setState(
          () => _selectionError = error is ApiException
              ? error.message
              : '岗位加载失败，请重试',
        );
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.65,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Column(
          children: [
            const ListTile(
              title: Text('选择已投递的岗位'),
              subtitle: Text('自动使用该次投递关联的简历'),
            ),
            if (_selecting) const LinearProgressIndicator(),
            if (_selectionError != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(_selectionError!),
              ),
            Expanded(
              child: _controller.loading && !_controller.initialized
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _controller.refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (_controller.error != null)
                            ListTile(
                              title: Text(_controller.error!),
                              trailing: TextButton(
                                onPressed: _selecting
                                    ? null
                                    : _controller.retry,
                                child: const Text('重试'),
                              ),
                            ),
                          if (_controller.items.isEmpty &&
                              _controller.error == null)
                            const Padding(
                              padding: EdgeInsets.all(AppSpacing.xxl),
                              child: Text(
                                '暂无已投递岗位，可先投递岗位后准备面试',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          for (final item in _controller.items)
                            ListTile(
                              title: Text(item.jobTitle),
                              subtitle: Text(
                                '${item.companyName}\n投递简历：${item.resumeName ?? '查看详情'}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _selecting ? null : () => _select(item),
                            ),
                          if (_controller.loadingMore)
                            const Center(child: CircularProgressIndicator())
                          else if (_controller.hasNext)
                            TextButton(
                              onPressed: _selecting
                                  ? null
                                  : _controller.loadMore,
                              child: const Text('加载更多'),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
