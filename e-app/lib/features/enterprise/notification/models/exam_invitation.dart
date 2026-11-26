/// 企业端会话中的笔试邀请卡片。
///
/// 后端以 type=5 文本写入 IM 会话，正文形如：
/// `【笔试邀请·Java笔试试卷】Java工程师，作答时间 ...，请点击链接进入：https://.../user/exam?scheduleId=12`
/// 只解析求职者端 `/exam` 的 scheduleId，不把消息中的任意 URL 当作可执行入口。
class ExamInvitation {
  const ExamInvitation({
    required this.scheduleId,
    required this.paperName,
    required this.detail,
    required this.url,
  });

  final int scheduleId;
  final String paperName;
  final String detail;
  final String url;

  static ExamInvitation? parse(String content) {
    final text = content.trim();
    final tag = RegExp(r'^【笔试邀请(?:·([^】]*))?】').firstMatch(text);
    if (tag == null) {
      return null;
    }
    final urlMatch = RegExp(r'https?://[^\s<>"】]+|/exam\?[^\s<>"】]+')
        .firstMatch(text);
    if (urlMatch == null) {
      return null;
    }
    final uri = Uri.tryParse(urlMatch.group(0)!);
    if (uri == null) {
      return null;
    }
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (!path.endsWith('/exam')) {
      return null;
    }
    final scheduleId = int.tryParse(uri.queryParameters['scheduleId'] ?? '');
    if (scheduleId == null || scheduleId <= 0) {
      return null;
    }
    final paperName = (tag.group(1) ?? '').trim();
    final detail = text
        .substring(tag.end, urlMatch.start)
        .trim()
        .replaceFirst(RegExp(r'[：:\s]*请点击链接进入[：:]?\s*$'), '')
        .replaceFirst(RegExp(r'[，,。；;\s：:]+$'), '')
        .trim();
    return ExamInvitation(
      scheduleId: scheduleId,
      paperName: paperName.isEmpty ? '在线笔试' : paperName,
      detail: detail.isEmpty ? '请查看笔试安排并进入考试' : detail,
      url: urlMatch.group(0)!,
    );
  }
}
