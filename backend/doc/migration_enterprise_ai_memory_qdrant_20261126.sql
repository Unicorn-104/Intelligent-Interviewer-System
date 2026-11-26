-- Enterprise recruiter long-term memory: multi-fact model and Qdrant outbox.
-- Additive/repeatable. MySQL 8, utf8mb4. Apply before enabling the new memory code.
-- Fixed preferences in t_enterprise_ai_memory remain unchanged and are always injected.

CREATE TABLE IF NOT EXISTS t_enterprise_ai_memory_fact (
  id CHAR(36) NOT NULL PRIMARY KEY,
  company_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  memory_type VARCHAR(40) NOT NULL,
  content VARCHAR(500) NOT NULL,
  evidence VARCHAR(500) NOT NULL,
  source_session_id BIGINT NULL,
  source_message_id BIGINT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
  index_status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
  created_at DATETIME(3) NOT NULL,
  updated_at DATETIME(3) NOT NULL,
  KEY idx_enterprise_ai_memory_fact_owner(company_id,user_id,status,updated_at),
  KEY idx_enterprise_ai_memory_fact_index(company_id,user_id,index_status),
  KEY idx_enterprise_ai_memory_fact_source(company_id,source_session_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_enterprise_ai_memory_outbox (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  company_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  memory_id CHAR(36) NULL,
  operation VARCHAR(16) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
  attempts INT NOT NULL DEFAULT 0,
  next_retry_at DATETIME(3) NOT NULL,
  last_error VARCHAR(200) NULL,
  created_at DATETIME(3) NOT NULL,
  updated_at DATETIME(3) NOT NULL,
  KEY idx_enterprise_ai_memory_outbox_retry(status,next_retry_at),
  KEY idx_enterprise_ai_memory_outbox_owner(company_id,user_id,status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
