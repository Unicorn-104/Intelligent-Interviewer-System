-- Personal knowledge RAG. Additive and repeatable; does not modify existing AI tables.
CREATE TABLE IF NOT EXISTS t_capp_knowledge_base (
 id VARCHAR(36) PRIMARY KEY, user_id BIGINT NOT NULL, name VARCHAR(80) NOT NULL,
 scope VARCHAR(16) NOT NULL DEFAULT 'PERSONAL', status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
 created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 INDEX idx_knowledge_owner(user_id,status)
);
CREATE TABLE IF NOT EXISTS t_capp_knowledge_document (
 id VARCHAR(36) PRIMARY KEY, base_id VARCHAR(36) NOT NULL, user_id BIGINT NOT NULL,
 name VARCHAR(180) NOT NULL, extension VARCHAR(8) NOT NULL, file_size BIGINT NOT NULL,
 file_hash VARCHAR(64) NOT NULL, storage_ref VARCHAR(500) NOT NULL,
 status VARCHAR(20) NOT NULL DEFAULT 'QUEUED', revision INT NOT NULL DEFAULT 1,
 active_revision INT NOT NULL DEFAULT 0, chunk_count INT NOT NULL DEFAULT 0, error_code VARCHAR(40),
 created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 INDEX idx_knowledge_document_owner(user_id,base_id,status),
 INDEX idx_knowledge_document_hash(user_id,base_id,file_hash)
);
CREATE TABLE IF NOT EXISTS t_capp_knowledge_chunk (
 id VARCHAR(36) PRIMARY KEY, document_id VARCHAR(36) NOT NULL, base_id VARCHAR(36) NOT NULL,
 user_id BIGINT NOT NULL, revision INT NOT NULL, ordinal_no INT NOT NULL,
 page_no INT, section_title VARCHAR(180), content TEXT NOT NULL,
 UNIQUE KEY uk_knowledge_chunk(document_id,revision,ordinal_no),
 INDEX idx_knowledge_chunk_owner(user_id,base_id,document_id,revision)
);
CREATE TABLE IF NOT EXISTS t_capp_knowledge_job (
 document_id VARCHAR(36) PRIMARY KEY, operation VARCHAR(16) NOT NULL,
 status VARCHAR(16) NOT NULL DEFAULT 'PENDING', attempts INT NOT NULL DEFAULT 0,
 lease_token VARCHAR(36), available_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 lease_until TIMESTAMP(3), error_code VARCHAR(40)
);
CREATE TABLE IF NOT EXISTS t_capp_knowledge_run (
 run_id VARCHAR(36) PRIMARY KEY, user_id BIGINT NOT NULL, session_id VARCHAR(36) NOT NULL,
 scope_json TEXT NOT NULL, sources_json TEXT,
 INDEX idx_knowledge_run_owner(user_id,session_id)
);
