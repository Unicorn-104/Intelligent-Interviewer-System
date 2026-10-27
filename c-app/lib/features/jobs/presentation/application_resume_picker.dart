import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/job.dart';
import '../../resume/data/resume_api.dart';
import '../../resume/domain/app_resume.dart';

Future<int?> chooseApplicationResume(
  BuildContext context, {
  required String token,
  required Job job,
  int? preferredResumeId,
  ResumeApi? api,
}) => showDialog<int>(
  context: context,
  builder: (_) => _ResumePicker(
    token: token,
    job: job,
    preferredResumeId: preferredResumeId,
    api: api,
  ),
);

class _ResumePicker extends StatefulWidget {
  const _ResumePicker({
    required this.token,
    required this.job,
    this.preferredResumeId,
    this.api,
  });
  final String token;
  final Job job;
  final int? preferredResumeId;
  final ResumeApi? api;
  @override
  State<_ResumePicker> createState() => _ResumePickerState();
}

class _ResumePickerState extends State<_ResumePicker> {
  final _client = ApiClient();
  List<AppResume>? _resumes;
  String? _error;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _resumes = null;
      _error = null;
      _selected = null;
    });
    try {
      final items = (await (widget.api ?? ResumeApi(_client)).list(
        widget.token,
      )).where((r) => r.resumeId != null).toList();
      if (!mounted) return;
      final preferred = items.where(
        (r) => r.resumeId == widget.preferredResumeId,
      );
      final defaults = items.where((r) => r.isDefault);
      setState(() {
        _resumes = items;
        _selected = preferred.isNotEmpty
            ? preferred.first.resumeId
            : defaults.isNotEmpty
            ? defaults.first.resumeId
            : items.isNotEmpty
            ? items.first.resumeId
            : null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException ? error.message : '简历加载失败，请重试',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('选择投递简历'),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('投递给「${widget.job.company}」的“${widget.job.title}”岗位'),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('重试')),
          ] else if (_resumes == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_resumes!.isEmpty)
            const Text('暂无可投递的简历，请先到简历页创建或导入简历')
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final resume in _resumes!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _selected == resume.resumeId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        title: Text(
                          resume.resumeName.isEmpty
                              ? '未命名简历'
                              : resume.resumeName,
                        ),
                        subtitle: Text(
                          [
                            if (resume.isDefault) '默认简历',
                            if (resume.jobDirection.isNotEmpty)
                              resume.jobDirection,
                          ].join(' · '),
                        ),
                        selected: _selected == resume.resumeId,
                        onTap: () =>
                            setState(() => _selected = resume.resumeId),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('暂不投递'),
      ),
      FilledButton(
        onPressed: _selected == null
            ? null
            : () => Navigator.pop(context, _selected),
        child: const Text('确认投递'),
      ),
    ],
  );
}
