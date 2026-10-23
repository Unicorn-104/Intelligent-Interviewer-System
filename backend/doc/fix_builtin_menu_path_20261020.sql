-- 修复内置目录菜单缺失的 path（与本地开发库对齐）
-- 背景：服务器库 menu_id 1/2/3/108 的 path 为空，导致系统管理/系统监控/系统工具
-- 及日志管理的前端路由拼接异常、菜单点击路径错乱。幂等，可重复执行。

UPDATE sys_menu SET path = 'system' WHERE menu_id = 1 AND (path IS NULL OR path = '');
UPDATE sys_menu SET path = 'monitor' WHERE menu_id = 2 AND (path IS NULL OR path = '');
UPDATE sys_menu SET path = 'tool'    WHERE menu_id = 3 AND (path IS NULL OR path = '');
UPDATE sys_menu SET path = 'log'     WHERE menu_id = 108 AND (path IS NULL OR path = '');

-- 说明：menu_id 2014/2015/2016（parent 2004，operation:* 权限）为他人模块残留空壳菜单，
-- 本地开发库不存在；此处不擅自停用或删除，由模块负责人确认后再处理。

-- ===== 对齐一级菜单排序（order_num）与自定义图标（icon），替换旧 fa 类名 =====
UPDATE sys_menu SET order_num = 7, icon = 'system' WHERE menu_id = 1;
UPDATE sys_menu SET order_num = 8, icon = 'monitor' WHERE menu_id = 2;
UPDATE sys_menu SET order_num = 9, icon = 'tool'    WHERE menu_id = 3;

-- ===== 对齐内置子菜单图标（本地自定义 svg 图标名，替换旧 fa 类名）=====
UPDATE sys_menu SET icon = 'user'        WHERE menu_id = 100;
UPDATE sys_menu SET icon = 'peoples'     WHERE menu_id = 101;
UPDATE sys_menu SET icon = 'tree-table'  WHERE menu_id = 102;
UPDATE sys_menu SET icon = 'tree'        WHERE menu_id = 103;
UPDATE sys_menu SET icon = 'post'        WHERE menu_id = 104;
UPDATE sys_menu SET icon = 'dict'        WHERE menu_id = 105;
UPDATE sys_menu SET icon = 'system'      WHERE menu_id = 106;
UPDATE sys_menu SET icon = 'bell'        WHERE menu_id = 107;
UPDATE sys_menu SET icon = 'log'         WHERE menu_id = 108;
UPDATE sys_menu SET icon = 'online'      WHERE menu_id = 109;
UPDATE sys_menu SET icon = 'time'        WHERE menu_id = 110;
UPDATE sys_menu SET icon = 'druid'       WHERE menu_id = 111;
UPDATE sys_menu SET icon = 'server'      WHERE menu_id = 112;
UPDATE sys_menu SET icon = 'redis'       WHERE menu_id = 113;
UPDATE sys_menu SET icon = 'build'       WHERE menu_id = 114;
UPDATE sys_menu SET icon = 'code'        WHERE menu_id = 115;
UPDATE sys_menu SET icon = 'swagger'     WHERE menu_id = 116;
UPDATE sys_menu SET icon = 'log'         WHERE menu_id = 500;
UPDATE sys_menu SET icon = 'logininfor'  WHERE menu_id = 501;
