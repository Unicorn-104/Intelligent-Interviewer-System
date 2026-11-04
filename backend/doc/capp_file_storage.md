# 四端图片与简历原文件存储（RustFS / S3）

## 接口与数据边界

本轮从最新 `origin/dev`（`d6fc2f9`）创建 `feature/storage-four-clients-MZR`，在独立 worktree 实现。
原工作区与其中的面试、记忆及 SQL 删除等修改保持原样。本轮不提交、不推送、不部署。

| 客户端 | 适配内容 |
| --- | --- |
| 用户 PC `user-PC/` | 头像、公共图片上传组件、聊天附件地址和既有私有简历接口 |
| 企业 PC `enterprise_pc/RuoYi-Vue3/` | 头像、公共图片上传组件、人才头像、聊天附件和原始简历预览 |
| 用户 App `c-app/` | 头像、企业 Logo、消息头像地址与既有 PDF 上传/鉴权预览 |
| 企业 App `e-app/` | 头像、企业/岗位 Logo、聊天附件、人才头像和鉴权 PDF 预览 |

四端均通过后端访问文件，不接触 RustFS 内网地址或凭据。URL 辅助函数兼容新旧 profile 路径，保留 API 子路径，避免重复前缀。
两个 PC 的裁剪头像以实际 PNG 格式命名；E-App 的头像选择白名单与后端 JPG/PNG/GIF/BMP 对齐。
接口路径、上传字段与原响应字段保持兼容：

| 接口 | 行为 |
| --- | --- |
| `POST /common/upload`、`/common/uploads` | 通用图片、Logo 和原允许文件的单个/批量上传 |
| `POST /system/im/attachments` | 聊天附件共享存储配置，保留 10 MB 与类型限制 |
| `GET /common/download/resource` | 原通用下载入口兼容新的公开上传引用 |
| `POST /system/user/profile/avatar` | `avatarfile` 上传头像，仍返回 `imgUrl` |
| `POST /app/resumes/import-pdf`、`/{resumeId}/import-pdf` | 保存结构化简历与原 PDF |
| `GET /app/resumes/{resumeId}/pdf` | 校验本人归属后读取原 PDF，支持 Range |
| `/agent/v1/resumes/**` 下已有原文件与附件接口 | 原 PDF 及 PDF/Word/JPG/PNG 附件使用相同存储配置 |
| 企业人才库原 PDF 与 AI 筛选 | 保留原企业/候选人归属校验，适配云端资源读取 |

启用 S3 后原文件进入 RustFS；MySQL 仍记录文件名、大小、归属与内部引用。新对象引用形如
`s3:recruit-files/private-resume/用户ID/日期/随机名.pdf`，其中记录桶名，不记录凭据或容器地址。
现有字段足够，无需改表。原有 `private-resume/...`、`private-resume-attachment/...` 和旧
`/profile/...pdf` 仍按原逻辑读取，不自动搬迁或删除历史文件。

所有桶保持私有。简历原 PDF 与简历附件仅经过原鉴权接口读取。头像通过后端
`GET /profile/storage/avatars/{userId}/{year}/{month}/{day}/{fileName}` 展示，延续旧头像公开展示语义；
这个入口只允许头像键，不能读取简历或任意对象。新头像 URL 不包含 RustFS 内部地址或临时签名。
头像限制 5 MB，校验扩展名、声明 MIME、实际图片格式与尺寸（单边不超过 8192 像素）。

通用上传的新路径为 `/profile/storage/uploads/{userId}/{year}/{month}/{day}/{fileName}`，保持旧 `/profile/upload/` 的公开资源语义。
公开代理只允许 `uploads`、`avatars` 各自的命名空间，不能读取 `private-resume` 或 `private-resume-attachment`。
含个人资料的简历继续通过专用上传和归属鉴权接口处理，不走通用公开上传。
会议录制、系统导出/备份不在本轮迁移范围，未修改管理员 PC 源码。

## 配置

默认 `local`，现有环境无需部署 RustFS 就可以继续运行。启用 S3 时在**后端进程**配置：

| 环境变量 | 说明 |
| --- | --- |
| `FILE_STORAGE_PROVIDER` | `s3` 启用，默认 `local` |
| `FILE_STORAGE_S3_ENDPOINT` | 后端能访问的 S3 API 根地址，不是控制台地址、不带桶名或 `/prod-api` |
| `FILE_STORAGE_S3_BUCKET` | 已创建的私有桶，默认 `recruit-files` |
| `FILE_STORAGE_S3_ACCESS_KEY`、`FILE_STORAGE_S3_SECRET_KEY` | 服务器秘密配置中的应用服务账号凭据 |
| `FILE_STORAGE_S3_REGION` | 与部署匹配的签名区域，默认 `us-east-1` |
| `FILE_STORAGE_S3_PATH_STYLE` | RustFS 保持 `true` |
| `FILE_STORAGE_S3_TIMEOUT_SECONDS` | 单次调用总超时，默认 60 秒，允许 1–300 秒 |

对应 Spring 属性为 `app.storage.provider` 和 `app.storage.s3.*`，可以放入服务器外部
`application.yml`；参考 [配置模板](../../deploy/backend/file-storage.example.yml)。
不要改或提交现有私有配置，不把凭据放进 Flutter 的 `dart-define`。

### 服务器：RustFS 在容器内，后端在宿主机运行

仓库现有 [run-backend.sh](../../deploy/backend/run-backend.sh) 用 `java -jar` 运行后端。
这种情况下应配置 RustFS 已发布到宿主机的 **S3 API 端口**，例如：

```text
FILE_STORAGE_PROVIDER=s3
FILE_STORAGE_S3_ENDPOINT=http://127.0.0.1:9000
FILE_STORAGE_S3_BUCKET=recruit-files
```

这里 `9000` 是示例，必须以服务器实际 `docker ps` / Compose 端口映射为准。若映射为
`127.0.0.1:19000:9000`，后端应连接 `http://127.0.0.1:19000`。不要给宿主机 JAR 配置
`http://rustfs:9000`，Docker 服务名通常只能在所属容器网络内解析。

`run-backend.sh` 继承启动进程环境；可由现有服务管理器通过受限环境文件注入上述变量与凭据。
如果用 systemd，请在已有 unit 中引用仅部署账号可读的 `EnvironmentFile`，不要在命令行打印密钥。
仅创建环境文件不会自动影响已经运行的 JVM，需要按既有部署流程重启后端。

### 服务器：后端与 RustFS 均在容器内

把后端加入 RustFS 所在的 Docker 网络，以实际服务名/网络别名配置，例如
`FILE_STORAGE_S3_ENDPOINT=http://rustfs:9000`。此时使用容器内部 S3 API 端口，不是宿主机映射端口。
后端容器里的 `127.0.0.1` 指向后端自身，不能用它连接另一个 RustFS 容器。

以下仅展示在已有后端 Compose 服务上补充配置，网络名和服务名需匹配实际部署：

```yaml
services:
  backend:
    environment:
      FILE_STORAGE_PROVIDER: s3
      FILE_STORAGE_S3_ENDPOINT: http://rustfs:9000
      FILE_STORAGE_S3_BUCKET: recruit-files
      FILE_STORAGE_S3_ACCESS_KEY: ${FILE_STORAGE_S3_ACCESS_KEY:?required}
      FILE_STORAGE_S3_SECRET_KEY: ${FILE_STORAGE_S3_SECRET_KEY:?required}
    networks:
      - storage
networks:
  storage:
    external: true
    name: ${FILE_STORAGE_DOCKER_NETWORK:?existing RustFS network required}
```

RustFS 已部署，不需要本功能重建其容器、替换镜像或重置数据卷。应检查持久数据卷已挂载、桶已存在、
应用账号对目标桶具备 GetObject/PutObject/DeleteObject 权限。后端不会自动建桶或修改桶策略。
RustFS API 与控制台通常分别为 9000、9001；以实际部署为准。

客户端继续使用现有公网后端地址（例如带 `/prod-api` 的地址），既有 Nginx API 反代应转发新头像路由；
不要把 `/prod-api/profile/storage/` 当成磁盘静态目录处理。无需向公网开放 RustFS 桶或将容器内网地址发送给客户端。
HTTPS endpoint 使用 JVM 正常证书校验；私有 CA 应加入服务器 JVM 信任库，不跳过 TLS 校验。

## 一致性、旧文件与回滚

- UUID 文件键避免重名覆盖；文件存储与数据库不共享事务。简历沿用现有事务回调：数据库回滚清理本次新对象，提交后才清理被替换的旧对象。
- 头像只有数据库明确更新失败时才清理新文件；数据库调用抛异常/超时视为结果未知，不盲删可能已引用的对象。
- 删除失败保留受控告警，不回滚已提交的业务操作；目前没有新增持久清理队列，网络故障后可能需要人工核对孤立对象。
- 后端按上限读取对象：PDF 依据现有配置（默认 10 MB）、附件 20 MB、头像 5 MB；不把对象下载到公开磁盘目录。
- 通用上传沿用 50 MB 上限，聊天附件仍为 10 MB；S3 模式的通用图片校验实际格式与单边 8192 像素限制。
  批量上传明确失败时只清理当前请求已创建的云端对象，不清理其他用户或历史文件。
- 本地新文件配置仍由 `RESUME_PDF_STORAGE` / `ruoyi.profile` 控制。若后端容器需读取旧本地文件，必须继续挂载原目录，路径配置保持一致。
- 未开始 S3 写入时可直接切回 `local`。已有 `s3:` 引用后，不可只回滚到不识别它的旧 JAR；应保留本次读取支持与有效 S3 配置，或先另行迁回原文件并核对数据库引用。
- 切换 endpoint、服务账号或桶权限前，应验证旧引用仍能读取；简历内部引用里保存桶名，但未保存不同服务器 endpoint。
  头像与通用上传 URL 使用配置中的桶；换桶时必须迁移相应 `avatars/`、`uploads/` 对象。头像 URL 保持在原字段长度范围内。

## 验证与边界

针对性验证命令（仓库 `backend/` 下）：

```powershell
mvn -B -ntp -pl ruoyi-admin -am "-Dtest=S3FileStorageTest,AvatarStorageTest,ResumePdfPersistenceTest,TalentPoolResumePdfTest,AppResumeControllerTest,SysProfileStorageTest,StoredAvatarControllerTest,CommonFileStorageTest,StoredUploadControllerTest,ImReadReceiptControllerTest,ScreeningServiceImplTest" "-Dsurefire.failIfNoSpecifiedTests=false" test
```

测试中的 S3 HTTP 服务、H2 数据库与合成文件仅用于验证协议接入、事务清理、归属校验、旧文件兼容和响应契约，
不能代替服务器真实 RustFS 验收。上线前使用获授权的测试账号与合成资料逐项验证：

1. 从实际后端运行环境访问 RustFS API；健康检查只能证明服务在线，不能证明桶权限和文件流程正确。
2. 上传头像、保存 PDF/图片附件，确认目标桶新增对应对象，数据库没有容器地址或密钥。
3. 重新打开头像、本人 PDF 与附件，验证 PDF Range；其他账号读取私有资源被拒绝。
4. 企业端在既有授权关系下仍能预览原 PDF；AI 筛选仍能读取原简历。
5. 替换和删除合成文件，核对数据库与对象状态；发生超时先查询最终状态再决定是否重试。

服务器部署仍需按既有流程配置并验收。本文下面的实际迁移和重启记录仅涉及本地开发环境。

### 本地 RustFS 实际切换与验收（2026-11-02）

本地运行后端已显式使用 `app.storage.provider=s3`，连接 Docker RustFS 的宿主机 API 映射端口；
使用私有桶 `recruit-files`，凭据仅从容器配置读取并通过进程环境传给后端，不写入源码、日志或命令参数。

- 迁移本地已有的 3 张头像和 2 份简历 PDF，逐个下载对象校验 SHA-256；事务更新 5 处数据库文件引用，提交后独立读回核对。
- 保留原本地文件，以及 Git 忽略的迁移前快照和对象映射；不自动删除原文件或回滚真实业务数据。
- 补齐 `migration_resume_attachments_20261026.sql` 所需的 `t_res_attachment` 表，验证简历图片附件可以保存和读取。
- 真实 HTTP 验收通过：历史头像代理、通用图片上传、聊天图片上传、聊天 TXT 附件上传与下载、私有简历 PDF 上传与读取、PDF Range 206、简历图片附件上传与读取，以及迁移后历史 PDF 读取。
- 私有 PDF 与简历附件匿名访问被拒绝。聊天上传验收没有发送消息，没有替换用户当前头像；验收简历通过业务接口删除，验收对象已清理，有效简历数与消息数恢复原值。
- 本机目录中没有历史聊天附件需要搬运；验收清理后桶中保留 5 个迁移对象。此记录不代表服务器容器或四端全部设备均已验收。

本地 `backend/tools/start_ai_local.ps1` 现在默认使用 S3/RustFS。可沿用 `-SkipMigration` 参数跳过 AI 迁移，
脚本在本地 API 地址与 Docker 映射端口匹配时读取 `rustfs` 容器凭据；远程 endpoint 必须显式提供成对的凭据环境变量。
缺少容器或凭据时在停止旧后端前中止，不自动退回本地存储。此启动脚本不创建桶、不迁移历史文件。
只有显式传入 `-FileStorageProvider local` 才启用旧开发存储方式。

### 本轮验证记录（2026-11-02，基线 d6fc2f9）

下表为接入与本地运行阶段的记录。随后在独立交付分支 `feature/storage-rustfs-MZR`、相同 dev 基线重新验证：

- Backend：73 项相关测试通过，Maven 编译与可执行 JAR 打包通过。
- 用户 PC：`npm ci --no-audit --no-fund --prefer-offline`、59 项单元测试和生产构建通过。
- 企业 PC：相同依赖安装检查、3 项单元测试和生产构建通过。
- C-App：改动的 4 个 Dart 文件格式检查通过，`flutter analyze --no-pub` 无问题，资源 URL 与 PDF 上传/预览共 18 项测试通过。
- E-App：改动的 7 个 Dart 文件格式检查无变化；因依赖未解析存在 lints 引用警告。`flutter pub get --offline` 确认 Dart `^3.13.0` 与本机 `3.12.2` 不匹配，analyze、Flutter 测试及构建未执行。
- 本地启动脚本 PowerShell 语法检查通过。交付文件凭据模式、差异及范围检查通过；不提交任何本地真实文件或运行状态。

交付分支未重启运行中的后端或覆盖模拟器 App；此前开发工作区的 Debug 构建、设备运行和真实 RustFS 记录不冒充交付分支设备验收。
服务器与四端完整设备验收仍待完成，功能 PR 保持 Draft，不推进 dev 到 main。

| 检查 | 结果与边界 |
| --- | --- |
| Backend | 编译、73 项相关测试和标准可执行 JAR 打包全部通过；产物为当前 worktree 的 `backend/ruoyi-admin/target/ruoyi-admin.jar` |
| 用户 PC | `npm ci`、59 项单元测试、生产构建通过；最终辅助函数补充静态头像用例后，再次通过 3 项专项测试及生产构建 |
| 企业 PC | `npm ci`、3 项单元测试、生产构建通过 |
| C-App | `flutter analyze --no-pub` 无问题；资源 URL、PDF 上传与预览共 18 项测试在最终源码上通过 |
| E-App | `flutter pub get` 被 SDK 约束阻塞：项目要求 Dart `^3.13.0`，本机为 3.12.2。保留项目约束，未替换 SDK，不能宣称 Flutter 分析/测试/构建通过 |
| 两个 App 的纯 Dart 辅助函数 | 对实际源码执行 34 项地址和安全断言，通过；不等同 E-App Flutter 集成验证 |
| 本地 RustFS 与接口 | 已连接本机 Docker RustFS、迁移 5 个真实文件、以 S3 配置重启本地后端并通过真实账号上传/读取验收；详见上节 |
| 服务器与四端设备 | 未部署或验收服务器 RustFS；四端全部设备仍未逐一验收，不能以共享后端接口验收替代 |

后端测试使用 S3 HTTP 夹具和 H2，不代替真实 RustFS/MySQL 验收。
最新 dev 上的 24 项筛选回归通过；原工作区旧基线的两项失败不属于当前结果。
Node 存在间接依赖的 engine 提示（要求 >=22.22，本机 22.20）；两端生产构建通过，未升级 Node。
构建产物、缓存和本地日志均不纳入源码交付。

PC 各端在自身目录下执行 `npm ci`、`npm run test:unit`、`npm run build:prod`。
E-App 后续使用满足其 `pubspec.yaml` 要求的 Flutter/Dart 环境执行：

```powershell
flutter pub get
flutter analyze
flutter test test/resource_url_test.dart test/profile_data_source_test.dart test/chat_attachment_and_quick_api_test.dart test/talent_resume_pdf_test.dart
flutter build apk --debug
```

上述 E-App 命令为待执行步骤。上线前仍需完成实际桶权限、上传/读取/替换/删除及四端互通验收。

参考：[RustFS 容器安装](https://github.com/rustfs/docs.rustfs.com/blob/main/content/en/installation/container/docker.md)、
[S3 兼容矩阵](https://docs.rustfs.com/en/reference/s3-compatibility)、
[AWS Java SDK endpoint 配置](https://docs.aws.amazon.com/sdk-for-java/latest/developer-guide/endpoint-config.html)。
