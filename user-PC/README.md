# 智聘 AI · RuoYi

基于官方 RuoYi Vue3 前端基座迁移，保留智聘 AI 求职者端，并配套官方 RuoYi-Vue Java 后端。

## 目录

- `src/`：RuoYi Vue3 管理端与智聘 AI 求职者端
- `src/views/agent/pages/`：求职者端页面
- `backend/`：RuoYi-Vue Java 后端

## 启动前端

```powershell
npm install
npm run dev
```

- 管理端：`http://127.0.0.1:5180/`
- 求职者端：`http://127.0.0.1:5180/agent/index`
- 后端代理：默认转发到 `http://localhost:8080`

开发环境默认启用纯前端模式，打开根地址会直接进入求职者端，不依赖后端服务。
后端接口、API 模块和代理均已保留；接入后端时将 `.env.development` 的 `VITE_FRONTEND_ONLY` 改为 `'false'`，并重启前端即可。

## 启动后端

进入 `backend` 目录，按官方 RuoYi-Vue 的数据库与 Java 环境要求启动；前端接口代理已配置为 `localhost:8080`。

## 求职者端接口契约

数据库与业务后端接入前，请以 [求职者端接口契约](docs/agent-api-contract.md) 为准。该文档定义了候选人端的接口、字段、枚举、错误码、幂等规则，以及页面到接口的映射；RuoYi 原有管理端接口保持不变。

## 质量检查与部署

运行 `npm run check` 可执行候选人端基础校验测试和生产构建；发布前请参阅 [部署与发布检查](docs/deployment.md)。
