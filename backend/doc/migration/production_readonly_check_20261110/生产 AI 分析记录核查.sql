-- =====================================================================
-- 生产 AI 分析记录核查.sql
-- 用途：判定 t_ai_candidate_analysis 当前所处迁移阶段，并核查主键/索引/多版本/外键。
-- 安全：仅含 SELECT 与 information_schema 读取；无写入/DDL/动态执行。
-- 阶段定义：
--   阶段0 原始：主键为三元组、无 asr_id、无 02 新列；
--   阶段1 02加列：已加 app_id/snapshot_id/source 等6列，主键仍为三元组；
--   阶段2 DR3重构：主键为单列 asr_id，存在 idx_asr_company_position_candidate。
-- =====================================================================

-- 0.0 执行前确认当前数据库（防止误在其他库执行；预期为目标库名，若不符立即停止）
SELECT DATABASE() AS current_database;

-- 3.1 当前主键列与列序（判断是单列还是复合主键）
-- 预期：阶段0/1 返回三列 company,position,candidate；阶段2 返回单列 asr_id。
SELECT ordinal_position, column_name
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
  AND constraint_name = 'PRIMARY'
ORDER BY ordinal_position;

-- 3.2 主键列数（单值；1=已重构单列主键，3=原始/02阶段复合主键，其余=异常）
SELECT COUNT(*) AS pk_column_count
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
  AND constraint_name = 'PRIMARY';

-- 3.3 asr_id 是否存在（单值：1=已加 asr_id，0=未加）
-- 异常判定：asr_id 存在但主键不是 asr_id，属中间态，标记 BLOCKED 人工核对。
SELECT COUNT(*) AS has_asr_id
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
  AND column_name = 'asr_id';

-- 3.4 关键列存在性一次性盘点（三元组 + app_id + snapshot_id + source + 各迁移列）
-- 预期：按当前阶段对应列存在；列缺失即未进入该阶段。
SELECT column_name, column_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
  AND column_name IN (
    'asr_id','asr_company_id','asr_position_id','asr_candidate_id',
    'asr_app_id','asr_snapshot_id','asr_content_hash','asr_source',
    'asr_version_status','asr_created_at')
ORDER BY column_name;

-- 3.5 迁移阶段严格综合判定（内层汇总指标，外层判定；禁止仅凭主键列数）
-- 指标：pk_columns 主键列名及顺序、asr_id_present、added_column_count(02六字段0-6)、
--   dr3_index_present(DR3索引“名称”是否存在)、dr3_index_ok(DR3索引结构是否正确)、
--   idx02_present_count(02四索引“名称”实际存在数 0-4)、idx02_ok_count(02四索引结构正确数 0-4)。
-- 索引完整结构校验五要素：non_unique=1、index_type=BTREE、列数量、列顺序、sub_part 全 NULL。
-- 02 四索引定义取自 02_schema.sql 的 p_ensure_index（均非唯一/BTREE/无前缀）：
--   idx_asr_app(asr_app_id,asr_source,asr_created_at)、idx_asr_snapshot(asr_snapshot_id)、
--   idx_asr_company_candidate(asr_company_id,asr_candidate_id)、
--   idx_asr_company_position(asr_company_id,asr_position_id)。
SELECT m.*,
  CASE
    -- STAGE0：复合主键正确、asr_id 不存在、02六字段全缺、DR3索引不存在、02四索引名称全部不存在
    WHEN m.pk_columns = 'asr_company_id,asr_position_id,asr_candidate_id'
         AND m.asr_id_present = 0
         AND m.added_column_count = 0
         AND m.dr3_index_present = 0
         AND m.idx02_present_count = 0
      THEN 'STAGE0_ORIGINAL'
    -- STAGE1：复合主键正确、asr_id 不存在、02六字段齐全、DR3索引不存在、02四索引结构全部正确
    WHEN m.pk_columns = 'asr_company_id,asr_position_id,asr_candidate_id'
         AND m.asr_id_present = 0
         AND m.added_column_count = 6
         AND m.dr3_index_present = 0
         AND m.idx02_ok_count = 4
      THEN 'STAGE1_AFTER_02'
    -- STAGE2：主键明确为 asr_id、02六字段齐全、DR3索引结构正确、02四索引结构全部正确
    WHEN m.pk_columns = 'asr_id'
         AND m.added_column_count = 6
         AND m.dr3_index_ok = 1
         AND m.idx02_ok_count = 4
      THEN 'STAGE2_AFTER_DR3'
    ELSE 'INCONSISTENT'
  END AS migration_stage
FROM (
  SELECT
    (SELECT GROUP_CONCAT(column_name ORDER BY ordinal_position)
       FROM information_schema.key_column_usage
      WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
        AND constraint_name = 'PRIMARY') AS pk_columns,
    (SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
        AND column_name = 'asr_id') AS asr_id_present,
    (SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
        AND column_name IN ('asr_app_id','asr_snapshot_id','asr_content_hash',
                            'asr_source','asr_version_status','asr_created_at'))
      AS added_column_count,
    (SELECT COUNT(DISTINCT index_name) FROM information_schema.statistics
      WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
        AND index_name = 'idx_asr_company_position_candidate') AS dr3_index_present,
    (SELECT COUNT(*) FROM (
        SELECT index_name FROM information_schema.statistics
         WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
           AND index_name = 'idx_asr_company_position_candidate'
         GROUP BY index_name
        HAVING MAX(non_unique) = 1 AND COUNT(*) = 3
           AND SUM(CASE WHEN sub_part IS NULL THEN 0 ELSE 1 END) = 0
           AND SUM(CASE WHEN index_type <> 'BTREE' THEN 1 ELSE 0 END) = 0
           AND GROUP_CONCAT(column_name ORDER BY seq_in_index)
               = 'asr_company_id,asr_position_id,asr_candidate_id'
      ) t) AS dr3_index_ok,
    (SELECT COUNT(DISTINCT index_name) FROM information_schema.statistics
      WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
        AND index_name IN ('idx_asr_app','idx_asr_snapshot',
                           'idx_asr_company_candidate','idx_asr_company_position'))
      AS idx02_present_count,
    (SELECT COUNT(*) FROM (
        SELECT e.index_name
        FROM (
          SELECT 'idx_asr_app' AS index_name, 'asr_app_id,asr_source,asr_created_at' AS exp_list, 3 AS exp_count
          UNION ALL SELECT 'idx_asr_snapshot', 'asr_snapshot_id', 1
          UNION ALL SELECT 'idx_asr_company_candidate', 'asr_company_id,asr_candidate_id', 2
          UNION ALL SELECT 'idx_asr_company_position', 'asr_company_id,asr_position_id', 2
        ) e
        JOIN (
          SELECT index_name, MAX(non_unique) AS non_unique, COUNT(*) AS col_count,
                 GROUP_CONCAT(column_name ORDER BY seq_in_index) AS col_list,
                 SUM(CASE WHEN sub_part IS NULL THEN 0 ELSE 1 END) AS prefix_cnt,
                 SUM(CASE WHEN index_type <> 'BTREE' THEN 1 ELSE 0 END) AS badtype_cnt
            FROM information_schema.statistics
           WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
           GROUP BY index_name
        ) a ON a.index_name = e.index_name
        WHERE a.non_unique = 1 AND a.col_count = e.exp_count
          AND a.col_list = e.exp_list AND a.prefix_cnt = 0 AND a.badtype_cnt = 0
      ) ok) AS idx02_ok_count
) m;

-- 3.6 全部索引名称、列序、唯一性、前缀（核对索引是否符合当前阶段）
-- 异常判定：出现当前阶段不应有的索引（如已重构仍保留复合唯一键）需人工确认。
SELECT index_name, non_unique, seq_in_index, column_name, sub_part
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
ORDER BY index_name, seq_in_index;

-- 3.7 DR3 三元组普通索引是否存在且结构正确（单值：1=结构正确，0=缺失/不符）
-- 与 3.5 内 dr3_index_ok 完全同一口径：非唯一、BTREE、3列、列序 company,position,candidate、无前缀。
SELECT COUNT(*) AS dr3_triple_index_ok
FROM (
  SELECT index_name
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 't_ai_candidate_analysis'
    AND index_name = 'idx_asr_company_position_candidate'
  GROUP BY index_name
  HAVING MAX(non_unique) = 1
     AND COUNT(*) = 3
     AND SUM(CASE WHEN sub_part IS NULL THEN 0 ELSE 1 END) = 0
     AND SUM(CASE WHEN index_type <> 'BTREE' THEN 1 ELSE 0 END) = 0
     AND GROUP_CONCAT(column_name ORDER BY seq_in_index)
         = 'asr_company_id,asr_position_id,asr_candidate_id'
) x;

-- 3.8 外键核查（预期：本表无外键，且无外键引用本表；任一非 0 标记 BLOCKED）
SELECT
  (SELECT COUNT(*) FROM information_schema.key_column_usage
    WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis'
      AND referenced_table_name IS NOT NULL) AS outgoing_fk,
  (SELECT COUNT(*) FROM information_schema.key_column_usage
    WHERE table_schema=DATABASE() AND referenced_table_name='t_ai_candidate_analysis')
    AS incoming_fk;

-- 3.9 重复三元组数量与最大重复度（阶段2 用于确认多版本规模；阶段0/1 应无重复）
SELECT COUNT(*) AS duplicate_groups, COALESCE(MAX(cnt), 0) AS max_versions
FROM (
  SELECT asr_company_id, asr_position_id, asr_candidate_id, COUNT(*) AS cnt
  FROM t_ai_candidate_analysis
  GROUP BY asr_company_id, asr_position_id, asr_candidate_id
  HAVING COUNT(*) > 1
) d;

-- 3.10 多版本明细（列出存在多版本的三元组及其 llm/manual 计数，仅观察不修改）
SELECT asr_company_id, asr_position_id, asr_candidate_id,
       SUM(CASE WHEN asr_source='llm' THEN 1 ELSE 0 END) AS llm_cnt,
       SUM(CASE WHEN asr_source='manual' THEN 1 ELSE 0 END) AS manual_cnt,
       SUM(CASE WHEN asr_source IS NULL THEN 1 ELSE 0 END) AS null_cnt,
       COUNT(*) AS total_cnt
FROM t_ai_candidate_analysis
WHERE (asr_company_id, asr_position_id, asr_candidate_id) IN (
  SELECT asr_company_id, asr_position_id, asr_candidate_id
  FROM t_ai_candidate_analysis
  GROUP BY asr_company_id, asr_position_id, asr_candidate_id
  HAVING COUNT(*) > 1
)
GROUP BY asr_company_id, asr_position_id, asr_candidate_id
ORDER BY total_cnt DESC, asr_company_id;
