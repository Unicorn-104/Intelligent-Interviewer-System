-- 消息发送记录：补充联系方式与失败原因列（幂等，可重复执行）
-- 目标表：t_msg_record
-- mr_contact   : 接收方联系方式（手机号 / 邮箱），用于列表展示与脱敏
-- mr_fail_reason: 最近一次发送失败原因，重发成功后清空

-- mr_contact
SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 't_msg_record'
    AND COLUMN_NAME = 'mr_contact'
);
SET @ddl := IF(
  @col = 0,
  'ALTER TABLE t_msg_record ADD COLUMN mr_contact varchar(100) NULL COMMENT ''接收方联系方式'' AFTER mr_user_name',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- mr_fail_reason
SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 't_msg_record'
    AND COLUMN_NAME = 'mr_fail_reason'
);
SET @ddl := IF(
  @col = 0,
  'ALTER TABLE t_msg_record ADD COLUMN mr_fail_reason varchar(500) NULL COMMENT ''最近一次失败原因'' AFTER mr_status',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
