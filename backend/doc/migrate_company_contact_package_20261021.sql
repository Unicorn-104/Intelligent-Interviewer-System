-- 企业管理扩展列：联系人、电话、套餐类型、到期日期（幂等，可重复执行）
-- 目标表：t_cmp
-- contact_name/contact_phone：认证联系人信息
-- package_type：basic基础版 / pro专业版 / flag旗舰版
-- expire_date：真实到期日期（date），为空时前端按创建时间+1年兜底推算

-- contact_name
SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='t_cmp' AND COLUMN_NAME='contact_name');
SET @ddl := IF(@col=0, 'ALTER TABLE t_cmp ADD COLUMN contact_name varchar(50) NULL COMMENT ''认证联系人'' AFTER cmp_email', 'SELECT 1');
PREPARE s FROM @ddl; EXECUTE s; DEALLOCATE PREPARE s;

-- contact_phone
SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='t_cmp' AND COLUMN_NAME='contact_phone');
SET @ddl := IF(@col=0, 'ALTER TABLE t_cmp ADD COLUMN contact_phone varchar(20) NULL COMMENT ''联系人电话'' AFTER contact_name', 'SELECT 1');
PREPARE s FROM @ddl; EXECUTE s; DEALLOCATE PREPARE s;

-- package_type
SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='t_cmp' AND COLUMN_NAME='package_type');
SET @ddl := IF(@col=0, 'ALTER TABLE t_cmp ADD COLUMN package_type varchar(20) NULL COMMENT ''套餐 basic/pro/flag'' AFTER api_used', 'SELECT 1');
PREPARE s FROM @ddl; EXECUTE s; DEALLOCATE PREPARE s;

-- expire_date
SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='t_cmp' AND COLUMN_NAME='expire_date');
SET @ddl := IF(@col=0, 'ALTER TABLE t_cmp ADD COLUMN expire_date date NULL COMMENT ''套餐到期日期'' AFTER package_type', 'SELECT 1');
PREPARE s FROM @ddl; EXECUTE s; DEALLOCATE PREPARE s;
