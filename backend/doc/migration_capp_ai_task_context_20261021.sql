-- Additive AI task context fields; safe to re-run on MySQL 8.
SET @capp_ai_application_exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 't_capp_ai_run' AND column_name = 'application_id'
);
SET @capp_ai_application_sql := IF(
  @capp_ai_application_exists = 0,
  'ALTER TABLE t_capp_ai_run ADD COLUMN application_id BIGINT NULL AFTER input_text',
  'SELECT 1'
);
PREPARE capp_ai_application_stmt FROM @capp_ai_application_sql;
EXECUTE capp_ai_application_stmt;
DEALLOCATE PREPARE capp_ai_application_stmt;

SET @capp_ai_task_type_exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 't_capp_ai_run' AND column_name = 'task_type'
);
SET @capp_ai_task_type_sql := IF(
  @capp_ai_task_type_exists = 0,
  'ALTER TABLE t_capp_ai_run ADD COLUMN task_type VARCHAR(32) NOT NULL DEFAULT ''chat'' AFTER application_id',
  'SELECT 1'
);
PREPARE capp_ai_task_type_stmt FROM @capp_ai_task_type_sql;
EXECUTE capp_ai_task_type_stmt;
DEALLOCATE PREPARE capp_ai_task_type_stmt;
