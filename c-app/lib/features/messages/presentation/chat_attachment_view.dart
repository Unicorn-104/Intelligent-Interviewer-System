import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_exception.dart';
import '../data/message_api.dart';
import '../domain/app_message.dart';

class ChatAttachmentView extends StatefulWidget {
  const ChatAttachmentView({
    super.key,
    required this.message,
    required this.api,
  });
  final ChatMessage message;
  final MessageApi api;
  @override
  State<ChatAttachmentView> createState() => _ChatAttachmentViewState();
}

class _ChatAttachmentViewState extends State<ChatAttachmentView> {
  bool _saving = false;
  int _imageAttempt = 0;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await widget.api.downloadAttachment(
        widget.message.attachmentUrl,
      );
      if (!mounted) return;
      final name = widget.message.content
          .replaceAll(String.fromCharCode(92), '/')
          .split('/')
          .last;
      final safeName = String.fromCharCodes(
        name.runes.map(
          (r) =>
              r < 32 || r == 127 || '<>:|?*"'.contains(String.fromCharCode(r))
              ? 95
              : r,
        ),
      );
      final location = await FilePicker.saveFile(
        fileName: safeName.isEmpty ? '聊天附件' : safeName,
        bytes: bytes,
        dialogTitle: '保存聊天附件',
      );
      if (mounted && location != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('文件已保存，可从系统文件管理器打开')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error is ApiException ? error.message : '文件保存失败，请重试'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final url = widget.api.attachmentUrl(message.attachmentUrl);
    if (url == null) {
      return Text(message.type == 2 ? '图片地址无效，暂时无法查看' : '文件地址无效，暂时无法下载');
    }
    if (message.type == 3) {
      return InkWell(
        onTap: _saving ? null : _save,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.content.isEmpty ? '文件附件' : message.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _saving ? '正在下载…' : '点击下载并保存',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (_saving)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      );
    }
    return Semantics(
      label: '查看图片',
      button: true,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => _ChatImagePreview(url: url)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210, maxHeight: 280),
            child: Image.network(
              url,
              key: ValueKey((url, _imageAttempt)),
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 150,
                      width: 210,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (_, _, _) => TextButton.icon(
                onPressed: () {
                  NetworkImage(url).evict();
                  setState(() => _imageAttempt++);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('图片加载失败，重试'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatImagePreview extends StatefulWidget {
  const _ChatImagePreview({required this.url});
  final String url;
  @override
  State<_ChatImagePreview> createState() => _ChatImagePreviewState();
}

class _ChatImagePreviewState extends State<_ChatImagePreview> {
  int _attempt = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('查看图片'),
      actions: [
        IconButton(
          tooltip: '重新加载图片',
          onPressed: () {
            NetworkImage(widget.url).evict();
            setState(() => _attempt++);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Image.network(
          widget.url,
          key: ValueKey(_attempt),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Text('图片暂不可用，请重新加载'),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : const CircularProgressIndicator(),
        ),
      ),
    ),
  );
}
