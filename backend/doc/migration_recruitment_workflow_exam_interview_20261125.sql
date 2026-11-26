-- Simplify company 1 recruitment workflows to written-test/interview stages.
-- Run after backing up the database and clearing related process instances.
-- The backup table is retained for rollback.

CREATE TABLE IF NOT EXISTS bak_workflow_exam_interview_20261125_stage LIKE t_process_stage;
INSERT IGNORE INTO bak_workflow_exam_interview_20261125_stage
SELECT s.*
FROM t_process_stage s
JOIN t_process_template t ON t.ptl_id = s.psg_template_id
WHERE t.ptl_company_id = 1;

START TRANSACTION;

DELETE s
FROM t_process_stage s
JOIN t_process_template t ON t.ptl_id = s.psg_template_id
WHERE t.ptl_company_id = 1
  AND s.psg_type NOT IN (1, 3);

DELETE duplicate_stage
FROM t_process_stage duplicate_stage
JOIN t_process_stage retained_stage
  ON retained_stage.psg_template_id = duplicate_stage.psg_template_id
 AND retained_stage.psg_type = duplicate_stage.psg_type
 AND retained_stage.psg_id < duplicate_stage.psg_id
JOIN t_process_template t ON t.ptl_id = duplicate_stage.psg_template_id
WHERE t.ptl_company_id = 1;

INSERT INTO t_process_stage
    (psg_template_id, psg_name, psg_type, psg_sort_order,
     psg_is_required, psg_pass_threshold, psg_interviewer_config_json)
SELECT t.ptl_id,
       CASE required_type.stage_type WHEN 1 THEN '在线笔试' ELSE 'HR综合面试' END,
       required_type.stage_type,
       required_type.stage_type,
       0,
       70,
       NULL
FROM t_process_template t
JOIN (
    SELECT 1 AS stage_type
    UNION ALL
    SELECT 3 AS stage_type
) required_type
WHERE t.ptl_company_id = 1
  AND NOT EXISTS (
      SELECT 1
      FROM t_process_stage s
      WHERE s.psg_template_id = t.ptl_id
        AND s.psg_type = required_type.stage_type
  );

UPDATE t_process_stage s
JOIN t_process_template t ON t.ptl_id = s.psg_template_id
SET s.psg_name = CASE s.psg_type WHEN 1 THEN '在线笔试' ELSE 'HR综合面试' END
WHERE t.ptl_company_id = 1
  AND TRIM(COALESCE(s.psg_name, '')) = '';

UPDATE t_process_stage s
JOIN t_process_template t ON t.ptl_id = s.psg_template_id
SET s.psg_sort_order = CASE s.psg_type WHEN 1 THEN 1 ELSE 2 END
WHERE t.ptl_company_id = 1
  AND s.psg_type IN (1, 3);

COMMIT;
