# A-PC 业务 API 目录与权限码命名表

## 1. 交付范围

本文以当前前端仓库为准，覆盖 `src/api` 下全部 API 文件：

- 12 个 API 域
- 52 个 JavaScript API 文件
- 核心业务、系统管理、租户、AI、内容、会员、消息、广告、监控和代码生成
- API 文件、URL 根路径、前端函数职责、权限码前缀和高风险动作


## 2. A-PC API 目录

```text
src/api/
├── login.js                    # 登录、注册、退出、锁屏、验证码
├── menu.js                     # 动态路由
├── dashboard.js                # 首页聚合
├── ad/
│   ├── advert.js
│   └── slot.js
├── ai/
│   ├── cascade.js
│   ├── model.js
│   ├── prompt.js
│   ├── quota.js
│   └── scorecard.js
├── biz/
│   ├── aiScreen.js
│   ├── business.js
│   ├── candidate.js
│   ├── exam.js
│   ├── interview.js
│   ├── interviewEval.js
│   ├── job.js
│   ├── resume.js
│   ├── resumeParse.js
│   └── schedule.js
├── content/
│   ├── category.js
│   ├── feedback.js
│   ├── help.js
│   ├── question.js
│   └── service.js
├── member/
│   ├── user.js
│   └── verify.js
├── monitor/
│   ├── cache.js
│   ├── job.js
│   ├── jobLog.js
│   ├── logininfor.js
│   ├── online.js
│   ├── operlog.js
│   └── server.js
├── msg/
│   ├── aiReply.js
│   ├── channel.js
│   ├── preference.js
│   ├── record.js
│   └── template.js
├── system/
│   ├── config.js
│   ├── dept.js
│   ├── menu.js
│   ├── notice.js
│   ├── post.js
│   ├── role.js
│   ├── service.js
│   ├── user.js
│   └── dict/
│       ├── data.js
│       └── type.js
├── tenant/
│   ├── company.js
│   └── package.js
└── tool/
    └── gen.js
```

## 3. 统一命名规则

### 3.1 API 文件

| 项目 | 规范 |
|---|---|
| 一级目录 | 与 URL 第一段、权限码第一段一致 |
| 资源文件 | 一个资源一个文件 |
| 函数命名 | `list`、`get`、`add`、`update`、`del` 加资源名 |
| 查询参数 | `query` |
| 请求体 | `data` |
| 路径参数 | `id` 或资源主键名称 |
| 下载接口 | 设置 `responseType: 'blob'` |
| 公共请求 | 统一使用 `@/utils/request` |

历史文件 `aiScreen.js`、`resumeParse.js`、`interviewEval.js` 等保持兼容；新文件不得在同一资源下混用 camelCase、snake_case 和 kebab-case。

### 3.2 URL

```text
GET    /{domain}/{resource}/list       列表
GET    /{domain}/{resource}/{id}       详情
POST   /{domain}/{resource}            新增
PUT    /{domain}/{resource}            修改
DELETE /{domain}/{resource}/{ids}      删除
PUT    /{domain}/{resource}/status     状态
POST   /{domain}/{resource}/audit      审核
POST   /{domain}/{resource}/run        执行
POST   /{domain}/{resource}/export     导出
```

特殊动作必须使用业务动词，例如 `publish`、`finalize`、`authorize`、`reschedule`、`forceLogout`，不得全部归并为 `edit`。

### 3.3 权限码

```text
{domain}:{resource}:{action}
```

标准动作：

| 动作 | 含义 |
|---|---|
| `list` | 分页或条件列表 |
| `query` | 详情、下拉或聚合查询 |
| `add` | 新增 |
| `edit` | 修改 |
| `remove` | 删除 |
| `export` | 导出 |
| `import` | 导入 |
| `changeStatus` | 修改业务状态 |
| `audit` | 审核、通过、驳回 |
| `publish` | 发布或上线 |
| `run` | 执行任务、AI 或测试 |
| `authorize` | 授权角色、用户或资源 |
| `finalize` | 定稿或确认最终结果 |
| `clear` | 清理缓存、日志等不可逆数据 |
| `forceLogout` | 强制下线 |

资源名使用当前后端兼容名称，例如 `resumeParse`、`interviewEval`、`aiScreen`。权限码变更必须同时改页面 `v-hasPermi`、菜单 `perms`、后端权限注解和权限台账。

## 4. 完整 API 与权限码矩阵

### 4.1 公共与首页

| 文件 | URL/资源 | 主要函数或动作 | 权限码 |
|---|---|---|---|
| `login.js` | `/login`、`/register`、`/getInfo`、`/logout` | 登录、注册、获取用户、退出、锁屏、验证码 | 登录态接口不使用业务按钮权限；服务端校验认证状态 |
| `menu.js` | `/getRouters` | 获取动态路由 | 服务端按角色、租户过滤 |
| `dashboard.js` | `/dashboard/*` | 统计、趋势、套餐分布、接口排行、近期日志、招聘概览 | `dashboard:overview:query`、`dashboard:log:query` |

### 4.2 核心业务 `biz`

| 文件 | URL 根路径 | 主要接口动作 | 权限码 |
|---|---|---|---|
| `candidate.js` | `/biz/candidate` | list、detail、add、edit、remove、status、tag、batchTag | `biz:candidate:list`、`biz:candidate:query`、`biz:candidate:add`、`biz:candidate:edit`、`biz:candidate:remove`、`biz:candidate:changeStatus`、`biz:candidate:tag` |
| `business.js` | `/biz/resume`、`/biz/resumeParse`、`/biz/aiScreen`、`/biz/schedule`、`/biz/interviewEval`、`/biz/candidate` | 历史聚合 API，覆盖简历、解析、AI 初筛、排期、评估、候选人 | 以资源权限码为准，不新增 `biz:business:*` 作为替代 |
| `job.js` | `/biz/job` | list、audit | `biz:job:list`、`biz:job:query`、`biz:job:audit` |
| `resume.js` | `/biz/resume` | list、query、add、edit、remove、export、download | `biz:resume:list`、`biz:resume:query`、`biz:resume:add`、`biz:resume:edit`、`biz:resume:remove`、`biz:resume:export`、`biz:resume:download` |
| `resumeParse.js` | `/biz/resumeParse` | list、query、parse、rescan、remove | `biz:resumeParse:list`、`biz:resumeParse:query`、`biz:resumeParse:add`、`biz:resumeParse:run`、`biz:resumeParse:remove` |
| `aiScreen.js` | `/biz/aiScreen` | list、query、run、status、cancel | `biz:aiScreen:list`、`biz:aiScreen:query`、`biz:aiScreen:run`、`biz:aiScreen:changeStatus`、`biz:aiScreen:cancel` |
| `schedule.js` | `/biz/schedule` | list、add、edit、cancel、reschedule、enter | `biz:schedule:list`、`biz:schedule:add`、`biz:schedule:edit`、`biz:schedule:remove`、`biz:schedule:reschedule`、`biz:schedule:enter` |
| `interview.js` | `/biz/interview` | list、query、terminate、remove | `biz:interview:list`、`biz:interview:query`、`biz:interview:terminate`、`biz:interview:remove` |
| `interviewEval.js` | `/biz/interviewEval` | list、query、submit、finalize、remove | `biz:interviewEval:list`、`biz:interviewEval:query`、`biz:interviewEval:edit`、`biz:interviewEval:finalize`、`biz:interviewEval:remove` |
| `exam.js` | `/biz/exam` | exam config、exam record list | `biz:exam:query`、`biz:exam:edit`、`biz:exam:list` |

### 4.3 AI `ai`

| 文件 | URL 根路径 | 主要接口动作 | 权限码 |
|---|---|---|---|
| `model.js` | `/ai/model` | list、query、add、edit、remove、test | `ai:model:list`、`ai:model:query`、`ai:model:add`、`ai:model:edit`、`ai:model:remove`、`ai:model:run` |
| `prompt.js` | `/ai/prompt` | list、query、add、edit、publish、versions | `ai:prompt:list`、`ai:prompt:query`、`ai:prompt:add`、`ai:prompt:edit`、`ai:prompt:publish`、`ai:prompt:queryVersion` |
| `quota.js` | `/ai/quota` | list、adjust、usage | `ai:quota:list`、`ai:quota:query`、`ai:quota:edit` |
| `cascade.js` | `/ai/cascade` | list、query、add、edit、remove | `ai:cascade:list`、`ai:cascade:query`、`ai:cascade:add`、`ai:cascade:edit`、`ai:cascade:remove` |
| `scorecard.js` | `/ai/scorecard` | list、query、add、edit、remove | `ai:scorecard:list`、`ai:scorecard:query`、`ai:scorecard:add`、`ai:scorecard:edit`、`ai:scorecard:remove` |

### 4.4 内容 `content`

| 文件 | URL 根路径 | 主要接口动作 | 权限码 |
|---|---|---|---|
| `category.js` | `/content/category` | list、query、add、edit、remove | `content:category:list`、`content:category:query`、`content:category:add`、`content:category:edit`、`content:category:remove` |
| `feedback.js` | `/content/feedback` | list、handle | `content:feedback:list`、`content:feedback:query`、`content:feedback:edit` |
| `help.js` | `/content/help` | list、query、add、edit、remove | `content:help:list`、`content:help:query`、`content:help:add`、`content:help:edit`、`content:help:remove` |
| `question.js` | `/content/question` | list、query、add、edit、remove | `content:question:list`、`content:question:query`、`content:question:add`、`content:question:edit`、`content:question:remove` |
| `service.js` | `/content/service/config` | 查询和修改客服配置 | `content:service:query`、`content:service:edit` |

### 4.5 会员 `member`

| 文件 | URL 根路径 | 主要接口动作 | 权限码 |
|---|---|---|---|
| `user.js` | `/member/user` | list、query、status、cancelAudit、logout | `member:user:list`、`member:user:query`、`member:user:edit`、`member:user:cancelAudit`、`member:user:forceLogout` |
| `verify.js` | `/member/verify` | list、audit | `member:verify:list`、`member:verify:query`、`member:verify:audit` |

### 4.6 消息 `msg`

| 文件 | URL 根路径 | 主要接口动作 | 权限码 |
|---|---|---|---|
| `template.js` | `/msg/template` | list、query、add、edit、remove | `msg:template:list`、`msg:template:query`、`msg:template:add`、`msg:template:edit`、`msg:template:remove` |
| `channel.js` | `/msg/channel` | list、edit、toggle | `msg:channel:list`、`msg:channel:edit`、`msg:channel:changeStatus` |
| `preference.js` | `/msg/preference` | list、query、edit、toggleChannel、toggleType | `msg:preference:query`、`msg:preference:edit`、`msg:preference:changeStatus` |
| `record.js` | `/msg/record` | list、resend | `msg:record:list`、`msg:record:query`、`msg:record:resend` |
| `aiReply.js` | `/msg/aiConfig`、`/msg/aiRecord`、`/msg/aiKnowledge` | AI 配置、记录、知识库增改删 | `msg:aiReply:query`、`msg:aiReply:edit`、`msg:aiReply:add`、`msg:aiReply:remove` |

### 4.7 广告 `ad`

| 文件 | URL 根路径 | 主要接口动作 | 权限码 |
|---|---|---|---|
| `slot.js` | `/ad/slot` | list、query、add、edit、remove、status | `ad:slot:list`、`ad:slot:query`、`ad:slot:add`、`ad:slot:edit`、`ad:slot:remove`、`ad:slot:changeStatus` |
| `advert.js` | `/ad/advert` | list、query、add、edit、remove、status、stats | `ad:advert:list`、`ad:advert:query`、`ad:advert:add`、`ad:advert:edit`、`ad:advert:remove`、`ad:advert:changeStatus`、`ad:advert:queryStats` |

### 4.8 租户 `tenant`

| 文件 | URL 根路径 | 主要接口动作 | 权限码 |
|---|---|---|---|
| `company.js` | `/tenant/company` | list、query、add、edit、remove、status | `tenant:company:list`、`tenant:company:query`、`tenant:company:add`、`tenant:company:edit`、`tenant:company:remove`、`tenant:company:changeStatus` |
| `package.js` | `/tenant/package` | list、query、add、edit、remove | `tenant:package:list`、`tenant:package:query`、`tenant:package:add`、`tenant:package:edit`、`tenant:package:remove` |

### 4.9 系统 `system`

| 文件 | URL 根路径 | 主要接口动作 | 权限码 |
|---|---|---|---|
| `user.js` | `/system/user` | 用户 CRUD、导入导出、重置密码、状态、角色授权、个人资料 | `system:user:list`、`system:user:query`、`system:user:add`、`system:user:edit`、`system:user:remove`、`system:user:export`、`system:user:import`、`system:user:resetPwd`、`system:user:authorize` |
| `role.js` | `/system/role` | 角色 CRUD、数据范围、状态、用户授权 | `system:role:list`、`system:role:query`、`system:role:add`、`system:role:edit`、`system:role:remove`、`system:role:export`、`system:role:authorize`、`system:role:changeStatus` |
| `menu.js` | `/system/menu` | 菜单 CRUD、树选择、排序 | `system:menu:list`、`system:menu:query`、`system:menu:add`、`system:menu:edit`、`system:menu:remove`、`system:menu:sort` |
| `dept.js` | `/system/dept` | 部门 CRUD、排序、树查询 | `system:dept:list`、`system:dept:query`、`system:dept:add`、`system:dept:edit`、`system:dept:remove`、`system:dept:sort` |
| `post.js` | `/system/post` | 岗位 CRUD | `system:post:list`、`system:post:query`、`system:post:add`、`system:post:edit`、`system:post:remove`、`system:post:export` |
| `config.js` | `/system/config` | 参数 CRUD、刷新缓存 | `system:config:list`、`system:config:query`、`system:config:add`、`system:config:edit`、`system:config:remove`、`system:config:export`、`system:config:clear` |
| `notice.js` | `/system/notice` | 公告 CRUD、置顶、已读、阅读用户 | `system:notice:list`、`system:notice:query`、`system:notice:add`、`system:notice:edit`、`system:notice:remove`、`system:notice:markRead` |
| `service.js` | `/system/privacy`、`/system/data`、`/system/theme`、`/system/maintenance` | 隐私、数据导出删除、主题、缓存、错误上报 | `system:data:query`、`system:data:export`、`system:data:delete`、`system:maintenance:cache`、`system:maintenance:report` |
| `dict/type.js` | `/system/dict/type` | 字典类型 CRUD、刷新缓存 | `system:dict:list`、`system:dict:query`、`system:dict:add`、`system:dict:edit`、`system:dict:remove`、`system:dict:export`、`system:dict:clear` |
| `dict/data.js` | `/system/dict/data` | 字典数据 CRUD | `system:dict:list`、`system:dict:query`、`system:dict:add`、`system:dict:edit`、`system:dict:remove`、`system:dict:export` |

### 4.10 监控 `monitor`

| 文件 | URL 根路径 | 主要接口动作 | 权限码 |
|---|---|---|---|
| `cache.js` | `/monitor/cache` | 查询缓存、键和值、清理 | `monitor:cache:query`、`monitor:cache:clear` |
| `job.js` | `/monitor/job` | 定时任务 CRUD、状态、立即执行 | `monitor:job:list`、`monitor:job:query`、`monitor:job:add`、`monitor:job:edit`、`monitor:job:remove`、`monitor:job:changeStatus`、`monitor:job:run` |
| `jobLog.js` | `/monitor/jobLog` | 日志列表、详情、清理 | `monitor:jobLog:list`、`monitor:jobLog:query`、`monitor:jobLog:clear` |
| `logininfor.js` | `/monitor/logininfor` | 登录日志、解锁、清理 | `monitor:logininfor:list`、`monitor:logininfor:query`、`monitor:logininfor:unlock`、`monitor:logininfor:clear` |
| `online.js` | `/monitor/online` | 在线用户、强制下线 | `monitor:online:list`、`monitor:online:forceLogout` |
| `operlog.js` | `/monitor/operlog` | 操作日志、清理 | `monitor:operlog:list`、`monitor:operlog:query`、`monitor:operlog:clear` |
| `server.js` | `/monitor/server` | 服务状态 | `monitor:server:query` |

### 4.11 工具 `tool`

| 文件 | URL 根路径 | 主要接口动作 | 权限码 |
|---|---|---|---|
| `gen.js` | `/tool/gen` | 表查询、导入、编辑、创建、预览、代码生成、同步、删除 | `tool:gen:list`、`tool:gen:query`、`tool:gen:import`、`tool:gen:edit`、`tool:gen:create`、`tool:gen:preview`、`tool:gen:code`、`tool:gen:sync`、`tool:gen:remove` |

## 5. 权限与接口安全要求

1. 页面 `v-hasPermi` 只控制展示，后端接口必须独立返回 401/403。
2. 列表、详情、导出、下载必须校验租户、部门、资源归属和数据范围。
3. 删除、导出、审核、执行、授权、清缓存、强制下线必须单独鉴权并记录审计日志。
4. `*:*:*` 仅允许超级管理员，普通角色不得通过前端传参获得该权限。
5. 权限变更后清理用户权限缓存，旧会话应在约定时间内失效。
6. 所有批量接口校验 ID 数量、重复 ID、资源归属和操作幂等性。
7. 文件上传、下载和导出接口校验文件类型、大小、资源权限和下载响应头。
8. Mock 返回的全权限账号不能作为生产安全证明。

## 6. 发布前验收

### 目录验收

- [ ] API 文件位于正确业务域目录。
- [ ] 文件名、URL 资源名、权限码资源名一致。
- [ ] 页面没有直接拼接业务 URL。
- [ ] API 文件统一使用 `@/utils/request`。
- [ ] 特殊动作没有滥用 `edit`。

### 权限验收

- [ ] 页面权限码全部登记在本文档。
- [ ] 菜单 `perms`、页面 `v-hasPermi`、后端权限注解完全一致。
- [ ] 普通用户直接调用无权限接口返回 403。
- [ ] 导出、下载、审核、执行和授权均有独立权限。
- [ ] 租户和数据范围越权用例通过。
- [ ] 高风险操作产生审计日志。

### 交付物

| 交付物 | 路径 |
|---|---|
| API 根目录规范 | `src/api/README.md` |
| 核心业务目录清单 | `src/api/biz/README.md` |
| 权限码摘要表 | `docs/A-PC业务API目录与权限码命名表.md` |
| 完整 API 与权限矩阵 | `docs/A-PC业务API完整交付版.md` |
