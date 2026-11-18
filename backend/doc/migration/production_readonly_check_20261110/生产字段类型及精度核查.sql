-- =====================================================================
-- 生产字段类型及精度核查.sql
-- 用途：按“预期字段清单 LEFT JOIN information_schema”逐字段核对类型/长度/精度/可空性/自增/字符集。
-- 安全：仅含 SELECT 与 information_schema 读取；不修改任何字段，无动态 SQL、无 DDL/DML。
-- 状态口径：
--   OK_* 全部符合；RISK_TYPE_REVIEW 类型/宽度/精度不符；RISK_NULLABILITY 可空性不符；
--   RISK_NOT_AUTO_INCREMENT 自增缺失；RISK_CHARSET 字符集不符；
--   MISSING_REQUIRED 应存在却缺失；MISSING_REVIEW 需人工核对；
--   NOT_APPLICABLE 当前阶段尚未执行相关迁移；TABLE_MISSING 表尚未建立。
-- 依据：02_schema.sql（AI 六字段、快照建表）、DR3_主键重构_待审核.sql（asr_id）、new.sql（原始 AI 表）。
-- =====================================================================

-- 0.0 执行前确认当前数据库（防止误在其他库执行；预期为目标库名，若不符立即停止）
SELECT DATABASE() AS current_database;

-- 4.1 AI 表字段逐字段预期清单（固定 8 行：原始 asr_updated_at + 02 六字段 + DR3 asr_id）
-- 预期可空性：asr_updated_at/asr_id 为 NO；02 六字段全部 DEFAULT NULL 为 YES。
SELECT e.column_name,
       CASE
         WHEN e.intro = 'STAGE0' THEN 'REQUIRED'
         WHEN e.intro = 'DR3' AND v.asr_id_present = 0 THEN 'NOT_APPLICABLE'
         WHEN e.intro = 'DR3' AND v.asr_id_present = 1 THEN 'REQUIRED'
         WHEN e.intro = 'STAGE1' AND v.added = 0 THEN 'NOT_APPLICABLE'
         WHEN e.intro = 'STAGE1' AND v.added = 6 THEN 'REQUIRED'
         ELSE 'REVIEW'
       END AS requirement,
       v.ai_present AS table_present,
       e.exp_nullable AS expected_nullable,
       c.data_type, c.column_type, c.datetime_precision,
       c.character_maximum_length, c.is_nullable, c.extra,
       CASE
         WHEN v.ai_present = 0 THEN 'TABLE_MISSING'
         WHEN c.column_name IS NULL THEN
           CASE
             WHEN e.intro = 'STAGE0' THEN 'MISSING_REQUIRED'
             WHEN e.intro = 'DR3' AND v.asr_id_present = 0 THEN 'NOT_APPLICABLE'
             WHEN e.intro = 'DR3' AND v.asr_id_present = 1 THEN 'MISSING_REQUIRED'
             WHEN e.intro = 'STAGE1' AND v.added = 0 THEN 'NOT_APPLICABLE'
             WHEN e.intro = 'STAGE1' AND v.added = 6 THEN 'MISSING_REQUIRED'
             ELSE 'MISSING_REVIEW'
           END
         ELSE
           CASE
             -- 第一层：类型/宽度/精度（先按 column_name 对应的 exp_type，再判 data_type）
             WHEN NOT (
               (e.exp_type = 'bigint' AND c.data_type = 'bigint')
               OR (e.exp_type = 'datetime' AND c.data_type = 'datetime' AND c.datetime_precision = 0)
               OR (e.exp_type = 'varchar' AND c.data_type = 'varchar'
                   AND c.character_maximum_length >= e.exp_width)
             ) THEN 'RISK_TYPE_REVIEW'
             -- 第二层：asr_id 必须 AUTO_INCREMENT
             WHEN e.exp_autoinc = 1 AND c.extra NOT LIKE '%auto_increment%'
               THEN 'RISK_NOT_AUTO_INCREMENT'
             -- 第三层：可空性必须与正式 DDL 一致
             WHEN c.is_nullable <> e.exp_nullable THEN 'RISK_NULLABILITY'
             -- 全部符合
             WHEN e.exp_type = 'bigint' THEN 'OK_BIGINT'
             WHEN e.exp_type = 'datetime' THEN 'OK_DATETIME'
             ELSE 'OK_VARCHAR'
           END
       END AS field_status
FROM (
  -- column_name | intro | exp_type | exp_width | exp_nullable | exp_autoinc
  SELECT 'asr_updated_at' AS column_name, 'STAGE0' AS intro, 'datetime' AS exp_type,
         NULL AS exp_width, 'NO' AS exp_nullable, 0 AS exp_autoinc
  UNION ALL SELECT 'asr_id','DR3','bigint',NULL,'NO',1
  UNION ALL SELECT 'asr_app_id','STAGE1','bigint',NULL,'YES',0
  UNION ALL SELECT 'asr_snapshot_id','STAGE1','bigint',NULL,'YES',0
  UNION ALL SELECT 'asr_content_hash','STAGE1','varchar',128,'YES',0
  UNION ALL SELECT 'asr_source','STAGE1','varchar',10,'YES',0
  UNION ALL SELECT 'asr_version_status','STAGE1','varchar',24,'YES',0
  UNION ALL SELECT 'asr_created_at','STAGE1','datetime',NULL,'YES',0
) e
CROSS JOIN (
  SELECT
    (SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis') AS ai_present,
    (SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
        AND column_name IN ('asr_app_id','asr_snapshot_id','asr_content_hash',
                            'asr_source','asr_version_status','asr_created_at')) AS added,
    (SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
        AND column_name = 'asr_id') AS asr_id_present
) v
LEFT JOIN information_schema.columns c
  ON c.table_schema = DATABASE()
 AND c.table_name = 't_ai_candidate_analysis'
 AND c.column_name = e.column_name
ORDER BY e.column_name;

-- 4.2 快照主表字段逐字段预期清单（固定 10 行；表未建全部 TABLE_MISSING，不逐个误判）
-- 预期可空性：5 个 ID 与 ers_created_at 为 NO；ers_snapshot_at 及三个文件列 DEFAULT NULL 为 YES。
SELECT e.column_name,
       CASE WHEN v.snap_present = 0 THEN 'NOT_APPLICABLE' ELSE 'REQUIRED' END AS requirement,
       v.snap_present AS table_present,
       e.exp_nullable AS expected_nullable,
       c.data_type, c.column_type, c.datetime_precision,
       c.character_maximum_length, c.is_nullable, c.extra,
       CASE
         WHEN v.snap_present = 0 THEN 'TABLE_MISSING'
         WHEN c.column_name IS NULL THEN 'MISSING_REQUIRED'
         ELSE
           CASE
             WHEN NOT (
               (e.exp_type = 'bigint' AND c.data_type = 'bigint')
               OR (e.exp_type = 'datetime' AND c.data_type = 'datetime' AND c.datetime_precision = 0)
               OR (e.exp_type = 'varchar' AND c.data_type = 'varchar'
                   AND c.character_maximum_length >= e.exp_width)
             ) THEN 'RISK_TYPE_REVIEW'
             WHEN e.exp_autoinc = 1 AND c.extra NOT LIKE '%auto_increment%'
               THEN 'RISK_NOT_AUTO_INCREMENT'
             WHEN c.is_nullable <> e.exp_nullable THEN 'RISK_NULLABILITY'
             WHEN e.exp_type = 'bigint' THEN 'OK_BIGINT'
             WHEN e.exp_type = 'datetime' THEN 'OK_DATETIME'
             ELSE 'OK_VARCHAR'
           END
       END AS field_status
FROM (
  SELECT 'ers_id' AS column_name, 'bigint' AS exp_type, NULL AS exp_width,
         'NO' AS exp_nullable, 1 AS exp_autoinc
  UNION ALL SELECT 'ers_app_id','bigint',NULL,'NO',0
  UNION ALL SELECT 'ers_candidate_id','bigint',NULL,'NO',0
  UNION ALL SELECT 'ers_company_id','bigint',NULL,'NO',0
  UNION ALL SELECT 'ers_position_id','bigint',NULL,'NO',0
  UNION ALL SELECT 'ers_snapshot_at','datetime',NULL,'YES',0
  UNION ALL SELECT 'ers_created_at','datetime',NULL,'NO',0
  UNION ALL SELECT 'ers_content_hash','varchar',128,'YES',0
  UNION ALL SELECT 'ers_file_path','varchar',500,'YES',0
  UNION ALL SELECT 'ers_file_name','varchar',255,'YES',0
) e
CROSS JOIN (
  SELECT COUNT(*) AS snap_present FROM information_schema.tables
   WHERE table_schema = DATABASE() AND table_name = 't_ent_resume_snapshot'
) v
LEFT JOIN information_schema.columns c
  ON c.table_schema = DATABASE()
 AND c.table_name = 't_ent_resume_snapshot'
 AND c.column_name = e.column_name
ORDER BY e.column_name;

-- 4.3 表级字符集预期清单（固定 6 行；统一统计五表存在数 snapshot_tables_present，部分存在 1-4 阻断）
SELECT e.table_name,
       CASE WHEN t.table_name IS NULL THEN 'MISSING' ELSE 'EXISTS' END AS table_status,
       t.table_collation,
       v.snapshot_tables_present,
       CASE
         WHEN t.table_name IS NULL AND e.table_name = 't_ai_candidate_analysis'
           THEN 'BLOCKED_TABLE_MISSING'
         WHEN t.table_name IS NULL AND v.snapshot_tables_present = 0
           THEN 'NOT_APPLICABLE'
         WHEN t.table_name IS NULL AND v.snapshot_tables_present BETWEEN 1 AND 4
           THEN 'BLOCKED_PARTIAL_SNAPSHOT_SCHEMA'
         WHEN t.table_name IS NULL AND v.snapshot_tables_present = 5
           THEN 'MISSING_REQUIRED'
         WHEN t.table_collation LIKE 'utf8mb4%' THEN 'OK_UTF8MB4'
         ELSE 'RISK_CHARSET'
       END AS verdict
FROM (
  SELECT 't_ai_candidate_analysis' AS table_name
  UNION ALL SELECT 't_ent_resume_snapshot'
  UNION ALL SELECT 't_ent_resume_education'
  UNION ALL SELECT 't_ent_resume_work'
  UNION ALL SELECT 't_ent_resume_project'
  UNION ALL SELECT 't_ent_resume_skill'
) e
CROSS JOIN (
  SELECT COUNT(*) AS snapshot_tables_present
    FROM information_schema.tables
   WHERE table_schema = DATABASE()
     AND table_name IN ('t_ent_resume_snapshot','t_ent_resume_education',
                        't_ent_resume_work','t_ent_resume_project','t_ent_resume_skill')
) v
LEFT JOIN information_schema.tables t
  ON t.table_schema = DATABASE() AND t.table_name = e.table_name
ORDER BY e.table_name;

-- 4.4 关键字符列级字符集预期清单（固定 5 行；复用 4.3 五表统计，部分存在 1-4 主表缺失判 BLOCKED_PARTIAL；AI 阶段判定保留）
SELECT e.table_name, e.column_name,
       CASE WHEN c.column_name IS NULL THEN 'MISSING' ELSE 'EXISTS' END AS column_status,
       c.character_set_name, c.collation_name,
       CASE
         WHEN c.column_name IS NULL THEN
           CASE
             WHEN e.table_name = 't_ai_candidate_analysis' AND v.ai_present = 0
               THEN 'BLOCKED_TABLE_MISSING'
             WHEN e.table_name = 't_ai_candidate_analysis' AND v.added = 0
               THEN 'NOT_APPLICABLE'
             WHEN e.table_name = 't_ai_candidate_analysis' AND v.added = 6
               THEN 'MISSING_REQUIRED'
             WHEN e.table_name = 't_ent_resume_snapshot' AND v.snap_present = 0
                  AND v.snapshot_tables_present = 0
               THEN 'NOT_APPLICABLE'
             WHEN e.table_name = 't_ent_resume_snapshot' AND v.snap_present = 0
                  AND v.snapshot_tables_present BETWEEN 1 AND 4
               THEN 'BLOCKED_PARTIAL_SNAPSHOT_SCHEMA'
             WHEN e.table_name = 't_ent_resume_snapshot' AND v.snap_present = 0
                  AND v.snapshot_tables_present = 5
               THEN 'MISSING_REQUIRED'
             WHEN e.table_name = 't_ent_resume_snapshot'
               THEN 'MISSING_REQUIRED'
             ELSE 'MISSING_REVIEW'
           END
         WHEN c.character_set_name = 'utf8mb4' THEN 'OK_UTF8MB4_COLUMN'
         ELSE 'RISK_CHARSET'
       END AS verdict
FROM (
  SELECT 't_ai_candidate_analysis' AS table_name, 'asr_content_hash' AS column_name
  UNION ALL SELECT 't_ai_candidate_analysis','asr_source'
  UNION ALL SELECT 't_ent_resume_snapshot','ers_content_hash'
  UNION ALL SELECT 't_ent_resume_snapshot','ers_file_path'
  UNION ALL SELECT 't_ent_resume_snapshot','ers_file_name'
) e
CROSS JOIN (
  SELECT
    (SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis') AS ai_present,
    (SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
        AND column_name IN ('asr_app_id','asr_snapshot_id','asr_content_hash',
                            'asr_source','asr_version_status','asr_created_at')) AS added,
    (SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = DATABASE() AND table_name = 't_ent_resume_snapshot') AS snap_present,
    (SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = DATABASE()
        AND table_name IN ('t_ent_resume_snapshot','t_ent_resume_education',
                           't_ent_resume_work','t_ent_resume_project','t_ent_resume_skill'))
      AS snapshot_tables_present
) v
LEFT JOIN information_schema.columns c
  ON c.table_schema = DATABASE()
 AND c.table_name = e.table_name
 AND c.column_name = e.column_name
ORDER BY e.table_name, e.column_name;
