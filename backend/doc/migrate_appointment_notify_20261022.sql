-- 面试前邮件提醒：预约表加「已提醒」去重标记（幂等，可重复执行）
-- 目标表：t_sch_appointment
-- apt_notified: 0 未提醒（默认），1 已发送面试提醒邮件，避免重复发送

SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 't_sch_appointment'
    AND COLUMN_NAME = 'apt_notified'
);
SET @ddl := IF(
  @col = 0,
  'ALTER TABLE t_sch_appointment ADD COLUMN apt_notified tinyint NOT NULL DEFAULT 0 COMMENT ''面试提醒已发送 0否1是'' AFTER apt_status',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
