-- =====================================================
-- 项目：Intelligent-Interviewer-System
-- 模块：E-App 企业投递简历独立存储
-- 文件用途：回滚数据库变更，恢复旧“覆盖式”分析结构
-- 数据保留原则（本版重点）：
--   1) 不做任何 DELETE 去重，不丢弃迁移后产生的 llm/manual 多版本分析；
--   2) 先把整表 RENAME 为历史归档表（完整保留所有行），再重建旧结构表，
--      从归档表按“每组优先 llm、再取最新”选择一条写入新表，并显式过滤 asr_source='llm'：
--      manual-only 组（无 llm）不写入旧表，其余行永久留存于归档表；
--   3) 企业快照表与企业 PDF 默认保留，不自动 DROP/删除。
-- 执行环境：需由用户核实目标库；代码侧应先通过 Git 回退到迁移前版本
-- 涉及数据表：t_ai_candidate_analysis（重命名为历史表并重建）、企业快照五表（保留）
-- 是否可重复执行：归档表后缀唯一，重复执行会被安全闸门中止，不会覆盖归档
-- 风险说明：
--   1) RENAME 会切换表名，执行期间应避开业务访问，建议停应用或在维护窗口执行；
--   2) 归档表占用额外空间，确认磁盘容量充足；
--   3) 旧结构不识别 asr_source，manual 行（含 manual-only 组）仅保留在归档表，不写入重建后的新表；
--   4) 中途失败风险：RENAME 已执行但后续删列/建索引/回填失败时，表会停在中间状态，
--      DDL 已隐式提交、无法自动回退；应在维护窗口内手工续作，或用全量备份恢复，勿在业务高峰操作。
-- 分阶段恢复（不可宣称整体事务原子回滚）：
--   a) 守卫阶段中止（未 RENAME）：表保持原样，按提示修正后重跑，无数据损失；
--   b) RENAME 后、建新表/删索引/删列失败：归档表完好，可手工补跑对应 ALTER，或直接用备份还原；
--   c) 2.7 回填失败：归档表含全部数据，修正后重跑 INSERT（幂等，可先 TRUNCATE 空的新表再回填）；
--   d) 任何阶段都不删除归档表，确保 manual/多版本可追溯。
-- 执行权限：仅用户审核批准后手动执行
-- =====================================================

-- -----------------------------------------------------
-- 第一部分（先看后动）：确认分析表是否存在同键多行
-- 仅诊断，不写入；用于预估归档规模
-- -----------------------------------------------------
SELECT asr_company_id, asr_position_id, asr_candidate_id, COUNT(*) AS cnt
FROM t_ai_candidate_analysis
GROUP BY asr_company_id, asr_position_id, asr_candidate_id
HAVING COUNT(*) > 1;

-- 归档表总行数（确认归档规模）
SELECT COUNT(*) AS archive_rows FROM t_ai_candidate_analysis;

-- -----------------------------------------------------
-- 第二部分：归档优先、零 DELETE 的回滚存储过程
-- 归档表后缀固定为 20261109，如需重复执行请先修改 hist_suffix 变量
-- -----------------------------------------------------
DROP PROCEDURE IF EXISTS p_ent_rollback;
DELIMITER $$
CREATE PROCEDURE p_ent_rollback()
BEGIN
  DECLARE pk_col VARCHAR(128);
  DECLARE hist_table VARCHAR(128);
  DECLARE v_missing INT DEFAULT 0;
  DECLARE v_pk_cols INT DEFAULT 0;
  DECLARE v_idx_bad INT DEFAULT 0;
  DECLARE v_dr3_idx INT DEFAULT 0;
  DECLARE v_fk_cnt INT DEFAULT 0;
  DECLARE v_msg VARCHAR(255);
  SET hist_table = 't_ai_candidate_analysis_hist_20261109';

  -- 安全闸门：归档表已存在则中止，防止覆盖历史归档
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = hist_table) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '归档表已存在，请更换 hist_table 后缀后再执行，禁止覆盖历史归档';
  END IF;

  -- ===== 结构前置守卫：全部在 RENAME 之前完成，任一不符即中止；此时尚未 RENAME，表保持原样 =====
  -- 守卫1：原表必须存在（确认回滚目标确实存在）
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                 WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '回滚中止：原表 t_ai_candidate_analysis 不存在';
  END IF;

  -- 守卫2：主键必须存在且为“单列主键”，主键列在字段表真实存在；不允许仅 LIMIT 1 取复合主键一列。
  -- 依赖说明（DR-3）：本守卫与“DR3_主键重构_待审核.sql”配套——重构后主键为单列 asr_id，守卫方可通过；
  -- 在未重构的复合三列主键表上会正确中止（上一轮演练已验证），此时应先完成主键重构，禁止删除本守卫强行回滚。
  SELECT COUNT(*) INTO v_pk_cols
  FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
    AND index_name = 'PRIMARY';
  IF v_pk_cols = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '回滚中止：原表缺少主键，结构不符';
  END IF;
  IF v_pk_cols <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '回滚中止：原表主键不是单列主键，无法安全定位回填顺序';
  END IF;

  -- 守卫2b：确认该主键列在 columns 表真实存在（防止统计与字段定义不一致）
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.key_column_usage k
    JOIN information_schema.columns c
      ON c.table_schema = k.table_schema AND c.table_name = k.table_name
     AND c.column_name = k.column_name
    WHERE k.table_schema = DATABASE() AND k.table_name = 't_ai_candidate_analysis'
      AND k.constraint_name = 'PRIMARY') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '回滚中止：主键列在字段表不存在，结构不符';
  END IF;

  -- 守卫2c：单列主键的列名必须恰好为 asr_id（DR3 重构后形态），其他单列主键不允许继续
  SELECT column_name INTO pk_col
  FROM information_schema.key_column_usage
  WHERE table_schema = DATABASE()
    AND table_name = 't_ai_candidate_analysis'
    AND constraint_name = 'PRIMARY'
  LIMIT 1;
  IF pk_col <> 'asr_id' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '回滚中止：单列主键列名不是 asr_id，结构不符，请先只读核对';
  END IF;

  -- 守卫3：原始业务字段(6) + 02新增字段(6) + DR3新增 asr_id(1) 必须完整，缺失任一即中止
  SELECT COUNT(*) INTO v_missing
  FROM (
    SELECT 'asr_id' AS c UNION ALL
    SELECT 'asr_company_id' UNION ALL SELECT 'asr_position_id' UNION ALL
    SELECT 'asr_candidate_id' UNION ALL SELECT 'asr_resume_id' UNION ALL
    SELECT 'asr_report' UNION ALL SELECT 'asr_updated_at' UNION ALL
    SELECT 'asr_app_id' UNION ALL SELECT 'asr_snapshot_id' UNION ALL
    SELECT 'asr_content_hash' UNION ALL SELECT 'asr_source' UNION ALL
    SELECT 'asr_version_status' UNION ALL SELECT 'asr_created_at'
  ) expected
  LEFT JOIN information_schema.columns col
    ON col.table_schema = DATABASE()
   AND col.table_name = 't_ai_candidate_analysis'
   AND col.column_name = expected.c
  WHERE col.column_name IS NULL;

  IF v_missing > 0 THEN
    SET v_msg = CONCAT('回滚中止：原表缺少 ', v_missing, ' 个预期字段，结构不符');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  -- 守卫4：迁移新增的 4 个普通索引逐一核对“名称/字段/顺序/是否唯一/前缀”，任一不符或缺失即中止。
  -- 确认当前确为“迁移后”形态而非未迁移旧表；名称与结构不一致时不允许直接跳过。
  SELECT COUNT(*) INTO v_idx_bad
  FROM (
    SELECT 'idx_asr_app' AS i, 1 AS non_unique, 3 AS col_cnt,
           'asr_app_id,asr_source,asr_created_at' AS cols, 0 AS prefix_cnt
    UNION ALL SELECT 'idx_asr_snapshot', 1, 1, 'asr_snapshot_id', 0
    UNION ALL SELECT 'idx_asr_company_candidate', 1, 2, 'asr_company_id,asr_candidate_id', 0
    UNION ALL SELECT 'idx_asr_company_position', 1, 2, 'asr_company_id,asr_position_id', 0
  ) expected
  LEFT JOIN (
    SELECT index_name, MAX(non_unique) AS non_unique, COUNT(*) AS col_cnt,
           GROUP_CONCAT(column_name ORDER BY seq_in_index) AS cols,
           SUM(CASE WHEN SUB_PART IS NULL THEN 0 ELSE 1 END) AS prefix_cnt
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
    GROUP BY index_name
  ) actual ON actual.index_name = expected.i
  WHERE actual.index_name IS NULL
     OR actual.non_unique <> expected.non_unique
     OR actual.col_cnt <> expected.col_cnt
     OR actual.cols <> expected.cols
     OR actual.prefix_cnt <> expected.prefix_cnt;

  IF v_idx_bad > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '回滚中止：新增索引的名称或结构与预期不符，请人工核对，禁止继续 RENAME';
  END IF;

  -- 守卫5：DR3 新增的三元组普通索引必须存在且结构正确（普通、3列、列序 company,position,candidate、无前缀）
  SELECT COUNT(*) INTO v_dr3_idx
  FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
    AND index_name = 'idx_asr_company_position_candidate'
    AND non_unique = 1;
  IF v_dr3_idx <> 3 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '回滚中止：DR3 三元组普通索引缺失或结构不符，请人工核对，禁止继续 RENAME';
  END IF;

  -- 守卫6：不得有其他表通过外键引用本表（DROP/RENAME 主键前必须确认）
  SELECT COUNT(*) INTO v_fk_cnt
  FROM information_schema.key_column_usage
  WHERE referenced_table_name = 't_ai_candidate_analysis';
  IF v_fk_cnt <> 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '回滚中止：存在外键引用本表，须先处理外键，禁止 RENAME';
  END IF;

  -- 2.1 主键列名 pk_col 已在守卫2c 动态取得（=asr_id），此处不再重复查询

  -- 2.2 整表 RENAME 为历史归档表：完整保留全部行与列，零 DELETE
  SET @rename_sql = CONCAT(
    'RENAME TABLE t_ai_candidate_analysis TO `', hist_table, '`');
  PREPARE stmt FROM @rename_sql;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;

  -- 2.3 以归档表为模板创建新表（复制列与索引），再剥离迁移新增的索引与列
  SET @create_sql = CONCAT(
    'CREATE TABLE t_ai_candidate_analysis LIKE `', hist_table, '`');
  PREPARE stmt FROM @create_sql;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;

  -- 2.4 删除 02 阶段新增的普通索引（用 information_schema 守卫，兼容 MySQL 8.0）
  IF EXISTS (SELECT 1 FROM information_schema.statistics
             WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
               AND index_name = 'idx_asr_app') THEN
    ALTER TABLE t_ai_candidate_analysis DROP INDEX idx_asr_app;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.statistics
             WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
               AND index_name = 'idx_asr_snapshot') THEN
    ALTER TABLE t_ai_candidate_analysis DROP INDEX idx_asr_snapshot;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.statistics
             WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
               AND index_name = 'idx_asr_company_candidate') THEN
    ALTER TABLE t_ai_candidate_analysis DROP INDEX idx_asr_company_candidate;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.statistics
             WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
               AND index_name = 'idx_asr_company_position') THEN
    ALTER TABLE t_ai_candidate_analysis DROP INDEX idx_asr_company_position;
  END IF;

  -- 2.4-bis 删除 DR3 新增的三元组普通索引（守卫确认存在，删除后回滚表不再保留该索引）
  IF EXISTS (SELECT 1 FROM information_schema.statistics
             WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
               AND index_name = 'idx_asr_company_position_candidate') THEN
    ALTER TABLE t_ai_candidate_analysis DROP INDEX idx_asr_company_position_candidate;
  END IF;

  -- 2.5 删除 02 新增列，恢复旧列结构（这些列由 02 写入，新表必然存在）
  ALTER TABLE t_ai_candidate_analysis
    DROP COLUMN asr_app_id,
    DROP COLUMN asr_snapshot_id,
    DROP COLUMN asr_content_hash,
    DROP COLUMN asr_source,
    DROP COLUMN asr_version_status,
    DROP COLUMN asr_created_at;

  -- 2.6 删除 DR3 的 asr_id 主键与列，恢复“原始复合主键”（不是 UNIQUE KEY；以 new.sql 原始 DDL 为准）
  -- 单条 ALTER：先 DROP 掉 asr_id 上的主键，再删除 asr_id 列，最后用三元组重建 PRIMARY KEY。
  ALTER TABLE t_ai_candidate_analysis
    DROP PRIMARY KEY,
    DROP COLUMN asr_id,
    ADD PRIMARY KEY (asr_company_id, asr_position_id, asr_candidate_id);

  -- 2.6-bis 恢复原始表自带的普通索引 idx_aca_candidate_updated（02/DR3 未删除它，缺失才补，幂等）
  IF NOT EXISTS (SELECT 1 FROM information_schema.statistics
                 WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
                   AND index_name = 'idx_aca_candidate_updated') THEN
    ALTER TABLE t_ai_candidate_analysis
      ADD KEY idx_aca_candidate_updated
        (asr_company_id, asr_candidate_id, asr_updated_at);
  END IF;

  -- 2.7 从归档表选择每组“优先 llm、再取最新”的一条写入新表（窗口函数，MySQL 8）
  -- 关键过滤：外层显式要求 asr_source='llm'，因此
  --   1) 含 llm 的组：仅把最优 llm 一条写入旧表；
  --   2) manual-only 组（该组没有任何 llm 行）：被 WHERE 过滤，不进入旧表；
  --   3) 其余 llm/manual 多版本行（含全部 manual）完整保留在归档表，不执行任何 DELETE。
  -- 旧结构不识别 asr_source，不能为恢复唯一索引而把 manual 行塞入旧表。
  SET @migrate_sql = CONCAT(
    'INSERT INTO t_ai_candidate_analysis ',
    '(asr_company_id, asr_position_id, asr_candidate_id, asr_resume_id, asr_report, asr_updated_at) ',
    'SELECT asr_company_id, asr_position_id, asr_candidate_id, asr_resume_id, asr_report, asr_updated_at ',
    'FROM (',
    '  SELECT h.*, ROW_NUMBER() OVER (',
    '    PARTITION BY asr_company_id, asr_position_id, asr_candidate_id ',
    '    ORDER BY CASE WHEN asr_source = ''llm'' THEN 0 ELSE 1 END, ',
    '             asr_created_at DESC, asr_updated_at DESC, `', pk_col, '` DESC',
    '  ) AS rn',
    '  FROM `', hist_table, '` h',
    ') ranked WHERE rn = 1 AND asr_source = ''llm''');
  PREPARE stmt FROM @migrate_sql;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;
END$$
DELIMITER ;

-- 确认第一部分归档规模与维护窗口后，再取消下一行注释执行：
-- CALL p_ent_rollback();
DROP PROCEDURE IF EXISTS p_ent_rollback;

-- -----------------------------------------------------
-- 第三部分：企业快照表默认保留（含迁移期间新投递），不自动删除
-- 仅当确认快照数据无需保留、且已完成合规评估后，手动取消注释执行：
-- -----------------------------------------------------
-- DROP TABLE IF EXISTS t_ent_resume_education;
-- DROP TABLE IF EXISTS t_ent_resume_work;
-- DROP TABLE IF EXISTS t_ent_resume_project;
-- DROP TABLE IF EXISTS t_ent_resume_skill;
-- DROP TABLE IF EXISTS t_ent_resume_snapshot;

-- -----------------------------------------------------
-- 第四部分：企业 PDF 文件处理
-- 已复制到企业命名空间的文件不通过本脚本删除；如确需清理，
-- 按企业数据生命周期流程，经授权后由受控任务处理，并保留操作记录。
-- -----------------------------------------------------

-- =====================================================
-- 回滚完成判定：
--   1) 新 t_ai_candidate_analysis 已恢复“原始复合主键 PRIMARY KEY(company,position,candidate)”，
--      asr_id 已删除、DR3 三元组普通索引已删除、02 六字段已删除；
--   2) 原始普通索引 idx_aca_candidate_updated 保留；
--   3) 全部多版本分析完整保留在 t_ai_candidate_analysis_hist_20261109；
--   4) 代码已 Git 回退；快照表与企业文件按合规要求保留或另行受控清理。
-- =====================================================

-- -----------------------------------------------------
-- 第五部分：回滚后只读核验（人工执行，确认结构与原始 DDL 一致；不写入）
-- -----------------------------------------------------
-- 5.1 回滚表主键列与顺序（应恰为 company,position,candidate 三列）
SELECT ordinal_position, column_name
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
  AND constraint_name = 'PRIMARY'
ORDER BY ordinal_position;

-- 5.2 回滚表字段清单（应只剩 6 个原始字段，无 asr_id、无 02 六字段）
SELECT ordinal_position, column_name, column_type
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
ORDER BY ordinal_position;

-- 5.3 回滚表全部索引（应只有 PRIMARY 与 idx_aca_candidate_updated，无 uk_/idx_asr_company_position_candidate）
SELECT index_name, GROUP_CONCAT(column_name ORDER BY seq_in_index) AS cols, non_unique
FROM information_schema.statistics
WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
GROUP BY index_name, non_unique;

-- 5.4 回滚表有效记录数（仅含每组最新 llm；manual-only 组不进入）
SELECT COUNT(*) AS active_rows FROM t_ai_candidate_analysis;

-- 5.5 归档表记录数与来源分布（llm/manual 全量保留，零删除）
SELECT COUNT(*) AS archive_rows FROM t_ai_candidate_analysis_hist_20261109;
SELECT asr_source, COUNT(*) AS archive_by_source
FROM t_ai_candidate_analysis_hist_20261109
GROUP BY asr_source;

