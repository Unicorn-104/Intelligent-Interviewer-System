# 系统设置五个 Tab 全部真实落库实施计划

## Context（背景）

企业端 [settings/index.vue](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/enterprise_pc/RuoYi-Vue3/src/views/enterprise/settings/index.vue) 的五个 Tab（组织架构、用户权限、面试集成、通知模板、数据管理）目前全是 mock：部门/用户写死在 ref 数组，按钮只弹"接口已预留"toast。

已确认决策：
1. **五个 Tab 全部真实落库**（刷新不丢、跨账号可见）
2. **面试集成仅配置持久化**，不真正调第三方 API
3. **权限模型：公司隔离新接口**——按当前用户 `t_cmp_binding` 的 company_id 隔离数据，HR 账号即可管理本公司（不复用带 `@PreAuthorize` 的 RuoYi 内置接口）

后端复用已验证的 Dashboard/IM 模式（Controller in `ruoyi-admin/web/controller/system` + Mapper XML in `ruoyi-system/resources/mapper/system`，`getUserId()` 取当前用户）。

## 实施顺序（按依赖与价值排序）

### 第 1 步：通知模板（最简单，表已存在）
- 表 `t_msg_template` 已有（tpl_code/tpl_title/tpl_content/tpl_channel/tpl_status），但无后端代码
- 后端：`MsgTemplateController` `/system/msg-template`（list/add/update/delete/toggle），加 `tpl_company_id` 列做公司隔离（ALTER + 更新模块 SQL 文件）
- 前端：模板列表真实加载；新增/编辑弹窗（标题、内容、渠道、变量占位符 `${candidateName}` 等）、启用/停用开关、删除
- 验证：zhangwei/lina 各见各的模板，CRUD 后刷新不丢

### 第 2 步：用户权限（复用 sys_user + t_cmp_binding）
- 后端：`EnterpriseMemberController` `/system/enterprise/member`
  - `GET /list`：本公司成员（join `t_cmp_binding`），返回昵称/部门/角色/状态
  - `PUT /role`：改角色（sys_user_role 更新，角色限 管理员/HR/面试官 三档 → sys_role 已有对应角色则复用，否则用 t_cmp_binding.bnd_job_title 记录）
  - `PUT /status`：启用/停用账号（sys_user.status）
  - `POST /invite`：邀请 = 创建待激活用户 + 绑定记录（bnd_status=0 待审核），返回初始密码
- 前端：成员列表真实加载；角色下拉、状态开关、邀请弹窗（姓名/邮箱/角色/部门）接真实接口
- 验证：停用后该账号无法登录；邀请账号出现在列表

### 第 3 步：组织架构（新建公司部门表）
- 新表 `t_cmp_dept`（dept_id, company_id, parent_id, dept_name, leader_user_id, order_num, status, created_at/updated_at），SQL 追加到模块 SQL 文件；种子数据按公司 1/2 各插几条
- 后端：`CmpDeptController` `/system/cmp-dept`：tree（含每部门成员数、在招岗位数统计）、add、update（名称/负责人/排序）、delete（有子部门或成员时拒绝）、toggle 停用
- 前端：部门树真实加载（缩进/展开保留现有样式），新增/编辑行内弹窗，删除前校验提示；顶部三个汇总卡（部门总数/在职成员/在招岗位）改真实统计
- 验证：新增部门刷新后仍在；删除有成员的部门被拒

### 第 4 步：面试集成（配置持久化）
- 新表 `t_cmp_integration`（id, company_id, provider_code[outlook/tencent_meeting/zoom/livekit], status[0未连接/1已连接/2需配置], config_json, updated_at）
- 后端：`IntegrationController` `/system/integration`：list（按公司）、`PUT /config`（保存 API Key/回调地址等 JSON 配置 + 状态切换）
- 前端：四个集成卡状态真实渲染（已连接/未连接/需配置 pill）；"连接/配置"弹窗保存表单到后端；断开连接
- 验证：Zoom 连接并保存配置后刷新状态保持；两公司互不影响

### 第 5 步：数据管理（导出/备份/清理）
- 后端：`DataManageController` `/system/data-manage`
  - `POST /export-resumes`：按公司导出候选人 CSV（姓名/应聘岗位/状态/入库时间），返回文件下载 URL（写入 `ruoyi.profile` 上传目录）
  - `POST /backup`：mysqldump 不可靠，改为导出本公司核心业务表 INSERT 语句 .sql 文件到 profile 目录并返回下载链接，记录备份时间（t_sys_alert 或简单 config 键）
  - `GET /backup-info`：最近备份时间
  - `POST /cleanup`：清理本公司 `tal_status IN (3,4)` 且流程结束超 2 年的 t_tal 关联数据（先 dry-run 返回影响行数，确认后执行，事务）
- 前端："开始导出"→ 下载 CSV；"立即备份"→ 进度提示 + 更新"最近备份"文案；"进入清理"→ 危险确认弹窗（显示将清理条数）→ 执行
- 验证：导出文件可下载打开；备份时间持久化；清理有二次确认

### 第 6 步：整页收尾
- 顶部"保存更改/重置更改"按钮语义调整：各 Tab 操作即时生效，全局保存按钮移除或改为仅提示（避免与即时保存冲突）
- 系统健康卡接真实数据（后端 `GET /system/data-manage/health`：DB/Redis ping + 关键表计数），可选简化为前端常量→真实
- `mvn package` + `npm run build:prod` + 端到端脚本验证（zhangwei 登录逐 Tab 调用）

## 关键文件

- 后端新增（复用 Dashboard 模式）：`backend/ruoyi-admin/.../controller/system/{MsgTemplate,EnterpriseMember,CmpDept,Integration,DataManage}Controller.java`；`backend/ruoyi-system/.../{mapper,service,service/impl}/...` + 对应 XML
- 前端：`enterprise_pc/RuoYi-Vue3/src/api/system/settings.js`（新）+ 改造 `views/enterprise/settings/index.vue`（拆子组件：DeptTab/MemberTab/IntegrationTab/TemplateTab/DataTab，放 `views/enterprise/settings/` 下）
- SQL：新表 DDL + ALTER 追加到数据库模块 SQL 文件（按项目约定：仅首文件含建库语句）

## 验证（每步都要过）

1. 每步后端：`mvn -q -pl ruoyi-admin -am package -DskipTests` → 重启 jar → PowerShell 登录 zhangwei 调新接口断言
2. 公司隔离：lina（公司2）看不到 zhangwei（公司1）的数据
3. 前端：`npm run build:prod` 通过 + 浏览器逐 Tab 操作验证刷新不丢
4. 全部完成后按 Git 规范提交 `feature/enterprise-settings-YLX` → dev PR
