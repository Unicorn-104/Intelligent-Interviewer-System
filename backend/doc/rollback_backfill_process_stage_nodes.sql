-- ============================================================================
-- 历史流程节点回填 · 回滚（只设计，未执行；执行需用户明确授权）
-- 日期：2026-11-05  作者：tqy
--
-- 范围：仅删除本次回填产生的节点与人工核查台账；
--   不删除运行时（ApplicationStatusService/ProcessStageInstanceService）正常写入的节点。
-- 判定依据：本次回填的节点均带 pis_ref_id，且笔试节点 pis_node_name='在线笔试'、
--   面试节点 pis_ref_id 来自 t_sch_appointment。为精确限定，按回填来源删除：
--   1) 笔试：pis_node_type=1 且 pis_ref_id 来自可关联的 t_exam_record
--   2) 面试：pis_node_type IN (2,3) 且 pis_ref_id 来自 t_sch_appointment
-- 注意：若回滚前运行时已在同一实例新增节点，本脚本只按来源删除历史回填行，
--   不触碰运行时新增的、pis_ref_id 不在历史单据集合内的节点。
-- ============================================================================

-- 1) 删除回填的笔试节点
DELETE p FROM t_process_instance_stage p
JOIN t_exam_record r ON r.erc_id = p.pis_ref_id AND p.pis_node_type = 1
JOIN t_exam_schedule s ON s.esd_id = r.erc_schedule_id
WHERE p.pis_ref_id IS NOT NULL;

-- 2) 删除回填的面试节点
DELETE p FROM t_process_instance_stage p
JOIN t_sch_appointment a ON a.apt_id = p.pis_ref_id
WHERE p.pis_node_type IN (2,3) AND p.pis_ref_id IS NOT NULL;

-- 3) 清空并移除人工核查台账
DROP TABLE IF EXISTS t_stage_backfill_review_20261105;

-- 4) 回滚后核对（只读）：节点表应回到回填前状态（生产当前为 0 行）
SELECT 'rollback_node_count' AS check_item, COUNT(*) AS cnt FROM t_process_instance_stage;
SELECT 'rollback_review_table_exists' AS check_item,
       EXISTS(SELECT 1 FROM information_schema.tables
           WHERE table_schema = DATABASE()
             AND table_name = 't_stage_backfill_review_20261105') AS exists_flag;
