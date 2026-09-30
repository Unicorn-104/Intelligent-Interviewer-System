# Git 协作与发布规范

> 本文档是本项目 Git 分支、提交、Pull Request（PR）和发布流程的唯一规范来源，适用于所有开发者与 AI Agent。
> 文中的“必须”表示硬性要求，“建议”表示无特殊理由时应遵循的默认做法。

## 1. 分支模型

项目固定采用以下单向流转模型，不允许绕过中间分支：

```text
feature/*  ->  dev  ->  main
功能开发       集成验证    稳定发布
```

| 分支 | 用途 | 允许来源 | 合并方式 |
| --- | --- | --- | --- |
| `main` | 始终保存完整、可运行、可发布的项目版本 | 仅 `dev` | PR |
| `dev` | 功能集成、联调和版本验收 | 仅 `feature/*` | PR |
| `feature/*` | 单个完整功能的开发与自测 | 从最新 `origin/dev` 创建 | PR 到 `dev` |

硬性规则：

- 禁止直接向 `dev` 或 `main` 推送提交。
- 禁止将 `feature/*` 直接合并到 `main`。
- 禁止从 `main` 直接创建功能分支；若缺少 `dev`，必须先从 `main` 创建并推送 `dev`。
- 一个 feature 分支只承载一个完整功能；无关修改必须放入其他分支。
- 紧急修复也不得绕过该模型，使用 `feature/<模块>-hotfix-<姓名缩写>`，仍按 `feature -> dev -> main` 流转。

## 2. 分支命名

功能分支统一命名为：

```text
feature/<模块名>-<功能名>-<姓名缩写>
```

命名约束：

- `<模块名>` 和 `<功能名>` 仅使用小写英文字母、数字与连字符 `-`。
- `<功能名>` 应清楚表达交付内容，避免 `update`、`test1` 等模糊命名。
- `<姓名缩写>` 使用 2～6 位大写英文字母，并在创建分支前由开发者确认；不得自行猜测。
- 当前任务的姓名缩写为 `MZR`，规范文档分支为 `feature/governance-git-workflow-MZR`。

示例：

```text
feature/auth-jwt-refresh-MZR
feature/interview-ai-evaluation-MZR
feature/userpc-resume-upload-MZR
feature/governance-git-workflow-MZR
```

版本标签采用语义化版本：`v<major>.<minor>.<patch>`，例如 `v1.4.0`。

## 3. 创建分支

先同步远程并确认分支状态：

```bash
git fetch origin --prune
git branch -r
```

如果远程尚无 `dev`，由有权限的维护者从最新 `origin/main` 创建：

```bash
git switch --create dev origin/main
git push --set-upstream origin dev
```

之后所有功能分支必须从最新 `origin/dev` 创建：

```bash
git fetch origin --prune
git switch --create feature/<模块名>-<功能名>-<姓名缩写> origin/dev
git push --set-upstream origin feature/<模块名>-<功能名>-<姓名缩写>
```

创建前必须确认同名分支不存在，避免覆盖他人的工作。

## 4. 提交规范

### 4.1 每个子功能单独提交

一个完整功能应按可独立理解、验证和回滚的子功能拆分提交。例如“简历上传”可拆为：

```text
feat(resume): 新增简历文件存储接口
feat(resume): 接入客户端文件选择与上传
test(resume): 补充简历上传异常场景测试
docs(resume): 补充简历存储配置说明
```

禁止把多个无关子功能、格式化全仓库和临时调试改动混入同一提交。

### 4.2 Conventional Commits

提交信息采用：

```text
<type>(<scope>): <subject>

<可选正文>

<可选脚注>
```

常用类型：

- `feat`：新功能
- `fix`：缺陷修复
- `docs`：文档
- `refactor`：不改变外部行为的重构
- `test`：测试
- `perf`：性能优化
- `build`：构建系统或依赖
- `ci`：持续集成
- `chore`：其他维护工作
- `revert`：回滚已有提交

要求：

- `scope` 使用实际模块名，如 `resume`、`message`、`backend`、`governance`。
- `subject` 使用简洁祈使句，明确说明结果，不写句号。
- 破坏性变更必须在正文或脚注写明 `BREAKING CHANGE:` 及迁移方式。
- 关联任务时在脚注写 `Closes #123` 或 `Refs #123`。

### 4.3 提交前检查

每次提交前必须执行：

```bash
git status --short
git diff
git diff --cached
```

只暂存本子功能涉及的文件，必要时使用 `git add -p`。禁止提交：

- 密码、Token、私钥、数据库连接凭据和真实个人数据；
- 本地环境配置、日志、缓存、依赖目录和构建产物；
- 与本功能无关的已有修改；
- 无法解释来源的生成文件。

## 5. Feature 开发与同步

开发期间可持续推送自己的 feature 分支。发起 PR 前必须基于最新 `origin/dev` 同步：

```bash
git fetch origin --prune
git rebase origin/dev
```

- 冲突必须逐项理解并解决，禁止盲目选择一侧内容。
- 已共享的提交原则上不改写历史；确需在个人 feature 分支更新 rebase 结果时，只能使用 `git push --force-with-lease`。
- 严禁对 `dev`、`main` 使用强制推送。
- 严禁使用 `git reset --hard` 清理他人或不明确归属的修改。

## 6. Feature 到 Dev 的 PR

只有完整功能开发和自测结束后，才统一创建一个 `feature/* -> dev` PR。不得为每个子提交分别创建 PR。

PR 标题沿用 Conventional Commits，例如：

```text
docs(governance): 完善 Git 协作与项目 memory
```

PR 描述至少包含：

```markdown
## 功能说明
说明目标、背景和交付范围。

## 变更清单
- 子功能一
- 子功能二

## 验证结果
- [ ] 静态检查通过
- [ ] 自动化测试通过
- [ ] 构建通过
- [ ] 核心流程人工验证通过

## 风险与回滚
说明兼容性、数据库或配置影响，以及回滚方式。

## 关联任务
Closes #<编号>
```

合并门禁：

- 分支已同步最新 `dev`，且不存在未解决冲突。
- PR 中只包含该功能相关改动，提交历史符合原子提交要求。
- 所有必需检查通过，Review 对话全部解决。
- 至少 1 名非作者审核者批准；高风险改动建议至少 2 人批准。
- 默认使用 **Rebase merge**，保留每个子功能的独立提交。
- 仅当 PR 本身只有一个有效提交或维护者明确同意时，才可使用 Squash merge。
- 禁止作者在未完成审核与检查时自行合并。
- 合并后删除远程 feature 分支；本地分支确认已合并后再删除。

## 7. 验证矩阵

根据改动范围执行下列相关检查，并在 PR 中记录命令与结果。跨模块功能必须执行集成验证，不能只验证单个目录。

| 范围 | 最低检查 |
| --- | --- |
| Java 后端 | `mvn -DskipTests compile`、相关单元/集成测试、启动与核心接口冒烟 |
| Flutter 客户端 | `flutter analyze`、`flutter test`、目标平台 debug 构建或启动验证 |
| Node/Web 前端 | `npm ci`、`npm run build`、项目定义的 lint/test |
| 数据库 | 迁移脚本可重复执行或可安全判定状态，升级与回滚路径明确，模拟数据不含敏感信息 |
| 文档/流程 | 链接、命令、分支和示例可验证，且与项目 memory 一致 |

仓库已有更严格脚本时，以项目脚本和 CI 为准。不能执行某项检查时，必须在 PR 中说明原因、影响与替代验证，不能写成“已通过”。

## 8. Dev 到 Main 的发布门禁

`dev -> main` 只用于完整、可运行项目版本的发布，必须单独创建 PR，且满足：

- 在干净环境中可按 README 完成依赖安装、配置、数据库初始化和启动。
- 所有受影响端均完成编译/构建、自动化测试和核心业务冒烟。
- 数据库迁移、初始数据及回滚方案已验证，不依赖未记录的手工操作。
- 配置模板完整且不含真实凭据；部署所需环境变量均有说明。
- 不存在未处置的 P0/P1 缺陷；已知问题已登记并评估。
- 发布说明列出功能、修复、破坏性变更、迁移步骤和回滚方式。
- 至少 1 名代码审核者与 1 名验收者确认；高风险版本建议 2 名审核者。
- 必需 CI 检查全部通过，Review 对话全部解决。

发布流程：

1. 在 `dev` 完成版本验收并确定版本号。
2. 创建 `dev -> main` PR，标题使用 `release: v<版本号>`。
3. 审核、CI 和验收全部通过后合并到 `main`。
4. 在合并后的 `main` 提交上创建带注释标签并推送：

```bash
git switch main
git pull --ff-only origin main
git tag -a v<major>.<minor>.<patch> -m "release v<major>.<minor>.<patch>"
git push origin v<major>.<minor>.<patch>
```

禁止在 `dev` 提前创建正式发布标签，避免标签指向未发布提交。

## 9. 分支保护建议

仓库管理员应为 `dev` 和 `main` 配置：

- 必须通过 PR 合并，禁止直接推送；
- 必须通过所需审核数和状态检查；
- 新提交后撤销过期批准；
- 必须解决全部 Review 对话；
- 禁止强制推送和删除受保护分支；
- `main` 仅允许来自 `dev` 的 PR；
- 对发布、CI 和分支保护配置限制维护权限。

## 10. 回滚与故障修复

- 已进入共享分支的错误使用 `git revert` 或平台的 Revert PR 回滚，保留审计历史。
- 禁止通过重写 `dev` 或 `main` 历史处理线上问题。
- 生产紧急修复从最新 `origin/dev` 创建 `feature/<模块>-hotfix-<姓名缩写>`，完成原子提交、测试和 PR 后进入 `dev`。
- 修复通过完整发布门禁后，再由 `dev -> main` 发布 patch 版本。
- 如 `dev` 同期包含不应发布的功能，由维护者先回滚或隔离这些改动；不得让 hotfix 绕过 `dev` 直接进入 `main`。

## 11. AI Agent 与自动化约束

AI Agent 执行 Git 操作前必须读取本文件与仓库根目录 `AGENTS.md`，并遵守：

- 先检查当前分支、远程、工作区状态和现有用户修改，不覆盖、不夹带、不擅自清理。
- 姓名缩写等身份信息由用户提供；本任务使用 `MZR`。
- 每个子功能单独 commit，完整功能完成后才创建到 `dev` 的 PR。
- 未获得明确发布授权且未完成发布门禁时，不创建或合并 `dev -> main` PR。
- 不自行合并需要人工 Review 的 PR。
- 不提交、打印或传播凭据；不得用破坏性 Git 命令处理不明确的状态。

## 12. 完成定义（Definition of Done）

完整功能只有在以下项目全部满足后才算完成：

- [ ] 分支名符合 `feature/<模块名>-<功能名>-<姓名缩写>`。
- [ ] 每个子功能均有独立、可理解、可回滚的提交。
- [ ] 代码、测试、数据库、配置模板和文档按需同步更新。
- [ ] 相关静态检查、测试、构建和核心流程验证通过。
- [ ] 无敏感信息、构建产物和无关修改。
- [ ] 已同步最新 `dev`，PR 描述完整且风险与回滚方式明确。
- [ ] Review、CI 与对话解决状态满足合并门禁。
