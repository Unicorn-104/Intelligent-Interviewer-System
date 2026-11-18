-- =====================================================
-- 项目：Intelligent-Interviewer-System
-- 模块：E-App 企业投递简历独立存储
-- 文件用途：把历史投递按“现存数据”重建为企业快照，并回填分析表来源/版本关联
-- 执行环境：需由用户核实目标库
-- 执行前提：已执行 02_schema.sql；建议先在测试库演练
-- 涉及数据表：t_app_record、t_tal、t_res_base 及 4 张子表、
--             t_ent_resume_snapshot 及 4 张子表、t_ai_candidate_analysis
-- 数据影响：DML（INSERT 重建快照、UPDATE 分析关联）；不删除任何原始数据
-- 是否可重复执行：是（均以 NOT EXISTS / 未处理条件限定，幂等）
-- 回滚文件：05_rollback.sql
-- 风险说明：
--   1) PDF 无法用 SQL 复制，本脚本不伪造文件，企业文件引用一律置 NULL，
--      由配套“企业简历文件迁移程序”按本文件末尾清单复制；
--   2) 历史简历可能已被修改，重建快照统一标记 REBUILT_UNVERIFIED，不冒充投递时原始版本；
--   3) 简历缺失者标记 MISSING_SOURCE，仅保留关联、不编造内容；
--   4) 注意：PDF 复制成功只代表文件完整、可读，不代表原始投递版本已核实；
--      原件核实必须有独立可靠证据，见步骤 4 与文末异常检查。
-- 执行权限：仅用户审核批准后手动执行
-- =====================================================

-- -----------------------------------------------------
-- 步骤 1：为每条尚无快照的投递建立主表记录
-- 企业ID经 t_tal 取得；PDF 引用与内容哈希置 NULL（SQL 不伪造）
-- 边界：此处对 t_tal 使用 INNER JOIN，若某投递的候选人在 t_tal 已不存在（孤儿投递），
--       该投递不会被本步骤处理；请务必执行文末“异常检查 A”核对，避免静默遗漏。
-- -----------------------------------------------------
INSERT INTO t_ent_resume_snapshot
  (ers_app_id, ers_candidate_id, ers_company_id, ers_position_id, ers_source_resume_id,
   ers_resume_name, ers_job_direction, ers_file_path, ers_file_name, ers_file_size,
   ers_content_hash, ers_snapshot_status, ers_time_source, ers_snapshot_at)
SELECT
  a.app_id,
  a.app_candidate_id,
  t.tal_company_id,
  a.app_position_id,
  a.app_resume_id,
  b.rbs_resume_name,
  b.rbs_job_direction,
  NULL, NULL, NULL, NULL,
  CASE WHEN b.rbs_id IS NULL THEN 'MISSING_SOURCE' ELSE 'REBUILT_UNVERIFIED' END,
  -- 时间来源：有真实投递时间标 BACKFILL_REAL；缺失标 BACKFILL_UNKNOWN，snapshot_at 保留 NULL，不伪造
  CASE WHEN a.app_created_at IS NULL THEN 'BACKFILL_UNKNOWN' ELSE 'BACKFILL_REAL' END,
  a.app_created_at
FROM t_app_record a
JOIN t_tal t ON t.tal_id = a.app_candidate_id
LEFT JOIN t_res_base b ON b.rbs_id = a.app_resume_id
WHERE NOT EXISTS (
  SELECT 1 FROM t_ent_resume_snapshot s WHERE s.ers_app_id = a.app_id
);

-- -----------------------------------------------------
-- 步骤 2：回填 4 张结构化子表（仅对可重建快照，源经 ers_source_resume_id 关联）
-- 每段均判断目标快照尚无明细，保证可重复执行
-- -----------------------------------------------------
-- 2.1 教育经历
INSERT INTO t_ent_resume_education
  (ere_snapshot_id, ere_school, ere_major, ere_degree, ere_start_date, ere_end_date,
   ere_gpa, ere_description)
SELECT s.ers_id, e.edu_school, e.edu_major, e.edu_degree, e.edu_start_date, e.edu_end_date,
       e.edu_gpa, e.edu_description
FROM t_ent_resume_snapshot s
JOIN t_res_education e ON e.edu_resume_id = s.ers_source_resume_id
WHERE s.ers_snapshot_status = 'REBUILT_UNVERIFIED'
  AND NOT EXISTS (SELECT 1 FROM t_ent_resume_education x WHERE x.ere_snapshot_id = s.ers_id);

-- 2.2 工作经历
INSERT INTO t_ent_resume_work
  (erw_snapshot_id, erw_company, erw_position, erw_department, erw_start_date, erw_end_date,
   erw_is_current, erw_salary_range, erw_description)
SELECT s.ers_id, w.wrk_company, w.wrk_position, w.wrk_department, w.wrk_start_date, w.wrk_end_date,
       w.wrk_is_current, w.wrk_salary_range, w.wrk_description
FROM t_ent_resume_snapshot s
JOIN t_res_work w ON w.wrk_resume_id = s.ers_source_resume_id
WHERE s.ers_snapshot_status = 'REBUILT_UNVERIFIED'
  AND NOT EXISTS (SELECT 1 FROM t_ent_resume_work x WHERE x.erw_snapshot_id = s.ers_id);

-- 2.3 项目经历
INSERT INTO t_ent_resume_project
  (erp_snapshot_id, erp_name, erp_role, erp_start_date, erp_end_date,
   erp_description, erp_tech_stack)
SELECT s.ers_id, p.prj_name, p.prj_role, p.prj_start_date, p.prj_end_date,
       p.prj_description, p.prj_tech_stack
FROM t_ent_resume_snapshot s
JOIN t_res_project p ON p.prj_resume_id = s.ers_source_resume_id
WHERE s.ers_snapshot_status = 'REBUILT_UNVERIFIED'
  AND NOT EXISTS (SELECT 1 FROM t_ent_resume_project x WHERE x.erp_snapshot_id = s.ers_id);

-- 2.4 技能
INSERT INTO t_ent_resume_skill (esk_snapshot_id, esk_name, esk_level)
SELECT s.ers_id, k.skl_name, k.skl_level
FROM t_ent_resume_snapshot s
JOIN t_res_skill k ON k.skl_resume_id = s.ers_source_resume_id
WHERE s.ers_snapshot_status = 'REBUILT_UNVERIFIED'
  AND NOT EXISTS (SELECT 1 FROM t_ent_resume_skill x WHERE x.esk_snapshot_id = s.ers_id);

-- -----------------------------------------------------
-- 步骤 3：历史 AI 来源识别（先全量诊断、后回填；不默认归类 llm）
-- 前置：02 已让历史行 asr_source 初始为 NULL（或旧版曾错误默认 llm）；实时新行已有 llm/manual。
-- 全量诊断不预设 asr_source IS NULL，能发现旧版错误默认 llm 与 DB/JSON 冲突。
-- -----------------------------------------------------

-- 3.0 全量来源诊断：数据库字段 asr_source vs 报告 JSON $.source，覆盖全部行，分类统计
SELECT
  CASE
    WHEN asr_source = 'llm'    AND json_source = 'llm'    THEN 'MATCH_LLM'
    WHEN asr_source = 'manual' AND json_source = 'manual' THEN 'MATCH_MANUAL'
    WHEN asr_source = 'llm'    AND json_source = 'manual' THEN 'CONFLICT_DBLLM_JSONMANUAL'
    WHEN asr_source = 'manual' AND json_source = 'llm'    THEN 'CONFLICT_DBMANUAL_JSONLLM'
    WHEN asr_source IS NULL AND json_source IN ('llm','manual') THEN 'NULL_CAN_BACKFILL'
    WHEN asr_source IS NULL THEN 'NULL_TO_UNKNOWN'
    WHEN asr_source = 'unknown' AND json_source IN ('llm','manual') THEN 'UNKNOWN_BUT_JSON_EVIDENCE'
    WHEN asr_source = 'unknown' THEN 'UNKNOWN_KEPT'
    ELSE 'REVIEW_OTHER'
  END AS source_state,
  COUNT(*) AS cnt
FROM (
  SELECT asr_source,
         COALESCE(json_unquote(json_extract(asr_report, '$.source')), '__MISSING__') AS json_source
  FROM t_ai_candidate_analysis
) x
GROUP BY source_state
ORDER BY source_state;

-- 3.0b 来源冲突/待核实明细（人工审核清单）：仅输出，不自动覆盖；原始 asr_report 完整保留。
-- 禁止因 asr_source='llm' 就默认其为真实 AI；冲突行不得自动改，须人工核实后单独处理。
SELECT asr_company_id, asr_position_id, asr_candidate_id, asr_source, json_source
FROM (
  SELECT asr_company_id, asr_position_id, asr_candidate_id, asr_source,
         COALESCE(json_unquote(json_extract(asr_report, '$.source')), '__MISSING__') AS json_source
  FROM t_ai_candidate_analysis
) x
WHERE (asr_source = 'llm' AND json_source = 'manual')
   OR (asr_source = 'manual' AND json_source = 'llm')
   OR (asr_source IS NOT NULL AND asr_source NOT IN ('llm','manual','unknown'))
   OR (asr_source = 'unknown' AND json_source IN ('llm','manual'));

-- 3.0c 人工修复模板（本轮不执行；新架构同一企业/岗位/候选人可有多行，禁止用三元组定位，必须用真实主键）
-- 步骤0（只读，先执行）：确认分析表真实主键列名，不允许猜测。
--   预期返回单列；记下 COLUMN_NAME 用于替换下面的 `主键列`。若返回复合主键/多列/无主键，停止并改用人工方案。
SELECT kcu.column_name, kcu.ordinal_position
FROM information_schema.key_column_usage kcu
WHERE kcu.table_schema = DATABASE()
  AND kcu.table_name = 't_ai_candidate_analysis'
  AND kcu.constraint_name = 'PRIMARY'
ORDER BY kcu.ordinal_position;
-- 模板1：DB 标 llm 但 JSON 实为 manual，且已人工确认应改 manual。
--   先把 `主键列` 替换为步骤0 查到的真实列名，把“主键值”替换为该行主键值。
-- 1a 先 SELECT（应恰好返回 1 行，且 asr_source 确为 llm）：
-- SELECT `主键列`, asr_company_id, asr_position_id, asr_candidate_id, asr_source, asr_version_status
-- FROM t_ai_candidate_analysis
-- WHERE `主键列` = 主键值 AND asr_source = 'llm';
-- 1b 确认恰好 1 行后再 UPDATE（原值守卫，预期影响=1；影响 0 或 >1 立即停止，禁止继续）：
-- UPDATE t_ai_candidate_analysis SET asr_source = 'manual'
--   WHERE `主键列` = 主键值 AND asr_source = 'llm';
-- 模板2：DB 标 unknown 但 JSON 有明确来源，且已人工确认。同样先 SELECT 后 UPDATE，预期影响=1：
-- 2a SELECT `主键列`, asr_source,
--          json_unquote(json_extract(asr_report,'$.source')) AS json_source
--    FROM t_ai_candidate_analysis
--    WHERE `主键列` = 主键值 AND asr_source = 'unknown';
-- 2b UPDATE t_ai_candidate_analysis
--    SET asr_source = json_unquote(json_extract(asr_report,'$.source'))
--    WHERE `主键列` = 主键值 AND asr_source = 'unknown'
--      AND json_unquote(json_extract(asr_report,'$.source')) IN ('llm','manual');
-- 禁止用 company+position+candidate 三元组代替主键；禁止无证据批量把历史 llm 改 unknown；禁止自动覆盖冲突记录。

-- 3.1 自动回填：仅处理 asr_source IS NULL 的历史行；报告明确 llm/manual 采用该值，其余一律 unknown，
--     不猜测、不默认 llm；创建时间无独立记录时沿用更新时间。幂等，不覆盖已正确绑定的实时分析。
UPDATE t_ai_candidate_analysis
SET asr_source = CASE
      WHEN json_unquote(json_extract(asr_report, '$.source')) IN ('llm','manual')
        THEN json_unquote(json_extract(asr_report, '$.source'))
      ELSE 'unknown'
    END,
    asr_created_at = COALESCE(asr_created_at, asr_updated_at)
WHERE asr_source IS NULL;

-- -----------------------------------------------------
-- 步骤 4：历史 AI 分析关联（核心修复：禁止把两个独立 MIN 当作同一条关联，先诊断 ID/版本再回填）
--
-- 先由 4.0 只读诊断区分 app_id/snapshot_id/version_status 状态：
--   MATCHED_NO_BINDING（MATCHED 但绑定不完整）优先识别为异常；
--   两 ID 均存在且正确 → 保留不覆盖；两 ID 均存在但错误、或仅单个 ID 有值 → 异常，仅输出人工清单，不自动处理；
--   仅“两 ID 均空且版本状态为 NULL/UNVERIFIED”的行进入 4A/4B/4C，按匹配快照数量处理：
--   4A 恰好 1 条快照：可确定唯一目标，关联“同一条”快照的 app_id 与 snapshot_id，
--      但因无法证明 AI 针对该次投递原件，version_status 仍标 UNVERIFIED；
--   4B 多于 1 条快照（重复投递）：无法确定属于哪次投递，不猜测、不回填 ID（保持 NULL），
--      仅标 UNVERIFIED，交由人工核查；
--   4C 无任何快照匹配：同样不回填 ID，仅标 UNVERIFIED。
-- 关键：app_id 与 snapshot_id 必须来自快照表的同一行（通过 MIN(ers_id) 定位后回连该行），
--      不分别独立计算 MIN；所有 UPDATE 均以两 ID 均空、版本状态非 MATCHED 为前提，
--      不覆盖已正确绑定的实时分析，也不把已有 MATCHED 改成 UNVERIFIED。
-- -----------------------------------------------------

-- 4.0 历史 AI 绑定完整性只读诊断（任何 UPDATE 前执行，只统计不修改；按 ID 与版本状态分类）
-- 分类：
--   MATCHED_NO_BINDING 版本状态为 MATCHED 但绑定不完整（缺 app_id 或 snapshot_id），异常优先识别
--   BOTH_CORRECT  两 ID 均存在且与同一快照一致（保留原值，不覆盖）
--   BOTH_WRONG    两 ID 均存在但与快照不一致（异常，停止自动处理）
--   ONLY_APP      仅 app_id 有值（异常，人工核查）
--   ONLY_SNAPSHOT 仅 snapshot_id 有值（异常，人工核查）
--   BOTH_EMPTY    两 ID 均空且版本状态非 MATCHED（进入 4A/4B/4C 按匹配快照数量处理）
SELECT
  CASE
    WHEN r.asr_version_status = 'MATCHED'
     AND (r.asr_app_id IS NULL OR r.asr_snapshot_id IS NULL)
      THEN 'MATCHED_NO_BINDING'
    WHEN r.asr_app_id IS NOT NULL AND r.asr_snapshot_id IS NOT NULL AND s.ers_id IS NOT NULL
     AND s.ers_app_id = r.asr_app_id
     AND s.ers_company_id = r.asr_company_id
     AND s.ers_position_id = r.asr_position_id
     AND s.ers_candidate_id = r.asr_candidate_id
      THEN 'BOTH_CORRECT'
    WHEN r.asr_app_id IS NOT NULL AND r.asr_snapshot_id IS NOT NULL
      THEN 'BOTH_WRONG'
    WHEN r.asr_app_id IS NOT NULL AND r.asr_snapshot_id IS NULL
      THEN 'ONLY_APP'
    WHEN r.asr_app_id IS NULL AND r.asr_snapshot_id IS NOT NULL
      THEN 'ONLY_SNAPSHOT'
    ELSE 'BOTH_EMPTY'
  END AS bind_state,
  COUNT(*) AS cnt
FROM t_ai_candidate_analysis r
LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = r.asr_snapshot_id
GROUP BY bind_state
ORDER BY bind_state;

-- 4.0b 异常绑定明细（人工处理清单）：MATCHED_NO_BINDING / BOTH_WRONG / ONLY_APP / ONLY_SNAPSHOT 的具体行。
-- 这些行不会被 4A/4B/4C 自动修改或清空（含 version_status），须人工核实后单独处理，禁止为让校验通过而直接清空 ID。
SELECT r.asr_company_id, r.asr_position_id, r.asr_candidate_id,
       r.asr_version_status, r.asr_app_id, r.asr_snapshot_id, s.ers_app_id AS snapshot_app_id
FROM t_ai_candidate_analysis r
LEFT JOIN t_ent_resume_snapshot s ON s.ers_id = r.asr_snapshot_id
WHERE (r.asr_version_status = 'MATCHED'
        AND (r.asr_app_id IS NULL OR r.asr_snapshot_id IS NULL))
   OR (r.asr_app_id IS NOT NULL AND r.asr_snapshot_id IS NULL)
   OR (r.asr_app_id IS NULL AND r.asr_snapshot_id IS NOT NULL)
   OR (r.asr_app_id IS NOT NULL AND r.asr_snapshot_id IS NOT NULL
       AND (s.ers_id IS NULL OR s.ers_app_id <> r.asr_app_id
            OR s.ers_company_id <> r.asr_company_id
            OR s.ers_position_id <> r.asr_position_id
            OR s.ers_candidate_id <> r.asr_candidate_id));

-- 4A 唯一快照组：回连同一行取两个 ID（HAVING COUNT(*)=1 保证三元组下唯一）
UPDATE t_ai_candidate_analysis r
JOIN (
  SELECT g.ers_company_id, g.ers_position_id, g.ers_candidate_id,
         s.ers_id AS matched_snapshot_id, s.ers_app_id AS matched_app_id
  FROM (
    SELECT ers_company_id, ers_position_id, ers_candidate_id,
           MIN(ers_id) AS first_snapshot_id
    FROM t_ent_resume_snapshot
    GROUP BY ers_company_id, ers_position_id, ers_candidate_id
    HAVING COUNT(*) = 1
  ) g
  JOIN t_ent_resume_snapshot s ON s.ers_id = g.first_snapshot_id
) m
  ON m.ers_company_id = r.asr_company_id
 AND m.ers_position_id = r.asr_position_id
 AND m.ers_candidate_id = r.asr_candidate_id
SET r.asr_snapshot_id = m.matched_snapshot_id,
    r.asr_app_id = m.matched_app_id,
    r.asr_version_status = 'UNVERIFIED'
-- 仅当 app_id、snapshot_id 均空，且版本状态为 NULL/UNVERIFIED（非 MATCHED）才自动关联；
-- MATCHED_NO_BINDING/ONLY_APP/BOTH_WRONG 等异常行不被命中，保留待人工处理，不把已有 MATCHED 改成 UNVERIFIED。
WHERE r.asr_snapshot_id IS NULL
  AND r.asr_app_id IS NULL
  AND (r.asr_version_status IS NULL OR r.asr_version_status = 'UNVERIFIED');

-- 4B 多快照组：仅标记 UNVERIFIED。SET 子句不含 app_id/snapshot_id，
-- 且 WHERE 要求两 ID 均空、版本状态非 MATCHED，因此执行后 app_id、snapshot_id 均保持 NULL，禁止猜测。
UPDATE t_ai_candidate_analysis r
JOIN (
  SELECT ers_company_id, ers_position_id, ers_candidate_id
  FROM t_ent_resume_snapshot
  GROUP BY ers_company_id, ers_position_id, ers_candidate_id
  HAVING COUNT(*) > 1
) m
  ON m.ers_company_id = r.asr_company_id
 AND m.ers_position_id = r.asr_position_id
 AND m.ers_candidate_id = r.asr_candidate_id
SET r.asr_version_status = 'UNVERIFIED'
WHERE r.asr_snapshot_id IS NULL
  AND r.asr_app_id IS NULL
  AND (r.asr_version_status IS NULL OR r.asr_version_status = 'UNVERIFIED');

-- 4C 无快照匹配：仅标记 UNVERIFIED，同样不写 app_id/snapshot_id，两个 ID 保持 NULL。
-- 原始 asr_report 完整保留，不删除、不覆盖。
UPDATE t_ai_candidate_analysis r
LEFT JOIN (
  SELECT DISTINCT ers_company_id, ers_position_id, ers_candidate_id
  FROM t_ent_resume_snapshot
) m
  ON m.ers_company_id = r.asr_company_id
 AND m.ers_position_id = r.asr_position_id
 AND m.ers_candidate_id = r.asr_candidate_id
SET r.asr_version_status = 'UNVERIFIED'
WHERE m.ers_company_id IS NULL
  AND (r.asr_version_status IS NULL OR r.asr_version_status = 'UNVERIFIED')
  AND r.asr_app_id IS NULL
  AND r.asr_snapshot_id IS NULL;

-- -----------------------------------------------------
-- 步骤 5：输出“企业简历文件迁移程序”工作清单
-- 含义：这些快照源简历在 C-App 仍保留 PDF，应通过 Java/对象存储读取源文件，
--       复制到企业命名空间后回写 ers_file_path/name/size/content_hash。
-- 重要：复制成功只证明文件完整，不证明原件真实；只有在人工取得可靠原件证据后，
--       才由 06 脚本把状态从 REBUILT_UNVERIFIED 升级为 COMPLETE，严禁仅凭复制成功升级。
-- 严禁直接把 C-App 的 rbs_file_path 写入 ers_file_path 冒充已复制。
-- -----------------------------------------------------
SELECT s.ers_id, s.ers_app_id, s.ers_company_id, s.ers_source_resume_id,
       b.rbs_file_path AS source_file_ref,
       b.rbs_file_name AS source_file_name,
       b.rbs_file_size AS source_file_size
FROM t_ent_resume_snapshot s
JOIN t_res_base b ON b.rbs_id = s.ers_source_resume_id
WHERE s.ers_snapshot_status = 'REBUILT_UNVERIFIED'
  AND b.rbs_file_path IS NOT NULL
ORDER BY s.ers_id;

-- =====================================================
-- 异常与待核查（只读，不写入；用于发现静默遗漏与需要人工判断的历史数据）
-- =====================================================

-- 异常检查 A：孤儿投递（候选人在 t_tal 不存在）
-- 步骤 1 的 INNER JOIN 会跳过这些投递，导致其没有快照；如有输出，必须先人工处理，再补建快照。
SELECT a.app_id, a.app_candidate_id, a.app_position_id
FROM t_app_record a
LEFT JOIN t_tal t ON t.tal_id = a.app_candidate_id
WHERE t.tal_id IS NULL;

-- 异常检查 B：重复投递三元组下的历史 AI 分析（对应步骤 4B，未关联具体投递）
-- 这些记录 asr_snapshot_id/app_id 为 NULL、version_status=UNVERIFIED，需人工选择正确投递。
SELECT r.asr_company_id, r.asr_position_id, r.asr_candidate_id,
       r.asr_source, r.asr_version_status, r.asr_app_id, r.asr_snapshot_id, g.snap_cnt
FROM t_ai_candidate_analysis r
JOIN (
  SELECT ers_company_id, ers_position_id, ers_candidate_id, COUNT(*) AS snap_cnt
  FROM t_ent_resume_snapshot
  GROUP BY ers_company_id, ers_position_id, ers_candidate_id
  HAVING COUNT(*) > 1
) g
  ON g.ers_company_id = r.asr_company_id
 AND g.ers_position_id = r.asr_position_id
 AND g.ers_candidate_id = r.asr_candidate_id
WHERE r.asr_snapshot_id IS NULL;

-- 异常检查 C：无任何快照匹配的历史 AI 分析（对应步骤 4C）
-- 保留原始记录，标 UNVERIFIED，不展示为当前投递有效分析，需人工核实。
SELECT r.asr_company_id, r.asr_position_id, r.asr_candidate_id,
       r.asr_source, r.asr_version_status
FROM t_ai_candidate_analysis r
LEFT JOIN (
  SELECT DISTINCT ers_company_id, ers_position_id, ers_candidate_id
  FROM t_ent_resume_snapshot
) m
  ON m.ers_company_id = r.asr_company_id
 AND m.ers_position_id = r.asr_position_id
 AND m.ers_candidate_id = r.asr_candidate_id
WHERE m.ers_company_id IS NULL;

-- =====================================================
-- 回填完成。请执行 04_verify.sql 全面核对数量与一致性；
-- PDF 复制与状态升级由独立文件迁移程序完成后，再次执行 04_verify.sql 复核。
-- 历史 AI 分析即使已关联，也全部为 UNVERIFIED，不得展示为当前投递的有效（已核实）分析。
-- =====================================================
