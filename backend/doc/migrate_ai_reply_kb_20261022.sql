-- AI应答：配置KV表 + 知识库表（幂等，可重复执行）

-- 1) AI应答配置 KV 表
SET @tbl := (
  SELECT COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 't_ai_reply_config'
);
SET @ddl := IF(
  @tbl = 0,
  'CREATE TABLE t_ai_reply_config (cfg_key varchar(50) NOT NULL PRIMARY KEY, cfg_value varchar(500) NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT=''AI应答配置KV''',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2) AI知识库表
SET @tbl := (
  SELECT COUNT(*) FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 't_ai_knowledge'
);
SET @ddl := IF(
  @tbl = 0,
  'CREATE TABLE t_ai_knowledge (kb_id bigint NOT NULL AUTO_INCREMENT PRIMARY KEY, question varchar(255) NOT NULL COMMENT ''标准问题'', answer text NOT NULL COMMENT ''标准回答'', category varchar(50) NULL COMMENT ''分类'', use_count int NOT NULL DEFAULT 0 COMMENT ''使用次数'', created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT=''AI知识库''',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
