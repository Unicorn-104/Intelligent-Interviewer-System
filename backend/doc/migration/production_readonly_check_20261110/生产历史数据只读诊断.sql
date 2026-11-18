-- =====================================================================
-- 生产历史数据只读诊断.sql
-- 用途：正式迁移前盘点现有数据规模、来源、重复、引用完整性与 PDF 可恢复性。
-- 安全：仅含 SELECT；无写入/DDL/动态执行，不自动修复任何异常。
-- 执行提示：
--   1) t_ai_candidate_analysis、t_app_record、t_res_base 为现有表，可直接执行；
--   2) 标注“快照五表建立后执行”的段落，若表尚未创建请跳过，避免报表不存在；
--   3) 源表真实 DDL 部分缺失，t_res_base 字段基于已知引用，若实际字段名不同需人工调整。
-- =====================================================================

-- 0.0 执行前确认当前数据库（防止误在其他库执行；预期为目标库名，若不符立即停止）
SELECT DATABASE() AS current_database;

-- 2.1 AI 分析记录总数（基线规模；用于核对迁移前后行数）
-- 预期：返回当前总行数，人工记录该数值。
SELECT COUNT(*) AS ai_total_rows FROM t_ai_candidate_analysis;

-- 2.2 AI 来源分布（口径A：派生列 asr_source）
-- 执行条件：仅在 02 加列完成后执行；未加列时该列不存在，执行会报表不存在，请跳过本段改用 2.3。
-- 预期：llm/manual/unknown/NULL 各自计数；NULL 表示尚未由 03 识别。
-- 异常判定：存在大量 NULL 或异常值需人工确认，禁止默认归类 llm。
SELECT COALESCE(asr_source, 'NULL') AS asr_source, COUNT(*) AS cnt
FROM t_ai_candidate_analysis
GROUP BY asr_source
ORDER BY asr_source;

-- 2.3 AI 来源分布（口径B：直接从 JSON 报告提取，原始表也可执行；与 2.2 交叉核对）
-- 预期：JSON 内 $.source 为 llm/manual，缺失为 unknown。
SELECT COALESCE(json_unquote(json_extract(asr_report, '$.source')), 'unknown') AS report_source,
       COUNT(*) AS cnt
FROM t_ai_candidate_analysis
GROUP BY report_source
ORDER BY report_source;

-- 2.4 同三元组重复记录分布（cnt>1 即该组已存在多版本；原始复合主键下预期无重复）
-- 空结果语义：无行返回=无重复三元组；可对照 2.5 标量 duplicate_triple_groups=0 确认。
-- 异常判定：原始复合主键表若出现 cnt>1 理论不可能，出现即结构异常，标记 BLOCKED。
SELECT asr_company_id, asr_position_id, asr_candidate_id, COUNT(*) AS cnt
FROM t_ai_candidate_analysis
GROUP BY asr_company_id, asr_position_id, asr_candidate_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC, asr_company_id;

-- 2.5 重复三元组总数（单值；0=无重复，>0 需结合主键阶段判断）
SELECT COUNT(*) AS duplicate_triple_groups
FROM (
  SELECT asr_company_id, asr_position_id, asr_candidate_id
  FROM t_ai_candidate_analysis
  GROUP BY asr_company_id, asr_position_id, asr_candidate_id
  HAVING COUNT(*) > 1
) d;

-- 2.6 投递记录六态分布（NULL/合法0-5/负值/超范围分别识别；本查询不改六态，不再用 COALESCE 混淆 NULL 与 -1）
-- 异常判定：status_class 出现 NULL、ILLEGAL_NEGATIVE、ILLEGAL_OVER_5 均标记 BLOCKED，人工核对原始值。
SELECT
  CASE
    WHEN app_status IS NULL THEN 'NULL'
    WHEN app_status < 0 THEN 'ILLEGAL_NEGATIVE'
    WHEN app_status > 5 THEN 'ILLEGAL_OVER_5'
    ELSE 'LEGAL_0_5'
  END AS status_class,
  app_status AS raw_value,
  CASE app_status
    WHEN 0 THEN '已投递'
    WHEN 1 THEN '招聘中'
    WHEN 2 THEN '待发Offer'
    WHEN 3 THEN '待确认Offer'
    WHEN 4 THEN '已录用'
    WHEN 5 THEN '未录用'
    ELSE NULL
  END AS status_label,
  COUNT(*) AS cnt
FROM t_app_record
GROUP BY status_class, app_status
ORDER BY app_status;

-- 2.7 简历引用异常分布（引用为空 / 引用简历已不存在 / 正常）
-- 异常判定：异常项迁移后只能“待核实”，禁止伪造 PDF/Hash。
SELECT
  CASE
    WHEN a.app_resume_id IS NULL THEN '简历引用为空'
    WHEN b.rbs_id IS NULL THEN '引用简历已不存在'
    ELSE '引用正常'
  END AS missing_type,
  COUNT(*) AS cnt
FROM t_app_record a
LEFT JOIN t_res_base b ON b.rbs_id = a.app_resume_id
GROUP BY missing_type
ORDER BY missing_type;

-- 2.8 源简历软删状态分布（rbs_status=0 软删，文件引用可能已清空）
SELECT COALESCE(b.rbs_status, -1) AS rbs_status, COUNT(*) AS cnt
FROM t_app_record a
LEFT JOIN t_res_base b ON b.rbs_id = a.app_resume_id
GROUP BY b.rbs_status
ORDER BY b.rbs_status;

-- 2.9 同候选人+岗位重复投递（验证须以 app_id 精确绑定，不能用三元组反查）
-- 空结果语义：无行返回=不存在重复投递；有行则 cnt 为该组投递次数，须以 app_id 区分而非三元组反查。
SELECT app_candidate_id, app_position_id, COUNT(*) AS cnt
FROM t_app_record
GROUP BY app_candidate_id, app_position_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC, app_candidate_id;

-- 2.10 原始 PDF 路径为空的简历数（路径为空必然无原件；路径非空也不代表对象真实存在）
-- 注意：数据库只能判断路径字段，对象真实存在性须由受控文件核对程序确认。
SELECT COUNT(*) AS resume_path_null_count
FROM t_res_base
WHERE rbs_file_path IS NULL OR rbs_file_path = '';

-- 2.11 投递引用的简历中 PDF 路径缺失/简历缺失的记录数（无法直接读取原件的候选范围）
SELECT COUNT(*) AS app_without_readable_pdf
FROM t_app_record a
LEFT JOIN t_res_base b ON b.rbs_id = a.app_resume_id
WHERE b.rbs_id IS NULL
   OR b.rbs_file_path IS NULL
   OR b.rbs_file_path = '';

-- 2.12 历史记录时间缺失统计（先判字段是否存在，禁止把“字段不存在”误判为“全部时间缺失”；无动态 SQL）
-- 2.12a 字段存在性判定（一定可执行）：COLUMN_EXISTS 或 COLUMN_MISSING
SELECT 'rbs_created_at' AS column_name,
       CASE
         WHEN EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_schema = DATABASE() AND table_name = 't_res_base'
                         AND column_name = 'rbs_created_at')
           THEN 'COLUMN_EXISTS'
         ELSE 'COLUMN_MISSING'
       END AS column_status;

-- 2.12b 仅当 2.12a 输出 COLUMN_EXISTS 时执行；若为 COLUMN_MISSING 请跳过本段（否则会报表不存在）
-- 预期：返回 rbs_created_at 实际为 NULL 的行数；时间未知须保持未知，禁止用迁移时间伪造。
SELECT COUNT(*) AS rbs_created_at_null_count
FROM t_res_base
WHERE rbs_created_at IS NULL;

-- 2.13 历史简历与当前用户关联情况（按用户汇总其简历数，确认 rbs_user_id 可追溯）
SELECT rbs_user_id, COUNT(*) AS resume_count
FROM t_res_base
GROUP BY rbs_user_id
ORDER BY resume_count DESC, rbs_user_id;

-- 2.14 快照五表记录数（快照五表建立后执行；表未建则跳过本段）
-- 预期：主表与各子表数量，子表 snapshot_id 应能在主表找到。
SELECT 'snapshot' AS tbl, COUNT(*) AS cnt FROM t_ent_resume_snapshot
UNION ALL SELECT 'education', COUNT(*) FROM t_ent_resume_education
UNION ALL SELECT 'work', COUNT(*) FROM t_ent_resume_work
UNION ALL SELECT 'project', COUNT(*) FROM t_ent_resume_project
UNION ALL SELECT 'skill', COUNT(*) FROM t_ent_resume_skill;

-- 2.15 快照 app_id 关联完整性（建立后执行；孤儿=主表 ers_app_id 在投递表找不到）
-- 预期：orphan_count=0；>0 标记 WARNING 人工核对。
SELECT COUNT(*) AS snapshot_app_orphan_count
FROM t_ent_resume_snapshot s
LEFT JOIN t_app_record a ON a.app_id = s.ers_app_id
WHERE a.app_id IS NULL;

-- 2.16 快照子表 snapshot_id 关联完整性（建立后执行；逐表找孤儿，预期均 0）
SELECT 'education' AS tbl, COUNT(*) AS orphan_count
  FROM t_ent_resume_education c LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = c.ere_snapshot_id
 WHERE s.ers_id IS NULL
UNION ALL
SELECT 'work', COUNT(*)
  FROM t_ent_resume_work c LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = c.erw_snapshot_id
 WHERE s.ers_id IS NULL
UNION ALL
SELECT 'project', COUNT(*)
  FROM t_ent_resume_project c LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = c.erp_snapshot_id
 WHERE s.ers_id IS NULL
UNION ALL
SELECT 'skill', COUNT(*)
  FROM t_ent_resume_skill c LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = c.esk_snapshot_id
 WHERE s.ers_id IS NULL;

-- 2.17 快照中 PDF 路径为空或状态非 COMPLETE 的记录数（快照五表建立后执行；待核实范围，不自动修复）
SELECT COALESCE(ers_snapshot_status, 'NULL') AS snapshot_status,
       SUM(CASE WHEN ers_file_path IS NULL OR ers_file_path = '' THEN 1 ELSE 0 END) AS path_null_cnt,
       COUNT(*) AS cnt
FROM t_ent_resume_snapshot
GROUP BY ers_snapshot_status
ORDER BY ers_snapshot_status;
