-- 消息模板：补充消息类型与变量列（幂等，可重复执行）
-- 目标表：t_msg_template
-- tpl_msg_type : 消息类型 0面试提醒 1面试结果 2录用通知 3淘汰关怀 4体验调研 5系统公告
-- tpl_variables: 模板变量名，逗号分隔，如 candidate_name,position_name

-- tpl_msg_type
SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 't_msg_template'
    AND COLUMN_NAME = 'tpl_msg_type'
);
SET @ddl := IF(
  @col = 0,
  'ALTER TABLE t_msg_template ADD COLUMN tpl_msg_type tinyint NULL DEFAULT NULL COMMENT ''消息类型'' AFTER tpl_channel',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- tpl_variables
SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 't_msg_template'
    AND COLUMN_NAME = 'tpl_variables'
);
SET @ddl := IF(
  @col = 0,
  'ALTER TABLE t_msg_template ADD COLUMN tpl_variables varchar(500) NULL COMMENT ''模板变量(逗号分隔)'' AFTER tpl_msg_type',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
