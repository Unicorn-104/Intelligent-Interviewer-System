-- 回滚：题库自定义题型名称与答案解析
-- 注意：回滚会丢失已填写的自定义题型名称与答案解析数据

ALTER TABLE t_exam_question
    DROP COLUMN eqs_analysis,
    DROP COLUMN eqs_type_name;
