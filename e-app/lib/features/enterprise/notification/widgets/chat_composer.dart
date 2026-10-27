import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_theme.dart';
import '../../../../core/network/api_exception.dart';
import '../models/message_view_data.dart';

enum ChatComposerPanel { none, quickReplies, emoji, attachments }

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.disabled,
    required this.canSend,
    required this.sending,
    required this.quickReplies,
    required this.quickLoading,
    required this.quickError,
    required this.maxPanelHeight,
    required this.maxInputLines,
    required this.onSend,
    required this.onSendQuick,
    required this.onReloadQuick,
    required this.onSaveQuick,
    required this.onAttachment,
    this.onSendJob,
    required this.onPanelChanged,
  });

  final TextEditingController controller;
  final bool disabled, canSend, sending, quickLoading;
  final List<ChatQuickReply> quickReplies;
  final String? quickError;
  final double maxPanelHeight;
  final int maxInputLines;
  final VoidCallback onSend, onReloadQuick;
  final VoidCallback? onSendJob;
  final ValueChanged<String> onSendQuick;
  final Future<void> Function(ChatQuickReply? reply, String text) onSaveQuick;
  final ValueChanged<bool> onAttachment, onPanelChanged;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _focus = FocusNode();
  ChatComposerPanel _panel = ChatComposerPanel.none;
  bool _editingQuick = false;
  final List<String> _recentEmoji = [];
  static const _emoji = [
    '😊',
    '😄',
    '😁',
    '🙂',
    '😉',
    '😍',
    '🥰',
    '😘',
    '🤗',
    '🤔',
    '😎',
    '🥳',
    '😅',
    '😂',
    '😭',
    '🥺',
    '😮',
    '😴',
    '😔',
    '😢',
    '👍',
    '👎',
    '👏',
    '🙏',
    '🤝',
    '💪',
    '👌',
    '✌️',
    '🙌',
    '👋',
    '❤️',
    '🌹',
    '🎉',
    '🎊',
    '☀️',
    '🌈',
    '✨',
    '💐',
    '✅',
    '💯',
  ];

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    widget.controller.addListener(_textChanged);
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_textChanged);
      widget.controller.addListener(_textChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_textChanged);
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    super.dispose();
  }

  void _textChanged() {
    if (mounted) setState(() {});
  }

  void _focusChanged() {
    if (!mounted) return;
    if (_focus.hasFocus) {
      _panel = ChatComposerPanel.none;
      widget.onPanelChanged(false);
    }
    setState(() {});
  }

  void _togglePanel(ChatComposerPanel panel) {
    if (widget.disabled) return;
    _focus.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    setState(() {
      _panel = _panel == panel ? ChatComposerPanel.none : panel;
      _editingQuick = false;
    });
    widget.onPanelChanged(_panel != ChatComposerPanel.none);
  }

  void _keyboard() {
    setState(() => _panel = ChatComposerPanel.none);
    widget.onPanelChanged(false);
    _focus.requestFocus();
  }

  void _insertEmoji(String emoji) {
    final value = widget.controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final text = value.text.replaceRange(selection.start, selection.end, emoji);
    if (text.length > 1000) return;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
    setState(() {
      _recentEmoji.remove(emoji);
      _recentEmoji.insert(0, emoji);
      if (_recentEmoji.length > 8) _recentEmoji.removeLast();
    });
  }

  void _deleteEmoji() {
    final value = widget.controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    var start = selection.start;
    if (selection.isCollapsed) {
      if (start == 0) return;
      final before = value.text.substring(0, start);
      start -= before.characters.last.length;
    }
    widget.controller.value = TextEditingValue(
      text: value.text.replaceRange(start, selection.end, ''),
      selection: TextSelection.collapsed(offset: start),
    );
  }

  Future<void> _editQuick([ChatQuickReply? reply]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) =>
          _QuickReplyEditor(reply: reply, onSave: widget.onSaveQuick),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final keyboardMode = _panel == ChatComposerPanel.emoji;
    final idle =
        !_focus.hasFocus && !hasText && _panel == ChatComposerPanel.none;
    return PopScope(
      canPop: _panel == ChatComposerPanel.none,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _panel = ChatComposerPanel.none);
          widget.onPanelChanged(false);
        }
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.canvas,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: DecoratedBox(
                key: const Key('chat-composer-toolbar'),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        key: const Key('chat-quick-toggle'),
                        tooltip: '常用语',
                        onPressed: widget.disabled
                            ? null
                            : () =>
                                  _togglePanel(ChatComposerPanel.quickReplies),
                        icon: idle
                            ? const CircleAvatar(
                                radius: 17,
                                backgroundColor: AppColors.interactive,
                                child: Text(
                                  '常',
                                  style: TextStyle(
                                    color: AppColors.canvas,
                                    fontSize: 17,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.short_text,
                                color: AppColors.interactive,
                              ),
                      ),
                      Expanded(
                        child: TextField(
                          key: const Key('chat-input'),
                          controller: widget.controller,
                          focusNode: _focus,
                          enabled: !widget.disabled,
                          minLines: 1,
                          maxLines: widget.maxInputLines,
                          maxLength: 1000,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(1000),
                          ],
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: '和TA聊一聊～',
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('chat-emoji-toggle'),
                        tooltip: keyboardMode ? '切换键盘' : '表情',
                        onPressed: widget.disabled
                            ? null
                            : keyboardMode
                            ? _keyboard
                            : () => _togglePanel(ChatComposerPanel.emoji),
                        icon: Icon(
                          keyboardMode
                              ? Icons.keyboard_alt_outlined
                              : Icons.sentiment_satisfied_alt,
                        ),
                      ),
                      if (hasText || widget.sending)
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Tooltip(
                            message: '发送消息',
                            child: FilledButton(
                              key: const Key('chat-send'),
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(46, 46),
                                shape: const CircleBorder(),
                              ),
                              onPressed: widget.canSend ? widget.onSend : null,
                              child: widget.sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send_rounded,
                                      size: 23,
                                      semanticLabel: '发送消息',
                                    ),
                            ),
                          ),
                        )
                      else
                        IconButton(
                          key: const Key('chat-more-toggle'),
                          tooltip: _panel == ChatComposerPanel.attachments
                              ? '收起附件'
                              : '更多',
                          onPressed: widget.disabled
                              ? null
                              : () =>
                                    _togglePanel(ChatComposerPanel.attachments),
                          icon: Icon(
                            _panel == ChatComposerPanel.attachments
                                ? Icons.cancel_outlined
                                : Icons.add_circle_outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_panel != ChatComposerPanel.none)
              SizedBox(
                key: const Key('chat-composer-panel'),
                height: widget.maxPanelHeight.clamp(0.0, 280.0),
                child: switch (_panel) {
                  ChatComposerPanel.quickReplies => _quickPanel(),
                  ChatComposerPanel.emoji => _emojiPanel(),
                  ChatComposerPanel.attachments => _attachmentPanel(),
                  ChatComposerPanel.none => const SizedBox.shrink(),
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickPanel() => ListView(
    key: const Key('chat-quick-panel'),
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text('常用语', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            key: const Key('chat-quick-add'),
            tooltip: '添加常用语',
            onPressed: widget.disabled ? null : () => _editQuick(),
            icon: const Icon(Icons.add, color: AppColors.interactive),
          ),
          IconButton(
            key: const Key('chat-quick-manage'),
            tooltip: _editingQuick ? '完成编辑' : '编辑常用语',
            onPressed: widget.disabled
                ? null
                : () => setState(() => _editingQuick = !_editingQuick),
            icon: Icon(
              _editingQuick ? Icons.check : Icons.edit_outlined,
              color: AppColors.interactive,
            ),
          ),
        ],
      ),
      if (widget.quickLoading)
        const Padding(padding: EdgeInsets.all(12), child: Text('正在读取常用语…'))
      else if (widget.quickError != null)
        Column(
          children: [
            Text(
              widget.quickError!,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            TextButton(
              onPressed: widget.onReloadQuick,
              child: const Text('重试读取常用语'),
            ),
          ],
        )
      else if (widget.quickReplies.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('暂无常用语，点击右上角添加'))
      else
        for (final reply in widget.quickReplies)
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: ValueKey('chat-quick-item-${reply.id}'),
                    onTap: widget.canSend && !_editingQuick
                        ? () => widget.onSendQuick(reply.content)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        reply.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                if (_editingQuick)
                  IconButton(
                    key: ValueKey('chat-quick-edit-${reply.id}'),
                    tooltip: '修改常用语',
                    onPressed: widget.disabled ? null : () => _editQuick(reply),
                    icon: const Icon(Icons.edit_outlined),
                  )
                else
                  TextButton(
                    key: ValueKey('chat-quick-send-${reply.id}'),
                    onPressed: widget.canSend
                        ? () => widget.onSendQuick(reply.content)
                        : null,
                    child: const Text('发送'),
                  ),
              ],
            ),
          ),
    ],
  );

  Widget _emojiPanel() => ListView(
    key: const Key('chat-emoji-panel'),
    padding: const EdgeInsets.all(12),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text('表情', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            key: const Key('chat-emoji-delete'),
            tooltip: '删除一个表情或字符',
            onPressed: widget.disabled ? null : _deleteEmoji,
            icon: const Icon(Icons.backspace_outlined),
          ),
        ],
      ),
      if (_recentEmoji.isNotEmpty) ...[
        const Text(
          '最近使用',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        Wrap(
          children: [
            for (final emoji in _recentEmoji) _emojiButton(emoji, recent: true),
          ],
        ),
      ],
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '全部表情',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ),
      Wrap(children: [for (final emoji in _emoji) _emojiButton(emoji)]),
    ],
  );

  Widget _emojiButton(String emoji, {bool recent = false}) => SizedBox(
    width: 46,
    height: 46,
    child: TextButton(
      key: ValueKey('chat-emoji-${recent ? 'recent-' : ''}$emoji'),
      onPressed: widget.disabled ? null : () => _insertEmoji(emoji),
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: Text(
        emoji,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(fontSize: 28),
      ),
    ),
  );

  Widget _attachmentPanel() => ListView(
    key: const Key('chat-attachment-panel'),
    padding: const EdgeInsets.all(16),
    children: [
      const Text('发送内容', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 20,
        runSpacing: 12,
        children: [
          _attachmentAction('图片', Icons.image_outlined, true),
          _attachmentAction('文件', Icons.insert_drive_file_outlined, false),
          if (widget.onSendJob != null)
            SizedBox(
              width: 86,
              child: OutlinedButton(
                key: const Key('chat-send-job'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: widget.canSend ? widget.onSendJob : null,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.work_outline, size: 30),
                    SizedBox(height: 8),
                    Text('发送岗位'),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        '图片或文件选择后需确认发送；单个附件不超过10MB',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    ],
  );

  Widget _attachmentAction(String label, IconData icon, bool image) => SizedBox(
    width: 86,
    child: OutlinedButton(
      key: ValueKey(image ? 'chat-pick-image' : 'chat-pick-file'),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
      onPressed: widget.canSend ? () => widget.onAttachment(image) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    ),
  );
}

class _QuickReplyEditor extends StatefulWidget {
  const _QuickReplyEditor({required this.reply, required this.onSave});
  final ChatQuickReply? reply;
  final Future<void> Function(ChatQuickReply? reply, String text) onSave;
  @override
  State<_QuickReplyEditor> createState() => _QuickReplyEditorState();
}

class _QuickReplyEditorState extends State<_QuickReplyEditor> {
  late final _text = TextEditingController(text: widget.reply?.content ?? '');
  bool _saving = false, _uncertain = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (_saving || _uncertain) return;
    if (text.isEmpty || text.length > 1000) {
      setState(() => _error = '请输入1至1000个字符');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(widget.reply, text);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _uncertain = error is! ApiException || error.code == null;
          _error = _uncertain
              ? '保存结果待核对，请关闭后重新读取常用语，避免重复新增'
              : (error is ApiException ? error.message : '保存失败，请稍后重试');
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.reply == null ? '添加常用语' : '修改常用语',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '当前服务使用共享模板，保存后其他招聘者也可能看到该常用语。请勿填写个人隐私或敏感信息。',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('chat-quick-editor'),
              controller: _text,
              enabled: !_saving,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: '输入常用语内容'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  key: const Key('chat-quick-save'),
                  onPressed: _saving || _uncertain ? null : _save,
                  child: Text(_saving ? '保存中' : '保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
