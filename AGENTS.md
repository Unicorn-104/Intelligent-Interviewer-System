# Project Memory

本项目所有人工开发者与 AI Agent 在开始开发、提交或发起 PR 前，必须先阅读并遵守：

- `docs/spec/development.md`
- `docs/spec/git.md`
- `docs/spec/coding-style.md`

关键约束：

- 分支模型固定为 `feature/* -> dev -> main`。
- 功能分支命名固定为 `feature/<模块名>-<功能名>-<姓名缩写>`。
- 每个子功能单独 commit，commit message 遵循 Conventional Commits。
- 完整功能开发完成后，仅通过 PR 合并到 `dev`。
- `dev` 只有在形成完整可运行版本并完成验收后，才允许通过 PR 合并到 `main`。
- 禁止提交敏感配置、运行时文件、依赖目录、构建产物和无关改动。
- 每个模块开发完成后，必须分模块逐一验证（接口通断、字段对齐、数据正确性），不得整体打包后才发现问题。
- 后端只允许新增自己负责模块的代码，不得修改其他模块的现有代码。
