# 智聘 AI · RuoYi

基于官方 RuoYi Vue3 前端基座迁移，保留智聘 AI 求职者端，并配套官方 RuoYi-Vue Java 后端。

## 目录

- `src/`：RuoYi Vue3 管理端与智聘 AI 求职者端
- `src/views/agent/pages/`：求职者端页面
- `backend/`：RuoYi-Vue Java 后端

## 启动前端

```powershell
npm install
npm run dev
```

- 管理端：`http://127.0.0.1:5180/`
- 求职者端：`http://127.0.0.1:5180/agent/index`
- 后端代理：默认转发到 `http://localhost:8080`

开发环境默认启用纯前端模式，打开根地址会直接进入求职者端，不依赖后端服务。
后端接口、API 模块和代理均已保留；接入后端时将 `.env.development` 的 `VITE_FRONTEND_ONLY` 改为 `'false'`，并重启前端即可。

## 启动后端

进入 `backend` 目录，按官方 RuoYi-Vue 的数据库与 Java 环境要求启动；前端接口代理已配置为 `localhost:8080`。

## 求职者端接口契约

数据库与业务后端接入前，请以 [求职者端接口契约](docs/agent-api-contract.md) 为准。该文档定义了候选人端的接口、字段、枚举、错误码、幂等规则，以及页面到接口的映射；RuoYi 原有管理端接口保持不变。

## 质量检查与部署

运行 `npm run check` 可执行候选人端基础校验测试和生产构建；发布前请参阅 [部署与发布检查](docs/deployment.md)。

## 简历回填与 PDF 识别

- 新建简历通过 `GET /app/profile` 读取本人基础资料，映射姓名、性别、求职状态、城市、手机号、邮箱及求职方向；编辑已有简历不自动覆盖已保存信息。基础资料读取失败时仍可手动填写。
- 编辑页扫描和简历列表直接上传 PDF 均优先保留已填基本信息及求职意向，PDF 只补充空白字段。编辑页替换已有经历或技能前需确认；PDF 中缺失的栏目不清空原内容。
- AI 编排区分学习、任职与项目客户等语义，合并工作和实习经历；未配置 AI 时规则识别严格按栏目处理，不再全篇匹配公司/学校或逐两行创建项目。
- 规则识别支持经历名称与起止时间分行，以及“时间 / 任职时间 / 项目时间”标注；同栏目按前置或后置日期顺序匹配，不跨栏目套用。仅有年月时补为当月 01 日并提示核对；“至今”的工作经历保留开始时间并标记目前在职。没有对应经历的日期保留到未归类原文，仍需人工核对混合或双栏版式。已有简历不会自动重扫，需重新上传 PDF 或在编辑页重新解析后保存。
- 大专、中专及未知学历均可正确显示；日期适配日期输入框。不能确定的日期归属、非法日期和未归类原文保留提示供人工核对，不能保证所有扫描版式均准确识别。原 PDF 仍通过原有导入接口作为附件保存。
- 前端回归：`node --test test/agentResume.test.js`；后端回归：在 `backend/` 执行 `mvn -pl ruoyi-system -am -Dtest=ResumeRuleStructurerTest,ResumeAiFieldMapperTest,LocalResumePdfParserTest,ResumePdfPersistenceTest -Dsurefire.failIfNoSpecifiedTests=false test`。使用合成数据及内存数据库，不写真实用户简历。

## 收藏岗位计数

- 收藏仍保存在浏览器本地；本次不迁移收藏、不修改服务端收藏数据。
- 岗位列表接口新增可选 `jobIds` 参数，格式为逗号分隔的正整数 ID，每次最多 200 个；不传时保持原查询行为，显式空集合不返回全部岗位。岗位和企业可用性、搜索及筛选条件对列表和分页总数一致生效。
- 岗位浏览页按收藏 ID 向真实岗位接口查询，分批、分页加载全部匹配的收藏，不再仅从普通列表前 50 条中筛选。收藏数字表示当前条件下可查看的收藏岗位数量，与收藏列表共用结果；失效岗位不计数，但不删除本地记录，清除筛选不会丢失其他收藏。
- 收藏/取消、窗口重新聚焦和其他标签页修改会同步更新；加载失败显示未知数量及错误提示，不伪报零收藏。
- 验证：`node --test test/agentSavedJobs.test.js`；后端执行 `mvn -pl ruoyi-system -am -Dtest=AgentJobMatchScoreTest,AgentJobQueryTest,AgentJobPresentationTest -Dsurefire.failIfNoSpecifiedTests=false test`，使用合成数据和 H2 内存数据库。
