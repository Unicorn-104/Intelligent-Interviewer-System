# 企业端阶段一验证记录

日期：2026-10-15。分支：`feature/eapp-core-services-zx`。

## 变更范围

四 Tab 外壳、首页骨架、三批功能入口、主题语义 Token、通用状态布局与相关测试。
API、screens、mock 数据和后端源码保持本次工作开始时的内容。
首页不请求业务数据，不展示伪造统计。

## 入口分批验证

| 批次 | 入口 | Widget 打开/返回检查 |
| --- | --- | --- |
| 一 | 招聘概览、人才库、面试日程、终审、Offer、通知、公告 | 通过 |
| 二 | 筛选任务、短名单、招呼语 | 通过，保留演示标识 |
| 三 | 工作台、设备检测、录播、预加载、改期审批、模板、调研、AI 助手 | 通过，全部显示演示标识 |

原有演示排期、面试入口保留在工作台“更多面试演示”菜单。

## 自动化检查

- `flutter test`：71 项通过（含设备测试依赖）。
- 首页覆盖 320×640、900×420、420×900 和模拟安全区。
- 导航覆盖各 Tab 独立栈、隐藏栈保留、系统返回和重复点击回根页。
- `flutter drive --driver=test_driver/stage_one_driver.dart --target=integration_test/stage_one_device_test.dart -d emulator-5554`：通过；55 页、110 张主题对照图，无渲染异常。
- 四个独立导航栈在 Pixel_10a 上通过详情返回、切换保留和重复点击回根页检查；此项使用合成导航页。
- 对照图中 35 页业务区域逐像素相同，18 页只有低幅度栅格差异。AI 助手占位页按钮高度、旧聊天页发送按钮点击区按主题规格变化，已检查无裁切与重叠。
- `flutter analyze --no-pub`：通过，No issues found。
- 最终 `flutter test`：71 项通过。
- `flutter build apk --debug`：通过，45.7 秒；正式入口 `lib/main.dart`。
- APK：`build/app/outputs/flutter-apk/app-debug.apk`，199,140,822 字节。
- APK SHA-256：`cac28a46cad995c18897c0864851fda121887950d2e9cb35d20dfe7dad80116f`。
- 三批 18 个入口在 Pixel_10a 分别通过打开、返回及演示标识验证。
- 窄屏物理分辨率 840×1680，四 Tab 均已检查。竖屏原始分辨率 1080×2424。
- 自动化横屏切换时模拟器意外退出。重启后以正式 APK 补验 2424×1080 横屏四 Tab，已通过；已恢复原始分辨率和竖屏。
- 正式 APK 真实登录态下，四 Tab 详情打开、原生返回、重复点击回首屏均通过。
- 正式 APK 冷启动恢复已有真实登录态、各 Tab 根页返回与重开、实际退出及退出后的冷启动保持均通过。
- 2026-10-15，用户使用测试账号在 Pixel_10a 登录页完成真实账号密码登录，成功进入首页，并确认四 Tab 切换及详情返回正常；本项由用户人工验收确认。

## 全页面清单

下列 55 个页面均已通过 420×900 的 Widget 渲染检查。
Widget 检查包含无会话时的错误状态，不替代设备截图和真实业务验收。
设备回归通过同一页面目录逐项打开，以重建的修改前按钮主题和修改后主题采集对照图。页面覆盖首次展示状态；无会话的真实接口页主要覆盖错误状态，不表示所有业务数据状态都已验收。
截图存放 `build/stage-one-device/screenshots/`，不纳入版本控制。

| 页面 | Widget 渲染 | Pixel_10a 主题对照 |
| --- | --- | --- |
| `LoginScreen` | 通过 | 已打开并对照，通过 |
| `OverviewPage` | 通过 | 已打开并对照，通过 |
| `EnterpriseModuleShell` | 通过 | 已打开并对照，通过 |
| `DeviceCheckPage` | 通过 | 已打开并对照，通过 |
| `InterviewEntrancePage` | 通过 | 已打开并对照，通过 |
| `InterviewPage` | 通过 | 已打开并对照，通过 |
| `InterviewWorkbenchPage` | 通过 | 已打开并对照，通过 |
| `PracticePreloadPage` | 通过 | 已打开并对照，通过 |
| `RecordingPage` | 通过 | 已打开并对照，通过 |
| `JobDetailPage` | 通过 | 已打开并对照，通过 |
| `JobPublishPage` | 通过 | 已打开并对照，通过 |
| `JobsPage` | 通过 | 已打开并对照，通过 |
| `LoginPage` | 通过 | 已打开并对照，通过 |
| `AssistantPlaceholderPage` | 通过 | 已打开并对照，通过 |
| `MessageCenterPage` | 通过 | 已打开并对照，通过 |
| `ChatPage` | 通过 | 已打开并对照，通过 |
| `NoticePage` | 通过 | 已打开并对照，通过 |
| `NotificationLogPage` | 通过 | 已打开并对照，通过 |
| `NotificationPage` | 通过 | 已打开并对照，通过 |
| `NotificationTemplatesPage` | 通过 | 已打开并对照，通过 |
| `SurveyResultPage` | 通过 | 已打开并对照，通过 |
| `OfferPage` | 通过 | 已打开并对照，通过 |
| `AccountPage` | 通过 | 已打开并对照，通过 |
| `EnterpriseSettingsPage` | 通过 | 已打开并对照，通过 |
| `EvaluationReportPage` | 通过 | 已打开并对照，通过 |
| `ReviewPage` | 通过 | 已打开并对照，通过 |
| `InterviewAppointmentDetailPage` | 通过 | 已打开并对照，通过 |
| `RealInterviewSchedulePage` | 通过 | 已打开并对照，通过 |
| `InterviewSchedulePage` | 通过 | 已打开并对照，通过 |
| `InterviewerCalendarPage` | 通过 | 已打开并对照，通过 |
| `RescheduleReviewPage` | 通过 | 已打开并对照，通过 |
| `SchedulePage` | 通过 | 已打开并对照，通过 |
| `CandidateScoreDetailPage` | 通过 | 已打开并对照，通过 |
| `GreetingPage` | 通过 | 已打开并对照，通过 |
| `RecommendationReportPage` | 通过 | 已打开并对照，通过 |
| `ScreeningPage` | 通过 | 已打开并对照，通过 |
| `ScreeningResultsPage` | 通过 | 已打开并对照，通过 |
| `ScreeningTaskListPage` | 通过 | 已打开并对照，通过 |
| `ShortlistReviewPage` | 通过 | 已打开并对照，通过 |
| `TalentDetailPage` | 通过 | 已打开并对照，通过 |
| `TalentPage` | 通过 | 已打开并对照，通过 |
| `P1PreviewShell` | 通过 | 已打开并对照，通过 |
| `P2PreviewShell` | 通过 | 已打开并对照，通过 |
| `P3PreviewShell` | 通过 | 已打开并对照，通过 |
| `P4PreviewShell` | 通过 | 已打开并对照，通过 |
| `P5PreviewShell` | 通过 | 已打开并对照，通过 |
| `P7PilotPage` | 通过 | 已打开并对照，通过 |
| `DashboardScreen` | 通过 | 已打开并对照，通过 |
| `JobsScreen` | 通过 | 已打开并对照，通过 |
| `MainShell` | 通过 | 已打开并对照，通过 |
| `MessagesScreen` | 通过 | 已打开并对照，通过 |
| `ChatScreen` | 通过 | 已打开并对照，通过 |
| `ProfileScreen` | 通过 | 已打开并对照，通过 |
| `SettingsScreen` | 通过 | 已打开并对照，通过 |
| `TalentScreen` | 通过 | 已打开并对照，通过 |

## 设备验收边界

设备必须为 Pixel_10a。真实业务请求沿用已有本地后端与登录令牌，日志不输出令牌及个人数据。
若缺少可用会话或测试凭据，真实登录流程标记未验证，不以合成导航页替代真实登录。
合成导航页只用于验证四个独立栈的返回与保留行为。
未完成要求的设备验收时不暂存、不提交。

## 阶段一人工验收与提交门禁

首次设备测试没有读到可用令牌，因此其报告中的 existingSessionAvailable 为 false。
随后正式 APK 确认已有真实登录态，Agent 已补验冷启动恢复、四 Tab 业务导航和真实退出。
这两种执行环境的结果分别记录，不以首次测试的无令牌结论覆盖后续实际验证。

2026-10-15，用户完成最后一项人工验收并明确确认：

- 在 Pixel_10a 登录页使用测试账号完成真实账号密码登录，成功进入首页。
- 四 Tab 切换正常。
- 详情返回正常。

以上为用户人工验收结果，区别于 Agent 已有登录态恢复及自动化测试结果；不记录账号、密码或令牌。
阶段一设备验收门禁已满足。提交前已再次运行 `flutter analyze --no-pub` 和 `flutter test`，结果如下。
本次仅在 `feature/eapp-core-services-zx` 创建本地阶段一提交，不执行推送；推送由用户另行决定。

## 提交前复验

- 2026-10-15 提交前 `flutter analyze --no-pub`：通过，No issues found，退出码 0。
- 2026-10-15 提交前 `flutter test`：全部 71 项通过，退出码 0。
- 提交文件仅包含阶段一页面、主题、通用组件、新增测试与设备验收辅助文件、本文和 integration_test 依赖声明及锁文件。
- 不暂存 API、screens、mock、后端、截图、日志、构建产物或本机配置。

## 重现设备回归

先启动本机截图辅助服务，再执行设备测试；结束后停止辅助服务。

```powershell
python test_driver/device_capture.py
flutter drive --driver=test_driver/stage_one_driver.dart --target=integration_test/stage_one_device_test.dart -d emulator-5554
flutter drive --driver=test_driver/stage_one_driver.dart --target=integration_test/stage_one_navigation_test.dart -d emulator-5554
```

辅助服务仅监听本机 `127.0.0.1:18989`，通过 Android 模拟器宿主地址接受测试请求。
使用 PATH、ANDROID_HOME 或本机 Android SDK 配置定位 ADB，不在源码中保存本机 SDK 路径。
设备尺寸测试使用 wm size 和系统方向设置，正常结束会恢复为系统原始分辨率及竖屏。若模拟器异常退出，需重启后执行 `adb shell wm size reset` 和 `adb shell settings put system user_rotation 0`；本次已恢复。
