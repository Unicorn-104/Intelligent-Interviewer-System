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

候选人端 API 的路径与鉴权规则见 [接口契约](agent-api-contract.md)。生产页面部署于 `/user/`，登录与注册地址为 `/user/login`、`/user/register`；其他求职页面仍受原有登录和求职者身份校验保护。面试邀请、问卷与笔试副机位保留各自的匿名校验入口。

`createWebHistory(import.meta.env.BASE_URL)` 使用 Vite 构建时的基础路径。Router 的 `push/replace` 使用 `/login`、`/index` 等应用内路由，不手动拼接 `/user/`；普通链接、浏览器地址替换与生成二维码使用 `appHref()` 添加部署前缀。开发环境基础路径仍为 `/`，生产构建为 `/user/`。历史 `/user/agent/*` 与 `.html` 页面地址仅作为兼容重定向，跳转后使用无 `agent` 的新地址；后端 `/agent/v1/*` 接口保持不变。

## Nginx 示例

将 `dist/` 的内容复制到 `/srv/zhipin-ai/user/`，保留 `/user/` 的 SPA 回退与独立 API 代理。不要只改 Vite 的 `base` 而遗漏服务器回退，否则 `/user/login`、`/user/job-detail` 等深链接刷新仍会 404：

```nginx
server {
  listen 80;
  server_name example.com;
  root /srv/zhipin-ai;
  index index.html;

  location = /user {
    return 301 /user/;
  }

  location /user/ {
    try_files $uri $uri/ /user/index.html;
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
- `/user/login`、`/user/jobs`、`/user/job-detail?id=26` 刷新均返回 `/user/index.html`，但 `/prod-api/*` 不走 SPA 回退。
- 登录后刷新 `/user/index` 不应清理现有会话；从职位详情登录后应返回原页面并保留查询参数。
- 消息切换会话、简历编辑、普通点击以及 Ctrl/中键新标签页打开链接后，地址仍保持 `/user/` 前缀。
- 通过浏览器检查登录、岗位浏览、简历上传、投递和消息入口，并保留构建日志与 `traceId` 便于排障。
