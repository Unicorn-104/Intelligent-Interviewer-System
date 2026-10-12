-- ============================================================================
-- 视频会议模块 - 真实录制增量迁移脚本
-- 日期：2026-10-12
-- 说明：浏览器端 MediaRecorder 录制 + 分片上传 + 服务端拼接落盘后，
--       录制文件除 URL/时长外还需记录真实文件大小（字节），
--       用于存储空间占用统计（替代原按码率估算的回落口径）。
-- 兼容：ses_rec_size_bytes 允许 NULL，历史数据无该字段时存储统计
--       自动回落到按录制时长 × 码率估算，不影响既有查询。
-- ============================================================================

USE recruit_agent;
SET NAMES utf8mb4;

ALTER TABLE t_int_session
    ADD COLUMN ses_rec_size_bytes bigint NULL DEFAULT NULL
        COMMENT '录制文件字节数' AFTER ses_rec_duration_sec;
