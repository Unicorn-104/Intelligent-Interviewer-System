-- ============================================================================
-- Testcontainers 并发集成测试 · 最小建表脚本（仅在一次性 MySQL8 容器内执行，不连生产）
-- 结构与 migration_app_status_refactor_ddl_20261105.sql 落地后的真实表一致
-- ============================================================================

DROP TABLE IF EXISTS t_process_instance_stage;
DROP TABLE IF EXISTS t_app_status_log;
DROP TABLE IF EXISTS t_process_instance;
DROP TABLE IF EXISTS t_app_record;

CREATE TABLE t_app_record (
    app_id bigint NOT NULL AUTO_INCREMENT COMMENT '投递ID',
    app_candidate_id bigint NOT NULL COMMENT '候选人ID',
    app_position_id bigint NOT NULL COMMENT '岗位ID',
    app_resume_id bigint DEFAULT NULL COMMENT '简历ID',
    app_process_instance_id bigint DEFAULT NULL COMMENT '流程实例ID',
    app_matched_score decimal(5,2) DEFAULT NULL COMMENT '匹配分',
    app_greeting varchar(200) DEFAULT NULL COMMENT '招呼语',
    app_status tinyint NOT NULL DEFAULT 0 COMMENT '六态：0已投递 1招聘中 2待发Offer 3待确认Offer 4已录用 5未录用',
    end_reason varchar(40) DEFAULT NULL COMMENT '终止原因编码',
    ended_at datetime DEFAULT NULL COMMENT '终止时间',
    ended_by bigint DEFAULT NULL COMMENT '终止操作人',
    end_remark varchar(500) DEFAULT NULL COMMENT '终止说明',
    app_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    app_updated_at datetime DEFAULT NULL,
    PRIMARY KEY (app_id),
    KEY idx_app_candidate_position (app_candidate_id, app_position_id),
    KEY idx_app_end_reason (end_reason)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

CREATE TABLE t_process_instance (
    pin_id bigint NOT NULL AUTO_INCREMENT,
    pin_candidate_id bigint NOT NULL,
    pin_position_id bigint NOT NULL,
    pin_status tinyint NOT NULL DEFAULT 0 COMMENT '0进行中 1已完成 2已终止 3已淘汰',
    pin_start_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    pin_end_at datetime DEFAULT NULL,
    pin_created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (pin_id),
    KEY idx_pin_candidate_position (pin_candidate_id, pin_position_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE t_process_instance_stage (
    pis_id bigint NOT NULL AUTO_INCREMENT,
    pis_instance_id bigint NOT NULL,
    pis_stage_id bigint DEFAULT NULL,
    pis_node_type tinyint DEFAULT NULL COMMENT '1在线笔试 2AI技术面试 3HR综合面试 4编程实操',
    pis_round int DEFAULT NULL COMMENT '同类型节点轮次',
    pis_status tinyint NOT NULL DEFAULT 0 COMMENT '0待开始 1进行中 2已完成 3已取消',
    pis_result tinyint DEFAULT NULL COMMENT '1通过 2未通过 3缺考 4取消',
    pis_ref_id bigint DEFAULT NULL COMMENT '业务单据ID',
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
