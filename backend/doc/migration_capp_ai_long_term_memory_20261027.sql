-- Additive MySQL 8 migration. Apply after the existing AI memory migration.
CREATE TABLE IF NOT EXISTS t_capp_ai_memory_item (
  id VARCHAR(36) NOT NULL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  memory_type VARCHAR(32) NOT NULL,
  content VARCHAR(1000) NOT NULL,
  content_hash CHAR(64) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
  revision BIGINT NOT NULL DEFAULT 1,
  superseded_by VARCHAR(36) NULL,
  created_at DATETIME(3) NOT NULL,
  updated_at DATETIME(3) NOT NULL,
  KEY idx_ai_memory_owner_status (user_id, status, updated_at),
  KEY idx_ai_memory_hash (user_id, content_hash, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_capp_ai_memory_evidence (
  memory_id VARCHAR(36) NOT NULL,
  user_id BIGINT NOT NULL,
  session_id VARCHAR(36) NOT NULL,
  run_id VARCHAR(36) NOT NULL,
  message_id BIGINT NOT NULL,
  evidence VARCHAR(500) NOT NULL,
  created_at DATETIME(3) NOT NULL,
  PRIMARY KEY (memory_id, message_id),
  KEY idx_ai_memory_evidence_owner (user_id, session_id, message_id),
  KEY idx_ai_memory_evidence_run (run_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_capp_ai_memory_extract_job (
  run_id VARCHAR(36) NOT NULL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  session_id VARCHAR(36) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
  attempts INT NOT NULL DEFAULT 0,
  lease_until DATETIME(3) NULL,
  next_attempt_at DATETIME(3) NOT NULL,
  last_error_type VARCHAR(80) NULL,
  created_at DATETIME(3) NOT NULL,
  updated_at DATETIME(3) NOT NULL,
  KEY idx_ai_memory_extract_pending (status, next_attempt_at, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_capp_ai_memory_vector_outbox (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  memory_id VARCHAR(36) NOT NULL,
  user_id BIGINT NOT NULL,
  revision BIGINT NOT NULL,
  operation VARCHAR(16) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
  attempts INT NOT NULL DEFAULT 0,
  lease_until DATETIME(3) NULL,
  next_attempt_at DATETIME(3) NOT NULL,
  last_error_type VARCHAR(80) NULL,
  created_at DATETIME(3) NOT NULL,
  updated_at DATETIME(3) NOT NULL,
  UNIQUE KEY uk_ai_memory_vector_version (memory_id, revision, operation),
  KEY idx_ai_memory_vector_pending (status, next_attempt_at, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
