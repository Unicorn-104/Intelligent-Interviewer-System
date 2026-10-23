-- AI应答记录：补充提问人、转人工标记、响应时长列（幂等，可重复执行）
-- 目标表：t_ai_chat_message
-- acm_user_id          : 提问人，关联 sys_user.user_id
-- acm_transfer_to_human: 是否转人工 0否 1是
-- acm_response_time     : AI响应耗时（秒）

-- acm_user_id
SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 't_ai_chat_message'
    AND COLUMN_NAME = 'acm_user_id'
);
SET @ddl := IF(
  @col = 0,
  'ALTER TABLE t_ai_chat_message ADD COLUMN acm_user_id bigint NULL COMMENT ''提问人'' AFTER acm_intent',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- acm_transfer_to_human
SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 't_ai_chat_message'
    AND COLUMN_NAME = 'acm_transfer_to_human'
);
SET @ddl := IF(
  @col = 0,
  'ALTER TABLE t_ai_chat_message ADD COLUMN acm_transfer_to_human tinyint NOT NULL DEFAULT 0 COMMENT ''是否转人工 0否1是'' AFTER acm_user_id',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- acm_response_time
SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 't_ai_chat_message'
    AND COLUMN_NAME = 'acm_response_time'
);
SET @ddl := IF(
  @col = 0,
  'ALTER TABLE t_ai_chat_message ADD COLUMN acm_response_time int NULL COMMENT ''响应耗时(秒)'' AFTER acm_transfer_to_human',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
