# 历史投递与 AI 分析数据保护报告

> 基线：历史投递 10（含软删关联 2）；AI 分析 16（llm 15、manual 1）；重复三元组 0。
> 结论口径：本报告基于源码与离线/隔离验证，不代表生产已迁移。

## 一、总体结论

| 保护对象 | 结论 | 依据 |
|---|---|---|
| 10 条历史投递快照 | PASS | 03 以全部 t_app_record 为入口，无 rbs_status 过滤，NOT EXISTS 幂等 |
| 2 条软删简历 | PASS | 主记录存在即 REBUILT_UNVERIFIED，不遗漏、不直接判 MISSING_SOURCE |
| 16 条 AI 分析 | PASS | 全链路无 DELETE/覆盖；DR3 不删行；04 校验行数与内容 |
| 1 条 manual 分析 | PASS | saveManualAnalysis 为 INSERT；05 回滚完整留存归档表 |
| 逐条追溯/报告不改写 | PASS | asr_id 独立主键；04 行哈希 + 多重集比对；无 UPDATE 改写 asr_report 的生产路径 |
| 详情页简历/PDF 读取口径 | WARNING | 候选人详情页结构化简历与“原始简历”仍读 C-App 当前简历，未完全走快照，详见阻断清单 W1/W2 |

## 二、10 条历史投递的保护

### 2.1 全量入口、无软删过滤
- 03_backfill.sql:45-50：`FROM t_app_record a JOIN t_tal t ... LEFT JOIN t_res_base b`，WHERE 仅 NOT EXISTS（幂等），**无 rbs_status=1 之类过滤**。
- 软删（rbs_status=0）只要主记录存在，b.rbs_id IS NOT NULL，标 REBUILT_UNVERIFIED；仅当主记录彻底缺失才 MISSING_SOURCE。
- 生产基线 2 软删均能找到主记录 → 正常进入快照与子表回填，不遗漏。

### 2.2 每 app_id 唯一有效快照
- 主表 uk_ers_app 唯一约束 + 03 NOT EXISTS 双重保证：每个 app_id 最多一条有效快照。
- 04 校验 3：按 ers_app_id 分组 HAVING COUNT(*)>1，应无输出。

### 2.3 子表保护与孤立防控
- 03 子表按 ers_source_resume_id INNER JOIN 源四子表，NOT EXISTS 幂等；源子表被清理则对应子表为空，不中断其他子表。
- 04 校验 9：四类子表孤儿行（snapshot_id 在主表不存在）应无输出；校验 8：源/快照多重集 COUNT 双向 + 行哈希，diff 应=0。

### 2.4 历史重建不标原始真实版本
- 03 主表对历史回填标 REBUILT_UNVERIFIED（非 COMPLETE），时间来源按 app_created_at 标 BACKFILL_REAL，缺失标 BACKFILL_UNKNOWN、snapshot_at 保留 NULL，不伪造。
- 仅实时投递路径（EntResumeSnapshotService.createForApplication）才标 COMPLETE/LIVE_ORIGINAL/LIVE_REAL。

## 三、16 条 AI 分析的保护

### 3.1 无删除、无覆盖（源码证据）
- 02_schema.sql：仅 CREATE TABLE IF NOT EXISTS、ADD COLUMN IF NOT EXISTS、p_ensure_index；无 DELETE 历史分析。
- DR3：单条 ALTER 改主键，不删行、不改 asr_report；原 16 行自动获得独立 asr_id。
- ScreeningMapper.xml：saveAnalysis（213）、saveManualAnalysis（224）均为 **INSERT 追加**；最新读取 order by asr_created_at, asr_updated_at, asr_id（180/193/203），排序稳定。
- updateAnalysisReport（318-322）按 asr_id 精确更新，注释明确“当前无生产调用方，防御性保留”，不按非唯一三元组更新。
- 全 Mapper 检索：仅 EnterpriseJobMapper.xml:231 deleteAiAnalysisByPosition 为删除岗位的既有级联清理，非迁移路径、迁移期间不触发，属范围外既有行为。

### 3.2 manual 与 llm 共存
- 人工评分 ScreeningServiceImpl:699-729 以 source=manual 独立 INSERT，不覆盖 AI 六维；llm/manual 各自成行，靠 asr_id 区分。
- 05 回滚为归档式 RENAME（零 DELETE），manual 与多版本完整留存归档表，不写入重建旧表但永久可追溯。

### 3.3 无法精确绑定者保持 UNVERIFIED
- 03 绑定段要求两 ID 均空、版本状态非 MATCHED 才进入，执行后 app_id/snapshot_id 保持 NULL，禁止猜测。
- ScreeningServiceImpl:466-477：分析绑定的 snapshot_id/content_hash 与当前快照不一致即 versionStatus=UNVERIFIED。
- 历史来源标记 15 llm/1 manual 仅为 JSON 标记，不等于版本真实性已验证；来源不明不自动标记为可信 llm。
- 有效分析口径 ScreeningServiceImpl:551：仅 llm/manual 被识别，unknown 不显示为有效 AI 分析。

## 四、迁移后对账方法（防止“只看总数”掩盖丢失）

1. 迁移前固化基线：AI 16、投递 10、来源分布 llm15/manual1。
2. 若迁移窗口允许新写入，必须先记录迁移起止时间，对增量单独对账，不能只用迁移后总数证明零丢失。
3. 逐条追溯：以 asr_id 回连，核对原始三元组与 asr_report 内容；04 行哈希 SHA-256 比对，确保报告内容未改写。
4. 行数核验：04 校验 1 投递数=快照数（gap=0）；AI 表迁移前后行数一致（无删除）。
5. manual 专项：确认 1 条 manual 迁移后仍在（回滚场景则在归档表）。

## 五、风险与边界

- 报告来源标记不等于历史版本真实性，精确投递绑定需 03/04 后人工核验（NOT_VERIFIED 部分见阻断清单）。
- 不凭三元组推断唯一投递版本；不做非唯一三元组 UPDATE；不批量改历史来源。
- 静态/隔离通过不等于生产生效，最终以用户手动执行 04 结果为准。
- 应用层遗留：候选人详情页（岗位上下文下同样）结构化简历与 PDF 仍读 C-App 当前简历，
  软删除后 PDF 下载会失败；数据迁移不受影响，但“彻底隔离”在详情页未完全闭环，
  最小修复方向见《正式迁移前阻断问题清单》W1/W2，须用户批准后再实施。
