# 企业级智能招聘面试官 Agent 系统

> 面向中大型企业招聘场景的多端智能招聘系统。覆盖岗位发布、简历接入与 AI 解析、AI 初筛与人岗匹配、智能预约调度、LiveKit 视频会议、多模式面试与 AI 评估、在线笔试、Offer 管理、企业知识库 RAG、长期记忆与 Agent 编排等完整招聘闭环。

| 项目 | 内容 |
|------|------|
| 项目名称 | 企业级智能招聘面试官 Agent 系统 |
| 数据库 | `recruit_agent`（MySQL，81 张表 / 12 大业务模块） |
| 开发单位 | 贵州慧科未来科技有限公司 |
| 后端 | RuoYi v3.9.2 · Spring Boot 4.1.0 · JDK 17 · MyBatis · Redis · JWT |
| 企业 PC 端 | RuoYi-Vue3 v3.8.7 · Vue3 + Element Plus + Vite + Pinia |
| 求职者 PC 端 | RuoYi-Vue3 v3.9.2 · Vue3 + Element Plus + Vite |
| 求职者 App（c-app） | Flutter · Dart ^3.12.2 · LiveKit · Dio · pdfx |
| 企业 App（e-app） | Flutter · Dart ^3.13.0 · LiveKit · Dio · pdfx |

---

## 一、核心功能

- **岗位发布与搜索**：企业端发布岗位、求职者端多维筛选与 AI 推荐、企业主页与收藏。
- **简历接入与 AI 解析**：PDF 上传解析、字段 AI 编排、原文件保存、投递关联与快照。
- **AI 初筛与人岗匹配**：基于 LangChain4j 的候选人匹配与智能推荐。
- **智能预约调度**：多面试官冲突校验、日历占用、改期、系统消息与邮件通知。
- **视频会议与面试执行**：LiveKit 多人会议、候选人主画面与面试官小窗、字幕与作答、录制回放。
- **AI 评估与报告**：面试报告生成、AI 记忆与 RAG 知识库、长期记忆（Qdrant）。
- **在线笔试**：题库管理、题目分析、题目范围、考试场次分配。
- **Agent 编排**：受控工具、SSE 任务恢复、会话历史、投递/简历上下文校验。
- **消息与聊天**：IM 线程、已读回执、快捷回复、文件与图片、游客浏览。
- **Offer 管理**：Offer 流程、通知、候选人状态流转。
- **权限与租户**：RBAC 角色权限、多租户、系统监控、操作日志。

---

## 二、系统架构

```
┌──────────────────────────────────────────────────────────────┐
│                         客户端                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │ admin_pc │  │ user-PC  │  │enterprise│  │  c-app   │     │
│  │ 管理 PC  │  │求职者 PC │  │  _pc     │  │ 求职者App│     │
│  │ Vue3     │  │ Vue3     │  │ Vue3     │  │ Flutter  │     │
│  │ :5173    │  │ :5180    │  │ :10081   │  │          │     │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │
│                                                 ┌──────────┐ │
│                                                 │  e-app   │ │
│                                                 │ 企业 App │ │
│                                                 │ Flutter  │ │
│                                                 └──────────┘ │
└──────────────────────────────────────────────────────────────┘
                            │ /prod-api
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                       backend :8080                          │
│  Spring Boot 4.1.0 · Spring Security · JWT · Redis · MyBatis │
│  LangChain4j · LiveKit · RustFS (S3) · Qdrant · Tess4j      │
└──────────────────────────────────────────────────────────────┘
        │                 │                │              │
        ▼                 ▼                ▼              ▼
    MySQL :3306      Redis :6379     LiveKit :7880   RustFS (S3)
                                       Qdrant :6333
```

---

## 三、目录结构

```
Intelligent-Interviewer-System
├── backend                              # 后端（Spring Boot / RuoYi）
│   ├── ruoyi-admin                      #   启动模块（RuoYiApplication）
│   ├── ruoyi-common                     #   通用工具 / 基础组件
│   ├── ruoyi-framework                  #   框架核心（安全、拦截器、配置）
│   ├── ruoyi-system                     #   系统管理模块
│   ├── ruoyi-quartz                     #   定时任务
│   ├── ruoyi-generator                  #   代码生成
│   ├── bin / config / doc / tools       #   脚本、配置、文档、工具
│   └── pom.xml                          #   Maven 配置
├── user-PC                              # 求职者 PC 端（Vue3 + Vite，端口 5180）
├── enterprise_pc                        # 企业 PC 端
│   └── RuoYi-Vue3                       #   Vue3 + Vite，端口 10081
├── admin_pc                             # 管理 PC 端（Vue3 + Vite，端口 5173）
│   └── RuoYi-Vue3
├── c-app                                # 求职者 App（Flutter，Dart ^3.12.2）
│   └── lib/features/                    #   ai / applications / auth / companies
│                                        #   interviews / jobs / messages / profile
│                                        #   resume / support
├── e-app                                # 企业 App（Flutter，Dart ^3.13.0）
│   └── lib/features/                    #   auth / enterprise
├── deploy                               # 部署模板
│   ├── docker-compose.yml               #   LiveKit Server / Egress
│   ├── nginx/recruit.conf               #   Nginx 反代示例
│   ├── full-deployment-guide.md         #   完整部署指南
│   └── env.example / *.example.yml      #   环境变量与配置模板
├── sql                                  # 数据库建库脚本（按模块拆分）
│   ├── 01_用户体系.sql ... 14_视图.sql  #   14 个模块化脚本
│   └── 仅第 1 个文件含建库语句
├── docs                                 # 项目文档
│   ├── prd/                             #   产品需求文档
│   ├── spec/                            #   开发规范（development / git / coding-style）
│   ├── agent-unified-design/            #   Agent 统一架构
│   └── sql-audit/                       #   SQL 审计
└── log                                  # 数据库设计与使用说明
    ├── 数据库设计（精简版v4）.md
    ├── 数据库表结构全量.md
    └── 项目使用说明.md
```

---

## 四、环境要求

| 依赖 | 版本 | 说明 |
|------|------|------|
| JDK | 17+ | 后端编译运行 |
| Maven | 3.6+ | 后端依赖管理与打包 |
| MySQL | 5.7+ / 8.0 | 数据库（库名 `recruit_agent`） |
| Redis | 5.0+ | 缓存 / 会话（默认 `localhost:6379`） |
| Node.js | 18+ | 前端构建（Vite 5 要求） |
| npm / pnpm / yarn | 任选 | 前端依赖安装 |
| Flutter | 3.12+ | c-app / e-app 构建 |
| Docker | 20+ | LiveKit / RustFS / Qdrant 容器部署 |

---

## 五、快速开始

### 1. 克隆仓库

```bash
git clone git@github.com:Unicorn-104/Intelligent-Interviewer-System.git
cd Intelligent-Interviewer-System
```

### 2. 准备数据库

```sql
CREATE DATABASE recruit_agent DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
```

按 `sql/01_用户体系.sql` → `14_视图.sql` 顺序执行，再按 `backend/doc/migration_*.sql` 增量迁移。

### 3. 配置后端

敏感配置未入库，需在本地创建：

- `backend/ruoyi-admin/src/main/resources/application.yml`（端口、Redis、JWT secret）
- `backend/ruoyi-admin/src/main/resources/application-druid.yml`（MySQL、Druid 监控台）

参考 `deploy/application-druid.example.yml` 与 `log/项目使用说明.md`。

### 4. 启动后端

```bash
cd backend
mvn clean package -Dmaven.test.skip=true
java -jar ruoyi-admin/target/ruoyi-admin.jar
```

或 IDEA 运行 `com.ruoyi.RuoYiApplication`。默认端口 **8080**。

### 5. 启动各前端

```bash
# 企业 PC 端（端口 10081）
cd enterprise_pc/RuoYi-Vue3 && pnpm install && npm run dev

# 求职者 PC 端（端口 5180）
cd user-PC && pnpm install && npm run dev

# 管理 PC 端（端口 5173）
cd admin_pc/RuoYi-Vue3 && pnpm install && npm run dev
```

开发代理已在各 `vite.config.js` 中配置：`/dev-api` → `http://localhost:8080`。

### 6. 启动 Flutter App

```bash
# 求职者 App
cd c-app && flutter pub get && flutter run

# 企业 App
cd e-app && flutter pub get && flutter run
```

### 7. 部署视频会议与存储

```bash
cd deploy
docker compose up -d   # LiveKit Server / Egress
```

放行端口：`7880/tcp`、`7881/tcp`、`50000-60000/udp`。RustFS / Qdrant 按 `deploy/*.example.yml` 配置。

---

## 六、访问地址

| 入口 | 地址 | 说明 |
|------|------|------|
| 企业 PC | `http://localhost:10081` | 企业端招聘业务 |
| 求职者 PC | `http://localhost:5180` | 求职者端 |
| 管理 PC | `http://localhost:5173` | 管理后台 |
| 后端接口 | `http://localhost:8080` | REST API |
| 接口文档 | `http://localhost:8080/swagger-ui.html` | SpringDoc |
| Druid 监控 | `http://localhost:8080/druid` | 账号 `ruoyi` / 密码 `123456` |

默认登录账号：`admin` / `admin123`

---

## 七、相关文档

| 文档 | 位置 |
|------|------|
| 产品需求文档 | `docs/prd/项目PRD.md` |
| 开发规范 | `docs/spec/development.md`、`git.md`、`coding-style.md` |
| 数据库设计 | `log/数据库设计（精简版v4）.md` |
| 全量表结构 | `log/数据库表结构全量.md` |
| 项目使用说明 | `log/项目使用说明.md` |
| 完整部署指南 | `deploy/full-deployment-guide.md` |
| 后端文档 | `backend/doc/*.md`（迁移、回滚、功能说明） |
| 各端文档 | `c-app/README.md`、`backend/README.md` |

---

## 八、安全说明

以下文件已通过 `.gitignore` 排除，**不会入库**：

- `application.yml` / `application-druid.yml`（含 JWT secret、Redis、MySQL 密码）
- `*.local.yml` / `application-local.*` 本地覆盖配置
- 各类密钥、证书、日志、构建产物

clone 后请按「快速开始 → 3. 配置后端」步骤本地创建配置文件。

---

## 九、协作流程

- 分支模型：`feature/* -> dev -> main`，禁止跳级或反向合并。
- 提交规范：Conventional Commits，`<type>(<scope>): <中文摘要>`。
- PR 门禁：`feature/* -> dev` 需说明范围、验证、风险；`dev -> main` 需完整验收。
- 详见 `docs/spec/git.md` 与根目录 `AGENTS.md`。
