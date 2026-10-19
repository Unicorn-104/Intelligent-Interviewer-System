# 后端部署说明（标准流程）

本模块为 RuoYi 多模块 Maven 工程，后端入口为 `ruoyi-admin`。标准部署采用
**打包 fat jar + `java -jar`**，服务器上不需要执行 Maven，也**不需要先 `mvn install`**。

## 1. 模块结构

```
backend/
├── ruoyi-admin      # Web 入口，最终产出 fat jar
├── ruoyi-framework  # 核心框架（依赖 system/common）
├── ruoyi-system     # 业务服务（含 system/app/agent/enterprise 等包）
├── ruoyi-quartz     # 定时任务
├── ruoyi-generator  # 代码生成
└── ruoyi-common     # 通用工具
```

Maven 在根目录构建时会按依赖顺序自动串联全部模块，单模块直接编译会因
本地仓库缺少最新依赖而报“找不到符号”，这不是代码错误。

## 2. 打包（本地或 CI 执行一次）

在仓库 `backend/` 根目录执行，或直接用脚本：

```bash
# 方式一：脚本（打包并输出到 deploy/backend/dist/）
chmod +x deploy/backend/build-backend.sh
./deploy/backend/build-backend.sh

# 方式二：手动命令
cd backend
mvn clean package -DskipTests
```

产物：`backend/ruoyi-admin/target/ruoyi-admin.jar`（自包含全部依赖）。

> 不要只在 `ruoyi-admin` 目录单独 `mvn package`，那样不会构建上游依赖模块。

## 3. 服务器部署

1. 上传 `ruoyi-admin.jar` 与配置文件到同一目录：
   - `application.yml`、`application-druid.yml`（数据库/Redis/端口等环境配置）
2. 使用启动脚本 `run-backend.sh`：

```bash
chmod +x run-backend.sh
./run-backend.sh
```

脚本通过 `nohup java -jar` 后台运行，并已设置持久临时目录与上传根目录。

3. 校验：访问 `/captchaImage` 返回 200 即启动正常；日志在 `logs/backend.out`。

## 4. 本地开发启动

拉取新代码或切换分支后，在 `backend/` 根目录用 `-am`（also make）自动
连带构建依赖模块，无需先 `install`：

```bash
# 开发调试（自动先构建被依赖模块）
mvn spring-boot:run -pl ruoyi-admin -am

# 若坚持单模块调试，需先在根目录安装依赖：
mvn install -DskipTests
mvn spring-boot:run -pl ruoyi-admin
```

## 5. 常见问题

- **单模块启动报“找不到符号/找不到类”**：本地仓库里的上游模块是旧 jar。
  改用根目录 `-am` 启动，或先 `mvn install -DskipTests`。
- **临时目录权限报错（Java 21 + Spring Boot 4）**：已在 `application.yml`
  设置 `server.servlet.session.persistent: false`，避免占用系统临时目录。
- **服务器不跑 Maven**：服务器只 `java -jar`，打包在本地/CI 完成后上传。

## 6. 前端与反向代理

前端构建产物由 Nginx 托管，API 统一反代到本后端实例，参考
`deploy/nginx/recruit.conf`。管理员端 base 为 `/admin/`，需对应 location 回退。
