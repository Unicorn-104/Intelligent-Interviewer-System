-- ============================================================================
-- 面试报告自动生成 - 增量迁移脚本
-- 日期：2026-11-03
-- 说明：为面试场次增加报告生成状态机字段；评估表 evl_session_id 增加唯一键保证一场一行。
--       逐字稿仍存 t_int_dialogue，报告结论存 t_int_evaluation，不产生独立报告文件。
-- ============================================================================

USE recruit_agent;
SET NAMES utf8mb4;

-- 1. 报告状态机：0未触发 1生成中 2成功 3失败；错误码用于前端提示与重试判断
ALTER TABLE t_int_session
  ADD COLUMN ses_report_status tinyint NOT NULL DEFAULT 0
    COMMENT '报告生成状态：0未触发 1生成中 2成功 3失败',
  ADD COLUMN ses_report_error varchar(64) NULL
    COMMENT '报告失败错误码：INSUFFICIENT_DATA / MODEL_UNAVAILABLE / EVIDENCE_MISMATCH / INTERNAL_ERROR',
  ADD COLUMN ses_report_retry tinyint NOT NULL DEFAULT 0
    COMMENT '报告自动/手动重试次数，用于限制重试上限';

-- 2. 回填历史已存在的评估行，避免旧数据在调用结果接口时被误判为「生成中」
UPDATE t_int_session s
  SET s.ses_report_status = 2
  WHERE EXISTS (SELECT 1 FROM t_int_evaluation e WHERE e.evl_session_id = s.ses_id);

-- 3. 评估行唯一性：当前库已存在 uk_evl_session_id (evl_session_id) 唯一键，
--    无需重复创建；仅在其它环境确认不存在时才执行下面语句：
--    SELECT evl_session_id, COUNT(*) FROM t_int_evaluation GROUP BY evl_session_id HAVING COUNT(*) > 1;
--    ALTER TABLE t_int_evaluation ADD UNIQUE KEY uk_evl_session (evl_session_id);

-- 4. AI 评估建议为自然语言，原 tinyint 字段放宽为文本以承载模型输出（历史 1/2 编码仍可正常读取）。
--    若线上 evl_recommendation 已是 varchar，本条仅做宽度对齐。
ALTER TABLE t_int_evaluation
  MODIFY COLUMN evl_recommendation varchar(500) NULL DEFAULT NULL COMMENT 'AI评估建议';
