-- User PC resume management extension.
-- Re-runnable for MySQL versions that do not support ADD COLUMN IF NOT EXISTS.

SET @schema_name = DATABASE();

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_real_name') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_real_name varchar(50) NULL COMMENT ''resume real name'' AFTER rbs_job_direction',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_gender') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_gender varchar(10) NULL COMMENT ''gender'' AFTER rbs_real_name',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_work_status') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_work_status varchar(30) NULL COMMENT ''work status'' AFTER rbs_gender',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_current_city') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_current_city varchar(50) NULL COMMENT ''current city'' AFTER rbs_work_status',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_phone') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_phone varchar(20) NULL COMMENT ''resume phone'' AFTER rbs_current_city',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_email') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_email varchar(100) NULL COMMENT ''resume email'' AFTER rbs_phone',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_target_role') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_target_role varchar(50) NULL COMMENT ''target role'' AFTER rbs_email',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_salary_expectation') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_salary_expectation varchar(50) NULL COMMENT ''salary expectation'' AFTER rbs_target_role',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_target_city') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_target_city varchar(100) NULL COMMENT ''target city'' AFTER rbs_salary_expectation',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_arrival_time') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_arrival_time varchar(30) NULL COMMENT ''arrival time'' AFTER rbs_target_city',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_file_path') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_file_path varchar(500) NULL COMMENT ''pdf resume resource path'' AFTER rbs_arrival_time',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_file_name') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_file_name varchar(255) NULL COMMENT ''pdf original file name'' AFTER rbs_file_path',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = 't_res_base' AND COLUMN_NAME = 'rbs_file_size') = 0,
    'ALTER TABLE t_res_base ADD COLUMN rbs_file_size bigint NULL COMMENT ''pdf file size bytes'' AFTER rbs_file_name',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
