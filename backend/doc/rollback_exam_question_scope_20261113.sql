-- 回滚：题库平台/企业隔离
-- 执行库：recruit_agent

ALTER TABLE t_exam_question
    DROP INDEX idx_exam_question_company,
    DROP COLUMN eqs_company_id;
