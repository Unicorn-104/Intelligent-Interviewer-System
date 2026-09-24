# A-PC API 目录

本目录是 A-PC 管理端唯一的前端 API 请求入口。API 文件只负责组装
`request` 参数，不在其中处理页面状态、权限展示或业务组件逻辑。

## 目录约定

```text
src/api/
├── login.js
├── menu.js
├── dashboard.js
├── system/
├── tenant/
├── biz/
├── ai/
├── content/
├── member/
├── msg/
├── ad/
├── monitor/
└── tool/
```

| 层级 | 命名 | 说明 |
|---|---|---|
| 一级目录 | `lowercase` | 业务域，与 URL 第一段和权限码第一段一致 |
| API 文件 | 资源名 | 一个文件对应一个资源 |
| 请求函数 | `list/get/add/update/del + Resource` | 与接口动作对应 |
| URL | `/{domain}/{resource}/{action}` | 使用后端已确认的资源路径 |

## 新增 API 交付清单

新增模块必须同时完成：

1. 在 `src/api/{domain}/{resource}.js` 新建请求文件。
2. 统一从 `@/utils/request` 发起请求。
3. 为列表、详情、写入、删除、状态和高风险动作分别声明函数。
4. 在页面使用对应权限码，并登记到 `docs/A-PC业务API目录与权限码命名表.md`。
5. 后端同步完成接口鉴权、数据范围校验和操作日志。

## 约束

- 不在页面中直接拼接业务 API URL。
- 不在 API 文件中绕过 `request` 直接使用 `fetch` 或 `axios`。
- 不把 `edit` 复用于审核、执行、授权等高风险动作。
- 历史文件名和权限码保持兼容；新文件按项目现有路径约定落地。
