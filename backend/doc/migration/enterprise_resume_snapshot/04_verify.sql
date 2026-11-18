-- =====================================================
-- 项目：Intelligent-Interviewer-System
-- 模块：E-App 企业投递简历独立存储
-- 文件用途：迁移后只读校验数量、状态合法性、关联完整性、子表完整性与回滚一致性，不做任何写入
-- 执行环境：需由用户核实目标库
-- 执行前提：已执行 03_backfill.sql；文件迁移程序跑完后可再次执行复核
-- 涉及数据表：t_app_record、t_tal、t_ent_resume_snapshot 及 4 张子表、
--             t_res_base 及子表、t_ai_candidate_analysis
-- 数据影响：只读（无 DDL / DML），全部为 SELECT
-- 是否可重复执行：是
-- 口径说明（与迁移策略保持一致）：
--   1) 历史快照即使升级为 COMPLETE+MANUAL_VERIFIED，仍纳入历史子表完整性检查，不退出；
--   2) LIVE_ORIGINAL 实时快照单独核验，不与历史口径混用；
--   3) MATCHED 必须具备有效绑定；UNVERIFIED 允许保持待核实，不能伪装 MATCHED；
--   4) MISSING_SOURCE 是合法状态，仅指“结构化源缺失”：核对其 version_verified 必须为空（未核实），
--      但 file_path 允许非空（源缺失前已独立归档的 PDF），不要求其无文件；
--   5) 标注“应无输出”的检查出现任何行都代表真实异常，需先排查再推进。
-- 执行权限：仅用户审核批准后手动执行
-- =====================================================

-- -----------------------------------------------------
-- 校验 1：投递总数 vs 快照总数（理想 gap=0，每条投递一个快照）
-- 若存在孤儿投递（校验5），其无法建快照，gap 会大于 0，属真实异常。
-- -----------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM t_app_record) AS app_total,
  (SELECT COUNT(*) FROM t_ent_resume_snapshot) AS snapshot_total,
  (SELECT COUNT(*) FROM t_app_record) - (SELECT COUNT(*) FROM t_ent_resume_snapshot) AS gap_should_be_zero;

-- -----------------------------------------------------
-- 校验 2：快照状态分布
-- COMPLETE 完整可用；REBUILT_UNVERIFIED 待文件迁移/人工核实；MISSING_SOURCE 结构化源缺失（合法，PDF 可独立留存）。
-- -----------------------------------------------------
SELECT ers_snapshot_status, COUNT(*) AS cnt
FROM t_ent_resume_snapshot
GROUP BY ers_snapshot_status
ORDER BY ers_snapshot_status;

-- -----------------------------------------------------
-- 校验 3：重复 app_id（应无输出；uk_ers_app 已在库内强制，这里二次核对）
-- -----------------------------------------------------
SELECT ers_app_id, COUNT(*) AS cnt
FROM t_ent_resume_snapshot
GROUP BY ers_app_id
HAVING COUNT(*) > 1;

-- -----------------------------------------------------
-- 校验 4：孤立快照（快照 app_id 在投递表不存在，应无输出）
-- -----------------------------------------------------
SELECT s.ers_id, s.ers_app_id
FROM t_ent_resume_snapshot s
LEFT JOIN t_app_record a ON a.app_id = s.ers_app_id
WHERE a.app_id IS NULL;

-- -----------------------------------------------------
-- 校验 5：孤儿投递（候选人在 t_tal 不存在，应无输出）
-- 03 步骤1 对 t_tal 为 INNER JOIN，这类投递会被跳过；如有输出须先人工处理再补建快照。
-- -----------------------------------------------------
SELECT a.app_id, a.app_candidate_id, a.app_position_id
FROM t_app_record a
LEFT JOIN t_tal t ON t.tal_id = a.app_candidate_id
WHERE t.tal_id IS NULL;

-- -----------------------------------------------------
-- 校验 6：状态码合法性（逐项，应无输出）
-- -----------------------------------------------------
-- 6.1 快照状态必须在三态内
SELECT ers_id, ers_snapshot_status
FROM t_ent_resume_snapshot
WHERE ers_snapshot_status NOT IN ('COMPLETE','REBUILT_UNVERIFIED','MISSING_SOURCE');

-- 6.2 版本核实值必须在 LIVE_ORIGINAL/MANUAL_VERIFIED 或 NULL
SELECT ers_id, ers_version_verified
FROM t_ent_resume_snapshot
WHERE ers_version_verified IS NOT NULL
  AND ers_version_verified NOT IN ('LIVE_ORIGINAL','MANUAL_VERIFIED');

-- 6.3 时间来源必须在三值内
SELECT ers_id, ers_time_source
FROM t_ent_resume_snapshot
WHERE ers_time_source NOT IN ('LIVE_REAL','BACKFILL_REAL','BACKFILL_UNKNOWN');

-- 6.4 AI 版本状态必须在 MATCHED/UNVERIFIED 或 NULL
SELECT asr_company_id, asr_position_id, asr_candidate_id, asr_version_status
FROM t_ai_candidate_analysis
WHERE asr_version_status IS NOT NULL
  AND asr_version_status NOT IN ('MATCHED','UNVERIFIED');

-- 6.5 AI 来源合法性：历史来源回填后必须为 llm/manual/unknown 之一（应无输出）
-- NULL 说明来源识别未覆盖；非法值说明被写入未定义枚举，二者均为异常。
-- 注意 unknown 是合法状态（历史来源无法确认），不阻止迁移；不允许用默认 llm 掩盖缺失。
SELECT asr_company_id, asr_position_id, asr_candidate_id, asr_source
FROM t_ai_candidate_analysis
WHERE asr_source IS NULL
   OR asr_source NOT IN ('llm','manual','unknown');

-- -----------------------------------------------------
-- 校验 7：主表 状态/版本/时间/PDF 一致性（应无输出）
-- 三个独立概念，不得互相推断：
--   A 结构化来源 ers_snapshot_status：原 C-App 结构化简历是否存在/可恢复；
--   B PDF 文件   ers_file_path：仅证明有企业独立 PDF“引用”，不证明对象真实存在（对象是否存在须文件侧验证）；
--   C 原件真实性 ers_version_verified：LIVE_ORIGINAL/MANUAL_VERIFIED 才有原件结论，NULL 为未核实。
-- 规则：
--   COMPLETE          version_verified 非空且 file_path 非空；
--   REBUILT_UNVERIFIED / MISSING_SOURCE  version_verified 为空（未核实）；
--   MISSING_SOURCE 仅表示“结构化源缺失”，其 file_path 允许非空（源缺失前已独立归档的 PDF，合法，见校验12）；
--   BACKFILL_UNKNOWN   snapshot_at 必须为空；LIVE_REAL/BACKFILL_REAL snapshot_at 必须非空。
-- -----------------------------------------------------
SELECT ers_id, ers_snapshot_status, ers_version_verified, ers_time_source, ers_snapshot_at,
       CASE WHEN ers_file_path IS NULL THEN 'NO_FILE' ELSE 'HAS_FILE' END AS file_state
FROM t_ent_resume_snapshot
WHERE (ers_snapshot_status = 'COMPLETE'
        AND (ers_version_verified IS NULL OR ers_file_path IS NULL))
   OR (ers_snapshot_status IN ('REBUILT_UNVERIFIED','MISSING_SOURCE')
        AND ers_version_verified IS NOT NULL)
   OR (ers_time_source = 'BACKFILL_UNKNOWN' AND ers_snapshot_at IS NOT NULL)
   OR (ers_time_source IN ('LIVE_REAL','BACKFILL_REAL') AND ers_snapshot_at IS NULL);

-- -----------------------------------------------------
-- 校验 7.5：时间来源与证据一致性（应无输出；旧版升级后重点核对，全部 SELECT 只读）
-- 覆盖：time_source 残留 NULL；LIVE_REAL 缺 LIVE_ORIGINAL 证据；LIVE_ORIGINAL 非 LIVE_REAL/COMPLETE；
--       BACKFILL_REAL 时间为空；BACKFILL_UNKNOWN 时间非空。
-- -----------------------------------------------------
SELECT z.ers_id, z.ers_snapshot_status, z.ers_version_verified, z.ers_time_source,
       z.ers_snapshot_at, z.reason
FROM (
  SELECT ers_id, ers_snapshot_status, ers_version_verified, ers_time_source, ers_snapshot_at,
    CASE
      WHEN ers_time_source IS NULL THEN 'TIME_SOURCE_NULL'
      WHEN ers_time_source = 'LIVE_REAL'
       AND (ers_version_verified IS NULL OR ers_version_verified <> 'LIVE_ORIGINAL')
        THEN 'LIVE_REAL_WITHOUT_LIVE_ORIGINAL'
      WHEN ers_version_verified = 'LIVE_ORIGINAL'
       AND (ers_time_source <> 'LIVE_REAL' OR ers_snapshot_status <> 'COMPLETE')
        THEN 'LIVE_ORIGINAL_NOT_REAL_COMPLETE'
      WHEN ers_time_source = 'BACKFILL_REAL' AND ers_snapshot_at IS NULL
        THEN 'BACKFILL_REAL_TIME_NULL'
      WHEN ers_time_source = 'BACKFILL_UNKNOWN' AND ers_snapshot_at IS NOT NULL
        THEN 'BACKFILL_UNKNOWN_TIME_NOT_NULL'
      ELSE 'OK'
    END AS reason
  FROM t_ent_resume_snapshot
) z
WHERE z.reason <> 'OK';

-- -----------------------------------------------------
-- 校验 8：历史简历子表“记录数量”一致性校验（覆盖全部历史，含已升级 MANUAL_VERIFIED；只输出差异，应无输出）
-- 历史范围：version_verified 为空(未核实) 或 =MANUAL_VERIFIED(已核实)，且非 MISSING_SOURCE。
-- 重要：本项只核对源与目标的“记录条数”相等，数量一致不代表字段内容完全一致
--      （如源为 Java/Python、快照为 Java/Go，数量相同但内容不同）；字段级差异见校验 8.5。
-- 迁移刚完成时数量应无差异；若后续源简历被改会出现差异，作为“版本漂移”提醒，不代表迁移失败。
-- -----------------------------------------------------
-- 8.1 教育
SELECT x.ers_id, x.src_cnt, x.snap_cnt, (x.src_cnt - x.snap_cnt) AS diff
FROM (
  SELECT s.ers_id,
    (SELECT COUNT(*) FROM t_res_education e WHERE e.edu_resume_id = s.ers_source_resume_id) AS src_cnt,
    (SELECT COUNT(*) FROM t_ent_resume_education e2 WHERE e2.ere_snapshot_id = s.ers_id) AS snap_cnt
  FROM t_ent_resume_snapshot s
  WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
    AND s.ers_snapshot_status <> 'MISSING_SOURCE'
) x
WHERE x.src_cnt <> x.snap_cnt;

-- 8.2 工作
SELECT x.ers_id, x.src_cnt, x.snap_cnt, (x.src_cnt - x.snap_cnt) AS diff
FROM (
  SELECT s.ers_id,
    (SELECT COUNT(*) FROM t_res_work w WHERE w.wrk_resume_id = s.ers_source_resume_id) AS src_cnt,
    (SELECT COUNT(*) FROM t_ent_resume_work w2 WHERE w2.erw_snapshot_id = s.ers_id) AS snap_cnt
  FROM t_ent_resume_snapshot s
  WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
    AND s.ers_snapshot_status <> 'MISSING_SOURCE'
) x
WHERE x.src_cnt <> x.snap_cnt;

-- 8.3 项目
SELECT x.ers_id, x.src_cnt, x.snap_cnt, (x.src_cnt - x.snap_cnt) AS diff
FROM (
  SELECT s.ers_id,
    (SELECT COUNT(*) FROM t_res_project p WHERE p.prj_resume_id = s.ers_source_resume_id) AS src_cnt,
    (SELECT COUNT(*) FROM t_ent_resume_project p2 WHERE p2.erp_snapshot_id = s.ers_id) AS snap_cnt
  FROM t_ent_resume_snapshot s
  WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
    AND s.ers_snapshot_status <> 'MISSING_SOURCE'
) x
WHERE x.src_cnt <> x.snap_cnt;

-- 8.4 技能
SELECT x.ers_id, x.src_cnt, x.snap_cnt, (x.src_cnt - x.snap_cnt) AS diff
FROM (
  SELECT s.ers_id,
    (SELECT COUNT(*) FROM t_res_skill k WHERE k.skl_resume_id = s.ers_source_resume_id) AS src_cnt,
    (SELECT COUNT(*) FROM t_ent_resume_skill k2 WHERE k2.esk_snapshot_id = s.ers_id) AS snap_cnt
  FROM t_ent_resume_snapshot s
  WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
    AND s.ers_snapshot_status <> 'MISSING_SOURCE'
) x
WHERE x.src_cnt <> x.snap_cnt;

-- -----------------------------------------------------
-- 校验 8.5：历史子表“多重集(Multiset/Bag)”字段级差异（只读，应无输出）
-- 实现：行级 SHA-256 哈希 + 按哈希分组 COUNT，再双向回连核对出现次数。
--   1. 用 JSON_ARRAY 把一条记录的完整业务字段按固定顺序序列化：JSON 数组位置即字段边界（无拼接歧义），
--      JSON null 与 JSON "" 天然区分（NULL≠空串），字符串/TEXT 保留全部原始字符且自动转义，长 TEXT 不截断；
--   2. CONVERT(... USING utf8mb4) COLLATE utf8mb4_bin 后再 SHA2(...,256)，得到字节级、大小写/全半角/首尾空格敏感的定长哈希；
--      日期用 date_format、数字 CAST AS CHAR 固定表示，避免类型隐式转换差异；
--   3. 分组键为“简历关联ID + 定长哈希(64字符)”，不再直接对 TEXT 做 GROUP BY，
--      从而规避 max_sort_length 只比较 TEXT 前若干字节、以及 utf8mb4_unicode_ci 忽略大小写/空格两大问题；
--   4. 两侧按哈希回连，方向化 > 判定，每个差异只报一次，重复行分布错误（如 Java/Java/Python vs Java/Python/Python）可准确检出。
-- 碰撞边界：SHA-256 为密码学哈希，碰撞概率约 2^-128 量级、工程上可忽略，但非数学上绝对零碰撞；
--   哈希输入已含全部业务字段，不另做语义归一。需要绝对零碰撞时可在哈希相等后再对原字段 <=> 复核（本文件默认不展开）。
-- 与校验8 关系：校验8 看每快照子表总条数，8.5 看每个行哈希的计数，二者必须同时通过，不能只看总数或成员存在。
-- 比较口径与 03 步骤2 复制的业务字段一致（不含自增 id、snapshot_id、created_at）。
-- -----------------------------------------------------
-- 8.5.1 教育：SRC_SIDE（源行哈希在快照缺失，或该哈希源计数 > 快照计数）
SELECT s.ers_id, 'EDU' AS tbl, 'SRC_SIDE' AS side,
       g.hh AS row_hash, g.cnt_src, COALESCE(h.cnt_snap,0) AS cnt_snap
FROM t_ent_resume_snapshot s
JOIN (
  SELECT e.edu_resume_id AS rid,
         SHA2(CONVERT(JSON_ARRAY(
           e.edu_school, e.edu_major, CAST(e.edu_degree AS CHAR),
           date_format(e.edu_start_date,'%Y%m%d'), date_format(e.edu_end_date,'%Y%m%d'),
           CAST(e.edu_gpa AS CHAR), e.edu_description
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_src
  FROM t_res_education e
  GROUP BY e.edu_resume_id, hh
) g ON g.rid = s.ers_source_resume_id
LEFT JOIN (
  SELECT x.ere_snapshot_id AS sid,
         SHA2(CONVERT(JSON_ARRAY(
           x.ere_school, x.ere_major, CAST(x.ere_degree AS CHAR),
           date_format(x.ere_start_date,'%Y%m%d'), date_format(x.ere_end_date,'%Y%m%d'),
           CAST(x.ere_gpa AS CHAR), x.ere_description
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_snap
  FROM t_ent_resume_education x
  GROUP BY x.ere_snapshot_id, hh
) h ON h.sid = s.ers_id AND h.hh = g.hh
WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
  AND s.ers_snapshot_status <> 'MISSING_SOURCE'
  AND (h.sid IS NULL OR g.cnt_src > h.cnt_snap);
-- 8.5.1b 教育：SNAP_SIDE（快照行哈希在源缺失，或快照计数 > 源计数）
SELECT s.ers_id, 'EDU' AS tbl, 'SNAP_SIDE' AS side,
       h.hh AS row_hash, COALESCE(g.cnt_src,0) AS cnt_src, h.cnt_snap
FROM t_ent_resume_snapshot s
JOIN (
  SELECT x.ere_snapshot_id AS sid,
         SHA2(CONVERT(JSON_ARRAY(
           x.ere_school, x.ere_major, CAST(x.ere_degree AS CHAR),
           date_format(x.ere_start_date,'%Y%m%d'), date_format(x.ere_end_date,'%Y%m%d'),
           CAST(x.ere_gpa AS CHAR), x.ere_description
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_snap
  FROM t_ent_resume_education x
  GROUP BY x.ere_snapshot_id, hh
) h ON h.sid = s.ers_id
LEFT JOIN (
  SELECT e.edu_resume_id AS rid,
         SHA2(CONVERT(JSON_ARRAY(
           e.edu_school, e.edu_major, CAST(e.edu_degree AS CHAR),
           date_format(e.edu_start_date,'%Y%m%d'), date_format(e.edu_end_date,'%Y%m%d'),
           CAST(e.edu_gpa AS CHAR), e.edu_description
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_src
  FROM t_res_education e
  GROUP BY e.edu_resume_id, hh
) g ON g.rid = s.ers_source_resume_id AND h.hh = g.hh
WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
  AND s.ers_snapshot_status <> 'MISSING_SOURCE'
  AND (g.rid IS NULL OR h.cnt_snap > g.cnt_src);
-- 8.5.2 工作：SRC_SIDE（源行哈希缺失或源计数 > 快照计数）
SELECT s.ers_id, 'WORK' AS tbl, 'SRC_SIDE' AS side,
       g.hh AS row_hash, g.cnt_src, COALESCE(h.cnt_snap,0) AS cnt_snap
FROM t_ent_resume_snapshot s
JOIN (
  SELECT w.wrk_resume_id AS rid,
         SHA2(CONVERT(JSON_ARRAY(
           w.wrk_company, w.wrk_position, w.wrk_department, CAST(w.wrk_is_current AS CHAR),
           date_format(w.wrk_start_date,'%Y%m%d'), date_format(w.wrk_end_date,'%Y%m%d'),
           w.wrk_salary_range, w.wrk_description
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_src
  FROM t_res_work w
  GROUP BY w.wrk_resume_id, hh
) g ON g.rid = s.ers_source_resume_id
LEFT JOIN (
  SELECT x.erw_snapshot_id AS sid,
         SHA2(CONVERT(JSON_ARRAY(
           x.erw_company, x.erw_position, x.erw_department, CAST(x.erw_is_current AS CHAR),
           date_format(x.erw_start_date,'%Y%m%d'), date_format(x.erw_end_date,'%Y%m%d'),
           x.erw_salary_range, x.erw_description
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_snap
  FROM t_ent_resume_work x
  GROUP BY x.erw_snapshot_id, hh
) h ON h.sid = s.ers_id AND h.hh = g.hh
WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
  AND s.ers_snapshot_status <> 'MISSING_SOURCE'
  AND (h.sid IS NULL OR g.cnt_src > h.cnt_snap);
-- 8.5.2b 工作：SNAP_SIDE（快照行哈希缺失或快照计数 > 源计数）
SELECT s.ers_id, 'WORK' AS tbl, 'SNAP_SIDE' AS side,
       h.hh AS row_hash, COALESCE(g.cnt_src,0) AS cnt_src, h.cnt_snap
FROM t_ent_resume_snapshot s
JOIN (
  SELECT x.erw_snapshot_id AS sid,
         SHA2(CONVERT(JSON_ARRAY(
           x.erw_company, x.erw_position, x.erw_department, CAST(x.erw_is_current AS CHAR),
           date_format(x.erw_start_date,'%Y%m%d'), date_format(x.erw_end_date,'%Y%m%d'),
           x.erw_salary_range, x.erw_description
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_snap
  FROM t_ent_resume_work x
  GROUP BY x.erw_snapshot_id, hh
) h ON h.sid = s.ers_id
LEFT JOIN (
  SELECT w.wrk_resume_id AS rid,
         SHA2(CONVERT(JSON_ARRAY(
           w.wrk_company, w.wrk_position, w.wrk_department, CAST(w.wrk_is_current AS CHAR),
           date_format(w.wrk_start_date,'%Y%m%d'), date_format(w.wrk_end_date,'%Y%m%d'),
           w.wrk_salary_range, w.wrk_description
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_src
  FROM t_res_work w
  GROUP BY w.wrk_resume_id, hh
) g ON g.rid = s.ers_source_resume_id AND h.hh = g.hh
WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
  AND s.ers_snapshot_status <> 'MISSING_SOURCE'
  AND (g.rid IS NULL OR h.cnt_snap > g.cnt_src);
-- 8.5.3 项目：SRC_SIDE（源行哈希缺失或源计数 > 快照计数）
SELECT s.ers_id, 'PROJ' AS tbl, 'SRC_SIDE' AS side,
       g.hh AS row_hash, g.cnt_src, COALESCE(h.cnt_snap,0) AS cnt_snap
FROM t_ent_resume_snapshot s
JOIN (
  SELECT p.prj_resume_id AS rid,
         SHA2(CONVERT(JSON_ARRAY(
           p.prj_name, p.prj_role,
           date_format(p.prj_start_date,'%Y%m%d'), date_format(p.prj_end_date,'%Y%m%d'),
           p.prj_description, p.prj_tech_stack
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_src
  FROM t_res_project p
  GROUP BY p.prj_resume_id, hh
) g ON g.rid = s.ers_source_resume_id
LEFT JOIN (
  SELECT x.erp_snapshot_id AS sid,
         SHA2(CONVERT(JSON_ARRAY(
           x.erp_name, x.erp_role,
           date_format(x.erp_start_date,'%Y%m%d'), date_format(x.erp_end_date,'%Y%m%d'),
           x.erp_description, x.erp_tech_stack
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_snap
  FROM t_ent_resume_project x
  GROUP BY x.erp_snapshot_id, hh
) h ON h.sid = s.ers_id AND h.hh = g.hh
WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
  AND s.ers_snapshot_status <> 'MISSING_SOURCE'
  AND (h.sid IS NULL OR g.cnt_src > h.cnt_snap);
-- 8.5.3b 项目：SNAP_SIDE（快照行哈希缺失或快照计数 > 源计数）
SELECT s.ers_id, 'PROJ' AS tbl, 'SNAP_SIDE' AS side,
       h.hh AS row_hash, COALESCE(g.cnt_src,0) AS cnt_src, h.cnt_snap
FROM t_ent_resume_snapshot s
JOIN (
  SELECT x.erp_snapshot_id AS sid,
         SHA2(CONVERT(JSON_ARRAY(
           x.erp_name, x.erp_role,
           date_format(x.erp_start_date,'%Y%m%d'), date_format(x.erp_end_date,'%Y%m%d'),
           x.erp_description, x.erp_tech_stack
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_snap
  FROM t_ent_resume_project x
  GROUP BY x.erp_snapshot_id, hh
) h ON h.sid = s.ers_id
LEFT JOIN (
  SELECT p.prj_resume_id AS rid,
         SHA2(CONVERT(JSON_ARRAY(
           p.prj_name, p.prj_role,
           date_format(p.prj_start_date,'%Y%m%d'), date_format(p.prj_end_date,'%Y%m%d'),
           p.prj_description, p.prj_tech_stack
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_src
  FROM t_res_project p
  GROUP BY p.prj_resume_id, hh
) g ON g.rid = s.ers_source_resume_id AND h.hh = g.hh
WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
  AND s.ers_snapshot_status <> 'MISSING_SOURCE'
  AND (g.rid IS NULL OR h.cnt_snap > g.cnt_src);
-- 8.5.4 技能：SRC_SIDE（源行哈希缺失或源计数 > 快照计数）
SELECT s.ers_id, 'SKILL' AS tbl, 'SRC_SIDE' AS side,
       g.hh AS row_hash, g.cnt_src, COALESCE(h.cnt_snap,0) AS cnt_snap
FROM t_ent_resume_snapshot s
JOIN (
  SELECT k.skl_resume_id AS rid,
         SHA2(CONVERT(JSON_ARRAY(
           k.skl_name, CAST(k.skl_level AS CHAR)
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_src
  FROM t_res_skill k
  GROUP BY k.skl_resume_id, hh
) g ON g.rid = s.ers_source_resume_id
LEFT JOIN (
  SELECT x.esk_snapshot_id AS sid,
         SHA2(CONVERT(JSON_ARRAY(
           x.esk_name, CAST(x.esk_level AS CHAR)
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_snap
  FROM t_ent_resume_skill x
  GROUP BY x.esk_snapshot_id, hh
) h ON h.sid = s.ers_id AND h.hh = g.hh
WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
  AND s.ers_snapshot_status <> 'MISSING_SOURCE'
  AND (h.sid IS NULL OR g.cnt_src > h.cnt_snap);
-- 8.5.4b 技能：SNAP_SIDE（快照行哈希缺失或快照计数 > 源计数）
SELECT s.ers_id, 'SKILL' AS tbl, 'SNAP_SIDE' AS side,
       h.hh AS row_hash, COALESCE(g.cnt_src,0) AS cnt_src, h.cnt_snap
FROM t_ent_resume_snapshot s
JOIN (
  SELECT x.esk_snapshot_id AS sid,
         SHA2(CONVERT(JSON_ARRAY(
           x.esk_name, CAST(x.esk_level AS CHAR)
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_snap
  FROM t_ent_resume_skill x
  GROUP BY x.esk_snapshot_id, hh
) h ON h.sid = s.ers_id
LEFT JOIN (
  SELECT k.skl_resume_id AS rid,
         SHA2(CONVERT(JSON_ARRAY(
           k.skl_name, CAST(k.skl_level AS CHAR)
         ) USING utf8mb4) COLLATE utf8mb4_bin, 256) AS hh,
         COUNT(*) AS cnt_src
  FROM t_res_skill k
  GROUP BY k.skl_resume_id, hh
) g ON g.rid = s.ers_source_resume_id AND h.hh = g.hh
WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified = 'MANUAL_VERIFIED')
  AND s.ers_snapshot_status <> 'MISSING_SOURCE'
  AND (g.rid IS NULL OR h.cnt_snap > g.cnt_src);

-- -----------------------------------------------------
-- 校验 9：LIVE_ORIGINAL 实时快照单独核验（应无输出）
-- 9.1~9.4 子表孤儿行：子表 snapshot_id 在主表不存在（四类，应无输出）
-- -----------------------------------------------------
SELECT e.ere_id, e.ere_snapshot_id
FROM t_ent_resume_education e
LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = e.ere_snapshot_id
WHERE s.ers_id IS NULL;

SELECT w.erw_id, w.erw_snapshot_id
FROM t_ent_resume_work w
LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = w.erw_snapshot_id
WHERE s.ers_id IS NULL;

SELECT p.erp_id, p.erp_snapshot_id
FROM t_ent_resume_project p
LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = p.erp_snapshot_id
WHERE s.ers_id IS NULL;

SELECT k.esk_id, k.esk_snapshot_id
FROM t_ent_resume_skill k
LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = k.esk_snapshot_id
WHERE s.ers_id IS NULL;

-- 9.5 实时快照特征：LIVE_ORIGINAL 必须 COMPLETE、LIVE_REAL、时间非空、PDF 存在（应无输出）
SELECT ers_id, ers_snapshot_status, ers_time_source, ers_version_verified
FROM t_ent_resume_snapshot
WHERE ers_version_verified = 'LIVE_ORIGINAL'
  AND (ers_snapshot_status <> 'COMPLETE' OR ers_time_source <> 'LIVE_REAL'
       OR ers_snapshot_at IS NULL OR ers_file_path IS NULL);

-- -----------------------------------------------------
-- 校验 10：AI 与 snapshot_id/app_id 关联完整性（应无输出）
-- -----------------------------------------------------
-- 10.1 MATCHED 但缺少绑定
SELECT asr_company_id, asr_position_id, asr_candidate_id
FROM t_ai_candidate_analysis
WHERE asr_version_status = 'MATCHED'
  AND (asr_app_id IS NULL OR asr_snapshot_id IS NULL);

-- 10.2 MATCHED 绑定指向不存在的投递/快照
SELECT r.asr_company_id, r.asr_position_id, r.asr_candidate_id
FROM t_ai_candidate_analysis r
LEFT JOIN t_app_record a ON a.app_id = r.asr_app_id
LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = r.asr_snapshot_id
WHERE r.asr_version_status = 'MATCHED'
  AND (a.app_id IS NULL OR s.ers_id IS NULL);

-- 10.3 MATCHED 三元组与绑定快照不一致（企业/岗位/候选人三个维度）
SELECT r.asr_company_id, r.asr_position_id, r.asr_candidate_id
FROM t_ai_candidate_analysis r
JOIN t_ent_resume_snapshot s ON s.ers_id = r.asr_snapshot_id
WHERE r.asr_version_status = 'MATCHED'
  AND (s.ers_company_id <> r.asr_company_id
       OR s.ers_position_id <> r.asr_position_id
       OR s.ers_candidate_id <> r.asr_candidate_id);

-- 10.4 绑定不成对：app_id 与 snapshot_id 一个为空另一个非空
SELECT asr_company_id, asr_position_id, asr_candidate_id
FROM t_ai_candidate_analysis
WHERE (asr_app_id IS NULL) <> (asr_snapshot_id IS NULL);

-- 10.5 全量已绑定行关联完整性（覆盖所有 snapshot_id 非空的行，含 MATCHED 与 UNVERIFIED；应无输出）
-- 相比 10.1~10.3 仅针对 MATCHED，本项不区分版本状态，并新增关键校验 app_id 必须等于该快照 ers_app_id，
-- 防止 AI 分析绑定到错误投递；UNVERIFIED 允许保留待核实，但不能存在错误绑定。
SELECT r.asr_company_id, r.asr_position_id, r.asr_candidate_id,
       r.asr_app_id, r.asr_snapshot_id, s.ers_app_id
FROM t_ai_candidate_analysis r
LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = r.asr_snapshot_id
WHERE r.asr_snapshot_id IS NOT NULL
  AND (
        s.ers_id IS NULL
     OR r.asr_app_id IS NULL
     OR s.ers_app_id <> r.asr_app_id
     OR s.ers_company_id <> r.asr_company_id
     OR s.ers_position_id <> r.asr_position_id
     OR s.ers_candidate_id <> r.asr_candidate_id
      );

-- -----------------------------------------------------
-- 校验 11：AI 来源分布与待人工核实清单
-- -----------------------------------------------------
-- 11.1 来源 × 版本状态分布
SELECT asr_source, COALESCE(asr_version_status, 'NULL') AS version_status, COUNT(*) AS cnt
FROM t_ai_candidate_analysis
GROUP BY asr_source, asr_version_status
ORDER BY asr_source, version_status;

-- 11.2 待人工核实清单（合法队列，非异常）：UNVERIFIED、未关联或来源 unknown
SELECT asr_company_id, asr_position_id, asr_candidate_id, asr_source,
       asr_version_status, asr_app_id, asr_snapshot_id
FROM t_ai_candidate_analysis
WHERE asr_version_status = 'UNVERIFIED' OR asr_snapshot_id IS NULL OR asr_source = 'unknown'
ORDER BY asr_company_id, asr_position_id, asr_candidate_id;

-- -----------------------------------------------------
-- 校验 12：PDF 状态——DB 侧“暂定分类”分布（只读统计，非最终分类）
-- 关键边界（务必遵守）：
--   1) 本查询只读取数据库字段，不访问对象存储，因此输出的 db_provisional_class 仅是“暂定分类”，
--      不能作为文件已复制/已归档/已核实的证据；
--   2) ers_file_path 非空只代表有 DB 引用，不证明 target 对象真实存在；
--      任何含 file_path 的暂定类，必须经文件清单确认 target_exists=TRUE 且 source/target 哈希一致，
--      才能转为最终分类；若文件清单 target_exists=FALSE，该暂定类作废并按文件侧实际结果重分类；
--   3) 原件真实性独立看 ers_version_verified，复制成功不自动升级 MANUAL_VERIFIED；
--      最终五分类 + LIVE 桶以《文件清单验证机制》的 final_classification 为准。
-- 暂定桶（与最终五分类同名但语义为“待文件核验”）：
--   RECOVERABLE_PENDING / COPIED_UNVERIFIED / COPIED_AND_VERIFIED /
--   SOURCE_MISSING_NO_FILE / SOURCE_MISSING_BUT_ARCHIVED，及实时桶 LIVE_ORIGINAL_COMPLETE。
-- -----------------------------------------------------
SELECT
  CASE
    WHEN ers_snapshot_status = 'COMPLETE' AND ers_version_verified = 'LIVE_ORIGINAL'
      THEN 'LIVE_ORIGINAL_COMPLETE'
    WHEN ers_snapshot_status = 'MISSING_SOURCE' AND ers_file_path IS NOT NULL
      THEN 'SOURCE_MISSING_BUT_ARCHIVED'   -- 暂定：须文件清单确认 target_exists=TRUE
    WHEN ers_snapshot_status = 'MISSING_SOURCE'
      THEN 'SOURCE_MISSING_NO_FILE'
    WHEN ers_file_path IS NULL
      THEN 'RECOVERABLE_PENDING'
    WHEN ers_version_verified = 'MANUAL_VERIFIED'
      THEN 'COPIED_AND_VERIFIED'          -- 暂定：仍须文件清单确认对象存在
    ELSE 'COPIED_UNVERIFIED'              -- 暂定：须文件清单确认 target_exists=TRUE
  END AS db_provisional_class,
  COUNT(*) AS cnt
FROM t_ent_resume_snapshot
GROUP BY db_provisional_class
ORDER BY db_provisional_class;

-- 校验 12b：DB 有 PDF 引用、但对象存储是否存在无法仅凭数据库判定（待文件侧验证清单）。
--   下列为“需要对象侧核对”的引用清单（仅取 ID 与路径，不读取简历正文）；
--   须逐条与文件清单的 target_exists/target_sha256 比对，对象实际缺失者进入人工处理清单，不伪造。
SELECT ers_id, ers_file_path, ers_file_name
FROM t_ent_resume_snapshot
WHERE ers_file_path IS NOT NULL
ORDER BY ers_id;

-- =====================================================
-- 两阶段验收口径（与《手动迁移执行手册》判定标准完全一致）
--
-- 【阶段 A：迁移时一致性】在迁移当时、源简历仍可读取时执行，证明“相对迁移时读到的源数据复制正确”，
--   不能证明是最早投递时的历史原件。需满足：
--   校验1 gap=0（或与校验5 孤儿对应并已处理）；校验3/4/5/6/7/9/10 无输出；
--   校验6.5 来源均为 llm/manual/unknown（unknown 合法，NULL/非法值为异常）；
--   校验7.5 时间来源与证据一致（无 NULL、LIVE_REAL 必有 LIVE_ORIGINAL、回填时间空/非空匹配）；
--   校验8 历史子表记录数量无差异；校验8.5 多重集字段级差异为空（每个字段组合计数一致，含重复分布）；
--   校验9 实时快照特征正确；校验10.5 已绑定行关联正确且 app_id=ers_app_id；
--   校验11.2 为待人工处理队列，历史未核实项允许长期保留；
--   校验12 PDF 五分类落账，合法历史缺失(SOURCE_MISSING/未处理)不阻止迁移，仅 COPIED_AND_VERIFIED 为原件已核实。
--
-- 【阶段 B：上线后独立性】上线后不再要求快照恒等于 C-App 当前简历；源后续变化导致的 8/8.5 差异
--   属正常“版本漂移”，不判损坏。应核对：
--   快照仍存在且能按 app_id 精确查询；企业 PDF 指向企业独立存储；内容未被意外修改（如需可在阶段A 留存基线哈希）；
--   子表与主表关联正确；AI 分析与快照一致；C-App 编辑/删除后 E-App 数据保持不变。
--
-- 阶段 A 全部满足后再进入上线联调；阶段 B 作为上线后验收与长期巡检口径。
-- =====================================================
