-- ============================================================================
-- 岗位投递状态重构：结构调整 DDL（第 1 步，可重复执行，不修改任何业务数据）
-- 日期：2026-11-05  作者：tqy
-- 口径：t_app_record.app_status 重构为 6 态
--   0 APPLIED 已投递 / 1 IN_PROGRESS 招聘中 / 2 PENDING_OFFER 待发Offer
--   3 OFFER_PENDING_CONFIRMATION 待确认Offer / 4 HIRED 已录用 / 5 NOT_HIRED 未录用
-- 本文件只做：新增终止字段、新增投递状态日志表、激活既有节点实例表
--   t_process_instance_stage（建表后一直未使用，本次优先复用，不重复建表）
-- 数据迁移见 migration_app_status_refactor_data_20261105.sql
-- 回滚见 rollback_app_status_refactor_20261105.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. t_app_record 增加终止信息字段（仅 app_status=5 时允许写入，由状态机在服务端校验）
-- ----------------------------------------------------------------------------
SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 't_app_record' AND column_name = 'end_reason'),
    'SELECT 1', 'ALTER TABLE t_app_record ADD COLUMN end_reason varchar(40) DEFAULT NULL COMMENT ''终止原因编码（仅未录用可填）''');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 't_app_record' AND column_name = 'ended_at'),
    'SELECT 1', 'ALTER TABLE t_app_record ADD COLUMN ended_at datetime DEFAULT NULL COMMENT ''终止时间''');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 't_app_record' AND column_name = 'ended_by'),
    'SELECT 1', 'ALTER TABLE t_app_record ADD COLUMN ended_by bigint DEFAULT NULL COMMENT ''终止操作人（HR 淘汰必填）''');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 't_app_record' AND column_name = 'end_remark'),
    'SELECT 1', 'ALTER TABLE t_app_record ADD COLUMN end_remark varchar(500) DEFAULT NULL COMMENT ''终止原因说明''');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 终止字段索引：未录用列表按原因筛选、人工核查使用
SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 't_app_record' AND index_name = 'idx_app_end_reason'),
    'SELECT 1', 'ALTER TABLE t_app_record ADD KEY idx_app_end_reason (end_reason)');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ----------------------------------------------------------------------------
-- 2. 岗位投递状态变更日志表：每次 app_status 变化留痕，由状态机统一写入
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS t_app_status_log (
    asl_id bigint NOT NULL AUTO_INCREMENT COMMENT '日志ID',
    asl_app_id bigint NOT NULL COMMENT '岗位投递ID',
    asl_candidate_id bigint NOT NULL COMMENT '候选人ID',
    asl_position_id bigint NOT NULL COMMENT '岗位ID',
    asl_from_status tinyint DEFAULT NULL COMMENT '原状态',
    asl_to_status tinyint NOT NULL COMMENT '目标状态',
    asl_operator_id bigint DEFAULT NULL COMMENT '操作人（系统事件为空，按来源区分）',
    asl_source varchar(30) NOT NULL COMMENT '操作来源：HR/AI/EXAM/INTERVIEW/OFFER/SCHEDULER/WITHDRAW',
    asl_reason varchar(500) DEFAULT NULL COMMENT '变更原因',
    asl_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '变更时间',
    PRIMARY KEY (asl_id),
    KEY idx_asl_app (asl_app_id),
    KEY idx_asl_candidate_position (asl_candidate_id, asl_position_id),
    KEY idx_asl_created (asl_created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='岗位投递状态变更日志';

-- ----------------------------------------------------------------------------
-- 3. 激活节点实例表 t_process_instance_stage（每轮笔试/面试一个独立节点）
--    既有列：pis_id/pis_instance_id/pis_stage_id/pis_start_at/pis_end_at/
--            pis_status/pis_operator_id/pis_result_note/pis_created_at
--    最小补列：节点类型快照、轮次、结果编码、业务单据引用、节点名称快照
--    pis_stage_id 改为可空：支持模板之外动态加轮（补考/新一轮）
-- ----------------------------------------------------------------------------
SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 't_process_instance_stage' AND column_name = 'pis_node_type'),
    'SELECT 1', 'ALTER TABLE t_process_instance_stage ADD COLUMN pis_node_type tinyint DEFAULT NULL COMMENT ''节点类型快照：1在线笔试 2AI技术面试 3HR综合面试 4编程实操''');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 't_process_instance_stage' AND column_name = 'pis_round'),
    'SELECT 1', 'ALTER TABLE t_process_instance_stage ADD COLUMN pis_round int DEFAULT NULL COMMENT ''同类型节点轮次（第N轮）''');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 't_process_instance_stage' AND column_name = 'pis_result'),
    'SELECT 1', 'ALTER TABLE t_process_instance_stage ADD COLUMN pis_result tinyint DEFAULT NULL COMMENT ''节点结果：1通过 2未通过 3缺考 4取消''');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 't_process_instance_stage' AND column_name = 'pis_ref_id'),
    'SELECT 1', 'ALTER TABLE t_process_instance_stage ADD COLUMN pis_ref_id bigint DEFAULT NULL COMMENT ''业务单据ID（笔试记录/面试预约）''');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 't_process_instance_stage' AND column_name = 'pis_node_name'),
    'SELECT 1', 'ALTER TABLE t_process_instance_stage ADD COLUMN pis_node_name varchar(100) DEFAULT NULL COMMENT ''节点名称快照''');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- pis_stage_id 放开为可空（动态加轮不一定对应模板阶段）
ALTER TABLE t_process_instance_stage
    MODIFY COLUMN pis_stage_id bigint DEFAULT NULL COMMENT '关联模板阶段ID（模板外动态节点为空）';

SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 't_process_instance_stage' AND index_name = 'idx_pis_instance'),
    'SELECT 1', 'ALTER TABLE t_process_instance_stage ADD KEY idx_pis_instance (pis_instance_id, pis_status)');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @ddl = IF(EXISTS(SELECT 1 FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 't_process_instance_stage' AND index_name = 'idx_pis_ref'),
    'SELECT 1', 'ALTER TABLE t_process_instance_stage ADD KEY idx_pis_ref (pis_ref_id)');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ----------------------------------------------------------------------------
-- 4. 结构核对（执行后人工确认输出）
-- ----------------------------------------------------------------------------
SELECT column_name, column_type FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 't_app_record'
   AND column_name IN ('end_reason','ended_at','ended_by','end_remark')
 ORDER BY ordinal_position;

SELECT table_name FROM information_schema.tables
 WHERE table_schema = DATABASE() AND table_name = 't_app_status_log';

SELECT column_name, column_type, is_nullable FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 't_process_instance_stage'
 ORDER BY ordinal_position;
