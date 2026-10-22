-- Rollback only the additive history-actions column.
SET @capp_ai_pinned_exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 't_capp_ai_session' AND column_name = 'pinned'
);
SET @capp_ai_pinned_sql := IF(
  @capp_ai_pinned_exists = 1,
  'ALTER TABLE t_capp_ai_session DROP COLUMN pinned',
  'SELECT 1'
);
PREPARE capp_ai_pinned_stmt FROM @capp_ai_pinned_sql;
EXECUTE capp_ai_pinned_stmt;
DEALLOCATE PREPARE capp_ai_pinned_stmt;
