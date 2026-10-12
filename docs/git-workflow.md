# Git 分支与提交规范

## 分支模型

采用 `feature -> dev -> main` 三级分支模型：

| 分支 | 作用 | 保护规则 |
|------|------|----------|
| `main` | 生产环境可运行版本 | 禁止直接 push，只能由 dev 合并 |
| `dev` | 集成开发分支，多人功能合并后测试 | 禁止直接 push，只能由 feature PR 合并 |
| `feature/*` | 个人功能开发分支 | 每人一条，完成后 PR 到 dev |

## feature 命名规范

```
feature/模块名-功能名-姓名缩写
```

示例：
- `feature/interview-pc-ui-redesign-TQY`
- `feature/auth-login-register-HFY`
- `feature/enterprise-im-chat-YLX`

## 提交信息规范

格式：`<type>(<scope>): <subject>`

| type | 说明 |
|------|------|
| feat | 新功能 |
| fix | 修复bug |
| style | UI样式调整（不影响逻辑） |
| refactor | 重构 |
| docs | 文档 |
| chore | 构建/工具配置 |
| perf | 性能优化 |

示例：
- `feat(interview): 面试安排中心日历状态色与详情抽屉`
- `fix(interview): 修复日历面试块与时间线对齐`
- `style(interview): 优化左侧候选人卡片紧凑布局`

## 提交流程

1. 从 `dev` 拉最新代码
2. 创建 feature 分支
3. 每个子功能单独 commit（不要混在一个commit里）
4. 功能完成后 push 到远程
5. 在 GitHub 创建 PR：feature -> dev
6. PR 描述写清：改了什么、怎么测、有无风险
7. dev 上完整可运行后再合并到 main

## 注意事项

- 禁止在 main/dev 上直接提交
- 一次commit只做一件事
- 提交前确认无 console.log、无调试代码
- 不要提交 node_modules、dist、.env、日志文件
