# 企业端真实改期审批

## 数据库变更

- 授权新增 `t_sch_reschedule_request`；完整DDL追加于 `e-app/new.sql` 的 `BEGIN RESCHEDULE_REVIEW_20261023` 标记段。
- 只执行该标记段的 CREATE TABLE，不重放历史迁移，不改已有表，不导入演示申请。消息通知复用 `t_msg`、`t_im_session`、`t_im_message`，不增加数据库结构。
- 保存预约、企业、人才、申请人、原始安排快照、新时段、申请原因、审批状态及审批人/说明/时间。
- 生成列唯一索引限制每个预约最多一条待审批申请；结案历史保留。
- 回滚先退应用代码并保留新表；审批已通过的面试不会自动恢复旧时间。删表需另行备份和审批。

## 接口（沿用登录鉴权，不改变原企业直接改期API）

| 方法 | 路径 | 入参/说明 |
| --- | --- | --- |
| GET | /enterprise/interview/reschedule-requests | status=pending/approved/rejected（可选）、pageNum、pageSize（1–100） |
| GET | /enterprise/interview/reschedule-requests/{requestId} | 当前企业申请详情，聊天审批前核对申请人账号与会话 peerId |
| PUT | /enterprise/interview/reschedule-requests/{requestId}/review | decision=approved/rejected、note（驳回必填，最多500字） |
| POST | /candidate/interview/reschedule-requests/{appointmentId} | newStartTime、reason（必填，最多500字）；仅当前候选人本人预约 |
| GET | /candidate/interview/reschedule-requests | pageNum、pageSize；仅本人申请 |

- 列表返回标准 `rows/total/code`；提交/审批返回 `data` 中真实申请记录。时间为北京时间 `yyyy-MM-dd HH:mm:ss`。
- 身份从登录态取得，不接受客户端企业或申请人归属；企业未绑定不兜底到企业1。
- 候选人提交时只保存申请，原时段仍保留。新时段须在未来且按分钟，沿用原时长（1–1440分钟）。
- 通过时核对原安排未变更，再通过原调度服务检查面试官/候选人冲突和阶段顺序。释放原时段、占用新时段与结案在同一事务提交。
- 驳回不改面试安排，说明必填。禁止审批本人申请；同结果重试幂等，不覆盖首次审批人和说明，反向决定被拒绝。
- 加锁顺序：候选人 → 预约 → 申请 → 原调度的升序面试官锁。锁后读取不复用MyBatis旧快照。
- 原安排被修改、取消或已开始时不能通过，但允许驳回关闭申请。

## APP行为与验收边界

- 「我的 → 改期审批」去掉演示标记，真实服务端筛选/分页、下拉刷新、通过/驳回确认、驳回说明、加载/错误/空态均接真实API。
- 发送中禁用重复审批；超时或结果不确定不自动重发，先刷新并人工核对。
- 没有申请时明确显示真实空态，不把普通面试安排伪造成审批记录。
- C-APP 面试详情提供改期申请入口；提交原因和新开始时间，保留原时长，申请结果不确定时先读取本人申请核对。
- 企业直接改期成功后，自动在与该求职者的会话发送改期卡片，并向求职者发送站内通知；无会话时创建真实双方账号会话，同一时段的重复保存不重复通知。
- 求职者提交申请后，同企业有效账号收到入站聊天卡片、未读计数及站内通知；卡片展示岗位、原时段、申请时段、原因和“同意 / 拒绝”。
- 点击审批先核对服务端详情与当前会话的求职者账号；同意复用冲突检查，拒绝必填原因。明确业务失败显示原因，结果不确定时只能核对原申请，不自动重试。
- 审批后更新原申请卡片状态，并发送结果卡片和求职者站内通知；聊天轮询同步状态，多位招聘者不会留下可操作的旧按钮。同结果重复审批不重复发送。通知上线前没有聊天卡片的历史申请仍可审批。
- 消息与申请、改期及审批在同一事务提交；任一步写入失败整笔回滚。卡片类型 `5` 的 JSON 使用 `kind=interview_reschedule`、`version=1` 和 `pending/changed/approved/rejected` 状态，仅服务端改期业务生成，普通发消息接口不接受该类型。
- 双端聊天卡片展示完整时间区间与审批说明；拒绝时明确原面试安排保留。聊天前台约8秒读取新消息，后台停止，返回恢复；此处为站内消息，不包含系统推送。
- 自动化测试仅用合成数据和H2，覆盖消息SQL、双方未读、幂等、通知失败回滚和聊天卡片，不审批真实候选人、不触发真实通知。真实双端申请/审批仍需授权测试账号人工验收。

## 验证命令

以下均为定向验证，不代表全量回归或真实双端验收：


```powershell
cd backend
mvn -o -pl ruoyi-admin -am package "-Dtest=RescheduleMessageServiceTest,RescheduleRequestServiceTest,InterviewScheduleServiceImplTest,RescheduleReviewControllerTest,ImServiceMessageTest" "-Dsurefire.failIfNoSpecifiedTests=false"
cd ../e-app
flutter test --no-pub test/reschedule_chat_card_test.dart test/reschedule_review_test.dart test/message_center_page_test.dart test/home_interview_reschedule_test.dart test/interview_reschedule_test.dart test/message_data_source_test.dart
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:8080
cd ../c-app
flutter test --no-pub test/reschedule_request_action_test.dart test/reschedule_message_card_test.dart test/app_message_test.dart test/application_interview_contract_test.dart test/application_interview_widget_test.dart
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

静态检查对本功能相关文件执行 `flutter analyze --no-pub` 和 Dart 格式检查。

2026-10-26 本机构建恢复了 C-APP 已声明的 PDF/Markdown 依赖；当前 Flutter SDK 要求锁文件同步 `matcher`、`meta`、`test_api`、`vector_math` 四个基础依赖，未升级业务依赖。Windows 跨盘 Kotlin 缓存异常可仅在构建进程中设置 `ORG_GRADLE_PROJECT_kotlin.incremental=false`、`ORG_GRADLE_PROJECT_kotlin.compiler.execution.strategy=in-process`，无需清空工作区或改动持久构建配置。

## 双端人工验收

1. 企业端在近期面试中改期，确认保存成功、原会话新增“企业已调整面试时间”卡片，求职者端收到聊天未读和站内通知，时段与日程一致。
2. 求职者端从本人面试详情提交申请，企业聊天收到入站申请卡片，岗位、申请人、原时段、新时段与原因均正确；其他企业账号不可查看或审批。
3. 点击同意后核对新日程与原时段释放；重复同意不重复改期或发消息，其他招聘者刷新后不再看到待处理按钮。
4. 点击拒绝须填写原因；拒绝后原时段保留，求职者看到拒绝结果与说明。冲突时显示真实错误，申请仍待处理。
5. 模拟提交或审批超时、切后台与返回，核对原申请且不自动重发；确认普通文本、图片、文件聊天和系统通知仍可用。

本功能为站内消息与聊天通知。尚不包含 Android/iOS 系统级推送；设备/模拟器及授权测试账号未完成上述步骤前，不标记真实双端验收通过。
