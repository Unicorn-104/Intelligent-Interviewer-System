import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:intelligent_interviewer/features/interviews/data/conference_connection.dart';

void main() {
  final backend = Uri.parse('https://backend.example/prod-api');
  bool trusts(String signaling, {bool enabled = true, Uri? origin}) =>
      usesConferencePrivateCa(
        enabled: enabled,
        backend: origin ?? backend,
        signaling: Uri.parse(signaling),
      );

  test(
    'private CA covers API origin and the authenticated same-host gateway',
    () {
      expect(trusts('wss://backend.example/livekit'), isTrue);
      expect(trusts('wss://backend.example:443/livekit'), isTrue);
      expect(trusts('wss://backend.example:8444/livekit'), isTrue);
      expect(trusts('wss://backend.example:8444/livekit/'), isTrue);
      expect(
        trusts(
          'wss://backend.example:8443/livekit',
          origin: Uri.parse('https://backend.example:8443/prod-api'),
        ),
        isTrue,
      );
    },
  );

  test(
    'private CA stays disabled for unrelated origins and unapproved ports',
    () {
      expect(
        trusts('wss://backend.example:8444/livekit', enabled: false),
        isFalse,
      );
      for (final url in [
        'ws://backend.example:8444/livekit',
        'wss://other.example:8444/livekit',
        'wss://backend.example.attacker.test:8444/livekit',
        'wss://backend.example@attacker.test:8444/livekit',
        'wss://user:pass@backend.example:8444/livekit',
        'wss://backend.example:8445/livekit',
        'wss://backend.example:8444/unrelated',
      ]) {
        expect(trusts(url), isFalse, reason: url);
      }
      expect(
        trusts(
          'wss://backend.example:8444/livekit',
          origin: Uri.parse('http://backend.example'),
        ),
        isFalse,
      );
    },
  );

  test(
    'connection errors identify certificate, admission and media failures without exposing tokens',
    () {
      const privateText =
          'wss://backend.example/livekit?access_token=synthetic-secret';
      expect(
        conferenceConnectionMessage(const HandshakeException(privateText)),
        contains('证书校验失败'),
      );
      expect(
        conferenceConnectionMessage(
          lk.ConnectException(
            privateText,
            reason: lk.ConnectionErrorReason.NotAllowed,
            statusCode: 403,
          ),
        ),
        contains('凭证'),
      );
      expect(
        conferenceConnectionMessage(
          lk.ConnectException(
            privateText,
            reason: lk.ConnectionErrorReason.Timeout,
          ),
        ),
        contains('超时'),
      );
      expect(
        conferenceConnectionMessage(lk.MediaConnectException(privateText)),
        contains('媒体通道'),
      );
      expect(
        conferenceConnectionMessage(lk.TrackPublishException(privateText)),
        contains('发布失败'),
      );
      expect(
        conferenceConnectionMessage(StateError(privateText)),
        isNot(contains('synthetic-secret')),
      );
    },
  );
}
