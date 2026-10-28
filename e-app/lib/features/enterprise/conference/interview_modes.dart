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

/// 兼容后端返回的数字或字符串模式值。
String interviewModeLabel(Object? value, [String fallback = '视频面试']) {
  final mode = value is int ? value : int.tryParse('${value ?? ''}');
  return interviewModeLabels[mode] ?? fallback;
}
