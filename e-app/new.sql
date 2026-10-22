-- ============================================================
-- recruit_agent 数据库 - 完整迁移脚本（幂等版）
-- 整合 4 个 Codex 窗口的所有已执行变更
-- 生成时间：2026-10-16
-- 使用方式：
--   mysql -u root -p recruit_agent < DB_MIGRATION_ALL_IN_ONE.sql
-- 或：
--   USE recruit_agent;
--   source DB_MIGRATION_ALL_IN_ONE.sql;
-- ============================================================
-- 特点：
--   1. 幂等：已存在的表/列会自动跳过
--   2. 按依赖顺序：建表 → 加列 → 插数据
--   3. 单文件：可直接执行
--   4. 兼容 MySQL 5.7+ / 8.0
-- ============================================================

SET NAMES utf8mb4;
SET @target_db = DATABASE();

SELECT CONCAT('当前数据库：', @target_db) AS info;

-- ============================================================
-- 一、新建表（IF NOT EXISTS，重复执行安全）
-- ============================================================

-- ------------------------------------------------------------
-- 1.1 IM 快捷回复模板表
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS t_im_quick_reply (
  id          bigint       NOT NULL AUTO_INCREMENT COMMENT '主键',
  category    varchar(30)  NOT NULL COMMENT '分类：面试安排/进度反馈/通用话术等',
  content     varchar(500) NOT NULL COMMENT '回复内容',
  created_at  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT 'IM快捷回复模板表';

-- ------------------------------------------------------------
-- 1.2 面试场次面试官关联表
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS t_int_session_interviewer (
  isi_id          bigint   NOT NULL AUTO_INCREMENT COMMENT '主键',
  isi_session_id  bigint   NOT NULL COMMENT '面试场次ID，关联 ses_id',
  isi_user_id     bigint   NOT NULL COMMENT '面试官用户ID，关联 sys_user.user_id',
  isi_is_primary  tinyint  NOT NULL DEFAULT 0 COMMENT '是否主面试官：0-否，1-是',
  isi_join_status tinyint  NOT NULL DEFAULT 0 COMMENT '加入状态：0-未加入，1-已加入',
  isi_joined_at   datetime NULL COMMENT '加入会议时间',
  isi_muted_av    tinyint  NOT NULL DEFAULT 0 COMMENT '加入时是否静音音视频：0-否，1-是',
  isi_created_at  datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  isi_updated_at  datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
                  ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (isi_id),
  UNIQUE KEY uk_isi_session_user (isi_session_id, isi_user_id),
  KEY idx_isi_user (isi_user_id),
  CONSTRAINT fk_isi_session_id
    FOREIGN KEY (isi_session_id) REFERENCES t_int_session (ses_id) ON DELETE CASCADE,
  CONSTRAINT fk_isi_user_id
    FOREIGN KEY (isi_user_id) REFERENCES sys_user (user_id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT '面试场次面试官关联表';

-- ------------------------------------------------------------
-- 1.3 面试会议运行时状态表
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS t_int_meeting_state (
  mst_session_id          bigint NOT NULL COMMENT '面试场次ID，关联 ses_id（一场一条）',
  mst_total_question      int NOT NULL DEFAULT 0 COMMENT '本轮题目总数',
  mst_current_question    int NOT NULL DEFAULT 0 COMMENT '已完成题目数',
  mst_duration_seconds    int NULL COMMENT '本场面试时长（秒）',
  mst_remaining_seconds   int NULL COMMENT '剩余秒数',
  mst_mic_enabled         tinyint NOT NULL DEFAULT 0 COMMENT '麦克风开关：0-关，1-开',
  mst_cam_enabled         tinyint NOT NULL DEFAULT 0 COMMENT '摄像头开关：0-关，1-开',
  mst_speaker_volume      tinyint NOT NULL DEFAULT 80 COMMENT '扬声器音量（0-100）',
  mst_device_json         json NULL COMMENT '所选设备ID等扩展信息',
  mst_cam_status          tinyint NOT NULL DEFAULT 0 COMMENT '摄像头检测：0-未检测，1-正常，2-警告，3-异常',
  mst_mic_status          tinyint NOT NULL DEFAULT 0 COMMENT '麦克风检测：同上',
  mst_speaker_status      tinyint NOT NULL DEFAULT 0 COMMENT '扬声器检测：同上',
  mst_net_status          tinyint NOT NULL DEFAULT 0 COMMENT '网络检测：同上',
  mst_net_rtt_ms          int NULL COMMENT '网络往返时延（毫秒）',
  mst_net_bandwidth_kbps  int NULL COMMENT '网络带宽（Kbps）',
  mst_risk_flag           tinyint NOT NULL DEFAULT 0 COMMENT '弱网风险标记：0-无，1-已忽略风险进入',
  mst_takeover            tinyint NOT NULL DEFAULT 0 COMMENT 'HR接管状态：0-未接管，1-接管中',
  mst_takeover_reason     varchar(255) NULL COMMENT '接管原因',
  mst_heartbeat_at        datetime NULL COMMENT '最后心跳时间',
  mst_created_at          datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  mst_updated_at          datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (mst_session_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT '面试会议运行时状态表';

-- ------------------------------------------------------------
-- 1.4 面试实时提词器建议表
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS t_int_copilot (
  cpt_id              bigint NOT NULL AUTO_INCREMENT COMMENT '建议ID',
  cpt_session_id      bigint NOT NULL COMMENT '关联场次ID',
  cpt_seq             int NOT NULL COMMENT '场次内序号，用于增量拉取',
  cpt_mode            tinyint NOT NULL DEFAULT 1 COMMENT '类型：1-建议问题，2-参考答案，3-评分要点',
  cpt_content         varchar(1000) NOT NULL COMMENT '建议问题 / 要点正文',
  cpt_reference       text NULL COMMENT '参考答案',
  cpt_points          json NULL COMMENT '评分要点数组',
  cpt_status          tinyint NOT NULL DEFAULT 0 COMMENT '状态：0-待处理，1-已采纳，2-已编辑，3-已忽略',
  cpt_adopted_content varchar(1000) NULL COMMENT '编辑后实际采用的内容',
  cpt_created_at      datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  cpt_updated_at      datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (cpt_id),
  UNIQUE KEY uk_cpt_session_seq (cpt_session_id, cpt_seq),
  KEY idx_cpt_session_status (cpt_session_id, cpt_status)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT '面试实时提词器建议表';

-- ------------------------------------------------------------
-- 1.5 面试录制存储策略表
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS t_int_recording_policy (
  rcp_id                   bigint NOT NULL AUTO_INCREMENT COMMENT '策略ID',
  rcp_company_id           bigint NULL COMMENT '归属企业ID，NULL=全局默认',
  rcp_keep_days            int NOT NULL DEFAULT 90 COMMENT '录制保留天数',
  rcp_max_storage_gb       int NOT NULL DEFAULT 500 COMMENT '总存储上限（GB）',
  rcp_default_access_level tinyint NOT NULL DEFAULT 1 COMMENT '默认访问级别',
  rcp_created_at           datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  rcp_updated_at           datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (rcp_id),
  UNIQUE KEY uk_rcp_company_id (rcp_company_id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT '面试录制存储策略表';

-- ============================================================
-- 二、给已有表加列（用存储过程做存在性检查）
-- ============================================================

DROP PROCEDURE IF EXISTS __add_column_if_not_exists;

DELIMITER $$
CREATE PROCEDURE __add_column_if_not_exists(
  IN p_table  VARCHAR(64),
  IN p_column VARCHAR(64),
  IN p_definition TEXT
)
BEGIN
  DECLARE col_count INT DEFAULT 0;
  SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME   = p_table
     AND COLUMN_NAME  = p_column;
  IF col_count = 0 THEN
    SET @ddl = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN ', p_definition);
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SELECT CONCAT('[ADDED] ', p_table, '.', p_column) AS result;
  ELSE
    SELECT CONCAT('[SKIP ] ', p_table, '.', p_column, ' already exists') AS result;
  END IF;
END$$
DELIMITER ;

-- ------------------------------------------------------------
-- 2.1 消息模板加公司归属列
-- ------------------------------------------------------------
CALL __add_column_if_not_exists(
  't_msg_template',
  'tpl_company_id',
  '`tpl_company_id` bigint NOT NULL DEFAULT 0 COMMENT ''所属公司ID，0为平台全局模板'' AFTER `tpl_code`'
);

-- ------------------------------------------------------------
-- 2.2 面试场次加录制文件大小列
-- ------------------------------------------------------------
CALL __add_column_if_not_exists(
  't_int_session',
  'ses_rec_size_bytes',
  '`ses_rec_size_bytes` bigint NULL DEFAULT NULL COMMENT ''录制文件字节数'' AFTER `ses_rec_duration_sec`'
);

-- ------------------------------------------------------------
-- 2.3 面试官关联表加邀约接受状态
-- ------------------------------------------------------------
CALL __add_column_if_not_exists(
  't_int_session_interviewer',
  'isi_accept_status',
  '`isi_accept_status` tinyint NOT NULL DEFAULT 0 COMMENT ''面试邀约接受状态：0-待确认，1-已接受，2-已拒绝'''
);

-- ------------------------------------------------------------
-- 2.4 简历基础表加 3 列
-- ------------------------------------------------------------
CALL __add_column_if_not_exists(
  't_res_base',
  'rbs_file_path',
  '`rbs_file_path` varchar(500) NULL COMMENT ''pdf resume reference'''
);

CALL __add_column_if_not_exists(
  't_res_base',
  'rbs_file_name',
  '`rbs_file_name` varchar(255) NULL COMMENT ''pdf original file name'''
);

CALL __add_column_if_not_exists(
  't_res_base',
  'rbs_file_size',
  '`rbs_file_size` bigint NULL COMMENT ''pdf file size bytes'''
);

-- 清理临时存储过程
DROP PROCEDURE IF EXISTS __add_column_if_not_exists;

-- ============================================================
-- 三、修改列注释（用存储过程做幂等检查）
-- ============================================================

DROP PROCEDURE IF EXISTS __modify_column_comment;

DELIMITER $$
CREATE PROCEDURE __modify_column_comment(
  IN p_table   VARCHAR(64),
  IN p_column  VARCHAR(64),
  IN p_comment VARCHAR(255)
)
BEGIN
  DECLARE current_comment VARCHAR(255);
  SELECT COLUMN_COMMENT INTO current_comment
    FROM information_schema.columns
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME   = p_table
     AND COLUMN_NAME  = p_column
   LIMIT 1;
  IF current_comment IS NULL OR current_comment <> p_comment THEN
    SET @ddl = CONCAT('ALTER TABLE `', p_table, '` MODIFY COLUMN `', p_column,
                      '` tinyint NOT NULL COMMENT ''', p_comment, '''');
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SELECT CONCAT('[UPDATED] ', p_table, '.', p_column, ' comment') AS result;
  ELSE
    SELECT CONCAT('[SKIP   ] ', p_table, '.', p_column, ' comment unchanged') AS result;
  END IF;
END$$
DELIMITER ;

CALL __modify_column_comment(
  't_int_session',
  'ses_mode',
  '实际面试模式：1-纯AI，2-AI+单面试官，3-AI+多面试官，4-无AI纯人工'
);

DROP PROCEDURE IF EXISTS __modify_column_comment;

-- ============================================================
-- 四、数据变更（幂等写法）
-- ============================================================

-- ------------------------------------------------------------
-- 4.1 消息模板公司归属（仅对 tpl_company_id=0 的记录更新）
-- ------------------------------------------------------------
UPDATE t_msg_template
   SET tpl_company_id = 1
 WHERE tpl_id IN (1, 2, 5, 6, 7, 9, 11)
   AND tpl_company_id = 0;

UPDATE t_msg_template
   SET tpl_company_id = 2
 WHERE tpl_id IN (3, 4, 8, 10)
   AND tpl_company_id = 0;

-- ------------------------------------------------------------
-- 4.2 IM 快捷回复种子数据（仅在表为空时插入）
-- ------------------------------------------------------------
INSERT INTO t_im_quick_reply (category, content)
SELECT * FROM (
  SELECT '面试安排' AS category,
         '您好，您的 AI 结构化预面已安排于明天 14:00，请提前 15 分钟进入会议。' AS content
  UNION ALL SELECT '面试安排', '您好，面试时间如需调整，您看本周五 10:30 是否方便？'
  UNION ALL SELECT '进度反馈', '您已通过初筛，HR 将在 1 个工作日内联系您确认下一步安排。'
  UNION ALL SELECT '进度反馈', '您的当前阶段评估已完成，后续安排请留意系统通知。'
  UNION ALL SELECT '通用话术', '您好，请问现在方便进行简短电话沟通吗？'
) AS seed
WHERE NOT EXISTS (SELECT 1 FROM t_im_quick_reply);

-- ------------------------------------------------------------
-- 4.3 全局录制策略（仅在不存在全局策略时插入）
-- ------------------------------------------------------------
INSERT INTO t_int_recording_policy (
  rcp_company_id, rcp_keep_days, rcp_max_storage_gb, rcp_default_access_level
)
SELECT NULL, 90, 500, 1
WHERE NOT EXISTS (
  SELECT 1 FROM t_int_recording_policy WHERE rcp_company_id IS NULL
);

-- ------------------------------------------------------------
-- 4.4 恢复岗位 6 状态（仅当下线时恢复到在招）
-- ------------------------------------------------------------
UPDATE t_pos
   SET pos_status = 1
 WHERE pos_id = 6
   AND pos_title = '初级Java开发工程师'
   AND pos_status = 0;

-- ============================================================
-- 五、备份表（可选，仅用于历史对比）
-- ============================================================
-- 注意：备份表使用 CREATE TABLE AS SELECT，重复执行会报错
-- 如果需要备份，取消注释下面的语句

-- -- 5.1 备份消息模板
-- CREATE TABLE IF NOT EXISTS t_msg_template_bak_20261014
--   AS SELECT * FROM t_msg_template;

-- -- 5.2 备份面试场次
-- CREATE TABLE IF NOT EXISTS t_int_session_bak_20261015
--   AS SELECT * FROM t_int_session;

-- ============================================================
-- 六、验证脚本（只读，检查变更是否生效）
-- ============================================================

SELECT '===== 结构验证 =====' AS section;

SELECT
  table_name,
  CASE WHEN COUNT(*) > 0 THEN '✅ 存在' ELSE '❌ 不存在' END AS status
FROM information_schema.tables
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    't_im_quick_reply',
    't_int_session_interviewer',
    't_int_meeting_state',
    't_int_copilot',
    't_int_recording_policy'
  )
GROUP BY table_name;

SELECT '===== 新增列验证 =====' AS section;

SELECT
  CONCAT(table_name, '.', column_name) AS column_full_name,
  column_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE TABLE_SCHEMA = DATABASE()
  AND (
    (table_name = 't_msg_template' AND column_name = 'tpl_company_id')
    OR (table_name = 't_int_session' AND column_name = 'ses_rec_size_bytes')
    OR (table_name = 't_int_session_interviewer' AND column_name = 'isi_accept_status')
    OR (table_name = 't_res_base' AND column_name IN ('rbs_file_path', 'rbs_file_name', 'rbs_file_size'))
  )
ORDER BY table_name, ordinal_position;

SELECT '===== 数据验证 =====' AS section;

SELECT '1. 消息模板归属分布' AS check_item,
       tpl_company_id,
       COUNT(*) AS cnt
FROM t_msg_template
GROUP BY tpl_company_id;

SELECT '2. IM 快捷回复数量' AS check_item,
       COUNT(*) AS total,
       COUNT(DISTINCT category) AS categories
FROM t_im_quick_reply;

SELECT '3. 全局录制策略' AS check_item,
       rcp_company_id,
       rcp_keep_days,
       rcp_max_storage_gb,
       rcp_default_access_level
FROM t_int_recording_policy
WHERE rcp_company_id IS NULL;

SELECT '4. 岗位 6 状态' AS check_item,
       pos_id, pos_title, pos_status
FROM t_pos
WHERE pos_id = 6;

SELECT '===== 变更完成 =====' AS section;

-- ============================================================
-- [追加] 2026-10-17：开启密码登录图形验证码
-- 来源：企业端登录页完善图形验证码，用户批准开启本地验证码配置
-- ============================================================
-- 配置为系统级开关，共用该配置的登录端会同时受到影响。
-- 本次沿用现有验证码接口与校验流程，不修改后端代码或表结构。
UPDATE sys_config
   SET config_value = 'true',
       update_time = NOW()
 WHERE config_key = 'sys.account.captchaEnabled'
   AND (config_value IS NULL OR config_value <> 'true');

-- 首次部署缺少该配置时补齐；重复执行不新增重复记录。
INSERT INTO sys_config (
    config_name, config_key, config_value, config_type,
    create_by, create_time, remark
)
SELECT '账号自助-验证码开关', 'sys.account.captchaEnabled', 'true', 'Y',
       'admin', NOW(), '密码登录图形验证码开关（true开启，false关闭）'
 WHERE NOT EXISTS (
    SELECT 1 FROM sys_config
     WHERE config_key = 'sys.account.captchaEnabled'
 );

-- 若通过 SQL 手动执行，需在参数设置中刷新缓存或重启后端使其生效。
-- 本地本次通过现有参数设置接口更新，数据库与配置缓存同步生效。
SELECT config_key, config_value
  FROM sys_config
 WHERE config_key = 'sys.account.captchaEnabled';

-- 回滚至本次修改前的关闭状态（按需单独执行，不随本脚本执行）：
-- UPDATE sys_config SET config_value = 'false', update_time = NOW()
--  WHERE config_key = 'sys.account.captchaEnabled';
-- 回滚后同样需要刷新参数缓存或重启后端。


-- ============================================================
-- [追加] 2026-10-17：预约记录关联招聘流程阶段及排期快照
-- 来源：企业端邀请面试支持多阶段排期、周日历、冲突检测和拖动改期
-- ============================================================
-- 只新增可空字段，旧预约兼容；不猜测历史预约的招聘阶段。
-- 快照保留名称、方式、顺序，避免岗位重配流程后历史预约信息丢失。
SET @schedule_ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 't_sch_appointment' AND column_name = 'apt_stage_id'), 'SELECT 1', 'ALTER TABLE t_sch_appointment ADD COLUMN apt_stage_id bigint DEFAULT NULL COMMENT ''关联招聘流程阶段ID''');
PREPARE schedule_stmt FROM @schedule_ddl;
EXECUTE schedule_stmt;
DEALLOCATE PREPARE schedule_stmt;

SET @schedule_ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 't_sch_appointment' AND column_name = 'apt_stage_name'), 'SELECT 1', 'ALTER TABLE t_sch_appointment ADD COLUMN apt_stage_name varchar(100) DEFAULT NULL COMMENT ''邀约时阶段名称快照''');
PREPARE schedule_stmt FROM @schedule_ddl;
EXECUTE schedule_stmt;
DEALLOCATE PREPARE schedule_stmt;

SET @schedule_ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 't_sch_appointment' AND column_name = 'apt_stage_type'), 'SELECT 1', 'ALTER TABLE t_sch_appointment ADD COLUMN apt_stage_type tinyint DEFAULT NULL COMMENT ''邀约时面试方式快照''');
PREPARE schedule_stmt FROM @schedule_ddl;
EXECUTE schedule_stmt;
DEALLOCATE PREPARE schedule_stmt;

SET @schedule_ddl = IF(EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 't_sch_appointment' AND column_name = 'apt_stage_order'), 'SELECT 1', 'ALTER TABLE t_sch_appointment ADD COLUMN apt_stage_order int DEFAULT NULL COMMENT ''邀约时阶段顺序快照''');
PREPARE schedule_stmt FROM @schedule_ddl;
EXECUTE schedule_stmt;
DEALLOCATE PREPARE schedule_stmt;

SET @schedule_ddl = IF(EXISTS(SELECT 1 FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 't_sch_appointment' AND index_name = 'idx_apt_stage_id'), 'SELECT 1', 'ALTER TABLE t_sch_appointment ADD KEY idx_apt_stage_id (apt_stage_id)');
PREPARE schedule_stmt FROM @schedule_ddl;
EXECUTE schedule_stmt;
DEALLOCATE PREPARE schedule_stmt;

SET @schedule_ddl = IF(EXISTS(SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema = DATABASE() AND table_name = 't_sch_appointment' AND constraint_name = 'fk_apt_stage_id'), 'SELECT 1', 'ALTER TABLE t_sch_appointment ADD CONSTRAINT fk_apt_stage_id FOREIGN KEY (apt_stage_id) REFERENCES t_process_stage (psg_id) ON DELETE SET NULL');
PREPARE schedule_stmt FROM @schedule_ddl;
EXECUTE schedule_stmt;
DEALLOCATE PREPARE schedule_stmt;

-- 验证：应返回四个可空字段。
SELECT column_name, column_type, is_nullable FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 't_sch_appointment'
   AND column_name IN ('apt_stage_id', 'apt_stage_name', 'apt_stage_type', 'apt_stage_order');

-- 回滚：先回滚本次后端和 APP，并导出阶段关联信息，再单独执行以下语句。
-- ALTER TABLE t_sch_appointment DROP FOREIGN KEY fk_apt_stage_id;
-- ALTER TABLE t_sch_appointment DROP INDEX idx_apt_stage_id;
-- ALTER TABLE t_sch_appointment DROP COLUMN apt_stage_id, DROP COLUMN apt_stage_name,
--     DROP COLUMN apt_stage_type, DROP COLUMN apt_stage_order;


-- ============================================================
-- [追加] 2026-10-18：企业消息中心表结构核查与既有表复用
-- 来源：企业 APP 消息中心接入真实会话、系统通知及已读能力
-- ============================================================
-- 已核查本地 information_schema：t_im_session、t_im_message、
-- t_im_quick_reply、t_msg 均已存在，所需字段和查询索引齐全。
-- 会话复用双方用户、摘要、最近消息时间和双方未读数；
-- 消息复用发送人、类型、内容、附件、撤回与发送时间；
-- 系统通知复用 msg_receiver_id、msg_title、msg_content、msg_type、
-- msg_is_read、msg_read_at、msg_target_url、msg_created_at。
-- 本次无新增/修改数据库结构或业务数据，不创建重复消息表、不插入演示消息。
-- 无需迁移或数据库回滚，仅部署消息模块接口与 APP 即可。


-- ============================================================
-- [追加] 2026-10-18：消息中心本地演示数据（默认关闭，手动启用）
-- 来源：用户要求在数据库插入消息示例验收企业端消息中心效果
-- ============================================================
-- 仅限本地验收，不发送推送、短信或邮件；不创建真实候选人或招聘流程。
-- 演示联系人禁用登录、无密码及角色，昵称和消息均注明“演示数据”。
-- 幂等追加：重复执行不新增重复示例，也不重置已经读过的消息。
-- 使用方式：在同一数据库会话先单独执行：
-- SET @eapp_message_demo_enabled = 1;
-- SET @eapp_message_demo_account = 'admin';
-- 然后只执行本追加段，不要重新执行整个历史文件。
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET @eapp_message_demo_enabled = COALESCE(@eapp_message_demo_enabled, 0);
SET @eapp_message_demo_account = CONVERT(COALESCE(@eapp_message_demo_account, 'admin') USING utf8mb4) COLLATE utf8mb4_unicode_ci;
SET @eapp_message_demo_owner = (
    SELECT user_id FROM sys_user
     WHERE user_name = @eapp_message_demo_account AND status = '0' AND del_flag = '0'
     LIMIT 1
);
SET @eapp_message_demo_marker = 'eapp_message_demo_20261018';

START TRANSACTION;

INSERT INTO sys_user (user_name, nick_name, status, del_flag, password, create_by, create_time, remark)
SELECT 'eapp_msg_demo_alpha', '演示数据 · 候选人甲', '1', '0', '', @eapp_message_demo_marker, NOW(),
       '消息中心本地演示数据；虚拟联系人，禁止登录；无真实联系方式'
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_message_demo_owner IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name = 'eapp_msg_demo_alpha');
SET @eapp_demo_alpha_user = (
    SELECT user_id FROM sys_user WHERE user_name = 'eapp_msg_demo_alpha'
      AND create_by = @eapp_message_demo_marker AND status = '1' AND del_flag = '0' LIMIT 1
);
INSERT INTO t_im_session (ims_user_a_id, ims_user_b_id, ims_last_message, ims_last_message_at,
                         ims_unread_a, ims_unread_b, ims_created_at, ims_updated_at)
SELECT @eapp_message_demo_owner, @eapp_demo_alpha_user, '', DATE_SUB(NOW(), INTERVAL 12 MINUTE),
       2, 0, NOW(), NOW()
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_message_demo_owner IS NOT NULL AND @eapp_demo_alpha_user IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_im_session WHERE
       (ims_user_a_id = @eapp_message_demo_owner AND ims_user_b_id = @eapp_demo_alpha_user)
       OR (ims_user_b_id = @eapp_message_demo_owner AND ims_user_a_id = @eapp_demo_alpha_user));
SET @eapp_demo_alpha_session = (
    SELECT ims_id FROM t_im_session
     WHERE ims_user_a_id = @eapp_message_demo_owner AND ims_user_b_id = @eapp_demo_alpha_user LIMIT 1
);

INSERT INTO sys_user (user_name, nick_name, status, del_flag, password, create_by, create_time, remark)
SELECT 'eapp_msg_demo_beta', '演示数据 · 候选人乙', '1', '0', '', @eapp_message_demo_marker, NOW(),
       '消息中心本地演示数据；虚拟联系人，禁止登录；无真实联系方式'
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_message_demo_owner IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name = 'eapp_msg_demo_beta');
SET @eapp_demo_beta_user = (
    SELECT user_id FROM sys_user WHERE user_name = 'eapp_msg_demo_beta'
      AND create_by = @eapp_message_demo_marker AND status = '1' AND del_flag = '0' LIMIT 1
);
INSERT INTO t_im_session (ims_user_a_id, ims_user_b_id, ims_last_message, ims_last_message_at,
                         ims_unread_a, ims_unread_b, ims_created_at, ims_updated_at)
SELECT @eapp_message_demo_owner, @eapp_demo_beta_user, '', DATE_SUB(NOW(), INTERVAL 70 MINUTE),
       1, 0, NOW(), NOW()
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_message_demo_owner IS NOT NULL AND @eapp_demo_beta_user IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_im_session WHERE
       (ims_user_a_id = @eapp_message_demo_owner AND ims_user_b_id = @eapp_demo_beta_user)
       OR (ims_user_b_id = @eapp_message_demo_owner AND ims_user_a_id = @eapp_demo_beta_user));
SET @eapp_demo_beta_session = (
    SELECT ims_id FROM t_im_session
     WHERE ims_user_a_id = @eapp_message_demo_owner AND ims_user_b_id = @eapp_demo_beta_user LIMIT 1
);

INSERT INTO sys_user (user_name, nick_name, status, del_flag, password, create_by, create_time, remark)
SELECT 'eapp_msg_demo_gamma', '演示数据 · 候选人丙', '1', '0', '', @eapp_message_demo_marker, NOW(),
       '消息中心本地演示数据；虚拟联系人，禁止登录；无真实联系方式'
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_message_demo_owner IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys_user WHERE user_name = 'eapp_msg_demo_gamma');
SET @eapp_demo_gamma_user = (
    SELECT user_id FROM sys_user WHERE user_name = 'eapp_msg_demo_gamma'
      AND create_by = @eapp_message_demo_marker AND status = '1' AND del_flag = '0' LIMIT 1
);
INSERT INTO t_im_session (ims_user_a_id, ims_user_b_id, ims_last_message, ims_last_message_at,
                         ims_unread_a, ims_unread_b, ims_created_at, ims_updated_at)
SELECT @eapp_message_demo_owner, @eapp_demo_gamma_user, '', DATE_SUB(NOW(), INTERVAL 1440 MINUTE),
       0, 0, NOW(), NOW()
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_message_demo_owner IS NOT NULL AND @eapp_demo_gamma_user IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_im_session WHERE
       (ims_user_a_id = @eapp_message_demo_owner AND ims_user_b_id = @eapp_demo_gamma_user)
       OR (ims_user_b_id = @eapp_message_demo_owner AND ims_user_a_id = @eapp_demo_gamma_user));
SET @eapp_demo_gamma_session = (
    SELECT ims_id FROM t_im_session
     WHERE ims_user_a_id = @eapp_message_demo_owner AND ims_user_b_id = @eapp_demo_gamma_user LIMIT 1
);

INSERT INTO t_im_message (imsg_session_id, imsg_sender_id, imsg_type, imsg_content, imsg_is_recalled, imsg_created_at)
SELECT @eapp_demo_alpha_session, @eapp_message_demo_owner, 1, '【演示数据】您好，欢迎了解移动端研发岗位，方便沟通您的技术经验吗？', 0, DATE_SUB(NOW(), INTERVAL 30 MINUTE)
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_demo_alpha_session IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_im_message WHERE imsg_session_id = @eapp_demo_alpha_session
       AND imsg_sender_id = @eapp_message_demo_owner AND imsg_content = '【演示数据】您好，欢迎了解移动端研发岗位，方便沟通您的技术经验吗？');

INSERT INTO t_im_message (imsg_session_id, imsg_sender_id, imsg_type, imsg_content, imsg_is_recalled, imsg_created_at)
SELECT @eapp_demo_alpha_session, @eapp_demo_alpha_user, 1, '【演示数据】您好，我有 Flutter 与 Java 项目经验，期待进一步沟通。', 0, DATE_SUB(NOW(), INTERVAL 20 MINUTE)
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_demo_alpha_session IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_im_message WHERE imsg_session_id = @eapp_demo_alpha_session
       AND imsg_sender_id = @eapp_demo_alpha_user AND imsg_content = '【演示数据】您好，我有 Flutter 与 Java 项目经验，期待进一步沟通。');

INSERT INTO t_im_message (imsg_session_id, imsg_sender_id, imsg_type, imsg_content, imsg_is_recalled, imsg_created_at)
SELECT @eapp_demo_alpha_session, @eapp_demo_alpha_user, 1, '【演示数据】已收到面试安排，我会按时参加，谢谢！', 0, DATE_SUB(NOW(), INTERVAL 12 MINUTE)
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_demo_alpha_session IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_im_message WHERE imsg_session_id = @eapp_demo_alpha_session
       AND imsg_sender_id = @eapp_demo_alpha_user AND imsg_content = '【演示数据】已收到面试安排，我会按时参加，谢谢！');

UPDATE t_im_session
   SET ims_last_message = '【演示数据】已收到面试安排，我会按时参加，谢谢！',
       ims_last_message_at = (SELECT MAX(imsg_created_at) FROM t_im_message WHERE imsg_session_id = @eapp_demo_alpha_session)
 WHERE @eapp_message_demo_enabled = 1 AND ims_id = @eapp_demo_alpha_session AND COALESCE(ims_last_message, '') = '';

INSERT INTO t_im_message (imsg_session_id, imsg_sender_id, imsg_type, imsg_content, imsg_is_recalled, imsg_created_at)
SELECT @eapp_demo_beta_session, @eapp_message_demo_owner, 1, '【演示数据】您的资料已收到，方便补充近期项目中负责的工作吗？', 0, DATE_SUB(NOW(), INTERVAL 90 MINUTE)
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_demo_beta_session IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_im_message WHERE imsg_session_id = @eapp_demo_beta_session
       AND imsg_sender_id = @eapp_message_demo_owner AND imsg_content = '【演示数据】您的资料已收到，方便补充近期项目中负责的工作吗？');

INSERT INTO t_im_message (imsg_session_id, imsg_sender_id, imsg_type, imsg_content, imsg_is_recalled, imsg_created_at)
SELECT @eapp_demo_beta_session, @eapp_demo_beta_user, 1, '【演示数据】可以，我主要负责接口设计和性能优化，稍后补充项目说明。', 0, DATE_SUB(NOW(), INTERVAL 70 MINUTE)
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_demo_beta_session IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_im_message WHERE imsg_session_id = @eapp_demo_beta_session
       AND imsg_sender_id = @eapp_demo_beta_user AND imsg_content = '【演示数据】可以，我主要负责接口设计和性能优化，稍后补充项目说明。');

UPDATE t_im_session
   SET ims_last_message = '【演示数据】可以，我主要负责接口设计和性能优化，稍后补充项目说明。',
       ims_last_message_at = (SELECT MAX(imsg_created_at) FROM t_im_message WHERE imsg_session_id = @eapp_demo_beta_session)
 WHERE @eapp_message_demo_enabled = 1 AND ims_id = @eapp_demo_beta_session AND COALESCE(ims_last_message, '') = '';

INSERT INTO t_im_message (imsg_session_id, imsg_sender_id, imsg_type, imsg_content, imsg_is_recalled, imsg_created_at)
SELECT @eapp_demo_gamma_session, @eapp_message_demo_owner, 1, '【演示数据】感谢沟通，后续进展会在消息中心告知。', 0, DATE_SUB(NOW(), INTERVAL 1500 MINUTE)
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_demo_gamma_session IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_im_message WHERE imsg_session_id = @eapp_demo_gamma_session
       AND imsg_sender_id = @eapp_message_demo_owner AND imsg_content = '【演示数据】感谢沟通，后续进展会在消息中心告知。');

INSERT INTO t_im_message (imsg_session_id, imsg_sender_id, imsg_type, imsg_content, imsg_is_recalled, imsg_created_at)
SELECT @eapp_demo_gamma_session, @eapp_demo_gamma_user, 1, '【演示数据】好的，感谢您的回复，期待后续消息。', 0, DATE_SUB(NOW(), INTERVAL 1440 MINUTE)
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_demo_gamma_session IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_im_message WHERE imsg_session_id = @eapp_demo_gamma_session
       AND imsg_sender_id = @eapp_demo_gamma_user AND imsg_content = '【演示数据】好的，感谢您的回复，期待后续消息。');

UPDATE t_im_session
   SET ims_last_message = '【演示数据】好的，感谢您的回复，期待后续消息。',
       ims_last_message_at = (SELECT MAX(imsg_created_at) FROM t_im_message WHERE imsg_session_id = @eapp_demo_gamma_session)
 WHERE @eapp_message_demo_enabled = 1 AND ims_id = @eapp_demo_gamma_session AND COALESCE(ims_last_message, '') = '';

INSERT INTO t_msg (msg_receiver_id, msg_sender_id, msg_type, msg_title, msg_content,
                   msg_is_read, msg_read_at, msg_target_url, msg_created_at)
SELECT @eapp_message_demo_owner, 0, 2, '【演示数据】面试日程提醒', '【演示数据】明天有一场待准备的面试，请提前查看岗位流程与候选人资料。本通知仅用于界面验收，不创建真实面试。', 0,
       NULL, NULL, DATE_SUB(NOW(), INTERVAL 5 MINUTE)
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_message_demo_owner IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_msg WHERE msg_receiver_id = @eapp_message_demo_owner
       AND msg_title = '【演示数据】面试日程提醒' AND msg_content = '【演示数据】明天有一场待准备的面试，请提前查看岗位流程与候选人资料。本通知仅用于界面验收，不创建真实面试。');

INSERT INTO t_msg (msg_receiver_id, msg_sender_id, msg_type, msg_title, msg_content,
                   msg_is_read, msg_read_at, msg_target_url, msg_created_at)
SELECT @eapp_message_demo_owner, 0, 1, '【演示数据】新的岗位投递', '【演示数据】一份示例简历已准备就绪，可在消息中心查看通知样式。本通知不代表真实投递。', 0,
       NULL, NULL, DATE_SUB(NOW(), INTERVAL 35 MINUTE)
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_message_demo_owner IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_msg WHERE msg_receiver_id = @eapp_message_demo_owner
       AND msg_title = '【演示数据】新的岗位投递' AND msg_content = '【演示数据】一份示例简历已准备就绪，可在消息中心查看通知样式。本通知不代表真实投递。');

INSERT INTO t_msg (msg_receiver_id, msg_sender_id, msg_type, msg_title, msg_content,
                   msg_is_read, msg_read_at, msg_target_url, msg_created_at)
SELECT @eapp_message_demo_owner, 0, 1, '【演示数据】消息中心已就绪', '【演示数据】这里可以查看会话、系统通知和未读角标。支持下拉刷新和全部已读。', 1,
       NOW(), NULL, DATE_SUB(NOW(), INTERVAL 1450 MINUTE)
 WHERE @eapp_message_demo_enabled = 1 AND @eapp_message_demo_owner IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM t_msg WHERE msg_receiver_id = @eapp_message_demo_owner
       AND msg_title = '【演示数据】消息中心已就绪' AND msg_content = '【演示数据】这里可以查看会话、系统通知和未读角标。支持下拉刷新和全部已读。');

COMMIT;

-- 验证只显示演示记录ID和数量，不输出其他用户消息：
SELECT ims_id AS demo_session_id, ims_unread_a AS unread_count FROM t_im_session
 WHERE @eapp_message_demo_enabled = 1 AND ims_user_a_id = @eapp_message_demo_owner
   AND ims_user_b_id IN (@eapp_demo_alpha_user, @eapp_demo_beta_user, @eapp_demo_gamma_user);
SELECT msg_id AS demo_notification_id, msg_is_read AS is_read FROM t_msg
 WHERE @eapp_message_demo_enabled = 1 AND msg_receiver_id = @eapp_message_demo_owner
   AND msg_title IN ('【演示数据】面试日程提醒', '【演示数据】新的岗位投递', '【演示数据】消息中心已就绪');

-- 防止后续误执行本段：
SET @eapp_message_demo_enabled = 0;

-- 清理说明：只清理上述演示账号和带【演示数据】前缀的消息，不删除其他资料。
-- 1. 以 sys_user.create_by='eapp_message_demo_20261018' 且 user_name 为
--    eapp_msg_demo_alpha / beta / gamma 找到演示用户与对应当前验收账号的会话。
-- 2. 删除这些会话中 imsg_content LIKE '【演示数据】%' 的消息；
--    删除验收账号上述三个 msg_title 且 msg_content LIKE '【演示数据】%' 的通知。
-- 3. 仅当演示会话已无任何消息时删除会话；仅当联系人没有任何会话引用时删除禁用演示联系人。
-- 若验收过程中发送了自己的新消息，保留这些会话及联系人，避免级联删除用户新输入。

-- 本地本次验收记录（仅标识，不含凭据）：
-- 会话ID：5、6、7；演示联系人ID：200、201、202；系统通知ID：17、18、19。
-- 上述ID仅供本机清理核对；其他环境以演示用户名和create_by标记查询，不硬编码ID删除。


-- ============================================================
-- [追加] 2026-10-20：企业APP服务器兼容核对与合成全流程验收数据
-- 来源：用户授权核对本机/服务器数据库、补齐服务器、清理可确认测试数据并重建验收集
-- 目标：recruit_agent；服务器MySQL 8.0.45；追加触发器语法要求MySQL >= 8.0.29
-- ============================================================
-- 本次核对：服务器115张业务基础表，本机111张（含2张本机备份表）；共同业务字段一致。
-- 服务器8个视图与本机一致、声明外键无孤儿记录；阶段字段已存在，不重复ALTER TABLE。
-- 仅补齐六个业务触发器。未复制本机严格sys_oper_log拦截器、无操作消息触发器或无关Agent触发器。
-- 原有“测试开发工程师”是岗位名称，不作为演示数据删除；未标记来源的用户/候选人/岗位全部保留。
-- 服务器变更前已导出完整备份，位于backend/doc/backup/db-support-20261020（本地私有，不提交）。
-- 下列演示清理/插入默认关闭；重跑整份历史new.sql并不安全，请只执行本追加节的相应分段。
-- 无数据库凭据、密码、Token、真实个人数据或本机连接配置。
--
-- 回滚说明：六个触发器均为本次新增；仅在确认停用本次补丁后逐一DROP TRIGGER。
-- 验收记录均以create_by=eapp_acceptance_20261020、JD JSON eappSeed和【演示数据】文本标记。
-- 完整备份可恢复变更前状态；不得在多人继续写入后整库覆盖，应按标记与关联表精确回滚。
-- 通知样例是演示文本，不代表自动改期通知已实现；报告和评分是预置演示内容，不是真实AI输出。
-- 所有虚拟候选人禁用登录、无角色、无密码和联系方式，不发送真实短信/邮件/推送。
--
-- A. 必要业务触发器（只新增缺失项，不覆盖现有触发器定义）
SET NAMES utf8mb4;

SET SESSION lock_wait_timeout=15;

DELIMITER $$

CREATE TRIGGER IF NOT EXISTS `trg_app_record_after_insert` AFTER INSERT ON `t_app_record` FOR EACH ROW
BEGIN
    UPDATE `t_tal` SET tal_status = 1, tal_updated_at = NOW()
    WHERE tal_id = NEW.app_candidate_id AND tal_status = 0;
END$$

CREATE TRIGGER IF NOT EXISTS `trg_tal_status_log_after_update` AFTER UPDATE ON `t_tal` FOR EACH ROW
BEGIN
    IF NEW.tal_status <> OLD.tal_status THEN
        INSERT INTO `t_tal_status_log` (tsl_candidate_id, tsl_from_status, tsl_to_status, tsl_operator_id, tsl_reason, tsl_created_at)
        VALUES (NEW.tal_id, OLD.tal_status, NEW.tal_status, NULL, '状态变更', NOW());
    END IF;
END$$

CREATE TRIGGER IF NOT EXISTS `trg_process_instance_after_update` AFTER UPDATE ON `t_process_instance` FOR EACH ROW
BEGIN
    IF NEW.pin_status <> OLD.pin_status OR
       (NEW.pin_current_stage_id <> IFNULL(OLD.pin_current_stage_id, 0)) THEN
        INSERT INTO `sys_oper_log` (
            aud_user_id, aud_action, aud_object_type, aud_object_id,
            aud_detail, aud_log_type, oper_ip, status, oper_time
        ) VALUES (
            NULL, 'UPDATE_PROCESS_INSTANCE', 'PROCESS_INSTANCE', NEW.pin_id,
            JSON_OBJECT(
                'from_status', OLD.pin_status, 'to_status', NEW.pin_status,
                'from_stage', OLD.pin_current_stage_id, 'to_stage', NEW.pin_current_stage_id
            ),
            2, NULL, 1, NOW()
        );
    END IF;
END$$

CREATE TRIGGER IF NOT EXISTS `trg_exam_record_after_update` AFTER UPDATE ON `t_exam_record` FOR EACH ROW
BEGIN
    IF NEW.erc_status <> OLD.erc_status THEN
        INSERT INTO `sys_oper_log` (
            aud_user_id, aud_action, aud_object_type, aud_object_id,
            aud_detail, aud_log_type, oper_ip, status, oper_time
        ) VALUES (
            NULL, 'UPDATE_EXAM_RECORD', 'EXAM_RECORD', NEW.erc_id,
            JSON_OBJECT('from_status', OLD.erc_status, 'to_status', NEW.erc_status),
            2, NULL, 1, NOW()
        );
    END IF;
END$$

CREATE TRIGGER IF NOT EXISTS `trg_exam_schedule_after_update` AFTER UPDATE ON `t_exam_schedule` FOR EACH ROW
BEGIN
    IF NEW.esd_status <> OLD.esd_status THEN
        INSERT INTO `sys_oper_log` (
            aud_user_id, aud_action, aud_object_type, aud_object_id,
            aud_detail, aud_log_type, oper_ip, status, oper_time
        ) VALUES (
            NULL, 'UPDATE_EXAM_SCHEDULE', 'EXAM_SCHEDULE', NEW.esd_id,
            JSON_OBJECT('from_status', OLD.esd_status, 'to_status', NEW.esd_status),
            2, NULL, 1, NOW()
        );
    END IF;
END$$

CREATE TRIGGER IF NOT EXISTS `trg_offer_approval_after_update` AFTER UPDATE ON `t_offer_approval` FOR EACH ROW
BEGIN
    IF NEW.oap_status <> OLD.oap_status THEN
        INSERT INTO `sys_oper_log` (
            aud_user_id, aud_action, aud_object_type, aud_object_id,
            aud_detail, aud_log_type, oper_ip, status, oper_time
        ) VALUES (
            NEW.oap_approver_id, 'UPDATE_OFFER_APPROVAL', 'OFFER_APPROVAL', NEW.oap_id,
            JSON_OBJECT('from_status', OLD.oap_status, 'to_status', NEW.oap_status),
            2, NULL, 1, NOW()
        );
    END IF;
END$$

DELIMITER ;

SELECT TRIGGER_NAME,EVENT_OBJECT_TABLE FROM INFORMATION_SCHEMA.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() ORDER BY TRIGGER_NAME;

-- B. 精确清理旧消息演示数据（默认关闭；保留包含非演示消息的会话）
-- 显式执行该分段前可设置：SET @eapp_legacy_cleanup_enabled=1;
SET NAMES utf8mb4;
SET @eapp_legacy_cleanup_enabled = COALESCE(@eapp_legacy_cleanup_enabled,0);
DELIMITER $$
DROP PROCEDURE IF EXISTS __eapp_cleanup_legacy_20261020$$
CREATE PROCEDURE __eapp_cleanup_legacy_20261020()
main: BEGIN
  DECLARE v_users INT DEFAULT 0;
  DECLARE v_sessions INT DEFAULT 0;
  DECLARE v_messages INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  IF @eapp_legacy_cleanup_enabled<>1 THEN SELECT 'SKIPPED: legacy cleanup opt-in is off' AS result; LEAVE main; END IF;
  START TRANSACTION;
  CREATE TEMPORARY TABLE IF NOT EXISTS eapp_legacy_users(user_id BIGINT PRIMARY KEY);
  CREATE TEMPORARY TABLE IF NOT EXISTS eapp_legacy_sessions(session_id BIGINT PRIMARY KEY);
  DELETE FROM eapp_legacy_users; DELETE FROM eapp_legacy_sessions;
  INSERT INTO eapp_legacy_users
    SELECT u.user_id FROM sys_user u
    WHERE u.create_by='eapp_message_demo_20261018'
      AND u.user_name IN('eapp_msg_demo_alpha','eapp_msg_demo_beta','eapp_msg_demo_gamma')
      AND u.status='1' AND COALESCE(u.password,'')=''
      AND NOT EXISTS(SELECT 1 FROM sys_user_role r WHERE r.user_id=u.user_id)
      AND NOT EXISTS(SELECT 1 FROM t_tal t WHERE t.tal_user_id=u.user_id)
      AND NOT EXISTS(SELECT 1 FROM t_cmp_binding b WHERE b.bnd_user_id=u.user_id)
      AND NOT EXISTS(SELECT 1 FROM t_res_base r WHERE r.rbs_user_id=u.user_id);
  INSERT INTO eapp_legacy_sessions
    SELECT s.ims_id FROM t_im_session s JOIN eapp_legacy_users u ON u.user_id=s.ims_user_a_id OR u.user_id=s.ims_user_b_id
    WHERE NOT EXISTS(SELECT 1 FROM t_im_message m WHERE m.imsg_session_id=s.ims_id AND m.imsg_content NOT LIKE '【演示数据】%');
  DELETE m FROM t_im_message m JOIN eapp_legacy_sessions s ON s.session_id=m.imsg_session_id;
  SET v_messages=ROW_COUNT();
  DELETE s FROM t_im_session s JOIN eapp_legacy_sessions x ON x.session_id=s.ims_id;
  SET v_sessions=ROW_COUNT();
  DELETE u FROM sys_user u JOIN eapp_legacy_users x ON x.user_id=u.user_id
    WHERE NOT EXISTS(SELECT 1 FROM t_im_session s WHERE s.ims_user_a_id=u.user_id OR s.ims_user_b_id=u.user_id)
      AND NOT EXISTS(SELECT 1 FROM t_msg m WHERE m.msg_receiver_id=u.user_id OR m.msg_sender_id=u.user_id);
  SET v_users=ROW_COUNT();
  COMMIT;
  SELECT v_users AS removed_demo_users,v_sessions AS removed_demo_sessions,v_messages AS removed_demo_messages;
END$$
DELIMITER ;
CALL __eapp_cleanup_legacy_20261020();
DROP PROCEDURE __eapp_cleanup_legacy_20261020;
SET @eapp_legacy_cleanup_enabled=0;

-- C. 全流程验收数据（默认关闭；每企业2个有候选人岗位、1个空态、1个暂停、1个下线）
-- 仅作用于已审核且已有活动绑定的企业1/2；用户身份从现有绑定只读获取，不修改成员权限。
-- 显式执行该分段前可设置：SET @eapp_seed_enabled=1;
-- 重复执行发现完整标记集合则直接跳过，不重置已读状态或已编辑数据；发现部分集合则拒绝执行。
-- EAPP acceptance fixture, explicit opt-in, synthetic content only.
-- Does not delete unmarked legacy rows, real users, permissions or configuration.
SET NAMES utf8mb4;
SET SESSION time_zone = '+08:00';
SET @eapp_seed_enabled = COALESCE(@eapp_seed_enabled, 0);
DELIMITER $$
DROP PROCEDURE IF EXISTS __eapp_seed_20261020$$
CREATE PROCEDURE __eapp_seed_20261020()
main: BEGIN
  DECLARE v_company BIGINT;
  DECLARE v_hr BIGINT;
  DECLARE v_user BIGINT;
  DECLARE v_resume BIGINT;
  DECLARE v_talent BIGINT;
  DECLARE v_pos BIGINT;
  DECLARE v_template BIGINT;
  DECLARE v_interview_template BIGINT;
  DECLARE v_instance BIGINT;
  DECLARE v_stage BIGINT;
  DECLARE v_appointment BIGINT;
  DECLARE v_slot BIGINT;
  DECLARE v_session BIGINT;
  DECLARE v_im BIGINT;
  DECLARE v_paper BIGINT;
  DECLARE v_question BIGINT;
  DECLARE v_schedule BIGINT;
  DECLARE v_record BIGINT;
  DECLARE v_task BIGINT;
  DECLARE v_offer BIGINT;
  DECLARE v_survey BIGINT;
  DECLARE v_idx INT DEFAULT 0;
  DECLARE v_j INT DEFAULT 0;
  DECLARE v_round INT DEFAULT 0;
  DECLARE v_passed INT DEFAULT 0;
  DECLARE v_current INT DEFAULT 1;
  DECLARE v_status INT DEFAULT 0;
  DECLARE v_pinstatus INT DEFAULT 0;
  DECLARE v_score DECIMAL(5,2);
  DECLARE v_start DATETIME;
  DECLARE v_end DATETIME;
  DECLARE v_name VARCHAR(100);
  DECLARE v_skill VARCHAR(50);
  DECLARE v_user_name VARCHAR(50);
  DECLARE v_existing INT DEFAULT 0;
  DECLARE v_lock INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    DO RELEASE_LOCK('eapp_acceptance_20261020');
    RESIGNAL;
  END;
  IF @eapp_seed_enabled <> 1 THEN
    SELECT 'SKIPPED: set @eapp_seed_enabled=1 explicitly for acceptance fixtures' AS result;
    LEAVE main;
  END IF;
  SELECT GET_LOCK('eapp_acceptance_20261020',5) INTO v_lock;
  IF v_lock <> 1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='EAPP fixture migration already running'; END IF;
  SELECT COUNT(*) INTO v_existing FROM sys_user WHERE create_by='eapp_acceptance_20261020';
  IF v_existing=8 THEN
    IF (SELECT COUNT(*) FROM t_pos WHERE JSON_UNQUOTE(JSON_EXTRACT(pos_jd_json,'$.eappSeed'))='eapp_acceptance_20261020')<>10 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Partial fixture exists; inspect before attempting repair';
    END IF;
    DO RELEASE_LOCK('eapp_acceptance_20261020');
    SELECT 'ALREADY_PRESENT: fixture unchanged, no read states or edits reset' AS result;
    LEAVE main;
  END IF;
  IF v_existing<>0 OR EXISTS(SELECT 1 FROM sys_user WHERE user_name LIKE 'eapp_acceptance_20261020_%') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unexpected fixture identity collision';
  END IF;
  IF (SELECT COUNT(DISTINCT b.bnd_company_id) FROM t_cmp_binding b JOIN sys_user u ON u.user_id=b.bnd_user_id JOIN t_cmp c ON c.cmp_id=b.bnd_company_id
      WHERE b.bnd_status=1 AND u.status='0' AND u.del_flag='0' AND c.cmp_status=1 AND c.cmp_verify_status=1 AND c.cmp_id IN(1,2))<>2 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Expected approved active enterprise bindings for company 1 and 2';
  END IF;
  START TRANSACTION;
  CREATE TEMPORARY TABLE IF NOT EXISTS eapp_fixture_users(idx INT PRIMARY KEY,user_id BIGINT,resume_id BIGINT);
  CREATE TEMPORARY TABLE IF NOT EXISTS eapp_fixture_jobs(company_id BIGINT,idx INT,pos_id BIGINT,template_id BIGINT,interview_template_id BIGINT,PRIMARY KEY(company_id,idx));
  CREATE TEMPORARY TABLE IF NOT EXISTS eapp_fixture_stages(template_id BIGINT,round_no INT,stage_id BIGINT,PRIMARY KEY(template_id,round_no));
  CREATE TEMPORARY TABLE IF NOT EXISTS eapp_fixture_talents(company_id BIGINT,idx INT,talent_id BIGINT,pos_id BIGINT,instance_id BIGINT,PRIMARY KEY(company_id,idx));
  CREATE TEMPORARY TABLE IF NOT EXISTS eapp_fixture_sessions(company_id BIGINT,idx INT,round_no INT,session_id BIGINT,PRIMARY KEY(company_id,idx,round_no));
  CREATE TEMPORARY TABLE IF NOT EXISTS eapp_fixture_surveys(company_id BIGINT PRIMARY KEY,survey_id BIGINT);
  DELETE FROM eapp_fixture_users; DELETE FROM eapp_fixture_jobs; DELETE FROM eapp_fixture_stages; DELETE FROM eapp_fixture_talents; DELETE FROM eapp_fixture_sessions; DELETE FROM eapp_fixture_surveys;

  SET v_idx=0;
  WHILE v_idx<8 DO
    SET v_user_name=CONCAT('eapp_acceptance_20261020_',LPAD(v_idx+1,2,'0'));
    INSERT INTO sys_user(user_name,nick_name,real_name,user_type,user_identity_type,password,status,del_flag,create_by,create_time,remark)
      VALUES(v_user_name,CONCAT('【演示数据】候选人',LPAD(v_idx+1,2,'0')),NULL,'00',0,NULL,'1','0','eapp_acceptance_20261020',NOW(),'【演示数据】禁用登录、无角色、无真实联系方式；仅用于企业APP功能验收');
    SET v_user=LAST_INSERT_ID();
    INSERT INTO t_res_base(rbs_user_id,rbs_resume_name,rbs_job_direction,rbs_is_default,rbs_status)
      VALUES(v_user,CONCAT('【演示数据】验收简历',v_idx+1),IF(v_idx<4,'Java后端开发','Flutter移动开发'),1,1);
    SET v_resume=LAST_INSERT_ID();
    INSERT INTO eapp_fixture_users VALUES(v_idx,v_user,v_resume);
    INSERT INTO t_res_education(edu_resume_id,edu_school,edu_major,edu_degree,edu_start_date,edu_end_date,edu_description)
      VALUES(v_resume,'【演示数据】示范大学','【演示数据】软件工程',IF(MOD(v_idx,3)=0,4,3),'2016-09-01','2020-06-30','【演示数据】虚构教育经历，不对应真实院校或个人');
    INSERT INTO t_res_work(wrk_resume_id,wrk_company,wrk_position,wrk_start_date,wrk_is_current,wrk_description)
      VALUES(v_resume,'【演示数据】示范研发团队',IF(v_idx<4,'后端工程师','移动开发工程师'),'2021-01-01',1,'【演示数据】参与接口设计、测试与交付；此经历为虚构验收内容');
    INSERT INTO t_res_project(prj_resume_id,prj_name,prj_role,prj_start_date,prj_end_date,prj_description,prj_tech_stack)
      VALUES(v_resume,'【演示数据】协作招聘样例','【演示数据】开发','2024-01-01','2024-12-31','【演示数据】用于项目摘要展开和完整度展示',IF(v_idx<4,'Java,Spring Boot,MySQL','Flutter,Dart,REST'));
    INSERT INTO t_res_skill(skl_resume_id,skl_name,skl_level) VALUES(v_resume,IF(v_idx<4,'Java','Flutter'),3),(v_resume,IF(v_idx<4,'Spring Boot','Dart'),3);
    IF MOD(v_idx,2)=0 THEN INSERT INTO t_res_skill(skl_resume_id,skl_name,skl_level) VALUES(v_resume,'MySQL',2),(v_resume,'Git',2); END IF;
    SET v_idx=v_idx+1;
  END WHILE;

  SET v_company=1;
  WHILE v_company<=2 DO
    SELECT MIN(b.bnd_user_id) INTO v_hr FROM t_cmp_binding b JOIN sys_user u ON u.user_id=b.bnd_user_id
      WHERE b.bnd_company_id=v_company AND b.bnd_status=1 AND u.status='0' AND u.del_flag='0';
    INSERT INTO t_survey_template(svt_name,svt_trigger_scene,svt_company_id,svt_questions,svt_status)
      VALUES('【演示数据】面试体验验收',1,v_company,JSON_ARRAY(JSON_OBJECT('id','overall','type','rating','title','【演示数据】本轮面试体验')),1);
    SET v_survey=LAST_INSERT_ID(); INSERT INTO eapp_fixture_surveys VALUES(v_company,v_survey);
    SET v_j=0;
    WHILE v_j<5 DO
      SET v_name=CASE v_j WHEN 0 THEN '【演示数据】Java后端工程师' WHEN 1 THEN '【演示数据】Flutter开发工程师' WHEN 2 THEN '【演示数据】待投递空态岗位' WHEN 3 THEN '【演示数据】暂停招聘样例' ELSE '【演示数据】已下线岗位样例' END;
      INSERT INTO t_pos(pos_company_id,pos_publisher_id,pos_title,pos_department,pos_work_city,pos_salary_min,pos_salary_max,pos_experience_required,pos_education_required,pos_job_type,pos_jd_json,pos_status)
      VALUES(v_company,v_hr,v_name,'【演示数据】研发组','【演示数据】示范城市',18000,28000,'3-5年',3,1,
        JSON_OBJECT('eappSeed','eapp_acceptance_20261020','description','【演示数据】用于招聘全流程验收，不是真实招聘岗位',
          'responsibilities',JSON_ARRAY('【演示数据】负责接口及客户端交付','【演示数据】参与测试和代码评审'),
          'requirements',JSON_ARRAY('【演示数据】掌握岗位所需技能','【演示数据】具有沟通与协作能力'),
          'summary','【演示数据】预置JD画像，不代表本次真实AI调用','softRequirements',JSON_ARRAY('【演示数据】沟通协作')),
        CASE v_j WHEN 3 THEN 2 WHEN 4 THEN 0 ELSE 1 END);
      SET v_pos=LAST_INSERT_ID();
      INSERT INTO t_pos_skill(psk_position_id,psk_name,psk_required) VALUES(v_pos,IF(v_j=1,'Flutter','Java'),1),(v_pos,IF(v_j=1,'Dart','Spring Boot'),1),(v_pos,'MySQL',1),(v_pos,'Git',0);
      IF v_j<2 THEN
        INSERT INTO t_process_template(ptl_company_id,ptl_name,ptl_position_id,ptl_version,ptl_status) VALUES(v_company,CONCAT('【演示数据】六阶段流程',v_j+1),v_pos,'v1.0',1);
        SET v_template=LAST_INSERT_ID();
        SET v_round=1;
        WHILE v_round<=6 DO
          SET v_name=CASE v_round WHEN 1 THEN '在线笔试' WHEN 2 THEN 'AI技术面试' WHEN 3 THEN '编程实操' WHEN 4 THEN '业务复试' WHEN 5 THEN 'HR综合面试' ELSE '录用沟通' END;
          INSERT INTO t_process_stage(psg_template_id,psg_name,psg_type,psg_sort_order,psg_is_required,psg_pass_threshold,psg_interviewer_config_json)
            VALUES(v_template,v_name,CASE v_round WHEN 1 THEN 1 WHEN 3 THEN 4 WHEN 5 THEN 3 WHEN 6 THEN 3 ELSE 2 END,v_round,1,70,
              JSON_OBJECT('duration',45,'interviewer',CAST(v_hr AS CHAR),'target','【演示数据】验收阶段','mode','在线','skip',FALSE,'terminate',FALSE));
          SET v_stage=LAST_INSERT_ID(); INSERT INTO eapp_fixture_stages VALUES(v_template,v_round,v_stage);
          SET v_round=v_round+1;
        END WHILE;
        UPDATE t_pos SET pos_process_template_id=v_template WHERE pos_id=v_pos;
        INSERT INTO t_int_template(itl_company_id,itl_name,itl_position_id,itl_interview_mode,itl_total_rounds,itl_process_template_id,itl_version,itl_stage_config_json,itl_status)
          VALUES(v_company,'【演示数据】多轮面试验收模板',v_pos,2,6,v_template,'v1.0',JSON_OBJECT('source','eapp_acceptance_20261020'),1);
        SET v_interview_template=LAST_INSERT_ID();
        INSERT INTO t_practice_task(tsk_position_id,tsk_template_id,tsk_title,tsk_description,tsk_language,tsk_initial_code,tsk_expected_output,tsk_test_cases,tsk_time_limit,tsk_difficulty,tsk_status)
          VALUES(v_pos,v_interview_template,'【演示数据】求和练习','【演示数据】仅供页面展示，不代表真实评测结果','java','// 演示数据：实现add函数','3',JSON_ARRAY(JSON_OBJECT('input','1 2','expected','3')),60,1,1);
      ELSE SET v_template=NULL; SET v_interview_template=NULL;
      END IF;
      INSERT INTO eapp_fixture_jobs VALUES(v_company,v_j,v_pos,v_template,v_interview_template);
      SET v_j=v_j+1;
    END WHILE;

    SET v_idx=0;
    WHILE v_idx<8 DO
      SELECT user_id,resume_id INTO v_user,v_resume FROM eapp_fixture_users WHERE idx=v_idx;
      SELECT pos_id,template_id,interview_template_id INTO v_pos,v_template,v_interview_template FROM eapp_fixture_jobs WHERE company_id=v_company AND idx=IF(v_idx<4,0,1);
      SET v_status=CASE v_idx WHEN 0 THEN 2 WHEN 1 THEN 1 WHEN 2 THEN 5 WHEN 3 THEN 3 WHEN 4 THEN 9 WHEN 5 THEN 0 WHEN 6 THEN 7 ELSE 4 END;
      SET v_passed=CASE v_idx WHEN 0 THEN 2 WHEN 1 THEN 0 WHEN 2 THEN 6 WHEN 3 THEN 2 WHEN 4 THEN 3 WHEN 5 THEN 0 WHEN 6 THEN 0 ELSE 5 END;
      SET v_current=LEAST(v_passed+1,6);
      SET v_score=CASE v_idx WHEN 0 THEN 79 WHEN 1 THEN 73 WHEN 2 THEN 91 WHEN 3 THEN 67 WHEN 4 THEN 61 WHEN 5 THEN 55 WHEN 6 THEN 70 ELSE 88 END;
      INSERT INTO t_tal(tal_user_id,tal_company_id,tal_resume_id,tal_status,tal_matched_score,tal_archive_source,tal_current_round)
        VALUES(v_user,v_company,v_resume,1,v_score,IF(v_idx=6,3,0),v_current);
      SET v_talent=LAST_INSERT_ID();
      SELECT stage_id INTO v_stage FROM eapp_fixture_stages WHERE template_id=v_template AND round_no=v_current;
      SET v_pinstatus=CASE WHEN v_idx IN(2,7) THEN 1 WHEN v_idx=3 THEN 3 WHEN v_idx=6 THEN 2 ELSE 0 END;
      INSERT INTO t_process_instance(pin_candidate_id,pin_position_id,pin_template_id,pin_current_stage_id,pin_status,pin_start_at,pin_end_at)
        VALUES(v_talent,v_pos,v_template,v_stage,v_pinstatus,DATE_SUB(NOW(),INTERVAL 15 DAY),IF(v_pinstatus=0,NULL,DATE_SUB(NOW(),INTERVAL 1 DAY)));
      SET v_instance=LAST_INSERT_ID();
      UPDATE t_tal SET tal_process_instance_id=v_instance WHERE tal_id=v_talent;
      INSERT INTO eapp_fixture_talents VALUES(v_company,v_idx,v_talent,v_pos,v_instance);
      INSERT INTO t_app_record(app_candidate_id,app_position_id,app_resume_id,app_matched_score,app_status,app_process_instance_id,app_created_at)
        VALUES(v_talent,v_pos,v_resume,v_score,IF(v_idx IN(2,7),2,IF(v_idx=3,3,1)),v_instance,DATE_SUB(NOW(),INTERVAL (v_idx+1) DAY));
      UPDATE t_tal SET tal_status=v_status WHERE tal_id=v_talent;
      INSERT INTO t_tal_tag(tg_candidate_id,tg_name,tg_source) VALUES(v_talent,'演示数据',1),(v_talent,IF(v_idx<4,'Java','Flutter'),1);
      INSERT INTO t_greeting_record(grt_position_id,grt_candidate_id,grt_resume_id,grt_match_points,grt_content,grt_status)
        VALUES(v_pos,v_talent,v_resume,JSON_ARRAY('【演示数据】技能标签可匹配','【演示数据】此内容为预置验收报告，不是实时AI生成'),
          '【演示数据】您好！这是企业APP招呼语和推荐报告展示样例，不会发送邮件或短信。',0);

      SET v_round=1;
      WHILE v_round<=v_passed DO
        SELECT stage_id INTO v_stage FROM eapp_fixture_stages WHERE template_id=v_template AND round_no=v_round;
        SET v_start=TIMESTAMP(DATE_SUB(CURDATE(),INTERVAL (v_idx*7+7-v_round) DAY),'10:00:00');
        SET v_end=DATE_ADD(v_start,INTERVAL 45 MINUTE);
        INSERT INTO t_process_instance_stage(pis_instance_id,pis_stage_id,pis_start_at,pis_end_at,pis_status,pis_operator_id,pis_result_note)
          VALUES(v_instance,v_stage,v_start,v_end,1,v_hr,'【演示数据】阶段已参加并通过，仅用于绿点绿线验收');
        INSERT INTO t_sch_slot(slt_interviewer_id,slt_position_id,slt_start_time,slt_end_time,slt_status) VALUES(v_hr,v_pos,v_start,v_end,1);
        SET v_slot=LAST_INSERT_ID();
        INSERT INTO t_sch_appointment(apt_candidate_id,apt_position_id,apt_interviewer_id,apt_slot_id,apt_start_time,apt_end_time,apt_status,apt_stage_id,apt_stage_name,apt_stage_type,apt_stage_order)
          SELECT v_talent,v_pos,v_hr,v_slot,v_start,v_end,3,psg_id,psg_name,psg_type,psg_sort_order FROM t_process_stage WHERE psg_id=v_stage;
        SET v_appointment=LAST_INSERT_ID();
        INSERT INTO t_int_session(ses_appointment_id,ses_candidate_id,ses_position_id,ses_interviewer_id,ses_template_id,ses_cascade_round,ses_mode,ses_status,ses_start_at,ses_end_at,ses_process_instance_id,ses_auto_recording)
          VALUES(v_appointment,v_talent,v_pos,v_hr,v_interview_template,v_round,2,2,v_start,v_end,v_instance,0);
        SET v_session=LAST_INSERT_ID();
        INSERT INTO eapp_fixture_sessions VALUES(v_company,v_idx,v_round,v_session);
        INSERT INTO t_int_session_interviewer(isi_session_id,isi_user_id,isi_is_primary,isi_join_status,isi_joined_at,isi_accept_status) VALUES(v_session,v_hr,1,2,v_start,1);
        INSERT INTO t_int_evaluation(evl_session_id,evl_overall_score,evl_dimension_scores,evl_summary,evl_advantages,evl_risks,evl_gaps,evl_recommendation,evl_hr_status)
          VALUES(v_session,v_score,JSON_OBJECT('技术理论',v_score,'项目实践',LEAST(v_score+2,100),'沟通协作',LEAST(v_score+1,100)),
            CONCAT('【演示数据】第',v_round,'轮面试总结：本报告为预置合成内容，仅供本轮报告入口和长正文展示验收；不是实时模型输出。'),
            '【演示数据】能够清楚描述实现思路和测试方法','【演示数据】需通过真实面试再次核实，不构成招聘结论','【演示数据】可加强边界条件分析',IF(v_score>=70,1,2),IF(v_idx=2,1,0));
        INSERT INTO t_int_dialogue(dlg_session_id,dlg_role,dlg_content,dlg_order,dlg_type)
          VALUES(v_session,1,'【演示数据】请描述一个项目中的技术挑战。',30,1),(v_session,3,'【演示数据】这是虚构候选人的合成作答。',60,1);
        INSERT INTO t_int_score(scr_session_id,scr_dimension,scr_score,scr_comment,scr_scorer_type)
          VALUES(v_session,1,v_score,'【演示数据】预置维度评分，不是实时AI打分',1);
        IF v_round=3 THEN
          SELECT MIN(tsk_id) INTO v_task FROM t_practice_task WHERE tsk_position_id=v_pos AND tsk_title='【演示数据】求和练习';
          INSERT INTO t_practice_answer(ans_task_id,ans_session_id,ans_candidate_id,ans_submitted_code,ans_execution_result,ans_pass_count,ans_total_count,ans_score,ans_duration_sec,ans_status)
            VALUES(v_task,v_session,v_talent,'// 演示数据：return a + b;',JSON_OBJECT('demo',TRUE,'message','演示数据：未调用真实评测器'),1,1,100,60,2);
        END IF;
        SET v_round=v_round+1;
      END WHILE;

      IF v_idx IN(0,1,4) THEN
        SELECT stage_id INTO v_stage FROM eapp_fixture_stages WHERE template_id=v_template AND round_no=v_current;
        SET v_start=IF(v_idx=0,DATE_ADD(NOW(),INTERVAL 1 HOUR),TIMESTAMP(DATE_ADD(CURDATE(),INTERVAL (v_idx+1) DAY),'10:00:00'));
        SET v_start=DATE_ADD(DATE_FORMAT(v_start,'%Y-%m-%d %H:00:00'),INTERVAL 15 MINUTE);
        SET v_end=DATE_ADD(v_start,INTERVAL 45 MINUTE);
        WHILE EXISTS(SELECT 1 FROM t_sch_appointment WHERE apt_status IN(0,1) AND (apt_interviewer_id=v_hr OR apt_candidate_id=v_talent) AND apt_start_time<v_end AND apt_end_time>v_start)
           OR EXISTS(SELECT 1 FROM t_sch_slot WHERE slt_interviewer_id=v_hr AND slt_status=0 AND slt_start_time<v_end AND slt_end_time>v_start) DO
          SET v_start=DATE_ADD(v_start,INTERVAL 1 HOUR); SET v_end=DATE_ADD(v_start,INTERVAL 45 MINUTE);
        END WHILE;
        INSERT INTO t_sch_slot(slt_interviewer_id,slt_position_id,slt_start_time,slt_end_time,slt_status) VALUES(v_hr,v_pos,v_start,v_end,0); SET v_slot=LAST_INSERT_ID();
        INSERT INTO t_sch_appointment(apt_candidate_id,apt_position_id,apt_interviewer_id,apt_slot_id,apt_start_time,apt_end_time,apt_status,apt_stage_id,apt_stage_name,apt_stage_type,apt_stage_order)
          SELECT v_talent,v_pos,v_hr,v_slot,v_start,v_end,IF(v_idx=1,0,1),psg_id,psg_name,psg_type,psg_sort_order FROM t_process_stage WHERE psg_id=v_stage;
      END IF;
      IF v_idx=5 THEN
        SELECT stage_id INTO v_stage FROM eapp_fixture_stages WHERE template_id=v_template AND round_no=1;
        INSERT INTO t_sch_appointment(apt_candidate_id,apt_position_id,apt_interviewer_id,apt_start_time,apt_end_time,apt_status,apt_stage_id,apt_stage_name,apt_stage_type,apt_stage_order)
          SELECT v_talent,v_pos,v_hr,DATE_SUB(NOW(),INTERVAL 2 DAY),DATE_ADD(DATE_SUB(NOW(),INTERVAL 2 DAY),INTERVAL 45 MINUTE),0,psg_id,psg_name,psg_type,psg_sort_order FROM t_process_stage WHERE psg_id=v_stage;
      END IF;
      IF v_idx=6 THEN
        SELECT stage_id INTO v_stage FROM eapp_fixture_stages WHERE template_id=v_template AND round_no=1;
        INSERT INTO t_sch_appointment(apt_candidate_id,apt_position_id,apt_interviewer_id,apt_start_time,apt_end_time,apt_status,apt_cancel_reason,apt_stage_id,apt_stage_name,apt_stage_type,apt_stage_order)
          SELECT v_talent,v_pos,v_hr,DATE_ADD(NOW(),INTERVAL 3 DAY),DATE_ADD(DATE_ADD(NOW(),INTERVAL 3 DAY),INTERVAL 45 MINUTE),2,'【演示数据】已取消，不占用新时段',psg_id,psg_name,psg_type,psg_sort_order FROM t_process_stage WHERE psg_id=v_stage;
      END IF;
      IF v_idx IN(2,7) THEN
        INSERT INTO t_off_offer(ofr_candidate_id,ofr_position_id,ofr_salary_offer,ofr_benefits,ofr_deadline,ofr_onboard_date,ofr_approval_status,ofr_status)
          VALUES(v_talent,v_pos,'【演示数据】月薪22000元','【演示数据】仅供Offer及审批验收，不是真实要约',DATE_ADD(NOW(),INTERVAL 14 DAY),DATE_ADD(CURDATE(),INTERVAL 21 DAY),IF(v_idx=2,2,1),IF(v_idx=2,1,5));
        SET v_offer=LAST_INSERT_ID();
        INSERT INTO t_offer_approval(oap_offer_id,oap_node_name,oap_node_order,oap_approver_id,oap_status,oap_comment,oap_approved_at)
          VALUES(v_offer,'【演示数据】HR审批',1,v_hr,IF(v_idx=2,1,0),'【演示数据】预置审批记录',IF(v_idx=2,NOW(),NULL));
        IF v_idx=2 THEN
          INSERT INTO t_onboarding(obd_offer_id,obd_candidate_id,obd_status,obd_followup_record,obd_owner_id,obd_expected_onboard_date)
            VALUES(v_offer,v_talent,1,'【演示数据】已入职记录，仅供状态展示',v_hr,DATE_SUB(CURDATE(),INTERVAL 1 DAY));
        END IF;
      END IF;
      IF v_idx=2 THEN
        SELECT session_id INTO v_session FROM eapp_fixture_sessions WHERE company_id=v_company AND idx=v_idx AND round_no=6;
        INSERT INTO t_survey_response(svr_template_id,svr_candidate_id,svr_session_id,svr_answers,svr_satisfaction_score,svr_submitted_at)
          VALUES(v_survey,v_talent,v_session,JSON_OBJECT('overall',5,'comment','【演示数据】合成满意度答复'),95,NOW());
      END IF;
      IF v_idx<3 THEN
        INSERT INTO t_im_session(ims_user_a_id,ims_user_b_id,ims_last_message,ims_last_message_at,ims_unread_a,ims_unread_b)
          VALUES(v_hr,v_user,'【演示数据】合成会话，请勿视为真实求职沟通',NOW(),1,0);
        SET v_im=LAST_INSERT_ID();
        INSERT INTO t_im_message(imsg_session_id,imsg_sender_id,imsg_type,imsg_content,imsg_created_at)
          VALUES(v_im,v_user,1,'【演示数据】您好，这是用于消息中心验收的合成消息。',DATE_SUB(NOW(),INTERVAL 5 MINUTE)),
          (v_im,v_hr,1,'【演示数据】岗位及面试信息可在资料卡片查看。',DATE_SUB(NOW(),INTERVAL 3 MINUTE)),
          (v_im,v_user,1,'【演示数据】消息已收到，暂无真实自动回复或外部通知。',NOW());
      END IF;
      SET v_idx=v_idx+1;
    END WHILE;

    SET v_j=0;
    WHILE v_j<2 DO
      SELECT pos_id INTO v_pos FROM eapp_fixture_jobs WHERE company_id=v_company AND idx=v_j;
      INSERT INTO t_exam_question(eqs_type,eqs_content,eqs_options_json,eqs_answer,eqs_score,eqs_difficulty,eqs_skill_tag)
        VALUES(1,'【演示数据】HTTP读取资源通常使用哪种方法？',JSON_ARRAY(JSON_OBJECT('key','A','text','GET'),JSON_OBJECT('key','B','text','DELETE')),'A',100,1,'演示数据');
      SET v_question=LAST_INSERT_ID();
      INSERT INTO t_exam_paper(epa_name,epa_position_id,epa_total_score,epa_duration_min,epa_rule_json,epa_status)
        VALUES('【演示数据】基础知识验收试卷',v_pos,100,45,JSON_OBJECT('demo',TRUE),1); SET v_paper=LAST_INSERT_ID();
      INSERT INTO t_exam_paper_question(epq_paper_id,epq_question_id,epq_score,epq_sort_order) VALUES(v_paper,v_question,100,1);
      INSERT INTO t_exam_schedule(esd_position_id,esd_paper_id,esd_start_at,esd_end_at,esd_max_attempts,esd_pass_threshold,esd_force_dual_camera,esd_submit_rule_json,esd_notify_config_json,esd_status)
        VALUES(v_pos,v_paper,DATE_SUB(NOW(),INTERVAL 10 DAY),DATE_SUB(NOW(),INTERVAL 8 DAY),1,70,0,JSON_OBJECT('demo',TRUE,'autoSubmit',TRUE),JSON_OBJECT('demo',TRUE,'enabled',FALSE),2);
      SET v_schedule=LAST_INSERT_ID();
      SELECT talent_id INTO v_talent FROM eapp_fixture_talents WHERE company_id=v_company AND idx=IF(v_j=0,2,7);
      INSERT INTO t_exam_record(erc_schedule_id,erc_candidate_id,erc_start_at,erc_submit_at,erc_status,erc_total_score,erc_pass_status)
        VALUES(v_schedule,v_talent,DATE_SUB(NOW(),INTERVAL 9 DAY),DATE_ADD(DATE_SUB(NOW(),INTERVAL 9 DAY),INTERVAL 20 MINUTE),4,100,1); SET v_record=LAST_INSERT_ID();
      INSERT INTO t_exam_answer(ean_record_id,ean_question_id,ean_content,ean_max_score,ean_is_correct,ean_score) VALUES(v_record,v_question,'A',100,1,100);
      INSERT INTO t_exam_result(ers_record_id,ers_objective_score,ers_subjective_score,ers_total_score,ers_pass_status,ers_comment)
        VALUES(v_record,100,0,100,1,'【演示数据】预置已评分结果，不触发真实判分与自动邀约');
      UPDATE t_tal SET tal_exam_record_id=v_record WHERE tal_id=v_talent;
      UPDATE t_app_record SET app_exam_record_id=v_record WHERE app_candidate_id=v_talent AND app_position_id=v_pos;
      INSERT INTO t_exam_schedule(esd_position_id,esd_paper_id,esd_start_at,esd_end_at,esd_max_attempts,esd_pass_threshold,esd_force_dual_camera,esd_notify_config_json,esd_status)
        VALUES(v_pos,v_paper,DATE_ADD(NOW(),INTERVAL 2 DAY),DATE_ADD(NOW(),INTERVAL 3 DAY),1,70,0,JSON_OBJECT('demo',TRUE,'enabled',FALSE),0);
      SET v_j=v_j+1;
    END WHILE;
    INSERT INTO t_msg(msg_receiver_id,msg_sender_id,msg_type,msg_title,msg_content,msg_is_read)
      VALUES(v_hr,0,1,'【演示数据】全流程验收数据已就绪','【演示数据】岗位、候选人、六阶段流程、已完成报告与未来排期均为合成验收数据，不是真实招聘。',0),
      (v_hr,0,1,'【演示数据】改期通知展示样例','【演示数据】此条仅展示通知格式，不代表后端已实现自动改期通知；请按代码实际能力验收。',0),
      (v_hr,0,1,'【演示数据】报告与Offer展示样例','【演示数据】预置面试总结、笔试成绩及Offer审批，不是实时AI分析或对真实候选人的要约。',1);
    SET v_company=v_company+1;
  END WHILE;
  IF (SELECT COUNT(*) FROM eapp_fixture_users)<>8 OR (SELECT COUNT(*) FROM eapp_fixture_talents)<>16 OR (SELECT COUNT(*) FROM eapp_fixture_jobs)<>10 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fixture count guard failed';
  END IF;
  COMMIT;
  DO RELEASE_LOCK('eapp_acceptance_20261020');
  SELECT 'CREATED: 8 disabled synthetic users; 16 company candidate records; 10 marked jobs; no real records changed' AS result;
END$$
DELIMITER ;
CALL __eapp_seed_20261020();
DROP PROCEDURE __eapp_seed_20261020;
SET @eapp_seed_enabled=0;


-- ============================================================
-- [追加] 2026-10-20：服务器执行结果与触发器权限门禁
-- 来源：服务器MySQL执行返回ERROR 1419；现有账号仅有当前库权限，不具备SUPER
-- ============================================================
-- A节六个触发器尚未在服务器创建：二进制日志策略限制，未降低全局安全设置或尝试提权。
-- 需由服务器数据库管理员在受控会话中执行A节；不应在应用账号上长期增加全局管理权限。
-- B节精确旧演示清理执行成功：匹配/删除均为0；未把“测试开发工程师”职业名当作演示数据。
-- C节执行成功：8个禁用用户、16个企业候选人、10个演示岗位及流程/报告/排期/消息关联数据。
-- 表结构/视图已有完整兼容字段；未复制本机备份表，不覆盖现有服务器额外表或配置。
-- 下方只为新演示候选人追加初始状态快照，幂等，不影响原有候选人或替代后续动态状态触发器。
SET NAMES utf8mb4;
START TRANSACTION;
INSERT INTO t_tal_status_log(tsl_candidate_id,tsl_from_status,tsl_to_status,tsl_reason,tsl_operator_id,tsl_created_at)
SELECT t.tal_id,NULL,t.tal_status,'【演示数据】eapp_acceptance_20261020 初始状态快照；仅为验收展示',NULL,NOW()
FROM t_tal t JOIN sys_user u ON u.user_id=t.tal_user_id
WHERE u.create_by='eapp_acceptance_20261020'
AND NOT EXISTS(SELECT 1 FROM t_tal_status_log l WHERE l.tsl_candidate_id=t.tal_id AND l.tsl_reason LIKE '【演示数据】eapp_acceptance_20261020%');
COMMIT;
SELECT COUNT(*) AS demo_initial_history FROM t_tal_status_log WHERE tsl_reason LIKE '【演示数据】eapp_acceptance_20261020%';


-- ============================================================
-- [追加] 2026-10-20：本次合成验收集的精确清理/回滚（默认关闭）
-- 来源：用户要求测试数据可替换；仅清理本节marker，保留原数据及出现真实互动的记录
-- 使用前先备份；仅执行本分段，显式设置两项开关：
-- SET @eapp_fixture_cleanup_enabled=1;
-- SET @eapp_fixture_cleanup_ack='eapp_acceptance_20261020';
-- 本分段本次只记录、未执行；清理完才可再次执行C节创建全新验收集。
-- ============================================================
SET NAMES utf8mb4;
SET @eapp_fixture_cleanup_enabled=COALESCE(@eapp_fixture_cleanup_enabled,0);
DELIMITER $$
DROP PROCEDURE IF EXISTS __eapp_fixture_cleanup_20261020$$
CREATE PROCEDURE __eapp_fixture_cleanup_20261020()
main: BEGIN
  DECLARE v_lock INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; DO RELEASE_LOCK('eapp_acceptance_20261020'); RESIGNAL; END;
  IF @eapp_fixture_cleanup_enabled<>1 OR COALESCE(@eapp_fixture_cleanup_ack,'')<>'eapp_acceptance_20261020' THEN
    SELECT 'SKIPPED: fixture cleanup disabled or explicit marker acknowledgement missing' AS result; LEAVE main;
  END IF;
  SELECT GET_LOCK('eapp_acceptance_20261020',5) INTO v_lock;
  IF v_lock<>1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fixture is in use by another migration'; END IF;
  START TRANSACTION;
  CREATE TEMPORARY TABLE IF NOT EXISTS eapp_cleanup_u(user_id BIGINT PRIMARY KEY);
  CREATE TEMPORARY TABLE IF NOT EXISTS eapp_cleanup_p(pos_id BIGINT PRIMARY KEY);
  DELETE FROM eapp_cleanup_u; DELETE FROM eapp_cleanup_p;
  INSERT INTO eapp_cleanup_u SELECT user_id FROM sys_user WHERE create_by='eapp_acceptance_20261020' AND user_name LIKE 'eapp_acceptance_20261020_%';
  INSERT INTO eapp_cleanup_p SELECT pos_id FROM t_pos WHERE JSON_UNQUOTE(JSON_EXTRACT(pos_jd_json,'$.eappSeed'))='eapp_acceptance_20261020';
  IF EXISTS(SELECT 1 FROM sys_user u JOIN eapp_cleanup_u d ON d.user_id=u.user_id WHERE u.status<>'1')
     OR EXISTS(SELECT 1 FROM sys_user_role r JOIN eapp_cleanup_u d ON d.user_id=r.user_id)
     OR EXISTS(SELECT 1 FROM t_cmp_binding b JOIN eapp_cleanup_u d ON d.user_id=b.bnd_user_id)
     OR EXISTS(SELECT 1 FROM t_im_message m JOIN t_im_session s ON s.ims_id=m.imsg_session_id JOIN eapp_cleanup_u d ON d.user_id=s.ims_user_a_id OR d.user_id=s.ims_user_b_id WHERE m.imsg_content NOT LIKE '【演示数据】%') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fixture has enabled identities, roles, bindings or non-demo messages; manual review required';
  END IF;
  IF EXISTS(SELECT 1 FROM t_app_record a JOIN eapp_cleanup_p p ON p.pos_id=a.app_position_id JOIN t_tal t ON t.tal_id=a.app_candidate_id WHERE NOT EXISTS(SELECT 1 FROM eapp_cleanup_u d WHERE d.user_id=t.tal_user_id))
     OR EXISTS(SELECT 1 FROM t_sch_appointment a JOIN eapp_cleanup_p p ON p.pos_id=a.apt_position_id JOIN t_tal t ON t.tal_id=a.apt_candidate_id WHERE NOT EXISTS(SELECT 1 FROM eapp_cleanup_u d WHERE d.user_id=t.tal_user_id)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Demo position has unmarked applicants or interviews; preserve and review manually';
  END IF;
  DELETE s FROM t_int_session s JOIN eapp_cleanup_p p ON p.pos_id=s.ses_position_id;
  DELETE a FROM t_sch_appointment a JOIN eapp_cleanup_p p ON p.pos_id=a.apt_position_id;
  DELETE t FROM t_tal t JOIN eapp_cleanup_u u ON u.user_id=t.tal_user_id;
  DELETE pt FROM t_process_template pt JOIN eapp_cleanup_p p ON p.pos_id=pt.ptl_position_id;
  DELETE task FROM t_practice_task task JOIN eapp_cleanup_p p ON p.pos_id=task.tsk_position_id;
  DELETE it FROM t_int_template it JOIN eapp_cleanup_p p ON p.pos_id=it.itl_position_id;
  DELETE slot FROM t_sch_slot slot JOIN eapp_cleanup_p p ON p.pos_id=slot.slt_position_id;
  DELETE p FROM t_pos p JOIN eapp_cleanup_p d ON d.pos_id=p.pos_id;
  DELETE u FROM sys_user u JOIN eapp_cleanup_u d ON d.user_id=u.user_id;
  DELETE q FROM t_exam_question q WHERE q.eqs_content='【演示数据】HTTP读取资源通常使用哪种方法？'
    AND NOT EXISTS(SELECT 1 FROM t_exam_paper_question pq WHERE pq.epq_question_id=q.eqs_id)
    AND NOT EXISTS(SELECT 1 FROM t_exam_answer a WHERE a.ean_question_id=q.eqs_id);
  DELETE st FROM t_survey_template st WHERE st.svt_name='【演示数据】面试体验验收' AND st.svt_company_id IN(1,2)
    AND NOT EXISTS(SELECT 1 FROM t_survey_response r WHERE r.svr_template_id=st.svt_id)
    AND NOT EXISTS(SELECT 1 FROM t_survey_dispatch d WHERE d.svd_template_id=st.svt_id);
  DELETE m FROM t_msg m WHERE m.msg_title IN('【演示数据】全流程验收数据已就绪','【演示数据】改期通知展示样例','【演示数据】报告与Offer展示样例')
    AND m.msg_content IN('【演示数据】岗位、候选人、六阶段流程、已完成报告与未来排期均为合成验收数据，不是真实招聘。',
      '【演示数据】此条仅展示通知格式，不代表后端已实现自动改期通知；请按代码实际能力验收。',
      '【演示数据】预置面试总结、笔试成绩及Offer审批，不是实时AI分析或对真实候选人的要约。');
  COMMIT;
  DO RELEASE_LOCK('eapp_acceptance_20261020');
  SELECT 'Only acknowledged synthetic fixture removed' AS result;
END$$
DELIMITER ;
CALL __eapp_fixture_cleanup_20261020();
DROP PROCEDURE __eapp_fixture_cleanup_20261020;
SET @eapp_fixture_cleanup_enabled=0;
SET @eapp_fixture_cleanup_ack=NULL;


-- ============================================================
-- [追加] 2026-10-20：本次最终数据库验收结果（仅记录，不执行）
-- ============================================================
-- 服务器新增：8个禁用无角色虚拟用户/8份简历、16个企业候选人、10个演示岗位、24阶段，
-- 46条预约（36已完成、6未来有效、其余过期/取消）、36会话/36逐轮评估报告，
-- 6聊天会话/18消息、4份笔试结果、4份Offer、2份问卷答复；均有明确演示标记。
-- 当前Mapper实际SELECT只读兼容检查108条全部通过，所有声明外键128项无孤儿；
-- 进度指针/岗位企业/阶段/报告身份/未来时段占用/新增有效预约冲突检查均为0异常。
-- 演示岗位更新、技能写入、通知写入/已读在事务中验证成功并回滚，未保留临时校验行。
-- C节幂等复跑返回ALREADY_PRESENT，所有验收统计一致，未重置已读或模拟用户编辑。
-- 旧演示精确清理匹配0、删除0；未删除未标记来源的数据或“测试开发工程师”职业岗位。
-- 初期指纹核实原99张单主键表记录无变化；最终有外部并发菜单新增和账号登录信息变化，
-- 未触碰/回滚这些并发数据。恢复时不得整库覆盖，应按精确演示标记审阅关联关系。
-- 六个业务触发器仍因ERROR 1419未创建，需要DBA执行A节；本次未放宽全局日志安全策略。
-- 默认关闭的清理段已验证语法且未执行删除；临时迁移存储过程均已移除。
-- 服务器/prod-api/captchaImage可用；APP当前默认仍指向模拟器宿主机，不自动切换服务器。
-- 本机数据库仅只读比较，无本机清理/插入；无后端或Flutter业务代码变更，未提交/推送。

-- ============================================================================
-- 2026-10-20 企业端真实AI筛选与雷达图分析
-- 来源：用户要求接入已配置模型，综合评估经历并生成简短推荐理由
-- 范围：仅新增本模块任务与结果表，不改原人才/岗位/招呼语结构；不预填AI分数
-- 幂等：CREATE TABLE IF NOT EXISTS；JSON评分由真实模型响应校验后写入
-- 回滚：停止筛选后台任务并回退本模块代码后，可删除以下两张专用表（会丢失本模块报告）
-- 不得执行整个new.sql；本段可独立执行。无全局配置或权限变更。
-- ============================================================================
CREATE TABLE IF NOT EXISTS t_ai_screening_task (
    ast_company_id BIGINT NOT NULL,
    ast_position_id BIGINT NOT NULL,
    ast_run_id VARCHAR(36) NOT NULL,
    ast_state VARCHAR(20) NOT NULL DEFAULT 'idle',
    ast_candidate_count INT NOT NULL DEFAULT 0,
    ast_completed_count INT NOT NULL DEFAULT 0,
    ast_passed_count INT NOT NULL DEFAULT 0,
    ast_error VARCHAR(500) DEFAULT NULL,
    ast_updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ast_company_id, ast_position_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='企业AI筛选任务与进度';

CREATE TABLE IF NOT EXISTS t_ai_screening_result (
    asr_company_id BIGINT NOT NULL,
    asr_position_id BIGINT NOT NULL,
    asr_candidate_id BIGINT NOT NULL,
    asr_resume_id BIGINT DEFAULT NULL,
    asr_report JSON NOT NULL,
    asr_updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (asr_company_id, asr_position_id, asr_candidate_id),
    KEY idx_asr_candidate_updated (asr_company_id, asr_candidate_id, asr_updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='岗位候选人真实AI匹配报告';
-- 仅在确认清除该模块结果时人工执行回滚：
-- DROP TABLE t_ai_screening_result;
-- DROP TABLE t_ai_screening_task;

-- ============================================================================
-- 服务器AI筛选迁移执行确认与连接配置（2026-10-20）
-- 来源：用户明确授权检查服务器数据库权限、创建AI分析表并修改后端连接配置
-- 执行范围：仅执行上方两张AI专用表的CREATE TABLE IF NOT EXISTS，未执行整个new.sql
-- 执行结果：服务器已创建t_ai_screening_task、t_ai_screening_result；结构与索引核验通过
-- 幂等验证：同一独立迁移重复执行成功；原有业务表、资料和演示数据未删除或覆盖
-- 权限验证：连接启用TLS；账号具备本迁移所需CREATE及日常查询/写入权限
-- 数据验证：两表事务内插入/更新验证后ROLLBACK，未遗留权限验证或伪造的AI报告
-- 备份：执行DDL前完成本地私有全库备份，保存在backend/doc/backup/（禁止提交）
-- 备份校验SHA256：b14b9852ac12c62b4c971d12a0cc878483172172e5f67e76cf1cdccbb7584e5f
-- 连接配置：本机application-druid.yml主库改为服务器，JDBC要求TLS；原配置已私有备份
-- 凭据只保留在被Git忽略的本地配置中，本SQL不记录用户名、密码或其他秘密
-- 边界：本次数据库迁移和本机配置调整不代表公网后端程序已部署或重启
-- 回滚：本机连接配置可由私有备份恢复；数据库表回滚仍遵循上方人工回滚说明
-- ============================================================================

-- 服务器AI筛选迁移后Java验证结果（2026-10-20）
-- 27项常规/数据库验证通过；实际MyBatis SELECT、JSON写入、进度更新及事务回滚访问服务器数据库
-- 字段类型/默认值/可空约束/主键/索引与本机预期结构一致；本轮未重复调用大模型
-- 两张AI表最终无测试遗留记录，真实分析报告待新版后端任务运行后生成


-- ============================================================================
-- 2026-10-21 企业端增量独立评分（仅独立执行本段，不执行整份历史脚本）
-- 默认增量：按企业+岗位+求职者去重；有记录（含资料不足/空分）的求职者不重复调用模型。
-- 全量：显式 fullAnalysis=true，逐人覆盖；每位求职者结果与进度独立事务提交。
-- 新增求职者不会因刷新/GET自动调用模型，须点击AI辅助筛选；支持后续增量补齐。
-- 无其他求职者简历/排名/分数进入模型输入；一条请求仅一份简历与岗位要求。
-- 不复制旧 t_ai_screening_result 的批量评分，避免误标为独立评分；旧表原样保留。
-- 读接口仅使用新独立评分表；旧批量评分不可证明未做横向比较，不继续作为独立AI结果展示。
-- 不改任何现有业务表或权限，不预填/伪造AI分数；已有两表结构不变。
-- 幂等：IF NOT EXISTS；新表已有记录不覆盖。首轮增量将对未有独立记录者逐人分析。
CREATE TABLE IF NOT EXISTS t_ai_candidate_analysis (
    asr_company_id BIGINT NOT NULL COMMENT '企业ID',
    asr_position_id BIGINT NOT NULL COMMENT '岗位ID',
    asr_candidate_id BIGINT NOT NULL COMMENT '求职者人才ID',
    asr_resume_id BIGINT DEFAULT NULL COMMENT '分析使用的简历ID',
    asr_report JSON NOT NULL COMMENT '独立六维评分、证据、推荐理由及版本信息',
    asr_updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '最近分析时间',
    PRIMARY KEY (asr_company_id, asr_position_id, asr_candidate_id),
    KEY idx_aca_candidate_updated (asr_company_id, asr_candidate_id, asr_updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='求职者与岗位独立AI匹配结果';
-- 回滚：先停止筛选任务、回退本模块代码；旧批量表内容未修改。
-- 只有确认不再需要新结果时才人工执行：DROP TABLE t_ai_candidate_analysis;
-- 结果保存按人提交：中途失败保留已完成结果，增量重试不重复分析已完成者。
-- 全量中途失败同样保留已完成的新结果，其余人的旧独立结果不变；再次全量可重算全部。
-- 岗位/已有简历更新不自动重算；需主动选择全量分析。刷新为纯数据库读取。

-- 2026-10-21 增量筛选交互与评分口径调整（仅行为记录，本段无DDL/DML）
-- 默认优先读取现有记录；已有结果（即使简历更新）不会自动调用模型，手动全量才重算。
-- 点击增量先GET读取缓存再补齐缺少结果者，进入页面自动GET，不自动分析。
-- 缺少材料的维度记0，综合分按固定六维权重计算；历史报告在GET时归一化，不写库、不调用模型。
-- 内嵌下拉菜单保留全量分析与耗时确认；移除求职者页独立刷新按钮。
