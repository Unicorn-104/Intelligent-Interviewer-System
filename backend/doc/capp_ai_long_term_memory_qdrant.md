# C-App 个人长期记忆与 Qdrant

本阶段只实现用户个人长期记忆，不接招聘知识库 RAG。MySQL 保存记忆事实、版本、来源消息和待同步任务；Qdrant 只保存 embedding 和过滤元数据，丢失后可从 MySQL 重建。是否保存由“对未来对话是否重要”决定，不由固定业务类型白名单决定。

## 数据流

1. AI 任务成功完成后，后端把本轮用户消息放入 `t_capp_ai_memory_extract_job`。
2. 后台用同一 AI Provider 提取最多 3 条候选。候选必须带原文连续证据；后端检查用户归属、证据存在、敏感信息、类型和去重。模型不能直接写数据库。
3. 通过校验的事实写入 `t_capp_ai_memory_item`，来源写入 `t_capp_ai_memory_evidence`，并写入向量 outbox。
4. 向量 worker 调用本机 Embedding API，再向 Qdrant upsert；失败自动延迟重试，MySQL 仍是事实源。
5. 新任务准备上下文时，以当前用户消息生成 query embedding，Qdrant 强制按 `user_id` 和 `status=ACTIVE` 过滤；召回 ID 再回 MySQL 读取正文。

## Qdrant 索引规范

- 集合：`capp_user_memory_bge_small_zh_v1`
- 距离：Cosine
- 当前示例维度：512
- payload：`user_id`（integer）、`status`（keyword）、`memory_type=fact`（keyword）、`revision`（integer）
- 点 ID：MySQL `t_capp_ai_memory_item.id` UUID
- 不把记忆正文放入 Qdrant payload
- 更换 embedding 模型、维度或距离时新建集合版本，不能混写旧集合
- 个人记忆与未来知识库必须使用不同集合和不同权限过滤

## 本机 Embedding 服务

Qdrant 本身不负责把中文文本转换为向量。仓库提供回环地址 FastEmbed 适配器：

```powershell
cd backend
powershell -ExecutionPolicy Bypass -File .\tools\start_memory_embedding.ps1
```

默认监听 `127.0.0.1:8091`，模型为 `BAAI/bge-small-zh-v1.5`。第一次启动会在用户本地虚拟环境安装并下载模型；真实模型文件不进入 Git。后端私有 `backend/config/application.yml` 需要配置：

```yaml
app:
  ai:
    memory:
      vector:
        qdrant-url: http://127.0.0.1:6333
        embedding-url: http://127.0.0.1:8091/v1/embeddings
        embedding-model: BAAI/bge-small-zh-v1.5
        dimension: 512
```

未配置 Embedding URL 时，MySQL 记忆和管理接口仍可用，向量同步会延迟重试，Agent 不会伪造检索结果。

## 管理接口

客户端仅在「设置 → 隐私与通用」显示「记忆」开关，AI 对话页不再提供记忆明细入口。
开关通过 `GET /app/ai/memory-settings` 和 `PUT /app/ai/memory-settings` 同步当前账号状态，
更新正文为 `{enabled, revision}`，响应仅包含开关与版本，不返回记忆内容。
关闭后停止个人事实提取、偏好与长期记忆召回及滚动摘要使用；已有记忆保留。
切换时递增版本并更新消息边界，关闭期间及切换前积压的消息不会在重新开启后补提取。
正在生成回答时返回冲突提示，需先停止生成再切换。

- `GET /app/ai/long-term-memories`
- `PUT /app/ai/long-term-memories/{id}`，正文 `{content, revision}`
- `DELETE /app/ai/long-term-memories/{id}`

删除和修改先更新 MySQL，再写向量 outbox；后台处理完成前，检索结果仍会再次回 MySQL 校验 `ACTIVE` 状态，不会把已删除正文注入模型。

## 迁移与回滚

- 迁移：`backend/doc/migration_capp_ai_long_term_memory_20261027.sql`
- 回滚：`backend/doc/rollback_capp_ai_long_term_memory_20261027.sql`

迁移增加记忆事实、来源、提取任务和向量 outbox 四张表。回滚前必须备份个人记忆并停止应用。
Qdrant 数据可根据 MySQL 中的有效事实重新向量化，但目前没有一键全量重建命令；已完成的 outbox 不会因集合丢失自动重跑。

## 服务器部署

推荐当前阶段将 Backend 与 Embedding 服务运行于同一 Linux 主机，Qdrant 使用容器并映射回环端口。
Backend 使用容器时不能照搬回环地址；当前 Python 适配器明确只支持回环监听。
需要跨主机或跨容器访问 Embedding 时，先设计受控代理与 TLS，不要直接取消监听限制后暴露公网。

1. 备份 MySQL；确认已完成 Agent、固定偏好、历史动作、任务上下文等前置迁移，再执行本次长期记忆迁移。
2. 固定 Qdrant 镜像版本并挂载 `/qdrant/storage` 到持久卷；映射为 `127.0.0.1:6333:6333`，启用自动重启。只开放 Backend 所需 REST 端口。
3. 创建 Python 虚拟环境并安装 `tools/requirements-memory.txt`，保存经验证的依赖版本。模型使用 `BAAI/bge-small-zh-v1.5`、512 维、Cosine。
4. 使用 `tools/memory-embedding.service.example` 配置 systemd；按服务器实际目录、账号和虚拟环境修改路径，提前创建并授权模型缓存目录。
5. 私有 `/etc/capp/memory-embedding.env` 写入 `MEMORY_EMBEDDING_TOKEN`，仅运行账号可读；Backend 的 `embedding-api-key` 使用同一值。Java 使用 `Authorization: Bearer`，Qdrant 则使用独立的 `api-key` 请求头。
6. 复制 `config/application.example.yml` 为服务器私有 `config/application.yml`，通过环境变量注入密钥，同时补齐项目原有数据库、Redis 和 AI Provider 配置。从 `backend/` 工作目录启动 JAR，或明确指定外部配置位置。

环境变量：`MEMORY_EMBEDDING_CACHE_DIR` 控制模型缓存目录；`MEMORY_EMBEDDING_PRELOAD=true` 在启动监听前加载模型。
首次下载需要访问模型源，建议部署时预下载，避免首次对话触发下载。只检查 `/health` 不足以验证未预加载的模型；必须调用一次真实 `/v1/embeddings`，确认返回 512 维。
当前 HTTP 适配器适合低并发，实际容量和超时应按目标服务器压测；默认模板请求超时为 10 秒。

Backend 首次使用时会创建集合、验证维度与距离并建立 `user_id`、`status`、`memory_type` 索引，账号须具备对应权限。
更换模型时，即使维度相同也应使用新集合并全量重新向量化。不要把旧向量和新模型查询混用。
向量配置只是检索依赖；个人事实提取仍需启用的对话 AI Provider 与可用 API 凭据。

验收：新消息完成回答后，检查提取任务完成、事实与证据入库、outbox 完成、Qdrant 点存在、新会话召回正确，
并覆盖不同账号隔离、关闭记忆、失败重试、修改与删除同步。现有本机验收不能替代服务器环境验收。
监控提取任务的 FAILED 状态与 outbox 重试积压；提取任务最多尝试 5 次，不能假设网络恢复后所有失败任务都会无限重试。
部署日志不要开启记忆/对话 Mapper 的 DEBUG 级别；模板已将两者设为 INFO。

Qdrant 和 MySQL 都应定期备份；数据库正文、证据、快照、模型缓存、私有环境文件与本机测试数据均不进入 Git。
旧版本回滚前先停用对应 worker，再按备份与回滚 SQL 评估；不要自动执行会删除真实记忆的 DROP TABLE。
