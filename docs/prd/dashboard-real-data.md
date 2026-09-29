# 首页招聘总览接入真实数据

## Context（背景）

企业端首页 `/enterprise/dashboard`（[dashboard/index.vue](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/enterprise_pc/RuoYi-Vue3/src/views/enterprise/dashboard/index.vue)）当前所有数据都是**写死的 mock**：顶部 4 个统计卡、招聘漏斗图、待办事项、最近动态，以及问候语"早上好，王经理"和日期，全部硬编码在组件里（L15-L37），`reserveApi` 只是占位打印、不发请求。

用户要求把这四块 + 问候语全部替换为真实数据。数据库 `recruit_agent` 已具备真实业务表（`t_pos` 岗位、`t_tal` 候选人、`t_res_base` 简历、`t_int_session` 面试会话、`t_sch_appointment` 预约、`t_tal_status_log` 状态流转、`t_cmp_binding` 用户-公司绑定）。

已确认的三项决策：
1. **范围**：全部四块（统计卡 + 漏斗 + 待办 + 动态）都接真实数据。
2. **公司归属**：后端用当前登录用户 ID 查 `t_cmp_binding` 得到 `company_id` 做统计过滤；未绑定用户（如 admin）默认看公司 1。
3. **问候语**：昵称取登录用户 `nickName`，问候语按当前时间动态生成，日期取系统时间。

## 数据口径（全部按 company_id 过滤）

统计卡：
- 在招岗位数 = `t_pos` 中 `pos_company_id=? AND pos_status=1` 计数
- 简历总量 = `t_tal`（company=?）关联 `t_res_base`（`tal_resume_id=rbs_id`）计数
- 待处理面试 = `t_sch_appointment` 关联 `t_pos`（company=?）中 `apt_status IN (0,1)` 计数
- 本周已完成面试 = `t_int_session` 关联 `t_pos`（company=?）中 `ses_status=2 AND ses_end_at` 在本周（周一至今）计数

招聘漏斗（近 30 天，company=?）：
- 简历投递 = `t_tal` 总数
- 初筛通过 = `tal_status IN (1,2,4,5,6,7)`
- 面试中 = `tal_status IN (2,4,7)`
- 已录用 = `tal_status=4`
- 转化率 = 已录用 / 简历投递（保留一位小数）

待办事项（最多 3 条，无数据则显示空态）：
- 待确认面试：`apt_status=0` 的预约（取最近 1 条，文案含候选人昵称 + 岗位 + 开始时间）
- 待终审候选人：`tal_status=7`（笔试通过）候选人（取最近 1 条）
- 即将开始的面试：`apt_status=1` 且 `apt_start_time` 最近的一条

最近动态：`t_tal_status_log` 按 `tsl_created_at` 倒序取最近 4 条，关联 `t_tal`→`sys_user` 取候选人昵称，文案由 `tsl_to_status` 映射为中文（0 新入库/1 初筛通过/2 面试中/3 已淘汰/4 已录用/5 待笔试/6 笔试中/7 笔试通过/8 笔试未通过/9 笔试缺考），时间显示相对值（分钟前/小时前/昨天 HH:mm）。

## 实施方案

### 后端（复用 IM 模块模式）

1. **Mapper 接口** [DashboardMapper.java](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/backend/ruoyi-system/src/main/java/com/ruoyi/system/mapper/DashboardMapper.java)
   - `Long selectCompanyIdByUser(Long userId)`（查 `t_cmp_binding` 中 `bnd_status=1`）
   - 各统计返回 `int`/`Map` 的计数方法；漏斗返回一个 `Map<String,Object>`；待办/动态返回 `List<Map<String,Object>>`。

2. **Mapper XML** `backend/ruoyi-system/src/main/resources/mapper/system/DashboardMapper.xml`
   - `namespace="com.ruoyi.system.mapper.DashboardMapper"`，纯 `<select resultType="...">`，无需 resultMap（返回 Map/List<Map>）。
   - 沿用 ImSessionMapper.xml 的表别名与 join 风格。

3. **Service** `IDashboardService.java` + [DashboardServiceImpl.java](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/backend/ruoyi-system/src/main/java/com/ruoyi/system/service/impl/DashboardServiceImpl.java)
   - `@Service`，注入 DashboardMapper。
   - `Map<String,Object> getOverview(Long userId)`：先解析 companyId（null→默认 1L），组装 `{ stats:{...}, funnel:{...}, todos:[...], timeline:[...] }`。

4. **Controller** [DashboardController.java](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/backend/ruoyi-admin/src/main/java/com/ruoyi/web/controller/system/DashboardController.java)
   - `@RestController @RequestMapping("/system/dashboard")` 继承 `BaseController`。
   - `@GetMapping("/overview")` → `AjaxResult.success(dashboardService.getOverview(getUserId()))`。
   - 不加 `@PreAuthorize`（与 IM 模块一致，登录即可访问）。

### 前端

5. **API** 新建 [api/system/dashboard.js](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/enterprise_pc/RuoYi-Vue3/src/api/system/dashboard.js)
   - `getDashboardOverview()` → `request({ url:'/system/dashboard/overview', method:'get' })`（复用 im.js 模式）。

6. **页面** 改造 [dashboard/index.vue](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/enterprise_pc/RuoYi-Vue3/src/views/enterprise/dashboard/index.vue)
   - 删除 mock 常量与 `reserveApi` 调用，改为 `ref` 状态 + `onMounted` 调 `getDashboardOverview()` 填充。
   - 问候语：`userStore.nickName`（[user.js](file:///d:/java/JavaProgram/Intelligent-Interviewer-System/enterprise_pc/RuoYi-Vue3/src/store/modules/user.js#L49) 已有）+ 按当前小时生成"早上好/中午好/下午好/晚上好"；日期用 `new Date()` 格式化为"YYYY年M月D日 星期X"。
   - 漏斗高度按 `value / 简历投递` 计算百分比；转化率取接口值。
   - 待办/动态为空时显示占位文案。

## 验证

1. 后端：`cd backend ; mvn -q -pl ruoyi-admin -am package`，重启 jar（8080）。
2. 用 PowerShell 脚本登录 `zhangwei`（公司1）拿 token，`GET /system/dashboard/overview`，核对返回 JSON 的 stats/funnel/todos/timeline 与数据库手算一致（在招岗位=4、简历=10 等公司1口径）。
3. 前端 `npm run build:prod` 通过；浏览器访问 http://localhost:81/enterprise/dashboard，确认四块数据与问候语均为真实值、随登录账号变化。
4. 用 `lina`（公司2）登录，确认统计口径切换到公司2（在招岗位=2）。
