-- =====================================================================
-- 题库 AI 能力升级 · 阶段 1 DDL
-- 状态：仅生成，未执行。执行前需负责人确认。
-- 目标：t_exam_question（MySQL 8.0）
-- 作用：为 AI 结构化抽取引入复核状态、机器校验得分、模型自评、来源与题干哈希
-- 注意：本阶段代码不得先于本 DDL 上线，否则引用新列会报 Unknown column
-- =====================================================================

ALTER TABLE t_exam_question
  ADD COLUMN eqs_status        TINYINT      NOT NULL DEFAULT 1 COMMENT '0待复核 1已通过 2已驳回' AFTER eqs_category,
  ADD COLUMN eqs_confidence    DECIMAL(3,2) NULL     COMMENT '机器校验得分 0-1，不取模型自评' AFTER eqs_status,
  ADD COLUMN eqs_ai_self_score DECIMAL(3,2) NULL     COMMENT '模型自评置信度，仅记录不参与判定' AFTER eqs_confidence,
  ADD COLUMN eqs_source        VARCHAR(255) NULL     COMMENT '来源文件名 + provider/model' AFTER eqs_ai_self_score,
  ADD COLUMN eqs_hash          CHAR(64)     NULL     COMMENT '题干规范化SHA-256' AFTER eqs_source;

-- 普通索引，不是 UNIQUE：同一道题会被多家企业分别收录（eqs_company_id 不同），
-- UNIQUE 会让第二家企业导入直接失败。判重由 ExamDedupService 负责。
ALTER TABLE t_exam_question ADD INDEX idx_eqs_hash (eqs_hash);

-- =====================================================================
-- 回滚（按需执行）
-- =====================================================================
-- ALTER TABLE t_exam_question DROP INDEX idx_eqs_hash;
-- ALTER TABLE t_exam_question
--   DROP COLUMN eqs_hash,
--   DROP COLUMN eqs_source,
--   DROP COLUMN eqs_ai_self_score,
--   DROP COLUMN eqs_confidence,
--   DROP COLUMN eqs_status;

-- =====================================================================
-- 回填说明
-- eqs_hash 由 ExamDedupService.rehashAll() 在应用侧计算后分批 UPDATE（500 条/批），
-- 不写进本脚本，避免在 DDL 中引入业务算法。
-- 存量 109 条（系统 55 + 企业 54）回填后 eqs_status 默认 1（已通过），
-- 新导入的低分题由 batchInsert 显式写入 eqs_status=0。
-- =====================================================================
