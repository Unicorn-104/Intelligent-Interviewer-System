# 企业端视频面试会议室（进入面试）

## 功能范围

企业端「消息-面试邀请」中的“进入面试”与面试详情中的“进入视频面试”不再打开演示工作台，而是进入真实视频会议室：复用 PC 端（enterprise_pc）同一套 `/system/conference` 接口与 LiveKit 媒体服务器，页面布局参考腾讯会议移动端与 enterprise_pc 视频会议页（暗色画面区、顶部会议信息/计时/结束、底部控制栏、成员与会议信息面板）。

本功能仅新增 e-app 前端接入，未新增后端接口；音视频由 LiveKit SFU 承载，令牌由后端签发。

## 接口复用（无新增后端接口）

| 步骤 | 接口 | 说明 |
| --- | --- | --- |
| 查询场次 | `GET /system/conference/session/current` | 聊天页“进入面试”入口查询待开始/进行中场次 |
| 场次上下文 | `GET /system/conference/session/{id}` | 面试详情页校验预约与会话匹配后取 role/interviewers |
| 面试官加入 | `POST /system/conference/session/{id}/interviewer/join` | HR 入会前登记 join_status（主面试官自动补记；幂等，失败不阻断入会） |
| 换取入会令牌 | `GET /system/conference/livekit-token/{id}` | 返回 `{url, token, room, identity}`，直接连 LiveKit |
| 保活 | `POST /system/conference/session/{id}/heartbeat` | 每 15 秒一次（与 PC 端一致） |
| 结束 | `POST /system/conference/session/{id}/finish` | 结束面试时提交 `endReason=normal`；离开会议（不结束）不调用 |

角色与权限沿用后端规则：候选人 `CANDIDATE`、主面试官/指派面试官 `HR`、同企业其他用户 `OBSERVER`（仅旁听、不发流）。OBSERVER 界面隐藏麦克风/摄像头开关并显示“旁听中”角标。

## 前端结构

- `lib/api/interview_room_api.dart`：新增 `getLiveKitToken`、`joinInterviewerSession`（均为已有后端接口的客户端封装）。
- `lib/features/enterprise/conference/interview_modes.dart`：面试模式文案与阶段类型→模式映射（与 PC 端 MODE_LABEL / STAGE_TYPE_MODE 一致），邀请页与会议室共用。
- `lib/features/enterprise/conference/conference_room_engine.dart`：`ConferenceRoomEngine` 抽象 + `LiveKitConferenceEngine` 实现（livekit_client 2.13.2）。连接/重连/断开、参会者与轨道事件、麦克风/摄像头开关、前后摄翻转、Android 扬声器外放、设备不可用提示；状态为不可变快照，页面只依赖抽象层，测试可注入假引擎。
- `lib/features/enterprise/conference/conference_room_page.dart`：会议室页面。入会引导（HR 登记 → 换令牌 → 连接 LiveKit）、候场/宫格画面、悬浮自拍预览（镜像）、状态角标、顶部计时与结束、底部麦克风/摄像头/翻转/成员/更多/结束、成员面板（本人/候选人/各面试官加入状态与麦克风）、会议信息面板、离开/结束二选一弹层、结束二次确认、失败重试与返回。心跳 15 秒、计时每秒推进。
- 入口接线：`conversation_page.dart` 的“进入面试”改为直接打开会议室（`conferenceRoomBuilder` 可注入，测试用）；`interview_appointment_detail_page.dart` 的演示工作台按钮改为“进入视频面试”，打开前先核对 `getSessionContext` 返回的 sessionId/appointmentId 与列表项一致。

## 平台与权限

- `pubspec.yaml` 新增 `livekit_client: ^2.13.2`（间接引入 flutter_webrtc 1.6.3）。
- AndroidManifest 新增 CAMERA、RECORD_AUDIO、MODIFY_AUDIO_SETTINGS、BLUETOOTH（maxSdkVersion 30）、BLUETOOTH_CONNECT；摄像头/麦克风 uses-feature 均 required=false，保证无摄像头设备仍可安装旁听。

## 验证

- `conference_room_page_test.dart`：假引擎驱动，覆盖 HR 入会三步（join→token→connect 参数核对）、候场界面、麦克风/摄像头/翻转调用、成员与会议信息面板、OBSERVER 旁听不发流、令牌失败重试、连接失败展示与返回、结束二次确认提交 finish 并断开、离开不结束、计时与心跳推进。
- `chat_interview_invite_button_test.dart`：改为断言“进入面试”直接打开注入的假会议室并传递完整场次上下文；空场次与查询失败提示保留。
- 完整 `flutter test` 通过（本增量无失败项）；`flutter analyze` 无错误。

## 实际验证边界（重要）

- 本地后端无 LiveKit 密钥，`livekit-token` 会返回“LiveKit 服务未配置”。真机联调需在后端启动参数配置 `--livekit.api-key/--livekit.api-secret/--livekit.url` 指向可用的 LiveKit 服务器（本次联调使用远端已部署的 LiveKit，密钥仅以启动参数传入，不写入任何文件）。
- 会议房间实时音视频端到端验证需要一个真实待开始/进行中场次。创建场次（`POST /system/conference/link`）会取消该候选人旧的待面试预约并推进流程状态，属不可逆业务写入，须经用户明确授权后才执行；在此之前不通过界面发起面试。
- 模拟器摄像头/麦克风为虚拟设备，真实设备行为（权限弹窗、前后摄切换、扬声器）以实机验证为准。
