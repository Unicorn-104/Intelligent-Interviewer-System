/// 模块一：岗位管理 - 本地模拟数据（Mock Data）。
///
/// 依据《业务功能分析》UC-01（发布岗位并生成 JD 画像）：
/// 岗位画像包含学历、年限、技能标签等硬性指标与软性要求。
///
/// TODO: P7阶段替换为真实接口（lib/api/jobs_api.dart 的 listJobs / getJdProfile）。
library;

/// 岗位列表模拟数据。字段与岗位画像（JD Profile）结构对应：
/// - title/dept/location：岗位基本信息
/// - active：招聘状态（true 招聘中 / false 已下线）
/// - education/years：硬性指标（学历/年限）
/// - skills：技能标签（硬性指标）
/// - softSkills：软性要求
/// - salary/applicants：展示辅助信息
const List<Map<String, dynamic>> mockJobs = [
  {
    'posId': 101,
    'title': '高级 Flutter 开发工程师',
    'dept': '技术中心',
    'location': '上海',
    'active': true,
    'education': '本科',
    'years': '5年以上',
    'skills': ['Flutter', 'Dart', '跨端架构'],
    'softSkills': ['沟通协作', '技术分享'],
    'salary': '30-50K·14薪',
    'applicants': 46,
  },
  {
    'posId': 102,
    'title': 'Java 后端开发工程师',
    'dept': '技术中心',
    'location': '杭州',
    'active': true,
    'education': '本科',
    'years': '3年以上',
    'skills': ['Spring Boot', 'MySQL', 'Redis'],
    'softSkills': ['责任心', '文档习惯'],
    'salary': '25-40K·14薪',
    'applicants': 82,
  },
  {
    'posId': 103,
    'title': 'AI 产品经理',
    'dept': '产品部',
    'location': '上海',
    'active': true,
    'education': '硕士',
    'years': '3年以上',
    'skills': ['LLM 应用', 'B端产品'],
    'softSkills': ['用户洞察', '跨团队推动'],
    'salary': '28-45K·13薪',
    'applicants': 31,
  },
  {
    'posId': 104,
    'title': '算法工程师（NLP）',
    'dept': 'AI 实验室',
    'location': '北京',
    'active': true,
    'education': '硕士',
    'years': '3年以上',
    'skills': ['NLP', 'PyTorch', 'RAG'],
    'softSkills': ['论文复现', '工程落地'],
    'salary': '35-60K·14薪',
    'applicants': 19,
  },
  {
    'posId': 105,
    'title': 'UI 设计师',
    'dept': '设计部',
    'location': '上海',
    'active': false,
    'education': '大专',
    'years': '2年以上',
    'skills': ['Figma', '设计系统'],
    'softSkills': ['审美能力'],
    'salary': '15-25K·13薪',
    'applicants': 57,
  },
];

/// 岗位详情模拟数据（含 JD 画像解析结果）。
/// TODO: P7阶段替换为真实接口（getJobDetail / getJdProfile）。
const Map<String, dynamic> mockJdProfile = {
  'jdSummary':
      '负责企业招聘产品移动端（Flutter）核心模块研发，参与跨端架构设计，'
      '与后端、AI 团队协作落地 AI 面试相关能力。',
  'hardRequirements': [
    {'field': '学历', 'value': '本科及以上'},
    {'field': '工作年限', 'value': '5 年以上'},
    {'field': '必备技能', 'value': 'Flutter / Dart / 跨端架构'},
  ],
  'softRequirements': [
    {'field': '软性要求', 'value': '良好的沟通协作能力，有技术分享习惯'},
  ],
  'skills': ['Flutter', 'Dart', '跨端架构', '性能优化'],
  'parsedAt': '2026-10-08 14:30',
};
