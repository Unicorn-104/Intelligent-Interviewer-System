-- 题库：支持自定义题型名称与答案解析
-- 执行库：recruit_agent
-- 关联功能：企业端题库改造（自定义题型、答案解析、AI 补全解析）

ALTER TABLE t_exam_question
    ADD COLUMN eqs_type_name varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL
        COMMENT '自定义题型名称（内置题型为空）' AFTER eqs_type,
    ADD COLUMN eqs_analysis text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL
        COMMENT '答案解析' AFTER eqs_answer;
