# 企业端人才发现与主动沟通

## 院校与期望薪资补充（2026-10-23）

- 卡片和基础详情新增毕业院校、专业、毕业年份、本人期望薪资，继续展示期望岗位与城市，不引入AI评分、内部标签或公司招聘状态。
- 院校选择本人当前默认有效简历中最高已完成的教育记录（结束日期不晚于今天、有效学历1–5）；同学历按毕业时间和教育记录ID排序。未来毕业的在读经历不会伪称毕业院校。毕业字段未填写则如实展示未填写。
- 学校/专业/毕业时间复用现有教育字段；期望岗位优先使用本人target_direction，否则读取当前有效简历的jobDirection。
- 期望薪资使用新增t_usr_job_preference：salaryMin/Max为人民币税前月薪整数元，salaryNegotiable=NULL未填写、1面议、0明确区间。保留未知与0元差异，不使用工作历史薪资或岗位薪资代替。
- DDL记录于e-app/new.sql的BEGIN TALENT_EXPECTATION_20261023段，只执行本次CREATE TABLE，不回填真实用户，不重放历史SQL。
- 求职者在c-app编辑资料的求职信息中本人填写，通过原PUT /app/profile保存并由登录态固定本人userId；旧请求不传薪资时保留已有值，显式全NULL清除。资料与薪资在同一事务更新。
- 数据库CHECK与服务端同时限制完整区间、合法模式和0≤下限≤上限≤10000000；面议与明确区间互斥。无账号填写前薪资显示未填写。
- 回滚先退应用代码并保留新表和用户意向；删表和清理数据需后续授权。

## 当前行为：我的 → 人才库（2026-10-23）

- 此入口是全站已注册求职者发现，不是本公司投递管理。登录企业需有有效企业绑定；账号必须是正常、未删除的求职者，排除管理员和企业招聘者。
- 查询从 `sys_user` 出发，不要求 `t_tal`、投递或本企业关联记录；没有简历的注册求职者仍可被搜索，缺失信息如实显示未填写。
- 只展示昵称、头像、城市、求职状态、最高学历、工作经验汇总与期望岗位。列表和详情均不返回/展示企业招聘状态、内部标签、AI/匹配评分、岗位ID、招聘轮次或面试入口。
- 公开目录不返回手机号、邮箱、账号密码和原始简历链接；搜索输入为姓名或期望岗位，联系方式请在沟通中向本人确认。手机号/邮箱式昵称显示通用名称。
- 求职状态采用用户本人资料的1在职考虑机会、2离职随时到岗、3应届生，不复用公司招聘流程状态。其余筛选仍由后端过滤后分页；活跃度沿用最近登录口径，不代表实时在线。
- 保留已确认的青绿搜索栏及白色输入区域镜像圆角，同页筛选锚点、清除/确认和条件回显不变。
- `GET /enterprise/talent-discovery`：keyword、direction、currentStatus、minimumEducation、experienceRange、city、cityType、loginWithinDays、pageNum/pageSize；列表返回 rows/total/code，资料包含 directoryVersion=1。
- `GET /enterprise/talent-discovery/options`：真实注册账号的期望岗位/城市选项；不提供企业内部标签。
- `GET /enterprise/talent-discovery/{userId}`：公开基础资料详情，按真实用户ID，不是talentId。
- 点击“主动沟通”直接进入该用户聊天页，不再弹出招呼语面板。使用真实 userId 精确查找已有 IM 会话；无会话也可输入消息，明确发送首条文字时后端才创建/复用真实会话。进入页面不自动发消息，超时不自动重发。
- 人才发现来源聊天不加载企业岗位上下文；点击头像查看公开基础资料。首条文字发送成功后可继续发送图片/文件。
- 旧 `/enterprise/talent/*`、`TalentDetailPage` 和岗位候选人管理保持企业权限边界，绝不作为目录接口未部署时的降级数据源。
- 本次无DDL/DML、无业务数据导入。H2合成测试刻意不创建企业人才/投递/AI/流程表；真实MySQL只读验证字段和数量，不输出个人资料、不主动联系真实用户。

## 平台目录验证

```powershell
cd backend
mvn -o -pl ruoyi-admin -am test "-Dtest=TalentDiscoveryTest,TalentDiscoveryControllerTest,TalentSearchMapperTest,TalentSearchServiceTest,TalentSearchControllerTest" "-Dsurefire.failIfNoSpecifiedTests=false"
cd ../e-app
flutter test --no-pub test/talent_directory_test.dart test/profile_page_test.dart
flutter analyze --no-pub
flutter test --no-pub
```

## 历史企业候选人管理兼容说明（不是当前“我的 → 人才库”）

以下记录原企业候选人数据源、接口与测试的兼容行为，不表示全站目录仍限于本企业。

## 使用方式

1. 进入「我的 → 人才库」。列表仍只展示当前企业有权限访问的候选人。
2. 输入姓名或手机号搜索；点击搜索栏右侧「筛选」，按求职方向、招聘状态、学历要求、工作经验、城市和活跃度六类条件组合筛选。候选人标签和归档来源入口已移除，不再从本页面发送这两类查询条件；底层接口保留兼容。
3. 筛选面板覆盖底部导航，选项采用等宽网格（窄屏大字号下自动单列），底部操作固定。筛选条件按区块排列在同一个可滚动页面中，左侧分类仅定位对应区块，滚动时联动高亮，不切换子页面。筛选面板内的更改是草稿。「确定」才应用；「清除」只清除草稿；关闭面板不影响已应用条件。列表上方「清除条件」立即重置查询。
4. 点击候选人卡片查看原人才详情；点击「主动沟通」核对真实账号和已有会话。
5. 已有会话可直接进入；首次联系须手动填写招呼语，明确点击「发送并进入聊天」后才发送首条消息并进入现有聊天页。

## 复用接口

- `GET /enterprise/talent/list`：`keyword`、`tag`、`direction`、`status`、`archiveSource`、`minimumEducation`、`experienceRange`、`city`、`cityType`、`loginWithinDays`、`pageNum`、`pageSize`；新增参数均可省略，旧 PC/App 请求不变。
- `GET /enterprise/talent/options`：读取当前企业已有求职方向、标签、所在城市和期望城市；`searchFilterVersion: 2` 表示支持新筛选。
- `GET /enterprise/talent/{talId}`：校验 `talentId`，读取真实 `userId`；不能将人才编号当作聊天账号。
- `GET /system/im/sessions`：以 `peerId == userId` 精确查找会话，不能按姓名猜测。
- `POST /system/im/messages`：首次联系发送 `peerId`、`type: 1`、`content`，使用响应中的真实 `sessionId` 打开聊天。

生产数据源使用服务端分页筛选，支持持续加载后续页，不再使用原客户端状态筛选的三页扫描方式。旧的注入式 loader 保留有界扫描行为，仅用于既有预览/测试适配兼容。

## 边界与安全

- 高级筛选沿用已有后端可选查询参数；本次筛选界面调整未修改 Backend 接口或数据库结构，也没有执行迁移或 DDL。
- 当前 API 仍不是全站公开人才市场。期望薪资没有启用；迁移设计见 `../../backend/doc/talent-search-salary-migration-proposal.md`，仅供审批，不执行。
- 学历按当前归属简历的最高有效学历筛选。编码 1 中专、2 大专、3 本科、4 硕士、5 博士，采用“及以上”门槛，资料缺失不匹配指定条件。
- 工作经验按有效工作经历的月份区间取并集：重叠/嵌套/相邻不重复，间隔时间不计；在职结束取当前月，未来结束日期封顶至当前月；缺失开始日期、已离职且缺失结束日期、结束早于开始的记录不计。无有效记录返回 NULL，不归入“1年以内”。这是月份粒度工作经历，不是工作能力评分。
- 经验范围：`lt1`=[0,12) 月、`1to3`=[12,36)、`3to5`=[36,60)、`5to10`=[60,120)、`gte10`=[120,+∞)。
- 城市为已填写字符串的精确匹配，`cityType=target` 期望城市（默认）或 `current` 所在城市，不推断地理位置。
- `loginWithinDays` 仅允许 1/3/7/14/30/90，页面展示为「活跃度」，仍按服务端最近一次账号登录时间过滤，不代表实时在线、行为活跃或回复意愿；面板内明确标注此口径。无登录时间或未来日期不匹配。
- 高级筛选需先部署新版 Backend。App 会核验选项能力版本及结果标记；旧服务不会被误报为“高级筛选成功”。未绑定企业的查询不再兜底到企业1，明确拒绝。
- 请求返回与指定状态/方向/归档来源不一致时明确报错，避免旧版本服务器忽略条件却误展示“筛选成功”。
- 打开卡片或主动沟通弹层不会自动发消息，不批量联系候选人。
- 发送中禁用重复提交。超时或响应缺少有效会话编号时进入待核对状态，只允许刷新查找已有会话，不自动重发。
- 合成测试不连接真实数据库、不联系真实候选人；安装/启动不等于完成线上双向送达验收。

## 验证

```powershell
cd e-app
flutter analyze --no-pub
flutter test --no-pub test/talent_discovery_api_test.dart test/talent_discovery_page_test.dart test/talent_page_test.dart test/talent_pool_data_source_test.dart
flutter test --no-pub
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

覆盖组合条件、草稿取消/清除、跨页加载、错误重试、精确身份关联、已有会话复用、首次显式发送、发送结果待核对、退出后迟到响应，以及 320dp / 横屏 / 二倍字号 / 键盘场景。部署后需由 HR 使用获授权的测试账号人工确认双向消息送达。

## 本轮后端测试

```powershell
cd backend
mvn compile
mvn -pl ruoyi-admin -am test "-Dtest=TalentSearchControllerTest,TalentSearchServiceTest,TalentSearchMapperTest" "-Dsurefire.failIfNoSpecifiedTests=false"
```

Mapper 回归只创建随机命名的 H2 内存库和合成数据，不读取应用数据源配置，不访问或修改业务数据库。SQL 使用区间自连接合并月份，不要求 MySQL 8 窗口函数。目标 MySQL 的 SQL 执行计划/性能以及真实数据完整度需要部署前人工核验。
