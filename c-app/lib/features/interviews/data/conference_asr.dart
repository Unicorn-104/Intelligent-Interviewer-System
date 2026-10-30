import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'conference_api.dart';

/// Uses the published microphone track, avoiding a second microphone capture.
class ConferenceAsr {
  WebSocket? _socket;
  Future<void> Function()? _removeRenderer;
  int _generation = 0;
  String? notice;

  Future<void> start(
    ConferenceApi api,
    int id,
    lk.LocalAudioTrack track,
    void Function() onChanged,
  ) async {
    await stop();
    final generation = _generation;
    try {
      final status = await api.asrStatus(id);
      if (generation != _generation) return;
      if (status['enabled'] != true) {
        notice = '实时字幕暂不可用，可继续进行面试';
        onChanged();
        return;
      }
      final ticket = await api.asrTicket(id);
      if (generation != _generation) return;
      if (ticket['ticket'] is! String || (ticket['ticket'] as String).isEmpty) {
        throw const FormatException();
      }
      final base = Uri.parse(api.client.baseUrl);
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws/conference-asr',
        queryParameters: {'ticket': ticket['ticket'] as String},
      );
      final socket = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 10));
      if (generation != _generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      notice = null;
      socket.listen(
        (raw) {
          if (generation != _generation || raw is! String) return;
          try {
            final data = jsonDecode(raw);
            if (data is Map && data['type'] == 'error') {
              notice = '实时字幕暂不可用，可继续进行面试';
              unawaited(stop());
              onChanged();
            }
            // Stable sentences are persisted by the server and deduplicated by
            // the common captions cursor. No transcript text is logged locally.
          } catch (_) {
            /* Ignore malformed non-caption frames. */
          }
        },
        onError: (_) {
          if (generation != _generation) return;
          notice = '字幕连接已中断，可重新连接';
          unawaited(stop());
          onChanged();
        },
        onDone: () {
          if (generation != _generation) return;
          notice = '字幕连接已中断，可重新连接';
          unawaited(stop());
          onChanged();
        },
      );
      var pending = Uint8List(0);
      _removeRenderer = track.addAudioRenderer(
        options: const lk.AudioRendererOptions(
          sampleRate: 16000,
          channels: 1,
          format: lk.AudioFormat.Int16,
        ),
        onFrame: (frame) {
          if (generation != _generation ||
              socket.readyState != WebSocket.open ||
              track.muted) {
            return;
          }
          final bytes = Uint8List(pending.length + frame.data.length)
            ..setAll(0, pending)
            ..setAll(pending.length, frame.data);
          var offset = 0;
          // Same framing as PC: 16 kHz, mono PCM16, 200 ms per frame.
          while (bytes.length - offset >= 6400) {
            socket.add(Uint8List.sublistView(bytes, offset, offset + 6400));
            offset += 6400;
          }
          pending = Uint8List.fromList(bytes.sublist(offset));
        },
      );
      onChanged();
    } catch (_) {
      if (generation != _generation) return;
      notice = '实时字幕暂不可用，可继续进行面试';
      await stop();
      onChanged();
    }
  }

  Future<void> stop() async {
    _generation++;
    final remove = _removeRenderer;
    _removeRenderer = null;
    await remove?.call();
    final socket = _socket;
    _socket = null;
    if (socket?.readyState == WebSocket.open) {
      socket!.add(jsonEncode({'type': 'end'}));
    }
    await socket?.close();
  }
}
