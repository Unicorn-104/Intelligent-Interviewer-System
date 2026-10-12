-- ============================================================================
-- 视频会议模块 - 多面试官增量迁移脚本
-- 日期：2026-10-10
-- 说明：视频面试支持「多位 HR 共同面试」，并扩展面试模式。
--       1) 新增 t_int_session_interviewer：记录一场面试被指派的多位面试官，
--          并标记主面试官（独占开始 / 结束 / 录制，可移交）。
--       2) 扩展 t_int_session.ses_mode 取值，严格联动面试官人数：
--          1-纯AI（0 位）、2-AI+单面试官（1 位）、3-AI+多面试官（≥2 位）、
--          4-无AI纯人工（≥1 位）。
-- 兼容：ses_interviewer_id 保留为主面试官（纯AI 时记为发起人），旧数据不受影响。
-- 注意：字符集须为 utf8mb4_unicode_ci，与既有 t_int_* 表保持一致。
-- ============================================================================

USE recruit_agent;
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS t_int_session_interviewer (
  isi_id          bigint   NOT NULL AUTO_INCREMENT             COMMENT '主键',
  isi_session_id  bigint   NOT NULL                            COMMENT '面试场次ID，关联 ses_id',
  isi_user_id     bigint   NOT NULL                            COMMENT '面试官用户ID，关联 sys_user.user_id',
  isi_is_primary  tinyint  NOT NULL DEFAULT 0                  COMMENT '是否主面试官：0-否，1-是（独占开始/结束/录制，可移交）',
  isi_join_status tinyint  NOT NULL DEFAULT 0                  COMMENT '加入状态：0-未加入，1-已加入',
  isi_joined_at   datetime NULL                                COMMENT '加入会议时间',
  isi_muted_av    tinyint  NOT NULL DEFAULT 0                  COMMENT '加入时是否静音音视频（旁听）：0-否，1-是',
  isi_created_at  datetime NOT NULL DEFAULT CURRENT_TIMESTAMP  COMMENT '创建时间',
  isi_updated_at  datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (isi_id),
  UNIQUE KEY uk_isi_session_user (isi_session_id, isi_user_id),
  KEY idx_isi_user (isi_user_id),
  CONSTRAINT fk_isi_session_id FOREIGN KEY (isi_session_id) REFERENCES t_int_session (ses_id) ON DELETE CASCADE,
  CONSTRAINT fk_isi_user_id FOREIGN KEY (isi_user_id) REFERENCES sys_user (user_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '面试场次面试官关联表';

ALTER TABLE t_int_session
  MODIFY COLUMN ses_mode tinyint NOT NULL
  COMMENT '实际面试模式：1-纯AI，2-AI+单面试官，3-AI+多面试官，4-无AI纯人工';