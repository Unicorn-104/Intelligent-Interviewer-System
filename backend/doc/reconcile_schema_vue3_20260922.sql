-- ============================================================================
-- 补齐脚本：让 sys_* 表结构匹配本工程(RuoYi-Vue3)代码实际使用的字段
-- 数据库: recruit_agent
-- 修正点:
--   1. sys_menu 补 Vue3 前端路由字段 (path/component/query/route_name/is_frame/is_cache/status)
--   2. sys_role 补 menu_check_strictly / dept_check_strictly
--   3. sys_user  列重命名 login_name->user_name(账号), user_name->nick_name(昵称)
--   4. sys_logininfor 列重命名 login_name->user_name
-- ============================================================================

USE recruit_agent;
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
-- 1. sys_menu 补充字段
-- ---------------------------------------------------------------------------
ALTER TABLE sys_menu
  ADD COLUMN path varchar(200) DEFAULT '' COMMENT '路由地址' AFTER order_num,
  ADD COLUMN component varchar(255) DEFAULT NULL COMMENT '组件路径' AFTER path,
  ADD COLUMN `query` varchar(255) DEFAULT NULL COMMENT '路由参数' AFTER component,
  ADD COLUMN route_name varchar(50) DEFAULT '' COMMENT '路由名称' AFTER `query`,
  ADD COLUMN is_frame int(1) DEFAULT 1 COMMENT '是否为外链（0是 1否）' AFTER route_name,
  ADD COLUMN is_cache int(1) DEFAULT 0 COMMENT '是否缓存（0缓存 1不缓存）' AFTER is_frame,
  ADD COLUMN status char(1) DEFAULT '0' COMMENT '菜单状态（0正常 1停用）' AFTER visible;

-- ---------------------------------------------------------------------------
-- 2. sys_role 补充字段
-- ---------------------------------------------------------------------------
ALTER TABLE sys_role
  ADD COLUMN menu_check_strictly tinyint(1) DEFAULT 1 COMMENT '菜单树选择项是否关联显示' AFTER data_scope,
  ADD COLUMN dept_check_strictly tinyint(1) DEFAULT 1 COMMENT '部门树选择项是否关联显示' AFTER menu_check_strictly;

-- ---------------------------------------------------------------------------
-- 3. sys_user 列重命名 (账号/昵称)
-- ---------------------------------------------------------------------------
ALTER TABLE sys_user RENAME COLUMN user_name TO nick_name;
ALTER TABLE sys_user RENAME COLUMN login_name TO user_name;

-- ---------------------------------------------------------------------------
-- 4. sys_logininfor 列重命名 (账号)
-- ---------------------------------------------------------------------------
ALTER TABLE sys_logininfor RENAME COLUMN login_name TO user_name;

-- ---------------------------------------------------------------------------
-- 5. 数据回填：菜单 path/component（由旧 url 推导，供 Vue3 前端路由使用）
-- ---------------------------------------------------------------------------
UPDATE sys_menu SET path = CASE
    WHEN url IS NULL OR url = '' OR url = '#' THEN ''
    ELSE TRIM(LEADING '/' FROM url)
END;
UPDATE sys_menu SET component = CONCAT(path, '/index')
WHERE menu_type = 'C' AND path != '' AND path NOT LIKE 'http%';
UPDATE sys_menu SET is_frame = 0 WHERE path LIKE 'http%';
UPDATE sys_menu SET status = '0';
