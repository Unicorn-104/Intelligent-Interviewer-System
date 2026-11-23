-- ============================================================================
-- 修复脚本：t_app_record 历史旧码重映射为六态（针对生产库当前 9 条未迁移数据）
-- 日期：2026-11-09  作者：tqy
-- 背景：生产库此前的“迁移”未真正重映射，旧码（0待筛选/1初筛通过/2初筛淘汰/
--       3已约面/4待笔试）与新六态在 0-5 值域重叠，被新查询错误解释
--       （如旧码 3“已约面”被显示成“待确认Offer”）。
-- 本脚本只做：先备份 → 按“备份表旧码”重映射 → 补历史初筛淘汰终止字段 → 核对。
-- 安全：所有 UPDATE 以备份表旧码分类，并加 a.app_status = b.app_status 幂等保护，
--       重复执行不会二次改写；不写 t_app_status_log（历史迁移不补日志，
--       该表自迁移后由新状态机开始记录）。
-- 回滚：见文末“回滚”段，从备份表整表恢复。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. 执行前盘点（只读，先留存输出作为迁移前基线）
-- ----------------------------------------------------------------------------
SELECT app_status, COUNT(*) AS total
FROM t_app_record GROUP BY app_status ORDER BY app_status;
-- 迁移前实测：0=1, 1=1, 2=2, 3=4, 4=1（共 9 条，无 5）

-- ----------------------------------------------------------------------------
-- 1. 备份（快照表，已存在则不覆盖；后续更新与回滚均依赖此表）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bak_app_record_20261105 AS
SELECT * FROM t_app_record;

-- 备份行数核对（应等于当前投递总数 9）
SELECT (SELECT COUNT(*) FROM bak_app_record_20261105) AS backup_rows,
       (SELECT COUNT(*) FROM t_app_record) AS current_rows;

-- ----------------------------------------------------------------------------
-- 2. 旧码 2 初筛淘汰 → 新码 5 未录用，并补历史初筛淘汰终止字段
--    对应 app_id 45、46（共 2 条）
-- ----------------------------------------------------------------------------
UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id
SET a.app_status     = 5,
    a.end_reason     = 'LEGACY_SCREENING_REJECTED',
    a.ended_at       = now(),
    a.ended_by       = NULL,
    a.end_remark     = '历史 AI 初筛淘汰记录迁移，仅留痕',
    a.app_updated_at = now()
WHERE b.app_status = 2
  AND a.app_status = b.app_status;   -- 幂等：仅未迁移行命中

-- ----------------------------------------------------------------------------
-- 3. 旧码 3 已约面 / 旧码 4 待笔试 → 新码 1 招聘中（节点级状态由流程节点承载）
--    对应 app_id 47、48、49、52、71（共 5 条）
-- ----------------------------------------------------------------------------
UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id
SET a.app_status     = 1,
    a.app_updated_at = now()
WHERE b.app_status IN (3, 4)
  AND a.app_status = b.app_status;

-- ----------------------------------------------------------------------------
-- 4. 旧码 0 待筛选 / 旧码 1 初筛通过，且无任何正式环节（笔试记录/有效预约）
--    → 新码 0 已投递。对应 app_id 70、78（共 2 条，已实测两类环节均为 0）
-- ----------------------------------------------------------------------------
UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id
SET a.app_status     = 0,
    a.app_updated_at = now()
WHERE b.app_status IN (0, 1)
  AND a.app_status = b.app_status
  AND NOT EXISTS (SELECT 1 FROM t_exam_record r
                  JOIN t_exam_schedule s ON s.esd_id = r.erc_schedule_id
                  WHERE r.erc_candidate_id = a.app_candidate_id
                    AND s.esd_position_id = a.app_position_id)
  AND NOT EXISTS (SELECT 1 FROM t_sch_appointment apt
                  WHERE apt.apt_candidate_id = a.app_candidate_id
                    AND apt.apt_position_id = a.app_position_id
                    AND apt.apt_status IN (0, 1, 3));

-- ----------------------------------------------------------------------------
-- 5. 执行后核对（人工确认输出）
-- ----------------------------------------------------------------------------
-- 5.1 新状态分布（预期：0=2, 1=5, 5=2；2/3/4 应为 0）
SELECT app_status, COUNT(*) AS total
FROM t_app_record GROUP BY app_status ORDER BY app_status;

-- 5.2 备份表旧码 vs 当前新码逐条对照（确认每条都已正确变更）
SELECT a.app_id, b.app_status AS old_status, a.app_status AS new_status, a.end_reason
FROM t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id
ORDER BY a.app_id;

-- 5.3 终止字段只允许出现在新码 5（应返回 0 行）
SELECT COUNT(*) AS reason_violation FROM t_app_record
WHERE app_status <> 5 AND (end_reason IS NOT NULL OR ended_at IS NOT NULL);

-- 5.4 新码 5 但缺终止原因（应返回 0 行）
SELECT app_id FROM t_app_record
WHERE app_status = 5 AND end_reason IS NULL;

-- 5.5 备份行数仍等于当前行数（应都为 9）
SELECT (SELECT COUNT(*) FROM bak_app_record_20261105) AS backup_rows,
       (SELECT COUNT(*) FROM t_app_record) AS current_rows;

-- ============================================================================
-- 回滚（如需撤销本次迁移，确认后单独执行以下语句；默认注释，不随主流程执行）
-- ============================================================================
-- UPDATE t_app_record a
-- JOIN bak_app_record_20261105 b ON b.app_id = a.app_id
-- SET a.app_status     = b.app_status,
--     a.app_updated_at = b.app_updated_at,
--     a.end_reason     = b.end_reason,
--     a.ended_at       = b.ended_at,
--     a.ended_by       = b.ended_by,
--     a.end_remark     = b.end_remark;
-- 确认回滚正确后，可再执行：DROP TABLE bak_app_record_20261105;
