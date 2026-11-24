import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

/// 系统识别只返回文字，不创建消息或保存音频。
abstract class ChatSpeechEngine {
  Future<bool> initialize(void Function(String) onError);
  Future<List<String>> locales();
  Future<void> listen(String locale, void Function(String, bool) onResult);
  Future<void> stop();
  Future<void> cancel();
}

class SystemChatSpeechEngine implements ChatSpeechEngine {
  final SpeechToText _speech = SpeechToText();

  @override
  Future<bool> initialize(void Function(String) onError) async {
    final ready = await _speech.initialize(debugLogging: false);
    _speech.errorListener = (error) => onError(error.errorMsg);
    return ready;
  }

  @override
  Future<List<String>> locales() async =>
      (await _speech.locales()).map((locale) => locale.localeId).toList();

  @override
  Future<void> listen(
    String locale,
    void Function(String, bool) onResult,
  ) async {
    await _speech.listen(
      localeId: locale,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
  @override
  Future<void> cancel() => _speech.cancel();
}

class ChatSpeechInput {
  ChatSpeechInput({ChatSpeechEngine? engine})
    : _engine = engine ?? SystemChatSpeechEngine();
  final ChatSpeechEngine _engine;
  int _generation = 0;
  bool _active = false, _listening = false;
  String _words = '';
  String? _error;
  Completer<void>? _finalResult;

  Future<void> start() async {
    if (_active) return;
    final generation = ++_generation;
    _active = true;
    _words = '';
    _error = null;
    _finalResult = Completer<void>();
    try {
      final available = await _engine.initialize((code) {
        if (generation != _generation) return;
        _error = switch (code) {
          'error_permission' ||
          'error_insufficient_permissions' => '请在系统设置中允许麦克风和语音识别权限',
          'error_no_match' || 'error_speech_timeout' => '没有听清，请重试',
          'error_network' || 'error_network_timeout' => '语音识别连接失败，请检查网络后重试',
          _ => '语音识别暂不可用，请使用键盘输入',
        };
        if (!(_finalResult?.isCompleted ?? true)) _finalResult!.complete();
      });
      if (generation != _generation || !_active) return;
      if (!available) throw const FormatException('本机语音识别不可用，请检查权限或使用键盘输入');
      final locales = await _engine.locales();
      if (generation != _generation || !_active) return;
      final chinese = locales
          .where((id) => id.toLowerCase().startsWith('zh'))
          .toList();
      if (chinese.isEmpty) throw const FormatException('本机未提供中文语音识别，请使用键盘输入');
      final locale = chinese.firstWhere(
        (id) => id.replaceAll('_', '-').toLowerCase() == 'zh-cn',
        orElse: () => chinese.first,
      );
      _listening = true;
      await _engine.listen(locale, (words, finalResult) {
        if (generation != _generation) return;
        _words = words;
        if (finalResult && !(_finalResult?.isCompleted ?? true)) {
          _finalResult!.complete();
        }
      });
      if (generation != _generation || !_active) await _engine.cancel();
    } catch (error) {
      if (generation == _generation) {
        _error = error is FormatException ? error.message : '语音识别暂不可用，请使用键盘输入';
        _active = false;
        _listening = false;
        await _engine.cancel();
        throw FormatException(_error!);
      }
    }
  }

  Future<String?> finish({bool cancel = false}) async {
    if (cancel) {
      if (!_active && !_listening) return null;
      ++_generation;
      _active = false;
      _listening = false;
      await _engine.cancel();
      return null;
    }
    if (!_active) return null;
    _active = false;
    if (!_listening) {
      ++_generation;
      await _engine.cancel();
      return null;
    }
    final generation = _generation;
    final finalResult = _finalResult!;
    try {
      await _engine.stop();
      if (generation != _generation) return null;
      await finalResult.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      if (generation != _generation) return null;
    } finally {
      if (generation == _generation) {
        ++_generation;
        _listening = false;
        await _engine.cancel();
      }
    }
    final words = _words.trim();
    if (words.isNotEmpty) return words;
    throw FormatException(_error ?? '没有听清，请重试');
  }
}
