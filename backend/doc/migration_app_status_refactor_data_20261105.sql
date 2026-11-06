-- ============================================================================
-- 岗位投递状态重构：历史数据迁移（第 2 步）
-- 日期：2026-11-05  作者：tqy
-- 前置：先执行 migration_app_status_refactor_ddl_20261105.sql 并核对结构
-- 安全：本脚本默认不自动执行；须经负责人确认、先备份、在维护窗口按段执行
-- 关键设计：新码与旧码在 0-5 区间重叠，所有 UPDATE 均以备份表
--   bak_app_record_20261105 中的“原始状态”分类（JOIN 备份），不依赖会被改写的
--   当前 app_status，避免已迁移行被后续语句按同码再次命中
-- 旧码：0待筛选 1初筛通过 2初筛淘汰 3已约面 4待笔试 5笔试中 6笔试通过
--       7笔试未通过 8笔试缺考 9已撤回 10待发Offer 11已录用 12 Offer拒绝/过期
-- 新码：0已投递 1招聘中 2待发Offer 3待确认Offer 4已录用 5未录用
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. 迁移前盘点（只读，先记录结果）
-- ----------------------------------------------------------------------------
SELECT app_status, COUNT(*) AS total
FROM t_app_record GROUP BY app_status ORDER BY app_status;

-- ----------------------------------------------------------------------------
-- 1. 备份（快照表，已存在则不覆盖；后续全部更新与回滚都依赖此表）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bak_app_record_20261105 AS
SELECT * FROM t_app_record;

-- 人工核查台账：存疑记录（笔试未通过/缺考、Offer 关闭原因不明）
CREATE TABLE IF NOT EXISTS bak_app_manual_review_20261105 (
    mr_app_id bigint NOT NULL,
    mr_old_status tinyint NOT NULL,
    mr_reason varchar(200) NOT NULL,
    mr_resolved tinyint NOT NULL DEFAULT 0,
    mr_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (mr_app_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='投递状态迁移人工核查台账';

-- ----------------------------------------------------------------------------
-- 2. 旧 0/1 待筛选/初筛通过：有正式招聘环节→招聘中；否则→已投递
--    正式环节：存在笔试记录，或存在未取消/已完成的面试预约
-- ----------------------------------------------------------------------------
UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id AND b.app_status IN (0, 1)
SET a.app_status = 1, a.app_updated_at = now()
WHERE
   EXISTS (SELECT 1 FROM t_exam_record r
           JOIN t_exam_schedule s ON s.esd_id = r.erc_schedule_id
           WHERE r.erc_candidate_id = a.app_candidate_id AND s.esd_position_id = a.app_position_id)
OR EXISTS (SELECT 1 FROM t_sch_appointment apt
           WHERE apt.apt_candidate_id = a.app_candidate_id
             AND apt.apt_position_id = a.app_position_id AND apt.apt_status IN (0, 1, 3));

UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id AND b.app_status IN (0, 1)
SET a.app_status = 0, a.app_updated_at = now()
WHERE NOT EXISTS (SELECT 1 FROM t_exam_record r
           JOIN t_exam_schedule s ON s.esd_id = r.erc_schedule_id
           WHERE r.erc_candidate_id = a.app_candidate_id AND s.esd_position_id = a.app_position_id)
  AND NOT EXISTS (SELECT 1 FROM t_sch_appointment apt
           WHERE apt.apt_candidate_id = a.app_candidate_id
             AND apt.apt_position_id = a.app_position_id AND apt.apt_status IN (0, 1, 3));

-- ----------------------------------------------------------------------------
-- 3. 旧 2 初筛淘汰：→未录用，历史标记 LEGACY_SCREENING_REJECTED（新业务不再 AI 自动淘汰）
-- ----------------------------------------------------------------------------
UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id AND b.app_status = 2
SET a.app_status = 5,
    a.end_reason = 'LEGACY_SCREENING_REJECTED',
    a.ended_at = a.app_updated_at,
    a.end_remark = '历史 AI 初筛淘汰记录迁移，仅留痕',
    a.app_updated_at = now();

-- ----------------------------------------------------------------------------
-- 4. 旧 3/4/5/6 已约面/待笔试/笔试中/笔试通过：统一→招聘中（节点级状态由节点实例承载）
-- ----------------------------------------------------------------------------
UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id AND b.app_status IN (3, 4, 5, 6)
SET a.app_status = 1, a.app_updated_at = now();

-- ----------------------------------------------------------------------------
-- 5. 旧 7/8 笔试未通过/缺考：无明确 HR 终止记录不得认定为淘汰
--    先登记人工核查台账，再统一落到招聘中（不伪造终止原因），由 HR 后续决定
-- ----------------------------------------------------------------------------
INSERT IGNORE INTO bak_app_manual_review_20261105 (mr_app_id, mr_old_status, mr_reason)
SELECT b.app_id, b.app_status,
       CASE b.app_status WHEN 7 THEN '历史笔试未通过，需 HR 核查是否终止'
                         WHEN 8 THEN '历史笔试缺考，需 HR 核查是否终止' END
FROM bak_app_record_20261105 b
WHERE b.app_status IN (7, 8);

UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id AND b.app_status IN (7, 8)
SET a.app_status = 1, a.app_updated_at = now();

-- ----------------------------------------------------------------------------
-- 6. 旧 9 已撤回：→未录用，CANDIDATE_WITHDRAWN
-- ----------------------------------------------------------------------------
UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id AND b.app_status = 9
SET a.app_status = 5,
    a.end_reason = 'CANDIDATE_WITHDRAWN',
    a.ended_at = a.app_updated_at,
    a.end_remark = '候选人主动撤回（历史迁移）',
    a.app_updated_at = now();

-- ----------------------------------------------------------------------------
-- 7. 旧 10 待发Offer：→待发Offer；旧 11 已录用：→已录用
-- ----------------------------------------------------------------------------
UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id AND b.app_status = 10
SET a.app_status = 2, a.app_updated_at = now();

UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id AND b.app_status = 11
SET a.app_status = 4, a.app_updated_at = now();

-- ----------------------------------------------------------------------------
-- 8. 旧 12 Offer 拒绝/过期：按 t_off_offer.ofr_status 区分（2拒绝 3过期 6 HR撤回）
--    无法对应的进入人工核查，不伪造原因，落到招聘中
-- ----------------------------------------------------------------------------
UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id AND b.app_status = 12
JOIN t_off_offer o ON o.ofr_candidate_id = a.app_candidate_id
                  AND o.ofr_position_id = a.app_position_id
                  AND o.ofr_status IN (2, 3, 6)
SET a.app_status = 5,
    a.end_reason = CASE o.ofr_status WHEN 2 THEN 'OFFER_REJECTED'
                                    WHEN 3 THEN 'OFFER_EXPIRED'
                                    WHEN 6 THEN 'OFFER_CANCELLED' END,
    a.ended_at = ifnull(o.ofr_withdraw_at, a.app_updated_at),
    a.end_remark = 'Offer 关闭历史迁移',
    a.app_updated_at = now();

-- 仍未匹配的旧 12：登记台账并落到招聘中等待人工
INSERT IGNORE INTO bak_app_manual_review_20261105 (mr_app_id, mr_old_status, mr_reason)
SELECT b.app_id, 12, 'Offer 关闭原因无法从 t_off_offer 确认，需人工核查'
FROM bak_app_record_20261105 b
WHERE b.app_status = 12
  AND NOT EXISTS (SELECT 1 FROM t_off_offer o
                  WHERE o.ofr_candidate_id = b.app_candidate_id
                    AND o.ofr_position_id = b.app_position_id AND o.ofr_status IN (2, 3, 6));

UPDATE t_app_record a
JOIN bak_app_record_20261105 b ON b.app_id = a.app_id AND b.app_status = 12
SET a.app_status = 1, a.app_updated_at = now()
WHERE NOT EXISTS (SELECT 1 FROM t_off_offer o
                  WHERE o.ofr_candidate_id = a.app_candidate_id
                    AND o.ofr_position_id = a.app_position_id AND o.ofr_status IN (2, 3, 6));

-- ----------------------------------------------------------------------------
-- 9. 迁移后核对
-- ----------------------------------------------------------------------------
-- 9.1 新状态分布（应只含 0-5）
SELECT app_status, COUNT(*) AS total FROM t_app_record GROUP BY app_status ORDER BY app_status;

-- 9.2 不应再有旧码（应返回 0 行）
SELECT COUNT(*) AS legacy_rows FROM t_app_record WHERE app_status NOT IN (0, 1, 2, 3, 4, 5);

-- 9.3 终止原因只允许出现在未录用（应返回 0 行）
SELECT COUNT(*) AS reason_violation FROM t_app_record
WHERE app_status <> 5 AND (end_reason IS NOT NULL OR ended_at IS NOT NULL);

-- 9.4 未录用但缺终止原因（应可解释，人工核查台账内除外）
SELECT app_id, app_status, end_reason FROM t_app_record WHERE app_status = 5 AND end_reason IS NULL;

-- 9.5 待人工核查清单
SELECT * FROM bak_app_manual_review_20261105 WHERE mr_resolved = 0;

-- 9.6 备份行数应等于当前投递总数
SELECT (SELECT COUNT(*) FROM bak_app_record_20261105) AS backup_rows,
       (SELECT COUNT(*) FROM t_app_record) AS current_rows;
