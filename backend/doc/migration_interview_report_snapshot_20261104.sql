-- HR 调整评分前留存 AI 原始评估快照，用于终审页「AI 原评 vs 当前评分」对比
-- 执行库：与 t_int_evaluation 所在业务库一致；需 MySQL 5.7+（使用 json_object）

ALTER TABLE t_int_evaluation
    ADD COLUMN evl_ai_snapshot json NULL COMMENT 'HR 调整前的 AI 原始评估快照' AFTER evl_hr_comment;

-- 回滚：
-- ALTER TABLE t_int_evaluation DROP COLUMN evl_ai_snapshot;
