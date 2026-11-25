-- 笔试阶段化与候选人分配回滚（仅回滚本迁移新增结构）。
-- 执行前确认应用代码已回滚，且已备份分配审计数据。

DROP TABLE IF EXISTS t_exam_schedule_candidate;

SET @db := DATABASE();
SET @sql := IF((SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema=@db AND table_name='t_exam_schedule' AND column_name='esd_stage_snapshot_json')>0,
    'ALTER TABLE t_exam_schedule DROP COLUMN esd_stage_snapshot_json', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF((SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema=@db AND table_name='t_exam_schedule' AND column_name='esd_template_version')>0,
    'ALTER TABLE t_exam_schedule DROP COLUMN esd_template_version', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF((SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema=@db AND table_name='t_exam_schedule' AND column_name='esd_stage_id')>0,
    'ALTER TABLE t_exam_schedule DROP COLUMN esd_stage_id', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF((SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema=@db AND table_name='t_process_instance' AND column_name='pin_template_version')>0,
    'ALTER TABLE t_process_instance DROP COLUMN pin_template_version', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF((SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema=@db AND table_name='t_process_instance_stage' AND index_name='idx_exam_stage_instance')>0,
    'ALTER TABLE t_process_instance_stage DROP INDEX idx_exam_stage_instance', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
