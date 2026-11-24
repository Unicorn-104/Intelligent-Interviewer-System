# C-App 消息分组与历史

## 目标

消息中心采用一个混合列表，HR、企业动态和系统通知按最近时间排列，无分类页签。保留原始 t_msg 和 IM 会话，只在读取时生成分组摘要：

- HR：按 IM 会话显示最后消息。
- 企业动态：按公司归并，详情按 msg_target_url 保留每个岗位动态。
- 已关注且当前没有岗位通知的企业也保留入口，显示“已关注，暂无新动态”；该入口不生成通知记录、计数或未读。取消关注后没有历史通知的入口消失，已有通知历史仍保留。复用 t_usr_interest 与 t_cmp，缺少关注表时只显示可读取的通知和 HR 会话，不自动建表。
- 系统通知：有预约关联的通知按 apt_id 归并，同一场面试的改期申请、审批结果和预约通知进入同一历史；无法安全关联的旧通知归入 SYSTEM/0。

## 接口

GET /app/messages/threads?category=ALL&limit=20
GET /app/messages/threads/{threadType}/{threadId}/events?limit=20
PUT /app/messages/threads/{threadType}/{threadId}/read

列表支持 beforeTime、beforeId 与 beforeType 游标，避免 HR 会话编号与通知编号相同且时间相同时漏项；历史支持 beforeId。响应包含 items、hasMore 和 unreadCounts（HR、COMPANY、SYSTEM）。后端保留按分类读取的兼容能力，默认 ALL。

已读接口只接受当前用户、当前分组可读的原始 messageIds，不会因为打开一条摘要而清空整个分组或其他分类的未读状态。

## 部署与回滚

本次不新增表或迁移，依赖 MySQL 8 的窗口函数。部署后先用测试账号读取三个分类和一家公司多个岗位，再检查同一预约的改期通知是否出现在同一历史流。回滚时先回退 C-App 到旧接口，再回退后端分组接口；原始通知数据不删除。

2026-11-23 本地运行发现原数据库尚无现有改期模块的 t_sch_reschedule_request 表。消息服务通过 information_schema 检查当前数据库，仅在表存在时复用 RescheduleRequestMapper 的 rsr_id、rsr_requester_id、rsr_appointment_id 关联；表缺失时不执行该关联，直接预约链接仍可归并，无法确认归属的改期通知保留在其他通知，不凭正文猜测，不建替代表或自动迁移。无此表的环境尚不能据此宣称改期业务本身可用。

已在模拟器热重载并验证本地登录后的统一消息列表与其他通知历史可正常读取；新增缺表回归与跨类型同时间同 ID 分页回归通过。未修改真实业务数据或服务器结构。

先更新后端，再启用新版客户端。旧服务不存在新接口时，客户端明确提示消息服务需要更新，不以旧摘要冒充完整历史。

本地验证包括实际 Mapper SQL 的 H2 MySQL 模式测试、后端编译、Flutter 交互与本地 HTTP 协议测试。截图使用合成数据。它们不代表当前服务器 MySQL 或真实账号已完成验收；本轮未部署服务器、未修改真实业务记录。
