import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// 只高亮通知中明确标注的字段、时间和状态，不改写通知原文。
List<InlineSpan> systemNoticeSpans(String content) {
  const keyStyle = TextStyle(
    color: AppColors.interactive,
    fontWeight: FontWeight.w600,
  );
  final pattern = RegExp(
    r'((?:候选人|申请人|岗位|职位)[：:][ \t]*)([^\n]+)|(?:\d{4}-\d{2}-\d{2}[ \t]+)?\d{1,2}:\d{2}(?::\d{2})?|已确认|已取消|即将开始|已生成|已投递|已同意|已拒绝',
  );
  final spans = <InlineSpan>[];
  var offset = 0;
  for (final match in pattern.allMatches(content)) {
    if (match.start > offset) {
      spans.add(TextSpan(text: content.substring(offset, match.start)));
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(text: match.group(1)));
      spans.add(TextSpan(text: match.group(2), style: keyStyle));
    } else {
      spans.add(TextSpan(text: match.group(0), style: keyStyle));
    }
    offset = match.end;
  }
  if (offset < content.length) {
    spans.add(TextSpan(text: content.substring(offset)));
  }
  return spans;
}
