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
