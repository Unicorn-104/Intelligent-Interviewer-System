# 企业端岗位发布

## 数据与接口

发布复用 `t_pos`，无需数据库迁移。月薪存储单位为人民币元，使用 `DECIMAL(10,2)`；面议时上下限同时为 NULL。学历代码沿用表定义：1 中专、2 大专、3 本科、4 硕士、5 博士，NULL 表示不限。工作性质为 1 全职、2 兼职、3 实习。

`pos_jd_json` 保存 `responsibilities` 与 `requirements` 数组，现有企业详情和求职端岗位浏览可直接读取。岗位技能画像仍由现有 JD 解析流程维护，本次不写入 `t_pos_skill`。招聘流程仍使用 `t_process_template`、`t_process_stage`，发布不自动创建虚构阶段。

- `GET /system/enterprise/jobs/publishing-options`：返回当前账号的 `company: {id, name, city}` 和已有 `departments`。
- `POST /system/enterprise/jobs`：接收 `title`、`dept`、`city`、`salaryMin`、`salaryMax`、`experience`、`education`、`jobType`、`responsibilities`、`requirements`、`status`；成功返回 `data: {posId, title, status}`。
- 公司与发布人由服务端当前登录态决定，忽略客户端传入的公司和发布人字段。普通账号须有已审核企业绑定；管理员沿用现有默认企业约定；企业必须处于正常状态。
- 字段错误使用业务码 400；企业未绑定、企业不存在或停用使用业务码 403。前端依据业务码及 `msg` 展示错误。

## 页面行为

企业端“岗位管理 → 发布岗位”进入独立表单，按基本信息、薪资与任职条件、岗位描述分组，支持真实部门快捷填写、薪资面议、发布前预览、返回修改、未发布离开确认和请求期间防重复点击。成功后返回并刷新岗位列表，提供查看岗位入口。

## 验证

后端 `EnterpriseJobPublishingTest` 覆盖金额与枚举校验、字段长度、JD JSON 转义、企业隔离和生成 ID；`EnterpriseJobMapperTest` 用独立内存数据库运行实际 Mapper 插入并检查回读；`AgentJobPresentationTest` 验证月薪元转 K 与学历映射。

前端 `job_publish_page_test.dart` 覆盖必填、预览及返回修改、防重复提交、薪资范围与面议、企业准入错误及窄屏横屏布局。真实环境联调应另行确认发布、列表、岗位详情与数据库回读。

本次不执行此前暂停的会议、录制和简历 PDF 迁移。凭据不写入代码、文档或日志。


## 本地验证结果

- 企业端 `flutter analyze --no-pub`：通过。
- 企业端 `flutter test --no-pub`：9 项通过（含原有空状态测试）；额外覆盖未发布退出、异常成功响应保护及键盘占位适配。
- Android `flutter build apk --debug --no-pub -t lib/main.dart`：通过，正常 App 已恢复到 Pixel_10a。
- 后端岗位相关测试：8 项通过；Maven 全模块打包通过。
- `EnterpriseJobPublishingDatabaseTest`：使用实际 MySQL 表完成发布、列表、详情回读，并强制事务回滚；回滚后岗位总数不变，无测试岗位残留。该测试默认禁用，仅设置 `JOB_MYSQL_SMOKE=true` 并提供进程环境中的连接信息时运行。
- Pixel_10a：用临时、不可提交的预览入口检查竖屏和横屏发布页面，无溢出；预览入口已删除。
- 尚未验证：正常 App 登录后的 HTTP 发布链路；模拟器目前位于登录页，需要企业端账号，数据库账号不能替代 App 登录。
- 最新 dev 的邮件服务在本地缺少邮件主机配置，本次仅使用进程参数 `--spring.mail.host=localhost` 完成启动，未测试邮件发送，也未修改邮件模块。
