# Git 分支与提交规范

## 一、分支模型

采用 **feature -> dev -> main** 三层分支模型：

| 分支 | 用途 | 保护规则 |
|------|------|----------|
| `main` | 生产环境稳定版本，只接受来自 `dev` 的合并 | 禁止直接 push，只接受 PR |
| `dev` | 开发集成分支，所有 feature 完成后合并到这里 | 禁止直接 push，只接受 feature 的 PR |
| `feature/*` | 功能开发分支，从 `dev` 拉取，完成后 PR 回 `dev` | 可自由提交、推送 |

## 二、分支命名规范

### Feature 分支

格式：`feature/<模块名>-<功能名>-<姓名缩写>`

- 模块名：大模块缩写（如 ad、interview、user、enterprise、auth 等）
- 功能名：具体功能描述，用短横线连接（如 backend-admin、list-query、crud）
- 姓名缩写：拼音首字母大写（如 TQY、YLX、HFY、MZR）

示例：
- `feature/ad-backend-crud-TQY`
- `feature/interview-conference-YLX`
- `feature/userpc-resume-management-HFY`

### 其他分支

- `hotfix/<问题描述>-<姓名缩写>`：紧急修复分支，从 main 拉取
- `docs/<文档内容>-<姓名缩写>`：文档更新分支

## 三、Commit 规范

### 提交信息格式

```
<类型>(<范围>): <主题>

<正文>
```

### 类型（type）

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复 bug |
| `docs` | 文档变更 |
| `style` | 代码格式（不影响功能） |
| `refactor` | 重构（既不是新增功能，也不是修复 bug） |
| `test` | 新增测试或修改测试 |
| `chore` | 构建过程或辅助工具的变动 |

### 范围（scope）

可选，用于说明影响范围，如：`ad`、`interview`、`user`、`auth`、`backend`、`frontend`。

### 提交规则

1. **一个子功能一个 commit**，不要把多个功能混在一个提交里
2. 主题行不超过 50 个字符，用动词开头（添加、修复、修改）
3. 正文说明"为什么这么做"，而不是"做了什么"
4. 每次提交前确保代码能编译通过

### 提交示例

```
feat(ad): 添加广告管理列表查询接口

- 实现 AdController 的 getList 接口
- 编写 AdMapper.xml 的分页查询 SQL
- 适配 t_ad 表旧字段命名
```

```
fix(ad): 修复状态变更接口 SQL 字段错误

原因：updateAdStatus 使用了 advert_id，数据库实际字段是 ad_id
```

## 四、合并与 PR 规范

### Feature -> Dev

1. 功能开发完成后，确认代码可运行
2. 在 GitHub 上发起 PR，从 feature 分支合并到 dev 分支
3. PR 标题格式：`feat(<模块>): <功能描述>`
4. PR 描述需包含：
   - 功能说明
   - 改动文件列表
   - 测试情况
5. 至少 1 人 review 通过后才能合并
6. 合并后删除 feature 分支

### Dev -> Main

1. 只有当 dev 分支达到**完整可运行的项目版本**时，才能合并到 main
2. 需要经过完整的功能测试
3. 打版本标签：`v<版本号>`（如 v1.0.0）
4. 版本号规则：主版本.次版本.修订号

## 五、其他约定

1. 禁止向 `main` 和 `dev` 分支直接 push
2. 提交前先 `git pull` 拉取最新代码，解决冲突
3. 敏感信息（密码、密钥）禁止提交到仓库
4. 大文件（>10MB）不要提交，使用 Git LFS 或外部存储
5. 每日下班前提交当日工作，避免丢失代码
