# 用户 PC 端六项完善

## 功能与接口

1. 真实企业与 HR 资料：企业主页和企业岗位使用现有 GET /app/companies/{id}、GET /app/companies/{id}/jobs；关注使用 PUT /app/companies/{id}/follow。新增 GET /agent/v1/contacts/{id}，登录后仅返回有效企业绑定 HR 的公开编号、昵称、头像和企业信息，不返回账号、手机号、邮箱或权限。非法编号、下架、请求失败均显示真实状态，不回退到示例人物或企业。岗位详情和消息会话详情提供入口。
2. 页面样式隔离：用户端旧全局样式增加各自 candidate-page--页面名 命名空间；body/html/:root 的规则迁移到页面根节点；动画名称也隔离。保留动态 innerHTML 内容所需的普通 CSS，并为图片预览 Teleport 提供对应命名空间。已有 scoped 页面不再使用 :global(body) 等跨页覆盖。
3. 收藏持久化：使用现有 GET /app/jobs/favorites、GET/PUT /app/jobs/{id}/favorite。身份由服务端登录上下文确定；首页、列表、详情共用账号收藏。完整分页读取收藏，在返回前台时重新同步。成功后更新 UI；请求失败保留错误状态，不显示虚假成功或零收藏。无法确认归属的旧 zhipin-ai-saved-jobs 不自动迁移，避免串号。
4. 简历编辑保护：字段修改与最后一次成功保存内容比较；站内离开和刷新/关闭时提醒。文字草稿按账号和简历编号存入当前标签页 sessionStorage，24 小时有效，可恢复或丢弃。新建保存后跳转真实简历编号；保存失败保留草稿，成功后清除。PDF 二进制和未上传附件不写浏览器草稿，恢复时提示重新选择 PDF。关闭标签页或浏览器清理存储可能导致草稿消失，草稿不能替代服务器保存。
5. 消息分页：新增 GET /system/im/sessions/{sessionId}/messages/page，参数 size 默认 30、上限 100，beforeId 和 afterId 必须为互斥的正整数。响应 data 包含升序 items 与 hasMore。首次读取最新页，加载更早消息时保留阅读位置；5 秒轮询只读取 afterId 之后的新消息，空增量不替换数组。前端去重排序、切会话丢弃旧请求，失败可重试，未追完增量时不清除未读角标。会话归属由后端验证，撤回消息不出现在查询结果。保留旧全量接口以兼容企业端和 App。
6. 岗位分享：复制包含实际部署 BASE_URL 的完整职位详情地址；优先 Clipboard API，失败时尝试浏览器复制命令，均失败则明确提示手动复制，不再虚报成功。

原静态模拟面试页改为已有 AI 助手的“面试准备”模式，支持选择真实简历和已投递岗位、保存 AI 会话历史；不再用固定题库或完成率冒充面试能力评分。AI 回答仍依赖已配置并可访问的后端模型服务，不宣称新增视频面试评测或经过校准的能力评分。

结构化消息使用独立卡片呈现岗位、面试与改期通知，会话预览和右侧摘要不再直接显示 JSON。消息正文不使用 HTML 注入，跳转地址经过协议及目标校验；无法识别的结构化内容降级为安全摘要，不阻断其他消息及已读处理。

## 验证与边界

- 用户 PC：npm run test:unit；npm run build:prod。
- 后端：Maven 对 ruoyi-admin 及依赖模块执行 ImServiceMessageTest、RecruiterPublicMapperTest、AgentContactControllerTest、AppCompanyServiceTest。
- 浏览器使用隔离合成接口响应验证：首页与消息/基础资料往返样式、企业与 HR 跳转、收藏/关注操作、消息最新页/历史页/增量、滚动位置、简历离开保护与恢复；消息卡片在 320、390、700、900、1050、1440 像素屏宽检查溢出。此结果不等同于生产环境或企业端真实账号互发验收。
- 测试不创建真实用户、岗位、简历或聊天记录；不执行生产迁移，不修改其他客户端。

## 部署与回滚

本轮没有新增数据库表或迁移。收藏/关注依赖现有业务表和服务端接口；新联系人和消息分页接口需要同步更新本地或服务器后端 JAR，不能仅发布前端静态文件。服务器前端仍部署到 /user/，需保留 SPA history 路由回退配置。

上线前需使用专用测试账号完成真实企业消息、多端收藏和目标服务器接口验收；不得用自动化合成数据验证代替生产验收。回滚时将前后端一起回滚到上一套兼容版本；旧全量消息接口未删除，无须回滚数据库。浏览器草稿仅是临时恢复数据，不作为服务器数据迁移来源。


## 本轮本地验证记录（2026-11-17）

- 前端单元测试 144/144 通过；生产构建通过；git diff --check 通过。
- 后端相关测试 21/21 通过（消息 13、企业资料 5、HR Mapper 1、HR 控制器 2），Maven 编译和最终 JAR 打包通过。
- 本地后端已用新 JAR 重启，8080 监听正常；5180 前端保持运行。匿名公开岗位请求返回 code=200；HR 和分页聊天接口未登录返回 code=401。
- 浏览器隔离接口回归及消息卡片六种屏宽检查通过。未进行生产发布，也未使用真实企业/候选人账号写入业务数据；真实双端互发及服务器验收仍需专用测试账号完成。

## 同步 dev 后的交付验证（2026-11-18）

- 保留当前 feature 分支，以普通合并同步 `origin/dev`（`73ea0fd`），未改写共享历史；PR 相对 dev 仅包含本轮用户 PC 完善与必要后端、测试和文档。
- `npm run test:unit`：144/144 通过；`npm run build:prod`：通过。
- Backend `mvn -pl ruoyi-admin -am -DskipTests compile`：通过。
- 相关 Maven 测试命令：`mvn -pl ruoyi-admin -am -Dtest=ImServiceMessageTest,AppCompanyServiceTest,RecruiterPublicMapperTest,AgentContactControllerTest -Dsurefire.failIfNoSpecifiedTests=false test`。本轮被 dev 已有企业模块测试的 `testCompile` 错误阻断：`OfferServiceConcurrencyIT` 的 `terminateApplication` 调用与 `ScreeningMapperDatabaseTest` 的 `selectAnalysis` 调用参数数量不匹配。已核对这两个测试及对应接口与 dev 完全一致，本轮没有修改它们。
- 上节 21/21 后端测试与隔离浏览器验证属于同步前的历史记录，不能作为最新交付分支后端测试或生产验收通过的证据。
- `git diff --check`、提交范围和新增凭据格式检查通过。未提交私有配置、凭据、真实数据、依赖、日志或构建产物。
- PR 保持 Draft；合并前需修复集成基线的测试编译问题并重跑相关测试、确认 CI 与非作者 Review，使用专用测试账号完成真实双端消息、多端收藏及目标服务器验收。本轮未合并 PR、未推送 dev/main、未生产部署或执行数据库迁移。
