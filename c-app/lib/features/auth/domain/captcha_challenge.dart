import 'dart:convert';
import 'dart:typed_data';

class CaptchaChallenge {
  const CaptchaChallenge({
    required this.enabled,
    this.uuid,
    this.imageBytes,
  });

  final bool enabled;
  final String? uuid;
  final Uint8List? imageBytes;

  factory CaptchaChallenge.fromJson(Map<String, dynamic> json) {
    final enabled = json['captchaEnabled'] == true;
    final rawImage = json['img']?.toString();
    return CaptchaChallenge(
      enabled: enabled,
      uuid: json['uuid']?.toString(),
      imageBytes: rawImage == null || rawImage.isEmpty
          ? null
          : base64Decode(rawImage.split(',').last),
    );
  }
}
