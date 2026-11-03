-- ============================================================================
-- 第三方集成凭据表 - 增量迁移脚本
-- 日期：2026-11-03
-- 说明：ASR 与简历解析 AI 的密钥从配置文件迁入数据库，落库后加密保存。
--       密文格式：ENC:Base64(IV + AES-256/GCM 密文)，主密钥见 app.secret.crypto-key。
-- ============================================================================

USE recruit_agent;
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS t_integration_secret (
  isc_id         bigint       NOT NULL AUTO_INCREMENT COMMENT '主键',
  isc_scope      varchar(32)  NOT NULL COMMENT '所属集成：asr / resume_ai',
  isc_key        varchar(64)  NOT NULL COMMENT '配置项：app-id / secret-id / secret-key / api-key / api-url / model',
  isc_value      text         NOT NULL COMMENT '配置值；ENC:Base64(IV+GCM密文)，服务启动后自动加密历史明文',
  isc_status     tinyint      NOT NULL DEFAULT 1 COMMENT '状态：1启用，0禁用',
  isc_updated_at datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (isc_id),
  UNIQUE KEY uk_isc_scope_key (isc_scope, isc_key)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '第三方集成凭据表';

-- 首次部署可直接写入明文（下面的占位值需替换为真实值），后端启动时会自动转为 ENC: 密文：
-- INSERT INTO t_integration_secret (isc_scope, isc_key, isc_value) VALUES
--   ('asr', 'app-id', '<腾讯云语音识别 AppID>'),
--   ('asr', 'secret-id', '<腾讯云 SecretId>'),
--   ('asr', 'secret-key', '<腾讯云 SecretKey>'),
--   ('resume_ai', 'api-key', '<简历解析模型 API Key>');
-- 可选：('resume_ai', 'api-url', 'https://api.deepseek.com/chat/completions')、('resume_ai', 'model', 'deepseek-chat')
