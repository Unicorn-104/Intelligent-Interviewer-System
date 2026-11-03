# 面试报告自动生成实施计划

> 适用范围：`backend/`（RuoYi 后端）、`c-app/`（求职者端）、`e-app/`（企业端）
> 编写依据：2026-11-03 代码盘点（会议链路、评估表、LLM 客户端、ASR 落库）
> 目标：面试正常结束后自动生成五维评估报告，HR 可直接终审，失败可重试

## 1. 结论

数据采集链路已经完整，**缺的是「生成器」和「状态机」**，不是从零建设。
但直接开工会被下面 4 个问题卡住，必须先定方案再写代码。

## 2. 现状盘点

| 能力 | 现状 | 位置 |
| --- | --- | --- |
| 面试结束 | 已实现，事务内更新 `ses_status=2` | `ConferenceServiceImpl#finishSession` |
| 逐字稿 | 已实现，ASR 按 `dlg_order` 落库 | `t_int_dialogue`（`dlg_role/dlg_content/dlg_order/dlg_type`） |
| 题目与作答 | 已实现 | `t_int_outline`、`t_int_meeting_state` |
| 评估表 | 只有建表、读取、HR 更新，**无任何写入** | `t_int_evaluation`、`InterviewReviewMapper` |
| LLM 客户端 | 已实现，模型配置在 `t_model_provider`，读取已补解密 | `AgentModelClient`、`ScreeningAiEvaluator` |
| 报告状态 | 只有 `ready/generating`，靠「评估行是否存在」判断 | `ConferenceMapper#selectSessionResult`、`buildSessionResult` |
| 报告接口 | 不存在 | PRD 中的 `POST/GET /api/v1/interview/report` 未落地 |
| HR 终审 | 已实现，但**依赖评估行已存在** | `InterviewReviewServiceImpl` |
| 候选人结果页 | 只有状态文案，无报告内容 | `c-app` `conference_screen.dart` |

## 3. 必须先解决的阻塞问题

### P0-1 没有生成器

`t_int_evaluation` 只被读取，Java 侧没有任何 insert。HR 终审页、候选人「已生成」状态、企业端「报告已生成」通知全部依赖一行不存在的数据。

### P0-2 状态机表达不了失败

`buildSessionResult` 把「无评估行」直接映射成 `generating`。模型超时、逐字稿缺失、密钥失效时，前端会永远停在「整理中」，无法区分失败与进行中，也没有重试入口。

### P0-3 没有逐字稿时的兜底

ASR 未开启、断网、全程静音、ASR 密钥失效时，`t_int_dialogue` 可能为空或只有零星几句。直接调模型会产出编造内容，必须显式失败而不是生成「假报告」。

### P0-4 事务与幂等

`finishSession` 是同步事务并在事务内返回结果。生成若同步执行，用户要等模型；若在事务内触发，回滚会留下孤儿任务。重复结束、HR 刷新、定时补偿都可能重复触发，需要 CAS 状态迁移和评估行唯一键。

### P1 级问题

- 触发范围：只对「正常结束」且时长/作答数达阈值的场次生成；异常终止 `abortSession` 不生成。
- 字段边界：`t_int_evaluation` 同时承载 AI 结论与 HR 审核字段，自动写入只能碰 AI 字段，`evl_hr_status` 必须保持默认待审。
- 长文本：45 分钟中文逐字稿约 6000–9000 字，单次塞入会得到泛化评价，需要分段汇总。
- 权限：报告接口必须校验会话归属（候选人本人 / 本企业 HR）。
- 前端：`c-app` 需要新增 `failed` 文案与重试；`e-app` 需要生成中/失败状态。

## 4. 技术方案

### 4.1 触发

1. `finishSession` 成功更新状态后，在事务内发布 `InterviewFinishedEvent(sessionId)`。
2. 监听器使用 `@TransactionalEventListener(phase = AFTER_COMMIT)` + `@Async("threadPoolTaskExecutor")`，异步执行，不阻塞会议结束响应。
3. 补偿：Quartz 每分钟扫描 `ses_status=2` 且 `ses_report_status` 为 `0`、或 `1` 超过 10 分钟的场次，重新投递。只在最近 7 天内扫描。
4. 开关：`app.report.enabled` 默认 `true`，关闭后不生成，状态保持 `0`，可快速回滚。

### 4.2 数据装配

按 `t_int_dialogue` 的 `dlg_order` 排序，剔除 `dlg_type=3` 的系统消息，按 `t_int_outline` 题目边界切片；同时带入简历结构化字段与 JD 摘要。

清洗规则：姓名/电话/邮箱/身份证脱敏；超长按题目分段，每段不超过 `app.report.max-chars-per-chunk`（默认 4000）；保留 `dlg_role` 以区分候选人与 HR。

### 4.3 生成

复用 `AgentModelClient`（模型来自 `t_model_provider`，密钥解密已在 2026-11-03 修复），Prompt 规范沿用 `ScreeningAiEvaluator`：

- system 固定五维定义与评分区间，禁止编造、禁止使用姓名/性别/年龄/婚育/院校名气评分；
- 每条维度结论必须附逐字稿原文引用；
- 只输出 JSON，不输出 Markdown；
- `temperature` 取低值，输出上限固定，沿用信号量限流。

长文本采用 map-reduce：先逐题输出「本题表现 + 证据」，再汇总为整体结论。短面试（单段可容纳）直接单次生成。

输出结构：

```json
{
  "dimensions": {
    "professional":   {"score": 82, "evidence": ["原文片段"]},
    "communication":  {"score": 75, "evidence": ["原文片段"]},
    "problemSolving": {"score": 68, "evidence": ["原文片段"]},
    "cultureFit":     {"score": 70, "evidence": ["原文片段"]},
    "potential":      {"score": 78, "evidence": ["原文片段"]}
  },
  "summary": "总体评述",
  "advantages": ["优势"],
  "risks": ["风险"],
  "gaps": ["能力差距"],
  "recommendation": "建议"
}
```

### 4.4 校验

1. JSON 容错解析（复用 `ScreeningAiEvaluator.decode` 的围栏剥离逻辑）。
2. 每条 `evidence` 必须能在清洗后的逐字稿中找到（空白归一化后包含匹配）；无效证据剔除并计数。
3. 无效证据占比超过 50% → 判定失败，错误码 `EVIDENCE_MISMATCH`。
4. 综合分由后端按固定权重计算，不采用模型自报总分。
5. 维度分缺失按 `0` 处理，不做归一化。

### 4.5 错误码与兜底

| 错误码 | 触发条件 | 处理 |
| --- | --- | --- |
| `INSUFFICIENT_DATA` | 逐字稿少于 200 字或作答数 < 2 | 不调模型，直接失败，提示 HR 人工评估 |
| `MODEL_UNAVAILABLE` | 模型未启用 / 鉴权失败 / 超时 | 失败，可由 Quartz 重试 |
| `EVIDENCE_MISMATCH` | 证据回查失败率 > 50% | 失败，不落库 |
| `INTERNAL_ERROR` | 其他异常 | 失败，记录异常摘要（不含原文） |

失败不生成任何评估行，只更新会话状态与错误码。

### 4.6 状态机

`t_int_session.ses_report_status`：

- `0` 未触发（默认）
- `1` 生成中
- `2` 成功
- `3` 失败

迁移用 CAS 防并发：`update ... set ses_report_status=1 where ses_id=? and ses_report_status in (0,3)`，影响行数为 0 则直接返回。

成功时：插入 `t_int_evaluation` + 更新 `ses_report_status=2`，同一事务。

### 4.7 接口

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/system/conference/session/{id}/result` | 扩展返回 `reportStatus`（`generating/ready/failed`）、`reportError`、`reportReadyAt` |
| GET | `/system/conference/session/{id}/report` | 候选人侧报告摘要（总分、五维、总结、建议），需会话归属校验 |
| GET | `/enterprise/review/{sessionId}` | 复用现有 HR 终审详情，返回完整报告 |
| POST | `/enterprise/review/{sessionId}/report/retry` | HR 手动重新生成，需 `enterprise:review:edit` 权限 |

候选人侧不返回 `risks/gaps` 与逐字稿原文，避免泄露内部评估口径。

### 4.8 前端

- `c-app`：`reportStatus=failed` 时显示「报告生成失败」与刷新按钮；`ready` 时展示摘要页。
- `e-app`：终审页增加生成中/失败状态与「重新生成」按钮；成功后沿用现有详情渲染。
- 企业端系统消息规则「存在评估行且 7 天内创建」保持不变，只在成功路径触发。

## 5. 数据存储位置

结论：**逐字稿和报告都落在 MySQL，不产生独立的报告文件**；录制视频单独存文件。

| 数据 | 存储位置 | 具体字段 | 说明 |
| --- | --- | --- | --- |
| 面试全部对话（逐字稿） | MySQL `t_int_dialogue` | `dlg_session_id`、`dlg_order`、`dlg_role`、`dlg_type`、`dlg_content`、`dlg_intent`、`dlg_created_at` | 一句一行；`dlg_role` 区分候选人/HR/AI；报告生成的唯一原文来源 |
| 题目与作答进度 | MySQL `t_int_outline`、`t_int_meeting_state` | `oln_topic/oln_description/oln_dimension`、`mst_current_question/mst_total_question` | 用于按题切片与完成率 |
| 生成报告 | MySQL `t_int_evaluation` | `evl_overall_score`、`evl_dimension_scores`(JSON)、`evl_summary`、`evl_advantages`、`evl_risks`、`evl_gaps`、`evl_recommendation`、`evl_created_at` | 一场一行，`evl_session_id` 唯一 |
| 维度证据 | `evl_dimension_scores` JSON 内 | `{"professional":{"score":82,"evidence":["原文片段"]}}` | 不单独建证据表，整行读取即可 |
| 报告状态/错误码 | MySQL `t_int_session` | `ses_report_status`、`ses_report_error` | 不写入评估行，失败时评估行不存在 |
| 录制文件 | 服务器上传目录 | `t_int_recording.rcd_url` | 仅归档回放，不参与文本生成 |
| 导出文件（可选） | 服务器上传目录 | `{sessionId}.docx` | 阶段五再做，不新增表字段 |

不存储的内容：模型原始 Prompt、模型原始响应、未通过校验的草稿。只保留校验后的结构化结论与可回查的证据片段，避免原文和敏感信息二次扩散。

逐字稿回放复用现有 `ConferenceMapper.selectCaptions`（按 `dlg_id` 增量分页），不新建表、不新增存储。

## 6. 数据库变更

新增脚本 `backend/doc/migration_interview_report_20261103.sql`：

```sql
alter table t_int_session
  add column ses_report_status tinyint not null default 0
    comment '报告状态：0未触发 1生成中 2成功 3失败',
  add column ses_report_error varchar(64) null comment '失败错误码';

-- 回填历史已有人工/演示评估的场次
update t_int_session s
  set s.ses_report_status = 2
  where exists (select 1 from t_int_evaluation e where e.evl_session_id = s.ses_id);

-- 评估行唯一键，保证幂等（若不存在）
alter table t_int_evaluation
  add unique key uk_evl_session (evl_session_id);
```

> 执行前先确认 `uk_evl_session` 不存在，避免重复添加失败。

## 7. 阶段拆分

按仓库规范，一个子功能一个 commit，统一一个 PR 到 `dev`。

1. **阶段一：状态机与骨架** — 迁移脚本、`ses_report_status` 读写、`buildSessionResult` 扩展、事件发布与 `AFTER_COMMIT` 监听、开关与错误码。
2. **阶段二：生成核心** — 数据装配、分段策略、Prompt、`AgentModelClient` 调用、JSON 解析与证据校验、成功落库。
3. **阶段三：补偿与重试** — Quartz 扫描、HR 重试接口、失败状态展示。
4. **阶段四：客户端** — `c-app` 状态与摘要页；`e-app` 生成状态与重试入口。
5. **阶段五（可选）：导出** — Apache POI 生成 `.docx`；PDF 另行评估。

## 8. 验收标准

1. 正常结束一场有字幕的面试：10 秒内 `reportStatus=ready`，`t_int_evaluation` 有且仅有一行。
2. 重复调用 `/finish`：不重复生成，状态仍为 `ready`。
3. 关闭 ASR 或字幕为空：`reportStatus=failed`，错误码 `INSUFFICIENT_DATA`，不产生评估行。
4. 模型密钥错误：`failed` + `MODEL_UNAVAILABLE`，HR 重试后成功。
5. HR 终审页能读到五维分数、总结、优势、风险，`evl_hr_status` 仍为待审。
6. 候选人结果页只看到总分、五维、总结与建议。
7. 模型返回的证据片段可在逐字稿中检索到。
8. `mvn -pl ruoyi-system,ruoyi-admin -am compile` 通过；改动客户端时 `flutter analyze` 通过。

## 9. 风险与回滚

| 风险 | 应对 |
| --- | --- |
| 模型编造结论 | 证据回查 + 无效证据率阈值 + 人工终审 |
| 生成成本不可控 | 每题分段 + 输出上限 + 并发信号量 + 单场只生成一次 |
| 报告泄露敏感信息 | 候选人侧裁剪字段，日志禁止输出逐字稿与 Prompt |
| 触发风暴 | Quartz 只扫 7 天内、CAS 状态迁移、失败最多重试 3 次 |
| 上线异常 | 关闭 `app.report.enabled`，状态保持 `0`，前端回到「整理中」 |

回滚步骤：关闭开关 → 停止 Quartz 任务 → 保留新增列（不影响旧逻辑）→ 如需删除，单独执行逆向 SQL。

## 10. 明确不做

- 不做语音情绪、语速、微表情分析。
- 不做录制视频的多模态评分。
- 不做 RAG 评分卡（首版使用固定五维口径）。
- 不自动推进 HR 终审结论，只提供 AI 初评。
