# 企业端发起面试邀请与进入面试

入口：首页/岗位面试列表点击「开始面试」（到开始时间且未结束时可用）。不发新增后端接口，全部复用 PC 端（enterprise_pc）与 backend 既有能力。

## 行为

- 点击「开始面试」调用 `POST /system/conference/link` 生成会议场次与候选人会议链接（与 PC 端同款），把邀请以文本消息发送到候选人会话，随后打开会话页。
- 邀请文案与 PC 端格式一致：`【面试邀请·{阶段名}·{模式名}】{企业} {岗位} 视频面试，请点击链接进入：{CANDIDATE_APP_URL}/conference-join?token={token}`。
- 会话气泡识别 `conference-join` 链接：隐藏原始链接文本，改为「进入面试」按钮；点击后查询 `GET /system/conference/session/current`，有待开始/进行中的场次则进入面试详情（`InterviewAppointmentDetailPage`），否则提示去面试安排查看。
- 面试方式按预约阶段推导，与 PC 端 `STAGE_TYPE_MODE` 一致：AI技术面试→AI+单面试官（mode 2）、HR综合面试→无AI纯人工（mode 4）、编程实操→纯AI（mode 1）。面试官取预约的 `interviewerId`；纯AI模式传空列表；未指派面试官时阻止发起。
- 时长按预约起止时间推算（1–480 分钟），区间外不传，由后端取默认值。
- 模块级防重入保护「生成链接+发消息」网络临界区，会话打开后立即释放，返回后可再次发起。

## 接口复用（无新增后端接口）

| 接口 | 用途 |
| --- | --- |
| `POST /system/conference/link` | 生成场次、签发会议链接（`createRoomLink`） |
| `GET /system/conference/session/current` | 「进入面试」查询当前场次 |
| `GET /system/im/sessions` / `POST /system/im/messages` | 查找/创建会话与发送文本邀请 |

## 语义注意事项

- `conference/link` 每次发起都会新建场次并签发新链接，同时取消该候选人旧的待面试预约与未结束场次。旧预约逐个经面试调度服务的统一取消逻辑处理（释放面试官时段、恢复候选人/投递状态，已取消/已完成静默跳过），候选人流程状态推进为「面试中」，该岗位投递同步为「已约面」。发起前按钮受 `startTime`/`endTime` 时间窗约束，但发起本身具有破坏旧预约的副作用，验证时须注意。
- 会议链接为候选人端（user-PC / c-app）入口，候选人点击后进入候选人会议页。

## 配置

- `CANDIDATE_APP_URL`：候选人端入口地址，默认 `http://localhost:5180`，与 PC 端 `VITE_CANDIDATE_APP_URL` 一致；服务器包需显式传入（如 `https://114.55.175.79:8445`）。

## 验证与验收

- 自动测试：`test/start_interview_invitation_test.dart`（发起流程、模式推导、异常分支）、`test/chat_interview_invite_button_test.dart`（按钮渲染与进入面试）、`test/home_interview_calendar_test.dart`（入口接线）。`flutter analyze` 与 `dart format` 通过。
- 人工验收在 Pixel_10a 完成；对演示库直接发起会取消若依的既有预约，需先征得同意。
