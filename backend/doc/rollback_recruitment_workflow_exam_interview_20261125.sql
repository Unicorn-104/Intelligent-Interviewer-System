-- Restore the company 1 workflow stages saved by the migration script.
-- Do not run unless bak_workflow_exam_interview_20261125_stage exists.

SET FOREIGN_KEY_CHECKS = 0;
START TRANSACTION;

DELETE s
FROM t_process_stage s
JOIN t_process_template t ON t.ptl_id = s.psg_template_id
WHERE t.ptl_company_id = 1;

INSERT INTO t_process_stage
SELECT * FROM bak_workflow_exam_interview_20261125_stage;

COMMIT;
SET FOREIGN_KEY_CHECKS = 1;
