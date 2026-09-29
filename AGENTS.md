# Project Memory

本文件是仓库级长期记忆入口。所有人工开发者与 AI Agent 在修改代码、执行 Git 操作或创建 PR 前，必须先阅读并遵守：

- `docs/spec/development.md`
- `docs/spec/git.md`（Git 流程的唯一规范来源）

## Git 工作流记忆

- 分支流转固定为 `feature/* -> dev -> main`，不允许跳级或反向合并。
- 功能分支必须从最新 `origin/dev` 创建；若仓库没有 `dev`，先从最新 `origin/main` 创建并推送 `dev`，再创建 feature 分支。
- 分支命名固定为 `feature/<模块名>-<功能名>-<姓名缩写>`；姓名缩写必须由开发者确认，当前开发者缩写为 `MZR`。
- 每个分支只开发一个完整功能，每个可独立理解、验证和回滚的子功能必须单独 commit。
- Commit 与 PR 标题遵循 Conventional Commits，例如 `feat(resume): 新增简历上传接口`。
- 完整功能开发、自测和同步最新 `dev` 后，统一创建 `feature/* -> dev` PR；不为每个子提交单独创建 PR。
- 默认使用 Rebase merge 保留原子提交；只有单提交或维护者明确同意时才 Squash。
- `dev -> main` 仅用于经完整构建、测试、数据库迁移和核心流程验收的可运行版本，并且必须通过 PR。
- 正式版本标签只能打在 `dev -> main` 合并后的 `main` 提交上。
- 禁止直接推送或强制推送 `dev`、`main`，禁止通过重写共享分支历史解决问题。

## 工作区与安全记忆

- 开始前检查当前分支、远程和 `git status`，保留用户已有修改，不覆盖、不清理、不夹带无关文件。
- 只暂存当前子功能的文件；提交前检查 `git diff` 与 `git diff --cached`。
- 禁止提交或输出密码、Token、私钥、数据库凭据、真实个人数据、本地配置、日志、依赖目录和构建产物。
- 已进入共享分支的错误使用 `git revert` 或 Revert PR 回滚；不得对不明确的修改使用破坏性 Git 命令。
- AI Agent 不自行合并需要人工 Review 的 PR；未完成发布门禁时不得推进 `dev -> main`。

具体命名、验证矩阵、PR 模板、分支保护、发布门禁与回滚流程以 `docs/spec/git.md` 为准。
