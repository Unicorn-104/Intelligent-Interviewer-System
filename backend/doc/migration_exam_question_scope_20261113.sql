-- 题库：区分平台题库与企业内部题库
-- 执行库：recruit_agent
-- 关联功能：企业端题库（平台共享 + 企业私有）
-- 说明：eqs_company_id 为空表示平台题库（全平台可读，企业只读解析以外的字段）；
--       非空表示该企业私有题目。脚本可重复执行。

DROP PROCEDURE IF EXISTS sp_exam_question_scope;
DELIMITER $$
CREATE PROCEDURE sp_exam_question_scope()
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE()
                     AND TABLE_NAME = 't_exam_question'
                     AND COLUMN_NAME = 'eqs_company_id') THEN
        ALTER TABLE t_exam_question
            ADD COLUMN eqs_company_id bigint NULL COMMENT '所属企业；NULL 表示平台题库' AFTER eqs_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS
                   WHERE TABLE_SCHEMA = DATABASE()
                     AND TABLE_NAME = 't_exam_question'
                     AND INDEX_NAME = 'idx_exam_question_company') THEN
        ALTER TABLE t_exam_question ADD INDEX idx_exam_question_company (eqs_company_id);
    END IF;
END$$
DELIMITER ;

CALL sp_exam_question_scope();
DROP PROCEDURE sp_exam_question_scope;
