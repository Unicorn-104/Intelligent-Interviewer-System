import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// 视频会议室连接阶段。
enum ConferenceRoomStage { connecting, connected, reconnecting, failed, closed }

/// 远端参会者的媒体视图（实时由 LiveKit 轨道事件刷新）。
@immutable
class ConferenceRemoteParticipant {
  const ConferenceRemoteParticipant({
    required this.identity,
    this.videoTrack,
    this.micEnabled = true,
    this.speaking = false,
  });

  /// LiveKit identity，形如 `u{userId}`，用于映射回业务用户。
  final String identity;
  final lk.VideoTrack? videoTrack;
  final bool micEnabled;
  final bool speaking;
}

/// 会议室的不可变状态快照，页面通过 [ConferenceRoomEngine] 监听其变化。
@immutable
class ConferenceRoomState {
  const ConferenceRoomState({
    required this.stage,
    this.error,
    this.localIdentity,
    this.localVideoTrack,
    this.remotes = const <ConferenceRemoteParticipant>[],
    this.micEnabled = false,
    this.cameraEnabled = false,
    this.canPublish = true,
    this.mediaNotice,
  });

  final ConferenceRoomStage stage;

  /// 连接失败/断开原因（stage 为 failed 时展示）。
  final String? error;

  /// 本人 identity（`u{userId}`）。
  final String? localIdentity;
  final lk.VideoTrack? localVideoTrack;
  final List<ConferenceRemoteParticipant> remotes;
  final bool micEnabled;
  final bool cameraEnabled;

  /// 观察者无发布权限时置 false，界面隐藏音视频开关。
  final bool canPublish;

  /// 摄像头/麦克风采集失败的一次性提示（已连接但设备不可用时非空）。
  final String? mediaNotice;
}

/// 把 LiveKit 的本地/远端轨道安全转为可渲染的视频轨（音频、屏幕共享轨为 null）。
lk.VideoTrack? _asVideoTrack(Object? track) =>
    track is lk.VideoTrack ? track : null;

/// 视频会议室媒体引擎抽象：页面只依赖这层接口，测试可注入假实现。
abstract class ConferenceRoomEngine extends ChangeNotifier {
  ConferenceRoomState get state;

  /// 连接 LiveKit 房间；[canPublish] 为 false 时只订阅不发布（观察者）。
  Future<void> connect({
    required String url,
    required String token,
    required bool canPublish,
  });

  Future<void> setMicrophoneEnabled(bool enabled);
  Future<void> setCameraEnabled(bool enabled);

  /// 前后摄像头切换（无摄像头轨时尝试重新开启）。
  Future<void> flipCamera();

  Future<void> disconnect();
}

/// 基于 livekit_client 的真实会议室实现，与 enterprise_pc 的 LiveKit 接入一致。
class LiveKitConferenceEngine extends ConferenceRoomEngine {
  LiveKitConferenceEngine() : _room = lk.Room();

  final lk.Room _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  final Set<String> _speaking = <String>{};
  ConferenceRoomStage _stage = ConferenceRoomStage.connecting;
  String? _error;
  String? _mediaNotice;
  bool _canPublish = true;
  bool _disposed = false;
  ConferenceRoomState _state = const ConferenceRoomState(
    stage: ConferenceRoomStage.connecting,
  );

  @override
  ConferenceRoomState get state => _state;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required bool canPublish,
  }) async {
    _canPublish = canPublish;
    _stage = ConferenceRoomStage.connecting;
    _error = null;
    _mediaNotice = null;
    _rebuild();

    _listener = _room.createListener()
      ..on<lk.RoomConnectedEvent>((_) {
        _stage = ConferenceRoomStage.connected;
        _rebuild();
      })
      ..on<lk.RoomReconnectingEvent>((_) {
        _stage = ConferenceRoomStage.reconnecting;
        _rebuild();
      })
      ..on<lk.RoomReconnectedEvent>((_) {
        _stage = ConferenceRoomStage.connected;
        _rebuild();
      })
      ..on<lk.RoomDisconnectedEvent>((event) {
        if (_disposed) return;
        _stage = ConferenceRoomStage.failed;
        _error = event.reason == null ? '会议连接已断开' : '会议连接已断开（${event.reason}）';
        _rebuild();
      })
      ..on<lk.ParticipantConnectedEvent>((_) => _rebuild())
      ..on<lk.ParticipantDisconnectedEvent>((_) => _rebuild())
      ..on<lk.TrackSubscribedEvent>((_) => _rebuild())
      ..on<lk.TrackUnsubscribedEvent>((_) => _rebuild())
      ..on<lk.TrackMutedEvent>((_) => _rebuild())
      ..on<lk.TrackUnmutedEvent>((_) => _rebuild())
      ..on<lk.LocalTrackPublishedEvent>((_) => _rebuild())
      ..on<lk.LocalTrackUnpublishedEvent>((_) => _rebuild())
      ..on<lk.ActiveSpeakersChangedEvent>((event) {
        _speaking
          ..clear()
          ..addAll(event.speakers.map((participant) => participant.identity));
        _rebuild();
      });

    await _room.connect(url, token);
    _stage = ConferenceRoomStage.connected;
    _rebuild();

    if (canPublish) {
      await _openMedia();
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // 面试场景默认扬声器外放；失败不影响会议本身。
      try {
        await lk.AudioManager.instance.setSpeakerOutputPreferred(true);
      } catch (_) {
        // 部分设备不支持该能力，忽略即可。
      }
    }
  }

  /// 分别开启麦克风与摄像头：任一失败不影响另一项，原因汇总后提示。
  Future<void> _openMedia() async {
    final notices = <String>[];
    try {
      await _room.localParticipant?.setMicrophoneEnabled(true);
    } catch (error) {
      notices.add('麦克风不可用：$error');
    }
    try {
      await _room.localParticipant?.setCameraEnabled(true);
    } catch (error) {
      notices.add('摄像头不可用：$error');
    }
    _mediaNotice = notices.isEmpty ? null : notices.join('；');
    _rebuild();
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _room.localParticipant?.setMicrophoneEnabled(enabled);
    _rebuild();
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    await _room.localParticipant?.setCameraEnabled(enabled);
    _rebuild();
  }

  @override
  Future<void> flipCamera() async {
    final publication = _room.localParticipant?.getTrackPublicationBySource(
      lk.TrackSource.camera,
    );
    final track = publication?.track;
    if (track is! lk.LocalVideoTrack) {
      await setCameraEnabled(true);
      return;
    }
    final options = track.currentOptions;
    final current = options is lk.CameraCaptureOptions
        ? options.cameraPosition
        : lk.CameraPosition.front;
    await track.setCameraPosition(
      current == lk.CameraPosition.front
          ? lk.CameraPosition.back
          : lk.CameraPosition.front,
    );
    _rebuild();
  }

  @override
  Future<void> disconnect() async {
    if (_stage == ConferenceRoomStage.closed) return;
    _stage = ConferenceRoomStage.closed;
    _error = null;
    _rebuild();
    final listener = _listener;
    _listener = null;
    try {
      await listener?.dispose();
    } catch (_) {
      // 已释放时忽略。
    }
    try {
      await _room.disconnect();
    } catch (_) {
      // 断网等异常场景下仍继续释放本地资源。
    }
    try {
      await _room.dispose();
    } catch (_) {
      // 重复释放忽略。
    }
  }

  /// 从 LiveKit 房间快照重建不可变状态，供页面渲染。
  void _rebuild() {
    if (_disposed) return;
    final local = _room.localParticipant;
    final localVideoPublication = local?.getTrackPublicationBySource(
      lk.TrackSource.camera,
    );
    final localVideo = localVideoPublication?.track;
    final remotes = <ConferenceRemoteParticipant>[];
    for (final participant in _room.remoteParticipants.values) {
      final publication = participant.getTrackPublicationBySource(
        lk.TrackSource.camera,
      );
      final track = publication?.track;
      remotes.add(
        ConferenceRemoteParticipant(
          identity: participant.identity,
          videoTrack: _asVideoTrack(track),
          micEnabled: participant.isMicrophoneEnabled(),
          speaking: _speaking.contains(participant.identity),
        ),
      );
    }
    _state = ConferenceRoomState(
      stage: _stage,
      error: _error,
      localIdentity: local?.identity,
      localVideoTrack: _asVideoTrack(localVideo),
      remotes: List<ConferenceRemoteParticipant>.unmodifiable(remotes),
      micEnabled: local?.isMicrophoneEnabled() ?? false,
      cameraEnabled: local?.isCameraEnabled() ?? false,
      canPublish: _canPublish,
      mediaNotice: _mediaNotice,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) {
      super.dispose();
      return;
    }
    _disposed = true;
    final listener = _listener;
    _listener = null;
    unawaited(_disposeQuietly(listener));
    super.dispose();
  }

  Future<void> _disposeQuietly(
    lk.EventsListener<lk.RoomEvent>? listener,
  ) async {
    try {
      await listener?.dispose();
    } catch (_) {
      // 忽略重复释放。
    }
    try {
      await _room.dispose();
    } catch (_) {
      // 忽略重复释放。
    }
  }
}
