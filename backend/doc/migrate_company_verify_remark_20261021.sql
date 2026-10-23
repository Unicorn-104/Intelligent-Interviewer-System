-- 企业审核：新增驳回理由列（幂等，可重复执行）
-- 目标表：t_cmp；新增 verify_remark 保存认证拒绝时的驳回理由
SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 't_cmp'
    AND COLUMN_NAME = 'verify_remark'
);
SET @ddl := IF(
  @col = 0,
  'ALTER TABLE t_cmp ADD COLUMN verify_remark varchar(255) NULL COMMENT ''审核驳回理由'' AFTER cmp_verify_by',
  'SELECT 1'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
