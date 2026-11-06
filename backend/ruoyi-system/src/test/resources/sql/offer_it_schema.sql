-- ============================================================================
-- OfferServiceConcurrencyIT · 最小建表脚本（仅在一次性 Testcontainers MySQL8 容器内执行）
-- 本轮“只准备不执行”：本脚本不连接任何持久化库，不修改原 it_schema.sql。
-- 每个字段均来自对应 Mapper XML 中真实出现的列；未在 Offer 链出现的列不纳入。
-- ============================================================================

DROP TABLE IF EXISTS t_msg;
DROP TABLE IF EXISTS t_tal_status_log;
DROP TABLE IF EXISTS t_app_status_log;
DROP TABLE IF EXISTS t_process_instance_stage;
DROP TABLE IF EXISTS t_off_offer;
DROP TABLE IF EXISTS t_cmp_binding;
DROP TABLE IF EXISTS t_cmp;
DROP TABLE IF EXISTS t_process_instance;
DROP TABLE IF EXISTS t_app_record;
DROP TABLE IF EXISTS t_pos;
DROP TABLE IF EXISTS sys_user;
DROP TABLE IF EXISTS t_tal;

-- 岗位（selectOfferById 经 t_pos 做企业隔离过滤，最小列）
CREATE TABLE t_pos (
    pos_id bigint NOT NULL AUTO_INCREMENT,
    pos_title varchar(100) NOT NULL,
    pos_company_id bigint NOT NULL,
    PRIMARY KEY (pos_id),
    KEY idx_pos_company (pos_company_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 系统用户（selectOfferById 等 LEFT JOIN 取昵称/邮箱，最小列）
CREATE TABLE sys_user (
    user_id bigint NOT NULL AUTO_INCREMENT,
    nick_name varchar(30) NOT NULL,
    email varchar(100) DEFAULT NULL,
    PRIMARY KEY (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 岗位投递（六态主表）
CREATE TABLE t_app_record (
    app_id bigint NOT NULL AUTO_INCREMENT COMMENT '投递ID',
    app_candidate_id bigint NOT NULL,
    app_position_id bigint NOT NULL,
    app_resume_id bigint DEFAULT NULL,
    app_process_instance_id bigint DEFAULT NULL,
    app_matched_score decimal(5,2) DEFAULT NULL,
    app_status tinyint NOT NULL DEFAULT 0 COMMENT '0已投递 1招聘中 2待发Offer 3待确认Offer 4已录用 5未录用',
    end_reason varchar(40) DEFAULT NULL,
    ended_at datetime DEFAULT NULL,
    ended_by bigint DEFAULT NULL,
    end_remark varchar(500) DEFAULT NULL,
    app_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    app_updated_at datetime DEFAULT NULL,
    PRIMARY KEY (app_id),
    KEY idx_app_candidate_position (app_candidate_id, app_position_id),
    KEY idx_app_end_reason (end_reason)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 投递状态变更日志（ApplicationStatusService 写入）
CREATE TABLE t_app_status_log (
    asl_id bigint NOT NULL AUTO_INCREMENT,
    asl_app_id bigint NOT NULL,
    asl_candidate_id bigint NOT NULL,
    asl_position_id bigint NOT NULL,
    asl_from_status tinyint DEFAULT NULL,
    asl_to_status tinyint NOT NULL,
    asl_operator_id bigint DEFAULT NULL,
    asl_source varchar(30) NOT NULL,
    asl_reason varchar(500) DEFAULT NULL,
    asl_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (asl_id),
    KEY idx_asl_app (asl_app_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 流程实例（状态机收尾：pin_status 0进行中 1完成 2终止 3淘汰）
CREATE TABLE t_process_instance (
    pin_id bigint NOT NULL AUTO_INCREMENT,
    pin_candidate_id bigint NOT NULL,
    pin_position_id bigint NOT NULL,
    pin_status tinyint NOT NULL DEFAULT 0,
    pin_start_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    pin_end_at datetime DEFAULT NULL,
    pin_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (pin_id),
    KEY idx_pin_candidate_position (pin_candidate_id, pin_position_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 流程节点（保留最小定义，供后续扩展；Offer 接受/过期主链不直接写此表）
CREATE TABLE t_process_instance_stage (
    pis_id bigint NOT NULL AUTO_INCREMENT,
    pis_instance_id bigint NOT NULL,
    pis_stage_id bigint DEFAULT NULL,
    pis_node_type tinyint DEFAULT NULL,
    pis_round int DEFAULT NULL,
    pis_status tinyint NOT NULL DEFAULT 0,
    pis_result tinyint DEFAULT NULL,
    pis_ref_id bigint DEFAULT NULL,
    pis_node_name varchar(100) DEFAULT NULL,
    pis_operator_id bigint DEFAULT NULL,
    pis_start_at datetime DEFAULT NULL,
    pis_end_at datetime DEFAULT NULL,
    pis_result_note varchar(500) DEFAULT NULL,
    pis_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (pis_id),
    KEY idx_pis_instance (pis_instance_id, pis_status),
    KEY idx_pis_ref (pis_ref_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 候选人/人才（全局 tal_status 状态机主表）
CREATE TABLE t_tal (
    tal_id bigint NOT NULL AUTO_INCREMENT,
    tal_user_id bigint DEFAULT NULL,
    tal_company_id bigint DEFAULT NULL,
    tal_resume_id bigint DEFAULT NULL,
    tal_status tinyint NOT NULL DEFAULT 0 COMMENT '0新入库 1初筛通过 2面试中 3已淘汰 4已录用 5待笔试 6笔试中 7笔试通过 8笔试未通过 9笔试缺考 10待发Offer',
    tal_process_instance_id bigint DEFAULT NULL,
    tal_exam_record_id bigint DEFAULT NULL,
    tal_matched_score decimal(5,2) DEFAULT NULL,
    tal_archive_source tinyint DEFAULT NULL,
    tal_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tal_updated_at datetime DEFAULT NULL,
    PRIMARY KEY (tal_id),
    KEY idx_tal_user (tal_user_id),
    KEY idx_tal_company (tal_company_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 候选人全局状态变更日志（TalStatusService 写入）
CREATE TABLE t_tal_status_log (
    tsl_id bigint NOT NULL AUTO_INCREMENT,
    tsl_candidate_id bigint NOT NULL,
    tsl_from_status tinyint DEFAULT NULL,
    tsl_to_status tinyint NOT NULL,
    tsl_reason varchar(500) DEFAULT NULL,
    tsl_operator_id bigint DEFAULT NULL,
    PRIMARY KEY (tsl_id),
    KEY idx_tsl_candidate (tsl_candidate_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Offer 主表（ofr_status：0已发送 1已接受 2已拒绝 3已过期 4草稿 5审批中 6已撤回）
CREATE TABLE t_off_offer (
    ofr_id bigint NOT NULL AUTO_INCREMENT,
    ofr_candidate_id bigint NOT NULL,
    ofr_position_id bigint NOT NULL,
    ofr_salary_offer varchar(50) DEFAULT NULL,
    ofr_benefits varchar(500) DEFAULT NULL,
    ofr_job_grade varchar(50) DEFAULT NULL,
    ofr_status tinyint NOT NULL DEFAULT 4,
    ofr_approval_status tinyint DEFAULT 0,
    ofr_offer_url varchar(255) DEFAULT NULL,
    ofr_onboard_date date DEFAULT NULL,
    ofr_deadline datetime DEFAULT NULL,
    ofr_withdraw_reason varchar(500) DEFAULT NULL,
    ofr_withdraw_at datetime DEFAULT NULL,
    ofr_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ofr_id),
    KEY idx_ofr_candidate_position (ofr_candidate_id, ofr_position_id),
    KEY idx_ofr_status_deadline (ofr_status, ofr_deadline)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 企业（selectCompanyName/selectCompanyEmail；本测试可空表）
CREATE TABLE t_cmp (
    cmp_id bigint NOT NULL AUTO_INCREMENT,
    cmp_name varchar(100) NOT NULL,
    cmp_email varchar(100) DEFAULT NULL,
    PRIMARY KEY (cmp_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 用户-企业绑定（selectCompanyIdByUser；本测试可空表，回落企业 1）
CREATE TABLE t_cmp_binding (
    bnd_id bigint NOT NULL AUTO_INCREMENT,
    bnd_company_id bigint NOT NULL,
    bnd_user_id bigint NOT NULL,
    bnd_status tinyint NOT NULL DEFAULT 1,
    PRIMARY KEY (bnd_id),
    KEY idx_bnd_user (bnd_user_id, bnd_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 站内消息（expire 链路在候选人关联用户时写入；本测试默认不关联，表保留）
CREATE TABLE t_msg (
    msg_id bigint NOT NULL AUTO_INCREMENT,
    msg_receiver_id bigint NOT NULL,
    msg_sender_id bigint NOT NULL DEFAULT 0,
    msg_type tinyint NOT NULL DEFAULT 1,
    msg_title varchar(200) NOT NULL,
    msg_content varchar(1000) DEFAULT NULL,
    msg_is_read bit(1) NOT NULL DEFAULT b'0',
    msg_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (msg_id),
    KEY idx_msg_receiver (msg_receiver_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
