-- Additive migration; apply after migration_capp_ai_agent_20261020.sql.
CREATE TABLE IF NOT EXISTS t_capp_ai_memory_state (
    user_id BIGINT NOT NULL PRIMARY KEY,
    enabled TINYINT NOT NULL DEFAULT 1,
    revision BIGINT NOT NULL DEFAULT 0,
    forget_before_id BIGINT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS t_capp_ai_memory (
    user_id BIGINT NOT NULL,
    memory_key VARCHAR(40) NOT NULL,
    memory_value VARCHAR(200) NOT NULL,
    updated_at DATETIME(3) NOT NULL,
    PRIMARY KEY (user_id, memory_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS t_capp_ai_summary (
    session_id VARCHAR(36) NOT NULL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    content VARCHAR(2000) NOT NULL,
    through_id BIGINT NOT NULL,
    revision BIGINT NOT NULL,
    updated_at DATETIME(3) NOT NULL,
    KEY idx_ai_summary_owner (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
