-- MySQL 8; additive migration, safe to re-run. No business-table changes.
CREATE TABLE IF NOT EXISTS t_capp_ai_session (
  id varchar(36) NOT NULL PRIMARY KEY,
  user_id bigint NOT NULL,
  title varchar(80) NOT NULL,
  active_run_id varchar(36) NULL,
  created_at datetime(3) NOT NULL,
  updated_at datetime(3) NOT NULL,
  KEY idx_ai_session_owner (user_id, updated_at, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_capp_ai_run (
  id varchar(36) NOT NULL PRIMARY KEY,
  session_id varchar(36) NOT NULL,
  user_id bigint NOT NULL,
  request_id varchar(36) NOT NULL,
  status varchar(16) NOT NULL,
  resume_id bigint NULL,
  input_text varchar(4000) NOT NULL,
  error_code varchar(40) NULL,
  model_calls int NOT NULL DEFAULT 0,
  tool_calls int NOT NULL DEFAULT 0,
  total_tokens int NOT NULL DEFAULT 0,
  created_at datetime(3) NOT NULL,
  finished_at datetime(3) NULL,
  UNIQUE KEY uk_ai_run_request (session_id, request_id),
  KEY idx_ai_run_owner (user_id, status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_capp_ai_message (
  id bigint NOT NULL AUTO_INCREMENT PRIMARY KEY,
  session_id varchar(36) NOT NULL,
  run_id varchar(36) NOT NULL,
  role varchar(12) NOT NULL,
  content mediumtext NOT NULL,
  cards_json mediumtext NULL,
  created_at datetime(3) NOT NULL,
  UNIQUE KEY uk_ai_message_run_role (run_id, role),
  KEY idx_ai_message_session (session_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS t_capp_ai_event (
  id bigint NOT NULL AUTO_INCREMENT PRIMARY KEY,
  run_id varchar(36) NOT NULL,
  event_type varchar(16) NOT NULL,
  data_json mediumtext NOT NULL,
  created_at datetime(3) NOT NULL,
  KEY idx_ai_event_run (run_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
