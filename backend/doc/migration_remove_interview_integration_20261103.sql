-- 下线「系统设置 > 面试集成」功能（2026-11-03）
-- 该表仅服务于已删除的面试集成配置页；前端页面、后端接口、Mapper 与数据备份清单已同步移除。
-- 执行前请确认业务方不再需要历史集成配置。

DROP TABLE IF EXISTS t_cmp_integration;

-- 回滚（如需恢复表结构，可重新执行原迁移中的建表段）：
-- CREATE TABLE IF NOT EXISTS t_cmp_integration (
--   id            bigint      NOT NULL AUTO_INCREMENT COMMENT '主键',
--   company_id    bigint      NOT NULL COMMENT '所属公司ID',
--   provider_code varchar(30) NOT NULL COMMENT '集成标识：outlook/tencent_meeting/zoom/livekit',
--   status        tinyint     NOT NULL DEFAULT 0 COMMENT '状态：0未连接 1已连接 2需配置',
--   config_json   json        DEFAULT NULL COMMENT '集成配置（API Key、回调地址等）',
--   created_at    datetime    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
--   updated_at    datetime    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
--   PRIMARY KEY (id),
--   UNIQUE KEY uk_integration (company_id, provider_code)
-- ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '企业面试集成配置表';
