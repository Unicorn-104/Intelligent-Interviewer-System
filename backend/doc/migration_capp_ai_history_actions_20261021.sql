-- Additive migration for AI conversation actions; safe to re-run on MySQL 8.
SET @capp_ai_pinned_exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 't_capp_ai_session' AND column_name = 'pinned'
);
SET @capp_ai_pinned_sql := IF(
  @capp_ai_pinned_exists = 0,
  'ALTER TABLE t_capp_ai_session ADD COLUMN pinned TINYINT NOT NULL DEFAULT 0',
  'SELECT 1'
);
PREPARE capp_ai_pinned_stmt FROM @capp_ai_pinned_sql;
EXECUTE capp_ai_pinned_stmt;
DEALLOCATE PREPARE capp_ai_pinned_stmt;
