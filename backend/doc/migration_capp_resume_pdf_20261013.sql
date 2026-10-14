-- C-APP PDF storage: compatible with migration_resume_management_20261008.sql.
-- Apply to the selected application database. Existing columns are unchanged.
SET @schema_name = DATABASE();
SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_file_path') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_file_path varchar(500) NULL COMMENT ''pdf resume reference''', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_file_name') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_file_name varchar(255) NULL COMMENT ''pdf original file name''', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_file_size') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_file_size bigint NULL COMMENT ''pdf file size bytes''', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
-- Rollback: roll back the C-APP code first. Retain these nullable columns and
-- stored PDFs: they are also used by user-PC, and dropping them loses data.
