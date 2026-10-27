# 聊天发送岗位卡片

## 双端使用

企业聊天底部“更多”面板与图片、文件并列增加“发送岗位”。点击后可搜索、分页选择当前企业在招岗位，再确认发送；打开选择器、搜索、取消或关闭均不会发送消息。无历史会话时，确认后按真实招聘者账号与peerId创建双方会话。

服务端生成type=6、kind=job_card、version=1的卡片，包含positionId、title、company、city、salaryMin/Max、experience、education及24位十六进制requestId。内容只包含发送时的公开岗位摘要，不接收客户端自拟标题、薪资、企业或发送人。普通/system/im/messages不接受type=6，岗位发送必须走受控业务接口。

C-APP聊天显示卡片摘要，“查看岗位 · 前往投递”点击后读取求职者接口GET /agent/v1/jobs/{positionId}，映射最新岗位数据并复用求职者JobDetailScreen。绝不打开企业端JobDetailPage或企业管理接口。已投递、停招状态读取服务端最新记录，禁止重复投递；已删除或不可见岗位显示真实错误，不用卡片历史快照冒充当前详情。

用户点击“立即投递”后再确认默认简历投递，调用C-APP已有POST /app/jobs/{id}/apply。卡片点击或详情读取不自动投递。没有简历时沿用已有提示；投递网络结果未知时禁用再次提交，提示核对本人投递记录。

## API与安全

- GET /enterprise/chat/jobs：keyword可选、page从1开始，每页20条，只查登录账号当前企业启用的在招岗位。
- POST /enterprise/chat/job-cards：sessionId可选、peerId、positionId、requestId；身份从登录态获取，企业从有效绑定取得。
- 服务端校验会话成员、peerId与当前会话对方账号一致，且对方是有效求职者；人才ID不能当聊天账号使用。
- 发送前锁定发送账号与岗位，检查当前企业归属及在招状态。卡片、会话摘要和接收人未读在同一事务，任何一步失败整笔回滚。
- 同一发送账号+requestId重试返回原messageId/sessionId，不重复发送；同一ID不能换岗位或接收人。客户端不会自动重发超时写请求，先刷新聊天人工核对。
- 复用t_im_message/t_im_session，不新增DDL、不修改现有API签名。type=6需双端同时更新才能显示；坏卡片显示不可用提示，不抛出原始JSON或打开任意URL。

## 验证与回滚

随机H2库用真实Mapper验证账号/企业/岗位/会话隔离、只列在招、真实卡片内容、未读计数、同请求幂等、并发重试与事务回滚。Flutter使用合成岗位验证工具栏、选择搜索、确认/取消、超时人工核对、窄屏，以及求职者聊天点击卡片后从本端岗位接口读取和投递确认。

```powershell
cd backend
mvn -o -pl ruoyi-admin -am test "-Dtest=ChatJobCardServiceTest,ChatJobCardControllerTest,ImServiceMessageTest,ImReadReceiptServiceTest" "-Dsurefire.failIfNoSpecifiedTests=false"
cd ../e-app
flutter test --no-pub test/chat_job_card_test.dart test/chat_composer_test.dart test/message_center_page_test.dart test/reschedule_chat_card_test.dart
cd ../c-app
flutter test --no-pub test/shared_job_card_test.dart test/chat_receipts_test.dart test/reschedule_message_card_test.dart test/app_message_test.dart
```

真实双端验收需授权账号：企业选择本企业岗位并确认→求职者收到未读卡片→点开C-APP最新岗位详情→人工确认投递→查看本人投递记录。测试不能代用户发送真实岗位消息或投递简历。

回滚应用代码，保留现有会话和消息；不要删除已有卡片记录。不执行数据库回滚或清理真实聊天。

## 2026-10-27 本地验证

企业端50项、求职者端17项、后端25项定向测试通过；相关静态检查、真实MySQL不存在账号企业范围的只读SQL兼容核对、后端打包和双端Android Debug构建通过。求职者详情JD描述映射补充后又通过6项岗位卡片专项测试。

已更新本地8080后端和Pixel_10a双端应用；运行中OpenAPI确认选择和发送路由注册，匿名选择接口业务401。模拟器实际聊天工具栏有发送岗位入口，选择器标题与搜索存在，真实岗位摘要显示3条且无读取错误。仅打开选择面板，没有代用户发送真实岗位卡片或投递。真实双端收发和投递仍由授权账号人工确认。
