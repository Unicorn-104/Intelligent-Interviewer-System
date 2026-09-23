-- ============================================================================
-- 冲突表迁移脚本：t_* -> 若依框架表 sys_*
-- 数据库: recruit_agent
-- 说明:
--   1. 给 sys_user / sys_config / sys_oper_log 补充设计文档独有字段
--   2. 数据迁移 (ID 映射: aut_id+100 -> user_id, rol_id+100 -> role_id, prm_id+2000 -> menu_id)
--   3. 业务表外键从 t_usr_auth 重指向 sys_user
--   4. 删除冲突表 t_usr_auth / t_usr_profile / t_role / t_permission /
--      t_role_permission / t_user_role / t_sys_config / t_sys_dict / t_log_audit
--   5. 密码统一重置为 admin123 (bcrypt)
-- ============================================================================

USE recruit_agent;

SET NAMES utf8mb4;

-- ----------------------------------------------------------------------------
-- 一、补充字段
-- ----------------------------------------------------------------------------

-- 1. sys_user 补充 t_usr_auth + t_usr_profile 独有字段
ALTER TABLE sys_user
  ADD COLUMN user_identity_type tinyint DEFAULT NULL COMMENT '用户身份：1-求职者(C端)，2-HR(B端)，3-管理员' AFTER user_type,
  ADD COLUMN mfa_enabled tinyint DEFAULT 0 COMMENT '是否启用MFA：0-否，1-是' AFTER user_identity_type,
  ADD COLUMN real_name varchar(50) DEFAULT NULL COMMENT '真实姓名' AFTER user_name,
  ADD COLUMN birth_date date DEFAULT NULL COMMENT '出生日期' AFTER sex,
  ADD COLUMN current_city varchar(50) DEFAULT NULL COMMENT '当前所在城市' AFTER avatar,
  ADD COLUMN hometown varchar(50) DEFAULT NULL COMMENT '籍贯' AFTER current_city,
  ADD COLUMN current_status tinyint DEFAULT NULL COMMENT '职业状态：1-在职，2-离职，3-应届生' AFTER hometown,
  ADD COLUMN target_direction varchar(100) DEFAULT NULL COMMENT '期望岗位方向' AFTER current_status,
  ADD COLUMN target_city varchar(50) DEFAULT NULL COMMENT '期望工作城市' AFTER target_direction,
  ADD COLUMN show_phone tinyint DEFAULT 0 COMMENT '是否对外显示手机号：0-隐藏，1-显示' AFTER target_city,
  ADD COLUMN ui_theme varchar(10) DEFAULT 'light' COMMENT 'UI主题：dark/light/auto' AFTER show_phone;

-- 1b. sys_user 加宽字段：容纳设计文档更大长度 + bcrypt 密码(60字符)
ALTER TABLE sys_user
  MODIFY login_name varchar(50) NOT NULL COMMENT '登录账号',
  MODIFY user_name varchar(50) DEFAULT '' COMMENT '用户昵称',
  MODIFY email varchar(100) DEFAULT '' COMMENT '用户邮箱',
  MODIFY phonenumber varchar(20) DEFAULT '' COMMENT '手机号码',
  MODIFY avatar varchar(255) DEFAULT '' COMMENT '头像路径',
  MODIFY password varchar(255) DEFAULT '' COMMENT '密码';

-- 2. sys_config 补充 t_sys_config 独有字段
ALTER TABLE sys_config
  ADD COLUMN value_type tinyint DEFAULT NULL COMMENT '值类型：1-string，2-number，3-json，4-boolean' AFTER config_type,
  ADD COLUMN config_group varchar(50) DEFAULT NULL COMMENT '配置分组' AFTER value_type;

-- 3. sys_oper_log 补充 t_log_audit 独有字段
ALTER TABLE sys_oper_log
  ADD COLUMN aud_user_id bigint DEFAULT NULL COMMENT '操作人用户ID，关联 sys_user.user_id' AFTER operator_type,
  ADD COLUMN aud_log_type tinyint DEFAULT NULL COMMENT '日志类型：1-登录，2-操作，3-接口，4-AI调用，5-数据访问审计' AFTER aud_user_id,
  ADD COLUMN aud_action varchar(30) DEFAULT NULL COMMENT '操作类型' AFTER aud_log_type,
  ADD COLUMN aud_object_type varchar(50) DEFAULT NULL COMMENT '操作对象类型' AFTER aud_action,
  ADD COLUMN aud_object_id bigint DEFAULT NULL COMMENT '操作对象ID' AFTER aud_object_type,
  ADD COLUMN aud_detail json DEFAULT NULL COMMENT '变更详情JSON' AFTER aud_object_id;

-- ----------------------------------------------------------------------------
-- 二、数据迁移
-- ----------------------------------------------------------------------------

-- 4. t_role -> sys_role (rol_id + 100)
INSERT INTO sys_role (role_id, role_name, role_key, role_sort, data_scope, status, del_flag, create_by, create_time, update_by, update_time, remark)
SELECT rol_id + 100,
       rol_name,
       CONCAT('biz_', rol_id),
       rol_id,
       '1',
       CASE WHEN rol_status = 1 THEN '0' ELSE '1' END,
       '0',
       'admin', rol_created_at, '', rol_updated_at, rol_description
FROM t_role;

-- 5. t_permission -> sys_menu (prm_id + 2000)
INSERT INTO sys_menu (menu_id, menu_name, parent_id, order_num, url, target, menu_type, visible, is_refresh, perms, icon, create_by, create_time, update_by, update_time, remark)
SELECT prm_id + 2000,
       prm_name,
       CASE WHEN prm_parent_id IS NULL OR prm_parent_id = 0 THEN 0 ELSE prm_parent_id + 2000 END,
       0, '#', '',
       CASE WHEN prm_type = 1 AND (prm_parent_id IS NULL OR prm_parent_id = 0) THEN 'M'
            WHEN prm_type = 1 THEN 'C'
            ELSE 'F' END,
       '0', '1', prm_code, '#', 'admin', prm_created_at, '', prm_updated_at, ''
FROM t_permission;

-- 6. t_usr_auth + t_usr_profile -> sys_user (aut_id + 100, 密码重置 admin123)
INSERT INTO sys_user (user_id, dept_id, login_name, user_name, user_type, email, phonenumber, sex, avatar, password, salt, status, del_flag, login_ip, login_date, pwd_update_date, create_by, create_time, update_by, update_time, remark, user_identity_type, mfa_enabled, real_name, birth_date, current_city, hometown, current_status, target_direction, target_city, show_phone, ui_theme)
SELECT a.aut_id + 100,
       NULL,
       a.aut_username,
       COALESCE(p.prf_nickname, a.aut_username),
       CASE WHEN a.aut_type = 3 THEN '00' ELSE '01' END,
       a.aut_email,
       a.aut_phone,
       CASE p.prf_gender WHEN 1 THEN '0' WHEN 2 THEN '1' ELSE '2' END,
       p.prf_avatar_url,
       '$2b$10$V66fXHpCemv8NXjXUz8wm.8LBuII3uh6Z9A9RePlJ3NPlB//QuYlW',
       '',
       CASE WHEN a.aut_status = 1 THEN '0' ELSE '1' END,
       '0',
       a.aut_last_login_ip,
       a.aut_last_login_at,
       NULL,
       'admin', a.aut_created_at, '', a.aut_updated_at, NULL,
       a.aut_type,
       a.aut_mfa_enabled,
       p.prf_real_name,
       p.prf_birth_date,
       p.prf_current_city,
       p.prf_hometown,
       p.prf_current_status,
       p.prf_target_direction,
       p.prf_target_city,
       p.prf_show_phone,
       p.prf_ui_theme
FROM t_usr_auth a
LEFT JOIN t_usr_profile p ON p.prf_user_id = a.aut_id;

-- 7. t_sys_config -> sys_config
INSERT INTO sys_config (config_name, config_key, config_value, config_type, create_by, create_time, update_by, update_time, remark, value_type, config_group)
SELECT COALESCE(cfg_description, cfg_key),
       cfg_key,
       cfg_value,
       'N',
       'admin', cfg_created_at, '', cfg_updated_at, cfg_description,
       cfg_type,
       cfg_group
FROM t_sys_config;

-- 8. t_sys_dict -> sys_dict_type + sys_dict_data
INSERT INTO sys_dict_type (dict_name, dict_type, status, create_by, create_time, update_by, update_time, remark)
SELECT dct_type, dct_type, '0', 'admin', MIN(dct_created_at), '', MAX(dct_updated_at), ''
FROM t_sys_dict
GROUP BY dct_type;

INSERT INTO sys_dict_data (dict_sort, dict_label, dict_value, dict_type, css_class, list_class, is_default, status, create_by, create_time, update_by, update_time, remark)
SELECT dct_sort_order, dct_value, dct_key, dct_type, '', '', 'N',
       CASE WHEN dct_status = 1 THEN '0' ELSE '1' END,
       'admin', dct_created_at, '', dct_updated_at, ''
FROM t_sys_dict;

-- 9. t_user_role -> sys_user_role (ID 重映射)
INSERT INTO sys_user_role (user_id, role_id)
SELECT uro_user_id + 100, uro_role_id + 100
FROM t_user_role;

-- 10. t_role_permission -> sys_role_menu (ID 重映射)
INSERT INTO sys_role_menu (role_id, menu_id)
SELECT rlp_role_id + 100, rlp_permission_id + 2000
FROM t_role_permission;

-- 11. t_log_audit -> sys_oper_log
INSERT INTO sys_oper_log (title, business_type, method, request_method, operator_type, oper_name, dept_name, oper_url, oper_ip, oper_location, oper_param, json_result, status, error_msg, oper_time, cost_time, aud_user_id, aud_log_type, aud_action, aud_object_type, aud_object_id, aud_detail)
SELECT COALESCE(aud_object_type, aud_action),
       0, '', '', 1, '', '', '', aud_ip, '', '', CAST(aud_detail AS CHAR),
       CASE WHEN aud_result = 1 THEN 0 ELSE 1 END,
       '', aud_created_at, 0,
       CASE WHEN aud_user_id > 0 THEN aud_user_id + 100 ELSE NULL END,
       aud_log_type, aud_action, aud_object_type, aud_object_id, aud_detail
FROM t_log_audit;

-- ----------------------------------------------------------------------------
-- 三、业务表外键重指向 sys_user (aut_id + 100)
-- ----------------------------------------------------------------------------

-- t_usr_device
ALTER TABLE t_usr_device DROP FOREIGN KEY fk_dev_user_id;
UPDATE t_usr_device SET dev_user_id = dev_user_id + 100 WHERE dev_user_id > 0;
ALTER TABLE t_usr_device ADD CONSTRAINT fk_dev_user_id FOREIGN KEY (dev_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_usr_cancel
ALTER TABLE t_usr_cancel DROP FOREIGN KEY fk_can_user_id;
UPDATE t_usr_cancel SET can_user_id = can_user_id + 100 WHERE can_user_id > 0;
ALTER TABLE t_usr_cancel ADD CONSTRAINT fk_can_user_id FOREIGN KEY (can_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_usr_verify
ALTER TABLE t_usr_verify DROP FOREIGN KEY fk_vef_user_id;
UPDATE t_usr_verify SET vef_user_id = vef_user_id + 100 WHERE vef_user_id > 0;
ALTER TABLE t_usr_verify ADD CONSTRAINT fk_vef_user_id FOREIGN KEY (vef_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_msg_preference
ALTER TABLE t_msg_preference DROP FOREIGN KEY fk_prf_user_id_msg;
UPDATE t_msg_preference SET prf_user_id = prf_user_id + 100 WHERE prf_user_id > 0;
ALTER TABLE t_msg_preference ADD CONSTRAINT fk_prf_user_id_msg FOREIGN KEY (prf_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_usr_interest
ALTER TABLE t_usr_interest DROP FOREIGN KEY fk_int_user_id;
UPDATE t_usr_interest SET int_user_id = int_user_id + 100 WHERE int_user_id > 0;
ALTER TABLE t_usr_interest ADD CONSTRAINT fk_int_user_id FOREIGN KEY (int_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_cmp_binding
ALTER TABLE t_cmp_binding DROP FOREIGN KEY fk_bnd_user_id;
UPDATE t_cmp_binding SET bnd_user_id = bnd_user_id + 100 WHERE bnd_user_id > 0;
ALTER TABLE t_cmp_binding ADD CONSTRAINT fk_bnd_user_id FOREIGN KEY (bnd_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_res_base
ALTER TABLE t_res_base DROP FOREIGN KEY fk_rbs_user_id;
UPDATE t_res_base SET rbs_user_id = rbs_user_id + 100 WHERE rbs_user_id > 0;
ALTER TABLE t_res_base ADD CONSTRAINT fk_rbs_user_id FOREIGN KEY (rbs_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_pos
ALTER TABLE t_pos DROP FOREIGN KEY fk_pos_publisher_id;
UPDATE t_pos SET pos_publisher_id = pos_publisher_id + 100 WHERE pos_publisher_id > 0;
ALTER TABLE t_pos ADD CONSTRAINT fk_pos_publisher_id FOREIGN KEY (pos_publisher_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_tal
ALTER TABLE t_tal DROP FOREIGN KEY fk_tal_user_id;
UPDATE t_tal SET tal_user_id = tal_user_id + 100 WHERE tal_user_id > 0;
ALTER TABLE t_tal ADD CONSTRAINT fk_tal_user_id FOREIGN KEY (tal_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_sch_slot
ALTER TABLE t_sch_slot DROP FOREIGN KEY fk_slt_interviewer_id;
UPDATE t_sch_slot SET slt_interviewer_id = slt_interviewer_id + 100 WHERE slt_interviewer_id > 0;
ALTER TABLE t_sch_slot ADD CONSTRAINT fk_slt_interviewer_id FOREIGN KEY (slt_interviewer_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_sch_appointment
ALTER TABLE t_sch_appointment DROP FOREIGN KEY fk_apt_interviewer_id;
UPDATE t_sch_appointment SET apt_interviewer_id = apt_interviewer_id + 100 WHERE apt_interviewer_id > 0;
ALTER TABLE t_sch_appointment ADD CONSTRAINT fk_apt_interviewer_id FOREIGN KEY (apt_interviewer_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_int_session
ALTER TABLE t_int_session DROP FOREIGN KEY fk_ses_interviewer_id;
UPDATE t_int_session SET ses_interviewer_id = ses_interviewer_id + 100 WHERE ses_interviewer_id > 0;
ALTER TABLE t_int_session ADD CONSTRAINT fk_ses_interviewer_id FOREIGN KEY (ses_interviewer_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_im_session (user_a)
ALTER TABLE t_im_session DROP FOREIGN KEY fk_ims_user_a;
UPDATE t_im_session SET ims_user_a_id = ims_user_a_id + 100 WHERE ims_user_a_id > 0;
ALTER TABLE t_im_session ADD CONSTRAINT fk_ims_user_a FOREIGN KEY (ims_user_a_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_im_session (user_b)
ALTER TABLE t_im_session DROP FOREIGN KEY fk_ims_user_b;
UPDATE t_im_session SET ims_user_b_id = ims_user_b_id + 100 WHERE ims_user_b_id > 0;
ALTER TABLE t_im_session ADD CONSTRAINT fk_ims_user_b FOREIGN KEY (ims_user_b_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_ai_chat_session
ALTER TABLE t_ai_chat_session DROP FOREIGN KEY fk_acs_user_id;
UPDATE t_ai_chat_session SET acs_user_id = acs_user_id + 100 WHERE acs_user_id > 0;
ALTER TABLE t_ai_chat_session ADD CONSTRAINT fk_acs_user_id FOREIGN KEY (acs_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_fbk
ALTER TABLE t_fbk DROP FOREIGN KEY fk_fbk_user_id;
UPDATE t_fbk SET fbk_user_id = fbk_user_id + 100 WHERE fbk_user_id > 0;
ALTER TABLE t_fbk ADD CONSTRAINT fk_fbk_user_id FOREIGN KEY (fbk_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_msg
ALTER TABLE t_msg DROP FOREIGN KEY fk_msg_receiver_id;
UPDATE t_msg SET msg_receiver_id = msg_receiver_id + 100 WHERE msg_receiver_id > 0;
ALTER TABLE t_msg ADD CONSTRAINT fk_msg_receiver_id FOREIGN KEY (msg_receiver_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_process_audit
ALTER TABLE t_process_audit DROP FOREIGN KEY fk_pau_operator_id;
UPDATE t_process_audit SET pau_operator_id = pau_operator_id + 100 WHERE pau_operator_id > 0;
ALTER TABLE t_process_audit ADD CONSTRAINT fk_pau_operator_id FOREIGN KEY (pau_operator_id) REFERENCES sys_user(user_id) ON DELETE SET NULL;

-- t_agent_manual_takeover
ALTER TABLE t_agent_manual_takeover DROP FOREIGN KEY fk_amt_takeover_by;
UPDATE t_agent_manual_takeover SET amt_takeover_by = amt_takeover_by + 100 WHERE amt_takeover_by > 0;
ALTER TABLE t_agent_manual_takeover ADD CONSTRAINT fk_amt_takeover_by FOREIGN KEY (amt_takeover_by) REFERENCES sys_user(user_id) ON DELETE SET NULL;

-- t_ai_review
ALTER TABLE t_ai_review DROP FOREIGN KEY fk_air_reviewer_id;
UPDATE t_ai_review SET air_reviewer_id = air_reviewer_id + 100 WHERE air_reviewer_id > 0;
ALTER TABLE t_ai_review ADD CONSTRAINT fk_air_reviewer_id FOREIGN KEY (air_reviewer_id) REFERENCES sys_user(user_id) ON DELETE SET NULL;

-- t_permission_change_log
ALTER TABLE t_permission_change_log DROP FOREIGN KEY fk_pcl_operator_id;
UPDATE t_permission_change_log SET pcl_operator_id = pcl_operator_id + 100 WHERE pcl_operator_id > 0;
ALTER TABLE t_permission_change_log ADD CONSTRAINT fk_pcl_operator_id FOREIGN KEY (pcl_operator_id) REFERENCES sys_user(user_id) ON DELETE SET NULL ON UPDATE CASCADE;

-- t_usr_mfa
ALTER TABLE t_usr_mfa DROP FOREIGN KEY fk_umf_user_id;
UPDATE t_usr_mfa SET umf_user_id = umf_user_id + 100 WHERE umf_user_id > 0;
ALTER TABLE t_usr_mfa ADD CONSTRAINT fk_umf_user_id FOREIGN KEY (umf_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_usr_session
ALTER TABLE t_usr_session DROP FOREIGN KEY fk_uss_user_id;
UPDATE t_usr_session SET uss_user_id = uss_user_id + 100 WHERE uss_user_id > 0;
ALTER TABLE t_usr_session ADD CONSTRAINT fk_uss_user_id FOREIGN KEY (uss_user_id) REFERENCES sys_user(user_id) ON DELETE CASCADE;

-- t_offer_approval
ALTER TABLE t_offer_approval DROP FOREIGN KEY fk_oap_approver_id;
UPDATE t_offer_approval SET oap_approver_id = oap_approver_id + 100 WHERE oap_approver_id > 0;
ALTER TABLE t_offer_approval ADD CONSTRAINT fk_oap_approver_id FOREIGN KEY (oap_approver_id) REFERENCES sys_user(user_id) ON DELETE SET NULL;

-- t_onboarding
ALTER TABLE t_onboarding DROP FOREIGN KEY fk_obd_owner_id;
UPDATE t_onboarding SET obd_owner_id = obd_owner_id + 100 WHERE obd_owner_id > 0;
ALTER TABLE t_onboarding ADD CONSTRAINT fk_obd_owner_id FOREIGN KEY (obd_owner_id) REFERENCES sys_user(user_id) ON DELETE SET NULL;

-- ----------------------------------------------------------------------------
-- 四、软引用列重映射（无外键约束，仅更新值）
-- ----------------------------------------------------------------------------

UPDATE t_cmp SET cmp_verify_by = cmp_verify_by + 100 WHERE cmp_verify_by > 0;
UPDATE t_cmp_binding SET bnd_audit_by = bnd_audit_by + 100 WHERE bnd_audit_by > 0;
UPDATE t_tal_status_log SET tsl_operator_id = tsl_operator_id + 100 WHERE tsl_operator_id > 0;
UPDATE t_int_score SET scr_scorer_id = scr_scorer_id + 100 WHERE scr_scorer_id > 0;
UPDATE t_im_message SET imsg_sender_id = imsg_sender_id + 100 WHERE imsg_sender_id > 0;
UPDATE t_msg SET msg_sender_id = msg_sender_id + 100 WHERE msg_sender_id > 0;
UPDATE t_process_instance_stage SET pis_operator_id = pis_operator_id + 100 WHERE pis_operator_id > 0;

-- ----------------------------------------------------------------------------
-- 五、删除冲突表
-- ----------------------------------------------------------------------------

DROP TABLE IF EXISTS t_role_permission;
DROP TABLE IF EXISTS t_user_role;
DROP TABLE IF EXISTS t_usr_profile;
DROP TABLE IF EXISTS t_log_audit;
DROP TABLE IF EXISTS t_permission;
DROP TABLE IF EXISTS t_role;
DROP TABLE IF EXISTS t_usr_auth;
DROP TABLE IF EXISTS t_sys_config;
DROP TABLE IF EXISTS t_sys_dict;

-- ----------------------------------------------------------------------------
-- 六、修正自增值，避免与迁移后的新 ID 冲突
-- ----------------------------------------------------------------------------

ALTER TABLE sys_user AUTO_INCREMENT = 200;
ALTER TABLE sys_role AUTO_INCREMENT = 200;
ALTER TABLE sys_menu AUTO_INCREMENT = 2100;
ALTER TABLE sys_config AUTO_INCREMENT = 200;
ALTER TABLE sys_dict_type AUTO_INCREMENT = 200;
ALTER TABLE sys_dict_data AUTO_INCREMENT = 200;

-- ----------------------------------------------------------------------------
-- 七、修正若依自带 admin/ry 的密码（官方脚本是 MD5，本工程用 BCrypt）
-- ----------------------------------------------------------------------------

UPDATE sys_user SET password = '$2b$10$V66fXHpCemv8NXjXUz8wm.8LBuII3uh6Z9A9RePlJ3NPlB//QuYlW' WHERE user_id IN (1, 2);
