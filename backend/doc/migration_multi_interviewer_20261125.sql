-- 面试阶段多面试官支持：预约维度的面试官名单。
-- 仅新增表，不修改已有业务表；可重复执行。
CREATE TABLE IF NOT EXISTS t_sch_appointment_interviewer (
    asi_id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    asi_appointment_id BIGINT NOT NULL COMMENT '预约ID',
    asi_user_id BIGINT NOT NULL COMMENT '面试官用户ID',
    asi_is_primary TINYINT NOT NULL DEFAULT 0 COMMENT '是否主面试官：1是 0否',
    asi_accept_status TINYINT NOT NULL DEFAULT 0 COMMENT '确认状态：0待确认 1接受 2拒绝',
    asi_created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    asi_updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (asi_id),
    UNIQUE KEY uk_asi_appointment_user (asi_appointment_id, asi_user_id),
    KEY idx_asi_user (asi_user_id, asi_appointment_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='面试预约面试官名单（多面试官）';
