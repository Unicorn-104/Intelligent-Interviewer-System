-- ============================================================================
-- 岗位投递状态重构：回滚脚本
-- 日期：2026-11-05  作者：tqy
-- 用途：迁移出现问题时，先回滚应用版本，再按本脚本恢复数据与结构
-- 前提：bak_app_record_20261105 备份表存在且完整
-- 注意：回滚为高风险操作，须确认备份可用并在维护窗口执行；结构回滚会删除新增字段/表
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 数据回滚：用备份快照整体覆盖 t_app_record（恢复旧码与旧字段值）
--    先删除迁移后新增的行，再按备份恢复；备份中不存在的新投递（迁移后产生）需人工确认
-- ----------------------------------------------------------------------------
DELETE FROM t_app_record
WHERE app_id NOT IN (SELECT app_id FROM bak_app_record_20261105);

REPLACE INTO t_app_record
SELECT * FROM bak_app_record_20261105;

-- 数据核对：行数应与备份一致
SELECT (SELECT COUNT(*) FROM bak_app_record_20261105) AS backup_rows,
       (SELECT COUNT(*) FROM t_app_record) AS restored_rows;

-- ----------------------------------------------------------------------------
-- 2. 结构回滚（确认数据已恢复、应用已回退到旧版本后再执行）
-- ----------------------------------------------------------------------------
-- 2.1 删除投递状态日志表
DROP TABLE IF EXISTS t_app_status_log;

-- 2.2 删除节点实例表新增列，恢复 pis_stage_id 为 NOT NULL（先清除动态空阶段节点）
DELETE FROM t_process_instance_stage WHERE pis_stage_id IS NULL;
ALTER TABLE t_process_instance_stage
    MODIFY COLUMN pis_stage_id bigint NOT NULL COMMENT '关联招聘流程阶段ID';
ALTER TABLE t_process_instance_stage
    DROP INDEX idx_pis_ref,
    DROP INDEX idx_pis_instance;
ALTER TABLE t_process_instance_stage
    DROP COLUMN pis_node_name,
    DROP COLUMN pis_ref_id,
    DROP COLUMN pis_result,
    DROP COLUMN pis_round,
    DROP COLUMN pis_node_type;

-- 2.3 删除 t_app_record 新增终止字段与索引
ALTER TABLE t_app_record
    DROP INDEX idx_app_end_reason;
ALTER TABLE t_app_record
    DROP COLUMN end_remark,
    DROP COLUMN ended_by,
    DROP COLUMN ended_at,
    DROP COLUMN end_reason;

-- 2.4 备份/核查表按需保留（默认保留以便审计）；确认无需后可手动删除：
-- DROP TABLE bak_app_manual_review_20261105;
-- DROP TABLE bak_app_record_20261105;

-- ----------------------------------------------------------------------------
-- 3. 回滚后核对：t_app_record 应已无终止字段，节点表应已恢复旧结构
-- ----------------------------------------------------------------------------
SELECT column_name FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 't_app_record'
  AND column_name IN ('end_reason','ended_at','ended_by','end_remark');
