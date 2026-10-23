# 管理员端部署对齐清单（feature → dev 已合并，dev HEAD=485eee1）

> 目的：运维 `git pull` 后重新部署，使线上 `https://<服务器>/admin/` 与本地开发版一致。
> 分支：仅合入 `dev`，**未推进 main**；dev→main 需完整构建验收后另行发版。

## 0. 前置

- 代码分支：`dev`（当前已含本次招聘管理改动与迁移脚本）
- 服务器：MySQL、Redis、后端 8080、Nginx 均在线
- 数据库连接信息以服务器环境配置为准，不在此记录明文密码

## 1. 拉取最新代码

```bash
cd <仓库目录>
git fetch origin
git checkout dev
git pull --ff-only origin dev
git log --oneline -1   # 应为 485eee1 或更新
```

> 若本地/服务器代理导致直连失败，临时对 git 设代理：
> `git -c http.proxy=http://127.0.0.1:7890 -c https.proxy=http://127.0.0.1:7890 pull`
> 该代理为本机加速器，不要写进服务器全局配置。

## 2. 数据库迁移（新环境/复现才执行；本服务器库已直接补过，可跳过）

脚本均为幂等（`CREATE TABLE IF NOT EXISTS` / `INSERT IGNORE` / 判断式 ALTER），按顺序执行：

```bash
mysql -h<host> -u<user> -p <库名> < backend/doc/migrate_missing_tables_20261020.sql
mysql -h<host> -u<user> -p <库名> < backend/doc/migration_pos_status_log_20261020.sql
mysql -h<host> -u<user> -p <库名> < backend/doc/migrate_seed_menu_20261020.sql
mysql -h<host> -u<user> -p <库名> < backend/doc/migrate_alter_columns_20261020.sql
mysql -h<host> -u<user> -p <库名> < backend/doc/migration_recruit_menu_20261020.sql
```

已在服务器库完成的对齐：11 张缺失表、菜单 2035、广告位/隐私种子、`sys_user.company_id` 列、菜单可见性。

## 3. 重新构建管理员端前端（界面一致的关键）

旧静态包菜单写死、不读数据库 visible，必须重新 build 并替换 `/admin/`：

```bash
cd admin_pc/RuoYi-Vue3
npm ci            # 或 npm install，保证依赖与 lock 一致
npm run build:prod
# 产物：admin_pc/RuoYi-Vue3/dist
```

将 `dist` 整体替换到 Nginx 管理员端站点目录（对应 `base: '/admin/'`），先备份旧目录：

```bash
# 示例路径，以服务器 Nginx 配置 root 为准
cp -r <旧admin目录> <旧admin目录>.bak.$(date +%Y%m%d)
rsync -a --delete admin_pc/RuoYi-Vue3/dist/ <Nginx的/admin/站点目录>/
```

Nginx 需满足：
- `location /admin/` 回退 `try_files $uri $uri/ /admin/index.html;`（history 模式刷新不 404）
- `location /prod-api/` 反代到 `127.0.0.1:8080`，结尾 `/` 剥前缀
- `client_max_body_size 20m;`

## 4. 后端（仅当 dev 比线上 jar 新时重打）

本次 PR 未改 Java 源码；若线上 jar 已是最新 dev，**无需重打**。否则：

```bash
# 本地/CI 打包（服务器不跑 Maven）
cd backend
mvn clean package -DskipTests
# 产物 backend/ruoyi-admin/target/ruoyi-admin.jar
```

重启（沿用 `deploy/backend/run-backend.sh`）：

```bash
# 停旧进程后
./run-backend.sh
# 校验
curl -k https://<服务器>/prod-api/captchaImage   # 返回 200 + 验证码即正常
```

## 5. 部署后验收清单

| 项 | 操作 | 通过标准 |
|---|---|---|
| 登录 | 打开 `/admin/` 登录 | 正常进入，无白屏 |
| 侧边栏 | 看菜单 | 与本地一致，无残留「若依官网」等旧入口 |
| 岗位管理 | 打开招聘管理-岗位 | 同公司岗位折叠分组；下架可看原因+操作时间 |
| 候选人管理 | 打开候选人列表 | 状态列正确；无批量打标签；统计卡显示 |
| 简历管理 | 打开简历，看详情 | 工作/教育/技能/项目齐全；手机号脱敏；无造假来源筛选 |
| 接口 | F12 Network | 无 401/500，列表数据正常返回 |

## 6. 回滚

- 前端：恢复步骤 3 备份的旧目录，`nginx -s reload`。
- 后端：用旧 jar 重启。
- 数据库：本次仅新增表/种子/可见性，无需回滚数据；误改可按备份恢复。

## 说明

- main 未合并：按规范 dev→main 需全量构建、测试与核心链路验收，由维护者发版。
- 非超管角色（招聘HR、运营专员等）若看不到新目录，需在「角色管理」勾选对应菜单授权。
