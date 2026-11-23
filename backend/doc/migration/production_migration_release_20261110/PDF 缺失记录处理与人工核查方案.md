# PDF 缺失记录处理与人工核查方案

> 基线：PDF 路径为空投递 3；路径非空 7（对象真实存在性未验证）；2 软删与 3 PDF 缺失不重合。
> 原则：PDF 缺失 ≠ 结构化来源缺失；不伪造文件、哈希、真实性；异常进人工核查。

## 一、结论

| 检查项 | 结论 |
|---|---|
| 空路径是否阻断结构化快照 | PASS（不阻断） |
| 是否生成虚假 PDF/哈希/真实性 | PASS（不生成） |
| 是否自动 COMPLETE/MANUAL_VERIFIED | PASS（不会） |
| 是否进人工核查清单 | PASS（SOURCE_MISSING_NO_FILE） |
| 企业端无 PDF 展示与报错 | PASS（结构化可展示，PDF 下载抛业务异常） |
| 7 条非空对象与 SHA-256 | NOT_VERIFIED（需受控工具读回核验，本线不连对象存储） |

## 二、3 条空路径的系统处理

### 2.1 结构化快照独立于 PDF
- 03_backfill 主表对全部 10 投递生效，PDF 三列（file_path/file_name/file_size）先写 NULL，不影响主表与四子表创建。
- 快照状态按主记录判定为 REBUILT_UNVERIFIED，与 PDF 是否存在无关。

### 2.2 PDF 工具逐条判定、不中断
- HistoricalResumePdfMigrator.migrateOne：源字节为 null/空 → Outcome SOURCE_MISSING（“源 PDF 缺失或为空，列入人工核查，禁止伪造”）；单条结果不影响其他条目。
- 清单解析 HistoricalResumeMigrationConsole:217-218：sourceRef 为空则 fail-fast 停止。因此空路径记录不进入“迁移工作清单”，而是在生成清单时归入人工核查，避免错误写入。
- PdfFileVerification.classify：源、目标均不存在 → SOURCE_MISSING_NO_FILE；读取异常/绑定错误 → MANUAL_REVIEW。

### 2.3 不产生伪造证据
- 空路径不计算/不写入 PDF 哈希，不生成 ers_content_hash 的 PDF 部分，不标 MANUAL_VERIFIED/LIVE_ORIGINAL。
- 真实性核验（authenticity_verified）保持未验证，需人工确认，不自动置真。

## 三、企业端界面行为（无 PDF 场景）

- 结构化简历：TalentPoolServiceImpl.getTalentResume 仅读结构化数据，不依赖 PDF，无 PDF 时教育/工作/项目/技能照常返回，详情页不会因缺 PDF 打不开。
- PDF 下载：getTalentResumePdf 在 filePath 为空时抛 ServiceException（“该简历未保存原始 PDF”），由全局异常处理返回标准错误码与中文提示，前端据此提示“该简历未保存原始 PDF”，而非崩溃或返回伪造文件。
- 投递/筛选/AI 路径均读快照结构化内容，缺 PDF 不阻断列表与 AI 分析。
- 口径澄清：上文 getTalentResume/getTalentResumePdf 是以 talId 为入口的“人才库当前简历”路径（读 t_res_*）；
  岗位筛选结果与 AI 分析才是投递快照路径。候选人详情页在岗位上下文下仍走当前简历路径，且软删除后
  PDF 下载会因 rbs_status 过滤失败，详见《正式迁移前阻断问题清单》W1/W2。

## 四、14 列清单与最终分类

- 输出文件：真实迁移 migration_file_verification_manifest.csv；dry-run dry_run_file_verification_manifest.csv；UTF-8，布尔 TRUE/FALSE。
- 14 列固定顺序：source_path、target_path、source_exists、target_exists、source_size、target_size、source_sha256、target_sha256、copy_verified、archive_integrity_verified、archive_reference_sha256、authenticity_verified、final_classification、detail。
- 3 条空路径预期 final_classification=SOURCE_MISSING_NO_FILE，source_exists/target_exists=FALSE，哈希列为空，authenticity_verified=FALSE。
- 相关最终分类（10 类）：RECOVERABLE_PENDING、COPIED_UNVERIFIED、COPIED_AND_VERIFIED、VERIFY_FAILED、SOURCE_MISSING_NO_FILE、ARCHIVED_UNVERIFIED、SOURCE_MISSING_BUT_ARCHIVED、ARCHIVE_HASH_MISMATCH、LIVE_ORIGINAL_COMPLETE、MANUAL_REVIEW。

## 五、7 条非空路径的逐个核实（受控执行，不连真实对象存储由 AI 代做）

1. 先 dry-run：HistoricalResumeMigrationConsole 默认 dry-run=true，只读源、算源哈希、不写目标，输出 14 列清单与计划。
2. 人工核对 dry-run 中 source_exists、source_size、source_sha256；任何读取异常条目按 MANUAL_REVIEW 处理。
3. 确认真实迁移：显式 dry-run=false，企业对象 CREATE_NEW 不覆盖、读回目标做 SHA-256 核验；不一致则 VERIFY_FAILED 并清理本次新建对象，可重试。
4. 逐对象确认：以 copy_verified（复制一致性）与 archive_integrity_verified（归档完整性）、authenticity_verified（原件真实性）三层分离，任一不满足不得判“已验证”。
5. 06 文件事实回写 SQL 保持注释，由用户逐条审核后手动执行；不自动执行。

## 六、人工核查台账（待用户填写，脱敏）

| 项 | 记录内容 |
|---|---|
| 3 条空路径 | app_id（脱敏映射）、当前快照状态、是否可补原件、最终处置 |
| 7 条非空 | 逐个 source_exists、size、source/target SHA-256、三层验证结果 |
| 无法恢复者 | 明确标 MANUAL_REVIEW/异常提示，保留结构化简历，不伪造成功 |

> 生产 PDF 对象真实存在性、SHA-256、对象存储对账当前均 NOT_VERIFIED，需上述受控程序或人工确认后更新结论。
