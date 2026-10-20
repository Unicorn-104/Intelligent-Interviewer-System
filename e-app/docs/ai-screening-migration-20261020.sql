-- ============================================================================
-- 2026-10-20 企业端真实AI筛选与雷达图分析
-- 来源：用户要求接入已配置模型，综合评估经历并生成简短推荐理由
-- 范围：仅新增本模块任务与结果表，不改原人才/岗位/招呼语结构；不预填AI分数
-- 幂等：CREATE TABLE IF NOT EXISTS；JSON评分由真实模型响应校验后写入
-- 回滚：停止筛选后台任务并回退本模块代码后，可删除以下两张专用表（会丢失本模块报告）
-- 不得执行整个new.sql；本段可独立执行。无全局配置或权限变更。
-- ============================================================================
CREATE TABLE IF NOT EXISTS t_ai_screening_task (
    ast_company_id BIGINT NOT NULL,
    ast_position_id BIGINT NOT NULL,
    ast_run_id VARCHAR(36) NOT NULL,
    ast_state VARCHAR(20) NOT NULL DEFAULT 'idle',
    ast_candidate_count INT NOT NULL DEFAULT 0,
    ast_completed_count INT NOT NULL DEFAULT 0,
    ast_passed_count INT NOT NULL DEFAULT 0,
    ast_error VARCHAR(500) DEFAULT NULL,
    ast_updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ast_company_id, ast_position_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='企业AI筛选任务与进度';

CREATE TABLE IF NOT EXISTS t_ai_screening_result (
    asr_company_id BIGINT NOT NULL,
    asr_position_id BIGINT NOT NULL,
    asr_candidate_id BIGINT NOT NULL,
    asr_resume_id BIGINT DEFAULT NULL,
    asr_report JSON NOT NULL,
    asr_updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (asr_company_id, asr_position_id, asr_candidate_id),
    KEY idx_asr_candidate_updated (asr_company_id, asr_candidate_id, asr_updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='岗位候选人真实AI匹配报告';
-- 仅在确认清除该模块结果时人工执行回滚：
-- DROP TABLE t_ai_screening_result;
-- DROP TABLE t_ai_screening_task;
