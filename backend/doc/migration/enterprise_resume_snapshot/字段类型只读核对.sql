-- =====================================================
-- 用途：04 校验8.5 行哈希涉及字段的“只读核对”（4 源表 + 4 快照子表）
-- 全部为 SELECT，仅查 information_schema，不读业务数据、不执行 DDL/DML。
-- 背景：源表(t_res_*)建表 DDL 不在仓库，无法静态确认日期列类型，禁止猜测，须用户在真实库手动核对。
-- 修订说明（2026-11-10）：
--   旧版用 column_name IN ('start_date','end_date') 匹配，但真实字段带表前缀（edu_start_date 等），
--   会返回 0 行；本版改用 12 个真实字段名 + 预期清单 LEFT JOIN，显式判定存在性与缺失，空结果不再被误判为 DATE。
-- =====================================================

-- 1) 8 张表全部字段的完整类型信息（按表、列序）
SELECT table_name, ordinal_position, column_name,
       data_type, column_type,
       datetime_precision,
       numeric_precision, numeric_scale,
       is_nullable, character_set_name, collation_name
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name IN (
    't_res_education','t_res_work','t_res_project','t_res_skill',
    't_ent_resume_education','t_ent_resume_work','t_ent_resume_project','t_ent_resume_skill')
ORDER BY table_name, ordinal_position;

-- 2) 【覆盖完整性】预期 12 个日期字段 LEFT JOIN 实际列：
--    presence=PRESENT 表示存在；MISSING 表示该字段缺失（data_type 等为 NULL）。
--    理想：12 行全部 PRESENT 且 data_type='date'。
WITH expected(tbl, col) AS (
  SELECT 't_res_education','edu_start_date' UNION ALL
  SELECT 't_res_education','edu_end_date' UNION ALL
  SELECT 't_ent_resume_education','ere_start_date' UNION ALL
  SELECT 't_ent_resume_education','ere_end_date' UNION ALL
  SELECT 't_res_work','wrk_start_date' UNION ALL
  SELECT 't_res_work','wrk_end_date' UNION ALL
  SELECT 't_ent_resume_work','erw_start_date' UNION ALL
  SELECT 't_ent_resume_work','erw_end_date' UNION ALL
  SELECT 't_res_project','prj_start_date' UNION ALL
  SELECT 't_res_project','prj_end_date' UNION ALL
  SELECT 't_ent_resume_project','erp_start_date' UNION ALL
  SELECT 't_ent_resume_project','erp_end_date'
)
SELECT e.tbl, e.col,
       CASE WHEN c.column_name IS NULL THEN 'MISSING' ELSE 'PRESENT' END AS presence,
       c.data_type, c.column_type, c.datetime_precision, c.is_nullable
FROM expected e
LEFT JOIN information_schema.columns c
  ON c.table_schema = DATABASE() AND c.table_name = e.tbl AND c.column_name = e.col
ORDER BY e.tbl, e.col;

-- 3) 【汇总判定】应找到 12 个；found<12 或有非 DATE / 含小数秒，即不通过，先处理再演练。
WITH expected(tbl, col) AS (
  SELECT 't_res_education','edu_start_date' UNION ALL
  SELECT 't_res_education','edu_end_date' UNION ALL
  SELECT 't_ent_resume_education','ere_start_date' UNION ALL
  SELECT 't_ent_resume_education','ere_end_date' UNION ALL
  SELECT 't_res_work','wrk_start_date' UNION ALL
  SELECT 't_res_work','wrk_end_date' UNION ALL
  SELECT 't_ent_resume_work','erw_start_date' UNION ALL
  SELECT 't_ent_resume_work','erw_end_date' UNION ALL
  SELECT 't_res_project','prj_start_date' UNION ALL
  SELECT 't_res_project','prj_end_date' UNION ALL
  SELECT 't_ent_resume_project','erp_start_date' UNION ALL
  SELECT 't_ent_resume_project','erp_end_date'
)
SELECT 12 AS expected_count,
       COUNT(c.column_name) AS found_count,
       SUM(CASE WHEN c.column_name IS NULL THEN 1 ELSE 0 END) AS missing_count,
       SUM(CASE WHEN c.data_type <> 'date' THEN 1 ELSE 0 END) AS non_date_count,
       -- 仅统计实际小数秒精度大于 0 的字段；NULL 与 0 都不计（NULL>0 结果为 NULL，走 ELSE）
       SUM(CASE WHEN c.datetime_precision > 0 THEN 1 ELSE 0 END) AS has_fractional_count
FROM expected e
LEFT JOIN information_schema.columns c
  ON c.table_schema = DATABASE() AND c.table_name = e.tbl AND c.column_name = e.col;

-- 4) 【源/目标成对一致性】6 对日期字段类型是否一致（理想：6 行 type_match=YES）。
WITH expected(side, tbl, col, pair_key) AS (
  SELECT 'SRC','t_res_education','edu_start_date','edu_start' UNION ALL
  SELECT 'SRC','t_res_education','edu_end_date','edu_end' UNION ALL
  SELECT 'SNP','t_ent_resume_education','ere_start_date','edu_start' UNION ALL
  SELECT 'SNP','t_ent_resume_education','ere_end_date','edu_end' UNION ALL
  SELECT 'SRC','t_res_work','wrk_start_date','wrk_start' UNION ALL
  SELECT 'SRC','t_res_work','wrk_end_date','wrk_end' UNION ALL
  SELECT 'SNP','t_ent_resume_work','erw_start_date','wrk_start' UNION ALL
  SELECT 'SNP','t_ent_resume_work','erw_end_date','wrk_end' UNION ALL
  SELECT 'SRC','t_res_project','prj_start_date','prj_start' UNION ALL
  SELECT 'SRC','t_res_project','prj_end_date','prj_end' UNION ALL
  SELECT 'SNP','t_ent_resume_project','erp_start_date','prj_start' UNION ALL
  SELECT 'SNP','t_ent_resume_project','erp_end_date','prj_end'
),
typed AS (
  SELECT e.pair_key, e.side, c.data_type, c.datetime_precision
  FROM expected e
  LEFT JOIN information_schema.columns c
    ON c.table_schema = DATABASE() AND c.table_name = e.tbl AND c.column_name = e.col
)
SELECT a.pair_key,
       a.data_type AS src_type, b.data_type AS snp_type,
       CASE WHEN a.data_type = b.data_type
             AND a.datetime_precision <=> b.datetime_precision
            THEN 'YES' ELSE 'NO' END AS type_match
FROM typed a JOIN typed b ON a.pair_key = b.pair_key
WHERE a.side = 'SRC' AND b.side = 'SNP'
ORDER BY a.pair_key;

-- 5) DECIMAL 列精度（教育 gpa，确认源/目标 precision、scale 一致）
SELECT table_name, column_name, data_type, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name IN ('t_res_education','t_ent_resume_education')
  AND data_type = 'decimal'
ORDER BY table_name, column_name;

-- 6) 字符串/TEXT/TINYINT 列字符集与排序规则
SELECT table_name, column_name, data_type, character_set_name, collation_name, is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name IN (
    't_res_education','t_res_work','t_res_project','t_res_skill',
    't_ent_resume_education','t_ent_resume_work','t_ent_resume_project','t_ent_resume_skill')
  AND data_type IN ('varchar','text','tinyint')
ORDER BY table_name, ordinal_position;

-- 7) DR-2：时间列真实类型与小数秒精度（确认 MODIFY 成秒级 datetime 是否会截断；纯只读，不修改字段）
-- 识别口径：data_type 区分 datetime/timestamp；column_type 区分 datetime 与 datetime(6)；
-- datetime_precision 给出小数秒精度（0=秒，6=微秒）；verdict 直接给出人工判定。
SELECT column_name, data_type, column_type, datetime_precision, is_nullable,
       CASE
         WHEN data_type = 'timestamp' THEN 'RISK_TIMESTAMP(时区/2038语义，须人工确认)'
         WHEN data_type = 'datetime' AND datetime_precision > 0
           THEN 'RISK_FRACTIONAL(02 MODIFY秒级会截断小数秒)'
         WHEN data_type = 'datetime' AND datetime_precision = 0 THEN 'OK_SECOND_DATETIME'
         ELSE 'OTHER_REVIEW'
       END AS verdict
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 't_ent_resume_snapshot'
  AND column_name IN ('ers_snapshot_at','ers_created_at')
ORDER BY column_name;
