import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_exception.dart';
import '../data/conference_api.dart';
import '../data/conference_media.dart';
import '../data/conference_asr.dart';
import '../domain/conference_readiness.dart';

enum ConferencePhase {
  loading,
  preparation,
  waiting,
  meeting,
  ended,
  invalid,
  error,
}

int conferenceInt(Object? value, [int fallback = 0]) =>
    int.tryParse('$value') ?? fallback;

class ConferenceController extends ChangeNotifier {
  ConferenceController({
    required this.api,
    required this.media,
    required this.userId,
    this.roomToken,
    this.initialSessionId,
    this.pollInterval = const Duration(seconds: 3),
  }) {
    media.addListener(changed);
  }
  final ConferenceApi api;
  final ConferenceMedia media;
  final int userId;
  final String? roomToken;
  final int? initialSessionId;
  final Duration pollInterval;
  final asr = ConferenceAsr();
  ConferencePhase phase = ConferencePhase.loading;
  Map<String, dynamic> context = {}, progress = {}, waiting = {}, result = {};
  final List<Map<String, dynamic>> captions = [];
  String? error, notice;
  int? id, rttMs;
  DateTime? waitingUpdatedAt;
  ConferenceReadiness get readiness =>
      ConferenceReadiness.fromJson(waiting, context, userId);
  int _captionSequence = 0, _ticks = 0;
  bool busy = false,
      checking = false,
      networkOk = false,
      speakerConfirmed = false;
  bool consentAccepted = false, answerUncertain = false;
  bool connecting = false;
  int _answerCountBeforeSubmit = 0;
  bool _disposed = false, _polling = false, _foreground = true;
  Timer? _timer;
  int get mode => conferenceInt(context['mode']);
  bool get canEnter =>
      phase == ConferencePhase.preparation &&
      !busy &&
      !checking &&
      media.cameraOn &&
      media.microphoneOn &&
      networkOk &&
      speakerConfirmed &&
      consentAccepted;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (busy) return;
    busy = true;
    phase = ConferencePhase.loading;
    error = null;
    changed();
    try {
      if (roomToken != null) {
        final info = await api.verify(roomToken!);
        if (_disposed) return;
        if (info['valid'] != true) {
          context = info;
          phase = ConferencePhase.invalid;
          return;
        }
        context = await api.join(roomToken!);
      } else if (initialSessionId != null && initialSessionId! > 0) {
        context = await api.context(initialSessionId!);
      } else {
        throw const FormatException();
      }
      if (_disposed) return;
      final sessionId = conferenceInt(context['sessionId']);
      if (sessionId <= 0 ||
          context['role'] != 'CANDIDATE' ||
          (context['candidateUserId'] != null &&
              conferenceInt(context['candidateUserId']) != userId)) {
        phase = ConferencePhase.invalid;
        return;
      }
      id = sessionId;
      if (![1, 2, 3, 4].contains(mode)) throw const FormatException();
      final status = conferenceInt(context['status'], -1);
      if (status >= 2) {
        await _ended();
        return;
      }
      if (![0, 1].contains(status)) throw const FormatException();
      // Every entry performs device checks and explicit consent before capture
      // is published, including a previously running session.
      phase = ConferencePhase.preparation;
    } catch (e) {
      if (_disposed) return;
      phase = ConferencePhase.error;
      error = e is ApiException && e.code == 401
          ? '登录已失效，请重新登录'
          : '无法读取面试信息，请重试或联系 HR';
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> check() async {
    if (checking || busy || id == null || !_foreground) return;
    checking = true;
    error = null;
    changed();
    try {
      await media.checkDevices();
      final watch = Stopwatch()..start();
      context = await api.context(id!);
      rttMs = watch.elapsedMilliseconds;
      networkOk = true;
      if (_disposed || !_foreground) return;
      await api.participant(id!, _environment(0));
    } catch (_) {
      networkOk = false;
      error = '设备或网络检测未完成，请重试';
    } finally {
      checking = false;
      changed();
    }
  }

  Map<String, dynamic> _environment(int ready) => {
    'camStatus': media.cameraOn ? 1 : 3,
    'micStatus': media.microphoneOn ? 1 : 3,
    'speakerStatus': speakerConfirmed ? 1 : 0,
    'netStatus': networkOk ? 1 : 3,
    'rttMs': rttMs,
    'riskFlag': (rttMs ?? 0) > 500 ? 1 : 0,
    'ready': ready,
  };
  void confirmSpeaker(bool value) {
    speakerConfirmed = value;
    changed();
  }

  Future<void> setConsent(bool value) async {
    if (busy || id == null) return;
    busy = true;
    error = null;
    changed();
    try {
      await api.consent(id!, value);
      consentAccepted = value;
    } catch (_) {
      consentAccepted = false;
      error = '录制同意未保存，请重试';
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> enter() async {
    if (!canEnter || id == null) return;
    busy = true;
    error = null;
    changed();
    try {
      await api.participant(id!, _environment(1));
      if (_disposed || !_foreground) return;
      if (mode == 1) {
        context = await api.start(id!);
        if (conferenceInt(context['status']) != 1) {
          throw const FormatException();
        }
        await _meeting();
      } else {
        phase = ConferencePhase.waiting;
        await media.release();
        _startPolling();
        await poll();
      }
    } catch (_) {
      error = '暂时无法进入面试，请重试';
    } finally {
      busy = false;
      changed();
    }
  }

  void _startPolling() {
    _timer?.cancel();
    if (pollInterval > Duration.zero) {
      _timer = Timer.periodic(pollInterval, (_) => unawaited(poll()));
    }
  }

  Future<void> _meeting() async {
    if (_disposed || !_foreground) return;
    phase = ConferencePhase.meeting;
    changed();
    _startPolling();
    await reconnect();
  }

  Future<void> reconnect() async {
    if (id == null ||
        _disposed ||
        !_foreground ||
        media.connected ||
        connecting ||
        phase != ConferencePhase.meeting) {
      return;
    }
    connecting = true;
    notice = null;
    media.error = null;
    changed();
    try {
      final state = await api.context(id!);
      if (_disposed || !_foreground) return;
      if (conferenceInt(state['status']) >= 2) {
        await _ended();
        return;
      }
      final credentials = await api.livekit(id!);
      if (_disposed || !_foreground || phase != ConferencePhase.meeting) return;
      await media.connect(credentials);
      if (_disposed || !_foreground || phase != ConferencePhase.meeting) {
        await media.release();
        return;
      }
      if (!media.connected) throw StateError('Disconnected');
      await api.media(
        id!,
        camera: media.cameraOn,
        microphone: media.microphoneOn,
      );
      notice = null;
      await _syncAsr();
    } catch (exception) {
      notice =
          media.error ??
          (exception is ApiException && exception.code == 401
              ? '登录已失效，请重新登录后进入面试'
              : '音视频连接未成功，请检查网络、设备权限后重新连接');
    } finally {
      connecting = false;
      changed();
    }
  }

  Future<void> _syncAsr() async {
    if (mode == 4 ||
        id == null ||
        !media.microphoneOn ||
        media.microphone == null) {
      await asr.stop();
      return;
    }
    await asr.start(api, id!, media.microphone!, changed);
  }

  Future<void> toggleMedia({required bool camera}) async {
    if (busy || !media.connected || id == null) return;
    busy = true;
    changed();
    try {
      if (camera) {
        await media.toggleCamera();
      } else {
        await asr.stop();
        await media.toggleMicrophone();
        await _syncAsr();
      }
      await api.media(
        id!,
        camera: media.cameraOn,
        microphone: media.microphoneOn,
      );
    } catch (_) {
      notice = '设备状态更新失败，请检查权限后重试';
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> flipCamera() async {
    if (busy ||
        !media.connected ||
        !media.cameraOn ||
        phase != ConferencePhase.meeting) {
      return;
    }
    busy = true;
    changed();
    try {
      await media.flipCamera();
    } catch (_) {
      notice = '摄像头切换失败，请检查设备后重试';
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> poll() async {
    if (_polling || _disposed || !_foreground || id == null) return;
    _polling = true;
    try {
      if (phase == ConferencePhase.waiting) {
        waiting = await api.waiting(id!);
        if (_disposed || !_foreground) return;
        waitingUpdatedAt = DateTime.now();
        final status = conferenceInt(waiting['sessionStatus'], -1);
        if (status >= 2) {
          await _ended();
        } else if (status == 1) {
          await _meeting();
        }
      } else if (phase == ConferencePhase.meeting) {
        final next = await api.progress(id!);
        if (_disposed || !_foreground) return;
        progress = next;
        if (conferenceInt(next['sessionStatus']) >= 2) {
          await _ended();
          return;
        }
        if (mode != 4) {
          try {
            final items = await api.captions(id!, _captionSequence);
            if (_disposed) return;
            for (final item in items) {
              final seq = conferenceInt(item['sequence']);
              if (seq <= _captionSequence) continue;
              captions.add(item);
              _captionSequence = seq;
            }
            if (captions.length > 60) {
              captions.removeRange(0, captions.length - 60);
            }
          } catch (_) {
            /* Retain existing captions during a transient failure. */
          }
        }
        if (_ticks++ % 4 == 0) await api.heartbeat(id!);
      }
      error = null;
    } catch (_) {
      error = '面试状态更新失败，请检查网络并刷新';
    } finally {
      _polling = false;
      changed();
    }
  }

  Future<bool> answer(String content) async {
    if (busy ||
        answerUncertain ||
        id == null ||
        phase != ConferencePhase.meeting ||
        mode == 4 ||
        conferenceInt(progress['takeover']) == 1 ||
        content.trim().isEmpty) {
      return false;
    }
    busy = true;
    _answerCountBeforeSubmit = conferenceInt(progress['answeredCount']);
    error = null;
    changed();
    try {
      progress = await api.answer(id!, content.trim());
      return true;
    } catch (_) {
      // This backend has no idempotency key. An ambiguous response must never
      // automatically submit the same answer again and increment twice.
      answerUncertain = true;
      error = '作答提交结果待确认，请刷新进度并核对后再继续';
      return false;
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> confirmAnswerState() async {
    if (id == null || busy) return;
    busy = true;
    changed();
    try {
      progress = await api.progress(id!);
      answerUncertain =
          conferenceInt(progress['answeredCount']) <= _answerCountBeforeSubmit;
      error = answerUncertain ? '作答进度尚未变化，请稍后刷新或联系面试官确认，避免重复提交' : null;
    } catch (_) {
      error = '进度暂时无法确认，请稍后重试';
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> finish() async {
    if (busy || id == null) return;
    busy = true;
    error = null;
    changed();
    try {
      result = await api.finish(id!);
      await _ended();
    } catch (_) {
      error = '结束结果待确认，请刷新面试状态后重试';
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> _ended() async {
    _timer?.cancel();
    phase = ConferencePhase.ended;
    await asr.stop();
    await media.release();
    try {
      result = await api.result(id!);
    } catch (_) {
      notice = '面试已结束，结果暂未加载，请刷新';
    }
    changed();
  }

  Future<void> refreshResult() async {
    if (id == null || busy) return;
    busy = true;
    changed();
    try {
      result = await api.result(id!);
      notice = null;
    } catch (_) {
      notice = '结果暂未加载，请稍后重试';
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> foreground(bool value) async {
    _foreground = value;
    if (!value) {
      _timer?.cancel();
      await asr.stop();
      await media.release();
      networkOk = false;
      if (phase == ConferencePhase.meeting) notice = '音视频已暂停，请点击重新连接';
    } else if ([
      ConferencePhase.waiting,
      ConferencePhase.meeting,
    ].contains(phase)) {
      _startPolling();
      await poll();
    }
    changed();
  }

  Future<void> leaveWaiting() async {
    if (id != null && phase == ConferencePhase.waiting) {
      try {
        await api.participant(id!, _environment(0));
      } catch (_) {
        /* no destructive operation */
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(asr.stop());
    media.removeListener(changed);
    media.dispose();
    super.dispose();
  }
}
