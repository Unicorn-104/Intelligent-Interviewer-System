-- Offer 接受到期提醒：录用意向书表加「已提醒」去重标记（幂等，可重复执行）
-- 目标表：t_off_offer
-- ofr_notified: 0 未提醒（默认），1 已发送到期提醒邮件，避免重复发送

SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 't_off_offer'
    AND COLUMN_NAME = 'ofr_notified'
);
SET @ddl := IF(
  @col = 0,
  'ALTER TABLE t_off_offer ADD COLUMN ofr_notified tinyint NOT NULL DEFAULT 0 COMMENT ''到期提醒已发送 0否1是'' AFTER ofr_status',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
