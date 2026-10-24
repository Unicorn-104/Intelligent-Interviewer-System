# 企业端真实改期审批

## 数据库变更

- 授权新增 `t_sch_reschedule_request`；完整DDL追加于 `e-app/new.sql` 的 `BEGIN RESCHEDULE_REVIEW_20261023` 标记段。
- 只执行该标记段的 CREATE TABLE，不重放历史迁移，不改已有表，不导入演示申请，不写 `t_msg`。
- 保存预约、企业、人才、申请人、原始安排快照、新时段、申请原因、审批状态及审批人/说明/时间。
- 生成列唯一索引限制每个预约最多一条待审批申请；结案历史保留。
- 回滚先退应用代码并保留新表；审批已通过的面试不会自动恢复旧时间。删表需另行备份和审批。

## 接口（沿用登录鉴权，不改变原企业直接改期API）

| 方法 | 路径 | 入参/说明 |
| --- | --- | --- |
| GET | /enterprise/interview/reschedule-requests | status=pending/approved/rejected（可选）、pageNum、pageSize（1–100） |
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
- 候选人提交API已提供；本次不修改c-app界面。需由候选人端后续接入该入口，才能从其界面发起申请。
- 自动化测试仅用合成数据和H2，不审批真实候选人、不触发真实通知。真实双端申请/审批仍需授权测试账号人工验收。

## 验证命令

```powershell
cd backend
mvn -o -pl ruoyi-admin -am test "-Dtest=RescheduleRequestServiceTest,InterviewScheduleServiceImplTest,RescheduleReviewControllerTest" "-Dsurefire.failIfNoSpecifiedTests=false"
cd ../e-app
flutter test --no-pub test/reschedule_review_test.dart test/profile_page_test.dart
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:8080
```
