-- ============================================================================
-- 企业系统设置落库迁移脚本
-- 数据库: recruit_agent
-- 说明:
--   1. t_msg_template 增加 tpl_company_id 列做公司隔离（0=平台全局模板）
--   2. 新建 t_cmp_dept 企业部门表 + 种子数据（公司1/公司2）
--   3. 新建 t_cmp_integration 面试集成配置表 + 种子数据
--   4. 已有模板种子按 tpl_id 归属到公司 1/2
-- 注意: 表字符集须为 utf8mb4_unicode_ci，与 t_cmp_binding/t_pos 保持一致，
--       否则跨表字符串比较会报 Illegal mix of collations
-- ============================================================================

USE recruit_agent;

SET NAMES utf8mb4;

-- ----------------------------------------------------------------------------
-- 一、消息模板公司隔离
-- ----------------------------------------------------------------------------

ALTER TABLE t_msg_template
  ADD COLUMN tpl_company_id bigint NOT NULL DEFAULT 0 COMMENT '所属公司ID，0为平台全局模板' AFTER tpl_code;

-- 种子模板归属：公司1(1,2,5,6,7,9,11) / 公司2(3,4,8,10)
UPDATE t_msg_template SET tpl_company_id = 1 WHERE tpl_id IN (1, 2, 5, 6, 7, 9, 11);
UPDATE t_msg_template SET tpl_company_id = 2 WHERE tpl_id IN (3, 4, 8, 10);

-- ----------------------------------------------------------------------------
-- 二、企业部门表
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS t_cmp_dept (
  dept_id     bigint       NOT NULL AUTO_INCREMENT COMMENT '部门ID',
  company_id  bigint       NOT NULL COMMENT '所属公司ID',
  parent_id   bigint       NOT NULL DEFAULT 0 COMMENT '父部门ID，0为根',
  dept_name   varchar(50)  NOT NULL COMMENT '部门名称',
  leader      varchar(30)  DEFAULT NULL COMMENT '负责人姓名',
  order_num   int          NOT NULL DEFAULT 0 COMMENT '显示顺序',
  status      tinyint      NOT NULL DEFAULT 1 COMMENT '状态：1启用 0停用',
  created_at  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (dept_id),
  KEY idx_dept_company (company_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '企业部门表';

INSERT INTO t_cmp_dept (company_id, parent_id, dept_name, leader, order_num) VALUES
(1, 0, '星辰科技（总部）', '陈建平', 1),
(1, 1, '人力资源部', '周琳', 1),
(1, 1, '产品研发部', '陈志远', 2),
(1, 3, '前端研发组', '郑凯', 1),
(1, 3, '后端研发组', '顾承宇', 2),
(1, 1, '设计中心', '李薇', 3),
(1, 1, '市场与销售部', '赵峰', 4),
(2, 0, '数联信息（总部）', '刘建国', 1),
(2, 8, '人事部', '孙丽', 1),
(2, 8, '技术部', '马涛', 2);

-- ----------------------------------------------------------------------------
-- 三、面试集成配置表
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS t_cmp_integration (
  id            bigint      NOT NULL AUTO_INCREMENT COMMENT '主键',
  company_id    bigint      NOT NULL COMMENT '所属公司ID',
  provider_code varchar(30) NOT NULL COMMENT '集成标识：outlook/tencent_meeting/zoom/livekit',
  status        tinyint     NOT NULL DEFAULT 0 COMMENT '状态：0未连接 1已连接 2需配置',
  config_json   json        DEFAULT NULL COMMENT '集成配置（API Key、回调地址等）',
  created_at    datetime    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at    datetime    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_integration (company_id, provider_code)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT '企业面试集成配置表';

INSERT INTO t_cmp_integration (company_id, provider_code, status, config_json) VALUES
(1, 'outlook', 1, '{"clientId": "demo-client-id", "redirectUri": "https://recruit.example.com/callback/outlook"}'),
(1, 'tencent_meeting', 1, '{"sdkId": "demo-sdk", "secret": "demo-secret"}'),
(1, 'zoom', 0, NULL),
(1, 'livekit', 2, '{"serverUrl": "wss://livekit.example.com"}'),
(2, 'outlook', 0, NULL),
(2, 'tencent_meeting', 0, NULL),
(2, 'zoom', 0, NULL),
(2, 'livekit', 0, NULL);
