/// 面试模式与阶段类型的展示文案（与 enterprise_pc 视频会议页保持一致）。
library;

/// 面试方式中文文案（与 PC 端 messages/index.vue 的 MODE_LABEL 一致）。
const Map<int, String> interviewModeLabels = {
  1: '纯AI面试',
  2: 'AI+单面试官',
  3: 'AI+多面试官',
  4: '无AI纯人工',
};

/// 阶段类型 → 默认面试方式（与 PC 端 STAGE_TYPE_MODE 一致）：
/// AI技术面试→AI+单面试官、HR综合面试→无AI纯人工、编程实操→纯AI。
const Map<int, int> stageTypeMode = {2: 2, 3: 4, 4: 1};

/// 去掉旧阶段名/旧卡片/会话预览里遗留的「无AI纯人工」文案。
/// 兼容 `HR 综合面试·无AI纯人工`、`HR 综合面试·无 AI · 纯人工` 等历史写法。
String cleanInterviewTitle(String value) {
  var text = value.trim().replaceAll(
    RegExp(r'\s*[·•]?\s*无\s*AI\s*(?:[·•]\s*)?纯人工', caseSensitive: false),
    '',
  );
  return text.replaceFirst(RegExp(r'[·•\s]+$'), '').trim();
}

/// 面试邀请标签：阶段名 + 面试方式。无AI纯人工已是当前默认面试环节，
/// 不再写入卡片标题；旧模式仍保留方式用于候选人端进入对应流程。
String interviewInviteTag(String stageName, Object? mode) {
  final stage = cleanInterviewTitle(stageName);
  final modeValue = mode is int ? mode : int.tryParse('${mode ?? ''}');
  if (modeValue == 4) {
    return '·${stage.isEmpty ? '面试' : stage}';
  }
  final modeLabel = interviewModeLabel(mode);
  return stage.isEmpty ? '·$modeLabel' : '·$stage·$modeLabel';
}

/// 兼容后端返回的数字或字符串模式值。
String interviewModeLabel(Object? value, [String fallback = '视频面试']) {
  final mode = value is int ? value : int.tryParse('${value ?? ''}');
  return interviewModeLabels[mode] ?? fallback;
}
