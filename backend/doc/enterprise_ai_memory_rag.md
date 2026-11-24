# 企业端 Agent、长期记忆与 RAG

企业助手仍使用 `/enterprise/assistant` 的会话、运行和 SSE 接口，身份由登录用户与企业绑定关系推导。新增的工具全部在 SQL 中强制附带 `company_id`，不会接受客户端传入的企业标识。

## 工具

除 `list_company_jobs`、`get_company_job` 外，Agent 还提供 `list_company_candidates`、`list_upcoming_interviews`、`get_recruiting_dashboard`、`get_recruiting_funnel` 和 `search_company_knowledge`。工具只读、限量，不能发送消息、发布岗位、安排面试或修改业务数据。

## 长期记忆

迁移 `migration_enterprise_ai_memory_rag_20261123.sql` 后，企业记忆默认启用。记忆按 `company_id + user_id` 双维度存储：企业边界隔离租户，账号维度保证每位招聘者的偏好互不可见；会话摘要按会话保存，由模型生成（保留最近 24 条消息的压缩结果，失败时回退为截断原文）。模型抽取必须提供原话证据，并拒绝密码、Token、联系方式和证件信息。

若数据库执行过本功能早期单企业维度的建表脚本，需先按回滚脚本删除旧表，再重新执行本迁移；脚本使用 `CREATE TABLE IF NOT EXISTS`，不会自动补 `user_id` 列。

可通过 `GET/POST /enterprise/assistant/memory` 查看或按 revision 修改；`POST` 的 `action` 支持 `settings`、`save`、`forget`、`clear` 和 `reset_context`。`reset_context` 必须传 `sessionId`，会删除该会话摘要并记录历史围栏（`t_enterprise_ai_context_reset.forget_before_id`），之后的回答不再回放被重置的历史；删除会话会同步清理摘要和围栏。

## RAG

知识库默认关闭，设置 `app.ai.enterprise.rag.enabled=true` 后执行迁移并使用 `/enterprise/assistant/knowledge/documents` 写入脱敏的制度、JD 规范或面试资料。检索工具返回 `[K1]` 等引用编号，模型只能依据返回片段回答；删除文档会立即从检索结果中排除。当前实现以企业范围的 MySQL 词项检索为可回退实现，后续可在服务内部替换为带相同 company filter 的向量索引。

回滚前停止 Agent，备份企业记忆和知识库数据，再按 rollback 脚本删除新增表；原有 `t_ai_chat_*` 会话和岗位业务表不受影响。
