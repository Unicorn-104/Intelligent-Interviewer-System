/// 模块四：面试入口与准备 - 本地模拟数据（Mock Data）。
///
/// 依据《业务功能分析》UC-10（面试入场鉴权与设备检测）、
/// UC-11（在线实操环境预加载）：
/// - 面试会话元数据：岗位名称、面试官、时长、面试模式
/// - 设备检测：摄像头/麦克风/网络（绿/黄/红状态灯）
/// - 实操环境：技术类岗位面试前异步预加载代码沙箱/云端 IDE
///
/// TODO: P7阶段替换为真实接口（lib/api/interview_room_api.dart 与
/// lib/api/practice_api.dart 的全部函数）。
library;

/// 面试场次上下文（UC-10 步骤3：鉴权通过后加载面试元数据）。
const Map<String, dynamic> mockSessionContext = {
  'sessionId': 8801,
  'positionName': '高级 Flutter 开发工程师',
  'candidateName': '陈思远',
  'interviewerName': '李娜',
  'duration': 45,
  'mode': 'AI+HR 协同面试',
  'startTime': '2026-10-09 16:30',
  'meetingLink': 'https://meeting.example.com/982445',
  // 技术类岗位且面试模式包含实操环节（UC-11 触发条件）
  'hasPractice': true,
};

/// 面试须知（UC-10 步骤8：候选人阅读并确认）。
const List<String> mockInterviewNotices = [
  '面试全程禁止录屏、录音及他人协助',
  '请确保处于安静、光线充足的环境',
  '面试过程将进行音视频录制与合规存档',
  'AI 生成的提问与评分仅供参考，最终结果以 HR 终审为准',
];

/// 设备检测结果模拟配置（UC-10 步骤5-6）。
/// result: pass=绿灯 / warn=黄灯 / fail=红灯
const Map<String, Map<String, dynamic>> mockDeviceCheckResult = {
  'camera': {
    'label': '摄像头',
    'result': 'pass',
    'message': '已捕获视频流，画面正常',
  },
  'mic': {
    'label': '麦克风',
    'result': 'pass',
    'message': '实时音量波形正常',
  },
  'network': {
    'label': '网络',
    'result': 'warn',
    'message': 'RTT 约 420ms，带宽低于 1Mbps，网络状态不佳',
    'suggestion': '建议切换至 Wi-Fi 或使用手机热点；如持续不佳，可"忽略风险，继续进入"（将记录风险标记，供面试参考）',
  },
};

/// 实操环境预加载步骤（UC-11：异步预加载，进入面试时无需等待初始化）。
const List<Map<String, dynamic>> mockPracticeSteps = [
  {'name': '分配代码沙箱资源', 'desc': '申请云端容器实例'},
  {'name': '拉取运行环境镜像', 'desc': 'Flutter 3.x + Dart SDK 镜像'},
  {'name': '初始化云端 IDE', 'desc': '挂载考题工程与测试用例'},
  {'name': '环境健康检查', 'desc': '编译链路与依赖预下载'},
];
