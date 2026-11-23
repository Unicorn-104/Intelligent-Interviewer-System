-- =====================================================
-- 隔离演练源表夹具（仅测试，非生产真实 DDL）
-- 说明：
--   1) t_ai_candidate_analysis 采用 e-app/new.sql 中的真实旧结构（复合三列主键）；
--   2) t_res_base 及四子表的真实建表 DDL 在仓库中缺失，本表列名严格取自迁移 SQL 已引用的列，
--      类型为代表性设定（日期用 DATE、排序用 utf8mb4_unicode_ci），真实类型/精度须 information_schema 核对；
--   3) 全部为脱敏占位数据结构，本文件只建表，不写业务数据。
-- =====================================================

CREATE TABLE t_pos (
    pos_id bigint NOT NULL AUTO_INCREMENT,
    pos_company_id bigint NOT NULL,
    pos_name varchar(100) NOT NULL,
    PRIMARY KEY (pos_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE t_app_record (
    app_id bigint NOT NULL AUTO_INCREMENT,
    app_candidate_id bigint NOT NULL,
    app_position_id bigint NOT NULL,
    app_resume_id bigint DEFAULT NULL,
    app_status tinyint NOT NULL DEFAULT 0,
    app_created_at datetime DEFAULT NULL,
    app_updated_at datetime DEFAULT NULL,
    PRIMARY KEY (app_id),
    KEY idx_app_candidate_position (app_candidate_id, app_position_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE t_tal (
    tal_id bigint NOT NULL AUTO_INCREMENT,
    tal_user_id bigint DEFAULT NULL,
    tal_company_id bigint DEFAULT NULL,
    tal_resume_id bigint DEFAULT NULL,
    PRIMARY KEY (tal_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE t_res_base (
    rbs_id bigint NOT NULL AUTO_INCREMENT,
    rbs_user_id bigint DEFAULT NULL,
    rbs_resume_name varchar(100) DEFAULT NULL,
    rbs_job_direction varchar(50) DEFAULT NULL,
    rbs_file_path varchar(500) DEFAULT NULL,
    rbs_file_name varchar(255) DEFAULT NULL,
    rbs_file_size bigint DEFAULT NULL,
    rbs_status tinyint NOT NULL DEFAULT 1,
    PRIMARY KEY (rbs_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE t_res_education (
    edu_id bigint NOT NULL AUTO_INCREMENT,
    edu_resume_id bigint NOT NULL,
    edu_school varchar(100) NOT NULL,
    edu_major varchar(50) DEFAULT NULL,
    edu_degree tinyint DEFAULT NULL,
    edu_start_date date DEFAULT NULL,
    edu_end_date date DEFAULT NULL,
    edu_gpa decimal(3,2) DEFAULT NULL,
    edu_description text,
    PRIMARY KEY (edu_id),
    KEY idx_edu_resume (edu_resume_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE t_res_work (
    wrk_id bigint NOT NULL AUTO_INCREMENT,
    wrk_resume_id bigint NOT NULL,
    wrk_company varchar(100) NOT NULL,
    wrk_position varchar(50) NOT NULL,
    wrk_department varchar(50) DEFAULT NULL,
    wrk_start_date date DEFAULT NULL,
    wrk_end_date date DEFAULT NULL,
    wrk_is_current tinyint DEFAULT 0,
    wrk_salary_range varchar(20) DEFAULT NULL,
    wrk_description text,
    PRIMARY KEY (wrk_id),
    KEY idx_wrk_resume (wrk_resume_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE t_res_project (
    prj_id bigint NOT NULL AUTO_INCREMENT,
    prj_resume_id bigint NOT NULL,
    prj_name varchar(100) NOT NULL,
    prj_role varchar(50) DEFAULT NULL,
    prj_start_date date DEFAULT NULL,
    prj_end_date date DEFAULT NULL,
    prj_description text,
    prj_tech_stack varchar(200) DEFAULT NULL,
    PRIMARY KEY (prj_id),
    KEY idx_prj_resume (prj_resume_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE t_res_skill (
    skl_id bigint NOT NULL AUTO_INCREMENT,
    skl_resume_id bigint NOT NULL,
    skl_name varchar(50) NOT NULL,
    skl_level tinyint DEFAULT 2,
    PRIMARY KEY (skl_id),
    KEY idx_skl_resume (skl_resume_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 真实旧结构（e-app/new.sql）：复合三列主键，无单列自增主键
CREATE TABLE t_ai_candidate_analysis (
    asr_company_id BIGINT NOT NULL,
    asr_position_id BIGINT NOT NULL,
    asr_candidate_id BIGINT NOT NULL,
    asr_resume_id BIGINT DEFAULT NULL,
    asr_report JSON NOT NULL,
    asr_updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (asr_company_id, asr_position_id, asr_candidate_id),
    KEY idx_aca_candidate_updated (asr_company_id, asr_candidate_id, asr_updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
