import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

enum JdDocumentImportPhase { idle, selecting, uploading, parsing, ready }

class JdDocumentImportCard extends StatelessWidget {
  const JdDocumentImportCard({
    super.key,
    required this.phase,
    required this.onImport,
    required this.onReview,
    this.onRetry,
    this.filename,
    this.error,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.hasDraft = false,
    this.applied = false,
    this.enabled = true,
  });

  final JdDocumentImportPhase phase;
  final VoidCallback onImport;
  final VoidCallback onReview;
  final VoidCallback? onRetry;
  final String? filename;
  final String? error;
  final int sentBytes;
  final int totalBytes;
  final bool hasDraft;
  final bool applied;
  final bool enabled;

  bool get _busy => switch (phase) {
    JdDocumentImportPhase.selecting ||
    JdDocumentImportPhase.uploading ||
    JdDocumentImportPhase.parsing => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('jd-document-import-card'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.accentPurple,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '从文档导入 JD',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'AI',
                style: TextStyle(color: AppColors.accentPurple),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '支持 PDF / DOCX，文件 ≤10MB',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        const Text(
          'AI 结果仅供参考',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          _progress(),
        ] else if (phase == JdDocumentImportPhase.ready) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              error != null
                  ? '上次解析的草稿仍可核对'
                  : applied
                  ? '草稿已回填，请继续编辑并预览'
                  : '解析完成，请核对',
              style: const TextStyle(color: AppColors.success),
            ),
          ),
        ],
        if (filename != null && !_busy) ...[
          const SizedBox(height: 8),
          Text(
            filename!,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Container(
              key: const Key('jd-document-import-error'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              key: const Key('jd-document-import-select'),
              onPressed: enabled && !_busy ? onImport : null,
              icon: const Icon(Icons.upload_file_outlined, size: 20),
              label: Text(
                _busy
                    ? '处理中'
                    : hasDraft || error != null
                    ? '重新选择文档'
                    : '选择文档',
              ),
            ),
            if (error != null && onRetry != null)
              TextButton(
                key: const Key('jd-document-import-retry'),
                onPressed: enabled && !_busy ? onRetry : null,
                child: const Text('重试解析'),
              ),
            if (hasDraft)
              TextButton(
                key: const Key('jd-document-import-review'),
                onPressed: enabled && !_busy ? onReview : null,
                child: Text(applied ? '查看核对结果' : '核对草稿'),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _progress() {
    final uploading = phase == JdDocumentImportPhase.uploading;
    final label = switch (phase) {
      JdDocumentImportPhase.selecting => '正在选择文档',
      JdDocumentImportPhase.uploading => '正在上传',
      _ => '正在解析',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.canvas,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (filename != null && phase != JdDocumentImportPhase.selecting) ...[
            const SizedBox(height: 4),
            Text(filename!, style: const TextStyle(color: AppColors.canvas)),
          ],
          const SizedBox(height: 12),
          LinearProgressIndicator(
            key: const Key('jd-document-import-progress'),
            value: uploading && totalBytes > 0
                ? (sentBytes / totalBytes).clamp(0.0, 1.0)
                : null,
            color: AppColors.accentPurple,
            backgroundColor: AppColors.canvas.withValues(alpha: 0.14),
          ),
          if (uploading) ...[
            const SizedBox(height: 8),
            Text(
              totalBytes > 0
                  ? '$sentBytes / $totalBytes 字节'
                  : '已上传 $sentBytes 字节',
              style: const TextStyle(color: AppColors.canvas, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
