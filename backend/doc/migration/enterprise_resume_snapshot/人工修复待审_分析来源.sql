-- =====================================================================
-- 人工修复待审文件：t_ai_candidate_analysis 来源(asr_source)逐行修正
-- 适用：03 步骤3 全量诊断发现“来源冲突/可疑”，且已取得确凿证据、需人工逐行修正时使用。
-- 重要：
--   1. 本文件独立于正常迁移流程，03 正常回填不会、也不应自动执行这里的任何 UPDATE。
--   2. 新架构同一企业/岗位/候选人可有多行，禁止用三元组定位，必须用真实主键，一次只改一行。
--   3. 所有 UPDATE 默认注释，必须先跑 SELECT 核对，确认影响行数=1 后由本人手动放开执行。
--   4. 无确凿证据的冲突不得修改；原始 asr_report 完整保留，本文件不动报告内容。
-- =====================================================================

-- 步骤0（只读，先执行）：确认分析表真实主键列名，不允许猜测。
--   预期返回单列；记下 COLUMN_NAME 用于替换下面的 `主键列`。
--   若返回多列(复合主键)或无主键(0 行)，停止本文件，改用人工逐条核查方案。
SELECT kcu.column_name, kcu.ordinal_position
FROM information_schema.key_column_usage kcu
WHERE kcu.table_schema = DATABASE()
  AND kcu.table_name = 't_ai_candidate_analysis'
  AND kcu.constraint_name = 'PRIMARY'
ORDER BY kcu.ordinal_position;

-- ---------------------------------------------------------------------
-- 模板1：DB 标 llm 但报告 JSON 实为 manual，且已人工确认应改 manual。
--   替换：`主键列` -> 步骤0 查到的真实列名；“主键值” -> 该行主键的真实值。
-- ---------------------------------------------------------------------
-- 1a 先 SELECT（必须恰好返回 1 行，且 asr_source 确为 llm，JSON 来源确为 manual）：
-- SELECT `主键列`, asr_company_id, asr_position_id, asr_candidate_id,
--        asr_source, asr_version_status,
--        json_unquote(json_extract(asr_report,'$.source')) AS json_source
-- FROM t_ai_candidate_analysis
-- WHERE `主键列` = 主键值 AND asr_source = 'llm';
-- 1b 确认 1a 恰好 1 行且证据一致后再执行 UPDATE（原值守卫，预期影响=1）：
-- UPDATE t_ai_candidate_analysis SET asr_source = 'manual'
--   WHERE `主键列` = 主键值 AND asr_source = 'llm';
-- 执行后核对：客户端提示影响行数必须为 1；若为 0 或 >1，立即停止并人工核查，不得继续。

-- ---------------------------------------------------------------------
-- 模板2：DB 标 unknown 但报告 JSON 有明确来源(llm/manual)，且已人工确认。
-- ---------------------------------------------------------------------
-- 2a 先 SELECT（必须恰好 1 行，json_source 为 llm 或 manual）：
-- SELECT `主键列`, asr_source,
--        json_unquote(json_extract(asr_report,'$.source')) AS json_source
-- FROM t_ai_candidate_analysis
-- WHERE `主键列` = 主键值 AND asr_source = 'unknown';
-- 2b 确认后执行 UPDATE（双重守卫：原 unknown 且 JSON 来源合法，预期影响=1）：
-- UPDATE t_ai_candidate_analysis
-- SET asr_source = json_unquote(json_extract(asr_report,'$.source'))
-- WHERE `主键列` = 主键值 AND asr_source = 'unknown'
--   AND json_unquote(json_extract(asr_report,'$.source')) IN ('llm','manual');

-- ---------------------------------------------------------------------
-- 安全红线
--   禁止用 asr_company_id+asr_position_id+asr_candidate_id 三元组代替主键。
--   禁止无证据批量把历史 llm 改为 unknown，禁止自动覆盖冲突记录。
--   若需同时改 asr_app_id/asr_snapshot_id，必须先核对真实关联，且不得改动 asr_version_status。
-- ---------------------------------------------------------------------
