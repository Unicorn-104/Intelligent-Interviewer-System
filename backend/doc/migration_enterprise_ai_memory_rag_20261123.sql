-- Enterprise AI memory and RAG corpus. MySQL 8, additive and repeatable.
-- Memory rows are scoped by company_id AND user_id: the company boundary isolates tenants,
-- while each recruiter keeps private preferences inside the enterprise.
CREATE TABLE IF NOT EXISTS t_enterprise_ai_memory_state (
  company_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  enabled TINYINT NOT NULL DEFAULT 1,
  revision BIGINT NOT NULL DEFAULT 0,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY(company_id,user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_enterprise_ai_memory (
  company_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  memory_key VARCHAR(40) NOT NULL,
  memory_value VARCHAR(500) NOT NULL,
  updated_at DATETIME(3) NOT NULL,
  PRIMARY KEY(company_id,user_id,memory_key),
  KEY idx_enterprise_ai_memory_updated(company_id,user_id,updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_enterprise_ai_summary (
  session_id BIGINT NOT NULL PRIMARY KEY,
  company_id BIGINT NOT NULL,
  content VARCHAR(3000) NOT NULL,
  through_message_id BIGINT NOT NULL,
  revision BIGINT NOT NULL,
  updated_at DATETIME(3) NOT NULL,
  KEY idx_enterprise_ai_summary_company(company_id,updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Per-session context reset fence: history with acm_id <= forget_before_id is not replayed.
CREATE TABLE IF NOT EXISTS t_enterprise_ai_context_reset (
  session_id BIGINT NOT NULL PRIMARY KEY,
  company_id BIGINT NOT NULL,
  forget_before_id BIGINT NOT NULL DEFAULT 0,
  updated_at DATETIME(3) NOT NULL,
  KEY idx_enterprise_ai_context_reset_company(company_id,updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_enterprise_ai_knowledge_document (
  id CHAR(36) NOT NULL PRIMARY KEY,
  company_id BIGINT NOT NULL,
  name VARCHAR(80) NOT NULL,
  content_length INT NOT NULL,
  chunk_count INT NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME(3) NOT NULL,
  updated_at DATETIME(3) NOT NULL,
  KEY idx_enterprise_ai_knowledge_document_company(company_id,status,updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_enterprise_ai_knowledge_chunk (
  id CHAR(36) NOT NULL PRIMARY KEY,
  document_id CHAR(36) NOT NULL,
  company_id BIGINT NOT NULL,
  ordinal_no INT NOT NULL,
  content TEXT NOT NULL,
  UNIQUE KEY uk_enterprise_ai_knowledge_chunk(document_id,ordinal_no),
  KEY idx_enterprise_ai_knowledge_chunk_company(company_id,document_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
