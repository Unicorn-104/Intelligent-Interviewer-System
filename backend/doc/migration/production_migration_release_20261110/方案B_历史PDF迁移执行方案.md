# 方案 B：历史简历 PDF 迁移执行方案（结构化优先，PDF 尽力恢复）

> 适用项目：Intelligent-Interviewer-System（分支 feature/eapp-core-services-zx）
> 目标库：recruit_agent（数据库结构迁移 02/DR3/03/04 已由用户手动完成）
> 交付日期：2026-11-11
> 本文性质：**只读审查 + 新增说明文档**。不连库、不执行 SQL、不写 RustFS、不复制/移动/删除文件、不部署、不 commit。
> 本文不覆盖任何已验收 SQL 与历史审计报告，仅作为方案 B 的独立执行与验收依据。

---

## 一、核心原则与验收口径

方案 B：**优先保证结构化简历独立，原始 PDF 尽力恢复；找不到的 PDF 标记不可用，不阻塞结构化迁移与部署。**

| 验收维度 | 目标 | 性质 |
|---|---|---|
| 结构化简历 | 10/10 投递快照可读 | 核心，必须满足 |
| AI 分析 | 16/16 保留（15 llm + 1 manual），原始 JSON 不覆盖 | 核心，必须满足 |
| 原始 PDF | 尽力恢复；可恢复者复制并回写，不可恢复者标记不可用 | 非阻断 |
| 隔离底线 | 任何 PDF 缺失都不得让结构化读取回退到 C-App 当前简历 | 强制 |

PDF 与结构化简历**独立验收**：PDF 不可用时，结构化简历仍正常展示；PDF 恢复结果不影响放行结构化功能与后端部署。

---

## 二、术语映射（用户口径 → 代码真实常量）

经全 backend 检索，用户使用的三个状态术语中，**代码内不存在 `CANDIDATE_UNVERIFIED`、`NO_SOURCE_REFERENCE` 两个字面量**（0 匹配），需映射到真实常量，避免按不存在的状态写程序或 SQL。

| 用户口径 | 代码真实定义 | 含义与本场景判定 |
|---|---|---|
| CANDIDATE_UNVERIFIED | 快照状态 `REBUILT_UNVERIFIED`（EntResumeSnapshot 第23行） | 现存数据重建、原始版本未核实；当前 10 条快照均为此状态 |
| NO_SOURCE_REFERENCE | `ers_file_path IS NULL`（路径为空）；PDF 验证分类 `SOURCE_MISSING_NO_FILE` | 原本无 PDF 引用；结构化快照仍正常，不寻找、不生成 |
| SOURCE_MISSING | 迁移 Outcome `SOURCE_MISSING`（PDF 读不到）；另有快照状态 `MISSING_SOURCE`（结构化源缺失） | 本场景主记录都在，**无 `MISSING_SOURCE`**；仅 PDF 对象读不到时用 Outcome `SOURCE_MISSING` |

> 关键区分：`MISSING_SOURCE`（快照状态）指结构化来源彻底缺失，本场景不出现；`SOURCE_MISSING`（迁移 Outcome）指 PDF 文件读不到，二者不可混用。

---

## 三、10 条投递 PDF 分类 manifest

以 **app_id 为唯一锚点**（`uk_ers_app` 唯一约束，无歧义）。用户清单中"snapshotId"为来源清单序号，其中两个"7"数字撞号（app_id=71 有引用 / app_id=46 无引用），**以 app_id 与源引用为准**，实际 `ers_id` 以数据库为准。

| app_id | 清单序号 | company_id | source_resume_id | 源引用（简化） | 预期大小 | 方案 B 分类 | 处置 |
|---|---|---|---|---|---|---|---|
| 45 | 6 | 以库为准 | 16 | 空 | — | NO_SOURCE_REFERENCE | 不复制，保持 NULL |
| 46 | 7（撞号） | 以库为准 | 16 | 空 | — | NO_SOURCE_REFERENCE | 不复制，保持 NULL |
| 47 | 2 | 135 | 35 | private-resume/.../d98c....pdf | 696287 | CANDIDATE_PENDING | 候选核验通过后复制 |
| 48 | 1 | 135 | 35 | 同 d98c（与 47 同对象） | 696287 | CANDIDATE_PENDING | 候选核验通过后复制 |
| 49 | 3 | 138 | 38 | private-resume/.../d737....pdf | 360830 | SOURCE_MISSING | 未找到，不复制，保持 NULL |
| 52 | 8 | 以库为准 | 16 | 空 | — | NO_SOURCE_REFERENCE | 不复制，保持 NULL |
| 70 | 4 | 152 | 52 | s3 .../226e....pdf | 309407 | S3_READY | HEAD 已验证（存在+大小），可进入读取，未做完整核验 |
| 71 | 7 | 151 | 51 | s3 .../1094....pdf | 163683 | S3_READY | HEAD 已验证（存在+大小），可进入读取，未做完整核验 |
| 78 | 10 | 151 | 51 | 同 1094（与 71 同对象） | 163683 | S3_READY | HEAD 已验证（存在+大小），可进入读取，未做完整核验 |
| 79 | 5 | 150 | 50 | private-resume/.../a237....pdf | SIZE_NOT_VERIFIED（冲突 2978739 / 297873，见第三节附） | SOURCE_MISSING | 源未找到且大小未确认，禁止复制，保持 NULL |

分类汇总：S3_READY 3 条（2 个源对象）；CANDIDATE_PENDING 2 条（1 个候选对象）；SOURCE_MISSING 2 条；NO_SOURCE_REFERENCE 3 条。

### 附：app_id=79 文件大小冲突核验（SIZE_NOT_VERIFIED）

仓库内存在两个相互冲突、且都来自用户提供材料的大小值，无法在不连库、不读真实对象的情况下裁决：

| 数值 | 出处 | 形态 |
|---|---|---|
| 2978739（7 位） | Dry Run 任务的无分隔紧凑 PDF 清单；据此录入 SourcePdfDryRun.java 第53行；原方案 B 文档 | 紧凑拼接，数字边界不清晰 |
| 297873（6 位） | 方案 B 任务资产清单，原文"applicationId=79……预期 297873 bytes，当前服务器搜索未找到" | 带分隔与 bytes 单位，表述明确 |

核验依据与判定：
- 其余 6 条 PDF 大小均为 6 位且两来源一致；仅 app79 出现 7 位/6 位分歧，疑似录入时多打/漏打一位，但**模式相似不构成证据**，不据此覆盖。
- 当前无法连接生产库、app79 源对象又未找到（无实际字节可比对），不满足确认条件。
- 据用户规则判定 **SIZE_NOT_VERIFIED**：在取得真实字节（连库核对 rbs_file_size 或找到对象后 HeadObject/实际读取）前，**禁止进入 app79 的正式复制与回写**；叠加其 SOURCE_MISSING 状态，保持 NULL。
- 解除条件：用户在可连库或找到对象的环境，用真实字节大小确认唯一值并更新本结论；若两值均无法证实，继续保持不可用。

### 同对象多 appId 的独立性（已核实）

- 复制目标 key 由 `EnterpriseResumeStorage.store`（第60–61行）生成：`enterprise-application-resume/{companyId}/{appId}/{随机32hex}.pdf`，**含 appId 与随机 UUID**。
- 同一源对象被多条投递引用时，每条 appId 各自生成独立目标，CREATE_NEW 不覆盖、不串用：
  - 1094 源对象 → app71、app78 各产生一个独立企业对象；
  - d98c 候选对象 → app47、app48 各产生一个独立企业对象。
- 两组重复各保留两条独立 appId 工作项，不去重。

---

## 四、两个 S3 源对象的迁移步骤（3 条投递）

源对象在 `recruit-files` 桶。**HEAD 验证只证明对象存在且返回大小，不等同完整迁移验收。** 当前验证状态分层如下：

| 验证项 | 状态 | 证据/说明 |
|---|---|---|
| 对象存在性（HeadObject） | 已验证 | 两对象 AWS CLI exit code=0 |
| HEAD 返回大小 | 已验证 | app70=309407；app71/78=163683，与预期一致 |
| GetObject 完整读取 | 未执行 | 尚未拉取完整字节 |
| 源 SHA-256 计算 | 未执行 | 须基于完整读取字节计算 |
| 目标对象复制 | 未执行 | 尚未写入企业命名空间 |
| 目标 SHA-256 核验 | 未执行 | 复制后读回比对 |
| 数据库回写 SQL | 未生成/未执行 | 见第七节，仅生成不执行 |

结论：app70、71、78 共 3 条**具备源对象读取条件**（HEAD 已通过），但完整迁移与回写尚未发生。以下为受控执行步骤，**本轮不执行**，且不启动完整 Spring 容器、不连库。

### 4.1 执行环境要求
- 在能访问 RustFS（隧道 127.0.0.1:19000）的环境，使用独立装配 S3Client 的受控程序（复用现有 `HistoricalResumePdfMigrator` / `EnterpriseResumeStorage` 纯逻辑，不初始化 Druid/MySQL/Redis/Quartz）。
- 源只读；目标 CREATE_NEW，禁止覆盖；凭据不入库、不输出。

### 4.2 复制与核验步骤
1. 按源引用 GetObject 读取字节，校验实际大小 = 预期大小（见下表）。
2. 对实际字节计算 SHA-256（`sha256Hex`，MessageDigest SHA-256，64hex）。
3. 调 `EnterpriseResumeStorage.store(companyId, appId, bytes, originalName)` 写入企业命名空间，记录返回的目标 reference、size。
4. 立即读回目标对象，重算 SHA-256，与源哈希比对：一致则复制一致性通过（结果仍为"未核实原件"，非原件证据）；不一致则判 VERIFY_FAILED，清理本次新建对象并重试。
5. 逐条记录：app_id、源/目标 reference、源/目标大小、源/目标 SHA-256、一致性结果。

| 源对象 | 关联 app_id | 预期大小 | 目标数量 |
|---|---|---|---|
| private-resume/104/2026/11/04/226e....pdf | 70 | 309407 | 1 |
| private-resume/2/2026/11/03/1094....pdf | 71、78 | 163683 | 2（各 1） |

### 4.3 异常判定（沿用既有规则）
- 仅明确 404/NoSuchKey 才判不存在；403、超时、5xx、大小不符一律 MANUAL_REVIEW，不把读取失败等同文件丢失。
- 所有对象均远小于 10MB 上限（最大 0.31MB），不触发大小限制。

---

## 五、候选 PDF 的内容核验与正式回写限制（app 47 / 48）

候选文件：`/home/ruoyi/uploadPath/upload/2026/10/28/我的简历_20261028110403A001.pdf`，大小 696287 与预期一致。**大小一致只满足"文件完整性"线索，不证明历史原件身份。**

### 5.1 正式回写的硬性前置（强制）
1. **只有 HR 人工确认候选文件确实属于对应历史投递，才允许写入正式 `ers_file_path`**；这是回写的唯一放行条件。
2. 仅大小一致、SHA-256 计算成功、或内容/文本相似，**均不能单独证明历史原件身份**，不得据此回写。
3. 身份未确认的候选文件，**不得通过正式企业投递 PDF 下载接口（`/resume/pdf`）暴露**；该接口只服务已回写的正式对象。
4. 如需临时保留候选文件，**必须与正式企业快照存储路径隔离**：放在独立暂存区/临时目录，不得写入 `enterprise-application-resume/` 正式命名空间，避免被误当正式原件。
5. **人工确认前不得回写 app 47、48 的正式 PDF 路径**，对应 `ers_file_path` 保持 NULL。
6. **文件复制完整性验证与历史原件身份验证分别记录**，不得用前者结论代替后者。

### 5.2 两类验证的分离（独立台账）
| 验证类型 | 回答的问题 | 通过证据 | 不代表 |
|---|---|---|---|
| 复制完整性验证 | 字节是否被完整、一致地保存 | 实际大小匹配 + 源/目标 SHA-256 一致 | 不代表是历史原件 |
| 原件身份验证 | 该文件是否为投递时的那份原件 | HR 人工确认（结合内容/时间等佐证） | 与字节完整性相互独立 |

### 5.3 可累积的佐证（不自动定真）
1. 计算候选文件真实 SHA-256 并留存（无独立历史参考哈希，无法靠哈希自证）。
2. 解析 PDF 文本/元数据，与结构化快照（source_resume_id=35）的教育/工作/项目/技能比对内容一致性。
3. 核对 PDF 内时间信息、文件名时间戳（20261028110403）与投递时间（2026-10-27/28）是否吻合。
4. 以上仅作为 HR 人工确认的支撑材料，不自动置真。

### 5.4 判定与处置
- **HR 确认是原件**：才从隔离暂存区复制到正式企业命名空间并回写；状态升级（MANUAL_VERIFIED）仍凭此证据单独决定（见第七节）。
- **身份无法确认**：保留在隔离暂存区，不回写正式路径、不暴露到下载接口，`version_verified` 保持 NULL，不冒充原件。
- 任一步异常或内容不符，转 MANUAL_REVIEW，不写入正式存储。

---

## 六、两类不可恢复记录的处理方案

### 6.1 两个 SOURCE_MISSING（app 49 / 79）
- 服务器搜索未找到对应源对象，且无候选；按方案 B 不复制、不生成替代文件，`ers_file_path/name/size` 保持 NULL。
- app79 另存在大小冲突（2978739 / 297873），已判 SIZE_NOT_VERIFIED（见第三节附），即使后续找到对象，也须先用真实字节确认唯一大小，否则不得复制。
- 企业端结构化简历正常展示；PDF 入口由后端返回"原始简历文件缺失"类提示（见第八节）。
- 后续若在其他位置发现对象，按第五节候选核验（含人工确认）流程补办，不影响当前部署。

### 6.2 三个 NO_SOURCE_REFERENCE（app 45 / 46 / 52）
- 原始 PDF 路径本就为空，业务上不寻找、不生成任何替代文件，保持 NULL。
- 不传入迁移程序（清单解析对空 sourceRef 会 fail-fast，故空路径在生成清单时即归入人工台账，不进入迁移工作清单）。
- 企业端结构化简历正常；PDF 入口返回"原始 PDF 不可用"提示。

---

## 七、数据库路径更新 SQL（仅生成，不执行）

> 目标 key 含随机 UUID，复制前无法预知。以下为**标准模板**：`<TARGET_REF>`、`<TARGET_SHA256>`、`<TARGET_SIZE>` 必须由受控复制程序输出的真实值替换，禁止手工编造。
> 全部语句默认以块注释包裹，**本文不执行、不自动放开**；沿用现有工具的 hex 编码（`_utf8mb4 X'...'`）与多重守卫，定位以 `ers_app_id` 为准，规避 ers_id 撞号。

### 7.1 文件事实回写（仅对成功复制并核验通过的记录：预期 app 70/71/78，及确认后的 47/48）

```sql
/*
-- 示例：app_id=70（其余 app 替换对应 app_id 与真实目标值；预期影响 1 行）
UPDATE t_ent_resume_snapshot
SET ers_file_path = _utf8mb4 X'<TARGET_REF 的 UTF-8 hex>',
    ers_file_name = _utf8mb4 X'<原始文件名 的 UTF-8 hex>',
    ers_file_size = <TARGET_SIZE>,
    ers_content_hash = _utf8mb4 X'<TARGET_SHA256 的 hex>'  -- 文件字节哈希，仅证明文件完整性，不代表原件
WHERE ers_app_id = 70
  AND ers_snapshot_status = 'REBUILT_UNVERIFIED'  -- 原状态守卫
  AND ers_version_verified IS NULL                -- 不覆盖已核实快照
  AND ers_file_path IS NULL;                      -- 幂等：已回写不再改动
*/
```

- 每条放开后核对影响行数 = 1，不符即停止排查。
- app 47/48 仅在 HR 人工确认原件身份、并从隔离暂存区正式复制后才生成回写；身份未确认的候选**不产生任何 UPDATE**，保持 NULL。
- 不复制的记录（app 49/79、45/46/52）**不生成任何 UPDATE**，保持 NULL；app79 在大小确认前同样禁止回写。

### 7.2 状态升级（独立步骤，需人工原件证据，本轮不放开）

```sql
/*
-- 仅在取得可靠原件证据（如第五节人工确认）后，逐条放开；预期影响 1 行
UPDATE t_ent_resume_snapshot
SET ers_snapshot_status = 'COMPLETE',
    ers_version_verified = 'MANUAL_VERIFIED'
WHERE ers_app_id = <APP_ID>
  AND ers_snapshot_status = 'REBUILT_UNVERIFIED'
  AND ers_version_verified IS NULL
  AND ers_file_path IS NOT NULL;  -- 必须已完成文件事实回写
*/
```

> 复制一致性/文件完整性通过 ≠ 原件已核实。无可靠证据前一律保持 `REBUILT_UNVERIFIED`，不自动升级 COMPLETE。
> 本文 SQL 与现有 `writeStatusUpdateSql`（HistoricalResumeMigrationConsole 第364–416行）语义一致，仅改为以 app_id 锚定并以模板呈现，不改动该工具源码。

---

## 八、后端接口对缺失 PDF 的行为（已核实，无代码改动）

投递级接口（ApplicationResumeController）：
- `GET /enterprise/applications/{applicationId}/resume`：结构化快照，**不依赖 PDF**。
- `GET /enterprise/applications/{applicationId}/resume/pdf`：企业独立 PDF。

服务层 `EntResumeSnapshotService`：
- `getApplicationResumeView`（第148–158行）：仅查快照与四子表，PDF 有无不影响结构化返回。
- `getApplicationResumePdf`（第166–195行）：
  - `filePath` 为空 → 业务异常"该投递原始 PDF 不可用"；
  - `enterpriseStorage.read` 抛 404 → 业务异常"原始简历文件缺失"；
  - 其他读取异常 → 通用"暂时无法读取"，不回退 C-App、不读 C-App 当前 PDF。
- `requireOwnership`（第198–210行）：校验快照 companyId = 当前登录企业，跨企业/跨岗位越权拒绝。

| 情况 | 预期行为 |
|---|---|
| 路径存在且对象存在 | 正常下载企业独立 PDF |
| 路径为空 | 提示原始 PDF 不可用，结构化仍可读 |
| 路径存在但对象不存在 | 提示文件缺失，不回退 C-App |
| C-App 简历软删除 | 不影响企业快照结构化与 PDF（不依赖 rbs_status） |
| 快照不存在 | SNAPSHOT_NOT_AVAILABLE，不回退当前简历 |
| 无企业访问权限 | 拒绝访问 |

### 8.1 PDF 下载接口安全边界（风险记录，本轮不改代码）

逐行核对 `getApplicationResumePdf`（第166–195行）、`ApplicationResumeController`、`EnterpriseResumeStorage.read`（第82–94行），接口对三个字段的实际校验情况：

| 字段 | 接口是否主动校验 | 实际行为 |
|---|---|---|
| ers_file_path | 是 | 第175行：为空/空白直接抛"原始 PDF 不可用" |
| ers_snapshot_status | **否** | 读取链路不判断快照状态，COMPLETE/REBUILT_UNVERIFIED 均不拦截 |
| ers_version_verified | **否** | 不判断原件核实证据，version_verified 为 NULL 也不拦截 |

- 关键风险：**若未核实历史原件身份的 PDF 路径被提前写入 `ers_file_path`（且对象真实存在），接口会照常读取并返回该文件**，不会因状态为 REBUILT_UNVERIFIED 或 version_verified 为 NULL 而拦截。
- `EnterpriseResumeStorage.read` 仅校验引用形态与对象是否存在，`ApplicationResumeController` 直接透传，二者也不独立验证原件身份。
- 因此当前安全门禁**依赖两道流程控制，而非接口自校验**：
  1. HR 人工确认原件身份前，正式 `ers_file_path` 保持 NULL（接口对空路径会拒绝）；
  2. 迁移前的 HR 人工确认与隔离暂存流程（见第五节）。
- 结论（如实记录）：**接口本身不独立验证历史原件身份；保护未确认候选不被暴露，靠"路径保持 NULL + 人工确认"门禁。** 本项仅记录风险，不修改业务代码。

---

## 九、方案 B 最终执行顺序（总清单）

1. **确认数据库基线**：04_verify 已通过，10 快照均 REBUILT_UNVERIFIED、PDF 列 NULL；16 AI 完整。
2. **受控复制 S3_READY（app 70/71/78）**：按第四节，读源→大小/哈希核验→写企业命名空间→读回比对，记录真实目标 reference/size/sha256。
3. **候选核验（app 47/48）**：按第五节，身份确认后才复制；无法确认则不冒充、不升级。
4. **登记不可恢复项**：app 49/79（SOURCE_MISSING）、app 45/46/52（NO_SOURCE_REFERENCE）保持 NULL，列入人工台账；app79 大小未确认前叠加 SIZE_NOT_VERIFIED，禁止复制。
5. **生成并人工审核回写 SQL**：用第 2/3 步真实值替换第七节模板占位符，逐条放开文件事实回写，核对影响行数=1；状态升级凭证据单独决定。
6. **部署前检查**：按第十节。
7. **后端部署（用户手动）**：参照《后端部署及功能验收清单.md》。
8. **部署后回归**：按第十一节。
9. 全程不删除/覆盖任何源对象与 C-App 数据；异常转 MANUAL_REVIEW。

---

## 十、正式部署前检查清单

| 编号 | 检查项 | 预期 |
|---|---|---|
| P1 | 数据库正向迁移 01/02/DR3/03/04 已通过 | 04 无硬性异常 |
| P2 | 结构化快照 10/10 可读、AI 16/16 完整 | 计数与来源正确 |
| P3 | 已复制对象读回哈希与源一致 | 复制一致性通过 |
| P4 | 回写 SQL 占位符已用真实值替换、影响行数=1 | 无手工编造值 |
| P5 | 未恢复项已登记、保持 NULL | 无伪造文件/哈希 |
| P5a | app79 大小已用真实字节确认唯一值 | 未确认前标 SIZE_NOT_VERIFIED，禁止复制/回写 |
| P5b | app47/48 已取得 HR 原件身份确认，候选与正式路径隔离 | 未确认不回写、不暴露到下载接口 |
| P6 | 迁移开关安全默认 | `historical-resume.enabled=false`、`dry-run=true` |
| P7 | 存储配置（endpoint/bucket/私有/凭据注入）正确 | 无明文密钥入库 |
| P8 | 新 JAR 已做隔离环境启动冒烟 | 无 Bean 装配失败 |
| P9 | 禁止先部署新后端再建表（表已存在，满足） | 顺序正确 |
| P10 | 受保护文件未改动（gradle.properties、ExamMonitorServiceImpl） | 保持原样 |

---

## 十一、部署后功能回归清单

| 编号 | 回归点 | 预期 |
|---|---|---|
| R1 | 岗位候选人列表/候选人 Tab | 数据来自投递快照 |
| R2 | 候选人结构化简历（含 PDF 缺失投递） | 教育/工作/项目/技能正常，缺 PDF 不阻断 |
| R3 | PDF 下载（已恢复投递） | 打开企业独立副本，非 C-App 路径 |
| R4 | PDF 缺失/空路径投递 | 明确中文提示，不崩溃、不回退 |
| R5 | 五入口（岗位详情/候选人 Tab/通知/聊天/首页面试日程） | 均走投递级快照 |
| R6 | 人才库（无岗位上下文） | 保留 talId 当前简历逻辑 |
| R7 | AI 分析（15 llm+1 manual）、人工评分 | 16 条不变，追加不覆盖 |
| R8 | 六态状态机（0–5） | 转换与终态保护不受影响 |
| R9 | 跨企业越权访问 | 拒绝 |
| R10 | C-App 修改/软删简历 | 企业快照结构化与已存 PDF 不变 |

---

## 十二、回滚方案及缺失文件影响说明

### 12.1 回滚（均由用户手动执行）
- **应用回滚**：用备份的旧 JAR + 原配置替换重启，确认服务恢复；与数据库回滚为两个独立动作，按故障点选择，不盲目同时操作。
- **数据库回滚**：需要时使用 `05_rollback.sql`（归档式，RENAME 保留全部行，不删除历史分析）。
- **对象回滚**：已复制到企业命名空间的对象不自动删除，后续凭对账处理；不执行 git reset/clean、不强制推送。
- 文件事实回写若发现错误，因有 `ers_file_path IS NULL` 幂等守卫且逐条执行，可在影响行数异常时立即停止，未批量扩散。

### 12.2 缺失文件影响
- 仅影响对应投递的"原始 PDF 查看/下载"，**不影响**结构化简历、人才库、AI 分析、人工评分、投递状态与招聘流程。
- 受影响投递：app 49/79（文件缺失）、app 45/46/52（本无引用），共 5 条 PDF 不可用；其余 5 条（app 47/48/70/71/78）具备恢复条件。
- 不产生任何伪造文件或哈希，不自动标记成功；所有未在目标环境实际执行的结论保持 **NOT_VERIFIED**。

---

## 十三、结论

- 结构化简历 10/10、AI 16/16 的核心目标不依赖 PDF 恢复，可独立放行。
- PDF 按尽力恢复：S3_READY 3 条（app70/71/78）HEAD 已验证、具备读取条件，但 GetObject/SHA/复制/回写均未做；候选 2 条（app47/48）须 HR 确认原件身份才回写；app79 大小冲突判 SIZE_NOT_VERIFIED，与 app49 等共 5 条不可恢复/无引用保持 NULL 且不阻塞。
- 现有后端接口能正确处理空路径、对象缺失、未确认候选与越权，且不回退 C-App；但 PDF 接口不独立验证原件身份（不检查 snapshot_status/version_verified），安全门禁依赖路径保持 NULL + HR 人工确认（见 8.1）。无需改动业务代码与已验收 SQL。
- 本文所有生产侧对象存在性、复制与回写结果当前均为 **NOT_VERIFIED**，待用户在受控环境按本方案执行并确认。

> 本轮为只读审查与新增文档，未执行任何写操作。完成后停止，等待用户审核。
