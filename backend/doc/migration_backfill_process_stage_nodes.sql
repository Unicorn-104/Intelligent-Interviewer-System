-- ============================================================================
-- 岗位投递状态重构 · 历史流程节点回填（只设计，未执行；执行需用户明确授权）
-- 日期：2026-11-05  作者：tqy
--
-- 前置条件（执行顺序，缺一不可）：
--   1) migration_app_status_refactor_ddl_20261105.sql 已执行
--      （t_process_instance_stage 已补 pis_node_type/pis_round/pis_result/
--        pis_ref_id/pis_node_name，pis_stage_id 已可空）
--   2) migration_app_status_refactor_data_20261105.sql 已执行（app_status 已为六态）
--   3) 既有 migration_backfill_process_instances_20261027.sql 已补齐流程实例
--
-- 口径（与运行时代码逐行对齐，不另起规则）：
--   - 笔试节点：pis_node_type=1、pis_node_name='在线笔试'、pis_ref_id=erc_id；
--     仅回填能经 t_exam_schedule 关联到现存流程实例的笔试记录，
--     丢失 t_exam_schedule 的孤儿记录不建节点，列人工核查表。
--   - 面试节点：apt_stage_type=2 → pis_node_type=2，其余（含 3/4/NULL）→ 3，
--     与 InterviewScheduleServiceImpl.nodeTypeOf 完全一致；type 2/3 共享轮次；
--     pis_ref_id=apt_id；改期为同 apt_id 的 UPDATE，不产生新节点，无需特殊去重。
--   - 轮次：同实例、同类型组内按业务单据ID（=创建先后）ROW_NUMBER 排序，
--     笔试(type1)单独成组，面试(type2/3)合并成组，与 ProcessStageInstanceService.createNode 一致。
--   - 幂等：按 (pis_ref_id, pis_node_type) 判重，重复执行零新增。
--   - 不改 app_status、不写 t_app_status_log、不把终态实例重新激活
--     （终态实例只补历史已结束/已取消节点，不新增待开始/进行中节点）。
--
-- 回滚：见 rollback_backfill_process_stage_nodes.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. 回填前检查（只读，人工确认输出）
-- ----------------------------------------------------------------------------
SELECT '01_node_before' AS check_item, COUNT(*) AS cnt FROM t_process_instance_stage;
SELECT '02_app_total' AS check_item, COUNT(*) AS cnt FROM t_app_record;
SELECT '03_orphan_exam_records' AS check_item, COUNT(*) AS cnt
  FROM t_exam_record r LEFT JOIN t_exam_schedule s ON s.esd_id = r.erc_schedule_id
  WHERE s.esd_id IS NULL;
SELECT '04_linkable_exam_records' AS check_item, COUNT(*) AS cnt
  FROM t_exam_record r JOIN t_exam_schedule s ON s.esd_id = r.erc_schedule_id
  JOIN t_process_instance pi ON pi.pin_candidate_id = r.erc_candidate_id
      AND pi.pin_position_id = s.esd_position_id;
SELECT '05_linkable_appointments' AS check_item, COUNT(*) AS cnt
  FROM t_sch_appointment a JOIN t_process_instance pi
      ON pi.pin_candidate_id = a.apt_candidate_id AND pi.pin_position_id = a.apt_position_id;
SELECT '06_completed_apt_without_evaluation' AS check_item, COUNT(*) AS cnt
  FROM t_sch_appointment a
  WHERE a.apt_status = 3
    AND NOT EXISTS (SELECT 1 FROM t_int_session ts
        JOIN t_int_evaluation e ON e.evl_session_id = ts.ses_id
        WHERE ts.ses_appointment_id = a.apt_id);

-- ----------------------------------------------------------------------------
-- 1. 人工核查台账（幂等建表）：记录无法可靠回填或需人工确认的单据
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS t_stage_backfill_review_20261105 (
    sbr_id bigint NOT NULL AUTO_INCREMENT COMMENT '核查ID',
    sbr_source varchar(20) NOT NULL COMMENT '来源：EXAM_ORPHAN/INTERVIEW_NO_EVAL/INTERVIEW_TYPE_SPECIAL',
    sbr_ref_id bigint NOT NULL COMMENT '业务单据ID（erc_id/apt_id）',
    sbr_candidate_id bigint DEFAULT NULL COMMENT '候选人ID',
    sbr_position_id bigint DEFAULT NULL COMMENT '岗位ID（无法判定为NULL）',
    sbr_reason varchar(255) NOT NULL COMMENT '待核查原因',
    sbr_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (sbr_id),
    UNIQUE KEY uk_sbr_source_ref (sbr_source, sbr_ref_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='节点回填人工核查台账';

-- 1.1 孤儿笔试记录（考试安排已删除，岗位/实例无法还原，不建节点）
INSERT INTO t_stage_backfill_review_20261105
    (sbr_source, sbr_ref_id, sbr_candidate_id, sbr_position_id, sbr_reason)
SELECT 'EXAM_ORPHAN', r.erc_id, r.erc_candidate_id, NULL,
       '关联 t_exam_schedule 已不存在，岗位与流程实例无法还原，未回填节点'
FROM t_exam_record r LEFT JOIN t_exam_schedule s ON s.esd_id = r.erc_schedule_id
WHERE s.esd_id IS NULL
  AND NOT EXISTS (SELECT 1 FROM t_stage_backfill_review_20261105 v
      WHERE v.sbr_source='EXAM_ORPHAN' AND v.sbr_ref_id = r.erc_id);

-- 1.2 已完成但无评估报告的面试（通过/未通过无法判定，不伪造结果）
INSERT INTO t_stage_backfill_review_20261105
    (sbr_source, sbr_ref_id, sbr_candidate_id, sbr_position_id, sbr_reason)
SELECT 'INTERVIEW_NO_EVAL', a.apt_id, a.apt_candidate_id, a.apt_position_id,
       '预约已完成但 t_int_evaluation 缺失，节点结果无法判定，先置已完成-结果为空'
FROM t_sch_appointment a
WHERE a.apt_status = 3
  AND NOT EXISTS (SELECT 1 FROM t_int_session ts
      JOIN t_int_evaluation e ON e.evl_session_id = ts.ses_id
      WHERE ts.ses_appointment_id = a.apt_id)
  AND NOT EXISTS (SELECT 1 FROM t_stage_backfill_review_20261105 v
      WHERE v.sbr_source='INTERVIEW_NO_EVAL' AND v.sbr_ref_id = a.apt_id);

-- 1.3 特殊面试方式（编程实操 type4 / 方式快照 NULL），运行时统一映射为 type3，列台账确认
INSERT INTO t_stage_backfill_review_20261105
    (sbr_source, sbr_ref_id, sbr_candidate_id, sbr_position_id, sbr_reason)
SELECT 'INTERVIEW_TYPE_SPECIAL', a.apt_id, a.apt_candidate_id, a.apt_position_id,
       CONCAT('apt_stage_type=', IFNULL(a.apt_stage_type,-1),
              '，按运行时 nodeTypeOf 统一映射为 HR综合面试(type3)，请确认')
FROM t_sch_appointment a
WHERE (a.apt_stage_type IS NULL OR a.apt_stage_type NOT IN (2,3))
  AND NOT EXISTS (SELECT 1 FROM t_stage_backfill_review_20261105 v
      WHERE v.sbr_source='INTERVIEW_TYPE_SPECIAL' AND v.sbr_ref_id = a.apt_id);

-- ----------------------------------------------------------------------------
-- 2. 正式回填 · 笔试节点（pis_node_type=1）
--    仅处理能关联到现存实例的笔试记录；结果按实际 erc_status/erc_pass_status 映射
-- ----------------------------------------------------------------------------
INSERT INTO t_process_instance_stage (
    pis_instance_id, pis_stage_id, pis_node_type, pis_round, pis_status, pis_result,
    pis_ref_id, pis_node_name, pis_operator_id, pis_start_at, pis_end_at, pis_result_note)
SELECT x.instanceId, NULL, 1, x.round, x.nodeStatus, x.nodeResult,
       x.ercId, '在线笔试', NULL, x.startAt, x.endAt, NULL
FROM (
    SELECT pi.pin_id AS instanceId, r.erc_id AS ercId,
           ROW_NUMBER() OVER (PARTITION BY pi.pin_id ORDER BY r.erc_id) AS round,
           CASE
               WHEN r.erc_status = 0 THEN 0
               WHEN r.erc_status = 1 THEN 1
               WHEN r.erc_status IN (2,4) AND r.erc_pass_status = 1 THEN 2
               WHEN r.erc_status IN (2,4) AND r.erc_pass_status = 0 THEN 2
               WHEN r.erc_status = 3 THEN 2
               ELSE 1
           END AS nodeStatus,
           CASE
               WHEN r.erc_status IN (2,4) AND r.erc_pass_status = 1 THEN 1
               WHEN r.erc_status IN (2,4) AND r.erc_pass_status = 0 THEN 2
               WHEN r.erc_status = 3 THEN 3
               ELSE NULL
           END AS nodeResult,
           r.erc_start_at AS startAt,
           CASE
               WHEN r.erc_status IN (2,3,4) THEN COALESCE(r.erc_submit_at, r.erc_updated_at)
               ELSE NULL
           END AS endAt
    FROM t_exam_record r
    JOIN t_exam_schedule s ON s.esd_id = r.erc_schedule_id
    JOIN t_process_instance pi ON pi.pin_candidate_id = r.erc_candidate_id
        AND pi.pin_position_id = s.esd_position_id
) x
WHERE NOT EXISTS (SELECT 1 FROM t_process_instance_stage p
    WHERE p.pis_ref_id = x.ercId AND p.pis_node_type = 1);

-- ----------------------------------------------------------------------------
-- 3. 正式回填 · 面试节点（type 2/3 共享轮次；状态按 apt_status 映射）
-- ----------------------------------------------------------------------------
INSERT INTO t_process_instance_stage (
    pis_instance_id, pis_stage_id, pis_node_type, pis_round, pis_status, pis_result,
    pis_ref_id, pis_node_name, pis_operator_id, pis_start_at, pis_end_at, pis_result_note)
SELECT x.instanceId, x.stageId, x.nodeType, x.round, x.nodeStatus, NULL,
       x.aptId, x.nodeName, x.operatorId, x.startAt, x.endAt, x.resultNote
FROM (
    SELECT pi.pin_id AS instanceId, a.apt_stage_id AS stageId,
           CASE WHEN a.apt_stage_type = 2 THEN 2 ELSE 3 END AS nodeType,
           ROW_NUMBER() OVER (PARTITION BY pi.pin_id ORDER BY a.apt_id) AS round,
           CASE a.apt_status
               WHEN 2 THEN 3
               WHEN 3 THEN 2
               ELSE 0
           END AS nodeStatus,
           a.apt_id AS aptId,
           COALESCE(a.apt_stage_name, '面试') AS nodeName,
           a.apt_interviewer_id AS operatorId,
           CASE WHEN a.apt_status = 3 THEN a.apt_start_time ELSE NULL END AS startAt,
           CASE
               WHEN a.apt_status = 2 THEN a.apt_updated_at
               WHEN a.apt_status = 3 THEN a.apt_end_time
               ELSE NULL
           END AS endAt,
           CASE WHEN a.apt_status = 2 THEN a.apt_cancel_reason ELSE NULL END AS resultNote
    FROM t_sch_appointment a
    JOIN t_process_instance pi ON pi.pin_candidate_id = a.apt_candidate_id
        AND pi.pin_position_id = a.apt_position_id
) x
WHERE NOT EXISTS (SELECT 1 FROM t_process_instance_stage p
    WHERE p.pis_ref_id = x.aptId AND p.pis_node_type = x.nodeType);

-- ----------------------------------------------------------------------------
-- 4. 回填后核对（只读）
-- ----------------------------------------------------------------------------
SELECT '07_node_after' AS check_item, COUNT(*) AS cnt FROM t_process_instance_stage;
SELECT '08_node_by_type' AS check_item, pis_node_type AS node_type, COUNT(*) AS cnt
  FROM t_process_instance_stage GROUP BY pis_node_type ORDER BY pis_node_type;
SELECT '09_orphan_node' AS check_item, COUNT(*) AS cnt
  FROM t_process_instance_stage p
  WHERE NOT EXISTS (SELECT 1 FROM t_process_instance pi WHERE pi.pin_id = p.pis_instance_id);
SELECT '10_duplicate_ref' AS check_item, COUNT(*) AS cnt FROM (
    SELECT pis_ref_id, pis_node_type, COUNT(*) AS c FROM t_process_instance_stage
    GROUP BY pis_ref_id, pis_node_type HAVING COUNT(*) > 1) d;
SELECT '11_open_node_in_terminal_instance' AS check_item, COUNT(*) AS cnt
  FROM t_process_instance_stage p JOIN t_process_instance pi ON pi.pin_id = p.pis_instance_id
  WHERE p.pis_status IN (0,1) AND pi.pin_status IN (1,2,3);
SELECT '12_review_ledger_total' AS check_item, COUNT(*) AS cnt
  FROM t_stage_backfill_review_20261105;
SELECT sbr_source, sbr_ref_id, sbr_candidate_id, sbr_position_id, sbr_reason
  FROM t_stage_backfill_review_20261105 ORDER BY sbr_source, sbr_ref_id;
