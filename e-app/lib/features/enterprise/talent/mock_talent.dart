/// 模块一：人才库 - 本地模拟数据（Mock Data）。
///
/// 依据《业务功能分析》UC-02（简历投递与智能解析）、UC-03（人才库简历检索与管理）：
/// 简历完成度检查（标记缺失字段）、智能去重后形成结构化人才数据。
///
/// TODO: P7阶段替换为真实接口（lib/api/talent_api.dart 的 searchTalentPool 等）。
library;

/// 人才库列表模拟数据。字段对应结构化人才数据：
/// - integrity：简历完整度百分比（UC-02 步骤5 完整度检查）
/// - missingFields：缺失的关键字段（完整度检查标记）
/// - skills：技能标签
/// - tags：人才标签（检索/收藏用）
/// - stage：当前流程状态
const List<Map<String, dynamic>> mockTalents = [
  {
    'talId': 201,
    'name': '陈思远',
    'phone': '138****2201',
    'email': 'siyuan.chen@example.com',
    'education': '硕士·浙江大学',
    'years': '6年经验',
    'skills': ['Flutter', 'Dart', '性能优化'],
    'tags': ['高潜', '技术栈匹配'],
    'integrity': 96,
    'missingFields': <String>[],
    'stage': 'AI 初筛通过',
    'appliedJob': '高级 Flutter 开发工程师',
  },
  {
    'talId': 202,
    'name': '林晓雨',
    'phone': '139****3348',
    'email': 'xiaoyu.lin@example.com',
    'education': '本科·南京大学',
    'years': '4年经验',
    'skills': ['Spring Boot', 'MySQL', 'K8s'],
    'tags': ['高潜'],
    'integrity': 88,
    'missingFields': ['项目经验 1 条待补充'],
    'stage': '待初筛',
    'appliedJob': 'Java 后端开发工程师',
  },
  {
    'talId': 203,
    'name': '王浩然',
    'phone': '135****7712',
    'email': 'haoran.wang@example.com',
    'education': '硕士·复旦大学',
    'years': '5年经验',
    'skills': ['NLP', 'RAG', 'LLM 应用'],
    'tags': ['技术栈匹配'],
    'integrity': 92,
    'missingFields': <String>[],
    'stage': '面试已预约',
    'appliedJob': '算法工程师（NLP）',
  },
  {
    'talId': 204,
    'name': '赵一诺',
    'phone': '137****9023',
    'email': 'yinuo.zhao@example.com',
    'education': '本科·上海交通大学',
    'years': '3年经验',
    'skills': ['Figma', '设计系统', 'C端交互'],
    'tags': <String>[],
    'integrity': 71,
    'missingFields': ['工作经历 1 条待补充', '期望薪资未填写'],
    'stage': '待初筛',
    'appliedJob': 'UI 设计师',
  },
  {
    'talId': 205,
    'name': '孙铭泽',
    'phone': '136****4410',
    'email': 'mingze.sun@example.com',
    'education': '本科·华中科技大学',
    'years': '7年经验',
    'skills': ['Spring Cloud', 'Redis', '消息队列'],
    'tags': ['高潜', '技术栈匹配'],
    'integrity': 98,
    'missingFields': <String>[],
    'stage': 'AI 初筛通过',
    'appliedJob': 'Java 后端开发工程师',
  },
];

/// 候选人详情模拟数据（简历解析结果视图，UC-02 步骤4 标准化 JSON 结构）。
/// TODO: P7阶段替换为真实接口（getTalentDetail / getTalentParsedResume）。
const Map<String, dynamic> mockTalentResume = {
  'educationList': [
    {'school': '浙江大学', 'degree': '硕士', 'major': '计算机科学与技术', 'period': '2016-2019'},
    {'school': '杭州电子科技大学', 'degree': '本科', 'major': '软件工程', 'period': '2012-2016'},
  ],
  'workList': [
    {'company': '某头部电商平台', 'title': '高级客户端工程师', 'period': '2021-至今',
     'summary': '负责 App 核心交易链路 Flutter 化改造，页面渲染性能提升 40%。'},
    {'company': '某互联网公司', 'title': 'Android 工程师', 'period': '2019-2021',
     'summary': '参与短视频 App 播放器模块开发，负责播放内核封装与内存治理。'},
  ],
  'projectList': [
    {'name': '跨端组件库建设', 'role': '负责人', 'summary': '沉淀 30+ 业务组件，双端复用率 85%。'},
  ],
  'skills': ['Flutter', 'Dart', '性能优化', '跨端架构'],
  'expectSalary': '35-45K',
};
