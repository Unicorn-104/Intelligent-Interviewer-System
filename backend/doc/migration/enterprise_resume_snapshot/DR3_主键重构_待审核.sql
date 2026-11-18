-- =====================================================
-- 项目：Intelligent-Interviewer-System
-- 文件：DR3_主键重构_待审核.sql
-- 用途：把 t_ai_candidate_analysis 由“复合三列主键(覆盖式)”重构为
--       “asr_id 单列自增主键 + 三元组普通索引(追加式)”，消除多版本 INSERT 主键冲突
-- 重要：本文件仅生成、不自动执行；所有 CALL 默认注释，须用户审核后本人手动执行
-- 执行时机：建议在 02_schema 完成之后（旧非主键唯一索引已删除、6 新列已就位）
-- 依赖：执行前请先跑 DR3_主键只读核对.sql，确认真实结构与本文件前置假设一致
-- =====================================================


-- #####################################################
-- 第一部分：执行前诊断（只读，不写入）
-- #################################################

-- 1.1 当前主键列与列数（预期：3 列，company/position/candidate）
SELECT GROUP_CONCAT(column_name ORDER BY ordinal_position) AS pk_columns,
       COUNT(*) AS pk_column_count
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
  AND constraint_name = 'PRIMARY';

-- 1.2 asr_id 是否已存在（预期：0；若为 1 说明已重构，勿重复执行）
SELECT COUNT(*) AS asr_id_exists
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
  AND column_name = 'asr_id';

-- 1.3 是否有其他表外键引用本表（预期：0；有则禁止直接改主键）
SELECT COUNT(*) AS referencing_fk_count
FROM information_schema.key_column_usage
WHERE referenced_table_name = 't_ai_candidate_analysis';

-- 1.4 记录总行数（用于变更前后比对，确认不丢数据）
SELECT COUNT(*) AS total_rows_before FROM t_ai_candidate_analysis;


-- #####################################################
-- 第二部分：数据冲突检测（只读）
-- 复合主键约束下理论上不会重复；若有触发器/旁路写入产生重复，须先人工处理
-- #####################################################
SELECT asr_company_id, asr_position_id, asr_candidate_id, COUNT(*) AS cnt
FROM t_ai_candidate_analysis
GROUP BY asr_company_id, asr_position_id, asr_candidate_id
HAVING COUNT(*) > 1;


-- #####################################################
-- 第三部分：正向主键迁移存储过程（仅定义；内部含完整前置守卫）
-- #####################################################
DROP PROCEDURE IF EXISTS p_dr3_pk_rebuild;
DELIMITER $$
CREATE PROCEDURE p_dr3_pk_rebuild()
BEGIN
  DECLARE v_pk_cnt INT DEFAULT 0;
  DECLARE v_asr_id_exists INT DEFAULT 0;
  DECLARE v_fk_cnt INT DEFAULT 0;
  DECLARE v_dup_cnt INT DEFAULT 0;
  DECLARE v_rows_before BIGINT DEFAULT 0;
  DECLARE v_rows_after BIGINT DEFAULT 0;

  -- 守卫0：表必须存在
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                 WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '中止：t_ai_candidate_analysis 不存在';
  END IF;

  -- 守卫1：当前主键必须恰好为复合三列
  SELECT COUNT(*) INTO v_pk_cnt
  FROM information_schema.key_column_usage
  WHERE table_schema = DATABASE()
    AND table_name = 't_ai_candidate_analysis'
    AND constraint_name = 'PRIMARY';
  IF v_pk_cnt <> 3 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '中止：当前主键不是预期的复合三列，结构不符，请先只读核对';
  END IF;

  -- 守卫2：asr_id 必须不存在，防止重复重构
  SELECT COUNT(*) INTO v_asr_id_exists
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 't_ai_candidate_analysis'
    AND column_name = 'asr_id';
  IF v_asr_id_exists <> 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '中止：asr_id 已存在，疑似已重构，禁止重复执行';
  END IF;

  -- 守卫3：无外键引用本表
  SELECT COUNT(*) INTO v_fk_cnt
  FROM information_schema.key_column_usage
  WHERE referenced_table_name = 't_ai_candidate_analysis';
  IF v_fk_cnt <> 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '中止：存在外键引用本表，须先处理外键';
  END IF;

  -- 守卫4：无同三元组重复行
  SELECT COUNT(*) INTO v_dup_cnt FROM (
    SELECT 1
    FROM t_ai_candidate_analysis
    GROUP BY asr_company_id, asr_position_id, asr_candidate_id
    HAVING COUNT(*) > 1
  ) d;
  IF v_dup_cnt <> 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '中止：存在同三元组重复数据，须人工核实后再改';
  END IF;

  SELECT COUNT(*) INTO v_rows_before FROM t_ai_candidate_analysis;

  -- 核心变更（单条 ALTER，表重建一次）：
  --   a) 删除旧复合主键；
  --   b) 首位新增 asr_id 自增列，为历史行自动分配连续 id；
  --   c) asr_id 设为新主键；
  --   d) 三元组降级为普通索引，保留按企业/岗位/候选人的查询能力（非唯一，允许多版本）。
  ALTER TABLE t_ai_candidate_analysis
    DROP PRIMARY KEY,
    ADD COLUMN asr_id BIGINT NOT NULL AUTO_INCREMENT FIRST,
    ADD PRIMARY KEY (asr_id),
    ADD KEY idx_asr_company_position_candidate
      (asr_company_id, asr_position_id, asr_candidate_id);

  -- 变更后校验：行数必须一致
  SELECT COUNT(*) INTO v_rows_after FROM t_ai_candidate_analysis;
  IF v_rows_after <> v_rows_before THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '异常：变更前后行数不一致，请立即用备份核对，勿继续业务写入';
  END IF;
END$$
DELIMITER ;

-- 手动执行（确认第一/二部分诊断无异常后，由用户本人取消注释执行）：
-- CALL p_dr3_pk_rebuild();
-- 执行后核验：新主键应为单列 asr_id，三元组普通索引存在，行数不变
SELECT GROUP_CONCAT(column_name ORDER BY ordinal_position) AS pk_columns_after
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
  AND constraint_name = 'PRIMARY';


-- #####################################################
-- 第四部分：回滚存储过程（仅定义；区分“无多版本”与“已产生多版本”）
-- #####################################################
DROP PROCEDURE IF EXISTS p_dr3_pk_rebuild_rollback;
DELIMITER $$
CREATE PROCEDURE p_dr3_pk_rebuild_rollback()
BEGIN
  DECLARE v_asr_id_exists INT DEFAULT 0;
  DECLARE v_dup_groups INT DEFAULT 0;

  -- 守卫：asr_id 必须存在（确认当前确为重构后形态）
  SELECT COUNT(*) INTO v_asr_id_exists
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 't_ai_candidate_analysis'
    AND column_name = 'asr_id';
  IF v_asr_id_exists = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '中止：未发现 asr_id，当前不是重构后结构';
  END IF;

  -- 检测是否已产生同三元组多版本
  SELECT COUNT(*) INTO v_dup_groups FROM (
    SELECT 1
    FROM t_ai_candidate_analysis
    GROUP BY asr_company_id, asr_position_id, asr_candidate_id
    HAVING COUNT(*) > 1
  ) d;

  IF v_dup_groups > 0 THEN
    -- 已多版本：直接恢复复合主键会因重复失败，必须走“归档+重建”，
    -- 复用 05_rollback.sql 的 RENAME 归档逻辑（每组优先 llm 取一条回旧表，其余完整留档）。
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = '已存在多版本，禁止直接 ALTER；请改用 05_rollback.sql 归档式回滚';
  ELSE
    -- 无多版本：可直接恢复旧复合主键并移除 asr_id 与三元组普通索引
    ALTER TABLE t_ai_candidate_analysis
      DROP PRIMARY KEY,
      DROP KEY idx_asr_company_position_candidate,
      DROP COLUMN asr_id,
      ADD PRIMARY KEY (asr_company_id, asr_position_id, asr_candidate_id);
  END IF;
END$$
DELIMITER ;

-- 手动回滚（仅在确认需要撤销主键重构时，由用户本人取消注释执行）：
-- CALL p_dr3_pk_rebuild_rollback();


-- #####################################################
-- 第五部分：执行顺序说明
-- #####################################################
-- 1) 先执行 DR3_主键只读核对.sql，确认真实主键=复合三列、无 asr_id、无外键；
-- 2) 执行本文件第一部分诊断、第二部分冲突检测，确认无异常；
-- 3) 维护窗口、停应用或隔离写入后，取消注释 CALL p_dr3_pk_rebuild();
-- 4) 执行后核验主键/索引/行数，并在下一阶段授权的 MySQL 8 隔离环境跑多版本验收；
-- 5) 仅当需要撤销时，才 CALL p_dr3_pk_rebuild_rollback()；已多版本则走 05 归档回滚。

-- #####################################################
-- 第六部分：失败恢复方案
-- #####################################################
-- DDL 隐式提交，无法靠单一事务整体回退；以下分阶段处理：
-- a) 守卫阶段中止（未 ALTER）：表保持原样，按提示修正后重跑，无数据损失；
-- b) ALTER 执行中断（数据库异常/实例故障）：用执行前全量逻辑备份+物理备份恢复，勿在业务高峰操作；
-- c) 变更后行数不一致：立即停止写入，以备份核对差异，不自动 DELETE/补数；
-- d) 回滚阶段提示已多版本：改用 05_rollback.sql 的 RENAME 归档，完整保留 manual/多版本；
-- e) 全程不删除归档表、不 DELETE 历史分析，确保可追溯。
