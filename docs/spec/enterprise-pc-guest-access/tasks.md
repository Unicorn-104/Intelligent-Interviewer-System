# 实施任务

## 后端

1. [x] `CompanyMapper.java` 增加企业名称精确查询、绑定插入/查询/批量状态更新、用户 company_id 更新方法。
2. [x] `CompanyMapper.xml` 扩展 `insertCompany` 可选列，新增上述语句。
3. [x] 新增 `IEnterpriseRegisterService` / `EnterpriseRegisterServiceImpl`：注册校验、企业+用户+绑定+角色事务写入、账号状态查询。
4. [x] `SysRegisterController` 增加 `@Anonymous POST /register/enterprise`（含验证码校验）。
5. [x] `CompanyServiceImpl.verifyCompany` / `resetVerify` 同步 `t_cmp_binding.bnd_status`。
6. [x] 新增 `EnterpriseAccountController`：`GET /enterprise/account/status`。
7. [x] 编译验证：`mvn -q -pl ruoyi-system,ruoyi-admin -am compile`（同时修复了 HEAD 上已存在的两处考试模块编译错误，详见交付说明）。

## 前端

8. [x] 新增 `src/api/portal.js`。
9. [x] 新增 `PortalLayout.vue`、`home.vue`、`features.vue`、`onboarding.vue`（企业视角，不含候选人岗位列表）。
10. [x] 新增企业注册页 `views/enterprise/register/index.vue`。
11. [x] 新增待审核页 `views/enterprise/pending/index.vue`。
12. [x] `router/index.js` 增加门户、企业注册、待审核路由。
13. [x] `permission.js` 增加公开路径放行与待审核拦截。
14. [x] `login.vue` 增加“先逛逛”入口。
15. [x] 构建验证：`npm run build:prod`。

## 验收

16. [x] 匿名接口 200 校验：`GET /api/v1/agent/v1/jobs` 返回 200。
17. [x] 门户游客浏览已通过浏览器验证：首页展示企业视角的平台能力与入驻流程，无候选人岗位卡片；平台能力/入驻流程路由正常；`POST /register/enterprise` 已连通并返回验证码校验，`GET /enterprise/account/status` 未登录返回 401。完整注册-审核-登录链路仍需人工处理图形验证码并在后台点击审核。
18. [x] 检查未改动 `admin_pc`、`c-app`、`e-app`、`user-PC`。
