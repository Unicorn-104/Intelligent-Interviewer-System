-- 投递流程实例回填（2026-10-27）
--
-- 背景：修复前新投递只写 t_app_record，不创建 t_process_instance，
-- 导致企业端岗位详情「求职者」、投递漏斗、AI 筛选与面试排期看不到新求职者。
-- 代码修复后新投递由后端自动创建实例；本脚本为存量投递补齐。
--
-- 特性：
--   - 幂等，可重复执行；只处理缺失实例的投递记录。
--   - 只为「有投递但未绑定流程模板」的岗位创建空模板并绑定，
--     已配置招聘流程的岗位直接复用现有模板。
--   - 实例起始阶段取模板第一个阶段；模板暂无阶段时为 NULL。
--
-- 执行前请先备份 t_pos / t_process_template / t_process_instance /
-- t_app_record / t_tal 五张表，并在目标库确认后执行。

-- 1) 为「有投递但未绑定流程模板」的岗位创建空模板
INSERT INTO t_process_template (ptl_company_id, ptl_name, ptl_position_id, ptl_version, ptl_status)
SELECT p.pos_company_id, '岗位招聘流程', p.pos_id, 'v1.0', 1
FROM t_pos p
WHERE p.pos_process_template_id IS NULL
  AND EXISTS (SELECT 1 FROM t_app_record ar WHERE ar.app_position_id = p.pos_id);

-- 2) 绑定模板（同岗位多个模板时取最新，避免旧数据残留影响）
UPDATE t_pos p
JOIN (SELECT ptl_position_id, MAX(ptl_id) AS latest_id
      FROM t_process_template
      GROUP BY ptl_position_id) t ON t.ptl_position_id = p.pos_id
SET p.pos_process_template_id = t.latest_id
WHERE p.pos_process_template_id IS NULL;

-- 3) 为缺失实例的投递创建流程实例
INSERT INTO t_process_instance
    (pin_candidate_id, pin_position_id, pin_template_id, pin_current_stage_id, pin_status, pin_start_at)
SELECT ar.app_candidate_id, ar.app_position_id, p.pos_process_template_id,
       (SELECT s.psg_id FROM t_process_stage s
        WHERE s.psg_template_id = p.pos_process_template_id
        ORDER BY s.psg_sort_order
        LIMIT 1),
       0, NOW()
FROM t_app_record ar
JOIN t_pos p ON p.pos_id = ar.app_position_id
LEFT JOIN t_process_instance pi
       ON pi.pin_candidate_id = ar.app_candidate_id AND pi.pin_position_id = ar.app_position_id
WHERE pi.pin_id IS NULL
  AND p.pos_process_template_id IS NOT NULL;

-- 4) 投递记录回填实例 id
UPDATE t_app_record ar
JOIN t_process_instance pi
  ON pi.pin_candidate_id = ar.app_candidate_id AND pi.pin_position_id = ar.app_position_id
SET ar.app_process_instance_id = pi.pin_id
WHERE ar.app_process_instance_id IS NULL;

-- 5) 候选人主档回填实例 id（已有实例时保持不变）
UPDATE t_tal t
JOIN t_process_instance pi ON pi.pin_candidate_id = t.tal_id
SET t.tal_process_instance_id = pi.pin_id
WHERE t.tal_process_instance_id IS NULL
  AND pi.pin_id = (SELECT MIN(p.pin_id) FROM t_process_instance p WHERE p.pin_candidate_id = t.tal_id);
