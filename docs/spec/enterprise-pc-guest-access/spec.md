# 企业 PC 游客浏览与企业自助注册

## 目标

企业 PC（`enterprise_pc/RuoYi-Vue3`）支持未登录浏览企业端公开门户；企业可通过自助注册提交入驻申请，注册后进入待审核状态，平台审核通过后才能使用企业后台。不修改 `admin_pc`、`c-app`、`e-app`、`user-PC`。

## 页面权限边界

游客可访问（无需登录）：

- `/enterprise/portal`：企业端门户首页（平台能力、招聘工作台、入驻流程）
- `/enterprise/portal/features`：平台能力介绍
- `/enterprise/portal/onboarding`：企业入驻流程、所需信息与常见问题
- `/enterprise/login`：企业登录
- `/enterprise/register`：企业自助注册

必须登录（企业角色 `admin/biz_1/biz_2/biz_3`）：

- `/enterprise/pending`：待审核提示页（已登录、未审核通过的企业用户）
- 其余 `/enterprise/**`：总览、岗位管理、候选人、筛选、人才库、面试、会议、笔试、发送、Offer、消息、AI 助手、搜索、设置、个人中心

游客页面展示企业招聘平台能力与入驻说明，不展示候选人视角的岗位列表、薪资与投递入口。游客页面不挂载 `EnterpriseLayout`、侧边栏、顶栏轮询、AI 助手球和欢迎引导，不请求任何个人/企业私有接口。登录页与注册页提供“先逛逛”入口返回 `/enterprise/portal`。

## 企业自助注册

新增匿名接口 `POST /register/enterprise`（`SysRegisterController`，`@Anonymous`），请求体字段：

- `username`、`password`：账号密码，长度 2-20 / 5-20
- `companyName`：企业全称，必填，精确重复校验
- `creditCode`：统一社会信用代码，可选
- `industry`、`city`、`companySize`：可选
- `contactName`：联系人，必填
- `phone`：联系人手机号，必填，`^1[3-9]\d{9}$`，需唯一
- `email`：可选
- `code`、`uuid`：图形验证码（仅在系统开启验证码时校验）

一个事务内完成：

1. `t_cmp` 新增企业：`cmp_verify_status=0`（待审核）、`cmp_status=1`（正常）、写入名称/信用代码/行业/城市/规模/联系人/联系电话/创建时间
2. `sys_user` 新增用户：`user_identity_type=2`（HR）、`status='0'`、BCrypt 密码、`pwd_update_date=now`、写入 `company_id`
3. `t_cmp_binding` 新增绑定：`bnd_status=0`（待审核）、`bnd_job_title='企业管理员'`、时间戳
4. `sys_user_role` 授予 `biz_1`（企业超级管理员）角色

注册成功不自动登录，返回“注册成功，请等待平台审核”。该接口不受 `sys.account.registerUser` 开关限制（企业入驻是带审核的独立流程）；图形验证码沿用 `SysRegisterService.validateCaptcha`。

失败返回明确错误：账号已存在、手机号已注册、企业名称已注册、系统未配置企业角色。

## 审核状态同步

- `CompanyServiceImpl.verifyCompany(cmpId, verifyStatus, verifyBy, rejectReason)`：在更新 `t_cmp` 后，按同一 `cmpId` 更新 `t_cmp_binding.bnd_status`：审核通过=1、驳回=2、其他=0。
- `CompanyServiceImpl.resetVerify(cmpId)`：同步将绑定重置为 0（待审核）。
- 保留 `resetVerify` 原有清空 `cmp_verify_at/cmp_verify_by/verify_remark` 的行为。

## 账号状态接口

新增 `GET /enterprise/account/status`（需登录，`BaseController.getUserId()`）返回：

```json
{
  "companyId": 1,
  "companyName": "示例企业",
  "bindingStatus": 0,
  "companyVerifyStatus": 0,
  "rejectReason": null
}
```

数据取该用户最新一条 `t_cmp_binding`，左连接 `t_cmp`。无绑定返回 `bindingStatus=null`。

## 前端实现

- `src/api/portal.js`：`registerEnterprise`、`getAccountStatus`。
- `src/views/enterprise/portal/PortalLayout.vue`：独立门户头（Logo、首页、平台能力、入驻流程、登录、企业注册）+ `router-view`。
- `src/views/enterprise/portal/home.vue`：企业视角首页，展示平台定位、招聘工作台、全流程能力、入驻步骤与注册引导。
- `src/views/enterprise/portal/features.vue`：平台能力详情（岗位管理、AI 简历筛选、面试安排、在线笔试、人才库、组织与看板）。
- `src/views/enterprise/portal/onboarding.vue`：入驻流程、注册所需信息、审核说明与常见问题。
- `src/views/enterprise/register/index.vue`：企业注册表单（含图形验证码与“先逛逛”）。
- `src/views/enterprise/pending/index.vue`：读取 `getAccountStatus` 展示待审核/已驳回原因，提供刷新与退出。
- `src/router/index.js`：新增 `/enterprise/portal`（PortalLayout 嵌套 `''`、`features`、`onboarding`）、`/enterprise/register`、`/enterprise/pending`；现有登录路由与后台路由保持不变。
- `src/permission.js`：
  - 公开路径判断：`/enterprise/login`、`/login`、`/enterprise/register`、`/enterprise/portal` 及其子路径。
  - 无 token：公开路径放行，其余跳登录并带 `redirect`。
  - 有 token：登录/注册页跳 `/enterprise/dashboard`；公开路径放行。
  - 首次拉取用户信息后，对非 `admin` 的企业角色调用 `getAccountStatus`；`bindingStatus !== 1` 时跳 `/enterprise/pending`（已在 pending 则直接放行）；`bindingStatus === 1` 且在 pending 时跳 `/enterprise/dashboard`。
- `src/views/login.vue`：增加“先逛逛”链接到 `/enterprise/portal`。

## 数据层改动

`CompanyMapper` 增加：

- `selectCompanyByNameExact(@Param("cmpName"))`
- `insertEnterpriseBinding(userId, companyId, jobTitle, status)`
- `selectBindingStatusByUser(userId)`
- `updateBindingStatusByCompany(companyId, status)`
- `updateUserCompanyId(userId, companyId)`

`CompanyMapper.xml`：

- `insertCompany` 补充可选列 `cmp_size`、`cmp_city`、`contact_name`、`contact_phone`、`cmp_verify_status`（均为 `<if>`，不影响既有调用）。
- 新增上述查询/写入语句；绑定状态更新同时刷新 `bnd_updated_at`。

新增 `IEnterpriseRegisterService` 与 `EnterpriseRegisterServiceImpl`（`ruoyi-system`），使用 `CompanyMapper`、`ISysUserService`、`SysRoleMapper`、`ISysConfigService`。

## 验收

- 后端：`mvn -q -pl ruoyi-system,ruoyi-admin -am compile` 通过；企业注册/审核/状态接口有对应单元测试或至少编译通过。
- 前端：`npm run build:prod` 通过。
- 浏览器验证：游客打开门户首页，展示“让企业招聘更智能、更高效”、平台能力与入驻流程，不出现候选人岗位卡片；点击“平台能力”“入驻流程”可正常跳转。
- 手动流程：注册 → 提示待审核 → 登录进入待审核页 → 后台审核通过 → 重新登录进入 `/enterprise/dashboard`。
- 未审核/驳回账号直接访问 `/enterprise/dashboard` 被重定向到 `/enterprise/pending`。
- `admin` 账号不受待审核拦截影响。

## 回滚

回滚本次前后端文件即可；公开岗位接口原本就是匿名，无数据库迁移、无新增依赖。已有注册数据保留，不执行删除。
