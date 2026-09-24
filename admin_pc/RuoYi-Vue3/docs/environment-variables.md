# 环境变量说明

## 文件说明

| 文件 | 用途 | 命令 |
|------|------|------|
| `.env.development` | 本地开发 | `npm run dev` |
| `.env.production` | 生产构建 | `npm run build:prod` |
| `.env.staging` | 预发构建 | `npm run build:stage` |

## 变量列表

### VITE_APP_TITLE
页面标题，显示在浏览器标签和登录页。

### VITE_APP_ENV
环境标识：`development` / `staging` / `production`。

### VITE_APP_BASE_API
API 请求前缀，axios baseURL。开发环境走 Vite proxy，生产由 Nginx 反向代理。

| 环境 | 值 |
|------|-----|
| development | `/dev-api` |
| staging | `/stage-api` |
| production | `/prod-api` |

### VITE_APP_USE_MOCK
是否启用前端 mock 数据。

- `true`：使用 `src/mock/` 本地假数据，无需后端
- `false`：请求真实后端接口

开发环境默认 `true`，生产/预发必须 `false`。

### VITE_APP_TARGET
仅开发环境生效。Vite dev server 的 proxy 目标地址，即后端服务地址。

默认 `http://localhost:8080`。

### VITE_BUILD_COMPRESS
生产构建时是否开启 gzip 压缩。当前配置为 `gzip`。

## 新增环境变量

在对应 `.env.*` 文件中添加 `VITE_` 前缀的变量，然后通过 `import.meta.env.VITE_XXX` 读取。
