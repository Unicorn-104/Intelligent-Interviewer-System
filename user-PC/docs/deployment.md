# 前端部署与发布检查

## 构建

要求 Node.js 24 和 npm。安装锁定依赖并执行发布检查：

```powershell
npm ci
npm run check
```

`check` 会先运行不依赖浏览器的校验单元测试，再执行生产构建。发布产物位于 `dist/`。

## 环境配置

生产构建读取 `.env.production`：

- `VITE_APP_BASE_API`：后端 API 前缀。默认 `/prod-api`，反向代理必须转发此路径。
- `VITE_FRONTEND_ONLY`：生产环境必须为 `'false'`。只用于页面演示时才可使用开发环境中的 `'true'`。

候选人端 API 的路径与鉴权规则见 [接口契约](agent-api-contract.md)。生产环境的 `/agent/login` 是唯一匿名候选人路由；其余 `/agent/*` 页面要求后端签发的 `candidateSession.accessToken`。

## Nginx 示例

将 `dist/` 部署到站点根目录，并保留 SPA 回退与 API 代理：

```nginx
server {
  listen 80;
  server_name example.com;
  root /srv/zhipin-ai/dist;
  index index.html;

  location / {
    try_files $uri $uri/ /index.html;
  }

  location /prod-api/ {
    proxy_pass http://127.0.0.1:8080/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

上线前确认：

- 不将 `.env.development` 的纯前端模式带入生产包。
- HTTPS 终止在网关或 Nginx；令牌接口和上传接口只接受 HTTPS。
- `/agent/*` 深链接刷新后仍返回 `index.html`，但 `/prod-api/*` 不走 SPA 回退。
- 通过浏览器检查登录、岗位浏览、简历上传、投递和消息入口，并保留构建日志与 `traceId` 便于排障。
