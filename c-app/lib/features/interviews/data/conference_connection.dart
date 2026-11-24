import 'dart:async';
import 'dart:io';

import 'package:livekit_client/livekit_client.dart' as lk;

/// Allow ICE and DTLS to finish on mobile networks before disposing the room.
/// Keep SDK defaults for debounce and track subscription.
const conferenceConnectOptions = lk.ConnectOptions(
  timeouts: lk.Timeouts(
    connection: Duration(seconds: 30),
    debounce: Duration(milliseconds: 20),
    publish: Duration(seconds: 15),
    subscribe: Duration(seconds: 10),
    peerConnection: Duration(seconds: 30),
    iceRestart: Duration(seconds: 30),
  ),
);

/// dart:io converts WSS into HTTPS while preserving Uri.port. Dart Uri has
/// no default port for WSS, so make 443 explicit before handing it to the SDK.
Uri conferenceSignalingUri(Uri signaling) =>
    signaling.scheme == 'wss' && !signaling.hasPort
    ? signaling.replace(port: 443)
    : signaling;

/// Only this SDK connection gets the extra CA; API HTTP trust stays unchanged.
bool usesConferencePrivateCa({
  required bool enabled,
  required Uri backend,
  required Uri signaling,
}) =>
    enabled &&
    backend.scheme == 'https' &&
    signaling.scheme == 'wss' &&
    signaling.userInfo.isEmpty &&
    signaling.host == backend.host &&
    ((signaling.hasPort ? signaling.port : 443) == backend.port ||
        (signaling.port == 8444 &&
            (signaling.path == '/livekit' || signaling.path == '/livekit/')));

String conferenceConnectionMessage(Object exception) {
  // Inspect SDK-wrapped causes locally; never display exception text, which
  // can contain a signaling URL with the room token in its query string.
  final text = exception.toString().toLowerCase();
  if (exception is HandshakeException ||
      exception is lk.CertificatePinningException ||
      text.contains('certificate_verify_failed') ||
      text.contains('certificate verify failed')) {
    return '会议服务证书校验失败，请联系 HR 检查会议服务证书';
  }
  if (exception is TimeoutException ||
      exception is lk.TimeoutException ||
      (exception is lk.ConnectException &&
          exception.reason == lk.ConnectionErrorReason.Timeout)) {
    return '会议服务连接超时，请检查网络后重新连接';
  }
  if (exception is lk.ConnectException &&
      (exception.reason == lk.ConnectionErrorReason.NotAllowed ||
          exception.statusCode == 401 ||
          exception.statusCode == 403)) {
    return '会议入场凭证无效或已过期，请重新连接获取凭证';
  }
  if (exception is lk.MediaConnectException) {
    return '会议媒体通道未连通，请切换网络后重试或联系 HR';
  }
  if (exception is lk.TrackPublishException) {
    return '音视频发布失败，请重新连接或联系 HR 检查会议权限';
  }
  return '音视频连接未成功，请检查网络、设备权限后重新连接';
}
