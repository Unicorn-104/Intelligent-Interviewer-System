/// Legacy invitations contain a PC link. Only extract its room token; never
/// navigate to that host or send the user's login token to a message URL.
class InterviewInvitation {
  const InterviewInvitation({
    required this.token,
    required this.title,
    required this.description,
  });
  final String token, title, description;

  static InterviewInvitation? parse(String content) {
    if (!content.startsWith('【面试邀请')) return null;
    final end = content.indexOf('】');
    if (end < 0) return null;
    for (final match in RegExp(r'https?://[^\s<>"】]+').allMatches(content)) {
      final uri = Uri.tryParse(match.group(0)!);
      if (uri == null ||
          uri.userInfo.isNotEmpty ||
          !['/conference-join', '/agent/conference-entry'].contains(uri.path)) {
        continue;
      }
      final tokens = uri.queryParametersAll['token'];
      if (tokens == null ||
          tokens.length != 1 ||
          !RegExp(r'^[a-zA-Z0-9_-]{16,256}$').hasMatch(tokens.single)) {
        continue;
      }
      final description = content
          .substring(end + 1, match.start)
          .replaceFirst(RegExp(r'视频面试[，,]?\s*请点击链接进入[：:]?\s*$'), '')
          .trim();
      return InterviewInvitation(
        token: tokens.single,
        title: content.substring(1, end).replaceFirst('面试邀请·', ''),
        description: description.isEmpty ? '请查看面试安排并完成设备检测' : description,
      );
    }
    return null;
  }
}
