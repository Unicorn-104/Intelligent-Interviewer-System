-- Remove only task-context fields added by migration_capp_ai_task_context_20261021.sql.
SET @capp_ai_task_type_exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 't_capp_ai_run' AND column_name = 'task_type'
);
SET @capp_ai_task_type_sql := IF(
  @capp_ai_task_type_exists = 1,
  'ALTER TABLE t_capp_ai_run DROP COLUMN task_type',
  'SELECT 1'
);
PREPARE capp_ai_task_type_stmt FROM @capp_ai_task_type_sql;
EXECUTE capp_ai_task_type_stmt;
DEALLOCATE PREPARE capp_ai_task_type_stmt;

SET @capp_ai_application_exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 't_capp_ai_run' AND column_name = 'application_id'
);
SET @capp_ai_application_sql := IF(
  @capp_ai_application_exists = 1,
  'ALTER TABLE t_capp_ai_run DROP COLUMN application_id',
  'SELECT 1'
);
PREPARE capp_ai_application_stmt FROM @capp_ai_application_sql;
EXECUTE capp_ai_application_stmt;
DEALLOCATE PREPARE capp_ai_application_stmt;
