-- =====================================================
-- 项目：Intelligent-Interviewer-System
-- 模块：E-App 企业投递简历独立存储
-- 文件用途：创建 5 张企业简历快照表，并把 t_ai_candidate_analysis 改造为“追加式 + 版本绑定”
-- 执行环境：需由用户核实目标库；执行前提：已人工确认 01_precheck.sql 结果
--
-- 【本版执行方式：分阶段手动执行，禁止整份一次运行】
--   所有业务 DDL（CREATE/ALTER/DROP INDEX）均封装在存储过程内，顶层不保留任何裸业务 DDL；
--   因此不放开并执行对应 CALL，就不会产生任何结构变更，从脚本结构上杜绝“CALL 被注释却已部分迁移”。
--   精确顺序：先跑“只读诊断” → 定义并执行阶段0守卫 → 定义并执行阶段1迁移 → 阶段2确认后清理过程。
--
-- 【首次迁移 vs 旧版升级 适用条件】
--   情况A 首次迁移：企业快照表此前不存在，由 p_ent_schema_migrate 内 CREATE TABLE IF NOT EXISTS 建表，
--                   历史回填显式 BACKFILL_REAL/BACKFILL_UNKNOWN，实时新投递由后端写 LIVE_REAL/LIVE_ORIGINAL。
--   情况B 旧版部分迁移：企业表或字段已存在，先跑下方只读诊断；time_source 对 NULL 行按证据受控回填，
--                   已存在的非空值若缺乏证据不自动覆盖，统一进人工核查清单，不得把历史默认成实时。
--
-- 数据影响：DDL（建表、加列、调整索引），不删除任何业务数据；幂等可重复执行
-- 回滚文件：05_rollback.sql
-- 不可回滚边界：CREATE/ALTER/DROP INDEX 均为 DDL，MySQL 隐式提交，无法用事务整体回滚；失败按 05 或人工处置
-- 执行权限：仅用户审核批准后手动执行
-- =====================================================


-- #####################################################
-- 第〇部分：旧版升级只读诊断（仅 SELECT，不修改任何数据）
-- #####################################################
-- 判定口径（先看诊断 A，再决定是否调用诊断过程）：
--   诊断 A 返回 0 行            -> 快照表不存在 -> 首次迁移，跳过 B/C，直接按阶段1建表。
--   诊断 A 三字段齐全            -> 旧版升级且字段完整，诊断过程返回 B 分布 + C 明细。
--   诊断 A 缺少任一字段          -> 旧版缺字段，诊断过程只返回缺失清单与行数，不执行会报错的 B/C。
-- #####################################################

-- 诊断 A（环境门禁，纯 information_schema，任何环境都不会报错）：
--   一次性列出快照表及三个必需字段的真实定义；表不存在返回 0 行，缺字段则该列不出现。
SELECT t.table_name, c.column_name, c.is_nullable, c.column_default, c.column_type
FROM information_schema.tables t
LEFT JOIN information_schema.columns c
  ON c.table_schema = t.table_schema AND c.table_name = t.table_name
 AND c.column_name IN ('ers_time_source','ers_version_verified','ers_snapshot_at')
WHERE t.table_schema = DATABASE() AND t.table_name = 't_ent_resume_snapshot'
ORDER BY c.column_name;

-- 诊断 B/C 封装为只读过程：内部按 information_schema 结果分支，
-- 从结构上保证“表不存在 / 字段缺失”时绝不直接访问业务列，因此不会报错。
DROP PROCEDURE IF EXISTS p_ent_diag_upgrade;
DELIMITER $$
CREATE PROCEDURE p_ent_diag_upgrade()
BEGIN
  DECLARE v_tbl_exists INT DEFAULT 0;
  DECLARE v_has_ts INT DEFAULT 0;
  DECLARE v_has_vv INT DEFAULT 0;
  DECLARE v_has_sa INT DEFAULT 0;

  -- 快照表是否存在
  SELECT COUNT(*) INTO v_tbl_exists
  FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 't_ent_resume_snapshot';

  IF v_tbl_exists = 0 THEN
    -- 首次迁移：表不存在，不执行 B/C，仅返回环境标记
    SELECT 'FIRST_MIGRATION' AS env,
           '快照表不存在，按首次迁移建表，跳过B/C数据诊断' AS msg;
  ELSE
    -- 三个必需字段是否存在
    SELECT COUNT(*) INTO v_has_ts FROM information_schema.columns
      WHERE table_schema=DATABASE() AND table_name='t_ent_resume_snapshot' AND column_name='ers_time_source';
    SELECT COUNT(*) INTO v_has_vv FROM information_schema.columns
      WHERE table_schema=DATABASE() AND table_name='t_ent_resume_snapshot' AND column_name='ers_version_verified';
    SELECT COUNT(*) INTO v_has_sa FROM information_schema.columns
      WHERE table_schema=DATABASE() AND table_name='t_ent_resume_snapshot' AND column_name='ers_snapshot_at';

    IF v_has_ts = 1 AND v_has_vv = 1 AND v_has_sa = 1 THEN
      -- 字段齐全：执行诊断 B（time_source 三值 + NULL 分布）
      SET @sql_b = 'SELECT COALESCE(ers_time_source,''__NULL__'') AS time_source, COUNT(*) AS cnt
                    FROM t_ent_resume_snapshot GROUP BY ers_time_source ORDER BY time_source';
      PREPARE stmt_b FROM @sql_b;
      EXECUTE stmt_b;
      DEALLOCATE PREPARE stmt_b;

      -- 执行诊断 C（可疑/可回填明细，reason 非 OK 即人工核查清单）
      --   SUSPECT_LIVE_REAL_NO_EVIDENCE  标了实时但无 LIVE_ORIGINAL 证据
      --   SUSPECT_UNKNOWN_BUT_HAS_TIME   标未知但实际有时间
      --   NULL_LIVE_ORIGINAL_CAN_BACKFILL / NULL_HAS_TIME_CAN_BACKFILL  字段为空但有证据，可由 NULL 回填安全处理
      SET @sql_c = 'SELECT c.ers_id, c.ers_time_source, c.ers_version_verified, c.ers_snapshot_at, c.reason
                    FROM (
                      SELECT ers_id, ers_time_source, ers_version_verified, ers_snapshot_at,
                        CASE
                          WHEN ers_time_source = ''LIVE_REAL''
                           AND (ers_version_verified IS NULL OR ers_version_verified <> ''LIVE_ORIGINAL'')
                            THEN ''SUSPECT_LIVE_REAL_NO_EVIDENCE''
                          WHEN ers_time_source = ''BACKFILL_UNKNOWN'' AND ers_snapshot_at IS NOT NULL
                            THEN ''SUSPECT_UNKNOWN_BUT_HAS_TIME''
                          WHEN ers_time_source IS NULL AND ers_version_verified = ''LIVE_ORIGINAL''
                            THEN ''NULL_LIVE_ORIGINAL_CAN_BACKFILL''
                          WHEN ers_time_source IS NULL AND ers_snapshot_at IS NOT NULL
                            THEN ''NULL_HAS_TIME_CAN_BACKFILL''
                          ELSE ''OK''
                        END AS reason
                      FROM t_ent_resume_snapshot
                    ) c
                    WHERE c.reason <> ''OK'' ORDER BY c.ers_id';
      PREPARE stmt_c FROM @sql_c;
      EXECUTE stmt_c;
      DEALLOCATE PREPARE stmt_c;
    ELSE
      -- 旧版缺字段：仅返回缺失清单，不执行会报错的 B/C；无法判断时停止，先补字段再重诊
      SELECT 'LEGACY_MISSING_COLUMNS' AS env,
             CONCAT_WS(',',
               IF(v_has_ts=0,'ers_time_source',NULL),
               IF(v_has_vv=0,'ers_version_verified',NULL),
               IF(v_has_sa=0,'ers_snapshot_at',NULL)) AS missing_columns,
             '字段不全，禁止运行B/C；先执行阶段1补齐字段后重新诊断，仍无法判断则停止' AS msg;
      -- 替代诊断：只统计快照行数（不依赖任何具体业务列），确认是否已有历史数据
      SET @sql_alt = 'SELECT COUNT(*) AS snapshot_rows FROM t_ent_resume_snapshot';
      PREPARE stmt_alt FROM @sql_alt;
      EXECUTE stmt_alt;
      DEALLOCATE PREPARE stmt_alt;
    END IF;
  END IF;
END$$
DELIMITER ;
-- 手动调用（只读，确认诊断 A 后执行；返回环境标记或 B/C 结果，不修改数据）：
-- CALL p_ent_diag_upgrade();
-- 说明：创建/删除本诊断过程属于数据库对象 DDL，并非“完全零数据库变更”；但其内部不含任何业务表写入。



-- #####################################################
-- 第一部分：阶段 0 执行期守卫（仅定义；通过后手动 CALL，不自动 DROP）
-- #####################################################
DROP PROCEDURE IF EXISTS p_ent_preflight_guard;
DELIMITER $$
CREATE PROCEDURE p_ent_preflight_guard()
BEGIN
  DECLARE legacy_count INT DEFAULT 0;
  DECLARE other_uq_count INT DEFAULT 0;

  -- 0.1 分析表必须存在
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                 WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 't_ai_candidate_analysis 不存在，已停止';
  END IF;

  -- 0.2 旧三字段完整列唯一索引（非主键、3 列、SUB_PART 全 NULL 排除前缀、列序恰为 company,position,candidate）
  SELECT COUNT(*) INTO legacy_count FROM (
    SELECT index_name
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
      AND non_unique = 0 AND index_name <> 'PRIMARY'
    GROUP BY table_schema, table_name, index_name
    HAVING COUNT(*) = 3
       AND SUM(CASE WHEN SUB_PART IS NULL THEN 0 ELSE 1 END) = 0
       AND GROUP_CONCAT(column_name ORDER BY seq_in_index)
           = 'asr_company_id,asr_position_id,asr_candidate_id'
  ) legacy;

  -- 0.3 其他非主键唯一索引（含前缀唯一、列数/列序不符）
  SELECT COUNT(*) INTO other_uq_count FROM (
    SELECT index_name
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
      AND non_unique = 0 AND index_name <> 'PRIMARY'
    GROUP BY table_schema, table_name, index_name
    HAVING NOT (COUNT(*) = 3
       AND SUM(CASE WHEN SUB_PART IS NULL THEN 0 ELSE 1 END) = 0
       AND GROUP_CONCAT(column_name ORDER BY seq_in_index)
           = 'asr_company_id,asr_position_id,asr_candidate_id')
  ) other;

  IF other_uq_count > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT =
      '存在非预期唯一索引（或前缀唯一索引），已停止；请人工核对索引后再执行迁移';
  END IF;
  IF legacy_count > 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT =
      '旧三字段唯一索引多于一个，已停止；请人工核对';
  END IF;
  -- legacy_count 仅允许 0（已迁移/重跑）或 1（待删）
END$$
DELIMITER ;

-- 手动步骤 0：确认目标库无误后，单独执行下一行（选中该行运行；本助手不自动执行）：
-- CALL p_ent_preflight_guard();


-- #####################################################
-- 第二部分：阶段 1 迁移过程（仅定义；内部第一步强制再跑守卫，保证守卫未通过绝不可能建表）
-- #####################################################
DROP PROCEDURE IF EXISTS p_ensure_index;
DROP PROCEDURE IF EXISTS p_ent_schema_migrate;
DELIMITER $$

-- 普通索引完整结构校验：名称/列数/列序/是否唯一/前缀/索引类型，与 05 回滚守卫同一标准。
-- 不存在则按设计创建；同名同结构幂等跳过；同名异结构（含唯一性/前缀/类型）SIGNAL 中止。
CREATE PROCEDURE p_ensure_index(
  IN p_index_name VARCHAR(64),
  IN p_column_list VARCHAR(255),
  IN p_column_count INT)
BEGIN
  DECLARE v_exists INT DEFAULT 0;
  DECLARE v_actual_list VARCHAR(255);
  DECLARE v_actual_count INT DEFAULT 0;
  DECLARE v_non_unique INT DEFAULT 0;
  DECLARE v_prefix_cnt INT DEFAULT 0;
  DECLARE v_bad_type INT DEFAULT 0;
  DECLARE v_msg VARCHAR(255);

  SELECT COUNT(*) INTO v_exists
  FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
    AND index_name = p_index_name;

  IF v_exists = 0 THEN
    SET @sql = CONCAT('ALTER TABLE t_ai_candidate_analysis ADD KEY `',
                      p_index_name, '` (', p_column_list, ')');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  ELSE
    SELECT GROUP_CONCAT(column_name ORDER BY seq_in_index), COUNT(*),
           MAX(non_unique),
           SUM(CASE WHEN SUB_PART IS NULL THEN 0 ELSE 1 END),
           SUM(CASE WHEN index_type <> 'BTREE' THEN 1 ELSE 0 END)
      INTO v_actual_list, v_actual_count, v_non_unique, v_prefix_cnt, v_bad_type
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
      AND index_name = p_index_name;
    IF v_actual_count <> p_column_count
       OR v_actual_list <> p_column_list
       OR v_non_unique <> 1
       OR v_prefix_cnt <> 0
       OR v_bad_type <> 0 THEN
      SET v_msg = CONCAT('索引 ', p_index_name,
        ' 同名异结构（列/唯一性/前缀/类型不符），已停止；请人工核对');
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    -- 同名同结构：幂等跳过，不重复创建，也不误删其他业务索引
  END IF;
END$$


CREATE PROCEDURE p_ent_schema_migrate()
BEGIN
  DECLARE legacy_name VARCHAR(128);
  DECLARE legacy_count INT DEFAULT 0;

  -- 强制前置：迁移过程内部再跑一次守卫，外部即使漏掉手动守卫，这里也会先阻断，未通过不会执行任何 DDL。
  CALL p_ent_preflight_guard();

  -- ===== 1) 建 5 张企业快照表（IF NOT EXISTS，首次建表/旧版重跑均安全）=====
  CREATE TABLE IF NOT EXISTS t_ent_resume_snapshot (
    ers_id bigint NOT NULL AUTO_INCREMENT COMMENT '企业投递简历快照ID',
    ers_app_id bigint NOT NULL COMMENT '对应投递记录 t_app_record.app_id',
    ers_candidate_id bigint NOT NULL COMMENT '候选人ID t_tal.tal_id',
    ers_company_id bigint NOT NULL COMMENT '企业ID',
    ers_position_id bigint NOT NULL COMMENT '岗位ID',
    ers_source_resume_id bigint DEFAULT NULL COMMENT '原C-App简历rbs_id，仅来源追溯，不可作读取依赖',
    ers_resume_name varchar(100) DEFAULT NULL COMMENT '投递时简历名称',
    ers_job_direction varchar(50) DEFAULT NULL COMMENT '投递时求职方向',
    ers_file_path varchar(500) DEFAULT NULL COMMENT '企业独立PDF对象引用(企业命名空间)',
    ers_file_name varchar(255) DEFAULT NULL COMMENT '原始PDF文件名',
    ers_file_size bigint DEFAULT NULL COMMENT 'PDF文件大小(字节)',
    ers_content_hash varchar(128) DEFAULT NULL COMMENT '快照内容哈希；v1为64位hex，v2带v2:前缀共67字符，varchar(128)兼容',
    ers_snapshot_status varchar(24) NOT NULL DEFAULT 'COMPLETE'
      COMMENT 'COMPLETE完整快照 / REBUILT_UNVERIFIED现存数据重建原始版本未核实 / MISSING_SOURCE来源缺失待核实',
    ers_version_verified varchar(24) DEFAULT NULL
      COMMENT '原始投递版本核实证据：LIVE_ORIGINAL实时投递天然原件 / MANUAL_VERIFIED历史快照经人工可靠证据核实 / NULL历史重建未核实',
    ers_time_source varchar(24) NOT NULL DEFAULT 'LIVE_REAL'
      COMMENT '时间来源：LIVE_REAL实时真实时间 / BACKFILL_REAL历史回填有真实时间 / BACKFILL_UNKNOWN历史时间未知',
    ers_snapshot_at datetime DEFAULT NULL
      COMMENT '快照对应投递时刻；历史投递时间未知时为NULL，严禁用迁移时间伪造',
    ers_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录创建时间',
    PRIMARY KEY (ers_id),
    UNIQUE KEY uk_ers_app (ers_app_id),
    KEY idx_ers_company (ers_company_id),
    KEY idx_ers_candidate (ers_candidate_id),
    KEY idx_ers_position (ers_position_id),
    KEY idx_ers_status (ers_snapshot_status)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='企业投递简历快照主表';

  CREATE TABLE IF NOT EXISTS t_ent_resume_education (
    ere_id bigint NOT NULL AUTO_INCREMENT COMMENT '教育经历ID',
    ere_snapshot_id bigint NOT NULL COMMENT '关联快照主表 ers_id',
    ere_school varchar(100) NOT NULL COMMENT '学校名称',
    ere_major varchar(50) DEFAULT NULL COMMENT '专业',
    ere_degree tinyint DEFAULT NULL COMMENT '学历:1中专2大专3本科4硕士5博士',
    ere_start_date date DEFAULT NULL COMMENT '入学时间',
    ere_end_date date DEFAULT NULL COMMENT '毕业时间',
    ere_gpa decimal(3,2) DEFAULT NULL COMMENT 'GPA',
    ere_description text COMMENT '描述/课程',
    ere_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (ere_id),
    KEY idx_ere_snapshot (ere_snapshot_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='企业快照-教育经历表';

  CREATE TABLE IF NOT EXISTS t_ent_resume_work (
    erw_id bigint NOT NULL AUTO_INCREMENT COMMENT '工作经历ID',
    erw_snapshot_id bigint NOT NULL COMMENT '关联快照主表 ers_id',
    erw_company varchar(100) NOT NULL COMMENT '公司名称',
    erw_position varchar(50) NOT NULL COMMENT '职位',
    erw_department varchar(50) DEFAULT NULL COMMENT '部门',
    erw_start_date date DEFAULT NULL COMMENT '入职时间',
    erw_end_date date DEFAULT NULL COMMENT '离职时间',
    erw_is_current tinyint DEFAULT 0 COMMENT '是否在职:0否1是',
    erw_salary_range varchar(20) DEFAULT NULL COMMENT '薪资范围',
    erw_description text COMMENT '工作描述/业绩',
    erw_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (erw_id),
    KEY idx_erw_snapshot (erw_snapshot_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='企业快照-工作经历表';

  CREATE TABLE IF NOT EXISTS t_ent_resume_project (
    erp_id bigint NOT NULL AUTO_INCREMENT COMMENT '项目经历ID',
    erp_snapshot_id bigint NOT NULL COMMENT '关联快照主表 ers_id',
    erp_name varchar(100) NOT NULL COMMENT '项目名称',
    erp_role varchar(50) DEFAULT NULL COMMENT '担任角色',
    erp_start_date date DEFAULT NULL COMMENT '开始时间',
    erp_end_date date DEFAULT NULL COMMENT '结束时间',
    erp_description text COMMENT '项目描述',
    erp_tech_stack varchar(200) DEFAULT NULL COMMENT '技术栈(逗号分隔)',
    erp_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (erp_id),
    KEY idx_erp_snapshot (erp_snapshot_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='企业快照-项目经历表';

  CREATE TABLE IF NOT EXISTS t_ent_resume_skill (
    esk_id bigint NOT NULL AUTO_INCREMENT COMMENT '技能ID',
    esk_snapshot_id bigint NOT NULL COMMENT '关联快照主表 ers_id',
    esk_name varchar(50) NOT NULL COMMENT '技能名称',
    esk_level tinyint DEFAULT 2 COMMENT '熟练度:1了解2熟悉3精通4专家',
    esk_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (esk_id),
    KEY idx_esk_snapshot (esk_snapshot_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='企业快照-技能表';

  -- ===== 2) 分析表幂等加列 =====
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
                   AND column_name = 'asr_app_id') THEN
    ALTER TABLE t_ai_candidate_analysis ADD COLUMN asr_app_id bigint DEFAULT NULL COMMENT '对应投递 app_id';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
                   AND column_name = 'asr_snapshot_id') THEN
    ALTER TABLE t_ai_candidate_analysis ADD COLUMN asr_snapshot_id bigint DEFAULT NULL COMMENT '对应企业快照 ers_id';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
                   AND column_name = 'asr_content_hash') THEN
    ALTER TABLE t_ai_candidate_analysis ADD COLUMN asr_content_hash varchar(128) DEFAULT NULL COMMENT '分析时简历内容哈希；v2带前缀共67字符，varchar(128)兼容';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
                   AND column_name = 'asr_source') THEN
    ALTER TABLE t_ai_candidate_analysis ADD COLUMN asr_source varchar(10) DEFAULT NULL
      COMMENT '来源:llm/manual/unknown；历史行初始NULL，由03按asr_report识别，不默认归类llm';
  END IF;

  -- 旧版可能已用 NOT NULL DEFAULT ''llm'' 加列，IF NOT EXISTS 不修复；无条件 MODIFY 放宽为可空（幂等）。
  -- MODIFY 只改约束，不清除旧版已填入的 ''llm''；曾用错误 DDL 的库，历史 llm 须人工核对或隔离重跑，不得直接信任。
  ALTER TABLE t_ai_candidate_analysis
    MODIFY COLUMN asr_source varchar(10) DEFAULT NULL
      COMMENT '来源:llm/manual/unknown；历史行初始NULL，由03按asr_report识别，不默认归类llm';

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
                   AND column_name = 'asr_version_status') THEN
    ALTER TABLE t_ai_candidate_analysis ADD COLUMN asr_version_status varchar(24) DEFAULT NULL
      COMMENT 'MATCHED与快照匹配 / UNVERIFIED版本未核实';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
                   AND column_name = 'asr_created_at') THEN
    ALTER TABLE t_ai_candidate_analysis ADD COLUMN asr_created_at datetime DEFAULT NULL COMMENT '本条分析创建时间';
  END IF;

  -- ===== 3) 快照主表补列 =====
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 't_ent_resume_snapshot'
                   AND column_name = 'ers_version_verified') THEN
    ALTER TABLE t_ent_resume_snapshot ADD COLUMN ers_version_verified varchar(24) DEFAULT NULL
      COMMENT '原始投递版本核实证据：LIVE_ORIGINAL实时投递 / MANUAL_VERIFIED人工核实 / NULL未核实';
  END IF;

  -- ===== 4) time_source 完整升级（不再整体放在 IF NOT EXISTS 内；字段已存在也会处理 NULL）=====
  -- 4a 字段不存在：先可空加列，严禁 NOT NULL DEFAULT 直接加导致历史被静默标 LIVE_REAL
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 't_ent_resume_snapshot'
                   AND column_name = 'ers_time_source') THEN
    ALTER TABLE t_ent_resume_snapshot ADD COLUMN ers_time_source varchar(24) DEFAULT NULL
      COMMENT '时间来源：LIVE_REAL实时真实 / BACKFILL_REAL历史有真实时间 / BACKFILL_UNKNOWN历史时间未知';
  END IF;

  -- 4a-bis 旧版主表可能缺 ers_snapshot_at（DR-2）：先可空补列，默认 NULL，严禁 NOW()/CURRENT_TIMESTAMP 伪造历史时间
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 't_ent_resume_snapshot'
                   AND column_name = 'ers_snapshot_at') THEN
    ALTER TABLE t_ent_resume_snapshot ADD COLUMN ers_snapshot_at datetime DEFAULT NULL
      COMMENT '快照对应投递时刻；历史投递时间未知时为NULL，严禁用迁移时间伪造';
  END IF;

  -- 4b 对仍为 NULL 的行按证据回填（新建与旧版字段均命中）；只动 NULL，不覆盖任何已存在的非空值
  UPDATE t_ent_resume_snapshot
  SET ers_time_source = CASE
        WHEN ers_version_verified = 'LIVE_ORIGINAL' THEN 'LIVE_REAL'
        WHEN ers_snapshot_at IS NOT NULL THEN 'BACKFILL_REAL'
        ELSE 'BACKFILL_UNKNOWN'
      END
  WHERE ers_time_source IS NULL;

  -- 4c 确认无残留 NULL 后再收紧 NOT NULL（与首次建表定义对齐）；存在 NULL 则不收紧，避免误改，留待人工处理
  IF NOT EXISTS (SELECT 1 FROM t_ent_resume_snapshot WHERE ers_time_source IS NULL) THEN
    ALTER TABLE t_ent_resume_snapshot
      MODIFY COLUMN ers_time_source varchar(24) NOT NULL DEFAULT 'LIVE_REAL'
        COMMENT '时间来源：LIVE_REAL实时真实 / BACKFILL_REAL历史有真实时间 / BACKFILL_UNKNOWN历史时间未知';
  END IF;

  -- 旧主表 snapshot_at 可能 NOT NULL；统一放宽可空，使历史未知时间保留 NULL，不伪造（幂等）
  ALTER TABLE t_ent_resume_snapshot
    MODIFY COLUMN ers_snapshot_at datetime DEFAULT NULL
      COMMENT '快照对应投递时刻；历史投递时间未知时为NULL，严禁用迁移时间伪造';

  -- ===== 5) 仅删除明确的旧三字段完整列唯一索引（重新识别，兼容首次/重跑）=====
  SELECT COUNT(*) INTO legacy_count FROM (
    SELECT index_name
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
      AND non_unique = 0 AND index_name <> 'PRIMARY'
    GROUP BY table_schema, table_name, index_name
    HAVING COUNT(*) = 3
       AND SUM(CASE WHEN SUB_PART IS NULL THEN 0 ELSE 1 END) = 0
       AND GROUP_CONCAT(column_name ORDER BY seq_in_index)
           = 'asr_company_id,asr_position_id,asr_candidate_id'
  ) legacy;

  IF legacy_count = 1 THEN
    SELECT index_name INTO legacy_name
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
      AND non_unique = 0 AND index_name <> 'PRIMARY'
    GROUP BY table_schema, table_name, index_name
    HAVING COUNT(*) = 3
       AND SUM(CASE WHEN SUB_PART IS NULL THEN 0 ELSE 1 END) = 0
       AND GROUP_CONCAT(column_name ORDER BY seq_in_index)
           = 'asr_company_id,asr_position_id,asr_candidate_id'
    LIMIT 1;
    SET @ddl = CONCAT('ALTER TABLE t_ai_candidate_analysis DROP INDEX `', legacy_name, '`');
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;

  -- ===== 6) 建 4 个普通索引（完整结构校验，与 05 同标准）=====
  CALL p_ensure_index('idx_asr_app', 'asr_app_id,asr_source,asr_created_at', 3);
  CALL p_ensure_index('idx_asr_snapshot', 'asr_snapshot_id', 1);
  CALL p_ensure_index('idx_asr_company_candidate', 'asr_company_id,asr_candidate_id', 2);
  CALL p_ensure_index('idx_asr_company_position', 'asr_company_id,asr_position_id', 2);
END$$
DELIMITER ;

-- 手动步骤 1：确认阶段0守卫已成功后，单独执行下一行（本助手不自动执行）：
-- CALL p_ent_schema_migrate();


-- #####################################################
-- 第三部分：迁移结果核对（手动执行下列 SHOW，确认结构后再进入 03）
-- #####################################################
-- SHOW TABLES LIKE 't_ent_%';
-- SHOW COLUMNS FROM t_ai_candidate_analysis;
-- SHOW COLUMNS FROM t_ent_resume_snapshot;
-- SHOW INDEX FROM t_ai_candidate_analysis;

-- 手动步骤 2：确认全部结构与预期一致后，再单独执行清理（默认不执行，过程保留亦无害）：
-- DROP PROCEDURE IF EXISTS p_ent_schema_migrate;
-- DROP PROCEDURE IF EXISTS p_ensure_index;
-- DROP PROCEDURE IF EXISTS p_ent_preflight_guard;

-- =====================================================
-- 完成判定：5 张企业表存在；分析表 6 新列、asr_source 可空；time_source 无 NULL 且为 NOT NULL；
--          旧唯一索引已删、4 个普通索引结构正确。确认后执行 03_backfill.sql。
-- =====================================================
