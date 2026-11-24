import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';
import '../../../config/app_config.dart';
import 'conference_connection.dart';

class ConferenceMedia extends ChangeNotifier {
  lk.LocalVideoTrack? camera;
  lk.LocalAudioTrack? microphone;
  lk.Room? room;
  bool blocked = false;
  bool get connected => room?.connectionState == lk.ConnectionState.connected;
  bool get cameraOn => camera != null && !camera!.muted;
  bool get microphoneOn => microphone != null && !microphone!.muted;
  String? error;
  bool _closed = false;
  int _generation = 0;
  void changed() {
    if (!_closed) notifyListeners();
  }

  Future<void> checkDevices() async {
    final generation = ++_generation;
    error = null;
    final permissions = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    if (_closed || generation != _generation) return;
    blocked = permissions.values.any(
      (p) => p.isPermanentlyDenied || p.isRestricted,
    );
    if (permissions[Permission.camera]?.isGranted == true && camera == null) {
      try {
        final track = await lk.LocalVideoTrack.createCameraTrack();
        if (_closed || generation != _generation) {
          await track.dispose();
          return;
        }
        camera = track;
      } catch (_) {
        error = '摄像头无法开启，请检查权限或设备占用';
      }
    }
    if (permissions[Permission.microphone]?.isGranted == true &&
        microphone == null) {
      try {
        final track = await lk.LocalAudioTrack.create();
        if (_closed || generation != _generation) {
          await track.dispose();
          return;
        }
        microphone = track;
      } catch (_) {
        error = '麦克风无法开启，请检查权限或设备占用';
      }
    }
    if (!cameraOn || !microphoneOn) {
      error ??= blocked ? '请在系统设置中允许摄像头和麦克风，然后重新检测' : '请允许摄像头和麦克风权限，然后重新检测';
    }
    changed();
  }

  Future<void> connect(Map<String, dynamic> credentials) async {
    error = null;
    // Release the preparation preview as well as a previous room. Preparation
    // tracks exist even when room is null; PC starts fresh capture after join.
    await release();
    final parsedUrl = Uri.tryParse('${credentials['url']}');
    if (parsedUrl == null ||
        parsedUrl.scheme != 'wss' ||
        parsedUrl.host.isEmpty ||
        credentials['token'] is! String) {
      error = '会议服务地址配置无效，请联系 HR 确认会议入口';
      throw StateError('Secure video connection unavailable');
    }
    final url = conferenceSignalingUri(parsedUrl);
    if (_closed) return;
    final connectGeneration = _generation;
    lk.NetworkOptions network = const lk.NetworkOptions();
    final backend = Uri.parse(AppConfig.apiBaseUrl);
    if (usesConferencePrivateCa(
      enabled: AppConfig.trustBaotaCertificate,
      backend: backend,
      signaling: url,
    )) {
      network = lk.NetworkOptions(
        certificatePinning: lk.CertificatePinningOptions(
          rules: [
            lk.CertificatePinningRule(
              hosts: [backend.host],
              trustedCertificates: [
                await lk.CertificateBytes.fromAsset(
                  AppConfig.privateCertificateAsset,
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (_closed || connectGeneration != _generation) return;
    final next = lk.Room(
      roomOptions: lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        networkOptions: network,
      ),
    );
    room = next;
    next.addListener(changed);
    try {
      await next.connect(
        url.toString(),
        credentials['token'] as String,
        connectOptions: conferenceConnectOptions,
      );
      if (_closed || connectGeneration != _generation || room != next) {
        await next.dispose();
        return;
      }
      // Match the working PC client: join the room first, then open and publish
      // local devices. This avoids making ICE/DTLS negotiation depend on a
      // pre-created camera track on mobile.
      if (!cameraOn || !microphoneOn) await checkDevices();
      if (_closed || !cameraOn || !microphoneOn || room != next) {
        error ??= '请允许摄像头和麦克风权限，然后重新检测';
        throw StateError('Media unavailable');
      }
      await next.localParticipant!.publishVideoTrack(camera!);
      await next.localParticipant!.publishAudioTrack(microphone!);
      error = null;
      changed();
    } catch (exception) {
      if (kDebugMode) {
        // 仅记录异常类型，不记录可能携带入场凭证的异常原文。
        debugPrint(
          'Conference media connection failed: ${exception.runtimeType}',
        );
      }
      error ??= conferenceConnectionMessage(exception);
      if (room == next) {
        try {
          await disconnectRoom();
        } catch (_) {
          // Cleanup failure must not hide the actual connection failure.
        }
      }
      rethrow;
    }
  }

  Future<void> toggleCamera() async {
    if (room == null) return;
    await room!.localParticipant!.setCameraEnabled(!cameraOn);
    camera =
        room!.localParticipant!
                .getTrackPublicationBySource(lk.TrackSource.camera)
                ?.track
            as lk.LocalVideoTrack?;
    changed();
  }

  Future<void> toggleMicrophone() async {
    if (room == null) return;
    await room!.localParticipant!.setMicrophoneEnabled(!microphoneOn);
    microphone =
        room!.localParticipant!
                .getTrackPublicationBySource(lk.TrackSource.microphone)
                ?.track
            as lk.LocalAudioTrack?;
    changed();
  }

  Future<void> flipCamera() async {
    final track = camera;
    if (track == null || !cameraOn || !connected) return;
    final options = track.currentOptions;
    final current = options is lk.CameraCaptureOptions
        ? options.cameraPosition
        : lk.CameraPosition.front;
    await track.setCameraPosition(
      current == lk.CameraPosition.front
          ? lk.CameraPosition.back
          : lk.CameraPosition.front,
    );
    changed();
  }

  Future<void> disconnectRoom() async {
    final previous = room;
    room = null;
    if (previous != null) {
      final video = camera, audio = microphone;
      camera = null;
      microphone = null;
      previous.removeListener(changed);
      try {
        // Room.dispose also disconnects. Calling both can delay retrying a
        // failed peer connection.
        await previous.dispose();
      } finally {
        // Tracks may not have been published if permission/publishing failed.
        await video?.dispose();
        await audio?.dispose();
      }
    }
    changed();
  }

  Future<void> release() async {
    _generation++;
    await disconnectRoom();
    final video = camera, audio = microphone;
    camera = null;
    microphone = null;
    await video?.dispose();
    await audio?.dispose();
    changed();
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(release());
    super.dispose();
  }
}
