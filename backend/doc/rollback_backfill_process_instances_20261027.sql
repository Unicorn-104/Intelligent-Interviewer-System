-- 投递流程实例回填回滚（2026-10-27）
--
-- 注意：本回滚按时间窗口识别回填创建的实例，仅在回填执行后、
-- 且尚无「代码修复后新投递自动创建」的实例混入时有效。
-- 若回填后已产生新投递，请人工核对 t_process_instance.pin_created_at 后再回滚，
-- 不要盲删可能属于真实新投递的实例。
--
-- 执行前请将下方时间戳改为回填执行时刻之后、下次新投递之前的时刻。

-- 1) 清空回填的实例引用
UPDATE t_app_record ar
JOIN t_process_instance pi ON pi.pin_id = ar.app_process_instance_id
SET ar.app_process_instance_id = NULL
WHERE pi.pin_created_at >= '2026-10-27 15:00:00';

UPDATE t_tal t
JOIN t_process_instance pi ON pi.pin_id = t.tal_process_instance_id
SET t.tal_process_instance_id = NULL
WHERE pi.pin_created_at >= '2026-10-27 15:00:00';

-- 2) 删除回填创建的流程实例
DELETE FROM t_process_instance WHERE pin_created_at >= '2026-10-27 15:00:00';

-- 3) 解除并删除回填创建的空模板（仅无阶段且无实例引用的模板）
UPDATE t_pos p
JOIN t_process_template t ON t.ptl_id = p.pos_process_template_id
SET p.pos_process_template_id = NULL
WHERE t.ptl_created_at >= '2026-10-27 15:00:00'
  AND NOT EXISTS (SELECT 1 FROM t_process_stage s WHERE s.psg_template_id = t.ptl_id)
  AND NOT EXISTS (SELECT 1 FROM t_process_instance pi WHERE pi.pin_template_id = t.ptl_id);

DELETE FROM t_process_template
WHERE ptl_created_at >= '2026-10-27 15:00:00'
  AND NOT EXISTS (SELECT 1 FROM t_process_stage s WHERE s.psg_template_id = t_process_template.ptl_id)
  AND NOT EXISTS (SELECT 1 FROM t_process_instance pi WHERE pi.pin_template_id = t_process_template.ptl_id);
