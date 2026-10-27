# 聊天气泡、时间与消息回执

## 界面

企业聊天使用浅灰背景、对方白色气泡、本人浅绿色气泡和深色16号正文；保留真实头像、岗位卡片、附件和改期卡片。聊天头像使用圆角方形，双向气泡尖角指向头像。

首条消息、相邻间隔至少5分钟或跨自然日时，在消息之间居中显示北京时间。当天显示时分，昨天显示“昨天”，跨年含年份。长按气泡可查看完整时间与复制消息。送达/已读放在本人气泡左下侧，不压缩到正文内部。

## 回执契约

- 送达（deliveryStatus=delivered）：服务端已保存消息并可供对方在会话中获取；不代表手机系统推送送达。
- 已读（deliveryStatus=read）：对方前台打开当前聊天、最新一批消息已显示，并成功提交已读游标。
- 入站消息使用received表示支持回执协议，不在入站气泡显示状态。
- 字段缺失、未知或未部署回执表时隐藏状态，不根据会话未读角标、请求成功或定时器推测已读。
- 双方客户端前台约8秒刷新历史及状态；暂停、离开或页面被覆盖时不提交已读；查看较早历史时不确认后续未显示消息。返回底部后才确认最新消息。
- 已读回执表示聊天已显示这一批消息，不能证明对方逐字阅读。旧客户端不会提交回执，需要双方更新。

新增接口：PUT /system/im/sessions/{sessionId}/receipts，body={lastMessageId: 正整数}。身份来自登录态，只允许会话成员，消息必须属于该会话；不接受客户端提供查看人或对方账号。

响应data包含supported与lastMessageId（支持时）。单调游标以会话和查看账号为主键，重复和乱序请求不会回退。锁定会话后更新游标，并按当前快照重算该接收人的未读数，新消息不会被旧确认清空。清除角标与“全部已读”保留原行为，不生成查看回执。

## 迁移和启用

原数据库没有逐消息已读记录。2026-10-26 经用户明确确认，已在项目当前数据源执行新增表脚本并验证重复执行幂等；4个非空字段和联合主键符合预期，原聊天消息表及会话表结构保持不变。没有为验证插入合成业务数据或伪造真实用户回执。

先由维护者确认并执行 [迁移脚本](../../backend/doc/migration_im_read_receipts_20261026.sql)，仅新增t_im_read_cursor，保留现有消息与会话表，不回填历史已读。随后部署服务端与双方客户端。

服务端每10秒检查表是否存在。表未部署时原聊天仍可使用，不显示不可靠的状态。部署后，历史消息只有在对方实际打开会话并确认后才出现已读。

回滚先退应用或关闭回执入口，保留游标表。确需删除时先备份并授权执行 [回滚脚本](../../backend/doc/rollback_im_read_receipts_20261026.sql)，会清除回执记录，不删除原聊天消息。不得运行中删除表。

## 2026-10-26 本地启用

- 新后端完成打包和18项定向测试，在8080启动；公开入口HTTP 200，匿名PUT回执接口业务code 401，运行中OpenAPI已确认路由注册。
- Pixel_10a模拟器保留数据更新双端Debug APK，双方冷启动成功，企业端保持前台。
- 回执将在双方真实打开聊天并显示消息后产生。没有用真实账号发送消息或代替用户确认已读，真实双端送达→已读验收仍待人工完成。

## 验证

只用随机H2数据库与合成消息，覆盖未迁移降级、归属校验、回执单调性、并发确认、本人查看不影响本人消息、新消息与旧确认交错、时间时区、长按、窄屏和大字。

定向命令：

```powershell
cd backend
mvn -o -pl ruoyi-admin -am test "-Dtest=ImReadReceiptServiceTest,ImServiceMessageTest,RescheduleMessageServiceTest" "-Dsurefire.failIfNoSpecifiedTests=false"
cd ../e-app
flutter test --no-pub test/chat_readability_receipts_test.dart test/message_center_page_test.dart test/reschedule_chat_card_test.dart test/chat_page_context_test.dart test/message_data_source_test.dart
cd ../c-app
flutter test --no-pub test/chat_receipts_test.dart test/app_message_test.dart test/reschedule_message_card_test.dart test/application_interview_contract_test.dart
```

合成预览位于e-app/build/chat-preview/readable-chat.png，不作为真实账号验收证据，不提交构建产物。还需双端授权测试账号验收：A发送→显示送达；B停留列表或清角标→仍为送达；B打开聊天→A刷新为已读；后台/覆盖页不产生误回执。

## 2026-10-26 状态文字缺失修复

企业端GET /system/im/sessions/{sessionId}/messages 原先只返回基础消息字段，漏掉了回执填充调用，导致deliveryStatus为空并被客户端按未知状态隐藏。现已在ImServiceImpl.selectMessageList返回前调用回执服务。

新增回归先在旧实现复现deliveryStatus为null，再验证修复后文本、表情和入站消息分别返回delivered/read/received；控制器测试检查最终JSON中的deliveryStatus及isMine，覆盖此前遗漏的历史接口到界面之间的契约。相关20项定向测试通过，新后端已打包并在8080启动。

已在模拟器中打开用户反馈对应的既有会话，仅统计界面状态文字，确认显示3处送达，没有发送测试消息、没有伪造对方已读。对方实际打开并显示消息后的已读状态仍按原回执契约判断。此次只更新后端，客户端无需重装。

## 气泡主体对齐与连续轮廓

双方使用固定头像列与同一正文区域，多行或超过6个字素的文本气泡扩展到统一矩形边界；不超过6个字素的单行短消息继续按内容收窄并贴近发送方头像。尖角和送达/已读均不计入矩形正文宽度，回执在气泡外左下侧浮置，不挤压绿色气泡。

气泡和箭头使用ChatBubbleBorder同一路径填充及描边，白色轮廓在连接处连续，无独立矩形边框穿过尖角。新增320/430/900宽度下的气泡矩形左右坐标、短消息收窄及状态框外位置验证，并使用像素采样验证箭头连接处无竖向边线。合成预览生成前直接断言四个完整句子的左右矩形坐标一致，避免预览单行收窄漏验。相关59项定向测试及静态检查通过。
