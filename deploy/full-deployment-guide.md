# 智能面试系统・完整部署方案（运维版）

> 适用：将仓库代码部署到 Linux 服务器，使线上与本地开发版一致。
> **核心原则：运维从 Git 仓库拉取，不要直接上传本地整个文件夹。**
> 本地目录含 
>
> `node_modules`
>
> 、本地 
>
> `application-druid.yml`
>
> （明文密码）、日志、
>
> `dump.rdb`
>
> 、
>
> `.idea`
>
> 、个人临时文件，直接上传会污染环境并泄密。



***

## 0. 架构与目录对照



| 端              | 源码目录                       | vite base      | 构建命令                            | 产物                | Nginx 路径                        |
| -------------- | -------------------------- | -------------- | ------------------------------- | ----------------- | ------------------------------- |
| 管理员端 admin     | `admin_pc/RuoYi-Vue3`      | `/admin/`      | `npm run build:prod`            | `dist/`           | `/admin/`                       |
| 企业端 enterprise | `enterprise_pc/RuoYi-Vue3` | `/enterprise/` | `npm run build:prod`            | `dist/`           | `/enterprise/`                  |
| 用户端 user       | `user-PC`                  | `/`            | `npm run build:prod`            | `dist/`           | `/`（根）                          |
| 后端             | `backend/`                 | —              | `mvn clean package -DskipTests` | `ruoyi-admin.jar` | `/prod-api/` → `127.0.0.1:8080` |



* 后端：Spring Boot 4.1.0 / RuoYi 3.9.2，端口 `8080`，context-path `/`

* 数据库：MySQL 库 `recruit_agent`，字符集 utf8mb4

* 缓存：Redis `6379`

* 三端前端 API 前缀统一 `/prod-api`，由 Nginx 反代到同一后端实例



***

## 1. 服务器环境准备（首次）



| 组件    | 要求               | 说明                                      |
| ----- | ---------------- | --------------------------------------- |
| JDK   | 17+（推荐 21，与本地一致） | `java -version` 验证；后端 Spring Boot 4     |
| Maven | 3.8+（仅打包机需要）     | 服务器只 `java -jar`，可不装 Maven，改在本地 / CI 打包 |
| Node  | 18 LTS / 20 LTS  | `node -v`；各端用 `npm ci` 按 lock 安装        |
| MySQL | 8.0              | 库 `recruit_agent`，utf8mb4               |
| Redis | 6+               | 6379，按需要设密码                             |
| Nginx | 1.20+            | 托管静态前端 + 反代                             |



***

## 2. 拉取代码（运维执行，不上传本地）



```
# 仓库（私有，需先在服务器配好只读访问密钥/凭据）
cd /data && git clone <仓库地址> Intelligent-Interviewer-System
cd Intelligent-Interviewer-System

# 发版用 main，日常可用 dev；二选一，保持团队统一
git checkout main
git pull --ff-only origin main
```

> 不要把本地 
>
> `node_modules`
>
> 、
>
> `logs/`
>
> 、
>
> `dump.rdb`
>
> 、
>
> `backend_err.log`
>
> 、
>
> `.idea/`
>
> 、个人配置拷上去，
>
> `.gitignore`
>
>  已排除未跟踪文件。



***

## 3. 数据库

### 3.1 首次建库



```
CREATE DATABASE recruit_agent DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
```

### 3.2 建表与迁移（按顺序，脚本均幂等）



```
cd /data/Intelligent-Interviewer-System
mysql -h<db_host> -u<db_user> -p recruit_agent < backend/doc/migration_recruit_menu_20261020.sql
mysql -h<db_host> -u<db_user> -p recruit_agent < backend/doc/migration_pos_status_log_20261020.sql
mysql -h<db_host> -u<db_user> -p recruit_agent < backend/doc/migrate_missing_tables_20261020.sql
mysql -h<db_host> -u<db_user> -p recruit_agent < backend/doc/migrate_seed_menu_20261020.sql
mysql -h<db_host> -u<db_user> -p recruit_agent < backend/doc/migrate_alter_columns_20261020.sql
# 其余历史 migration_*.sql 按需补跑；重复执行不报错（IF NOT EXISTS / IGNORE / 判断式 ALTER）
```

### 3.3 后端数据源配置（不提交明文）

服务器上单独维护一份 `application-druid.yml` / 用环境变量覆盖，**不要改仓库里的默认值并提交**：



* `spring.datasource.druid.master.url` → 服务器 MySQL 地址 / 库名

* `username` / `password` → 服务器库账号

* `spring.data.redis.host/port/password` → 服务器 Redis



***

## 4. 后端打包与启动

### 4.1 打包（本地或 CI 一次，产物上传；服务器不跑 Maven）



```
cd backend
mvn clean package -DskipTests
# 产物：ruoyi-admin/target/ruoyi-admin.jar
```

也可用脚本：`./deploy/backend/build-backend.sh`（输出到 `deploy/backend/dist/`）。

### 4.2 启动（沿用 deploy 脚本）



```
# 部署目录放：ruoyi-admin.jar、application.yml、application-druid.yml、run-backend.sh
chmod +x run-backend.sh
./run-backend.sh
```

`run-backend.sh` 已通过 `nohup java -jar` 后台运行，并设置持久临时目录与上传根目录

（`--ruoyi.profile=/home/ruoyi/uploadPath`，需保证写权限）。

### 4.3 校验



```
curl http://127.0.0.1:8080/captchaImage     # 200 + 验证码即正常
tail -f logs/backend.out
```

> 临时目录权限报错（Java21 + Spring Boot4）：
>
> `application.yml`
>
>  已设
> `server.servlet.session.persistent: false`
>
> ，无需额外处理。



***

## 5. 三端前端构建

对每个端分别执行（以管理员端为例）：



```
cd admin_pc/RuoYi-Vue3
npm ci                 # 严格按 package-lock 安装；无 lock 时用 npm install
npm run build:prod     # 输出 dist/
```



* 企业端：`enterprise_pc/RuoYi-Vue3` → `npm ci && npm run build:prod`

* 用户端：`user-PC` → `npm ci && npm run build:prod`

把各端 `dist/` 内容分别放到 Nginx 站点目录（见第 6 节占位），替换前先备份旧目录。



***

## 6. Nginx 配置（三端 + API 同域示例）



```
upstream recruit_backend {
    server 127.0.0.1:8080;
    keepalive 32;
}

server {
    listen 443 ssl;
    server_name 114.55.175.79;

    # 证书路径按现网替换
    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    client_max_body_size 20m;

    # 管理员端 /admin/
    location /admin/ {
        alias /data/sites/admin/dist/;
        try_files $uri $uri/ /admin/index.html;
    }

    # 企业端 /enterprise/
    location /enterprise/ {
        alias /data/sites/enterprise/dist/;
        try_files $uri $uri/ /enterprise/index.html;
    }

    # 用户端（根路径）
    location / {
        root /data/sites/user/dist;
        try_files $uri $uri/ /index.html;
    }

    # 后端 API（剥掉 /prod-api 前缀）
    location /prod-api/ {
        proxy_pass http://recruit_backend/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_connect_timeout 30s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 视频会议 SSE 信令（如启用录制/实时面试）必须关缓冲
    location /prod-api/system/conference/signal/stream {
        proxy_pass http://recruit_backend/system/conference/signal/stream;
        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 1h;
    }
}
```

校验并重载：



```
nginx -t && nginx -s reload
```

> 路径占位 
>
> `/data/sites/{admin,enterprise,user}/dist`
>
>  按现网 root/alias 实际位置替换；
> 企业端 / 候选人端 SSE 与后端互通细节见 
>
> `deploy/nginx/recruit.conf`
>
> 。



***

## 7. 部署后验收



| 项    | 操作                | 通过标准                              |
| ---- | ----------------- | --------------------------------- |
| 管理员端 | 打开 `/admin/` 登录   | 正常进入，侧边栏与本地一致，无「若依官网」旧入口          |
| 岗位管理 | 招聘管理 - 岗位         | 同公司分组折叠；下架可看原因 + 操作时间             |
| 候选人  | 候选人列表             | 状态列正确；无批量打标签；统计卡显示                |
| 简历   | 简历详情              | 工作 / 教育 / 技能 / 项目齐全；手机号脱敏；无造假来源筛选 |
| 企业端  | `/enterprise/` 登录 | 页面与接口正常                           |
| 用户端  | `/` 打开            | 页面正常、路由刷新不 404                    |
| 接口   | F12 Network       | 无 401/500，列表正常返回                  |

非超管角色看不到新目录时，在「角色管理」勾选对应菜单授权。



***

## 8. 日常更新流程（每次发版）



```
cd /data/Intelligent-Interviewer-System
git pull --ff-only origin main

# 后端有改动才重打包重启；无改动跳过
cd backend && mvn clean package -DskipTests
# 替换 jar 后重启：kill 旧进程 → ./run-backend.sh

# 前端有改动才重新 build 对应端并替换 dist，nginx -s reload
```

## 9. 回滚



* 前端：恢复上一版备份目录，`nginx -s reload`。

* 后端：换回旧 jar 重启。

* 数据库：本次迁移仅新增表 / 种子 / 可见性，无需回滚；误改用备份恢复。

## 10. 安全注意



* 仓库不提交数据库 / Redis / 邮箱明文密码；服务器配置单独存放。

* 不上传本地 `application-druid.yml`、`dump.rdb`、日志、`.idea`、`node_modules`。

* 生产关闭验证码以外的调试端点，定期备份 MySQL 与上传目录 `/home/ruoyi/uploadPath`。