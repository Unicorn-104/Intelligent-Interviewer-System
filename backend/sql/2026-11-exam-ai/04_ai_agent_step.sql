-- ============================================================================
-- 04 Agent 工具调用审计表
-- 状态：待授权执行。本文件只出稿，不在任何环境自动执行。
-- 执行后需要把配置 ai.agent.audit.enabled 置为 true，审计记录才会写入。
-- 回滚：DROP TABLE IF EXISTS t_ai_agent_step;
-- ============================================================================

CREATE TABLE IF NOT EXISTS t_ai_agent_step (
    step_id         BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    step_scope      VARCHAR(16)  NOT NULL COMMENT '所属端：admin/enterprise/seeker/exam',
    step_user_id    BIGINT       NULL COMMENT '操作人用户ID',
    step_user_name  VARCHAR(64)  NULL COMMENT '操作人账号',
    step_tool       VARCHAR(64)  NOT NULL COMMENT '工具名',
    step_args       TEXT         NULL COMMENT '参数摘要，截断 500 字',
    step_result     TEXT         NULL COMMENT '结果摘要，截断 500 字',
    step_status     TINYINT      NOT NULL DEFAULT 0 COMMENT '0 成功 1 失败',
    step_cost_ms    INT          NULL COMMENT '耗时毫秒',
    step_pending_id VARCHAR(32)  NULL COMMENT '关联的待确认编号，写提案时非空',
    step_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '调用时间',
    PRIMARY KEY (step_id),
    KEY idx_step_at (step_at),
    KEY idx_step_pending (step_pending_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Agent 工具调用审计';

-- 回滚语句（需要时单独执行）：
-- DROP TABLE IF EXISTS t_ai_agent_step;
