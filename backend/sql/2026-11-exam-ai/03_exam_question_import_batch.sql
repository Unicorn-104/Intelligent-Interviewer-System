-- =====================================================================
-- 题库导入记录与撤销 · DDL
-- 状态：已执行（2026-11-19 旧库；2026-11-23 新库 192.168.100.3:1260，负责人授权后执行）
-- 目标库：recruit_agent（MySQL 8.0）
-- 作用：记录每一次题库写入（文件导入 / 单条新增），支持按批次撤销
-- =====================================================================

CREATE TABLE IF NOT EXISTS t_exam_question_import_batch (
  eqb_id          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '批次主键',
  eqb_type        TINYINT      NOT NULL DEFAULT 1     COMMENT '1文件导入 2单条新增',
  eqb_file_name   VARCHAR(255) NULL                   COMMENT '文件名，单条新增为 NULL',
  eqb_company_id  BIGINT       NULL                   COMMENT '企业ID，NULL=系统题库',
  eqb_total       INT          NOT NULL DEFAULT 0     COMMENT '提交条数',
  eqb_inserted    INT          NOT NULL DEFAULT 0     COMMENT '成功条数',
  eqb_failed      INT          NOT NULL DEFAULT 0     COMMENT '失败条数',
  eqb_question_ids TEXT        NULL                   COMMENT '本批写入的题目ID，逗号分隔，撤销用',
  eqb_status      TINYINT      NOT NULL DEFAULT 0     COMMENT '0正常 1已撤销',
  eqb_operator    VARCHAR(64)  NULL                   COMMENT '操作人',
  eqb_created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (eqb_id),
  KEY idx_eqb_created (eqb_created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='题库导入批次记录';

-- =====================================================================
-- 回滚
-- =====================================================================
-- DROP TABLE IF EXISTS t_exam_question_import_batch;

-- =====================================================================
-- 撤销语义（代码实现，不在本脚本内）
-- 1. 只删除本批 eqb_question_ids 中仍存在的题目；
-- 2. 已被 t_exam_paper_question / t_exam_answer 引用的题目跳过，不删除；
-- 3. 撤销后 eqb_status=1，不允许二次撤销。
-- =====================================================================
