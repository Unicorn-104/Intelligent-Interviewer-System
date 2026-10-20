-- 2026-10-20 部署对齐补充：菜单2035 + 广告位/隐私默认种子（幂等，可重复执行）
-- 目标库 recruit_agent；仅补本地有而服务器缺的基础项，不迁移业务测试数据

-- 菜单：健康告警（挂在系统管理 parent_id=1）
INSERT IGNORE INTO `sys_menu`
(`menu_id`,`menu_name`,`parent_id`,`order_num`,`path`,`component`,`query`,`route_name`,`is_frame`,`is_cache`,`url`,`target`,`menu_type`,`visible`,`status`,`is_refresh`,`perms`,`icon`,`create_by`,`create_time`,`update_by`,`update_time`,`remark`)
VALUES
(2035,'健康告警',1,6,'health','monitor/health/index','','',1,0,'#','','C','0','0','1','monitor:health:list','bug','admin',NOW(),'',NULL,'系统健康与告警');

-- 广告位基础配置（广告下拉选项来源）
INSERT IGNORE INTO `t_ad_slot`
(`slot_code`,`slot_name`,`slot_type`,`target`,`rule_desc`,`rule`,`status`,`create_by`,`create_time`,`update_by`,`update_time`,`remark`) VALUES
('home_banner','首页Banner','banner','hr','HR端首页顶部轮播',NULL,'0','admin',NOW(),'',NOW(),NULL),
('home_popup','首页弹窗','popup','candidate','候选人端首页弹窗',NULL,'0','admin',NOW(),'',NOW(),NULL),
('int_end_page','面试结束页','popup','candidate','面试结束后展示',NULL,'0','admin',NOW(),'',NOW(),NULL),
('post_feed','信息流广告','feed','all','信息流列表中穿插展示',NULL,'0','admin',NOW(),'',NOW(),NULL),
('splash','开屏广告','splash','all','App启动时展示3秒',NULL,'0','admin',NOW(),'',NOW(),NULL);

-- 系统隐私/默认设置
INSERT IGNORE INTO `t_system_privacy`
(`priv_key`,`priv_value`,`priv_desc`,`priv_type`,`create_by`,`create_time`,`update_by`,`update_time`) VALUES
('data_retention_days','365','数据保留天数','retention','admin',NOW(),'',NOW()),
('log_enabled','true','是否开启操作日志','log','admin',NOW(),'',NOW()),
('backup_enabled','true','是否开启自动备份','backup','admin',NOW(),'',NOW());
