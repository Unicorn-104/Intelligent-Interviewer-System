# 用户 PC 端前后端开发规范

> 本规范适用于 `user-PC` 前端、`backend` 后端，以及两者之间的接口联调。
> 所有开发、提交、推送、PR 与交付动作必须遵守本文档和 `docs/spec/git.md`。

---

## 1. 分支模型

本项目采用固定三层分支模型：

```text
feature/* -> dev -> main
```

| 分支 | 定位 | 合并规则 |
| --- | --- | --- |
| `feature/*` | 单一功能或单一修复开发分支 | 从 `dev` 拉出，开发完成后 PR 到 `dev` |
| `dev` | 日常集成与联调分支 | 只接受 `feature/*` PR |
| `main` | 稳定可运行版本分支 | 只接受 `dev` PR，且必须是完整可运行版本 |

硬性要求：

- 禁止直接在 `main` 上开发或推送。
- 禁止直接向 `dev` 推送业务代码，必须通过 PR。
- 如果本地或远程缺少 `dev`，从 `main` 创建 `dev` 后再创建 feature 分支。
- 一个完整功能使用一个 feature 分支，避免多个业务目标混在同一分支。

## 2. Feature 分支命名

格式：

```text
feature/<模块名>-<功能名>-<姓名缩写>
```

命名规则：

- `模块名`：小写英文，如 `candidate`、`job`、`interview`、`resume`、`auth`、`docs`、`userpc`。
- `功能名`：小写英文，多个单词用 `-` 连接，必须能表达本次功能范围。
- `姓名缩写`：使用开发者姓名拼音首字母，2 到 4 位大写，如 `ZSH`、`LS`、`HFY`。

示例：

```text
feature/userpc-job-list-HFY
feature/interview-schedule-HFY
feature/resume-editor-HFY
feature/docs-development-standard-HFY
```

## 3. Commit 规范

每个子功能必须单独 commit。一次 commit 只表达一件事，禁止把前端、后端、样式、文档、无关格式化混在同一个提交里。

Commit message 使用 Conventional Commits：

```text
<type>(<scope>): <subject>
```

常用 `type`：

| type | 用途 |
| --- | --- |
| `feat` | 新功能 |
| `fix` | 缺陷修复 |
| `docs` | 文档 |
| `style` | 纯格式、样式调整，不影响逻辑 |
| `refactor` | 重构，不改变外部行为 |
| `test` | 测试相关 |
| `chore` | 构建、依赖、脚本、工程配置 |
| `perf` | 性能优化 |
| `ci` | CI/CD 配置 |

推荐拆分方式：

```text
feat(candidate): 新增候选人岗位列表接口
feat(userpc): 实现岗位列表筛选交互
fix(userpc): 修复岗位卡片移动端换行异常
test(candidate): 补充岗位列表查询单元测试
docs(userpc): 更新候选人端使用说明
```

提交前必须执行：

```bash
git status
git diff --staged
```

只暂存本次提交需要的文件，禁止提交：

- `node_modules/`
- `.npm-cache/`
- `dist/`
- `target/`
- `.idea/`
- `.vscode/`
- `backend/ruoyi-admin/src/main/resources/application.yml`
- `backend/ruoyi-admin/src/main/resources/application-druid.yml`
- 数据库密码、Redis 密码、JWT secret、第三方 API key
- 与本功能无关的接口文档、临时文件和个人草稿

## 4. PR 规范

完整功能开发完成后，feature 分支统一 PR 到 `dev`。

PR 标题格式：

```text
<type>(<scope>): <功能简述>
```

PR 描述必须包含：

```markdown
## 功能说明
- 

## 变更清单
- 

## 自测结果
- [ ] 后端编译通过
- [ ] 用户 PC 端启动通过
- [ ] 核心页面或流程自测通过

## 风险与回滚
- 
```

合并要求：

- feature -> dev：至少完成本功能自测，并确保不夹带无关文件。
- dev -> main：必须是完整可运行项目版本，后端、用户 PC 端、必要数据库脚本和核心流程都已验收。
- AI Agent 或自动化协作者不得自行把 `dev` 合并到 `main`。

## 5. 用户 PC 端前端规范

目录范围：

```text
user-PC/
```

启动命令：

```bash
cd user-PC
npm install
npm run dev
```

当前开发端口：

```text
http://127.0.0.1:5180/
```

用户端页面入口：

```text
http://127.0.0.1:5180/agent/index
```

开发要求：

- 优先复用 `src/views/agent`、`src/components/agent`、`src/utils` 中已有结构。
- 用户 PC 端页面优先走 `/agent/*` 路由，不混入后台管理端路由。
- 页面状态应清晰处理加载、空数据、错误、禁用、权限不足和提交中状态。
- 与后端联调的接口统一封装在 `src/api` 或对应模块 API 文件中，避免页面内散落 axios 调用。
- 表单必须有前端校验；后端仍必须再次校验，不能只依赖前端。
- 样式修改必须检查桌面端主流宽度和移动端窄屏，不允许文字溢出、按钮挤压、元素重叠。
- 演示数据和真实接口切换必须通过环境变量或明确的 mock 层控制，禁止在业务逻辑中硬编码临时开关。

前端自测建议：

```bash
cd user-PC
npm run test:unit
npm run build:prod
```

## 6. 后端规范

目录范围：

```text
backend/
```

启动方式：

```bash
cd backend
mvn clean package -Dmaven.test.skip=true
java -jar ruoyi-admin/target/ruoyi-admin.jar
```

开发要求：

- Controller 只做参数接收、权限声明、响应包装，核心业务放在 Service。
- 入参 DTO 必须校验，关键字段在后端强校验。
- Mapper XML 与实体字段保持一致，涉及表结构变更必须补充 SQL 或迁移说明。
- 返回给用户 PC 端的数据结构要稳定，字段命名清晰，避免直接暴露内部敏感字段。
- 新接口必须补充权限、异常、分页、排序和空数据行为。
- 涉及登录、简历、面试、投递等用户数据时，必须校验当前登录用户的数据归属。
- 禁止把数据库密码、Redis 密码、JWT secret 写入仓库。

后端自测建议：

```bash
cd backend
mvn clean compile
mvn test
```

## 7. 前后端接口协作

接口开发流程：

1. 先明确页面字段、交互状态和后端数据模型。
2. 后端定义接口路径、请求方法、入参、出参、错误码和权限。
3. 前端封装 API 调用，再接入页面。
4. 联调时记录接口变更，必要时更新接口文档。
5. 任何破坏性接口变更必须同步调整前端和文档。

接口约定：

- 用户 PC 端接口路径应按业务域组织，例如 `/candidate/*`、`/job/*`、`/interview/*`、`/resume/*`。
- 列表接口必须支持分页。
- 时间字段统一返回可解析的标准格式。
- 金额、薪资、评分等数值字段必须明确单位。
- 错误响应必须能让前端展示可理解提示。

## 8. 数据库与迁移

- 表结构变更必须有 SQL 文件或迁移说明，不允许只改本地数据库。
- 字段命名保持业务语义清晰，避免缩写过度。
- 新增字段必须明确默认值、是否可空、索引需求和历史数据兼容。
- 涉及用户隐私数据时，应避免冗余存储和日志输出。
- dev -> main 前必须确认数据库脚本可从空库重建。

## 9. 启动与联调要求

日常查看用户 PC 端页面时，优先启动：

```bash
cd user-PC
npm run dev
```

如果页面依赖真实接口，再启动后端：

```bash
cd backend
mvn spring-boot:run -pl ruoyi-admin -am
```

后端启动前必须确认本地存在以下配置文件：

```text
backend/ruoyi-admin/src/main/resources/application.yml
backend/ruoyi-admin/src/main/resources/application-druid.yml
```

如果缺少配置文件，不允许提交临时敏感配置；应使用本地模板或向团队获取配置。

## 10. 开发完成检查清单

提交前：

- [ ] 当前分支符合 `feature/<模块名>-<功能名>-<姓名缩写>`。
- [ ] 每个子功能已单独 commit。
- [ ] `git status` 中没有无关文件。
- [ ] 前端页面已在用户 PC 端入口验证。
- [ ] 后端接口已完成必要校验和异常处理。
- [ ] 已更新接口文档、README 或说明文档。
- [ ] 未提交敏感配置、缓存、依赖目录和构建产物。

PR 前：

- [ ] 已同步最新 `dev`。
- [ ] 前端构建或关键页面启动验证通过。
- [ ] 后端编译或关键接口启动验证通过。
- [ ] PR 描述包含功能说明、变更清单、自测结果、风险与回滚。

dev -> main 前：

- [ ] 后端可启动。
- [ ] 用户 PC 端可启动。
- [ ] 核心业务流程可走通。
- [ ] 数据库脚本可执行。
- [ ] 无 P0/P1 缺陷。
- [ ] 已完成验收并通过 PR。
