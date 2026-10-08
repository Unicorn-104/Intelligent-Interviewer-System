-- ============================================================================
-- 视频会议模块 - 会前链路增量迁移脚本
-- 日期：2026-10-08
-- 说明：会议进入方式改为「HR 生成会议链接 → 双方都从链接进入」。
--       链接令牌复用既有 t_int_session.ses_room_token / ses_room_id，不新增列；
--       本脚本仅新增 1 张表：面试参与者会前状态表。
--
--       为什么需要它：既有 t_int_meeting_state 的四项检测与音视频开关是
--       「场次级单行」，HR 与候选人会互相覆盖。本表按 (场次, 用户) 维度
--       分别记录每人的检测结果与就绪标记，供等候室展示对方状态。
-- 注意：字符集须为 utf8mb4_unicode_ci，与既有 t_int_* 表保持一致。
-- ============================================================================

USE recruit_agent;
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS t_int_participant_state (
  pst_id                  bigint   NOT NULL AUTO_INCREMENT       COMMENT '主键',
  pst_session_id          bigint   NOT NULL                      COMMENT '面试场次ID，关联 ses_id',
  pst_user_id             bigint   NOT NULL                      COMMENT '参与者用户ID，关联 sys_user.user_id',
  pst_role                tinyint  NOT NULL                      COMMENT '角色：1-面试官/HR，2-候选人',
  pst_cam_status          tinyint  NOT NULL DEFAULT 0            COMMENT '摄像头检测：0-未检测，1-正常，2-警告，3-异常',
  pst_mic_status          tinyint  NOT NULL DEFAULT 0            COMMENT '麦克风检测：同上',
  pst_speaker_status      tinyint  NOT NULL DEFAULT 0            COMMENT '扬声器检测：同上',
  pst_net_status          tinyint  NOT NULL DEFAULT 0            COMMENT '网络检测：同上',
  pst_net_rtt_ms          int      NULL                         COMMENT '网络往返时延（毫秒）',
  pst_net_bandwidth_kbps  int      NULL                         COMMENT '下行带宽（Kbps）',
  pst_risk_flag           tinyint  NOT NULL DEFAULT 0            COMMENT '弱网风险已忽略：0-否，1-是',
  pst_device_json         json     NULL                         COMMENT '所选设备ID等扩展信息',
  pst_ready               tinyint  NOT NULL DEFAULT 0            COMMENT '就绪：0-未就绪，1-已就绪（已进入等候室）',
  pst_waiting_at          datetime NULL                         COMMENT '进入等候室时间',
  pst_in_meeting          tinyint  NOT NULL DEFAULT 0            COMMENT '已在会议中：0-否，1-是',
  pst_created_at          datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  pst_updated_at          datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (pst_id),
  UNIQUE KEY uk_pst_session_user (pst_session_id, pst_user_id),
  KEY idx_pst_session_role (pst_session_id, pst_role)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '面试参与者会前状态表';