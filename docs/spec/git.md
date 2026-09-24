# Git 协作规范

> 本文档定义本项目的 Git 分支模型、命名规范、提交规范与 PR 流程。
> 适用于所有人工开发者与 AI Agent 协作者。**AI Agent 在执行任何 Git 操作前必须先通读本规范。**

---

## 一、分支模型

本项目采用三层分支模型：

```
feature/*  ──►  dev  ──►  main
(功能开发)   (集成分支)  (生产分支)
```

| 分支 | 职责 | 来源 | 合并去向 | 保护策略 |
|------|------|------|----------|----------|
| `main` | 生产可发布版本，每个 commit 必须是完整可运行的项目 | 由 `dev` 合并 | — | 禁止直推，仅接受来自 `dev` 的 PR |
| `dev` | 集成与联调分支，承载多个 feature 的汇合 | 由 `feature/*` 合并 | `main` | 禁止直推，仅接受 PR |
| `feature/*` | 单一功能开发分支，生命周期短 | 由 `dev`（无则 `main`）拉出 | `dev` | 可直推，开发完成后提 PR |

### 分支职责细则

- **main**：永远处于"可部署到生产"状态。main 上的代码必须经过 dev 集成与完整验证。仅由 dev 通过 PR 合并，合并时项目必须是完整可运行版本。
- **dev**：集成分支，承载多个 feature 的汇合。dev 上的代码应能编译/启动/通过基础冒烟测试，但不要求达到生产可发布质量。
- **feature/\***：单一功能开发分支。每个功能一个分支，开发完成后统一提 PR 到 dev。

---

## 二、分支命名规范

### feature 分支命名

```
feature/<模块名>-<功能名>-<姓名缩写>
```

- **模块名**：业务模块，小写，如 `auth`、`job`、`interview`、`candidate`、`offer`、`sys`、`docs`
- **功能名**：具体功能，多个单词用连字符 `-` 分隔，全小写
- **姓名缩写**：开发者姓名拼音首字母组合（2–4 位大写），如张三华 → `ZSH`，李四 → `LS`

示例：

| 分支名 | 说明 |
|--------|------|
| `feature/auth-jwt-refresh-ZSH` | 鉴权模块 / JWT 刷新 / 张三华 |
| `feature/interview-ai-evaluation-LS` | 面试模块 / AI 评价 / 李四 |
| `feature/job-publish-workflow-ZSH` | 职位模块 / 发布工作流 / 张三华 |
| `feature/docs-git-spec-LS` | 文档模块 / Git 规范 / 李四（本文档示例） |

### 其他分支命名

- 紧急修复：`hotfix/<问题描述>-<姓名缩写>`，从 `main` 拉出，修复后同时合并回 `main` 与 `dev`
- 发版标签：`v<major>.<minor>.<patch>`，如 `v1.0.0`

---

## 三、分支创建与使用流程

### 创建分支（若目标分支不存在，自行创建）

```bash
# 1. 同步远程
git fetch origin --prune

# 2. 创建 dev（若远程无 dev 分支）
git checkout -b dev main
git push -u origin dev

# 3. 创建 feature 分支（从 dev 拉出；dev 不存在时从 main 拉出）
git checkout -b feature/<模块名>-<功能名>-<姓名缩写> dev
git push -u origin feature/<模块名>-<功能名>-<姓名缩写>
```

> **AI Agent 规则**：执行分支创建前，先 `git fetch origin && git branch -r` 确认 dev 是否存在；不存在则按上面步骤创建。

### 开发流程

1. 在 feature 分支上开发
2. 每个子功能完成即**单独 commit**（见第四节）
3. 定期 `git fetch` 并 `git rebase origin/dev`（或 merge）保持与 dev 同步
4. 完整功能开发完成后，**统一提 PR 到 dev**（见第五节）
5. PR 合并后删除已合并的 feature 分支（本地与远程）

---

## 四、Commit 规范

### 原则：每个子功能单独 commit

一个完整功能通常拆为多个子功能，每个子功能独立 commit。**禁止把多个不相关改动塞进同一个 commit**。

**子功能拆分示例**（以"职位发布工作流"功能为例）：

| # | Commit Message |
|---|-----------------|
| 1 | `feat(job): 新增职位发布数据模型与 Mapper` |
| 2 | `feat(job): 实现职位发布 Service 业务逻辑` |
| 3 | `feat(job): 新增职位发布 Controller 与 DTO 校验` |
| 4 | `feat(job): 实现前端职位发布表单与提交流程` |
| 5 | `feat(job): 补充职位发布单元测试` |

### Commit Message 格式（Conventional Commits）

```
<type>(<scope>): <subject>

<body>

<footer>
```

- **type**（必填）：`feat` 新功能 / `fix` 修复 / `docs` 文档 / `style` 格式 / `refactor` 重构 / `test` 测试 / `chore` 构建工具 / `perf` 性能 / `ci` CI 配置
- **scope**（可选）：模块名，如 `auth`、`job`、`interview`、`docs`
- **subject**（必填）：简短描述，祈使句，小写开头，不超过 50 字，结尾不加句号
- **body**（可选）：补充说明，换行分隔，每行 ≤ 72 字
- **footer**（可选）：`BREAKING CHANGE:` 说明、关联 Issue（`Closes #123`）

示例：

```
feat(interview): 实现 AI 面试评价自动打分

- 接入大模型评分接口
- 支持按维度（专业/沟通/逻辑）输出分数
- 评价结果写入 interview_evaluation 表

Closes #42
```

### Commit 注意事项

- 一次 commit 只做一件事，禁止混合无关改动
- commit 前用 `git status` 确认暂存内容，避免误提交
- **禁止提交敏感配置**（已在 .gitignore 排除：`application.yml` / `application-druid.yml`）
- **禁止提交编译产物**（`target/`、`dist/`、`node_modules/`）
- 必要时用 `git add -p` 分块暂存

---

## 五、PR 流程（feature → dev）

### 提 PR 前自查清单

- [ ] feature 分支已 rebase 最新 dev，无冲突
- [ ] 本地能编译通过（后端 `mvn clean compile`，前端 `npm run build`）
- [ ] 已写/更新相关单元测试
- [ ] commit message 符合第四节规范
- [ ] 未夹带无关改动、未提交敏感文件

### 创建 PR

```bash
# 推送 feature 分支
git push -u origin feature/<模块名>-<功能名>-<姓名缩写>

# 用 gh CLI 创建 PR（目标分支为 dev）
gh pr create --base dev --head feature/<模块名>-<功能名>-<姓名缩写> \
  --title "feat(<scope>): <功能简述>" \
  --body "$(cat <<'EOF'
## 功能说明
<功能目的与背景>

## 变更清单
- <变更点 1>
- <变更点 2>

## 自测结果
- [ ] 后端编译通过
- [ ] 前端构建通过
- [ ] 核心流程自测通过

## 关联 Issue
Closes #<编号>
EOF
)"
```

### PR 标题规范

PR 标题继承 commit message 格式：`<type>(<scope>): <subject>`

### Review 与合并策略

- 至少 **1 人 Review 通过**（项目初期可由作者自查 + 另一协作者确认）
- 合并策略优先 **Squash merge**（保持 dev 历史整洁），次选 **Rebase merge**
- **禁用 Create a merge commit**（避免 dev 历史出现 merge 噪声）
- 合并后删除 feature 分支（本地 + 远程）

---

## 六、dev → main 发布规则

### 合并门槛（硬性条件，全部满足才可合并）

dev 合并到 main **必须**满足以下全部条件：

1. **完整可运行版本**：项目可从空环境 clone 后按 README 步骤启动成功（后端 8080、前端 80 正常访问）
2. **数据库可重建**：所有迁移 SQL 按序执行后数据库结构一致，无遗留手工补字段
3. **核心功能冒烟通过**：登录、关键业务流程可走通
4. **无 P0/P1 缺陷**：遗留问题已记录到 issue 跟踪
5. **通过 PR Review**：至少 1 人 Code Review + 1 人验收

### 发布流程

```bash
# 1. 在 dev 上打 tag（语义化版本）
git checkout dev && git pull origin dev
git tag v<major>.<minor>.<patch>
git push origin v<major>.<minor>.<patch>

# 2. 提 PR: dev → main
gh pr create --base main --head dev \
  --title "release: v<major>.<minor>.<patch>" \
  --body "$(cat <<'EOF'
## 发布说明
<本次发布核心变更>

## 自测清单
- [ ] 空环境 clone + 按README启动成功
- [ ] 数据库迁移SQL按序执行结构一致
- [ ] 核心业务流程冒烟通过
- [ ] 无 P0/P1 缺陷

## 变更范围
<相对上个版本的变更范围>
EOF
)"

# 3. Review 通过后 Squash merge 到 main
# 4. main 上同步打 tag（若步骤1已打则跳过）
```

### 版本号规则（语义化版本 SemVer）

`v<major>.<minor>.<patch>`

- **major**：不兼容的 API / 数据结构变更
- **minor**：向下兼容的新功能
- **patch**：向下兼容的缺陷修复

---

## 七、AI Agent 协作指引

当 AI Agent 参与本项目时，必须遵守以下条款：

1. **先读规范**：执行任何 git 操作前，确认已读取本文件 `docs/spec/git.md`
2. **分支模型**：所有功能开发走 `feature → dev → main`，**禁止 AI 直接向 main 推送**
3. **分支命名**：feature 分支严格按 `feature/<模块名>-<功能名>-<姓名缩写>` 命名
4. **分支自建**：目标分支不存在时，AI 应主动创建（dev 不存在从 main 建，feature 从 dev 建）
5. **commit 粒度**：每个子功能独立 commit，遵循 Conventional Commits 格式
6. **PR 优先**：完成完整功能后由 AI 提 PR 到 dev，由人 Review；**AI 不得自行合并 PR**
7. **dev → main 守门**：**AI 不得将 dev 合并到 main**；此动作必须由人确认"完整可运行版本"后执行
8. **敏感信息**：AI 禁止提交 `application.yml` / `application-druid.yml` 及任何含密钥/密码的文件
9. **冲突处理**：AI 遇到 rebase 冲突时，优先 `git status` 分析；复杂冲突应暂停并向人求助
10. **不可破坏性操作**：AI 禁止执行 `push --force` 到 main/dev、`reset --hard` 远程已分享支、删除他人分支

---

## 八、附：常见命令速查

```bash
# 同步远程并清理已删除分支
git fetch origin --prune

# 新建 feature 分支（从 dev 拉出）
git checkout -b feature/<模块>-<功能>-<缩写> dev

# 提交子功能
git add <具体文件>
git commit -m "feat(<scope>): <描述>"

# 同步 dev（保持 feature 分支与 dev 一致）
git fetch origin
git rebase origin/dev

# 推送 feature 分支
git push -u origin feature/<模块>-<功能>-<缩写>

# 提 PR（feature → dev）
gh pr create --base dev --head feature/<模块>-<功能>-<缩写> \
  --title "feat(<scope>): <简述>" --body "..."

# PR 合并后清理分支
git checkout dev && git pull origin dev
git branch -d feature/<模块>-<功能>-<缩写>
git push origin --delete feature/<模块>-<功能>-<缩写>
```
