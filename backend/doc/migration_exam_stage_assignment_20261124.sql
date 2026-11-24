-- 笔试阶段化与候选人分配（2026-11-24）
-- 目的：把考试场次、岗位流程阶段和候选人资格分开保存。
-- 执行顺序：先备份相关表，再执行本脚本，最后部署后端。

SET @db := DATABASE();

-- 流程实例固定使用创建投递时的模板版本。历史实例暂留 NULL，迁移前由业务核对。
SET @sql := IF((SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema=@db AND table_name='t_process_instance' AND column_name='pin_template_version')=0,
    'ALTER TABLE t_process_instance ADD COLUMN pin_template_version varchar(32) DEFAULT NULL COMMENT ''投递使用的不可变流程版本''',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 考试场次必须绑定一个具体笔试阶段；旧场次先允许 NULL，完成历史回填后再收紧。
SET @sql := IF((SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema=@db AND table_name='t_exam_schedule' AND column_name='esd_stage_id')=0,
    'ALTER TABLE t_exam_schedule ADD COLUMN esd_stage_id bigint DEFAULT NULL COMMENT ''岗位流程笔试阶段ID''',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF((SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema=@db AND table_name='t_exam_schedule' AND column_name='esd_template_version')=0,
    'ALTER TABLE t_exam_schedule ADD COLUMN esd_template_version varchar(32) DEFAULT NULL COMMENT ''考试场次使用的流程版本''',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF((SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema=@db AND table_name='t_exam_schedule' AND column_name='esd_stage_snapshot_json')=0,
    'ALTER TABLE t_exam_schedule ADD COLUMN esd_stage_snapshot_json json DEFAULT NULL COMMENT ''阶段名称/类型/顺序快照''',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS t_exam_schedule_candidate (
    esc_id bigint NOT NULL AUTO_INCREMENT,
    esc_schedule_id bigint NOT NULL,
    esc_application_id bigint DEFAULT NULL,
    esc_candidate_id bigint NOT NULL,
    esc_process_instance_id bigint DEFAULT NULL,
    esc_stage_id bigint DEFAULT NULL,
    esc_template_version varchar(32) DEFAULT NULL,
    esc_stage_node_id bigint DEFAULT NULL,
    esc_source varchar(32) NOT NULL DEFAULT 'manual',
    esc_assignment_revision int NOT NULL DEFAULT 1,
    esc_assigned_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    esc_revoked_at datetime DEFAULT NULL,
    esc_notify_at datetime DEFAULT NULL,
    esc_notify_count int NOT NULL DEFAULT 0,
    esc_last_notify_status varchar(32) DEFAULT NULL,
    esc_last_notify_error varchar(500) DEFAULT NULL,
    esc_notify_result_json json DEFAULT NULL,
    esc_created_by bigint DEFAULT NULL,
    esc_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    esc_updated_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (esc_id),
    UNIQUE KEY uk_exam_schedule_candidate (esc_schedule_id, esc_candidate_id),
    KEY idx_exam_candidate_stage (esc_candidate_id, esc_stage_id, esc_revoked_at),
    KEY idx_exam_schedule_active (esc_schedule_id, esc_revoked_at),
    KEY idx_exam_application (esc_application_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='笔试场次候选人分配与通知审计';

-- 仅建立查询索引，不对历史 stage_id=NULL 节点强行加唯一约束。
SET @sql := IF((SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema=@db AND table_name='t_process_instance_stage' AND index_name='idx_exam_stage_instance')=0,
    'ALTER TABLE t_process_instance_stage ADD KEY idx_exam_stage_instance (pis_instance_id, pis_stage_id, pis_node_type)',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT 'exam_stage_assignment migration prepared; backfill legacy versions/nodes before tightening NULL columns' AS migration_status;
