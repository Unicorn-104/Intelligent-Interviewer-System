# AI招聘管理系统 — 后台管理端（平台方）

基于若依 RuoYi-Vue3（Vue3 + Element Plus + Vite）定制，已内置前端 mock 数据层，无需 Java 后端即可独立运行演示。

## 运行

```bash
npm install        # 首次运行（本次已装好，可跳过）
npm run dev        # 启动开发服务器，浏览器打开 http://localhost:80
```

登录页账号密码已预填 admin / admin123，演示模式下任意账号均可登录（验证码已关闭）。

## 演示模式开关

`.env.development` 中：

```
VITE_APP_USE_MOCK = true   # 前端 mock 数据，独立演示
VITE_APP_USE_MOCK = false  # 连接真实若依后端（默认 /dev-api 代理）
```

mock 层位于 `src/mock/`（index.js 适配器 / db.js 系统数据 / business.js 业务数据）。关闭 mock 后，登录、菜单、数据均走后端接口，需配合 RuoYi 后端并按 `src/mock/index.js` 中的接口路径实现服务端。

## 菜单结构

- 首页（仪表盘：租户/候选人/AI 调用统计、趋势图、套餐分布、API TOP10、最近操作）
- 租户管理：企业管理（详情抽屉含基本信息/配额/子账号/日志）、套餐管理
- 系统管理：用户管理、角色分配、菜单配置、数据字典（若依原生）
- AI 配置：模型管理（含测试连接）、API 配额（含用量明细图表）、提示词模板（全屏编辑 + 版本历史）
- 内容管理：职位分类（左树右表单）、面试题库（单选/多选/开放题）、公告管理（若依原生）、广告管理（广告位管理 + 广告列表，支持开屏/弹窗/Banner/信息流四类广告位、投放与数据统计）
- 日志审计：操作日志、登录日志（若依原生）
- 系统监控：在线用户、服务状态、定时任务（若依原生）

## 与真实后端对接

mock 中约定的接口即后端需实现的接口，主要模块：

| 模块 | 前缀 |
|------|------|
| 仪表盘 | /dashboard/* |
| 企业管理 | /tenant/company/* |
| 套餐管理 | /tenant/package/* |
| 模型管理 | /ai/model/* |
| API 配额 | /ai/quota/* |
| 提示词模板 | /ai/prompt/* |
| 职位分类 | /content/category/* |
| 面试题库 | /content/question/* |
| 广告位 | /ad/slot/* |
| 广告 | /ad/advert/* |

返回结构遵循若依规范：列表 `{ code, msg, rows, total }`，详情 `{ code, msg, data }`，操作 `{ code, msg }`，code=200 为成功。
