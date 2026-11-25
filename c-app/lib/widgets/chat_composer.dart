import 'dart:async';

import 'package:flutter/material.dart';

import '../features/messages/data/chat_speech_input.dart';
import '../theme/app_theme.dart';

class ChatComposerAction {
  const ChatComposerAction(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// HR 与 AI 共用输入栏；语音结果只写入草稿，不自动发送。
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.busy = false,
    this.maxLength = 1000,
    this.onCamera,
    this.cameraTooltip = '拍照',
    this.moreTooltip = '更多功能',
    this.actions = const [],
    this.onStop,
    this.stopping = false,
    this.speechInput,
    this.safeArea = true,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled, busy, stopping, safeArea;
  final int maxLength;
  final VoidCallback? onCamera, onStop;
  final String cameraTooltip, moreTooltip;
  final List<ChatComposerAction> actions;
  final ChatSpeechInput? speechInput;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer>
    with WidgetsBindingObserver {
  late final ChatSpeechInput _speech;
  final _focus = FocusNode();
  bool _voice = false, _holding = false, _processing = false, _cancel = false;
  double _startY = 0;
  int? _pointer;
  Timer? _limit;
  TextEditingValue? _draft;

  bool get _available =>
      widget.enabled && !widget.busy && !_processing && !_holding;

  @override
  void initState() {
    super.initState();
    _speech = widget.speechInput ?? ChatSpeechInput();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        widget.busy ||
        oldWidget.controller != widget.controller) {
      unawaited(_finish(cancel: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_finish(cancel: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _limit?.cancel();
    unawaited(_speech.finish(cancel: true));
    _focus.dispose();
    super.dispose();
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _start(PointerDownEvent event) async {
    if (!_available || !_voice) return;
    _draft = widget.controller.value;
    _pointer = event.pointer;
    _startY = event.position.dy;
    setState(() {
      _holding = true;
      _cancel = false;
    });
    _limit = Timer(const Duration(seconds: 60), () => _finish());
    try {
      await _speech.start();
    } on FormatException catch (error) {
      if (mounted && _holding) {
        _notice(error.message);
        await _finish(cancel: true);
      }
    } catch (_) {
      if (mounted && _holding) {
        _notice('语音识别暂不可用，请使用键盘输入');
        await _finish(cancel: true);
      }
    }
  }

  Future<void> _finish({bool cancel = false}) async {
    if (!_holding && !_processing) return;
    if (_processing && !cancel) return;
    _limit?.cancel();
    _pointer = null;
    if (mounted) {
      setState(() {
        _holding = false;
        _processing = !cancel;
      });
    }
    try {
      final text = await _speech.finish(cancel: cancel || _cancel);
      if (!mounted || text == null || !widget.enabled || widget.busy) return;
      if (widget.controller.value != _draft) {
        _notice('草稿已变化，语音未写入，请重试');
        return;
      }
      final draft = _draft!;
      final selection = draft.selection;
      final start = selection.isValid ? selection.start : draft.text.length;
      final end = selection.isValid ? selection.end : draft.text.length;
      final combined = draft.text.replaceRange(start, end, text);
      if (combined.characters.length > widget.maxLength) {
        _notice('识别后文字过长，请分段输入');
        return;
      }
      widget.controller.value = TextEditingValue(
        text: combined,
        selection: TextSelection.collapsed(offset: start + text.length),
      );
      setState(() => _voice = false);
    } on FormatException catch (error) {
      _notice(error.message);
    } catch (_) {
      _notice('语音识别失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _cancel = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_holding || _processing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _processing
                    ? '正在识别…'
                    : _cancel
                    ? '松开取消'
                    : '正在聆听 · 松开转文字，上滑取消',
                style: TextStyle(
                  color: _cancel ? AppColors.red : AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.hairline),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: _voice ? '切换键盘输入' : '切换语音输入',
                  onPressed: _available
                      ? () {
                          _focus.unfocus();
                          setState(() => _voice = !_voice);
                        }
                      : null,
                  icon: Icon(
                    _voice ? Icons.keyboard_outlined : Icons.mic_none_rounded,
                  ),
                  color: AppColors.ink,
                ),
                Expanded(
                  child: _voice
                      ? Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: _start,
                          onPointerMove: (event) {
                            if (event.pointer == _pointer && _holding) {
                              final cancel = _startY - event.position.dy > 60;
                              if (cancel != _cancel) {
                                setState(() => _cancel = cancel);
                              }
                            }
                          },
                          onPointerUp: (event) {
                            if (event.pointer == _pointer) _finish();
                          },
                          onPointerCancel: (event) {
                            if (event.pointer == _pointer) {
                              _finish(cancel: true);
                            }
                          },
                          child: SizedBox(
                            height: 44,
                            child: Center(
                              child: Text(
                                _holding
                                    ? (_cancel ? '松开取消' : '松开转文字')
                                    : _processing
                                    ? '正在识别…'
                                    : '按住 说话',
                                style: TextStyle(
                                  color: widget.enabled
                                      ? AppColors.ink
                                      : AppColors.muted,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        )
                      : TextField(
                          controller: widget.controller,
                          focusNode: _focus,
                          enabled: widget.enabled && !_processing,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: widget.maxLength,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: '发消息或切换语音…',
                            counterText: '',
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 2,
                            ),
                          ),
                        ),
                ),
                IconButton(
                  tooltip: widget.cameraTooltip,
                  onPressed: _available ? widget.onCamera : null,
                  icon: const Icon(Icons.camera_alt_outlined),
                  color: AppColors.ink,
                ),
                PopupMenuButton<int>(
                  tooltip: widget.moreTooltip,
                  enabled: _available && widget.actions.isNotEmpty,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.ink,
                  ),
                  onSelected: (index) => widget.actions[index].onTap(),
                  itemBuilder: (_) => [
                    for (var i = 0; i < widget.actions.length; i++)
                      PopupMenuItem(
                        value: i,
                        child: Row(
                          children: [
                            Icon(widget.actions[i].icon, size: 20),
                            const SizedBox(width: 12),
                            Text(widget.actions[i].label),
                          ],
                        ),
                      ),
                  ],
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (_, value, _) {
                    if (widget.onStop != null) {
                      return IconButton(
                        tooltip: '停止生成',
                        onPressed: widget.stopping ? null : widget.onStop,
                        icon: const Icon(
                          Icons.stop_circle_outlined,
                          color: AppColors.interactive,
                        ),
                      );
                    }
                    if (widget.busy) {
                      return const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    if (value.text.trim().isEmpty || _voice) {
                      return const SizedBox.shrink();
                    }
                    return IconButton.filled(
                      tooltip: '发送',
                      onPressed: _available ? widget.onSend : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return widget.safeArea ? SafeArea(top: false, child: content) : content;
  }
}
