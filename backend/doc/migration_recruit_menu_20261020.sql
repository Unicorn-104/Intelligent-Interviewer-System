-- ============================================================
-- 招聘管理菜单补全（服务器部署第一步）
-- 目标库: recruit_agent
-- 说明:
--   1. 将服务器已有的 2002 由 F(权限标识) 修正为 M(目录/Layout)
--   2. 补齐 2040-2044 五个页面菜单(C)
--   3. 为业务角色 102(招聘HR)/105(运营专员) 补 role_menu 授权
-- 超管(role_id=1)默认全量可见，无需 role_menu 授权。
-- 可重复执行：菜单用 INSERT IGNORE，授权用 INSERT IGNORE。
-- ============================================================
USE recruit_agent;

-- 1. 2002 修正为顶部目录
UPDATE sys_menu
SET parent_id = 0,
    order_num = 3,
    path = 'recruit',
    component = 'Layout',
    query = NULL,
    route_name = '',
    is_frame = 1,
    is_cache = 0,
    url = '#',
    menu_type = 'M',
    visible = '0',
    status = '0',
    is_refresh = 1,
    perms = 'recruit',
    icon = 'job'
WHERE menu_id = 2002;

-- 2. 补齐页面菜单
INSERT IGNORE INTO sys_menu
(menu_id, parent_id, menu_name, order_num, path, component, query, route_name,
 is_frame, is_cache, url, target, menu_type, visible, status, is_refresh, perms, icon, create_by, create_time, remark)
VALUES
(2040, 2002, '岗位管理', 1, 'job',       'biz/job/index',       NULL, '', 1, 0, '#', '', 'C', '0', '0', 1, 'biz:job:list',       'list',         'admin', NOW(), ''),
(2041, 2002, '候选人管理', 2, 'candidate', 'biz/candidate/index', NULL, '', 1, 0, '#', '', 'C', '0', '0', 1, 'biz:candidate:list', 'peoples',      'admin', NOW(), ''),
(2042, 2002, '简历管理', 3, 'resume',    'biz/resume/index',    NULL, '', 1, 0, '#', '', 'C', '0', '0', 1, 'biz:resume:list',    'documentation','admin', NOW(), ''),
(2043, 2002, '面试安排', 4, 'interview', 'biz/interview/index', NULL, '', 1, 0, '#', '', 'C', '0', '0', 1, 'biz:interview:list', 'date',         'admin', NOW(), ''),
(2044, 2002, '面试评估', 5, 'exam',      'biz/exam/index',      NULL, '', 1, 0, '#', '', 'C', '0', '0', 1, 'biz:exam:list',      'edit',         'admin', NOW(), '');

-- 3. 业务角色授权（102 招聘HR / 105 运营专员）
INSERT IGNORE INTO sys_role_menu (role_id, menu_id)
SELECT r.role_id, m.menu_id
FROM (SELECT 102 AS role_id UNION SELECT 105) r
CROSS JOIN (SELECT 2002 AS menu_id UNION SELECT 2040 UNION SELECT 2041 UNION SELECT 2042 UNION SELECT 2043 UNION SELECT 2044) m;
