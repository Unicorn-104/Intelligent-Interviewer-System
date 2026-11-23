-- =====================================================
-- 项目：Intelligent-Interviewer-System
-- 文件：DR3_主键只读核对.sql
-- 用途：在真实库“只读”核对 t_ai_candidate_analysis 的真实主键/约束/索引/列结构
-- 特性：本文件全部为 SELECT，不做任何写入或结构变更；可安全反复执行
-- 前提：先 USE 到正确业务库；执行结果请脱敏留存，勿粘贴账号密码
-- =====================================================

-- 0. 确认当前库与目标表是否存在（防止在错误库执行）
SELECT DATABASE() AS current_database;
SELECT table_schema, table_name, engine, table_collation, table_comment
FROM information_schema.tables
WHERE table_name = 't_ai_candidate_analysis';

-- 1. 主键由哪些列构成、共几列、列序（判定单列还是复合主键的核心证据）
SELECT ordinal_position, column_name
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
  AND constraint_name = 'PRIMARY'
ORDER BY ordinal_position;

-- 2. 主键列数汇总（=1 单列；=3 复合三列；0 无主键）
SELECT COUNT(*) AS primary_key_column_count
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
  AND constraint_name = 'PRIMARY';

-- 3. 全部唯一约束（含 PRIMARY 与非主键唯一索引），确认是否存在三元组唯一键
SELECT kcu.constraint_name,
       tc.constraint_type,
       GROUP_CONCAT(kcu.column_name ORDER BY kcu.ordinal_position) AS columns_in_order
FROM information_schema.key_column_usage kcu
JOIN information_schema.table_constraints tc
  ON tc.table_schema = kcu.table_schema
 AND tc.table_name = kcu.table_name
 AND tc.constraint_name = kcu.constraint_name
WHERE kcu.table_schema = DATABASE()
  AND kcu.table_name = 't_ai_candidate_analysis'
GROUP BY kcu.constraint_name, tc.constraint_type
ORDER BY kcu.constraint_name;

-- 4. 全部索引明细（含普通索引、是否唯一、前缀 SUB_PART、索引类型）
SELECT index_name, seq_in_index, column_name, non_unique, SUB_PART, index_type
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
ORDER BY index_name, seq_in_index;

-- 5. 全部列定义（确认是否已有 asr_id，以及各列类型/可空/默认值）
SELECT ordinal_position, column_name, column_type, is_nullable, column_default,
       extra, column_comment
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
ORDER BY ordinal_position;

-- 6. 确认是否存在单列自增列 asr_id（预期旧结构为 0）
SELECT COUNT(*) AS asr_id_exists
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
  AND column_name = 'asr_id';

-- 7. 同三元组行数分布（主键约束下不会出现 >1；用于核对是否存在历史异常/触发器旁路数据）
SELECT asr_company_id, asr_position_id, asr_candidate_id, COUNT(*) AS cnt
FROM t_ai_candidate_analysis
GROUP BY asr_company_id, asr_position_id, asr_candidate_id
HAVING COUNT(*) > 1;

-- 8. 确认是否有其他表通过外键引用本表（主键改造前必须确认；预期无输出）
SELECT table_schema, table_name, constraint_name, column_name
FROM information_schema.key_column_usage
WHERE referenced_table_name = 't_ai_candidate_analysis';
