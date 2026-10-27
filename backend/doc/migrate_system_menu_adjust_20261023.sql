-- 系统管理菜单整理（幂等，可重复执行）
-- 日期：2026-10-23
-- 说明：仅调整菜单启用状态与新增隐私配置菜单，不改若依原生源码，可独立回滚。

-- P0-1 启用「用户管理」(menu_id=100)：本地库有25个后台账号(含3个停用)，需界面维护。
-- 原为 status=1 禁用，现恢复可见。
UPDATE sys_menu SET status = '0', visible = '0' WHERE menu_id = 100;

-- P0-2 停用「健康告警」(menu_id=2035) 死菜单：
-- 其 component=monitor/health/index 在前端不存在，点开即空白/404，且后端 /system/sysHealth
-- 与菜单 perms=monitor:health:list 不对齐。先隐藏消除死入口，健康告警功能正式立项时再补页面。
UPDATE sys_menu SET status = '1' WHERE menu_id = 2035;

-- P0-3 新增「隐私设置」菜单(2107)及按钮权限(2108-2111)，对接 /system/privacy 的KV配置CRUD。
DELETE FROM sys_menu WHERE menu_id IN (2107, 2108, 2109, 2110, 2111);

INSERT INTO sys_menu
(menu_id, menu_name, parent_id, order_num, path, component, query, route_name,
 is_frame, is_cache, url, target, menu_type, visible, status, is_refresh, perms, icon,
 create_by, create_time, update_by, update_time, remark)
VALUES
(2107, '隐私设置', 1, 10, 'privacy', 'system/privacy/index', NULL, '',
 1, 0, '/system/privacy', '', 'C', 0, 0, 1, 'system:privacy:list', 'lock',
 'admin', NOW(), NULL, NULL, '隐私设置菜单'),
(2108, '隐私设置查询', 2107, 1, '', NULL, NULL, '',
 1, 0, '', '', 'F', 0, 0, 1, 'system:privacy:query', '#',
 'admin', NOW(), NULL, NULL, ''),
(2109, '隐私设置新增', 2107, 2, '', NULL, NULL, '',
 1, 0, '', '', 'F', 0, 0, 1, 'system:privacy:add', '#',
 'admin', NOW(), NULL, NULL, ''),
(2110, '隐私设置修改', 2107, 3, '', NULL, NULL, '',
 1, 0, '', '', 'F', 0, 0, 1, 'system:privacy:edit', '#',
 'admin', NOW(), NULL, NULL, ''),
(2111, '隐私设置删除', 2107, 4, '', NULL, NULL, '',
 1, 0, '', '', 'F', 0, 0, 1, 'system:privacy:remove', '#',
 'admin', NOW(), NULL, NULL, '');
