# 企业端 Agent、长期记忆与 RAG

企业助手仍使用 `/enterprise/assistant` 的会话、运行和 SSE 接口，身份由登录用户与企业绑定关系推导。所有工具查询都强制携带 `company_id`；知识库检索在 Qdrant 按 `company_id` 过滤后，还会回查 MySQL 的 `ACTIVE` 文档，避免跨企业或已删除资料进入上下文。

## 工具

除 `list_company_jobs`、`get_company_job` 外，Agent 还提供 `list_company_candidates`、`list_upcoming_interviews`、`get_recruiting_dashboard`、`get_recruiting_funnel` 和 `search_company_knowledge`。工具只读、限量，不能发送消息、发布岗位、安排面试或修改业务数据。

## 长期记忆

迁移 `migration_enterprise_ai_memory_rag_20261123.sql` 和 `migration_enterprise_ai_memory_qdrant_20261126.sql` 后，企业记忆默认启用。记忆按 `company_id + user_id` 双维度存储：企业边界隔离租户，账号维度保证每位招聘者的偏好互不可见；会话摘要按会话保存，由模型生成（保留最近 24 条消息的压缩结果，失败时回退为截断原文）。模型抽取必须提供原话证据，并拒绝密码、Token、联系方式和证件信息。抽取在回答完成后异步执行，记忆页刷新可能有延迟；模型没有直接写记忆的工具，不得声称保存成功。

固定偏好仍保存在 `t_enterprise_ai_memory` 的 7 个 key 中，回答时全量注入，用于招聘重点、薪资策略等硬约束。明确事实改为多条保存到 `t_enterprise_ai_memory_fact`，每条有独立 `id`、类型、正文和原文证据；同一 key 可以有多条事实，不再后写覆盖前写。

语义召回流程：当前用户问题先走 Embedding，再在 Qdrant 集合 `enterprise_memory_bge_small_zh_v1` 中按 `company_id + user_id + status=ACTIVE` 过滤召回 Top 30；命中后回查 MySQL 的 `ACTIVE + INDEXED` 事实；配置 Reranker 时对候选做精排取 Top 5，Reranker 不可用或超时时回退 Qdrant 分数。`prepare()` 只注入固定偏好、召回事实和当前会话摘要，不再把全部事实一次性塞入上下文。

Qdrant 只保存向量和 `company_id`、`user_id`、`memory_type`、`status` 过滤元数据，不保存正文。新增事实先写 MySQL（`PENDING`），再批量 Embedding/upsert，成功后标记 `INDEXED`；失败标记 `FAILED` 并写入 outbox，由定时任务补偿。删除先把 MySQL 事实标为 `DELETED`，再尽力删除 Qdrant 点；检索回查 MySQL，残留向量不会进入上下文。修改事实保持 `memory_id` 不变，用同一个 Qdrant point id upsert。

可通过 `GET/POST /enterprise/assistant/memory` 查看或按 revision 修改固定偏好；`POST` 的 `action` 支持 `settings`、`save`、`forget`、`clear` 和 `reset_context`。`clear` 同时清空固定偏好和全部事实，`reset_context` 必须传 `sessionId`，会删除该会话摘要并记录历史围栏（`t_enterprise_ai_context_reset.forget_before_id`），之后的回答不再回放被重置的历史；删除会话会同步清理摘要和围栏。

新增事实管理接口：

- `GET /enterprise/assistant/memory/items`：当前招聘者的 ACTIVE 事实。
- `PUT /enterprise/assistant/memory/items/{id}`：修改类型、正文或证据，point id 不变。
- `DELETE /enterprise/assistant/memory/items/{id}`：删除单条事实并清理 Qdrant。
- `POST /enterprise/assistant/memory/clear`：清空当前招聘者的全部事实。
- `POST /enterprise/assistant/memory/reindex`：从 MySQL 重建当前招聘者的事实向量。
- `GET /enterprise/assistant/memory/index-status`：返回 active/indexed/pending/failed/deleted、outbox 和 Qdrant 点数。

Reranker 默认关闭。部署后配置 `app.ai.enterprise.memory.rerank.enabled=true` 和 `/rerank` 地址；未部署时系统只使用 Qdrant 向量分，不影响回答。所有身份仍从登录用户与企业绑定关系推导，接口不接收 `companyId` 或 `userId`。

## RAG

知识库默认关闭，设置 `app.ai.enterprise.rag.enabled=true` 后执行迁移并使用 `/enterprise/assistant/knowledge/documents` 写入脱敏的制度、JD 规范或面试资料。检索工具返回 `[K1]` 等引用编号，模型只能依据返回片段回答；删除文档会立即从检索结果中排除。

MySQL 仍是文档和片段的权威数据源；Qdrant 只保存向量与 `company_id`、`document_id` 过滤元数据，不保存正文。默认集合为 `enterprise_knowledge_bge_small_zh_v1`，Cosine、512 维，不能与个人长期记忆集合混用。Embedding 复用 `app.ai.memory.vector` 的 `embedding-url`、模型和维度配置；未配置 Embedding 时新增和检索返回 503，助手工具会降级为无可引用资料，不会中断整轮回答。

新增文档会同步分批 Embedding 并 upsert；Qdrant 写入失败时文档标记为 `FAILED`，不会进入检索。删除先更新 MySQL 状态，再尽力清理 Qdrant 点；检索命中还会回查 `ACTIVE` 文档，因此残留向量不会注入模型。切换到 Qdrant 前已存在的 MySQL 文档需要由企业管理员调用一次 `POST /enterprise/assistant/knowledge/reindex` 重建向量。

回滚前停止 Agent，备份企业记忆和知识库数据，再按 rollback 脚本删除新增表；原有 `t_ai_chat_*` 会话和岗位业务表不受影响。
