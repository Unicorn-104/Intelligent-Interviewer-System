# 历史简历 PDF 迁移方案 B 最终生产执行计划（最终门禁修复版）

> 本文件仅为人工审核与未来按步骤执行的依据。本执行包全部内容只生成、不执行：未连库、未连 RustFS、未复制对象、未执行 SQL、未部署。

## 〇、关键阻断声明（务必先读）

关于原子条件写能力，统一口径如下，任何地方不得表述为已验证：

- **当前尚未验证。** 仓库内无 RustFS 版本、无条件写入（If-None-Match）的代码或文档证据；现有 `S3FileStorage.store()` 仅用普通 putObject。
- **计划采用** `put-object --if-none-match "*"`（目标已存在时服务端应返回 412、不覆盖）。
- **必须先运行 `test_conditional_write.ps1` 对当前实例做非生产探测**，证据由该脚本真实测试产生，不能仅靠修改 JSON 字段宣称成功。
- 证据模板 `conditional_write_evidence.example.json` 所有待证字段默认 `NOT_VERIFIED`，直接使用无法通过门禁。
- 证据须包含并通过校验：endpoint、bucket、region、rustfsVersion、probeKey、firstPutStatus、secondPutStatus、firstObjectSha256、finalObjectSha256、verifiedAt、verifiedBy。
- 版本无法自动获取，证据固定 `versionVerification=MANUAL_VERIFICATION`：rustfsVersion 须人工从服务器核实并作为参数传入，禁止只判断非空。
- **实测成功前禁止正式复制。** 证据不通过，copy_objects 即使带 `-Execute` 也直接 throw。

## 一、背景与目标

企业简历快照五表已建成，结构化简历与 AI 分析已完成回填并通过核验。当前阶段仅处理历史投递的原始 PDF：把可确认的 S3 源对象复制到企业独立命名空间并回写引用；无法确认者保持路径 NULL，不阻塞结构化简历。

核心原则：**结构化简历 10/10、AI 分析 16/16 已是既成事实且不受 PDF 结果影响；PDF 采用尽力恢复。**

## 二、数据来源与证据等级

| 证据 | 来源 | 等级 |
|---|---|---|
| 源对象完整读取、大小、SHA-256 | source_pdf_dry_run_result.csv（真实 GetObject） | 已验证 |
| 人工复核清单 | source_pdf_manual_review.csv | 0 条异常 |
| 空路径登记 | no_pdf_reference.csv | 已登记 |
| 条件写能力、目标复制、目标哈希、回写 | 尚未执行/未验证 | 未验证 |

## 三、10 条记录最终分类

| 分类 | appId | 数量 | 本轮动作 |
|---|---|---|---|
| READY_TO_COPY | 70、71、78 | 3 | 源已验证，待条件写实测后复制 |
| CANDIDATE_PENDING | 47、48 | 2 | HR 门禁，阻断 |
| SOURCE_MISSING | 49 | 1 | 保持 NULL |
| SIZE_NOT_VERIFIED | 79 | 1 | 大小冲突，阻断 |
| NO_SOURCE_REFERENCE | 45、46、52 | 3 | 保持 NULL |

## 四、三条可复制记录（目标 key 已固定）

> **companyId 修正（2026-11-11，真实数据库核实，最高优先级）**
> - 真实查询确认 app70/71/78 的 `ers_company_id` 与岗位所属 `pos_company_id` 均为 **1**（app70 ers_id=4/position158、app71 ers_id=158/position17、app78 ers_id=10/position164）。
> - 此前包内 companyId=152/151 为错误值，目标 key 已全部修正为 `/1/` 段；UUID、大小、SHA 保持不变。
> - 已复制到旧路径 `enterprise-application-resume/152/70/…`、`…/151/71/…`、`…/151/78/…` 的三个对象**保留不删、不覆盖**，其最终处置另行授权。
> - 新 `/1/` 目标与此前已批准目标不同，**必须重新明确批准后才能执行复制**；批准前保持阻断。

目标 key 依据 `EnterpriseResumeStorage.store()` 第 60-61 行规则 `enterprise-application-resume/{companyId}/{appId}/{32hex}.pdf`，UUID 已在本包固定，重试不重新随机。

| appId | companyId | 源大小 | 源 SHA-256 | 固定目标 key |
|---|---|---|---|---|
| 70 | 1 | 309407 | d4da83f8…30022 | enterprise-application-resume/1/70/f7265a2484e44f1bb8f28eb898e517d3.pdf |
| 71 | 1 | 163683 | e42eea0c…50bda | enterprise-application-resume/1/71/41b70c7ec33e42be9bfbe584645935a0.pdf |
| 78 | 1 | 163683 | e42eea0c…50bda | enterprise-application-resume/1/78/18a5a19616884d64a492decd1f86a4e8.pdf |

71 与 78 共用同一源对象（源只读一次），但分别生成独立目标，不合并 appId。ers_file_path 写入形态为 `s3:recruit-files/<目标key>`（依据 S3FileStorage.reference() 第 38-43 行）。

## 五、条件写探测脚本 test_conditional_write.ps1

- 默认 Dry Run，不写任何对象；`-Execute` 才执行非生产探测。
- 探测 key 固定在独立前缀 `conditional-write-probe/`，禁止使用正式业务 key。
- 第一次 `put-object --if-none-match "*"` 必须成功（firstPutStatus=HTTP_200_OK）。
- 第二次对同一 key 条件写必须为 `HTTP_412_PRECONDITION_FAILED`；**409 单独分类，不得判定成功**。
- GetObject 读取并计算真实 SHA-256，firstObjectSha256 与 finalObjectSha256 必须一致，证明第二次请求未覆盖。
- 全部满足才生成证据 JSON；rustfsVersion 由人工传入并保持 MANUAL_VERIFICATION。
- 探测对象清理单独授权（`-CleanupProbe`，校验前缀），默认不删除，失败时不误删其他对象。
- 凭据在 finally 恢复，不写入文件或日志。

## 六、复制脚本安全机制（最终版）

- 证据全字段校验：endpoint/bucket/region 完全一致，版本为真实值且 MANUAL_VERIFICATION，probeKey 前缀正确，firstPutStatus=HTTP_200_OK，secondPutStatus=412，双 SHA 为 64hex 且一致，verifiedAt/verifiedBy 完整，result=VERIFIED。
- 错误分类：捕获 AWS CLI 真实输出，区分 403/404/412/409/5xx/网络，真实错误码与摘要写入 Error，不记录密钥。
- HEAD 仅明确 404 判不存在；403/5xx/网络/未知一律停止。
- 源复核：复制前重新 GetObject 并比对固定大小与 SHA。
- 目标已存在：完整读取核验，一致幂等跳过，不一致停止不覆盖。
- 一个 appId 失败后，后续未执行记录标 `NOT_ATTEMPTED`。
- 报告独占创建不覆盖，在外层 finally 保存部分执行结果；凭据 finally 恢复。

## 七、四条 NOT_FOUND 记录处置

Dry Run 对 47/48/49/79 的 S3 GetObject 均返回明确 404。它们是裸 `private-resume` 路径，运行时走本地磁盘分支（`ResumePdfStorage.readResource()` 第 74 行），不通过 S3，故桶内 404 符合逻辑，**不能据此判定文件永久丢失**。

- 47/48：见第八节 HR 门禁。
- 49：服务器本地未找到，保持正式路径 NULL，标记 SOURCE_MISSING。
- 79：见第九节大小冲突。

## 八、appId 47/48 的 HR 人工确认门禁

- HR 人工确认是写入正式 ers_file_path 的唯一放行条件。
- 仅大小一致、SHA 计算成功或内容相似，均不能单独证明历史原件身份。
- 身份未确认前：不自动回写、不通过企业 PDF 下载接口暴露、候选文件仅可进入隔离暂存区。
- 复制完整性验证与原件身份验证分别记录。

## 九、appId 79 的 SIZE_NOT_VERIFIED 门禁

历史存在两个冲突大小 297873 与 2978739，且 S3 返回 404。未获得真实字节证据前，不得选择任一数值、不得复制、不得回写，保持 SIZE_NOT_VERIFIED。

## 十、三条无 PDF 引用记录

appId 45、46、52 路径为空，保持 NULL，不寻找、不生成替代文件；结构化简历正常可读。注意 snapshotId=7 与 app71 工作项编号撞号，所有数据库操作一律以 app_id（必要时加 company_id）定位，禁止仅凭 snapshotId。

## 十一、数据库回写与人工提交

database_update.sql 与 rollback.sql **均不含可执行 COMMIT**；本轮仅将路径 company 段与定位条件同步为 companyId=1，未改变守卫机制与更新范围。

- 独立连接：使用专用数据库会话，避免 START TRANSACTION 影响其他未提交事务。
- 逐条执行：手动逐条运行，每条 UPDATE 后立即看 ROW_COUNT，禁止整文件一次执行后忽略中间结果。
- 严格守卫：UPDATE 要求 `ers_file_path IS NULL AND ers_file_size IS NULL`，空字符串不被当作 NULL；迁移前原始值（均 NULL）与 rollback 还原值一致。
- 仅更新 ers_file_path、ers_file_size，不碰身份字段、六态、AI、评分、人才库。
- 回滚以新路径 + 本次大小双前置，任一变化即停止，不覆盖其他合法更新。

## 十二、Schema 证据（只读）

- 文件：`backend/doc/migration/enterprise_resume_snapshot/02_schema.sql`
- 第 275 行：`UNIQUE KEY uk_ers_app (ers_app_id)`，第 274 行主键 `PRIMARY KEY (ers_id)`。
- 结论：ers_app_id 受唯一约束，**每个 app_id 在主表中唯一**，以 app_id 定位天然最多命中 1 行，并以 company_id 辅助校验。

## 十三、风险分析

| 风险 | 缓解 |
|---|---|
| 条件写能力未验证导致误覆盖 | 默认阻断，证据须真实探测且全字段通过，不开放 -Execute |
| 仅改 JSON 伪造证据 | 字段默认 NOT_VERIFIED，412/双 SHA/前缀/版本全部校验 |
| 部分成功后异常丢失报告 | 报告在 finally 独占保存，含失败与 NOT_ATTEMPTED |
| PDF 下载接口不独立校验身份 | 依赖路径保持 NULL 与 HR 门禁 |
| 误把 404 当永久丢失、409 当成功 | 错误码严格分类，409 不算成功 |
| 覆盖迁移后业务更新 | UPDATE/回滚均带严格双字段守卫 |

## 十四、回滚方案

- 数据库：执行 rollback.sql，以新路径 + 大小双前置还原为迁移前 NULL，人工 COMMIT。
- 对象：数据库回滚不自动删除目标对象；对象清理须另行授权，且不得删除 C-App 源。

## 十五、验收标准

- 条件写能力经 test_conditional_write 真实探测并留档；三个目标大小与 SHA-256 与源完全一致（不用 ETag）。
- 仅 70/71/78 回写，其余 7 条字段保持不变；身份核验字段未被擅自设置。
- 企业 PDF 下载成功；路径为空/对象缺失有明确提示且结构化简历仍可读。
- 六态状态机、AI 分析、评分、人才库功能不受影响。
