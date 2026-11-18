# 生产迁移 SQL 执行顺序与核验清单

> 所有语句由用户本人手动执行；每文件先 `SELECT DATABASE();` 核对 recruit_agent，不符立即停止。
> 标记说明：【只读】可重复执行；【DDL】隐式提交、不可事务回滚；【DML】数据回填。

## 一、执行顺序总览

| 序 | 阶段 | 文件（相对仓库根） | 类型 | 语句数 |
|---|---|---|---|---|
| 0 | A | 备份（mysqldump/物理/对象存储） | — | — |
| 1 | A | production_readonly_check_20261110/生产表结构只读核查.sql | 只读 | 9 |
| 2 | A | production_readonly_check_20261110/生产 AI 分析记录核查.sql | 只读 | 11 |
| 3 | A | production_readonly_check_20261110/生产字段类型及精度核查.sql | 只读 | 5 |
| 4 | A | production_readonly_check_20261110/生产历史数据只读诊断.sql | 只读 | 19 |
| 5 | B | enterprise_resume_snapshot/01_precheck.sql | 只读 | 12 检查 |
| 6 | B | enterprise_resume_snapshot/02_schema.sql（手动 CALL） | DDL | 过程 |
| 7 | B | enterprise_resume_snapshot/DR3_主键重构_待审核.sql（手动 CALL） | DDL | 过程 |
| 8 | C | enterprise_resume_snapshot/03_backfill.sql | DML | 多段 |
| 9 | D | enterprise_resume_snapshot/04_verify.sql | 只读 | 12 组 |
| — | G | enterprise_resume_snapshot/05_rollback.sql（仅回滚，不进正向） | DDL/DML | 过程 |

## 二、只读核查（序 1–4，共 44 SELECT）

执行顺序固定：表结构 → AI 分析 → 字段类型 → 历史数据。

- 序 1 表结构：1.1 固定 6 行表存在性、1.1-bis 五表计数（基线=0）；1.6/1.7 外键预期 0。
- 序 2 AI：3.1–3.4 主键/asr_id/列盘点；3.5 输出 migration_stage（基线 STAGE0_ORIGINAL）；3.7 与 3.5 同口径；3.8 外键 0；3.9/3.10 多版本。
- 序 3 字段类型：4.1 AI 固定 8 行、4.2 主表 10 行；4.3 表级 6 行、4.4 列级 5 行。
- 序 4 历史数据：2.1 规模；2.6 六态仅 LEGAL_0_5；2.7/2.8 引用与软删；2.10/2.11 PDF 路径；2.12 时间；2.14–2.17 仅建表后执行。
- 条件执行：2.2 仅 02 加列后；2.12b 仅 2.12a 为 COLUMN_EXISTS；2.14–2.17 未建表跳过。
- 停止条件：外键非 0、出现 ILLEGAL/NULL 状态、migration_stage 与基线不符、RISK_CHARSET 等，任一出现即停止。

## 三、结构迁移（序 5–7）

### 序 5：01_precheck.sql【只读】
- 前置：序 1–4 与基线一致。
- 预期：检查 2 依赖 8 表齐全；检查 3 无非法六态；检查 10 无“需停止”；检查 11 无同名异结构。
- 停止：任一“需停止”项未澄清即停止。

### 序 6：02_schema.sql【DDL】
- 前置：序 5 通过。操作：审核后取消注释，手动 `CALL p_ent_schema_migrate();`
- 影响对象：CREATE TABLE IF NOT EXISTS 五张 t_ent_resume_*；AI 表 ADD COLUMN IF NOT EXISTS 02 六字段（均 DEFAULT NULL）；p_ensure_index 建 02 四索引。
- 执行后核验：
```sql
SELECT table_name FROM information_schema.tables
 WHERE table_schema=DATABASE() AND table_name LIKE 't_ent_resume_%';   -- 预期 5 行
SELECT column_name FROM information_schema.columns
 WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis'
   AND column_name IN ('asr_app_id','asr_snapshot_id','asr_content_hash',
                       'asr_source','asr_version_status','asr_created_at'); -- 预期 6 行
SELECT index_name, non_unique FROM information_schema.statistics
 WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis'
   AND index_name LIKE 'idx_asr_%';  -- 02 四索引，non_unique 均为 1
```
- 停止：守卫 p_ent_preflight_guard 失败即中止（未产生变更）。

### 序 7：DR3_主键重构_待审核.sql【DDL】
- 前置：序 6 核验通过。操作：手动 `CALL p_dr3_pk_rebuild();`
- 影响：DROP 旧主键；ADD asr_id BIGINT NOT NULL AUTO_INCREMENT FIRST；ADD PRIMARY KEY(asr_id)；ADD KEY idx_asr_company_position_candidate。
- 执行后核验：
```sql
SELECT column_name, extra FROM information_schema.columns
 WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis' AND column_name='asr_id';
   -- extra 含 auto_increment，data_type=bigint，is_nullable=NO
SELECT index_name, column_name, seq_in_index FROM information_schema.statistics
 WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis'
   AND index_name='idx_asr_company_position_candidate' ORDER BY seq_in_index; -- 3 列、列序 company,position,candidate
SELECT COUNT(*) FROM t_ai_candidate_analysis;  -- 预期仍为 16，行不丢
```
- 停止：守卫失败即中止（未 ALTER）。

## 四、回填与验证（序 8–9）

### 序 8：03_backfill.sql【DML】
- 前置：序 7 核验通过。按文件内分段顺序执行（主表 → 四子表 → AI 来源/绑定）。
- 幂等：每段 NOT EXISTS，可重复执行。
- 执行后核验：
```sql
SELECT COUNT(*) FROM t_ent_resume_snapshot;                 -- 预期 10
SELECT ers_snapshot_status, COUNT(*) FROM t_ent_resume_snapshot GROUP BY ers_snapshot_status;
SELECT ers_app_id, COUNT(*) FROM t_ent_resume_snapshot GROUP BY ers_app_id HAVING COUNT(*)>1; -- 无输出
SELECT COUNT(*) FROM t_ai_candidate_analysis;               -- 预期 16，不被删改
```
- 必做：执行 03 文末异常检查 A（孤儿投递）、B（多快照未绑定）、C（无快照匹配），
  生产重复三元组为 0，B 应无输出；A、C 若有输出立即停止并人工处理，不得静默继续。
- 停止：孤儿投递、行数与预期不符即停止。

### 序 9：04_verify.sql【只读】
- 前置：序 8 完成。
- 通过标准：校验 1 gap_should_be_zero=0；校验 3/4/5/6/7/9/10 无异常输出；校验 8 各子表 diff=0；校验 11 待人工清单符合预期。
- 停止：任一硬性校验有输出即停止，不进入部署。

## 五、回滚（仅 G，不进正向）

- 05_rollback.sql：手动 `CALL p_ent_rollback();`（默认注释），归档表后缀固定 20261109，重复执行被安全闸门中止。
- 回滚后核验：归档表行数=回滚前总行数；重建表结构与旧版一致；manual/多版本留存归档表。
- 无法自动恢复：企业快照五表/PDF 默认保留不 DROP；RENAME 后中途失败需人工 ALTER 或备份恢复。

## 六、结果回收清单（每序完成后留存，脱敏）

1. 每文件 0.0 库名；2. 序 6/7 结构核验三查询结果；3. 序 8 计数与状态分布；4. 序 9 全部校验结果；5. 任何异常的完整错误码与中文说明。
