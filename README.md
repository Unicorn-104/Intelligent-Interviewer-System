# 企业级智能招聘面试官 Agent 系统

> 基于 RuoYi-Vue（前后端分离）框架二次开发的企业级智能招聘面试官 Agent 系统，
> 面向 C 端求职者、B 端 HR、管理员三类用户，覆盖招聘核心、面试评估、在线笔试与双机位、
> 面试流程编排、Agent 管理、Offer 管理、权限角色等业务域。

| 项目 | 内容 |
|------|------|
| 项目名称 | 企业级智能招聘面试官 Agent 系统 |
| 数据库 | `recruit_agent`（MySQL，81 张表 / 12 大业务模块） |
| 开发单位 | 贵州慧科未来科技有限公司 |
| 后端框架 | RuoYi v3.9.2（Spring Boot 4.1.0 / JDK 17 / MyBatis / Redis / JWT） |
| 前端框架 | RuoYi-Vue3 v3.8.7（Vue3 + Element Plus + Vite + Pinia） |

---

## 一、项目简介

本项目是一套**企业级智能招聘面试官 Agent 系统**，采用前后端分离架构：

- **后端**：Spring Boot + Spring Security + Redis + JWT，基于 MyBatis 持久层，
  内置代码生成器、定时任务、服务监控等能力。
- **前端**：Vue3 + Element Plus + Vite + Pinia，含后台管理端与「企业端」招聘业务模块。
- **数据库**：MySQL，共 81 张表，划分为 12 大业务模块（详见 `log/数据库设计（精简版v4）.md`）。

---

## 二、目录结构

```
Intelligent-Interviewer-System
├── backend                              # 后端工程（Spring Boot / RuoYi）
│   ├── ruoyi-admin                      #   启动模块（入口 RuoYiApplication）
│   ├── ruoyi-common                     #   通用工具 / 基础组件
│   ├── ruoyi-framework                  #   框架核心（安全、拦截器、配置）
│   ├── ruoyi-system                     #   系统管理模块
│   ├── ruoyi-quartz                     #   定时任务模块
│   ├── ruoyi-generator                  #   代码生成模块
│   ├── bin                              #   打包 / 运行脚本
│   ├── doc                              #   数据库脚本与文档
│   ├── pom.xml                          #   Maven 配置
│   ├── ry.bat / ry.sh                   #   jar 启停脚本
│   └── README.md                        #   后端 README
├── enterprise_pc                        # 前端工程
│   └── RuoYi-Vue3                       #   Vue3 + Vite
│       ├── src/views/system             #     系统管理页面
│       ├── src/views/monitor            #     监控页面
│       ├── src/views/tool               #     工具页面
│       ├── src/views/enterprise         #     ★ 企业端招聘业务模块（自定义）
│       ├── src/api                      #     接口封装
│       ├── .env.development             #     开发环境变量
│       ├── .env.production              #     生产环境变量
│       └── vite.config.js               #     端口 / 代理配置
├── log                                  # 项目文档目录
│   ├── 数据库设计（精简版v4）.md        #   数据库设计文档
│   ├── 数据库表结构全量.md              #   全量表结构
│   └── 项目使用说明.md                  #   详细使用说明
├── .gitignore
└── README.md                            # 本文件
```

---

## 三、环境要求

| 依赖 | 版本要求 | 说明 |
|------|----------|------|
| JDK | 17+ | 后端编译运行 |
| Maven | 3.6+ | 后端依赖管理与打包 |
| MySQL | 5.7+ / 8.0 | 数据库（库名 `recruit_agent`） |
| Redis | 5.0+ | 缓存 / 会话（默认 `localhost:6379`） |
| Node.js | 18+ | 前端构建（Vite 5 要求） |
| 包管理器 | npm / yarn / pnpm | 前端依赖安装（三选一） |

---

## 四、快速开始

### 1. 克隆仓库

```bash
git clone git@github.com:Unicorn-104/Intelligent-Interviewer-System.git
cd Intelligent-Interviewer-System
```

### 2. 准备数据库

新建数据库：

```sql
CREATE DATABASE recruit_agent DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
```

按 `log/数据库设计（精简版v4）.md` 与 `backend/doc/` 中的脚本顺序执行建表与初始化数据。

### 3. 配置后端（敏感配置不入库，需本地创建）

后端的两个配置文件因含密码、密钥**未纳入版本控制**，需在本地手动创建：

- `backend/ruoyi-admin/src/main/resources/application.yml`（主配置：端口、Redis、JWT secret 等）
- `backend/ruoyi-admin/src/main/resources/application-druid.yml`（数据源：MySQL 账号密码、Druid 监控台账号）

可参考 `log/项目使用说明.md` 中的配置示例，或从团队成员处获取模板，自行填入本地密码：

```yaml
# application-druid.yml 示例片段
spring:
  datasource:
    druid:
      master:
        url: jdbc:mysql://localhost:3306/recruit_agent?useUnicode=true&characterEncoding=UTF-8&serverTimezone=GMT%2B8
        username: root
        password: 你的数据库密码
```

### 4. 启动后端

```bash
cd backend
mvn clean package -Dmaven.test.skip=true       # 打包
java -jar ruoyi-admin/target/ruoyi-admin.jar    # 运行
```

或在 IDEA 中直接运行入口类：
`backend/ruoyi-admin/src/main/java/com/ruoyi/RuoYiApplication.java`

> 后端默认端口 **8080**，启动成功后访问 `http://localhost:8080`。

### 5. 启动前端

```bash
cd enterprise_pc/RuoYi-Vue3

# 安装依赖（三选一，推荐 pnpm）
pnpm install --registry=https://registry.npmmirror.com
# 或 npm install --registry=https://registry.npmmirror.com
# 或 yarn install

# 启动开发服务
npm run dev
```

> 前端默认端口 **80**（`http://localhost`）。
> 开发代理已在 `vite.config.js` 中配置：`/dev-api` → `http://localhost:8080`。

### 6. 生产构建

```bash
# 前端
cd enterprise_pc/RuoYi-Vue3
npm run build:prod        # 生成 dist/ 目录
```

---

## 五、访问地址与默认账号

| 入口 | 地址 | 说明 |
|------|------|------|
| 前端页面 | `http://localhost` | 登录后进入系统 |
| 后端接口 | `http://localhost:8080` | REST 接口 |
| 接口文档 | `http://localhost:8080/swagger-ui.html` | SpringDoc 自动生成 |
| Druid 监控 | `http://localhost:8080/druid` | 账号 `ruoyi` / 密码 `123456` |

**默认登录账号**：`admin` / `admin123`

---

## 六、相关文档

| 文档 | 位置 |
|------|------|
| 详细使用说明 | `log/项目使用说明.md` |
| 数据库设计文档 | `log/数据库设计（精简版v4）.md` |
| 数据库表结构全量 | `log/数据库表结构全量.md` |
| 后端 README | `backend/README.md` |
| 前端 README | `enterprise_pc/RuoYi-Vue3/README.md` |

---

## 七、安全说明

为防止敏感信息泄漏到公开仓库，以下文件**已通过 `.gitignore` 排除**，不会入库：

- `backend/ruoyi-admin/src/main/resources/application.yml`（含 JWT secret、Redis 等）
- `backend/ruoyi-admin/src/main/resources/application-druid.yml`（含 MySQL 与 Druid 监控台账号密码）
- 各类 `*.local.yml` / `application-local.*` 本地覆盖配置

clone 后请按「快速开始 → 3. 配置后端」步骤本地创建上述文件。
