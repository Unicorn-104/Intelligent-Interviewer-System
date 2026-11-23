-- =====================================================================
-- 生产表结构只读核查.sql
-- 用途：正式迁移前核对企业快照五表与 AI 分析表的真实结构。
-- 安全：本文件仅含 SELECT 与 information_schema 读取，无任何写入/DDL/动态执行。
-- 执行方式：由人工在生产库手动执行，逐段核对结果。
-- 表名基准（以 02_schema.sql 真实定义为准）：
--   t_ent_resume_snapshot / t_ent_resume_education / t_ent_resume_work /
--   t_ent_resume_project / t_ent_resume_skill / t_ai_candidate_analysis
-- 说明：任务书所写 t_ent_resume_experience、t_ent_resume_award 在方案中不存在，
--   真实表为 t_ent_resume_work、t_ent_resume_skill。
-- =====================================================================

-- 0.0 执行前确认当前数据库（防止误在其他库执行；预期为目标库名，若不符立即停止，不继续后续查询）
SELECT DATABASE() AS current_database;

-- 1.1 目标表存在性逐表判定（固定 6 行，缺表也返回 MISSING，避免空结果被误判）
-- 口径：AI 表必须存在（缺失 BLOCKED）；快照五表首次迁移前允许不存在（缺失属正常待建）；
--   快照表存在则需按 1.2 起逐字段核对，部分存在见 1.1-bis。
SELECT e.table_name, e.requirement,
       CASE WHEN t.table_name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END AS table_status,
       t.engine, t.table_collation,
       CASE
         WHEN e.requirement = 'REQUIRED' AND t.table_name IS NOT NULL
           THEN 'OK_REQUIRED_PRESENT'
         WHEN e.requirement = 'REQUIRED' AND t.table_name IS NULL
           THEN 'BLOCKED_REQUIRED_MISSING'
         WHEN e.requirement = 'OPTIONAL_BEFORE_FIRST' AND t.table_name IS NULL
           THEN 'OK_EXPECTED_BEFORE_FIRST_MIGRATION'
         ELSE 'WARNING_EXISTS_NEED_STRUCTURE_CHECK'
       END AS verdict
FROM (
  SELECT 't_ai_candidate_analysis' AS table_name, 'REQUIRED' AS requirement
  UNION ALL SELECT 't_ent_resume_snapshot', 'OPTIONAL_BEFORE_FIRST'
  UNION ALL SELECT 't_ent_resume_education', 'OPTIONAL_BEFORE_FIRST'
  UNION ALL SELECT 't_ent_resume_work', 'OPTIONAL_BEFORE_FIRST'
  UNION ALL SELECT 't_ent_resume_project', 'OPTIONAL_BEFORE_FIRST'
  UNION ALL SELECT 't_ent_resume_skill', 'OPTIONAL_BEFORE_FIRST'
) e
LEFT JOIN information_schema.tables t
  ON t.table_schema = DATABASE() AND t.table_name = e.table_name
ORDER BY e.table_name;

-- 1.1-bis 快照五表存在数量汇总（0=干净未建可首次迁移；5=全部已建；1-4=部分存在，非干净中间态）
-- 异常判定：1-4 标记 WARNING，需人工确认是否为失败/中断的历史迁移，核对后再决定继续或清理。
SELECT COUNT(t.table_name) AS snapshot_tables_present,
       CASE
         WHEN COUNT(t.table_name) = 0 THEN 'OK_NONE_FIRST_MIGRATION'
         WHEN COUNT(t.table_name) = 5 THEN 'WARNING_ALL_PRESENT_VERIFY'
         ELSE 'WARNING_PARTIAL_PRESENT_BLOCK_REVIEW'
       END AS verdict
FROM (
  SELECT 't_ent_resume_snapshot' AS table_name
  UNION ALL SELECT 't_ent_resume_education'
  UNION ALL SELECT 't_ent_resume_work'
  UNION ALL SELECT 't_ent_resume_project'
  UNION ALL SELECT 't_ent_resume_skill'
) e
LEFT JOIN information_schema.tables t
  ON t.table_schema = DATABASE() AND t.table_name = e.table_name;

-- 1.2 快照五表全部字段明细（名称/类型/可空/默认/字符集；与 02 建表定义逐字段比对）
-- 预期：字段名、column_type、is_nullable、column_default 与 02 定义一致。
-- 异常判定：字段类型不符、可空性相反、默认值非预期均标记 WARNING 或 BLOCKED。
SELECT table_name, ordinal_position, column_name, column_type, is_nullable,
       column_default, character_set_name, collation_name, extra
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name IN (
    't_ent_resume_snapshot','t_ent_resume_education','t_ent_resume_work',
    't_ent_resume_project','t_ent_resume_skill')
ORDER BY table_name, ordinal_position;

-- 1.3 快照五表全部索引（区分 PRIMARY/UNIQUE/普通；核对列名与列序）
-- 预期主表：PRIMARY(ers_id)、uk_ers_app(ers_app_id)、idx_ers_company/candidate/position/status。
-- 子表：各自单列主键 + 一个 snapshot_id 普通索引。
-- 异常判定：索引缺失、列序不符、存在非预期唯一索引均需人工确认。
SELECT table_name, index_name, non_unique, seq_in_index, column_name, sub_part
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name IN (
    't_ent_resume_snapshot','t_ent_resume_education','t_ent_resume_work',
    't_ent_resume_project','t_ent_resume_skill')
ORDER BY table_name, index_name, seq_in_index;

-- 1.4 AI 分析表字段明细（判断当前处于“原始/02加列后/DR3重构后”哪个阶段）
-- 预期原始仅 6 列；02 后增加至 12 列；DR3 后再增 asr_id 共 13 列。
-- 异常判定：出现方案外字段、类型不符需人工确认。
SELECT ordinal_position, column_name, column_type, is_nullable, column_default, extra
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
ORDER BY ordinal_position;

-- 1.5 AI 分析表全部索引与列序（核对主键、DR3 三元组普通索引、02 四索引、原始 idx_aca）
-- 原始预期：PRIMARY 三列 + idx_aca_candidate_updated。
-- DR3 后预期：PRIMARY(asr_id) + idx_asr_company_position_candidate + 02 四索引 + idx_aca。
-- 异常判定：索引结构与当前阶段不匹配，按迁移前置条件判定，禁止凭路径名猜测。
SELECT index_name, non_unique, seq_in_index, column_name, sub_part
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
ORDER BY index_name, seq_in_index;

-- 1.6 外键核查（预期：全部目标表无外键，方案不使用外键）
-- 异常判定：若存在外键，属方案外结构，标记 BLOCKED，需人工评估后再迁移。
SELECT table_name, constraint_name, referenced_table_name, referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE()
  AND table_name IN (
    't_ent_resume_snapshot','t_ent_resume_education','t_ent_resume_work',
    't_ent_resume_project','t_ent_resume_skill','t_ai_candidate_analysis')
  AND referenced_table_name IS NOT NULL
ORDER BY table_name, constraint_name;

-- 1.7 引用 AI 表的外键（反向核查；预期 0 行，05 守卫6 同样要求无外键引用本表）
-- 异常判定：若有其他表外键引用 AI 表，DROP PRIMARY KEY 会失败，标记 BLOCKED。
SELECT table_name, constraint_name, column_name
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE()
  AND referenced_table_name = 't_ai_candidate_analysis'
ORDER BY table_name, constraint_name;
