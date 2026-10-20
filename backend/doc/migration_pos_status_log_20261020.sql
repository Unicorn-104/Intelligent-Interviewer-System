USE recruit_agent;
SET NAMES utf8mb4;

-- 岗位状态变更日志表：记录每次审核通过 / 违规下架的原因与操作时间（不改 t_pos 原表）
CREATE TABLE IF NOT EXISTS t_pos_status_log (
  psl_id          bigint       NOT NULL AUTO_INCREMENT COMMENT '主键',
  psl_pos_id      bigint       NOT NULL COMMENT '岗位ID（t_pos.pos_id）',
  psl_from_status tinyint      DEFAULT NULL COMMENT '变更前状态：0待审核/1已发布/2违规下架/3已下架',
  psl_to_status   tinyint      NOT NULL COMMENT '变更后状态：1已发布/2违规下架/3已下架',
  psl_reason      varchar(500) DEFAULT NULL COMMENT '处理原因 / 违规下架原因',
  psl_operator_id bigint       DEFAULT NULL COMMENT '操作人（平台管理员）ID',
  psl_created_at  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
  PRIMARY KEY (psl_id),
  KEY idx_psl_pos (psl_pos_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '岗位状态变更日志表';
