# C-App 个人知识库 RAG

本轮实现 Backend 与 C-App 的个人知识库。平台公共库仅预留 scope 字段；当前接口只允许 PERSONAL，客户端不能发布公共资料。

## 使用与资料范围

AI 助手顶部文件夹 → 知识空间 → 上传资料。固定分类为“最近、创作、文件、音频”，来源筛选为“已生成、我的上传”。个人附件自动归为“文件 / 我的上传”，不需要建库、指定上传位置或选库。页面仅提供资料上传、删除、处理失败重试和刷新。“已生成”和“音频”当前为空，尚未实现生成内容归档和音频导入。

每账号自动使用一个内部个人存储，历史版本已有多个库的资料统一展示并纳入本人检索，不删除、搬迁原文件或重建历史向量。Agent 自动检索本人可用资料，命中相关内容时引用；无命中或暂时故障时仍可回答普通问题，但必须明确缺少个人资料依据。

支持文字型 PDF（最多 100 页）、DOCX、UTF-8 TXT/Markdown，单文件 20 MB、提取文字 20 万字符。扫描 PDF 提示上传文字型文档，本轮不含 OCR。用于问答的命中片段会发送给当前配置的模型供应商。

## 存储与权限

- 原文件使用现有存储配置：S3 模式为 RustFS 私有桶，独立 private-knowledge/{userId}/ 命名空间；local 模式为公开 profile 目录之外的 knowledge-files 目录。
- MySQL 保存库、文档、片段、任务、问答范围和引用。Qdrant 仅保存向量及归属和版本元数据，默认集合 capp_knowledge_bge_small_zh_v1，与长期记忆分开。
- 复用现有 Embedding 连接及模型配置，更换模型/维度需新建集合并重新索引。每片段最多 120 Unicode codepoints、重叠 20，保守控制当前模型输入。召回最多 6 个主片段并补充相邻片段；Agent 工具补检索总计最多 18 个来源，仍受任务总时限和上下文预算约束。
- 检索先按 user_id/base_id 过滤，回 MySQL 核验库、所有者、文档和 active_revision。模型不能扩大范围，文档指令被视为不可信资料。
- 本人有可用资料时 Agent 自动先检索。无命中或服务暂时故障时普通聊天继续，个人附件问题须说明缺少资料依据；兼容旧客户端显式范围时仍保留严格资料问答和 KNOWLEDGE_UNAVAILABLE。后端生成来源编号，移除未知引用编号；引用有效不等于模型论断必然得到支持，仍需质量验收。
- 回答完成与引用保存共用事务。历史接口动态读取来源；删除或更新后展示“来源已删除或更新”，历史回答正文仍保留。
- 删除先标记失效，后台清理向量、原文件和片段。重新处理先建立新 revision，完整后切换，原版本可在处理期间服务。旧版本数据后续清理需独立容量维护策略。

## 配置与迁移

先执行 migration_capp_knowledge_20261109.sql，只新增 5 张表，可重复执行，不修改既有 AI 表。

| 配置 | 默认 / 说明 |
|---|---|
| app.ai.knowledge.enabled | false；迁移后显式启用 |
| app.ai.knowledge.collection | capp_knowledge_bge_small_zh_v1 |
| app.ai.knowledge.max-bases | 20 |
| app.ai.knowledge.max-documents | 每库 100 |
| app.ai.knowledge.max-user-size-mb | 200 |
| app.ai.memory.vector.embedding-url | 复用现有 Embedding API，如 http://127.0.0.1:8091/v1/embeddings |
| app.ai.memory.vector.qdrant-url | 如 http://127.0.0.1:6333 |

任务使用数据库 lease，进程退出后恢复，临时失败最多自动尝试 5 次，之后可人工重试。长文档逐片段向量化，处理耗时与片段数相关。多实例必须共享私有存储。

部署前由获授权维护者对目标数据库执行本目录的 migration_capp_knowledge_20261109.sql，并检查五张知识库表。配置参考 capp_knowledge_config.example.yml；依赖和配置确认后再启用知识库。数据库和对象存储凭据由部署环境注入，不写入命令行和仓库。Embedding 适配器 tools/memory_embedding_service.py 支持 MEMORY_EMBEDDING_MODEL_PATH，显式本地模型路径搭配 local_files_only 禁止下载。

## 接口

接口统一前缀 /app/ai/knowledge，需要登录，不接受用户身份参数，普通响应为 code/msg/data。

| 方法 | 路径 | 行为 |
|---|---|---|
| GET / POST | /documents | 本人资料统一列表 / multipart file 上传、自动归档、哈希去重 |
| POST | /documents/{id}/retry | 失败重试或重建索引 |
| DELETE | /documents/{id} | 立即失效，后台清理 |
| GET | /documents/{id}/original | 鉴权下载，不暴露存储地址 |

POST /app/ai/sessions/{id}/runs 默认自动取本人可用资料，不需要客户端传 knowledgeBaseIds。旧字段和按库读取、上传接口仅保留兼容历史客户端，新建和删除库的 HTTP 入口已移除。任务创建时保存实际资料范围，重复 requestId 不受后续新上传影响；历史 assistant 消息增加 sources。SSE 协议保持兼容，完成后读取最终回答和引用。

## 验证与回滚

后端验证 KnowledgeServiceTest、AppAiServiceTest、AgentToolsTest、S3FileStorageTest；客户端执行 flutter analyze、flutter test 和本地地址 Debug APK 构建。模拟测试不代替真实 RustFS 上传、Embedding 512 维、Qdrant 点、带证据回答和设备来源展示。

关闭 app.ai.knowledge.enabled 可恢复普通 Agent，保留原文件与数据。回滚数据库前停止 worker、备份并确认删除范围，再执行 rollback_capp_knowledge_20261109.sql。回滚脚本不删除原文件或既有 AI 表，不自动迁移或删除生产数据。
