-- ============================================================================
-- 视频会议模块 - 增量迁移脚本
-- 日期：2026-09-30
-- 说明：面试链路复用既有 t_int_session / t_int_dialogue / t_int_outline /
--       t_int_evaluation / t_sch_appointment 等表，本脚本仅新增 3 张缺失表：
--       1) t_int_meeting_state     会议运行时状态（设备、网络、进度、接管、心跳）
--       2) t_int_copilot           实时提词器 / 协同建议
--       3) t_int_recording_policy  录制存储策略
-- 注意：字符集须为 utf8mb4_unicode_ci，与既有 t_int_* 表保持一致。
-- ============================================================================

USE recruit_agent;
SET NAMES utf8mb4;

-- ----------------------------------------------------------------------------
-- 1. 会议运行时状态（与 t_int_session 一对一，ses_id 即主键）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS t_int_meeting_state (
  mst_session_id          bigint       NOT NULL                    COMMENT '面试场次ID，关联 ses_id（一场一条）',
  mst_total_question      int          NOT NULL DEFAULT 0          COMMENT '本轮题目总数',
  mst_current_question    int          NOT NULL DEFAULT 0          COMMENT '已完成题目数（当前题目序号 = 该值 + 1）',
  mst_duration_seconds    int          NULL                        COMMENT '本场面试时长（秒，取自预约时段）',
  mst_remaining_seconds   int          NULL                        COMMENT '剩余秒数',
  mst_mic_enabled         tinyint      NOT NULL DEFAULT 0          COMMENT '麦克风开关：0-关，1-开',
  mst_cam_enabled         tinyint      NOT NULL DEFAULT 0          COMMENT '摄像头开关：0-关，1-开',
  mst_speaker_volume      tinyint      NOT NULL DEFAULT 80         COMMENT '扬声器音量（0-100）',
  mst_device_json         json         NULL                        COMMENT '所选设备ID等扩展信息',
  mst_cam_status          tinyint      NOT NULL DEFAULT 0          COMMENT '摄像头检测：0-未检测，1-正常，2-警告，3-异常',
  mst_mic_status          tinyint      NOT NULL DEFAULT 0          COMMENT '麦克风检测：同上',
  mst_speaker_status      tinyint      NOT NULL DEFAULT 0          COMMENT '扬声器检测：同上',
  mst_net_status          tinyint      NOT NULL DEFAULT 0          COMMENT '网络检测：同上',
  mst_net_rtt_ms          int          NULL                        COMMENT '网络往返时延（毫秒）',
  mst_net_bandwidth_kbps  int          NULL                        COMMENT '下行带宽（Kbps）',
  mst_risk_flag           tinyint      NOT NULL DEFAULT 0          COMMENT '弱网风险标记：0-无，1-已忽略风险进入',
  mst_takeover            tinyint      NOT NULL DEFAULT 0          COMMENT 'HR接管状态：0-未接管，1-接管中',
  mst_takeover_reason     varchar(255) NULL                        COMMENT '接管原因',
  mst_heartbeat_at        datetime     NULL                        COMMENT '最后心跳时间（用于断网判定）',
  mst_created_at          datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  mst_updated_at          datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (mst_session_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '面试会议运行时状态表';

-- ----------------------------------------------------------------------------
-- 2. 实时提词器 / 协同建议
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS t_int_copilot (
  cpt_id              bigint        NOT NULL AUTO_INCREMENT       COMMENT '建议ID',
  cpt_session_id      bigint        NOT NULL                      COMMENT '关联场次ID，关联 ses_id',
  cpt_seq             int           NOT NULL                      COMMENT '场次内序号，用于增量拉取',
  cpt_mode            tinyint       NOT NULL DEFAULT 1            COMMENT '类型：1-建议问题，2-参考答案，3-评分要点',
  cpt_content         varchar(1000) NOT NULL                      COMMENT '建议问题 / 要点正文',
  cpt_reference       text          NULL                          COMMENT '参考答案',
  cpt_points          json          NULL                          COMMENT '评分要点数组',
  cpt_status          tinyint       NOT NULL DEFAULT 0            COMMENT '状态：0-待处理，1-已采纳，2-已编辑，3-已忽略',
  cpt_adopted_content varchar(1000) NULL                          COMMENT '编辑后实际采用的内容',
  cpt_created_at      datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  cpt_updated_at      datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (cpt_id),
  UNIQUE KEY uk_cpt_session_seq (cpt_session_id, cpt_seq),
  KEY idx_cpt_session_status (cpt_session_id, cpt_status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '面试实时提词器建议表';

-- ----------------------------------------------------------------------------
-- 3. 录制存储策略（企业级；rcp_company_id 为 NULL 表示全局默认）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS t_int_recording_policy (
  rcp_id                    bigint   NOT NULL AUTO_INCREMENT      COMMENT '策略ID',
  rcp_company_id            bigint   NULL                         COMMENT '归属企业ID，关联 cmp_id（NULL=全局默认）',
  rcp_keep_days             int      NOT NULL DEFAULT 90          COMMENT '录制保留天数',
  rcp_max_storage_gb        int      NOT NULL DEFAULT 500         COMMENT '总存储上限（GB）',
  rcp_default_access_level  tinyint  NOT NULL DEFAULT 1           COMMENT '默认访问级别：1-仅HR/面试官，2-含管理员，3-候选人可见',
  rcp_created_at            datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  rcp_updated_at            datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (rcp_id),
  UNIQUE KEY uk_rcp_company_id (rcp_company_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '面试录制存储策略表';

INSERT INTO t_int_recording_policy (rcp_company_id, rcp_keep_days, rcp_max_storage_gb, rcp_default_access_level)
SELECT NULL, 90, 500, 1
WHERE NOT EXISTS (SELECT 1 FROM t_int_recording_policy WHERE rcp_company_id IS NULL);