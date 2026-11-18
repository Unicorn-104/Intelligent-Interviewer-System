-- 候选人状态日志去重 + 移除触发器（2026-11-16）
-- 背景：t_tal 上的 trg_tal_status_log_after_update 与 TalStatusService 双写，每次状态变更产生两条日志。
-- 前置：TalentPoolServiceImpl.updateStatus 已改为逐条调用 TalStatusService，后端不再有直接更新 t_tal.tal_status 的路径。
-- 顺序：备份 -> 删除重复 -> 删除触发器。
-- 注意：本脚本不删除业务日志，只删除触发器写入的“状态变更”重复行。

-- 1. 备份待删除的重复记录（同候选人、同起止状态、60 秒内存在带业务原因的日志）
CREATE TABLE IF NOT EXISTS t_tal_status_log_bak_20261116 AS
SELECT l.*
FROM t_tal_status_log l
WHERE l.tsl_reason = '状态变更'
  AND EXISTS (
      SELECT 1 FROM t_tal_status_log a
      WHERE a.tsl_candidate_id = l.tsl_candidate_id
        AND a.tsl_from_status = l.tsl_from_status
        AND a.tsl_to_status = l.tsl_to_status
        AND a.tsl_reason <> '状态变更'
        AND ABS(TIMESTAMPDIFF(SECOND, a.tsl_created_at, l.tsl_created_at)) <= 60
  );

-- 2. 删除重复记录
DELETE FROM t_tal_status_log
WHERE tsl_id IN (SELECT tsl_id FROM t_tal_status_log_bak_20261116);

-- 3. 删除触发器（反向操作见文件末尾）
DROP TRIGGER IF EXISTS trg_tal_status_log_after_update;

-- ==================== 回滚 ====================
-- 恢复触发器：
-- CREATE DEFINER=`recruit_agent`@`%` TRIGGER `trg_tal_status_log_after_update` AFTER UPDATE ON `t_tal` FOR EACH ROW
-- BEGIN
--     IF NEW.tal_status <> OLD.tal_status THEN
--         INSERT INTO `t_tal_status_log` (tsl_candidate_id, tsl_from_status, tsl_to_status, tsl_operator_id, tsl_reason, tsl_created_at)
--         VALUES (NEW.tal_id, OLD.tal_status, NEW.tal_status, NULL, '状态变更', NOW());
--     END IF;
-- END;
--
-- 恢复被删除的重复数据：
-- INSERT INTO t_tal_status_log SELECT * FROM t_tal_status_log_bak_20261116;
