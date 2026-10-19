# 企业端岗位信息编辑

## 行为与范围

岗位详情“基础信息”的信息卡右上角提供“编辑”。复用 `JobPublishPage` 的表单、文档导入、字段校验、技能编辑和预览，读取当前服务端数据后回填，不以列表摘要作为保存内容。进入编辑和预览不写入；点击“保存修改”后才提交。保存中阻止重复提交与返回，失败保留预览及修改内容并允许重试，取消不写入。

可修改：名称、部门、城市、薪资或面议、经验、学历、工作性质、工作职责、任职要求与技能。编辑不包含招聘流程的新增或覆盖；招聘状态继续走已有独立入口。保留未列入表单的原 JD JSON 字段，包括 PC 的 description、summary、softRequirements。

## 接口与数据

- 新增 `PUT /system/enterprise/jobs/{posId}`，请求字段与发布岗位基本信息一致，返回 `{posId, title, status}`。当前登录用户由服务端确定，忽略客户端传入的企业、发布者、状态或流程身份。原 API 函数签名不变。
- 沿用 `GET /system/enterprise/jobs/publishing-options` 获取真实企业与部门，`GET /system/enterprise/jobs/{posId}` 增加 skills 数组（数据库技能行，必备标识可为空），用于完整回填。无效 ID、技能或正文格式会阻止编辑，避免误覆盖。
- 后端使用实际企业绑定并校验企业状态。按岗位和企业组合条件锁定已有记录，复用发布字段校验，更新现有 t_pos；可显式传 skills 替换对应 t_pos_skill。省略 skills 则保留原技能，空数组表示清空。岗位与技能修改在同一事务中执行，失败回滚。
- 不改变岗位 ID、所属企业、发布者、创建日期、招聘状态、流程模板、既有投递或预约记录；编辑不触发关注者的新岗位通知。保存后回读详情与技能，返回列表后沿用原列表刷新，保留排序选择。
- 无数据库结构变更或数据迁移，不追加 new.sql；未操作本地数据库备份与 docs/sql-audit。

## 验证与回滚

Backend 的 EnterpriseJobSkillsTransactionTest 使用隔离 H2 与实际 Mapper XML 验证事务、企业隔离、字段校验、技能替换失败回滚、原 JD 扩展字段保留、状态和流程不变以及不重复发通知；EnterpriseJobPublishingTest 继续覆盖原发布逻辑。测试使用合成数据，不访问真实数据库。

Flutter 的 job_edit_page_test.dart 验证回填、确认前无写入、防重复、失败重试、取消和读取失败、保存后详情刷新、技能空标识保留及 320dp/横屏/键盘布局。发布、流程和详情沿用原测试回归。

回滚时撤销本次前后端增量并重新部署；不需要数据库回滚。已成功保存的业务字段不会随代码回滚自动恢复，恢复业务内容需通过受控编辑。

## 2026-10-19 实际验证结果

- 修改的6个Dart文件格式检查通过，`flutter analyze --no-pub` 无问题。
- `flutter test --no-pub --reporter expanded` 全部493项通过。
- `mvn -o -pl ruoyi-system -am -Dtest=EnterpriseJobPublishingTest,EnterpriseJobSkillsTransactionTest,EnterpriseJobMapperTest -Dsurefire.failIfNoSpecifiedTests=false test`：21项通过。
- `mvn -o -DskipTests package`：全部7个模块构建成功；`flutter build apk --debug --no-pub` 成功。
- 新版后端已重启并确认验证码接口 HTTP 200、业务码200；继续沿用本次会话已有的本机邮件占位参数，邮件不可发出。
- Pixel_10a（emulator-5554）已覆盖安装新版，确认信息卡编辑入口、真实字段回填、预览及保存按钮、未保存返回；没有对真实岗位执行保存。保存成功、失败重试、防重复及事务回滚使用合成数据自动验证，不能视为真实岗位写入的完整人工验收。
- 无数据库迁移、未改动new.sql，未提交或推送。
