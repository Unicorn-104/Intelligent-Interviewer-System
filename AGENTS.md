# Project Memory

## C-APP 面试交付（2026-10-30）

- 本轮完整功能为「c-app 面试」，姓名缩写由用户指定为 `MZR`；从最新 `origin/dev` 创建 `feature/capp-interview-MZR`，采用 `feature/* -> dev -> main` 单向模型。
- 用户明确限定本次只提交面试相关代码；AI 长期记忆管理 API 与面板等独立功能留在原工作区，不夹带入面试 PR。
- 交付范围包括面试邀请卡片、日程入口、设备检测与录制同意、候选人等候与会议状态、LiveKit 音视频、字幕与作答、与 E-App 对齐的会议 UI，以及必要平台配置、已有测试源码和文档。
- 按 [提交与发布规范](c-app/提交与发布规范.md) 的「C-APP 面试交付」逐子功能提交 Conventional Commits，完整功能统一一个 PR 到 `dev`；不直接推送或合并 `dev`，不推进 `main` 或创建发布标签。
- 使用最新 dev 的独立 worktree，仅迁移原工作区相对 HEAD 的面试增量，保留原工作区、dev 新后端实现及其他端代码。Backend 无新增业务源码时不重复提交，不纳入原工作区已有 SQL 删除。
- 用户此前已要求后续不再测试，本轮只整理、检查交付差异并提交；不重跑格式化、静态分析、业务测试或构建。历史验证单独标注，不能作为本轮交付分支验证；PR 保持 Draft，待 CI、人工 Review 与必要设备验收。
- 面试邀请只提取合法 room token，不向消息链接主机发送登录凭据；会议私有 CA 仅在显式开关启用时匹配指定 API 同源或同主机 `8444/livekit` 网关，保留 TLS 校验。
- 禁止纳入本机配置、凭据、真实会话数据、日志、模型缓存、APK 与 Flutter 工具状态。实现与验收边界见 [视频面试与邀请卡片](c-app/视频面试与邀请卡片.md)。

## 长期记忆增量交付（2026-10-27）

- 本轮分支为 `feature/capp-long-term-memory-MZR`，从最新 `origin/dev` 创建；主功能为长期记忆，姓名缩写由用户明确指定为 `MZR`。
- 用户随后明确要求「全部当一个提交，写主要功能，长期记忆」，因此本轮将长期记忆、必要的服务器适配、简历选择投递及撤回投递增量汇总为一个 Conventional Commit；此例外不改变后续任务默认的子功能原子提交规则。
- 具体范围、验证、发布门禁与回滚见 [提交与发布规范](c-app/提交与发布规范.md) 的「长期记忆增量交付」，部署要求见 [个人长期记忆与 Qdrant](backend/doc/capp_ai_long_term_memory_qdrant.md)。
- 使用独立 worktree 整理，保留原工作区及最新 dev 的 PDF、消息、岗位和其他端实现；不以本地旧文件整体覆盖远端代码。
- 仅提交 `backend/`、`c-app/` 与必要的项目 memory。排除本机账号和业务数据、测试岗位数据、已有 SQL 删除、私有配置、模型缓存、日志、产物及其他端修改。
- 授权包括创建、提交、推送 feature 分支和统一创建到 dev 的 PR；不包含合并 PR、直接推送 dev/main、创建发布标签或推进 dev 到 main。未完成服务器环境验收时保持 Draft，并明确验证边界。

本文件是仓库级长期协作记忆。开发、提交、推送或创建 PR 前必须阅读并遵守：

- `docs/spec/development.md`
- `docs/spec/git.md`
- `docs/spec/coding-style.md`
- `c-app/提交与发布规范.md`

## 版本控制模型

- 固定流转方向：`feature/* -> dev -> main`，禁止跳级、反向合并或直接在 `dev`、`main` 开发。
- 功能分支必须从最新 `origin/dev` 创建；若远端没有 `dev`，先从最新 `origin/main` 创建并推送 `dev`。
- 功能分支命名：`feature/<模块名>-<功能名>-<姓名缩写>`；模块名和功能名使用小写英文、数字与连字符，姓名缩写保留大写；当前开发者缩写为 `MZR`。
- 一个 feature 分支只承载一个完整功能。一个可独立理解、验证和回滚的子功能对应一个 commit；完整功能完成后统一创建一个 `feature/* -> dev` PR。
- `dev -> main` 只能通过 PR，并且候选提交必须是经过完整构建、测试和核心流程验收的可运行版本。
- 禁止直接推送或强制推送 `dev`、`main`，禁止重写共享分支历史。

## Commit 规范

- 使用 Conventional Commits：`<type>(<scope>): <中文摘要>`。
- `type` 允许：`feat`、`fix`、`refactor`、`test`、`docs`、`chore`、`build`、`ci`、`perf`、`revert`。
- `scope` 使用稳定模块名，例如 `capp`、`auth`、`job`、`resume`、`message`、`profile`、`support`、`backend`、`git`。
- 摘要使用祈使语气，说明结果而非过程，不加句号；需要时在正文写明原因、兼容性影响和验证结果。
- 禁止使用 `update`、`changes`、`fix bug` 等无法独立理解的描述，禁止把无关修改混入同一 commit。
- 破坏性变更使用 `!` 并在正文增加 `BREAKING CHANGE:`；关联事项使用 `Refs:` 或 `Closes:`。

## PR 与发布门禁

- `feature/* -> dev` PR 必须说明目标、改动范围、接口或数据结构影响、验证命令、人工验证结果、风险和回滚方式。
- 创建 PR 前同步最新 `origin/dev`，解决冲突并重新执行受影响模块的验证。
- Backend 至少通过相关 Maven 编译/测试；Flutter 至少通过格式检查、`flutter analyze`、`flutter test`，涉及构建或平台能力时补充 Debug 构建和目标设备验证。
- `dev -> main` 必须同时满足：所有计划内功能已合入、CI 通过、数据库迁移可执行且可回滚、无明文凭据、Backend 与客户端可从干净环境构建、核心业务链路验收通过。
- `main` 合并后再创建版本标签；标签采用语义化版本 `vMAJOR.MINOR.PATCH`。
- 默认保留原子提交并使用 Rebase merge；仅当分支只有一个有效提交或维护者明确要求时 Squash。
- AI Agent 可以准备和推送 feature 分支，但未经明确授权不代替人工 Review 合并 PR，也不自行推进 `dev -> main`。

## 工作区与安全

- 开始前检查分支、远端和工作区，保留用户已有修改；只暂存当前子功能的文件。
- 提交前检查 `git diff`、`git diff --cached` 和待提交文件清单，确认没有夹带日志、构建产物或无关内容。
- 禁止提交或输出密码、Token、私钥、数据库凭据、真实个人数据及本地专用配置。
- 已进入共享分支的错误使用 `git revert` 或 Revert PR 回滚；不得用破坏性命令清理不明确的修改。
- 每个模块完成后必须逐一验证接口通断、字段对齐和数据正确性，不得等到整体打包后才排查模块问题。
- Backend 只允许新增或修改当前负责模块的代码，不得修改无关模块的现有实现。
- Backend 和 `c-app` 的业务、接口、安全与验证要求同时受根目录 `process.md` 约束，但 `process.md` 作为本地开发依据不纳入版本控制。

## 简历上传解析功能

- 本功能分支：`feature/capp-resume-upload-parse-MZR`，从最新 `origin/dev` 创建，完成后统一 PR 到 `dev`。
- 提交范围为 `backend/`、`c-app/` 的简历上传、PDF 解析、AI 字段编排、原文件保存及其必要依赖、测试和文档；包含本 memory 与必要的源码忽略规则修复。
- 子功能拆分、验证与回滚要求见 `c-app/提交与发布规范.md`；实现说明见 `c-app/简历上传解析与编排原理.md`。
- Flutter 的 `lib/features/*/data/*.dart` 是接口源码，必须纳入版本控制，不能被运行时 `data/` 忽略规则排除。

## 求职者端完善交付（2026-10-16）

- 当前交付分支为 `feature/capp-improve-MZR`，功能名 `improve` 对应用户指定的「完善」，从交付时最新 `origin/dev` 创建。
- 完整功能为完善求职者端岗位发现与求职管理闭环：AI 推荐、岗位组合筛选、投递跟踪与面试日历、企业主页与收藏提醒、岗位收藏，以及必要的登录失效处理、个人中心入口和私有配置模板。
- 本次仅上传 `backend/`、`c-app/` 及必要的 `.gitignore`、本文件；不纳入 `e-app/` 等其他端的本地修改，不提交 `process.md`、本机启动说明、私有配置、缓存或构建产物。
- 按 [C-APP 与 Backend 提交及发布规范](c-app/提交与发布规范.md) 的「求职者端完善交付」拆分原子提交，完整功能统一一个 PR 到 `dev`。必要人工验收未完成时保持 Draft，明确已有验证和未验收边界。
- 使用从最新 dev 创建的独立 worktree 整理交付，保留原工作区全部修改。PR 仅包含当前工作区相对其原 HEAD 的相关增量，不用旧目录整体覆盖最新 dev。
- 本次授权包括创建、提交、推送 feature 分支并创建 PR；不包含合并 PR、直接推送 dev/main 或推进 dev 到 main。

## 求职者端 AI Agent 交付（2026-10-22）

- 功能分支为 `feature/capp-agent-MZR`，从最新 `origin/dev` 创建，完整功能统一 PR 到 `dev`。
- 范围包括服务端 AI 对话编排与受控工具、SSE 任务恢复、会话历史与记忆、投递/简历上下文校验，以及 C-APP 对话入口、选择面板和错误恢复。
- 仅纳入 `backend/`、`c-app/` 中 Agent 必需代码、迁移、回滚、测试、说明与项目 memory；不纳入 `e-app/`、本地 AI 配置、启动说明、密钥、真实简历或聊天数据。
- 子功能拆分、接口契约、迁移顺序及验证要求见 [C-APP 与 Backend 提交及发布规范](c-app/提交与发布规范.md) 的「求职者端 AI Agent 交付」。实现和部署边界见 `backend/doc/capp_ai_agent.md`。
- 功能 PR 仅推进至 `feature/* -> dev`。未经人工 Review 不合并 PR，不直接推送 `dev`/`main`，不执行生产发布。

## Backend 与 C-APP 增量交付（2026-10-23）

- 交付分支为 `feature/capp-job-assistant-delivery-MZR`，从最新 `origin/dev` 创建；姓名缩写由用户指定为 `MZR`。
- 执行 [C-APP 与 Backend 提交及发布规范](c-app/提交与发布规范.md) 的「Backend 与 C-APP 增量交付（2026-10-23）」：用户随后明确要求本轮一起提交，因此本轮汇总为一个 Conventional Commit，统一一个 PR 到 dev；其他任务仍沿用默认原子提交规则。
- 已核对的本地新增业务源码均已在 dev；保留 dev 较新的岗位接口、AI 控制器和企业岗位发布实现，仅提交尚未入库的说明与安全忽略规则，不重复提交或回退远端代码。
- 在独立 worktree 中整理，保留原工作区全部修改。排除其他端修改、已有 SQL 删除、本地账号与业务数据导出、私有配置、启动命令、凭据和产物。
- 本轮授权包括创建、提交、推送 feature 分支及创建 PR，不包含代替人工 Review 合并或推进 dev 到 main。只有完整可运行项目通过发布门禁后，才能另行通过 dev 到 main 的 PR 发布。
- 仅文档与忽略规则差异执行文档契约、链接、敏感信息和 diff 检查；历史测试结果不能作为当前全部业务验收通过的证据。
