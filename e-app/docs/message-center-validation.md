# 企业端真实消息中心

## 已有能力核查

原 APP 消息中心和聊天页使用 `mock_notification.dart`，模拟发送并生成自动回复。本次切换为真实接口，不修改 Mock 文件，也不将其内容写入业务库。

复用已有 `/system/im` 企业 IM 接口：

- `GET /sessions`：当前用户会话列表，读取 `sessionId`、`peerId`、`peerName`、`peerAvatar`、`lastMessage`、`lastMessageAt`、`unread`。
- `GET /sessions/{sessionId}/messages`：读取真实历史，消息自身归属由服务端 `isMine` 判定。
- `POST /messages`：发送文本 `{sessionId,type:1,content}`，发送人由登录态决定。
- `PUT /sessions/{sessionId}/read`、`PUT /read-all`：保留原会话已读语义。
- `GET /quick-replies`：读取服务端快捷回复，点击仅填入编辑框，用户点击发送才发送。
- `GET /unread-count`：原有 IM 未读数接口保持不变。

## 补充的消息接口

仍在同一个 `ImController`、`IImService`、`ImServiceImpl`、`ImMessageMapper` 模块内补齐系统通知，不调用或更改求职者 `/app/messages` 接口：

- `GET /system/im/notifications?limit=50&beforeId=...`：读取当前接收人的通知，返回 `data` 数组和该接收人的 `unreadCount`。`limit` 被限制在1–100，按消息ID倒序游标分页。
- `PUT /system/im/notifications/{messageId}/read`：验证接收人，标记单条已读；重复读取幂等。
- `PUT /system/im/notifications/read-all`：只修改当前接收人的系统通知。

这些接口复用现有企业角色鉴权，用户ID全部来自登录态；越权读取或修改单条通知会被拒绝。IM 已有成员校验保留，发送文本补充空内容和1000字符限制，不接受客户端伪造的发送人ID。岗位、面试、个人资料等其他接口没有修改。

## UI 与交互

蓝白消息中心采用分类切换、单行摘要、圆形头像、右侧时间和红色未读数量，系统通知作为聚合入口。保留现有底部四 Tab，不新增导航。

- “全部已读”分别复用会话已读和系统通知已读；任一步失败均不报成功，并重新读取实际未读状态。
- 打开会话先读取历史，再同步已读；不再显示模拟回复或演示消息。
- 聊天支持真实文本发送、快捷回复填入、手动刷新和前台每8秒回读；离开页面后停止轮询。
- 发送中禁用重复操作；服务端明确拒绝保留输入，网络结果未知时要求刷新核对，不自动重发。发送成功后回读真实记录。
- 现有图片和文件消息以类型摘要展示，不虚构预览或下载完成。
- 企业端未发现 AI Agent 会话接口与数据分类，因此 AI 分类明确显示“功能开发中”，不伪造会话、头像或未读数据。不复制求职者端的企业关注动态。
- 空数据、部分接口失败、权限失效有明确状态，失败不视作无消息。

## 数据库记录

只读核查了本地 `information_schema`：`t_im_session`、`t_im_message`、`t_im_quick_reply` 和 `t_msg` 均存在且必需字段完整；会话参与人索引、消息会话时间索引和通知接收人/未读索引已具备。

因此本次没有表结构或业务数据修改。`e-app/new.sql` 末尾追加了2026-10-18核查与复用说明，保留此前内容，无新增 DDL/DML。不创建重复表，不回填或插入测试消息，无需数据库迁移与回滚。

## 验证

- 后端 `ImServiceMessageTest` 使用独立 H2 数据库及生产 Mapper，覆盖接收人隔离、游标分页、已读幂等、批量已读不影响其他用户、分页边界、历史归属和文本发送校验；7项通过。仅测试资源将 MySQL 时间函数映射到 H2；生产 SQL 未作兼容性替换。
- `message_data_source_test.dart` 核对现有接口路径、方法、JSON字段、通知游标和错误响应。
- `message_center_page_test.dart` 覆盖列表、分类、空态、部分失败、全部已读、发送成功与失败、结果未知保护、通知详情、前台轮询停止及320dp/横屏键盘布局。
- 完整 Maven 编译、消息模块测试打包、Flutter 静态分析与全量测试、Android Debug 构建执行。
- 本地管理员只读联调：会话列表、通知列表、未读计数和快捷回复接口 code=200；当前管理员没有会话/通知记录，按空态展示。未向真实用户发送消息，未修改真实通知已读状态。含会话账号的真实互发与通知已读待人工验收，不能用自动测试代替。
