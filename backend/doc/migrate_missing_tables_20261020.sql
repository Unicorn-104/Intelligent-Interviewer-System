CREATE TABLE IF NOT EXISTS `t_ad_slot` (
  `slot_code` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '广告位编码',
  `slot_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '广告位名称',
  `slot_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '广告位类型（splash开屏 popup弹窗 banner轮播 feed信息流）',
  `target` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'all' COMMENT '投放端（hr HR端 candidate候选人端 all全部）',
  `rule_desc` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '展示规则描述',
  `rule` text COLLATE utf8mb4_unicode_ci COMMENT '展示规则（JSON）',
  `status` char(1) COLLATE utf8mb4_unicode_ci DEFAULT '0' COMMENT '状态（0启用 1停用）',
  `create_by` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '创建者',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_by` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '更新者',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `remark` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`slot_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='广告位管理表';
CREATE TABLE IF NOT EXISTS `t_ai_cascade` (
  `cac_id` bigint NOT NULL AUTO_INCREMENT COMMENT '规则ID',
  `cac_name` varchar(100) NOT NULL COMMENT '规则名称',
  `cac_trigger_type` varchar(50) DEFAULT NULL COMMENT '触发类型',
  `cac_condition` text COMMENT '触发条件JSON',
  `cac_action` text COMMENT '执行动作JSON',
  `cac_priority` int DEFAULT '0' COMMENT '优先级',
  `cac_status` char(1) DEFAULT '0' COMMENT '状态（0正常 1停用）',
  `create_by` varchar(64) DEFAULT '' COMMENT '创建者',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_by` varchar(64) DEFAULT '' COMMENT '更新者',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`cac_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI级联规则表';
CREATE TABLE IF NOT EXISTS `t_content_category` (
  `cca_id` bigint NOT NULL AUTO_INCREMENT,
  `cca_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '分类名称',
  `cca_parent_id` bigint DEFAULT '0' COMMENT '父分类ID',
  `cca_sort` int DEFAULT '0' COMMENT '排序',
  `cca_status` char(1) COLLATE utf8mb4_unicode_ci DEFAULT '0' COMMENT '状态（0正常 1停用）',
  `cca_create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `cca_update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`cca_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='内容分类';
CREATE TABLE IF NOT EXISTS `t_content_feedback` (
  `cf_id` bigint NOT NULL AUTO_INCREMENT,
  `cf_user_id` bigint DEFAULT NULL COMMENT '用户ID',
  `cf_user_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '用户名称',
  `cf_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '反馈类型',
  `cf_content` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '反馈内容',
  `cf_contact` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '联系方式',
  `cf_status` char(1) COLLATE utf8mb4_unicode_ci DEFAULT '0' COMMENT '状态（0待处理 1已处理）',
  `cf_reply` text COLLATE utf8mb4_unicode_ci COMMENT '回复',
  `cf_create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `cf_update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`cf_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='反馈处理';
CREATE TABLE IF NOT EXISTS `t_content_help` (
  `ch_id` bigint NOT NULL AUTO_INCREMENT,
  `ch_title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '标题',
  `ch_category` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '分类',
  `ch_content` text COLLATE utf8mb4_unicode_ci COMMENT '内容',
  `ch_sort` int DEFAULT '0' COMMENT '排序',
  `ch_status` char(1) COLLATE utf8mb4_unicode_ci DEFAULT '0' COMMENT '状态（0正常 1停用）',
  `ch_create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `ch_update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`ch_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='帮助中心';
CREATE TABLE IF NOT EXISTS `t_content_question` (
  `cq_id` bigint NOT NULL AUTO_INCREMENT,
  `cq_title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '问题标题',
  `cq_category_id` bigint DEFAULT NULL COMMENT '分类ID',
  `cq_content` text COLLATE utf8mb4_unicode_ci COMMENT '问题内容',
  `cq_answer` text COLLATE utf8mb4_unicode_ci COMMENT '答案',
  `cq_view_count` int DEFAULT '0' COMMENT '浏览次数',
  `cq_status` char(1) COLLATE utf8mb4_unicode_ci DEFAULT '0' COMMENT '状态（0发布 1草稿）',
  `cq_create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `cq_update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`cq_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='问题管理';
CREATE TABLE IF NOT EXISTS `t_msg_channel` (
  `mc_id` bigint NOT NULL AUTO_INCREMENT,
  `mc_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '渠道名称',
  `mc_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '渠道类型（sms/email/webhook）',
  `mc_config` text COLLATE utf8mb4_unicode_ci COMMENT '配置JSON',
  `mc_status` char(1) COLLATE utf8mb4_unicode_ci DEFAULT '0' COMMENT '状态（0启用 1停用）',
  `mc_create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `mc_update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`mc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='渠道配置';
CREATE TABLE IF NOT EXISTS `t_msg_record` (
  `mr_id` bigint NOT NULL AUTO_INCREMENT,
  `mr_user_id` bigint DEFAULT NULL COMMENT '接收用户ID',
  `mr_user_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '接收用户名称',
  `mr_template_id` bigint DEFAULT NULL COMMENT '模板ID',
  `mr_channel` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '渠道（sms/email/system）',
  `mr_content` text COLLATE utf8mb4_unicode_ci COMMENT '发送内容',
  `mr_status` char(1) COLLATE utf8mb4_unicode_ci DEFAULT '0' COMMENT '状态（0成功 1失败）',
  `mr_create_time` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`mr_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='消息发送记录';
CREATE TABLE IF NOT EXISTS `t_scorecard` (
  `sc_id` bigint NOT NULL AUTO_INCREMENT COMMENT '评分卡ID',
  `sc_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '评分卡名称',
  `sc_direction` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '岗位方向',
  `sc_dimensions` text COLLATE utf8mb4_unicode_ci COMMENT '评分维度JSON',
  `sc_status` tinyint DEFAULT '1' COMMENT '状态：1启用 0禁用',
  `sc_created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `sc_updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`sc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI评分卡';
CREATE TABLE IF NOT EXISTS `t_system_privacy` (
  `priv_id` bigint NOT NULL AUTO_INCREMENT COMMENT '设置ID',
  `priv_key` varchar(100) NOT NULL COMMENT '配置键',
  `priv_value` text COMMENT '配置值',
  `priv_desc` varchar(200) DEFAULT NULL COMMENT '配置说明',
  `priv_type` varchar(50) DEFAULT NULL COMMENT '配置类型',
  `create_by` varchar(64) DEFAULT '' COMMENT '创建者',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_by` varchar(64) DEFAULT '' COMMENT '更新者',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`priv_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='系统隐私设置表';
CREATE TABLE IF NOT EXISTS `t_tenant_package` (
  `pkg_id` bigint NOT NULL AUTO_INCREMENT COMMENT '套餐ID',
  `pkg_name` varchar(100) NOT NULL COMMENT '套餐名称',
  `pkg_type` varchar(50) DEFAULT NULL COMMENT '套餐类型',
  `api_quota` int DEFAULT '0' COMMENT 'API配额',
  `max_companies` int DEFAULT '0' COMMENT '最大企业数',
  `max_users` int DEFAULT '0' COMMENT '最大用户数',
  `price` decimal(10,2) DEFAULT '0.00' COMMENT '价格',
  `pkg_status` char(1) DEFAULT '0' COMMENT '状态（0正常 1停用）',
  `description` varchar(500) DEFAULT NULL COMMENT '描述',
  `create_by` varchar(64) DEFAULT '' COMMENT '创建者',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_by` varchar(64) DEFAULT '' COMMENT '更新者',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`pkg_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='企业套餐表';
