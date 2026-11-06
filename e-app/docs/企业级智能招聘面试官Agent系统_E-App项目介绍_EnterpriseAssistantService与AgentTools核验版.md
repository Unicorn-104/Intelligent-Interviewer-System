# 企业级智能招聘面试官 Agent 系统------项目介绍与 E-App 开发总结

> **项目角色：** 企业招聘移动端（E-App）开发\
> **项目仓库：**
> https://github.com/Unicorn-104/Intelligent-Interviewer-System\
> **代码参考分支：** `dev`\
> **整理日期：** 2026-10-29（依据运行截图与服务器 Docker 运行信息更新）\
> **用途：** 项目汇报、简历扩展介绍、技术答辩、开发交接与部署说明

> **本轮核验进度：** 已根据用户提供的服务器
> `docker ps`、进程列表和目录信息核实运行容器与端口绑定；尚未取得
> Compose 文件路径、容器挂载/入口、记忆服务代码、后端 Agent
> 调用链等下一阶段证据。文档不会把未执行或未返回的远程检查写成已完成。

## 0. 阅读说明与真实性边界

本文结合公开仓库中**已经核验的
README、`pubspec.yaml`、`package.json`、Maven POM 和若干 E-App
源文件**，重点说明企业移动端。为便于讲解，区分以下三种情况：

-   **【已核实：源码】**：有可定位的源码、依赖声明或真实 API
    调用链支持。
-   **【已核实：运行截图】**：2026-10-29
    提供的企业移动端运行截图能够直接证明的用户可见功能，不能反推出内部代码。
-   **【演示/预留】**：仓库明确标识为 Mock、Demo、TODO
    或尚未接通的功能；不应对外表述成已上线。
-   **【参考设计】**：为讲解原理、架构或给出可实施部署而补充的代码与方案；**并非声称仓库已采用**。

**重要修订（2026-10-29，依据真实运行截图）：企业侧「AI
招聘助手」已经可以实际对话并生成招聘文案，不能再概括为"仅是占位"。**
截图中实际展示了用户提问"帮我写一段友好的沟通开场白"、AI
返回通用版和已投递候选人版话术，以及复制按钮、新建对话与历史记录入口、停止状态和
Markdown 样式。**这属于运行体验得到验证的功能。**

需要同时保留代码差异事实：公开仓库 `dev` 分支里
`AssistantPlaceholderPage` 与 `assistant_api.dart/chatWithAssistant()`
仍对应旧的占位入口及
`UnimplementedError`；说明**当前可运行的聊天功能不能仅用这两个旧文件定位**。可能存在其他实现入口、构建版本差异或未同步提交；在没有实际安装包源码/请求日志的情况下，不确定是哪一种，不能把旧占位接口当成"全部企业
AI 助手"。`InterviewWorkbenchPage` 与独立 `ScreeningTaskListPage`
的部分功能仍按仓库 Mock 标识呈现。**岗位详情 AI 筛选 API 和 LiveKit
Flutter 会议引擎已有仓库源码支持。**

**新增的服务器运行证据（2026-10-29）：** 根据用户在 SSH
登录服务器后实际执行的 `docker ps` 与 `ps -ef` 输出，该服务器上正在运行
`hr-backend`（镜像 `hr-backend:latest`，端口绑定
`127.0.0.1:8080->8080`）、`memory-embedding`（镜像
`python:3.11-slim`）、`qdrant`（`qdrant/qdrant:latest`，健康状态
`healthy`，宿主机回环地址映射 `127.0.0.1:6333-6334`），以及 LiveKit
Server 和 Egress 容器。Java 进程运行
`/app/ruoyi-admin.jar`，启动参数包含
`--spring.profiles.active=druid,docker`；宿主机 Nginx
进程也在运行。**这证明服务器部署中存在后端、Python
记忆/向量相关基础设施与 LiveKit
服务，但单凭容器名称和进程列表，尚不能证明 AI 招聘助手一定调用了
`memory-embedding` 或 Qdrant。** 截至本文整理时，Compose
配置、容器日志和具体调用关系尚未读取，因此这些连接关系仍标记为待核验；文档不会虚构真实调用链。

对于 Agent，"能正常与模型对话"与"已证实服务端具备短期记忆及 Function
Calling 工具执行链"是两回事。**AI
聊天已可用；模型厂商、SSE/WebSocket/普通
HTTP、会话历史持久化、`memory-embedding`/Qdrant
是否参与、LangChain4j/自建 Agent
循环、真实工具注册表等仍需以当前运行版本的后端源码、Compose
配置或脱敏日志核验。**后文将已证实的客户端体验、已确认的部署事实和仍待核验的
Agent 内部实现分开写。

------------------------------------------------------------------------

## 一、项目名称

**中文名称：** 企业级智能招聘面试官 Agent 系统\
**英文描述：** Intelligent Interviewer System --- Enterprise Recruiting
& AI Interview Agent Platform\
**移动端应用名称：** E-App（Enterprise Recruiter，企业招聘移动端）

**项目定位：**
将岗位发布、人才筛选、智能匹配、招聘沟通、面试日程、在线面试、结果评估及招聘流程管理连接为一体的多端协同智能招聘平台。

## 二、项目简介

### 2.1 精炼版（项目汇报/简历）

项目是一套基于 **RuoYi + Spring Boot + MySQL + Redis + Vue 3 + Flutter**
的企业级智能招聘与面试系统，包含**求职者移动端（C-App）、企业招聘移动端（E-App）、企业
PC 端、管理员 PC 端、求职者 Web 端及 Java 后端**。系统覆盖岗位 JD
解析与流程编排、求职者画像与岗位适配分析、AI
初筛推荐、招聘即时通讯、面试邀请、LiveKit
实时视频面试及招聘业务管理，帮助企业提升岗位发布、筛选和面试协作效率。

**本人主要负责 E-App 的 Flutter 客户端开发及相关接口联调**，重点参与岗位
JD 文档导入与结构化编辑、AI
候选人适配结果展示与筛选任务管理、**已能实际对话的企业 AI 招聘助手**及其
Agent 相关能力、LiveKit
视频会议接入。关于短期记忆和工具调用的代码归属，仍以本人实现和对应服务端源码为准。

### 2.2 系统端划分

  -------------------------------------------------------------------------------------------------------------------------------------------------------------
  模块           目录                          使用群体                   主要职责                                             主要技术
  -------------- ----------------------------- -------------------------- ---------------------------------------------------- --------------------------------
  求职者移动端   `c-app/`                      求职者                     岗位浏览、求职资料、投递及面试相关移动端体验         Flutter / Dart
  C-App                                                                                                                        

  企业移动端     `e-app/`                      HR、企业招聘人员、面试官   岗位管理、JD 导入、候选人查看、AI                    Flutter / Dart
  E-App                                                                   筛选、消息、会议与面试                               

  企业 PC 端     `enterprise_pc/RuoYi-Vue3/`   企业 HR 与管理人员         招聘业务管理、面试协作、后台业务工作台               Vue 3 / Element Plus / Vite

  管理员 PC 端   `admin_pc/RuoYi-Vue3/`        系统管理员                 系统配置、账号权限与基础运维管理                     Vue 3 / Element Plus / Vite

  求职者 Web 端  `user-PC/`                    求职者                     Web 端求职、登录、岗位及 Agent 相关页面              Vue 3 / Vite / Element Plus

  统一后端       `backend/`                    所有客户端                 认证鉴权、招聘业务、数据持久化、AI                   Spring Boot / MyBatis / MySQL /
                                                                          服务接口、会议会话                                   Redis

  部署相关目录   `deploy/`                     开发、测试和运维人员       部署资源及环境相关文件；具体内容需进一步逐文件核验   Docker
                                                                                                                               等部署技术（参考方案见第六章）
  -------------------------------------------------------------------------------------------------------------------------------------------------------------

> 仓库根 README 主要介绍后端及企业 PC
> 端，移动端和其他端需要结合各自目录核对，不能只根据根 README
> 推断所有功能已实现。

### 2.3 逻辑架构

``` mermaid
flowchart TB
    C[求职者 C-App] --> API[Spring Boot / RuoYi 后端 API]
    E[企业 E-App Flutter] --> API
    CP[企业 PC Vue3] --> API
    AP[管理 PC Vue3] --> API
    UP[求职者 Web Vue3] --> API
    API --> DB[(MySQL recruit_agent)]
    API --> R[(Redis)]
    API --> AI[大模型/AI 分析服务（接口及具体实现需核验）]
    E -->|签发 Token 后连接| LK[LiveKit 实时音视频服务]
    C -->|视具体客户端接入| LK
    API -->|会议场次、鉴权、Token| LK
```

核心原则：**业务接口、用户权限及持久化数据由 Java 后端统一管理；Flutter
主要负责用户交互、状态展示与媒体客户端接入；LiveKit
承担实时音视频信令和媒体传输**。E-App 不直连
MySQL，也不应在移动安装包中保存大模型密钥或 LiveKit 服务端密钥。

------------------------------------------------------------------------

## 三、项目功能（按端尽可能展开）

### 3.1 企业招聘移动端 E-App------本人重点

**（1）账号与应用基础【已核实】**

企业账号登录；图形验证码；Token 安全存储；启动时恢复登录态；失效 Token
清理；登出；统一 HTTP
请求和错误处理；网络超时提示；不同环境接口地址切换；Material Design
界面主题；四大底部导航页（首页、岗位、消息、我的）；子页面嵌套路由；导航返回与底栏显隐控制；页面回到顶部；加载骨架屏、空态与错误重试。

**（2）招聘首页与工作台【已核实】**

企业身份信息；招聘概览；统计数据；待办跳转；最新投递与候选人摘要；面试预览；面试日历；公告入口；快捷功能入口；未读消息数据；刷新及多数据源异步加载；从首页直达岗位、候选人和面试场次。

**（3）岗位管理【已核实】**

岗位列表；关键字搜索；状态筛选；列表分页与加载更多；排序条件；岗位上下线；岗位详情；岗位新增；岗位编辑；岗位删除；岗位预览；所属企业及部门加载；工作城市、岗位性质、学历要求、经验要求、薪资上下限、职责、任职要求、技能标签维护；薪资面议处理；保存异常提示；未保存内容离开确认；查看
JD 岗位画像；创建和编辑招聘流程。

**（4）JD 智能导入与招聘流程编排【已核实】**

从文件选择器导入 PDF/DOCX；文档后缀与大小校验（10
MB）；分块读取文件；multipart
上传；上传进度展示；请求取消；解析超时和重试；接收结构化 JD
草稿；字段类型和枚举校验；薪资范围一致性校验；职责、要求、技能标签提取结果预览；必备/加分技能显示；解析警告展示；人工审核草稿；对当前表单生成差量
Patch；覆盖旧字段前确认；解析结果回填；保存岗位；编排招聘阶段（在线笔试、AI
技术面试、HR
综合面试、编程实操）；配置阶段时长、通过阈值、重点考察项、必选/可跳过/失败终止；阶段增删改与招聘工作流保存。

**（5）AI 求职者岗位适配与推荐【已核实 API，部分独立页面演示】**

从岗位查看候选人；读取结构化画像；获取岗位候选人评分；发起异步 AI
筛选；选择增量分析与全量重算；任务轮询；分析完成后刷新；查看排序与维度明细；读取
Top N
短名单；查看匹配点、风险点、待核实点等推荐报告；读取候选人个性化招呼语；人工复核与评分调整
API；候选人详情入口；简历解析数据与原始 PDF
查看能力。独立筛选任务列表、某些短名单/招呼语演示页面仍可能使用
Mock，**以岗位详情真实 API 链路为准**。

**（6）人才管理【已核实相关页面/接口引用】**

候选人基本资料；投递岗位关联；人才详情；候选人简历解析结果；原始简历 PDF
下载和预览；招聘阶段状态展示；从岗位和首页进入人才详情；候选人操作与业务状态跳转。细分操作以
`features/enterprise/talent/` 对应页面和接口为准。

**（7）招聘沟通与面试邀请【已核实】**

消息中心；候选人会话；点对点会话查询；不存在会话时创建；发送招聘相关消息；面试预约与邀请；通过服务端生成随机面试链接；将链接发送到候选人聊天；打开会话；防止重复发起；面试方式与面试官人数联动。

**（8）面试日程与视频会议【已核实】**

正式面试日程查询；日期范围筛选；列表分页控制；面试详情；真实预约 ID
和会话 ID 一致性校验；查询会议上下文；面试官登记入会；获取 LiveKit 入会
Token；连接会议室；麦克风开关；摄像头开关；前后摄像头切换；远端参会者音视频渲染；宫格布局；成员面板；本人小窗；发言者状态；只读旁听角色；连接中、重连、断线状态提示；15
秒一次会话心跳；离开会议与结束面试分别处理；媒体轨道与事件监听器释放；异常重试。

**（9）AI 招聘助手【已核实：运行截图，部分内部机制待核验】**

企业招聘助手聊天界面；用户自然语言输入；AI
生成招聘沟通话术；根据沟通场景输出多个版本（如首次联系候选人、已投递候选人）；带标题、加粗、引用的富文本/Markdown
风格展示；生成结果一键复制；新建对话入口；对话历史入口；回答停止状态显示；输入框和发送按钮；底部
AI
生成内容核实提示。**注意：**"新建对话""历史记录"是截图可见的入口；截图本身尚未测试跨会话恢复和历史持久化。生成"已停止"说明存在该显示状态，不足以单独证明使用
SSE 流式传输或真正的中断 API。

**（10）评估、终审、Offer、通知【部分演示/预留】**

面试评估接口及结果显示能力；实时字幕、AI
面试提词、人工接管接口预留；终审页面、Offer
页面、通知日志、通知模板、调研结果页等功能入口。**请区分真实业务页面和
Demo；部分 Mock 实时字幕与 AI
提词仍不能当成生产能力，但已经实际可用的企业 AI
招聘助手也不能因旧文件名含 `Placeholder` 就被误判为全功能占位**。

### 3.2 求职者移动端 C-App

**仓库已核实基础能力：** Flutter
应用、账号敏感信息安全存储、照片/文件选择、Markdown 展示、PDF
预览。**业务功能范围（系统设计与端定位）：**
求职者注册登录、个人资料、简历上传与维护、岗位搜索、岗位详情、职位申请、投递记录、面试邀请、面试准备、招聘沟通、面试结果查询等。后面这些具体功能是否完整上线，需要逐页核对
`c-app/lib/`，不可仅凭业务目标认定已实现。

### 3.3 企业 PC 端

**仓库确认的企业业务方向：**
招聘业务管理；岗位和企业基础信息；招聘总览；面试会议；人才筛选与候选人管理；招聘流程配置；消息与协同；权限相关页面。原有
RuoYi
页面包括用户/角色/菜单管理、部门/岗位等基础管理、操作日志、监控和工具能力；具体企业自定义功能及权限由
`src/views/enterprise/` 和相应 API 控制。

### 3.4 管理员 PC 端

系统管理；用户角色和权限；菜单配置；基础数据与系统参数；日志、后台监控、数据统计与报表类页面；系统运维辅助功能。以
`admin_pc/RuoYi-Vue3`
对应代码为实际范围，平台级功能与当前已开放的管理员菜单不完全等同。

### 3.5 求职者 Web 端

求职者网页入口；前端登录与鉴权；岗位及求职相关页面；Agent
相关页面目录；API
契约和页面校验；在线招聘业务及候选人侧面试流程。该端开发文档特别指出：开发环境可能启动**纯前端演示模式**，正式联调/生产部署需关闭
`VITE_FRONTEND_ONLY`。

### 3.6 Java 后端

统一认证与授权；验证码与 JWT；MySQL 数据管理；Redis 缓存/会话；岗位
CRUD；招聘流程；JD 文本/文档解析；OCR 支持依赖；AI 筛选任务
API；候选人评分结果；短名单与报告；即时通讯相关接口；会议场次和面试官加入；LiveKit
Token 签发；面试心跳、状态与结果；SpringDoc 接口文档；Quartz
定时任务；代码生成；用户权限管理。

------------------------------------------------------------------------

## 四、项目技术栈与依赖库（横向书写）

> 依照要求，**技术栈均采用横向排列，不使用逐项竖排列表**。版本以仓库直接依赖声明为准；`^`
> 代表允许的兼容版本区间，不等于锁文件最终安装版本。

### 4.1 E-App：Flutter 企业移动端

**语言 / 框架：** Dart（SDK `^3.13.0`）｜Flutter SDK｜Material
Design｜Cupertino Icons `^1.0.8`。\
**网络与安全：** `dio ^5.7.0`｜`flutter_secure_storage ^11.2.0`｜Dart
`HttpClient`｜Bearer Token｜Multipart/FormData｜SSE
字节流｜`SecurityContext`｜自定义 `HttpOverrides`｜TLS 证书信任域控制。\
**文件与富文本：**
`file_picker ^13.1.0`｜`pdfx ^2.11.0`｜`flutter_markdown_plus ^1.0.12`｜Dart
`dart:typed_data`｜`dart:convert`。\
**视频面试：** `livekit_client ^2.13.2`｜LiveKit Room｜WebRTC
媒体轨道｜RoomEvent｜音视频设备控制｜远端轨道订阅｜Room 重连状态监听。\
**测试与工程：**
`flutter_test`｜`integration_test`｜`flutter_lints ^6.0.0`｜`flutter analyze`｜`flutter test`｜`flutter build apk`｜`flutter build appbundle`｜`flutter build ios`。\
**工程实现机制：**
StatefulWidget｜StatelessWidget｜Navigator｜IndexedStack｜ChangeNotifier｜ListenableBuilder｜Future/Future.wait｜Stream｜Timer｜CancelToken｜依赖注入式数据源适配｜请求编号/异步防竞态｜表单校验。

### 4.2 C-App：求职者移动端

**语言 / 框架：** Dart（SDK `^3.12.2`）｜Flutter
SDK｜`cupertino_icons ^1.0.8`。\
**直接依赖：**
`flutter_secure_storage ^11.2.0`｜`image_picker ^1.2.0`｜`file_picker ^13.1.0`｜`flutter_markdown_plus ^1.0.12`｜`pdfx ^2.11.0`。\
**开发依赖：** `flutter_test`｜`flutter_lints ^6.0.0`。\
**注意：** C-App 的这份 `pubspec.yaml` 中**没有**直接声明
`livekit_client`；不能因此断言它与 E-App 使用完全相同的媒体 SDK。

### 4.3 企业 PC 端

**框架：**
`vue 3.4.0`｜`vue-router 4.2.5`｜`pinia 2.1.7`｜`element-plus 2.4.3`｜`@element-plus/icons-vue 2.3.1`｜`vite 5.0.4`。\
**直接运行依赖：**
`axios 0.27.2`｜`livekit-client ^2.22.4`｜`echarts 5.4.3`｜`@vueuse/core 10.6.1`｜`@vueup/vue-quill 1.2.0`｜`clipboard ^2.0.11`｜`file-saver 2.0.5`｜`fuse.js 6.6.2`｜`js-beautify ^1.14.11`｜`js-cookie 3.0.5`｜`jsencrypt 3.3.2`｜`nprogress 0.2.0`｜`pinyin-pro ^3.29.5`｜`vue-cropper 1.1.1`｜`vuedraggable ^4.1.0`。\
**开发/构建依赖：**
`@vitejs/plugin-vue 5.0.1`｜`@vue/compiler-sfc 3.4.0`｜`sass 1.69.5`｜`unplugin-auto-import 0.17.1`｜`unplugin-vue-setup-extend-plus 1.0.0`｜`vite-plugin-compression 0.5.1`｜`vite-plugin-svg-icons 2.0.1`。

### 4.4 管理员 PC 端

**框架：**
`vue 3.5.26`｜`vue-router 4.6.4`｜`pinia 3.0.4`｜`element-plus 2.13.1`｜`vite 6.4.3`。\
**直接运行依赖：**
`@element-plus/icons-vue 2.3.2`｜`@vueup/vue-quill 1.2.0`｜`@vueuse/core 14.1.0`｜`axios 1.20.0`｜`clipboard 2.0.11`｜`echarts ^6.1.0`｜`file-saver 2.0.5`｜`fuse.js 7.1.0`｜`js-beautify 1.15.4`｜`js-cookie 3.0.8`｜`jsencrypt 3.3.2`｜`nprogress 0.2.0`｜`vue-cropper 1.1.1`｜`vuedraggable 4.1.0`。\
**开发/质量依赖：**
`@eslint/js ^10.0.1`｜`@vitejs/plugin-vue 5.2.4`｜`@vue/eslint-config-prettier ^10.2.0`｜`eslint ^10.10.0`｜`eslint-plugin-vue ^10.11.0`｜`prettier ^3.9.6`｜`rollup-plugin-visualizer ^7.1.1`｜`sass-embedded 1.97.2`｜`unplugin-auto-import 0.18.6`｜`unplugin-vue-setup-extend-plus 1.0.1`｜`vite-plugin-compression 0.5.1`｜`vite-plugin-svg-icons 2.0.1`｜`quill 2.0.2`（覆盖约束）。

### 4.5 求职者 Web 端

**框架：**
`vue 3.5.26`｜`vue-router 4.6.4`｜`pinia 3.0.4`｜`element-plus 2.13.1`｜`vite 6.4.1`。\
**直接运行依赖：**
`@element-plus/icons-vue 2.3.2`｜`@vueup/vue-quill 1.2.0`｜`@vueuse/core 14.1.0`｜`axios 1.13.2`｜`clipboard 2.0.11`｜`echarts 5.6.0`｜`file-saver 2.0.5`｜`fuse.js 7.1.0`｜`js-beautify 1.15.4`｜`js-cookie 3.0.5`｜`jsencrypt 3.3.2`｜`livekit-client ^2.22.4`｜`nprogress 0.2.0`｜`qrcode ^1.5.4`｜`vue-cropper 1.1.1`｜`vuedraggable 4.1.0`。\
**开发/构建依赖：**
`@vitejs/plugin-vue 5.2.4`｜`sass-embedded 1.97.2`｜`unplugin-auto-import 0.18.6`｜`unplugin-vue-setup-extend-plus 1.0.1`｜`vite-plugin-compression 0.5.1`｜`vite-plugin-svg-icons 2.0.1`｜`quill 2.0.2`（覆盖约束）。

### 4.6 Java 后端

**语言 / 框架 / 服务：** Java 17｜Maven｜RuoYi `3.9.2`｜Spring Boot
`4.1.0`（POM 声明）｜Spring MVC｜Spring Security｜MyBatis Spring Boot
Starter `4.1.0`｜MySQL｜Redis｜JWT｜Quartz。\
**数据库 / ORM / 缓存：**
`mysql-connector-j`｜`druid-spring-boot-4-starter 1.2.28`｜`mybatis-spring-boot-starter 4.1.0`｜`pagehelper-spring-boot-starter 4.1.1`｜`spring-boot-starter-data-redis`｜`spring-boot-starter-cache`｜`commons-pool2`。\
**Web / 安全 / 数据校验：**
`spring-web`｜`spring-webmvc`｜`spring-boot-starter-websocket`｜`spring-boot-starter-security`｜`spring-boot-starter-validation`｜`jjwt 0.9.1`｜`springdoc-openapi-starter-webmvc-ui 3.1.0`｜`jakarta.servlet-api`｜`kaptcha 2.3.3`。\
**文档 / AI 解析相关工具：**
`poi-ooxml 5.5.1`｜`tess4j 5.19.0`｜`commons-io 2.22.0`｜`fastjson2 2.0.64`｜`jackson-databind`｜`commons-lang3`｜`spring-boot-starter-mail`。\
**其他组件：**
`velocity-engine-core 2.3`｜`oshi-core 7.4.4`｜`yauaa 8.2.0`｜`jaxb-api 2.3.1`｜`spring-boot-devtools`｜`spring-boot-starter-test`｜`h2`（测试）｜`maven-surefire-plugin 3.5.6`｜`maven-compiler-plugin 3.13.0`。

**注意：** 以上列出的后端依赖以根
POM、`ruoyi-admin`、`ruoyi-common`、`ruoyi-system`
核验为主；**没有把未核实的
LangChain4j、LangGraph、Qdrant、Milvus、OpenAI Java SDK
自动算作已采用依赖**。

### 4.7 运维与工程化技术

**确认使用或确认存在文档依据：** Maven 打包｜Flutter 原生构建｜Vite
静态构建｜Nginx 静态网站与 API 反向代理（`user-PC`
部署文档）｜Git｜GitHub。\
**推荐部署方案技术（不代表仓库已部署）：** Docker｜Dockerfile｜Docker
Compose v2｜Docker Context｜Docker Build
Context｜多阶段构建｜Nginx｜持久化
Volume｜容器健康检查｜HTTPS｜反向代理｜镜像仓库｜CI/CD｜LiveKit
专用媒体服务。

------------------------------------------------------------------------

## 五、个人职责与四个技术难点（重点）

### 5.1 我的总体职责

本人主要负责**企业招聘移动端 E-App 的 Flutter
页面、客户端状态管理、招聘业务接口对接和重点智能化交互功能**。在客户端侧完成岗位发布及
JD 文档导入、候选人筛选与推荐结果操作、招聘流程配置、会议场次联动与
LiveKit 视频会议。围绕 Agent 功能，重点理解并参与大模型 API
调用、短期对话上下文管理和工具调用的应用方案；其后端独立 Agent
实现边界需结合本人实际提交记录和服务端代码进一步确认。

**与后端的分工边界：** E-App 不负责在本地运行
OCR/LLM，也不承担模型训练。Flutter
完成文件上传和结果校验展示，后端处理文档识别、智能分析、数据存储和
LiveKit Token 签发。此分工使敏感密钥留在服务器，便于多端复用。

### 5.2 难点一：岗位 JD 文档识别、结构化导入与招聘流程编排

#### 5.2.1 业务背景

HR
发布岗位通常要手动填写名称、部门、薪资、岗位职责、任职要求、技能标签及招聘阶段。原始
JD 往往以 PDF/DOCX
文档保存，复制粘贴费时且结构不统一。因此需要实现**文档导入 → 服务端识别
→ 结构化草稿 → 人工校验 → 岗位保存 → 流程编排**的闭环。

#### 5.2.2 真实技术流程

``` mermaid
flowchart TD
    A[HR 在岗位发布页选择文档] --> B[file_picker 选择 PDF/DOCX]
    B --> C[后缀/大小/完整性校验]
    C --> D[Dio multipart 上传]
    D --> E[POST /enterprise/jd/parse-document]
    E --> F[服务端提取文本/OCR/结构化解析]
    F --> G[JdImportDraft.fromJson 校验]
    G --> H[人工核对: JdImportReviewSheet]
    H --> I[生成差量 Patch + 字段覆盖确认]
    I --> J[岗位表单回填]
    J --> K[保存岗位]
    K --> L[配置招聘阶段及阈值]
    L --> M[保存招聘工作流]
```

**客户端重要文件及作用：**
`lib/features/enterprise/jobs/job_publish_page.dart`（总体表单与导入状态机）｜`jobs/data/jd_document_picker.dart`（文件选择与校验）｜`lib/api/jd_document_api.dart`（文件上传接口）｜`jobs/models/jd_import_draft.dart`（结构化草稿、数据校验、差量
Patch）｜`jobs/widgets/jd_import_review_sheet.dart`（人工确认）｜`jobs/widgets/job_publish_workflow.dart`（阶段编排）。

**已核实的数据安全和可靠性措施：** 只接收 `.pdf/.docx`；文件最大 10
MB；在文件读取过程中再次核验大小；避免读取不完整的文件；`Uint8List`
转只读视图；上传显示已发送字节数；`CancelToken` 允许取消；`_importEpoch`
防止旧请求返回后覆盖新状态；上传和解析超时分别提示；服务端草稿字段严格校验；若草稿与现有表单冲突则明确提示覆盖。

**结构化草稿主要字段：**
`title`｜`dept`｜`city`｜`salaryMin`｜`salaryMax`｜`experience`｜`education`｜`jobType`｜`responsibilities`｜`requirements`｜`skills`｜`summary`｜`softRequirements`｜`warnings`。

**关键设计：识别结果不能直接发布岗位。**
上传接口只返回可审阅草稿，不直接创建正式岗位。`prepareImport()`
仅形成修改集合，缺失/空字段不随意覆盖已有表单；对已有内容的覆盖需确认。这样能减少
OCR 错误、模型幻觉和误识别造成的错误岗位发布。

**招聘流程编排：** 支持在线笔试、AI 技术面试、HR
综合面试、编程实操四类阶段；每一阶段包含类型、时长、通过阈值、考察项、是否必选、是否允许跳过及未通过是否终止。阶段表单可单独编辑，岗位与流程保存分步完成，失败时允许继续补充，而不是误报整体成功。

**难点总结：** 这个功能真正复杂的不是"调用
OCR"，而是**不可信文档输入的安全处理、异步状态管理、结构化结果的强类型验证、冲突合并、人工审核以及跨接口的岗位/流程保存一致性**。

#### 5.2.3 可用于答辩的回答

> 我负责在 Flutter 企业端实现岗位 JD 文档智能导入及招聘流程编排。HR 上传
> PDF 或 DOCX 后，客户端会进行格式、大小与文件完整性校验，再使用 Dio 的
> multipart
> 上传能力调用服务端识别接口。识别结果不是直接发布，而是先转换为强类型
> JD 草稿，校验薪资、学历、技能等字段，并通过审核弹窗让 HR
> 确认，最后通过差量 Patch
> 回填岗位表单。同时支持按阶段设置面试方式、时长、通过阈值和跳过规则。重点解决了异步取消、旧请求覆盖、解析结果不准确及表单冲突问题。

### 5.3 难点二：AI 求职者岗位适配度分析与推荐

#### 5.3.1 业务背景

企业收到大量简历后，HR
需要从学历、工作经历、技术能力及岗位相关性等方面筛选合适人才。不能只靠关键词命中，也不能直接把大模型输出当作绝对客观的录用结论；需要**结构化评分、结果解释、任务进度、人工复核和成本控制**。

#### 5.3.2 已核实的客户端---后端调用链

``` mermaid
flowchart TD
    A[岗位详情加载候选人] --> B[读取已有 AI 评分]
    B --> C{需要重新分析?}
    C -->|否| D[只读展示已有结果]
    C -->|是| E[POST /enterprise/screening/tasks/async]
    E --> F[后端异步分析任务]
    F --> G[每 2 秒轮询 /status]
    G --> H{状态完成?}
    H -->|否| G
    H -->|成功| I[GET /results]
    H -->|失败| J[错误提示/保留已有结果]
    I --> K[候选人评分及推荐展示]
    K --> L[短名单/报告/招呼语/人工复核]
```

**已核实 API：**
`POST /enterprise/screening/tasks/async`（发起分析）｜`GET /enterprise/screening/tasks/{taskId}/status`（读取状态）｜`GET /enterprise/screening/tasks/{taskId}/results`（评分与维度明细）｜`GET /enterprise/screening/tasks/{taskId}/shortlist`（Top
N）｜`GET /enterprise/screening/results/{resultId}/report`（推荐理由）｜`GET /enterprise/screening/results/{resultId}/greeting`（招呼语）｜`PUT /enterprise/screening/results/{resultId}/review`（人工审核）。

**关键实现细节：**
岗位详情进入候选人标签页时惰性加载评分；普通"补充分析"先重新读取候选人与已有评分，避免对已有
LLM
分析结果再次付费；"全量分析"需二次确认，并明确提示可能覆盖历史结果和消耗模型额度；异步任务由后端运行，客户端每
2 秒查询状态；前端设置约 12
分钟的等待边界，超时仅提示后台可能仍在执行，**不会自动重复提交任务**；服务端任务标识与岗位标识不符时进行异常处理。

**评分说明：** API
文档注释称返回"六维真实模型评分"，并对资料缺失维度使用
`null`。具体六维名称、权重和模型提示词必须以服务端评分代码为准，本文不虚构确定的算法公式。可在答辩中说明系统需评估技能匹配、经验匹配、学历/硬性条件、项目相关性等维度，但**这些是业务理解示例，不等于已核实的全部六维字段**。

**为何采用异步任务：** 对一批候选人逐个调用模型可能超过普通 HTTP
请求超时。将"触发任务"和"查询状态"解耦，客户端可以退出页面后再次查看，不必一直持有模型请求；可让后端控制并发、失败处理与成本。**具体后端线程池/队列中间件需以代码核实，不把
Redis 自动称为模型任务队列**。

**为何强调可解释推荐：** 分值可以用于辅助排序，但 HR
更需要知道"符合哪些要求、缺失哪些证据、哪些经历需复核"。对资料缺失应显示"信息不足"，而不是随意给零分；推荐报告供人工决策参考，避免将自动评分作为唯一聘用依据。

#### 5.3.3 可用于答辩的回答

> 我负责 E-App 的 AI
> 筛选任务触发、进度追踪、评分结果与推荐信息展示。岗位详情通过真实后端
> API
> 发起异步分析，并以状态轮询方式等待结果。为节省模型调用成本，普通分析会先检查候选人已有评分，尽量只处理待分析人员；全量重算则要求
> HR
> 二次确认。分析结束后展示匹配度、维度明细及推荐理由，并提供人工复核入口。这个模块的核心难点在于异步任务状态一致性、幂等防重、评分结果解释和模型调用成本控制。

### 5.4 难点三：Agent 实现------模型 API、短期记忆与工具调用

> **实现边界（已修订）：** 企业移动端真实运行截图显示 **AI
> 招聘助手已经可以接收问题、返回招聘文案并供用户复制**，因此客户端聊天功能应按"已可用"介绍。公开
> `dev` 分支里存在的旧 `AssistantPlaceholderPage`、`chatWithAssistant()`
> 占位接口不能代表截图对应的实际运行链路。**截图没有揭示**服务端短期记忆、Function
> Calling、底层模型或持久化方案；以下对这些内部技术的讲解是原理、合理的实现方式和待核对项，不把推测写成源码事实。

#### 5.4.1 已运行的 AI 招聘助手------功能和证据

**截图场景：** HR 在「AI
招聘助手」发送"帮我写一段友好的沟通开场白"，助手给出"通用版（首次联系候选人）"以及"已投递候选人版"的两套话术，内容针对岗位、候选人背景和沟通方式组织。与只能显示静态说明的占位页不同，这证明运行环境已经能够输出与用户提问相关的完整
AI 文本。

**可见客户端能力：** 用户消息与 AI
消息分角色排版；文本输入和发送入口；AI
内容按段落、标题或加粗呈现；单条回答复制按钮；新建对话入口；历史记录入口；生成停止状态和"AI
内容仅供参考"的提示。对话连续性、真实停止网络请求、重新进入历史会话后的恢复，需要通过操作或日志进一步验证。

#### 5.4.1.1 服务器侧已确认的运行组件（尚未确认助手调用关系）

根据 2026-10-29
由用户从服务器执行并提供的只读命令输出，可确认以下容器正在运行：

  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  组件                         现场观察到的信息                                                             对 AI 助手分析的意义              当前结论
  ---------------------------- ---------------------------------------------------------------------------- --------------------------------- ------------------------------------------------------------------
  `hr-backend`                 镜像 `hr-backend:latest`；`127.0.0.1:8080->8080/tcp`；运行约 17 小时         Java 业务后端入口候选             已确认后端容器运行；AI 聊天请求是否经过该容器仍需追踪接口

  Java 进程                    `java ... -jar /app/ruoyi-admin.jar --spring.profiles.active=druid,docker`   后端使用 RuoYi/Spring Boot        已确认进程命令；具体 Agent Service 类与模型客户端未确认
                                                                                                            形式启动，并启用了 `druid,docker` 
                                                                                                            profile                           

  `memory-embedding`           镜像 `python:3.11-slim`；容器运行约 24 小时；`docker ps`                     可能用于文本向量化或记忆处理      仅能确认容器与镜像；入口脚本、API、依赖和调用方未知
                               未显示宿主机端口映射                                                                                           

  `qdrant`                     镜像 `qdrant/qdrant:latest`；状态 `healthy`；宿主机映射                      提供向量存储/检索能力的基础设施   已确认 Qdrant
                               `127.0.0.1:6333-6334`                                                                                          服务健康；尚未确认是否存储聊天记忆、集合名称、向量维度或检索策略

  `livekit-livekit-server-1`   镜像 `livekit/livekit-server:v1.13.9`；运行约 47 小时                        实时音视频会议服务                已确认容器运行；端口暴露与实际 E-App 连接地址待核实

  `livekit-livekit-egress-1`   镜像 `livekit/egress:v1.15.0`；运行约 47 小时                                LiveKit                           已确认容器运行；是否启用录制以及具体用途待核实
                                                                                                            的媒体导出/录制相关服务组件       

  宿主机 Nginx                 进程使用 `/www/server/nginx/sbin/nginx -c /www/server/nginx/conf/nginx.conf` 可能承担公网入口和反向代理        已确认进程；域名、路由和 upstream 配置尚未读取
  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

同一次 `docker ps` 输出还显示 `enterprise-pc`、`admin-pc`、`user-pc`
三个 Web 容器分别将容器 80 端口映射到宿主机回环地址的
8082、8081、8083；这些是 Web 前端服务，不能与 Flutter E-App
混为一谈。后端和 Web 容器的端口均绑定在
`127.0.0.1`，表明它们没有通过这些映射直接监听宿主机所有网卡；外部访问路径需要结合宿主机
Nginx 配置确认。

**重要边界：** Qdrant 健康、`memory-embedding`
容器运行，只能证明相关基础设施存在，不能据此直接宣称 AI
招聘助手已经实现了"长期记忆"或"向量检索"。同样，短期对话记忆通常是按会话维护历史消息，两者概念不同：短期记忆可以存于应用状态、Redis
或数据库；Qdrant
更适合语义向量检索。需要读取应用代码和脱敏日志才能确定本项目的实际设计。

**适合在项目介绍中使用的描述：**"企业移动端已接入可实际使用的 AI
招聘助手，可响应 HR
的自然语言需求，生成候选人沟通开场白等招聘辅助内容；客户端提供会话界面、历史入口、生成状态展示和内容复制等交互。"

**客户端与服务端的职责划分：** Flutter
负责用户输入、消息展示及复制等交互；实际部署的 Java 后端已确认存在企业助手 Controller、`EnterpriseAssistantService`、`AgentModelClient` 与 `EnterpriseAssistantMapper`。服务层包含会话/运行管理、历史上下文构建线索、工具调用编排及 SSE 事件处理；模型 API Key 位于后端模型供应商配置模型中（字段名可见 `mppApiKey`），不应放入 Flutter 客户端。由于尚未取得与当前安装包完全对应的 Dart 请求源码，前端具体 API 文件和请求路径仍不在本轮证据范围内。

**若要确认是否是真正具备工具调用的 Agent，可使用以下三项验证：**

1.  **多轮记忆测试：**
    先指定岗位名，再提问"这个岗位的招呼语还能更正式一点吗"；观察是否记住指代，并通过请求或服务端日志核对
    `sessionId` 和历史 `messages`。
2.  **工具调用测试：**
    询问"查询我负责的岗位及候选人名单"，查看服务端是否产生真实的工具调用记录和授权的业务
    API/Service 查询，而不仅是模型生成的泛化回答。
3.  **调用链验证：** 对照实际运行构建版本定位 Flutter 页面 → 网络请求 →
    后端 Controller → Agent Service → 模型适配器/工具注册 → 数据库或
    Redis。核对真实协议和实际类名后才能宣称已完成"短期记忆 + Function
    Calling"。

#### 5.4.2 Agent 与普通大模型 API 调用的区别

普通模型调用可以是一次固定请求：输入 Prompt → 模型输出文本。**Agent
在此基础上增加状态、上下文、可选工具、执行控制与任务完成条件**。模型负责决定是否需要工具以及生成调用参数，后端负责合法性校验、真正执行工具并把执行结果返回模型，最后由模型生成回复。

``` mermaid
sequenceDiagram
    participant HR as E-App/HR
    participant S as Java 后端 Agent 服务
    participant M as 大模型 API
    participant T as 业务工具
    participant DB as 业务数据源
    HR->>S: 发送提问 + sessionId
    S->>S: 加载短期会话上下文
    S->>M: system + history + user + tools
    M-->>S: 返回文本或 tool_call(name,args)
    alt 需要业务查询
        S->>S: 工具白名单与权限/参数校验
        S->>T: 调用真实后端方法
        T->>DB: 查询授权范围的数据
        DB-->>T: 查询结果
        T-->>S: 工具结果（受控结构）
        S->>M: 追加 tool_result，继续模型推理
        M-->>S: 最终自然语言结果
    end
    S->>S: 更新短期记忆（截断/摘要）
    S-->>HR: 返回最终消息/事件流
```

#### 5.4.3 大模型 API 调用（参考实现思想）

典型服务端模型调用请求包含 `model`、`messages`、`tools`
以及可选的流式输出开关。`messages` 通常包含
`system`、`user`、`assistant`、`tool` 四类消息；后端应集中管理服务端 API
Key、重试、超时、日志脱敏和模型返回格式校验。客户端只调用业务后端，**不在
Flutter 中放置大模型 API Key**。

参考伪代码（非仓库实际 Java 类名）：

``` text
handleChat(userId, sessionId, userMessage):
    assertAuthenticated(userId)
    history = shortTermMemory.load(userId, sessionId)
    messages = [systemPrompt] + history + [userMessage]
    for step in 1..MAX_TOOL_STEPS:
        response = modelApi.chat(messages, allowedTools)
        if response.hasNoToolCalls():
            shortTermMemory.saveBounded(userId, sessionId, messages, response)
            return response.text
        for call in response.toolCalls:
            tool = registry.requireAllowed(call.name, userId)
            args = validateAgainstSchema(call.arguments)
            result = tool.execute(args, userContext=userId)
            messages += [call, boundedToolResult(result)]
    return safeFallback("需要进一步确认相关业务信息")
```

#### 5.4.4 短期记忆原理与设计

**短期记忆不是模型参数记住用户，而是服务端在下一轮请求时把历史上下文重新交给模型。**
例如 HR
第一轮问"某岗位有多少求职者"，第二轮问"其中匹配度最高的三位是谁"；系统需保留"某岗位"的上下文，正确解析指代。

**参考存储结构：**
`sessionId`｜`userId`｜`role`｜`content`｜`toolCallId`｜`createdAt`｜`expiresAt`。\
**参考存储选型：** 进程内缓存（单机原型）｜Redis（跨实例共享、设置
TTL）｜MySQL（需要审计或持久记录时）；是否采用某一种应以实际项目后端为准。\
**重要策略：** 绑定登录用户与会话权限；限制窗口条数与 Token 消耗；保留
system
指令和必要的工具结果；过长历史可做摘要；脱敏候选人个人数据；会话失效清理；避免未经授权把一个企业的候选人数据带入另一企业上下文。

#### 5.4.5 工具调用 Function Calling 原理

以"查询岗位候选人"为例，模型可能返回结构化工具请求：

``` json
{
  "name": "list_job_candidates",
  "arguments": {"positionId": 123, "topN": 5}
}
```

**这只是模型要求执行工具，并非模型自己访问数据库。** Agent
后端应按工具名在白名单中找到处理器，校验 `positionId` 和
`topN`，检查当前 HR 是否有权查看该岗位，再调用业务
Service/Mapper，返回经过字段过滤的业务结果，最后由模型综合回答。对发布岗位、发送面试邀请、修改评分等**有副作用的工具**增加用户确认、权限校验和幂等防重；只读查询与写入操作分级授权。

**可结合本项目设计的工具（示例，不等于已注册）：**
`get_job_detail`（查看岗位）｜`list_job_candidates`（查看候选人）｜`get_screening_results`（读取匹配度）｜`get_interview_schedule`（查询日程）｜`get_candidate_resume_summary`（查看授权简历摘要）｜`create_interview_invitation`（需确认，发起邀请）。

#### 5.4.6 如何说明与 E-App 的关系

E-App 企业 AI
招聘助手**在运行版本中已具备实际聊天与招聘文案生成能力**。客户端需要承担消息输入与展示、Markdown
展示、复制、会话入口、发送/停止状态、失败提示等交互。真实请求是流式还是非流式、取消是否中止服务端生成、工具是否执行均需要检查运行版本。公开仓库
E-App 有 `EnterpriseApiClient.eventBytes()` 的鉴权 SSE
字节流基础，**但不能据此认定截图对应助手一定使用了 SSE**；公开
`chatWithAssistant()` 仍为旧占位实现，也不能据此反证运行截图。真正的 API
Key、会话权限、模型调用、短期记忆与工具执行应落在可信服务端，不应放进
Flutter 安装包。

#### 5.4.7 可用于答辩的回答

> 企业侧 AI 招聘助手在实际运行的 E-App 中已经可以使用。HR
> 输入自然语言后，系统能够生成分场景招聘沟通话术，界面支持展示结果、复制、新建对话及历史入口。我重点关注了聊天交互、请求状态管理以及模型能力在招聘业务中的落地。Agent
> 的进一步难点是多轮短期记忆与工具调用：短期记忆需要按会话组织历史上下文，工具调用则由大模型返回工具名和参数，再由后端校验身份、执行业务
> Service
> 并反馈结果。具体项目是否采用了这些机制及其代码实现，需要对应运行版本源码核实，不能仅凭聊天界面认定。

### 5.5 难点四：LiveKit 实时视频面试接入

#### 5.5.1 业务背景

面试需要多人实时沟通，除了"显示视频"，还涉及业务会话鉴权、音视频设备采集、角色权限、网络断线、媒体轨道订阅和会议退出。采用
LiveKit 可以将 WebRTC 传输能力交给媒体 SDK，Flutter
重点处理**业务会议与实时媒体之间的衔接**。

#### 5.5.2 真实接入链路

``` mermaid
sequenceDiagram
    participant E as E-App
    participant B as Spring Boot
    participant L as LiveKit
    E->>B: 获取预约/场次详情
    B-->>E: sessionId + appointmentId + 角色信息
    E->>E: 验证预约与场次匹配
    E->>B: POST /session/{id}/interviewer/join
    E->>B: GET /livekit-token/{id}
    B-->>E: url + token + room + identity
    E->>L: Room.connect(url, token)
    L-->>E: RoomConnected + 远端媒体事件
    E->>L: 发布麦克风/摄像头轨道（可发布角色）
    loop 每15秒
        E->>B: /session/{id}/heartbeat
    end
    E->>L: disconnect + dispose
    opt 结束面试
        E->>B: POST /session/{id}/finish
    end
```

**对应真实文件：**
`lib/features/enterprise/schedule/interview_appointment_detail_page.dart`（预约身份校验）｜`lib/api/interview_room_api.dart`（场次
API
和令牌）｜`lib/features/enterprise/conference/conference_room_page.dart`（会议
UI、入场、心跳、退出）｜`lib/features/enterprise/conference/conference_room_engine.dart`（LiveKit
媒体引擎）｜`lib/features/enterprise/conference/interview_modes.dart`（面试模式映射）。

#### 5.5.3 已核实功能要点

**连接与鉴权：** 先取得业务 `sessionId`，由后端签发 LiveKit
Token；客户端调用 `Room.connect(url, token)`，不自行生成签名；预约 ID
与真实会话 ID 核验通过后才出现入会按钮。\
**角色权限：** 企业面试官在入会前登记；`OBSERVER`
观察者禁止发布媒体，只订阅；支持纯 AI、AI+单面试官、AI+多面试官、无 AI
纯人工四种模式定义。\
**媒体轨道：** SDK 监听
`TrackSubscribedEvent`、`TrackUnsubscribedEvent`、`TrackMutedEvent`、`TrackUnmutedEvent`、`ParticipantConnectedEvent`
等，按事件重建不可变 UI
状态；可渲染远端摄像头轨道、麦克风状态和活跃发言者。\
**设备控制：**
入会后分别开启麦克风和摄像头；任一设备失败不影响另一个；提供关闭/开启麦克风、摄像头和切换前后置摄像头；Android
尝试优先扬声器输出。\
**稳定性：** 处理
connecting、connected、reconnecting、failed、closed；支持失败重试；每 15
秒业务心跳；定时器与 LiveKit Listener
在页面销毁时取消；离开房间与结束整个面试是不同操作。\
**会议 UI：**
远端参会者宫格、本人视频浮窗、等待人员加入的空态、当前岗位与候选人、面试计时、成员面板、旁听状态、结束面试二次确认。

**Android 已声明权限：**
`INTERNET`｜`CAMERA`｜`RECORD_AUDIO`｜`MODIFY_AUDIO_SETTINGS`｜`BLUETOOTH`（旧系统）｜`BLUETOOTH_CONNECT`。**上线还要在运行时申请权限**；Android
Manifest 中 `usesCleartextTraffic=true` 适合当前联调，但生产环境应优先
HTTPS/WSS 并视需要收紧配置。iOS
的摄像头/麦克风隐私说明也应在正式打包前核实。

#### 5.5.4 会议网络机制（原理）

LiveKit 建立连接时使用 WebSocket/WSS
信令交换入会状态、参与者与媒体元信息；音视频主要通过 WebRTC 传输，涉及
ICE、STUN/TURN、DTLS/SRTP 等技术。**WebSocket 不等于音视频直接通过
WebSocket 传输**，媒体通常走 UDP
或在网络受限时通过合适的回退通道。用户点击静音，本质是操作本地发布轨道状态，并由
SDK 传播相关事件。

LiveKit 服务器负责提供媒体会话，Java
后端负责**会议业务状态和身份授权**。这两个系统职责不同：即便媒体连接正常，业务会话仍需心跳、状态和结束接口。LiveKit
Cloud 与自建 LiveKit
的服务端参数、开放端口及部署方法不同，不能把某个端口视为所有环境通用。

#### 5.5.5 可用于答辩的回答

> 我负责 Flutter 企业端接入 LiveKit
> 实时视频面试。用户从真实面试日程进入会议前，会先校验预约与会话身份，再请求
> Java 后端签发 LiveKit 入会 Token，客户端用 `livekit_client` 创建 Room
> 并连接媒体服务器。会议引擎监听成员加入、远端媒体轨道、静音、活跃发言者和断线重连等事件，通过
> ChangeNotifier
> 更新界面。同时实现麦克风与摄像头控制、多成员宫格展示、15
> 秒业务心跳，以及离开会议和结束面试的差异化处理。难点主要是业务鉴权和
> WebRTC 会话生命周期的协调，而不是单纯调用连接方法。

------------------------------------------------------------------------

## 六、运维部署与环境配置

### 6.1 先解释三种容易混淆的技术

**Dockerfile：** 定义"一个镜像怎么构建"，例如安装 JDK/Node
运行环境、复制 JAR 或前端静态资源、指定启动命令。\
**Docker Compose：** 在一个 YAML
文件中定义多个容器服务、网络、数据卷、环境变量、健康检查及依赖关系，可一次启动后端、数据库、Redis、多个
Web 站点等。\
**Docker Context：** Docker CLI 的**目标 Docker Engine 配置**；例如本机
Docker Desktop 和通过 SSH 连接的远程 Linux Docker 主机可用不同 Context
切换。另一个名称相近但不同的概念是 **Docker build
context（构建上下文）**，即 `docker build`
最后一个参数指定的文件目录，构建阶段的 `COPY`
只能读取构建上下文内未被忽略的文件。两者不要混为一谈。

### 6.1.1 当前服务器运行快照（2026-10-29）

以下数据来自用户在服务器上执行的
`docker ps --format ...`、`ps -ef | grep -E '[j]ava|[n]ginx'`、`pwd` 和
`ls -lah` 命令输出。它们是**运行状态证据**，不是对 Compose
文件、镜像构建过程或 Nginx 路由的直接审计。

  ------------------------------------------------------------------------------------------------------------------------
  容器名                       镜像                               端口信息（按 `docker ps` 输出）        状态
  ---------------------------- ---------------------------------- -------------------------------------- -----------------
  `admin-pc`                   `admin-pc:latest`                  `127.0.0.1:8081->80/tcp`               Up 17 hours

  `hr-backend`                 `hr-backend:latest`                `127.0.0.1:8080->8080/tcp`             Up 17 hours

  `user-pc`                    `user-pc:latest`                   `127.0.0.1:8083->80/tcp`               Up 24 hours

  `enterprise-pc`              `enterprise-pc:latest`             `127.0.0.1:8082->80/tcp`               Up 24 hours

  `memory-embedding`           `python:3.11-slim`                 输出未显示宿主机端口映射               Up 24 hours

  `qdrant`                     `qdrant/qdrant:latest`             `127.0.0.1:6333-6334->6333-6334/tcp`   Up 47 hours
                                                                                                         (healthy)

  `livekit-livekit-egress-1`   `livekit/egress:v1.15.0`           输出未显示端口映射                     Up 47 hours

  `livekit-livekit-server-1`   `livekit/livekit-server:v1.13.9`   输出未显示端口映射                     Up 47 hours
  ------------------------------------------------------------------------------------------------------------------------

另观察到宿主机 Nginx 进程
`/www/server/nginx/sbin/nginx -c /www/server/nginx/conf/nginx.conf`，以及
Java 命令
`java -Xmx512m -Xms256m ... -jar /app/ruoyi-admin.jar --spring.profiles.active=druid,docker`。宿主机
Nginx 很可能承担统一入口，但没有读取 Nginx
配置前，不应把具体域名路由、HTTPS 终止或 SSE/WebSocket
代理行为写成已确认事实。

#### 6.1.1.1 服务器部署拓扑（实线为已确认存在，虚线为待核验关系）

``` mermaid
flowchart TD
    U[企业 E-App / Web 客户端]
    N[宿主机 Nginx 进程：已确认运行]
    B[hr-backend：Spring Boot / RuoYi]
    P[memory-embedding：Python 3.11 镜像]
    Q[Qdrant：healthy]
    L[LiveKit Server]
    E[LiveKit Egress]
    W[enterprise-pc / admin-pc / user-pc]
    U -. "公网域名与路由待核验" .-> N
    N -. "upstream 配置待核验" .-> B
    N -. "静态站点路由待核验" .-> W
    B -. "是否调用该服务待核验" .-> P
    P -. "是否连接及集合配置待核验" .-> Q
    U -. "LiveKit URL/端口待核验" .-> L
    L -. "Egress 配置待核验" .-> E
```

#### 6.1.1.2 端口暴露的安全含义

`hr-backend` 的 8080、三个 PC 前端的 8081/8082/8083，以及 Qdrant 的
6333/6334，均显示绑定到
`127.0.0.1`。按这些端口映射本身来看，外部机器不能直接通过宿主机公网 IP
访问这些映射端口，通常需要由宿主机 Nginx
或其他受控入口转发。**不要为了排查而将后端或 Qdrant 改为 `0.0.0.0`
暴露，也不要直接向公网开放 Qdrant 管理端口。** LiveKit 的 `PORTS`
列没有显示映射，可能与网络模式或配置方式有关，需检查 Compose
文件和监听端口后再判断，不能仅据此认定 LiveKit 无法从外部访问。

#### 6.1.1.3 尚待补齐的运维证据

目前尚未直接读取 Compose
文件、容器挂载、容器网络、镜像构建上下文、宿主机 Nginx 配置和 AI
服务日志。因此，以下信息仍未确认：部署文件的准确路径、`memory-embedding`
的启动入口及依赖、Qdrant collection/向量维度、后端到记忆服务的
URL、模型供应商与模型名称、助手的真实
Controller/Service、对话历史的存储位置、是否使用 SSE、LiveKit 的公网 URL
与媒体端口。只有检查这些配置和对应源码，才能把"可能的架构"升级为"已确认的真实调用链"。

**后续只读核验命令（需在已登录的服务器 SSH
终端执行；不要把密钥、环境变量或 `.env` 内容贴出）：**

``` bash
# 1. 查看 Compose 项目
 docker compose ls

# 2. 只打印 Compose 标签，不读取环境变量
 docker inspect -f 'name={{.Name}} image={{.Config.Image}} project={{index .Config.Labels "com.docker.compose.project"}} workdir={{index .Config.Labels "com.docker.compose.project.working_dir"}} files={{index .Config.Labels "com.docker.compose.project.config_files"}}' hr-backend memory-embedding qdrant livekit-livekit-server-1

# 3. 查看常见部署目录中的配置文件名（不打印文件内容）
 find /root/workspace /opt /data /www/wwwroot -maxdepth 4 -type f \
   \( -iname '*compose*.yml' -o -name 'compose.yaml' -o -name 'application*.yml' -o -name '*.py' \) \
   2>/dev/null | head -100

# 4. 查看 Python 容器入口进程和目录，不输出环境变量
 docker exec memory-embedding sh -lc 'pwd; ps -ef; ls -lah /'
 docker exec memory-embedding sh -lc 'find /app /workspace /srv -maxdepth 3 -type f 2>/dev/null | head -80'
```

以上命令仅用于读取运行状态和定位文件；不要执行 `docker inspect` 的完整
JSON 输出，不要运行 `env`、`printenv`，也不要直接
`cat .env`，以免泄露模型 API Key、数据库密码或 LiveKit Secret。

#### 6.1.1.4 生产凭据安全提醒

服务器登录密码曾在聊天消息中以明文形式提供。建议在完成当前排查后立即更换该密码，并优先改用
SSH 公钥认证；不要把 SSH 密码、数据库密码、模型 API Key、LiveKit API
Secret 或完整 `.env` 文件写入项目文档、Git
仓库、命令输出截图或公开工单。排障时只分享脱敏后的容器名称、镜像、端口和错误信息。

### 6.2 仓库已经确认的启动/发布方式

#### 6.2.1 Java 后端

**开发环境：** JDK 17、Maven、MySQL、Redis。根 README 给出了数据库名
`recruit_agent`、默认后端端口 8080、Spring Boot 启动类及
`application.yml` / `application-druid.yml`
本地配置方式。生产环境密钥和数据库账号不应写入 Git。

``` bash
cd backend
mvn clean package -Dmaven.test.skip=true
java -jar ruoyi-admin/target/ruoyi-admin.jar
```

> 上述命令为仓库 README
> 所述本地运行方式。实际打包产物位置与测试要求可通过 Maven
> 构建确认；生产建议启用正常测试，并显式加载生产配置。

#### 6.2.2 E-App 企业移动端

``` bash
cd e-app
flutter pub get
flutter analyze
flutter test
flutter run
```

Android 模拟器访问宿主机后端默认
`http://10.0.2.2:8080`；真机可改为同局域网电脑的服务地址。针对不同部署环境，使用编译期配置：

``` bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/prod-api

flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com/prod-api \
  --dart-define=CANDIDATE_APP_URL=https://candidate.example.com

flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.example.com/prod-api \
  --dart-define=CANDIDATE_APP_URL=https://candidate.example.com
```

**平台区别：** Flutter APK/AAB 安装在用户手机上，**不能把 Android App
当成长期运行的 Docker Web 服务**。Docker 可选用于 CI 统一构建环境、生成
APK/AAB；终端用户安装的是打包产物，不是容器。iOS 生产打包必须有适当的
macOS/Xcode 环境、签名和配置：

``` bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.example.com/prod-api
```

**配置项（源码已核实）：**
`API_BASE_URL`（后端地址）｜`CANDIDATE_APP_URL`（候选人端会议邀请
URL）｜`TRUST_BAOTA_CERTIFICATE`（仅显式用于信任指定后端主机私有 CA
的包；不是禁用 TLS 验证）。`DEV_TOKEN`
仅为联调兜底，不要带入正式发布包。

#### 6.2.3 C-App 求职者移动端

``` bash
cd c-app
flutter pub get
flutter run
flutter build apk --release
```

同样使用 Flutter 的原生 Android/iOS
构建与分发流程；具体后端地址及构建定义要以 C-App 配置文件为准，不照搬
E-App 的 `dart-define` 变量。

#### 6.2.4 企业 PC 端

``` bash
cd enterprise_pc/RuoYi-Vue3
npm install
npm run dev
npm run build:prod
```

生产构建生成 `dist/`，由 Nginx 或其他静态资源服务器部署；将 `/prod-api`
等接口前缀反向代理到 Java 后端。根 README 记录了本地 Vite `/dev-api` 到
`localhost:8080` 的代理关系。

#### 6.2.5 管理员 PC 端

``` bash
cd admin_pc/RuoYi-Vue3
npm install
npm run lint
npm run build:prod
```

生产产物为静态页面，建议与企业 PC
端分域名或独立路径部署，并在后端通过角色权限保护管理员操作。

#### 6.2.6 求职者 Web 端

仓库 `user-PC/docs/deployment.md` 的要求为 **Node.js
24、npm、`npm ci`、`npm run check`**。`check` 包含单测与构建；部署
`dist/` 时要保证 SPA history fallback，并将 `/prod-api/` 代理到 Java
后端。生产环境 `VITE_FRONTEND_ONLY='false'`，不要保留纯前端演示模式。

``` bash
cd user-PC
npm ci
npm run check
```

### 6.3 Dockerfile 原理及参考实现【参考设计，并非仓库现有文件】

#### 6.3.1 后端多阶段 Dockerfile

建议存放路径：`deploy/docker/Dockerfile.backend`。以下示例以根目录为构建上下文，Maven
阶段编译，JRE 阶段运行；镜像版本应与你们的实际可用构建平台确认。

``` dockerfile
# 示例：deploy/docker/Dockerfile.backend
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /workspace
COPY backend/ ./
RUN mvn -B -pl ruoyi-admin -am clean package -Dmaven.test.skip=true

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /workspace/ruoyi-admin/target/ruoyi-admin.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

> 注意：后端当前 POM 声明 Spring Boot 4.1.0 但 Java 17
> 也是项目声明值；构建前应以真实 Maven
> 编译结果核验组合兼容性。`application.yml`、数据库密码、JWT Secret
> 不要在镜像中硬编码；可以通过只读配置挂载或环境注入，具体要匹配 RuoYi
> 配置绑定方式。

#### 6.3.2 Vue Web 端多阶段 Dockerfile（企业、管理员、求职者 Web 可复用思路）

将下面文件作为模板，按目录分别复制为
`Dockerfile.enterprise`、`Dockerfile.admin`、`Dockerfile.candidate`；示例使用可配置的源码目录。

``` dockerfile
# 示例：deploy/docker/Dockerfile.web
FROM node:24-alpine AS build
ARG APP_DIR
WORKDIR /src
COPY ${APP_DIR}/package*.json ./
RUN npm ci
COPY ${APP_DIR}/ ./
RUN npm run build:prod

FROM nginx:stable-alpine
COPY deploy/nginx/spa.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist/ /usr/share/nginx/html/
EXPOSE 80
```

**注意：** `npm ci` 要求对应端存在可用的
`package-lock.json`；如果团队使用 pnpm 锁文件，应将 Dockerfile
中的安装方式切换成与锁文件相匹配的包管理器。这里的 `COPY ${APP_DIR}/`
依赖根目录作为 Build Context。

#### 6.3.3 Nginx SPA 及后端代理示例

``` nginx
# 示例：deploy/nginx/spa.conf
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /prod-api/ {
        proxy_pass http://backend:8080/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**关键路径规则：** 当 `location /prod-api/` 使用
`proxy_pass http://backend:8080/;` 时会去掉 `/prod-api/`
前缀；假如后端本身要求保留该路径，必须调整
`proxy_pass`，不可机械照抄。WebSocket、SSE、LiveKit
的反向代理需要额外考虑升级头、连接超时、流式缓冲与媒体端口；上面的示例仅覆盖普通
API。

### 6.4 Docker Compose 多服务示例【参考设计】

以下示例放在**仓库根目录 `compose.reference.yml`**，展示
MySQL、Redis、Java 后端和三个 Vue Web
服务如何编排。它不是已经验证可一键运行的仓库部署文件，必须准备生产配置、数据库初始化文件、对应锁文件以及匹配的构建命令后再使用。

``` yaml
name: intelligent-interviewer
services:
  mysql:
    image: mysql:8.0
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: recruit_agent
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:?set MYSQL_ROOT_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -uroot -p$$MYSQL_ROOT_PASSWORD --silent"]
      interval: 10s
      timeout: 5s
      retries: 12
    networks: [internal]

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks: [internal]

  backend:
    build:
      context: .
      dockerfile: deploy/docker/Dockerfile.backend
    restart: unless-stopped
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_started
    ports:
      - "127.0.0.1:8080:8080"
    # 实际使用时挂载与 RuoYi 项目一致的生产配置
    volumes:
      - ./secrets/application.yml:/app/config/application.yml:ro
      - ./secrets/application-druid.yml:/app/config/application-druid.yml:ro
    networks: [internal]

  enterprise-web:
    build:
      context: .
      dockerfile: deploy/docker/Dockerfile.web
      args:
        APP_DIR: enterprise_pc/RuoYi-Vue3
    ports: ["8081:80"]
    depends_on: [backend]
    networks: [internal]

  admin-web:
    build:
      context: .
      dockerfile: deploy/docker/Dockerfile.web
      args:
        APP_DIR: admin_pc/RuoYi-Vue3
    ports: ["8082:80"]
    depends_on: [backend]
    networks: [internal]

  candidate-web:
    build:
      context: .
      dockerfile: deploy/docker/Dockerfile.web
      args:
        APP_DIR: user-PC
    ports: ["8083:80"]
    depends_on: [backend]
    networks: [internal]

networks:
  internal:

volumes:
  mysql_data:
  redis_data:
```

**该示例必须注意的前提：** 生产配置文件需要真实存在且不纳入 Git；Java
端读取外部配置路径的方式需验证；各 Web 端需按对应的 Node/Vite 版本和
lockfile 调整；`compose.reference.yml` 不会自动部署 LiveKit；不要把
MySQL、Redis 对公网开放；需要额外配置统一公网 HTTPS
入口、域名、备份、日志和安全组。

**启动与检查：**

``` bash
# 在根目录放好示例 Dockerfile、Nginx 配置与 secrets 后执行
docker compose -f compose.reference.yml config
docker compose -f compose.reference.yml build
docker compose -f compose.reference.yml up -d
docker compose -f compose.reference.yml ps
docker compose -f compose.reference.yml logs -f backend
```

**常见维护命令：**
`docker ps`（运行中的容器）｜`docker images`（镜像）｜`docker logs -f <container>`（日志）｜`docker exec -it <container> sh`（进入容器）｜`docker compose up -d --build`（重建并启动）｜`docker compose down`（停止并删除容器网络）｜`docker volume ls`（查看数据卷）｜`docker inspect <container>`（检查网络和挂载）。**不要随意使用
`docker compose down -v`**，否则会同时删除 Compose
声明的数据卷并造成数据库数据丢失。

### 6.5 Docker Context 远程服务器部署

**Docker Context 是 Docker 客户端选择远程 Engine 的方式**；适合本地
Windows/WSL 管理远程 Linux Docker。示例地址是占位符，不对应真实服务器。

``` bash
# 查看当前 Docker 上下文
docker context ls

# 假设服务器已经安装 Docker、SSH 可访问且该 Linux 用户有 Docker 权限
docker context create recruiter-prod \
  --docker "host=ssh://deploy@example.com"

# 切换到服务器 Docker Engine
docker context use recruiter-prod

docker info

# 在指定 Context 上操作（下列相对路径依赖本地构建文件）
docker --context recruiter-prod ps

# 回到本机
docker context use default
```

**与 Docker build context 的区别：**

``` bash
# 这里最后的 . 是构建上下文（仓库根目录）
docker build -f deploy/docker/Dockerfile.backend -t recruiter/backend:latest .

# 这里 recruiter-prod 是 Docker Engine Context
# 注意：远程 Compose 中的宿主机 bind mount 路径需在远程主机存在。
docker --context recruiter-prod compose -f compose.reference.yml up -d
```

**远程部署最重要的坑：** 构建上下文文件来自本地，容器 bind mount
对应的是**远程 Docker 宿主机**的文件系统。上面 Compose 使用
`./secrets/...`
的主机文件挂载，不能默认认为在本地存在就能在远程挂载。建议生产环境先通过
CI
将镜像推送镜像仓库，在服务器上以镜像部署，并用服务器本地的绝对路径或外部
Secret 管理配置。

### 6.6 LiveKit 部署与网络说明

**E-App 本身不部署 LiveKit Server；它是 LiveKit 客户端。** 如果采用
LiveKit Cloud，主要完成项目凭据、服务端 Token
签发、房间连接和域名配置；如果自建
LiveKit，除部署服务器镜像外，还需配置公开可达的 WSS 信令入口、UDP
媒体端口、NAT/ICE 和必要的 TURN
服务。浏览器与移动端的网络环境不同，应在蜂窝网络、企业 Wi-Fi
和受限网络下实际测试。

**推荐的生产链路：** 用户手机 E-App → HTTPS 访问业务后端签发 Token → WSS
连接 LiveKit 信令 → WebRTC 音视频媒体网络 → Java
后端维持业务会话与心跳。LiveKit API Key/Secret
只放服务器，客户端仅获得有时效、限制房间和身份权限的 Token。

**不能仅配置一个 Nginx HTTP 反向代理就断言视频全部可用。** 尤其要核实
UDP/ICE/TURN、TLS、证书、媒体带宽、防火墙以及容器网络模式。具体
`docker-compose` 与 `livekit.yaml`
应从你们实际服务器配置导出核对，不能凭文档虚构。

### 6.7 发布前检查表

  ---------------------------------------------------------------------------------------------------
  检查项                  E-App / Android / iOS                  Web / 后端 / LiveKit
  ----------------------- -------------------------------------- ------------------------------------
  构建                    Flutter 依赖、测试、签名、APK/AAB      npm 锁文件、Maven 构建、镜像构建

  配置                    正式 API 域名、候选人链接、证书        数据库、Redis、JWT、模型
                                                                 Key、LiveKit Secret

  安全                    Token 安全存储、运行时媒体权限、禁用   HTTPS、角色/企业隔离、Secret 不入库
                          DEV_TOKEN                              

  功能                    JD                                     API 鉴权、异步任务、媒体网络、心跳
                          上传、草稿审核、筛选进度、音视频入会   

  可靠性                  重试、断网、取消、前后台切换           日志、监控、数据备份、健康检查

  合规                    文件/简历个人信息展示权限              简历处理、面试音视频告知及保留策略
  ---------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

## 七、典型业务流程总结

### 7.1 企业发布岗位

`企业登录 → 岗位管理 → 新增岗位 → 手动填写或导入 JD → 文档解析 → 人工校验与回填 → 发布/保存岗位 → 配置招聘阶段 → 保存流程 → 候选人投递`。

### 7.2 企业智能筛选人才

`HR 进入岗位详情 → 查看当前候选人与已有评分 → 发起增量/全量 AI 筛选 → 后端异步任务 → E-App 轮询状态 → 展示评分和推荐报告 → HR 复核 → 邀请面试`。

### 7.3 在线视频面试

`HR 选择场次 → 后端核对真实预约/场次 → 获取 LiveKit Token → 连接音视频服务器 → 成员入会及轨道订阅 → 会话心跳 → 离开/结束面试 → 后端记录结束与评估流程`。

### 7.4 AI 招聘助手（已运行）与 Agent 扩展流程（参考设计）

**运行截图已证实的用户流程：**
`HR 打开 AI 招聘助手 → 输入自然语言要求 → 获得招聘沟通文案（多场景版本）→ 查看 Markdown 风格回复 → 一键复制使用`。顶部另有新对话与历史记录入口。

**服务器侧已确认的基础设施：** `hr-backend` Java
后端容器正在运行；`memory-embedding` Python 容器正在运行；Qdrant 状态为
`healthy`；LiveKit Server 与 Egress 容器正在运行。它们为进一步核验 Agent
和视频面试链路提供了明确的排查入口。

**待以源码/配置核验的 Agent 内部流程：**
`HR 提问 → 后端按会话读取短期历史 → 调用模型 API → 可选触发 Function Calling → 后端验证权限并执行工具 → 模型归纳结果 → 保存会话上下文 → Flutter 展示`。虽然服务器有
Qdrant 和 Python embedding 容器，但尚未确认企业 AI
助手与它们之间的连接关系。**不要将这个参考内部链路误写成截图已经证实的实现。**

------------------------------------------------------------------------

## 八、项目优势、难点与优化空间

### 8.1 已实现架构中值得强调的点

**多端复用：** Flutter 两端和 Vue Web 端共同使用 Java 后端业务能力。\
**智能业务与人工复核结合：** JD 识别生成草稿但不自动发布，候选人 AI
匹配辅助 HR 判断。\
**异步与成本控制：** AI 分析通过触发任务 +
状态轮询解耦，存在已分析结果时尽量避免重复调用。\
**音视频能力复用：** Flutter 接入 LiveKit，与企业 Web
端使用一致的会议业务接口。\
**工程可靠性：** Token
安全存储、取消令牌、异步竞态防护、请求超时、登录恢复、状态和错误提示、资源释放。

### 8.2 后续可优化方向（不是已实现功能）

**AI 模型：** 深化 JD
抽取准确率评估、结构化结果校验、评分可解释性、评估公平性和人工反馈闭环。\
**Agent：**
对已经可用的助手补充运行版本源码核验及自动化测试；如尚未实现，再完善后端工具注册与权限模型、短期上下文存储、Token
预算、工具调用链审计、跨租户隔离和会话评测。\
**实时通信：** 完善断线重连后的会话恢复、背景切换、iOS
原生权限说明、网络质量监控和弱网测试。\
**部署：** 将 Dockerfile、Compose、测试、镜像发布、备份、Secret
管理形成标准化部署流水线。

------------------------------------------------------------------------

## 九、面试/答辩介绍版本

### 9.1 30 秒项目介绍

> 我参与开发的是一套企业级智能招聘面试官 Agent 系统，系统包括 Flutter
> 求职者与企业移动端、Vue 企业与管理后台、求职者 Web 端以及 Spring Boot
> 后端。我主要负责 Flutter 企业移动端开发，覆盖岗位管理、JD
> 文档解析导入、AI 候选人筛选和面试协作。其中有四个重点：一是 PDF/DOCX
> 岗位文档解析与人工审核回填，二是异步 AI
> 适配分析与推荐结果展示，三是已经可以用于招聘文案生成的企业 AI
> 助手，以及 Agent 的模型 API、短期记忆和工具调用机制，四是 LiveKit
> 实时视频会议接入。

### 9.2 60～90 秒技术介绍

> 企业移动端采用 Flutter/Dart 开发，通过 Dio 统一封装与 Java
> 后端的接口交互，并使用安全存储维护登录
> Token。我主要负责四项智能化相关工作。第一，在发布岗位时通过文件选择、大小与格式校验、multipart
> 上传调用 JD
> 识别服务，将结果转成强类型草稿，经人工审核和冲突确认后回填字段，再编排招聘流程。第二，岗位详情可触发异步
> AI
> 求职者匹配任务，客户端轮询分析状态并展示维度评分、推荐报告和候选人排序，同时避免对已分析人员重复调用模型。第三，企业侧
> AI
> 招聘助手已经可以完成实际问答，例如为首次沟通和已投递候选人生成不同的招聘话术，界面提供复制、新对话和历史入口；同时，我重点分析了
> Agent 的模型 API
> 调用、短期记忆与工具执行链，具体后端落地方式需要对照当前运行版本核实。第四，接入
> LiveKit SDK，从后端换取入会
> Token，监听成员、轨道和连接状态，完成摄像头/麦克风控制、多人画面、业务心跳和退出清理。整体上我更关注模型能力与真实招聘业务的结合，以及端到端的可靠性。

### 9.3 高频追问速答

  --------------------------------------------------------------------------------------------------------------------------------
  问题                                回答重点
  ----------------------------------- --------------------------------------------------------------------------------------------
  为什么 JD 导入后还要人工审核？      PDF/OCR/模型抽取可能丢字段或误判；草稿、强类型校验、差量 Patch 和覆盖确认降低错误发布风险。

  如何避免重复 AI 调用？              普通分析先读取候选人与已有 `source=llm` 评分；只对需要补充的数据启动任务，全量重算单独确认。

  长耗时模型请求怎么处理？            后端异步任务，客户端只触发一次并轮询状态，超时不自动二次提交。

  AI 招聘助手能做什么？               已验证可以理解招聘沟通诉求并生成分场景候选人招呼语，界面有回复复制、历史入口和新对话入口。

  Agent 为什么需要记忆？              模型 API 本身不自动维护所有会话；服务端按会话组织历史并再次作为上下文输入。服务器已运行
                                      `memory-embedding` 与 Qdrant，但其是否服务于该助手尚待源码/配置确认。

  Function Calling 谁真正执行工具？   模型输出工具名和参数；后端按白名单、Schema 和权限执行业务方法并返回结果。

  LiveKit 是什么？                    基于 WebRTC 的实时音视频平台，SDK 负责房间和媒体轨道，业务后端负责身份授权、会话和 Token。

  为什么 Flutter 不用 Docker 运行？   Flutter 移动端生成 APK/AAB/IPA 安装在设备；Docker 更适合后端、Web 服务或 CI 构建环境。

  Docker Context 与 build context     前者选择 Docker Engine；后者指定 Docker 构建时可读取的源文件目录。
  区别？                              

  为什么选用 Flutter？                使用 Dart 与跨平台组件体系复用 Android/iOS 业务交互，结合 SDK 接入文件、网络和音视频能力。
  --------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

## 十、源码定位与核验参考

以下是文档整理时**直接可读取**的公开仓库源码，优先以实际代码为准；后续仓库更新可能改变文件内容和依赖版本。

  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  分类                    文件链接                                                                                                                                                                    核验重点
  ----------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- -----------------------------------------------------------------
  项目总览                [根 README](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/README.md)                                                                     多端定位、RuoYi、数据库和本地启动

  E-App                   [E-App README](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/README.md)                                                            企业移动端功能、启动和接口范围

  E-App                   [pubspec.yaml](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/pubspec.yaml)                                                         Flutter 直接依赖版本

  E-App                   [企业首页 Shell](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/features/enterprise/enterprise_shell.dart)                      四大 Tab 与演示功能标识

  E-App                   [岗位发布页](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/features/enterprise/jobs/job_publish_page.dart)                     JD 导入、状态管理、流程保存

  E-App                   [JD 文件选择](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/features/enterprise/jobs/data/jd_document_picker.dart)             文件格式和大小校验

  E-App                   [JD 草稿模型](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/features/enterprise/jobs/models/jd_import_draft.dart)              字段校验和差量 Patch

  E-App                   [JD 文档上传](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/api/jd_document_api.dart)                                          真实解析 API

  E-App                   [招聘阶段编排](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/features/enterprise/jobs/widgets/job_publish_workflow.dart)       阶段类型/阈值/规则

  E-App                   [岗位详情页](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/features/enterprise/jobs/job_detail_page.dart)                      异步筛选任务与轮询

  E-App                   [AI 筛选 API](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/api/screening_api.dart)                                            评分、推荐、短名单、复核

  E-App                   [HTTP 客户端](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/core/network/enterprise_api_client.dart)                           Dio、Token、上传、SSE

  E-App（旧入口）         [历史占位页](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/features/enterprise/notification/assistant_placeholder_page.dart)   公开 dev 分支的历史/演示入口；**不能代表截图中已运行的聊天助手**

  E-App（旧接口）         [历史占位接口](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/api/assistant_api.dart)                                           公开 dev
                                                                                                                                                                                                      分支该函数尚未实现；**不能否定另一运行版本/调用路径的聊天能力**

  E-App                   [会议室 UI](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/features/enterprise/conference/conference_room_page.dart)            Token、心跳、结束、界面

  E-App                   [LiveKit 媒体引擎](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/features/enterprise/conference/conference_room_engine.dart)   Room 事件、音视频轨道、释放

  E-App                   [会议业务 API](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/lib/api/interview_room_api.dart)                                      会话、Token 和录制接口

  E-App                   [AndroidManifest](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/e-app/android/app/src/main/AndroidManifest.xml)                          音视频相关权限

  C-App                   [pubspec.yaml](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/c-app/pubspec.yaml)                                                         C-App Flutter 依赖

  企业 PC                 [package.json](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/enterprise_pc/RuoYi-Vue3/package.json)                                      企业 PC 真实依赖

  管理 PC                 [package.json](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/admin_pc/RuoYi-Vue3/package.json)                                           管理端真实依赖

  求职者 Web              [package.json](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/user-PC/package.json)                                                       求职者 Web 真实依赖

  求职者 Web              [部署文档](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/user-PC/docs/deployment.md)                                                     Node、构建、Nginx 代理

  后端                    [根 pom.xml](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/backend/pom.xml)                                                              版本、模块、OCR 依赖

  后端                    [ruoyi-system/pom.xml](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/backend/ruoyi-system/pom.xml)                                       WebSocket、OCR、Mail

  后端                    [ruoyi-common/pom.xml](https://raw.githubusercontent.com/Unicorn-104/Intelligent-Interviewer-System/dev/backend/ruoyi-common/pom.xml)                                       安全、Redis、JSON 等
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**核验结论（2026-10-29 修订）：** 本文已从公开仓库核验 JD
文件导入、招聘流程配置、AI 筛选 API 的客户端联调和 LiveKit Flutter
媒体接入；从用户真实运行截图证实**企业 AI
招聘助手可进行实际问答并输出招聘话术**。但**尚未定位截图所用构建版本对应的聊天
Dart 文件和后端 Agent 服务实现**。公开 `dev`
分支旧占位页/接口与运行功能不一致，已明确标注为"源码版本/入口差异"，不能据此判定整个助手不可用。模型厂商、短期记忆持久化、工具注册框架和"现有
Docker Compose 文件"仍未冒充已核实实现。文中 Dockerfile/Compose/Context
是参考部署模板，使用前需与实际环境核对。

**截图证据：** 用户于 2026-10-29 提供的 E-App「AI
招聘助手」实机页面；示例问题为"帮我写一段友好的沟通开场白"，可见 AI
输出通用版及已投递候选人版文字。运行截图没有附带网络抓包或服务端日志，因此不据此断言流式协议、历史持久化或
Function Calling 实现。

------------------------------------------------------------------------

## 附录 A：服务器下一阶段核验记录与只读操作清单

### A.1 当前已经确认的运行事实

以下结论来自本次用户实际在 SSH 服务器终端执行并回传的输出：

  -----------------------------------------------------------------------------------------------------------------------------------------------------------
  核验项                  当前证据                                                                     能得出的结论
  ----------------------- ---------------------------------------------------------------------------- ------------------------------------------------------
  SSH                     用户已成功登录 `root` shell                                                  服务器 SSH
                                                                                                       可用；第一次密码输入失败、第二次成功，不代表服务故障

  Java 后端               `hr-backend:latest`，`127.0.0.1:8080->8080/tcp`                              后端容器运行，映射端口只绑定宿主机回环地址

  Java 启动参数           `java ... -jar /app/ruoyi-admin.jar --spring.profiles.active=druid,docker`   运行的是 RuoYi/Spring Boot 形式的 JAR，并激活
                                                                                                       `druid,docker` profile

  Python 记忆相关容器     `memory-embedding`，镜像 `python:3.11-slim`，未显示宿主机端口映射            容器运行；名称提示其可能用于
                                                                                                       embedding，但实际入口、代码和调用方仍未核实

  向量数据库              `qdrant/qdrant:latest`，`healthy`，映射 `127.0.0.1:6333-6334`                Qdrant 健康运行；尚不能证明 AI
                                                                                                       招聘助手实际向其写入或检索

  LiveKit                 `livekit/livekit-server:v1.13.9` 与 `livekit/egress:v1.15.0` 均运行          服务容器存在；公开地址、端口、网络模式及 E-App
                                                                                                       的实际连接关系待核验

  Web 前端容器            `admin-pc`、`enterprise-pc`、`user-pc` 均运行                                三个 PC/Web 容器存在；它们不是 Flutter E-App

  Nginx                   宿主机 Nginx                                                                 宿主机 Nginx 进程存在；具体域名、代理规则、SSE
                          `/www/server/nginx/sbin/nginx -c /www/server/nginx/conf/nginx.conf` 正在运行 缓冲设置仍未知

  当前目录                `/root`，只看到常见用户目录与 `workspace/`                                   当前目录不是项目部署路径的充分证据，需继续查 Compose
                                                                                                       标签与挂载
  -----------------------------------------------------------------------------------------------------------------------------------------------------------

### A.2 尚未完成的远程检查

**截至本文件生成时，以下命令的执行结果尚未收到，因此不能写成已完成核验：**
`docker compose ls`、容器的 Compose 标签/挂载/入口、`memory-embedding`
内部文件、后端 JAR 中的 Agent 类名、实际 AI 助手请求路径、Nginx
反向代理配置。

当前对话环境不能直接附着到用户已经打开的 SSH
交互会话；因此下列命令需要在用户已登录的服务器 shell
中执行，再将脱敏输出反馈用于进一步分析。不要把 SSH
密码再次写入命令，也不要把完整环境变量或 `.env` 发到聊天中。

### A.3 第一组：定位 Compose 项目与部署文件

``` bash
# 1. 查看 Compose 项目
docker compose ls

# 2. 只打印容器的 Compose 标签，不输出环境变量
docker inspect -f 'name={{.Name}} image={{.Config.Image}} project={{index .Config.Labels "com.docker.compose.project"}} workdir={{index .Config.Labels "com.docker.compose.project.working_dir"}} files={{index .Config.Labels "com.docker.compose.project.config_files"}}' \
  hr-backend memory-embedding qdrant livekit-livekit-server-1
```

用途：优先获得 Compose 项目名称、部署工作目录及配置文件路径。若 `files=`
为空，可能容器不是由 Docker Compose 创建，或创建时没有保留相应标签。

### A.4 第二组：查看容器启动入口、挂载和网络（不输出环境变量）

``` bash
docker inspect -f 'name={{.Name}} image={{.Config.Image}} entrypoint={{json .Config.Entrypoint}} cmd={{json .Config.Cmd}} workdir={{.Config.WorkingDir}} mounts={{range .Mounts}}{{.Source}}->{{.Destination}};{{end}} networks={{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' \
  hr-backend memory-embedding qdrant livekit-livekit-server-1
```

重点关注 `memory-embedding` 的
`entrypoint`、`cmd`、挂载路径和网络；这些字段能帮助定位它究竟运行了什么程序，以及是否有机会连接
Qdrant。不要使用 `docker inspect <container>` 输出完整 JSON
后直接粘贴，因为完整配置可能包含敏感信息。

### A.5 第三组：检查 Python 容器实际运行什么程序

``` bash
docker exec memory-embedding sh -lc 'pwd; ps -ef; ls -lah /'
docker exec memory-embedding sh -lc 'find /app /workspace /srv -maxdepth 3 -type f 2>/dev/null | head -80'
```

如果上面找不到文件，先不要假定容器没有程序：程序可能来自其他挂载目录、镜像入口或其他工作目录。把
`pwd`、`ps -ef`、目录列表和 `docker inspect` 的脱敏结果结合起来判断。

### A.6 第四组：从后端 JAR 中定位 Agent 相关类

``` bash
docker exec hr-backend sh -lc \
  'jar tf /app/ruoyi-admin.jar 2>/dev/null | grep -Ei "assistant|agent|memory|embedding|qdrant|chat|llm|livekit|jd" | head -120'
```

如果镜像内没有 `jar` 命令，可以先检查：

``` bash
docker exec hr-backend sh -lc 'command -v jar; command -v unzip; ls -lah /app'
```

这一步的目的只是发现类名和包路径，不需要反编译或修改运行中的
JAR。找到候选类后，再依据对应仓库源码定位
Controller、Service、模型客户端和工具处理器。

### A.7 第五组：核对 Nginx 的代理方向

在宿主机执行以下只读命令：

``` bash
nginx -T 2>/dev/null | grep -E 'server_name|listen |location |proxy_pass|proxy_buffering|proxy_read_timeout'
```

此命令只提取常见路由字段，不保证覆盖所有复杂配置。输出中的域名、内部地址如果不希望公开，可先脱敏。若
AI 助手使用 SSE，需要继续确认相关 `location`
的缓冲、超时和连接保持配置；**不能仅凭存在 Nginx
就断言流式响应一定已正确代理**。

### A.8 关于日志的安全检查

如需查看服务日志，先在服务器本地检查，不要直接把未经审阅的完整日志粘贴到聊天：

``` bash
docker logs --tail 100 memory-embedding 2>&1
docker logs --tail 200 hr-backend 2>&1
```

日志可能意外包含访问令牌、请求正文、用户信息或模型服务密钥。分享之前应删除
`Authorization`、`Bearer`、`api_key`、`token`、`secret`、`password`
及真实个人信息。不要运行 `env`、`printenv`，也不要直接输出
`.env`、`application*.yml` 的完整内容。

### A.9 什么时候可以把 Agent 内部流程写成"已实现"

只有拿到对应证据后，才把下列内容升级为项目真实实现：

  --------------------------------------------------------------------------------------------------------
  待确认项                            最低证据要求
  ----------------------------------- --------------------------------------------------------------------
  模型 API                            实际运行版本中的模型客户端/HTTP 调用代码，或脱敏请求日志

  短期记忆                            会话历史的读取、追加、截断和再次传入模型的代码

  历史记录持久化                      数据表、Redis Key、文件存储或其他存储读写实现

  Qdrant 长期/语义记忆                实际 collection、向量化调用、写入和查询代码，且能追到助手请求链

  Function Calling                    工具定义、模型工具调用解析、权限校验、工具执行与结果回传的完整链路

  流式输出                            客户端真实协议与后端响应方式（例如 SSE）以及取消/断开处理代码

  LiveKit Token                       后端签发 Token 的接口、身份/房间授权规则和客户端连接地址

  部署关系                            Compose 标签、服务网络、挂载、Nginx 配置与运行进程共同印证
  --------------------------------------------------------------------------------------------------------

### A.10 安全提醒

服务器 SSH 密码此前曾以明文出现在聊天中。建议尽快更换密码，优先配置 SSH
公钥认证，并确认登录日志中是否存在非本人来源的失败尝试。不要把密码、数据库凭据、模型
API Key、LiveKit API Secret、JWT Secret 或完整环境变量写入本项目文档或
Git 仓库。

------------------------------------------------------------------------

## 附录 B：当前结论摘要

**已确认：** E-App 企业 AI
招聘助手在实际运行截图中可以完成招聘话术生成；服务器正在运行 Java
后端、Python 3.11 容器、健康状态的 Qdrant、LiveKit Server/Egress 和三个
Web 前端容器；宿主机 Nginx 进程存在；后端 JAR 启用了 `druid,docker`
profile；部分端口仅绑定 `127.0.0.1`。

**尚未确认：** 当前聊天功能的具体
Controller/Service、模型提供商与协议、短期记忆保存方式、Qdrant
是否服务于该助手、工具注册及执行机制、Python 容器的真实用途、Compose
文件路径、Nginx 的实际路由与 SSE 配置、LiveKit 公网媒体连接配置。

**对外介绍建议：** 可以明确说"企业侧 AI
招聘助手已可实际生成招聘沟通话术，服务器部署了后端、向量数据库和 LiveKit
等服务"；在没有完成上述代码与配置核验前，不要把"Qdrant
长期记忆""Function Calling 已落地""SSE
流式输出"等内部细节写成已经证实的事实。

---

## 附录 C：2026-10-29 最新服务器检查结果

### C.1 本轮实际返回的结果

本节以用户本轮在服务器上实际执行并回传的命令输出为依据，更新此前的待核验状态。

#### Compose 项目与部署位置

`docker compose ls` 返回：

| Compose 项目 | 状态 | 配置文件 |
|---|---|---|
| `docker-compose` | `running(4)` | `/www/docker-compose/docker-compose.yml` |
| `embedding` | `running(1)` | `/www/embedding/docker-compose.yml` |
| `livekit` | `running(2)` | `/www/livekit/docker-compose.yml` |
| `qdrant` | `running(1)` | `/www/qdrant/docker-compose.yml` |

容器标签进一步确认：

| 容器 | 镜像 | Compose 工作目录 | 配置文件 |
|---|---|---|---|
| `hr-backend` | `hr-backend:latest` | `/www/docker-compose` | `/www/docker-compose/docker-compose.yml` |
| `memory-embedding` | `python:3.11-slim` | `/www/embedding` | `/www/embedding/docker-compose.yml` |
| `qdrant` | `qdrant/qdrant:latest` | `/www/qdrant` | `/www/qdrant/docker-compose.yml` |
| `livekit-livekit-server-1` | `livekit/livekit-server:v1.13.9` | `/www/livekit` | `/www/livekit/docker-compose.yml` |

这确认了部署配置分为四个 Compose 项目，而不是全部集中在一个 Compose 文件中。

#### Python 记忆服务

用户在容器内执行文件查找后，实际找到：

- `/app/memory_embedding_service.py`
- `/app/requirements-memory.txt`

容器工作目录为 `/app`，根目录下有 `/models` 目录。由于容器中没有 `ps` 命令，不能从该命令得出进程列表；这属于精简镜像缺少工具，不代表服务异常。

**当前可确认：** 服务器部署了一个独立 Python 记忆/向量化服务，并且存在其源文件与依赖清单。

**仍不能确认：** 该服务是否被 AI 招聘助手调用、使用哪一种 Embedding 模型、是否直接访问 Qdrant、是否保存对话短期记忆。必须继续阅读代码、依赖和 Compose 的网络/启动配置。

#### Java 后端 JAR 检查

尝试执行 `jar tf /app/ruoyi-admin.jar` 后没有匹配输出。由于原命令将标准错误重定向到 `/dev/null`，并且使用了 `grep` 过滤，不能判断是缺少 `jar` 命令、JAR 路径不正确，还是确实没有相关类名。后续应先确认命令与文件存在，再使用可用的归档工具读取 JAR 条目。

### C.2 下一步：先检查记忆服务代码与依赖

在服务器 SSH shell 中执行以下命令。这些命令只读取文件，不修改服务。

先查看依赖清单：

```bash
cat /www/embedding/requirements-memory.txt
```

再查看 Python 文件的函数、路由、模型和数据库调用位置：

```bash
grep -nE '^(class |def |async def )|@app\\.|FastAPI|Flask|Qdrant|embedding|sentence|transformers|openai|httpx|requests|uvicorn|collection|memory|history' \
  /www/embedding/memory_embedding_service.py
```

然后查看源码主体（分享前先检查是否有写死的密钥；不要将任何凭据发到聊天中）：

```bash
sed -n '1,260p' /www/embedding/memory_embedding_service.py
```

如果文件较长，可再查看后续部分：

```bash
sed -n '261,520p' /www/embedding/memory_embedding_service.py
```

查看 Compose 时不要直接粘贴包含密码或 Token 的环境变量值。可先用下面的命令输出结构并隐藏常见敏感字段：

```bash
sed -E \
  -e '/(PASSWORD|PASSWD|SECRET|TOKEN|API[_-]?KEY|PRIVATE[_-]?KEY|AUTHORIZATION)/I s/(:[[:space:]]*|=[[:space:]]*).*/\\1[REDACTED]/' \
  /www/embedding/docker-compose.yml
```

此脱敏表达式只能过滤常见命名，分享前仍需人工检查是否出现真实密钥、访问令牌或密码。也可以只分享 `services`、`ports`、`volumes`、`networks`、`command`、`entrypoint` 等非敏感配置片段。

### C.3 检查后端 JAR 是否可读取

先确认文件与工具是否存在：

```bash
docker exec hr-backend sh -lc 'ls -lah /app; command -v jar; command -v unzip'
```

如果容器中没有 `jar`，可检查宿主机是否有归档工具：

```bash
command -v jar
command -v unzip
```

如果宿主机有 `unzip`，并且确认后端 JAR 位于容器内 `/app/ruoyi-admin.jar`，可以把它复制到服务器临时目录，再查看条目：

```bash
docker cp hr-backend:/app/ruoyi-admin.jar /tmp/ruoyi-admin-inspect.jar
unzip -l /tmp/ruoyi-admin-inspect.jar | grep -Ei 'assistant|agent|memory|embedding|qdrant|chat|llm|livekit|jd' | head -120
```

完成后删除临时副本：

```bash
rm -f /tmp/ruoyi-admin-inspect.jar
```

以上操作只复制和列出 JAR 内容，不会重启或修改运行中的后端。注意：如果 JAR 包含内部类名，这些类名可以用于定位，但仍需结合源代码或字节码确认真实业务逻辑。

### C.4 对当前 Agent 实现的准确表述

当前证据足以说明：

1. 企业侧 AI 招聘助手在实际运行截图中可以生成招聘沟通话术。
2. Java 后端容器正在运行，且有独立 Python 记忆服务、Qdrant 向量数据库和 LiveKit 服务。
3. Python 服务的源文件和依赖清单已经定位到服务器上的 `/www/embedding` 部署项目。

当前证据**不足以**断言：

- AI 助手一定通过 Qdrant 实现长期记忆；
- 短期对话历史具体存储于 Redis、数据库还是进程内存；
- Agent 已经实现 Function Calling 或特定业务工具；
- 助手使用 SSE、WebSocket 或其他流式协议；
- Python 记忆服务中的具体模型、Embedding 维度或向量 collection 名称；
- LiveKit 的 Token 签发接口和鉴权逻辑已经核实。

上述细节应在检查 `memory_embedding_service.py`、依赖清单、Compose 配置和后端 AI 服务代码后再写成确定结论。

---

## 附录 D：Embedding 服务源码核验结果（2026-10-29）

### D.1 依赖与模型

用户在服务器执行 `cat /www/embedding/requirements-memory.txt`，实际输出为：

```text
fastembed>=0.7,<1.0
```

源码 `/www/embedding/memory_embedding_service.py` 给出了以下默认配置（运行时环境变量可以覆盖这些默认值）：

| 配置 | 源码中的默认值 | 含义 |
|---|---|---|
| `MEMORY_EMBEDDING_MODEL` | `BAAI/bge-small-zh-v1.5` | 使用的文本向量模型名称 |
| `MEMORY_EMBEDDING_MODEL_PATH` | `/models/bge-small-zh-v1.5` | 本地模型目录 |
| `MEMORY_EMBEDDING_HOST` | `127.0.0.1` | 仅绑定回环地址 |
| `MEMORY_EMBEDDING_PORT` | `8091` | HTTP 服务端口 |
| `MEMORY_EMBEDDING_THREADS` | `1` | CPU 推理线程数 |
| `MEMORY_EMBEDDING_PRELOAD` | `true` | 默认启动时预加载模型 |
| `MEMORY_EMBEDDING_TOKEN` | 空字符串 | 可选的 Bearer Token；是否启用取决于部署环境变量 |

代码显式设置 `HF_HUB_OFFLINE=1`、`TRANSFORMERS_OFFLINE=1`、`HF_HUB_DISABLE_TELEMETRY=1`，并使用 `local_files_only=True`、`CPUExecutionProvider`，表明该服务设计为从本地模型目录离线加载模型、使用 CPU 执行推理。模型目录不存在时会报错，不会在这段代码中自动下载模型。

### D.2 HTTP 接口

源码使用 Python 标准库 `http.server.HTTPServer` 与 `BaseHTTPRequestHandler`，没有使用 FastAPI 或 Flask。当前可确认的接口如下：

| 方法与路径 | 用途 | 行为 |
|---|---|---|
| `GET /health` | 健康检查 | 会调用 `get_model()`，因此不仅检查进程，也会检查模型能否加载；成功返回 `status=ok` 和模型名，失败返回 503 |
| `POST /v1/embeddings` | 文本向量化 | 接受 JSON 请求，返回每条文本对应的 embedding 向量 |

`POST /v1/embeddings` 的关键约束：

- 请求体必须是 JSON 对象。
- `input` 必须是字符串数组，数量为 1–16 条。
- 每条文本必须非空，且长度不超过 2000 个字符。
- `input_type` 只允许 `query` 或 `passage`，默认 `passage`。
- 当 `MEMORY_EMBEDDING_TOKEN` 非空时，必须通过 `Authorization: Bearer <token>` 验证。
- 请求体长度小于 2 字节或超过 65536 字节会被拒绝。
- `input_type=query` 时调用 `model.query_embed(texts)`；`passage` 时调用 `model.passage_embed(texts)`。
- 成功返回类似 OpenAI Embeddings 风格的 `object=list`、`model`、`data[].embedding` 结构。
- 异常响应只返回通用错误信息，并仅记录异常类型，源码注释明确避免记录用户文本、Token 和异常详情。
- `log_message()` 只记录状态码，不打印请求正文。

### D.3 模型加载与并发

`get_model()` 使用模块级变量缓存模型实例，并通过 `threading.Lock` 防止首次初始化时重复加载。启动时默认执行预加载。`HTTPServer` 是标准库的同步服务器；源码中没有实现异步任务队列或多进程推理。`THREADS` 参数用于 FastEmbed/CPU 执行提供器配置，不等同于 HTTP 服务的并发线程数。

### D.4 一个重要的归属边界：此服务明确标注为 C-App 个人记忆

Python 文件第一行的模块说明为：

> `Loopback-only FastEmbed adapter for the C-App personal-memory Qdrant index.`

因此，**现有证据指向这是 C-App（求职者端）个人记忆 Qdrant 索引使用的 Embedding 适配服务**。它证明服务器上有个人记忆向量化组件，但不能单凭该组件就认定 E-App（企业端）智能招聘助手使用了相同的记忆链路。

在企业 AI 招聘助手章节中，应作如下区分：

- **已确认的企业侧功能：** 根据用户提供的真实运行截图，企业侧 AI 招聘助手可以生成招聘沟通话术并提供对话交互。
- **已确认的服务器基础设施：** 存在独立 FastEmbed HTTP 服务，默认使用 `BAAI/bge-small-zh-v1.5`，并且源码文档将其用途指向 C-App 个人记忆 Qdrant 索引。
- **尚待核实的企业侧 Agent 实现：** 企业助手是否有自己的会话记忆、是否调用大模型 API、是否使用 Function Calling、是否调用该 Embedding 服务或 Qdrant，必须继续从企业侧客户端接口和 Java 后端调用链确认。

### D.5 下一步应检查的文件

#### 1. 后端 Compose 配置（注意脱敏）

在服务器执行：

```bash
sed -n '1,260p' /www/docker-compose/docker-compose.yml
```

分享之前检查并删除密码、API Key、Token、数据库连接凭据和其他敏感值。优先保留 `services`、`ports`、`volumes`、`networks`、`command`、`entrypoint`、`depends_on` 等字段。

#### 2. 后端容器中的 JAR 与工具

```bash
docker exec hr-backend sh -lc 'ls -lah /app; command -v jar; command -v unzip'
```

若 `jar` 在容器中不存在，不要把空输出解释为没有 Agent 类。可从宿主机检查：

```bash
command -v jar
command -v unzip
```

如果宿主机有 `unzip`，再只复制 JAR 到临时位置并列出条目：

```bash
docker cp hr-backend:/app/ruoyi-admin.jar /tmp/ruoyi-admin-inspect.jar
unzip -l /tmp/ruoyi-admin-inspect.jar | grep -Ei 'assistant|agent|memory|embedding|qdrant|chat|llm|livekit|jd|job|resume|candidate' | head -160
rm -f /tmp/ruoyi-admin-inspect.jar
```

该检查只是列出归档条目，不能单独证明业务执行流程。若未找到匹配类名，还应考虑打包结构、类名命名和依赖 JAR 的情况。

#### 3. 搜索后端源码仓库

先从 `/www/docker-compose/docker-compose.yml` 的挂载路径或部署说明确定源代码所在目录，再对**确认的项目源码目录**进行搜索，而不是在整个服务器上无边界扫描：

```bash
grep -RInE 'ChatClient|ChatModel|OpenAI|DashScope|DeepSeek|FunctionCallback|ToolCallback|@Tool|tool_calls|qdrant|memory_embedding|/v1/embeddings|assistant' \
  /实际的后端源码目录 2>/dev/null | head -200
```

将 `/实际的后端源码目录` 替换为真实路径；不要原样执行占位路径。检查结果中如有硬编码密钥，应立即停止分享并先脱敏。

### D.6 对项目介绍的推荐表述

可以准确写成：

> 服务器部署了独立的 Python 文本向量化服务，基于 FastEmbed 加载本地中文 BGE 模型，并通过受限的 HTTP Embeddings 接口生成 query/passage 向量；服务默认使用 CPU 推理、离线模型文件和回环地址监听。其源码说明该服务面向 C-App 的个人记忆 Qdrant 索引。企业侧 AI 招聘助手的具体大模型调用、短期记忆、工具调用以及是否复用该向量服务，仍需结合企业端接口与后端源码确认。

不要把这个 Python 服务直接写成“企业侧 Agent 的短期记忆模块”。Embedding 负责把文本转换为向量，本身不等于对话历史存储，也不等于检索逻辑；向量数据库检索和会话记忆管理需要由其他代码实现。

---

## 附录 E：后端 Compose 配置与 JAR 检查结果（2026-10-29）

### E.1 后端部署方式已进一步确认

用户在服务器执行 `sed -n '1,260p' /www/docker-compose/docker-compose.yml`，实际配置表明，该 Compose 项目统一编排 Java 后端和三个 Web 前端：

| 服务 | 构建上下文 | Dockerfile | 镜像 | 宿主机绑定 |
|---|---|---|---|---|
| `hr-backend` | `./backend` | `Dockerfile` | `hr-backend:latest` | `127.0.0.1:8080` → 容器 `8080` |
| `admin-pc` | `./admin_pc/RuoYi-Vue3` | `Dockerfile` | `admin-pc:latest` | `127.0.0.1:8081` → 容器 `80` |
| `enterprise-pc` | `./enterprise_pc/RuoYi-Vue3` | `Dockerfile` | `enterprise-pc:latest` | `127.0.0.1:8082` → 容器 `80` |
| `user-pc` | `./user-PC` | `Dockerfile` | `user-pc:latest` | `127.0.0.1:8083` → 容器 `80` |

Compose 文件注释明确说明：MySQL 与 Redis 安装在宿主机（宝塔），后端通过 `172.17.0.1` 访问宿主机的 MySQL `3306` 和 Redis `6379`。这是文件中声明的网络设计；实际连接是否成功仍应由应用日志或健康检查确认。

后端配置还确认：

- `restart: always`：容器退出后由 Docker 尝试自动重启。
- `/home/ruoyi/uploadPath:/home/ruoyi/uploadPath`：把宿主机上传目录挂载到容器内相同路径，避免上传文件只存在于容器可写层。
- 三个 Web 前端均设置 `depends_on: hr-backend`，用于声明启动依赖；Compose 的 `depends_on` 本身不等同于应用健康检查，也不一定等待后端业务接口可用。
- 所有 Web 服务端口均绑定 `127.0.0.1`，表示通过宿主机回环接口访问；公网请求通常需要宿主机 Nginx 等代理转发。真实代理路由仍需查看 Nginx 配置。

### E.2 与企业侧移动端 E-App 的关系

该 Compose 文件部署的是 Java 后端、管理员 PC、企业 PC、求职者 PC，不包含 Flutter `e-app` 的构建服务。这通常意味着 E-App 作为移动客户端单独构建/发布，通过 API 访问后端；但其实际 API Base URL、鉴权方式与网络协议还需要结合 E-App 源码确认。

因此，项目架构介绍应将以下端区分清楚：

- `e-app`：Flutter 企业侧移动端，面向 HR/面试官。
- `enterprise_pc`：Vue 企业 PC 管理端。
- `user-PC`：求职者 Web 端。
- `admin_pc/RuoYi-Vue3`：系统管理 Web 端。
- `backend`：Java/Spring Boot/RuoYi 后端服务。

### E.3 Java 后端 JAR 的当前检查状态

`docker exec hr-backend sh -lc 'ls -lah /app; command -v jar; command -v unzip'` 的实际输出显示：

- `/app/ruoyi-admin.jar` 存在，大小约 `122M`。
- 容器内没有返回 `jar` 和 `unzip` 的可执行路径。

这不代表 JAR 无法检查，也不代表没有 Agent 类。只是当前后端容器镜像没有通过 `command -v` 找到这两个归档工具。应在宿主机检查 `unzip`、`python3` 或 `java` 是否存在，再使用已有工具读取 JAR 目录；不需要在生产容器内安装软件或重启后端。

### E.4 下一步只读命令

先确认后端源代码目录是否实际保留在宿主机，以及宿主机是否有归档工具：

```bash
ls -lah /www/docker-compose
ls -lah /www/docker-compose/backend
command -v unzip
command -v python3
command -v java
```

若 `/www/docker-compose/backend` 有源码，可在该目录内查找助手相关类和接口：

```bash
grep -RInE 'ChatClient|ChatModel|OpenAI|DeepSeek|DashScope|FunctionCallback|ToolCallback|@Tool|tool_calls|qdrant|memory_embedding|/v1/embeddings|assistant|agent|livekit' \
  /www/docker-compose/backend 2>/dev/null | head -200
```

请检查并脱敏任何硬编码密钥后再分享结果。若没有源码目录，则从运行中的容器只复制 JAR 到宿主机临时路径，不修改正在运行的服务：

```bash
docker cp hr-backend:/app/ruoyi-admin.jar /tmp/ruoyi-admin-inspect.jar
```

如果宿主机有 `unzip`：

```bash
unzip -l /tmp/ruoyi-admin-inspect.jar | grep -Ei 'assistant|agent|memory|embedding|qdrant|chat|llm|livekit|jd|job|resume|candidate' | head -160
```

如果宿主机有 Python 3，可使用标准库列出 Spring Boot JAR 中的条目：

```bash
python3 - <<'PY'
import zipfile
p = "/tmp/ruoyi-admin-inspect.jar"
keywords = ("assistant", "agent", "memory", "embedding", "qdrant", "chat", "llm", "livekit", "jd", "job", "resume", "candidate")
with zipfile.ZipFile(p) as z:
    for name in z.namelist():
        if any(k in name.lower() for k in keywords):
            print(name)
PY
```

检查完毕后删除临时副本：

```bash
rm -f /tmp/ruoyi-admin-inspect.jar
```

这组命令只复制并读取 JAR 目录，不会更改正在运行的容器。JAR 条目名称可以帮助定位代码，但要确认具体逻辑仍需继续读取源码或反编译对应类。

### E.5 目前对企业 AI 招聘助手可作出的准确结论

- 企业侧助手在用户提供的真实运行截图中可以生成招聘沟通话术，说明聊天功能实际可用。
- Java 后端以 Docker 容器运行，入口 JAR 为 `/app/ruoyi-admin.jar`，激活 `druid,docker` Spring profile。
- 宿主机 MySQL/Redis、宿主机 Nginx、独立 Qdrant 与 Embedding 服务、LiveKit 服务都存在于部署架构中。
- Embedding 源码的模块说明明确指向 C-App 个人记忆 Qdrant 索引，因此不能在没有后端调用证据时把它写成 E-App Agent 的记忆实现。
- 企业助手的模型调用类、会话历史策略、工具注册/执行、响应流协议和停止生成机制仍需从后端类与 E-App API 客户端源码进一步确认。

---

## 附录 F：后端源码目录搜索与下一步 JAR 定位（2026-10-29）

### F.1 本轮结果

用户在服务器上确认：

- 宿主机存在 `/usr/bin/unzip`。
- 宿主机存在 `/usr/bin/python3`。
- `command -v java` 没有输出，说明当前宿主机 PATH 中没有可直接调用的 `java` 命令。
- 对 `/www/docker-compose/backend` 执行包含 `ChatClient`、`ChatModel`、`OpenAI`、`DeepSeek`、`qdrant`、`assistant`、`agent`、`livekit` 等关键字的递归搜索，没有输出匹配项。

由于命令将错误输出重定向到了 `/dev/null`，这不能单独证明源码目录存在但没有相关实现；也可能是目录不存在、没有源文件、权限或搜索关键字不匹配。下一步先查看目录本身，再从正在运行的 JAR 中列出归档条目。

### F.2 先确认构建上下文是否保留源码

在服务器执行：

```bash
ls -lah /www/docker-compose
ls -lah /www/docker-compose/backend
find /www/docker-compose/backend -maxdepth 4 -type f 2>/dev/null | head -100
```

根据结果判断：

- 如果存在 `src/main/java`、`pom.xml` 等文件，可以继续搜索源码。
- 如果目录不存在或基本为空，说明当前服务器部署目录可能只保留 Compose 配置或已不保留原始源代码；不代表运行中的 JAR 没有相应功能。

### F.3 安全地列出 JAR 条目

容器中已确认 `/app/ruoyi-admin.jar` 存在，大小约 122 MB；宿主机有 `unzip` 与 Python 3，足以在不修改生产容器的情况下读取 JAR 的目录结构。

执行：

```bash
docker cp hr-backend:/app/ruoyi-admin.jar /tmp/ruoyi-admin-inspect.jar
unzip -Z1 /tmp/ruoyi-admin-inspect.jar | grep -Ei 'assistant|agent|memory|embedding|qdrant|chat|llm|livekit|jd|job|resume|candidate|interview|recruit' | head -200
```

如果这条命令有输出，把条目名称发来即可。它只列出文件路径，不会执行 JAR 中的代码。

如果没有输出，不要立即判定不存在 Agent：类名可能采用业务术语、位于嵌套依赖中，或由其他模块提供。可以先列出 Spring Boot 的包结构：

```bash
unzip -Z1 /tmp/ruoyi-admin-inspect.jar | head -100
```

再列出应用自身的类文件：

```bash
unzip -Z1 /tmp/ruoyi-admin-inspect.jar | grep '^BOOT-INF/classes/.*\.class$' | head -200
```

并检查配置文件名（不要打印配置内容）：

```bash
unzip -Z1 /tmp/ruoyi-admin-inspect.jar | grep -Ei 'BOOT-INF/classes/.*(application.*yml|application.*yaml|application.*properties|\.xml)$' | head -100
```

完成检查后清理临时副本：

```bash
rm -f /tmp/ruoyi-admin-inspect.jar
```

### F.4 后续如何从类名追到 Agent 逻辑

找到候选类之后，需要继续确认：

1. Controller 的映射路径、请求 DTO 和响应类型；
2. Service 如何拼接 Prompt、调用模型客户端；
3. 对话历史是通过数据库、Redis、内存还是请求参数管理；
4. 如果存在工具调用，工具定义如何交给模型、工具执行结果如何回填；
5. E-App Flutter 客户端调用哪个 API，如何处理生成中、完成、失败和停止状态。

JAR 目录列表只能帮助定位类名与资源路径，不能独立证明实现细节。若部署目录没有源代码，下一步可依据找到的包名/类名检查仓库对应源文件，或在确认权限与安全前提后对单个目标类进行反编译分析；不需要修改正在运行的服务。

### F.5 对外项目介绍的边界

企业侧 AI 招聘助手已经通过用户提供的实际运行截图证明可生成招聘沟通话术；后端容器、向量数据库、Python Embedding 服务和 LiveKit 服务也已从运行状态核实。当前还没有足够证据描述企业助手内部的具体模型 SDK、短期记忆存储方式、Function Calling 工具列表或流式协议，因此这些内容仍应标记为待源码核实。

---

## 附录 G：从运行中 JAR 定位到企业 AI 助手控制器（2026-10-29）

### G.1 本轮检查的直接证据

用户在服务器执行：

```bash
docker cp hr-backend:/app/ruoyi-admin.jar /tmp/ruoyi-admin-inspect.jar
unzip -Z1 /tmp/ruoyi-admin-inspect.jar | grep -Ei 'assistant|agent|memory|embedding|qdrant|chat|llm|livekit|jd|job|resume|candidate|interview|recruit' | head -200
```

实际输出中出现以下类：

| JAR 条目 | 可确认的定位 | 仍需验证的内容 |
|---|---|---|
| `com/ruoyi/web/controller/enterprise/EnterpriseAssistantController.class` | 企业助手控制器类存在 | 真实 API 路径、模型调用、会话历史、停止生成方式 |
| `com/ruoyi/web/controller/enterprise/EnterpriseJdController.class` | 企业 JD 控制器类存在 | 岗位 CRUD、字段校验及流程编排 |
| `com/ruoyi/web/controller/enterprise/EnterpriseJdDocumentController.class` | 企业 JD 文档控制器类存在 | 文件上传、解析器调用、草稿和确认流程 |
| `com/ruoyi/web/controller/enterprise/ChatJobCardController.class` | 企业聊天岗位卡片控制器类存在 | 卡片生成和聊天业务的关联 |
| `com/ruoyi/web/controller/system/ConferenceLiveKitController.class` | LiveKit 会议控制器类存在 | 房间创建、Token 签发、权限和过期策略 |
| `com/ruoyi/web/controller/agent/AgentJobController.class` | Agent 岗位控制器类存在 | Agent 具体执行逻辑及岗位数据来源 |
| `com/ruoyi/web/controller/agent/AgentApplicationController.class` | Agent 申请控制器类存在 | 申请状态、工具调用和业务授权 |
| `com/ruoyi/web/controller/admin/AiAgentMonitorController.class` | Agent 监控控制器类存在 | 监控数据来源、执行记录及错误处理 |
| `com/ruoyi/web/controller/ai/AdminAssistantController.class` | 管理员 AI 助手控制器类存在 | 与企业侧 `EnterpriseAssistantController` 的职责边界 |
| `com/ruoyi/web/controller/ai/AiModelController.class` | AI 模型管理控制器类存在 | 模型供应商和配置管理方式 |
| `com/ruoyi/web/controller/system/ModelProviderController.class` | 模型供应商控制器类存在 | 供应商配置与实际推理客户端如何连接 |
| `com/ruoyi/web/controller/app/AppAiController.class` | C-App AI 接口控制器类存在 | 求职者端 AI 功能，与企业侧助手是否共享底层服务 |
| `com/ruoyi/web/controller/app/AppAiMemoryController.class` | C-App AI 记忆控制器类存在 | 个人记忆设置和记忆服务的具体关系 |

这次检查还列出了 `AppAiController`、`AppAiMemoryController` 等求职者端类，进一步支持一个重要区分：服务器同时包含企业侧助手与 C-App AI/记忆相关控制器，但类文件的存在不代表这些接口都被 E-App 调用，也不能据此认定它们共享同一套记忆机制。

### G.2 后端源码目录的当前状态

本轮检查发现：

- `/www/docker-compose/` 下只看到了 `docker-compose.yml`。
- `/www/docker-compose/backend` 不存在。
- 在该路径执行 `grep -R` 没有返回源码匹配项。
- 运行中的容器 `/app/ruoyi-admin.jar` 存在，大小约 122 MB。
- 宿主机具有 `/usr/bin/unzip` 和 `/usr/bin/python3`，但 `command -v java` 没有返回可执行路径。
- JAR 归档列表已经成功读取，证明可以在不重启后端的情况下继续分析类文件。

因此，下一步应基于 JAR 条目定位控制器与服务类，而不是继续在不存在的源码目录中搜索。JAR 中的类名可以帮助确定业务边界；要确认方法体，需要查看对应源码版本或用合适的 Java 反编译工具分析单个目标类。

### G.3 下一步一：查找与企业助手配套的 Service 类

如果 `/tmp/ruoyi-admin-inspect.jar` 仍存在，可直接执行：

```bash
unzip -Z1 /tmp/ruoyi-admin-inspect.jar \
  | grep '^BOOT-INF/classes/.*\.class$' \
  | grep -Ei '/(service|serviceimpl|ai|agent|enterprise|common)/|Assistant|Agent|Memory|Embedding|Chat|Model|Tool|JdDocument|LiveKit|Conference' \
  | head -300
```

再检查 Spring Boot 包含哪些 AI/网络/实时通信相关依赖 JAR（只查看依赖名称，不输出配置值）：

```bash
unzip -Z1 /tmp/ruoyi-admin-inspect.jar \
  | grep '^BOOT-INF/lib/.*\.jar$' \
  | grep -Ei 'spring-ai|langchain|openai|dashscope|deepseek|qdrant|redis|webflux|websocket|okhttp|httpclient|livekit|jackson|mybatis'
```

依赖名只说明这些库可能被打包，不一定证明企业助手实际使用了某个库。若没有匹配输出，也可能是项目使用自定义 HTTP 客户端或未采用这些特定框架。

### G.4 下一步二：从控制器 class 中提取可读字符串

没有 Java 运行环境也可以先用 `strings` 查看 class 文件中保留的字符串常量，包括可能的 URL 路径、字段名、错误消息和服务类引用。它不能完整还原 Java 方法逻辑，但可以辅助定位。

```bash
unzip -p /tmp/ruoyi-admin-inspect.jar \
  BOOT-INF/classes/com/ruoyi/web/controller/enterprise/EnterpriseAssistantController.class \
  | strings
```

针对 JD 文档：

```bash
unzip -p /tmp/ruoyi-admin-inspect.jar \
  BOOT-INF/classes/com/ruoyi/web/controller/enterprise/EnterpriseJdDocumentController.class \
  | strings
```

针对 LiveKit：

```bash
unzip -p /tmp/ruoyi-admin-inspect.jar \
  BOOT-INF/classes/com/ruoyi/web/controller/system/ConferenceLiveKitController.class \
  | strings
```

针对 Agent 业务入口：

```bash
unzip -p /tmp/ruoyi-admin-inspect.jar \
  BOOT-INF/classes/com/ruoyi/web/controller/agent/AgentJobController.class \
  | strings

unzip -p /tmp/ruoyi-admin-inspect.jar \
  BOOT-INF/classes/com/ruoyi/web/controller/agent/AgentApplicationController.class \
  | strings
```

输出中可能包含业务提示文本或接口路径；分享前仍需人工检查并脱敏任何凭据或个人数据。若要完整还原方法体，需进一步使用与 Java class 版本兼容的反编译工具或取得匹配版本的源码。

### G.5 下一步三：检查 JD 与 AI 助手的服务层调用链

继续在 JAR 条目中搜索可能配套的 Service、DTO 和配置类：

```bash
unzip -Z1 /tmp/ruoyi-admin-inspect.jar \
  | grep '^BOOT-INF/classes/.*\.class$' \
  | grep -Ei 'EnterpriseAssistant|EnterpriseJd|JdDocument|ChatJobCard|ConferenceLiveKit|AgentJob|AgentApplication|AiModel|ModelProvider|Prompt|Conversation|Message|Memory|Embedding|Tool|LLM|Chat'
```

需要优先找出：

1. 企业助手 Controller 注入了哪个 Service；
2. Service 是否调用独立的模型客户端或通用 AI 服务；
3. 会话 ID、消息列表和上下文是否在服务端保存；
4. 是否有工具注册、参数解析、业务方法执行和工具结果回填；
5. JD 文档上传后由哪个解析服务处理，解析结果是否进入草稿/确认流程；
6. LiveKit Token 由哪个类生成，身份、房间和权限如何绑定。

若类条目没有明显的 Service 命名，可以先从 Controller 字符串提取类引用或 endpoint，再结合全 JAR 类列表反查。

### G.6 对四个重点功能的证据状态更新

#### 企业 AI 招聘助手 / Agent

- **已确认：** `EnterpriseAssistantController.class` 存在，真实运行截图证明企业侧助手能生成招聘沟通话术。
- **待确认：** 实际模型客户端、Prompt、会话记忆、工具调用循环、流式协议、停止生成机制。
- **面试材料写法：** 可以描述可用的企业招聘对话功能；具体 Agent 内部技术应在继续分析类方法后再作确定陈述。

#### JD 文档识别与编排

- **已确认：** `EnterpriseJdDocumentController.class` 和 `EnterpriseJdController.class` 均存在。
- **待确认：** PDF/DOCX 解析器的具体依赖、解析服务调用、字段归一化、草稿保存与用户确认的真实代码链。
- **面试材料写法：** 可以说明存在独立 JD 文档控制器；解析与编排细节应依据方法实现确认。

#### AI 岗位适配分析与推荐

- **已确认：** JAR 中有岗位、简历、候选人、申请、Agent 岗位等多类控制器，例如 `EnterpriseResumeController`、`TalentDiscoveryController`、`AgentJobController`、`AgentApplicationController`。
- **待确认：** 评分算法、候选人召回方式、是否使用向量检索、异步任务机制和排序依据。
- **面试材料写法：** 不应仅凭类名断言匹配算法、模型或评分公式。

#### LiveKit 视频面试

- **已确认：** `ConferenceLiveKitController.class` 存在，且服务器上的 LiveKit Server 与 Egress 容器处于运行状态。
- **待确认：** Token 生成、房间管理、权限校验、客户端连接参数、Webhook 与 Egress 录制流程。
- **面试材料写法：** 可以说明系统集成了 LiveKit 服务与会议控制器；完整鉴权与媒体流程还需继续追踪。

### G.7 清理临时文件

分析完成后执行：

```bash
rm -f /tmp/ruoyi-admin-inspect.jar
```

这是清理本轮复制的 JAR 临时文件，不会影响运行中的 `hr-backend` 容器。

---

## 附录 H：本轮结论

本轮从正在运行的后端 JAR 中成功定位到企业助手、JD 文档、JD 岗位、Agent 岗位/申请、AI 模型、C-App 记忆和 LiveKit 会议等控制器类。服务器没有保留 `/www/docker-compose/backend` 源码目录，因此后续应通过 JAR 条目、class 字符串、服务层类定位或兼容的反编译工具继续核实。

这比仅根据基础设施名称推测实现更可靠，但仍需区分“控制器类存在”和“内部功能已经按某种算法实现”。后续文档只有在拿到方法级证据后，才能把模型调用、短期记忆、Function Calling、JD 解析器与 LiveKit Token 逻辑写成确定的实现细节。

---

## 附录 I：JAR 临时文件清理顺序修正（2026-10-29）

### I.1 本轮命令结果的原因

本轮终端输出显示，用户先执行：

```bash
rm -f /tmp/ruoyi-admin-inspect.jar
```

随后才尝试使用 `unzip -p /tmp/ruoyi-admin-inspect.jar ...` 提取三个类的字符串。由于临时 JAR 已经被删除，后续命令自然无法读取该文件，因而没有输出。

**这不是类不存在的证据，也不推翻此前成功列出类条目的结果。** 此前的 JAR 目录已经明确包含：

- `com/ruoyi/web/controller/enterprise/EnterpriseAssistantController.class`
- `com/ruoyi/web/controller/enterprise/EnterpriseJdDocumentController.class`
- `com/ruoyi/web/controller/system/ConferenceLiveKitController.class`

### I.2 正确的执行顺序

在服务器 SSH shell 中，先复制 JAR：

```bash
docker cp hr-backend:/app/ruoyi-admin.jar /tmp/ruoyi-admin-inspect.jar
```

确认文件存在：

```bash
ls -lh /tmp/ruoyi-admin-inspect.jar
```

然后依次提取企业助手、JD 文档和 LiveKit 类的可读字符串：

```bash
unzip -p /tmp/ruoyi-admin-inspect.jar \
  BOOT-INF/classes/com/ruoyi/web/controller/enterprise/EnterpriseAssistantController.class \
  | strings
```

```bash
unzip -p /tmp/ruoyi-admin-inspect.jar \
  BOOT-INF/classes/com/ruoyi/web/controller/enterprise/EnterpriseJdDocumentController.class \
  | strings
```

```bash
unzip -p /tmp/ruoyi-admin-inspect.jar \
  BOOT-INF/classes/com/ruoyi/web/controller/system/ConferenceLiveKitController.class \
  | strings
```

确认需要的信息已经输出并保存后，再清理临时文件：

```bash
rm -f /tmp/ruoyi-admin-inspect.jar
```

不要在提取之前执行删除命令。若只想一次性执行全部操作，可以把复制、三次提取、最后清理按上述顺序写在同一段 shell 脚本中。

### I.3 `strings` 的能力边界

`strings` 可以帮助发现 class 文件中保留的 URL 路径、字段名、错误消息、类名和部分字符串常量，但不能完整反编译 Java 字节码，也不能仅凭字符串顺序还原方法的控制流程。

如果字符串输出仍不足以判断模型调用、会话历史或工具调用，应继续查看相关 Service 类，或使用与当前 Java class 版本兼容的反编译工具分析目标类。整个过程无需更改正在运行的容器。

---

## 附录 J：三个关键控制器的真实接口线索（2026-10-29）

> 本节依据用户从生产服务器 `/app/ruoyi-admin.jar` 提取的三个 `.class` 文件字符串与注解常量整理。它能证明类、依赖类型、部分方法名和映射注解常量存在，但不是完整反编译结果。未由证据直接支持的业务语义均标记为待核实。

### J.1 企业 AI 助手控制器

类：`com/ruoyi/web/controller/enterprise/EnterpriseAssistantController`

依赖字段：

```text
service : com/ruoyi/enterprise/service/EnterpriseAssistantService
```

控制器基础路径由 `@RequestMapping` 字符串确认：

```text
/enterprise/assistant
```

从 `@GetMapping`、`@PostMapping`、`@DeleteMapping`、方法描述符与字符串常量中识别到以下接口：

| HTTP 方法 | 完整路径 | 当前可以确认的用途 |
|---|---|---|
| `GET` | `/enterprise/assistant/sessions` | 会话列表相关方法，参数中出现 `before` |
| `POST` | `/enterprise/assistant/sessions` | 创建会话，方法名 `create` |
| `GET` | `/enterprise/assistant/sessions/{id}/messages` | 查询会话消息 |
| `POST` | `/enterprise/assistant/sessions/{id}/runs` | 提交运行请求，方法参数包含 `SendRequest`，字段字符串包含 `content` 与 `requestId` |
| `GET` | `/enterprise/assistant/sessions/{id}/requests/{requestId}` | 查询指定请求相关信息；具体返回语义需要 Service 方法体确认 |
| `GET` | `/enterprise/assistant/runs/{id}/events` | SSE 事件接口，方法返回类型为 Spring MVC `SseEmitter` |
| `POST` | `/enterprise/assistant/runs/{id}/cancel` | 取消运行相关操作 |
| `DELETE` | `/enterprise/assistant/sessions/{id}` | 删除会话相关操作 |

SSE 方法的返回类型以及响应头常量明确包括：

```text
org/springframework/web/servlet/mvc/method/annotation/SseEmitter
text/event-stream;charset=UTF-8
Cache-Control: no-store
X-Accel-Buffering
```

这些常量支持以下结论：

1. 后端提供了基于 Spring MVC `SseEmitter` 的服务器推送事件接口。
2. 响应内容类型为 `text/event-stream;charset=UTF-8`。
3. 控制器中存在设置 `Cache-Control: no-store` 与 `X-Accel-Buffering` 的逻辑线索；仅凭字符串还不能确认每条分支和所有响应都如何设置该头。
4. 会话、运行任务、事件流、请求查询与取消操作分别有独立路径。
5. `SendRequest` 内部类中可见 `content` 与 `requestId` 字段访问器的字符串；请求完整字段、校验规则和 ID 生成方式仍需继续反编译确认。

#### 推荐的面试讲解

> 企业侧 AI 助手不是单个同步聊天接口，而是把会话管理与一次具体的运行任务分开处理。客户端先通过会话接口创建或读取对话，再提交 run 请求，随后可以通过独立的 SSE 事件接口接收服务端事件；另外还提供请求查询、任务取消和会话删除接口。这样的接口拆分有利于管理较长的模型生成过程，并为前端实时展示事件提供基础。至于模型调用、短期记忆、工具调用和取消信号的实际实现，需要继续看 `EnterpriseAssistantService` 的方法体，不能仅凭 Controller 断言。

### J.2 JD 文档控制器

类：`com/ruoyi/web/controller/enterprise/EnterpriseJdDocumentController`

依赖字段：

```text
documentService : com/ruoyi/enterprise/service/IJdDocumentService
```

基础路径与映射信息：

```text
@RequestMapping("/enterprise/jd")
@PostMapping(value = "/parse-document", consumes = "multipart/form-data")
```

因此可以确认接口：

```text
POST /enterprise/jd/parse-document
Content-Type: multipart/form-data
```

可见的参数与调用链线索：

- 控制器接收 `MultipartFile file`。
- 同时接收 `MultipartHttpServletRequest request`。
- 从 multipart request 获取多文件映射，并调用集合流式处理相关方法计算数量或检查文件集合。
- 使用当前用户 ID（`getUserId()`）。
- 调用 `IJdDocumentService.parseDocument(userId, file)`。
- 返回对象类型为 `JdDocumentDraft`，并通过公共 `success(...)` 响应包装返回。
- 类上存在 `@PreAuthorize("@ss.hasAnyRoles('biz_1,biz_2,biz_3')")` 相关注解常量，表明该接口有角色权限约束线索；最终授权行为还受 Spring Security 配置影响。

#### 可以确定的流程边界

`Controller → IJdDocumentService.parseDocument(userId, file) → JdDocumentDraft → success(...)`

这证明控制器将实际文档处理交给 Service，而不是在 Controller 中直接实现解析算法。当前不能仅凭类名断言它使用 OCR、PDFBox、Apache POI、LLM 结构化抽取或某一种具体文件解析库；这些要从 `IJdDocumentService` 的实现类及其依赖继续确认。

#### 推荐的面试讲解

> 企业端提供了独立的 JD 文档解析接口，使用 `multipart/form-data` 接收上传文件，并通过当前登录用户 ID 将请求关联到用户上下文。Controller 把文件交给 `IJdDocumentService.parseDocument`，返回 `JdDocumentDraft`，说明解析结果会以草稿对象形式返回给前端。解析器、字段抽取、异常恢复和草稿确认逻辑位于 Service 或其下游实现中，需要继续查看实现类后再介绍具体技术。

### J.3 LiveKit 会议控制器

类：`com/ruoyi/web/controller/system/ConferenceLiveKitController`

依赖字段：

```text
liveKitTokenService : com/ruoyi/system/service/ILiveKitTokenService
```

基础路径：

```text
/system/conference
```

接口映射：

```text
GET /system/conference/livekit-token/{sessionId}
```

控制器方法将 `sessionId` 作为路径变量，调用：

```text
ILiveKitTokenService.issueToken(userId, sessionId)
```

其中 `userId` 来自继承的 `getUserId()`，返回结果经 `success(...)` 包装。可确认 Token 签发职责委托给独立 Service，而不是直接在 Controller 中生成。

#### 尚待确认的 LiveKit 细节

- `issueToken` 如何校验用户是否有权进入指定 session；
- LiveKit room 名称如何确定；
- Token 的 identity、grant、过期时间如何设置；
- LiveKit API Key/Secret 从哪里读取；
- Flutter E-App 如何请求该接口并连接 LiveKit；
- Webhook、录制或 Egress 是否参与面试流程。

#### 推荐的面试讲解

> 后端提供了独立的 LiveKit Token 接口，客户端按面试 session ID 请求会议凭证。Controller 获取当前登录用户 ID，并把用户与 session ID 一并交给 `ILiveKitTokenService.issueToken`。这种分层将会议凭证签发和业务授权逻辑放在 Service 中，避免在控制器里直接暴露 Token 生成细节。具体的房间授权和 Token grant 需要继续查看 Service 实现。

### J.4 本轮证据能支持的整体调用链

```text
E-App / 企业端客户端
        |
        | 企业助手 HTTP API
        v
EnterpriseAssistantController
        |
        v
EnterpriseAssistantService
        |
        | 具体模型 API / 对话状态 / 工具执行
        | 尚待 Service 方法体确认
        v
模型与业务逻辑（待进一步核实）


企业端 JD 文档上传
        |
        | POST multipart/form-data
        v
EnterpriseJdDocumentController
        |
        v
IJdDocumentService.parseDocument(userId, file)
        |
        v
JdDocumentDraft


企业端视频面试
        |
        | GET /system/conference/livekit-token/{sessionId}
        v
ConferenceLiveKitController
        |
        v
ILiveKitTokenService.issueToken(userId, sessionId)
        |
        v
Token 响应（签发细节待核实）
```

### J.5 下一步：从 JAR 中继续定位 Service 实现类

如果临时 JAR 文件还在，先执行：

```bash
ls -lh /tmp/ruoyi-admin-inspect.jar
```

若文件已被删除，重新复制：

```bash
docker cp hr-backend:/app/ruoyi-admin.jar /tmp/ruoyi-admin-inspect.jar
```

再列出相关 Service 与实现类条目：

```bash
unzip -Z1 /tmp/ruoyi-admin-inspect.jar \
  | grep -Ei 'EnterpriseAssistantService|JdDocumentService|LiveKitTokenService|Assistant.*Service|Jd.*Service|LiveKit.*Service'
```

注意 Spring Boot JAR 可能只包含实现类 `.class`，接口与实现类名称也可能不同。找到候选条目后，针对确切路径使用 `unzip -p ... | strings` 进一步提取字符串。若字符串不足以还原方法体，再考虑兼容当前 class 版本的 Java 反编译工具；不要为此重启或修改生产容器。

处理完后再执行：

```bash
rm -f /tmp/ruoyi-admin-inspect.jar
```

### J.6 本轮核验结论

本轮已从真实运行 JAR 中确认三个关键 Controller 的服务依赖与主要接口：

- 企业 AI 助手：`EnterpriseAssistantService`，会话/运行任务/SSE 事件/取消等接口；
- JD 文档处理：`IJdDocumentService.parseDocument(...)`，上传后返回 `JdDocumentDraft`；
- LiveKit 会议：`ILiveKitTokenService.issueToken(userId, sessionId)`，提供独立 Token 接口。

这使项目文档可以将上述接口与分层关系写成已核实事实。但模型供应商、Prompt、短期记忆的具体存储、工具注册与执行、JD 文件解析库、LiveKit grant 与授权规则仍然需要 Service 实现或客户端源码支持，不能仅从 Controller 的字符串常量推断。

---

## 附录 K：Service 类名搜索无结果后的续查（2026-10-29）

### K.1 本轮结果的解释

用户执行：

```bash
unzip -Z1 /tmp/ruoyi-admin-inspect.jar \
  | grep -Ei 'EnterpriseAssistantService|JdDocumentService|LiveKitTokenService|Assistant.*Service|Jd.*Service|LiveKit.*Service'
```

终端没有输出匹配项。

这只能说明：当前 `unzip -Z1` 展开的**外层 Spring Boot JAR 条目名**没有匹配这些字符串。它不能直接证明对应 Service 不存在，因为：

1. 临时 JAR 可能已被删除、路径错误或文件不完整；
2. 接口或实现类可能使用了不同命名；
3. Spring Boot 可执行 JAR 的 `BOOT-INF/lib/*.jar` 是嵌套依赖包，`unzip -Z1` 只列出这些内层 JAR 的文件名，不会递归列出其内部 `.class`；
4. Controller 的字段类型字符串可以存在于 class 文件中，而具体类型可能由另一个模块/依赖提供。

此前成功提取的 Controller 字符串仍能证明这些类型引用存在：

- `com/ruoyi/enterprise/service/EnterpriseAssistantService`
- `com/ruoyi/enterprise/service/IJdDocumentService`
- `com/ruoyi/system/service/ILiveKitTokenService`

### K.2 先确认临时 JAR 仍存在

```bash
ls -lh /tmp/ruoyi-admin-inspect.jar
```

如果提示文件不存在，重新复制：

```bash
docker cp hr-backend:/app/ruoyi-admin.jar /tmp/ruoyi-admin-inspect.jar
```

然后验证归档可读：

```bash
unzip -t /tmp/ruoyi-admin-inspect.jar | tail -5
```

### K.3 用更宽的关键词查看外层归档

```bash
unzip -Z1 /tmp/ruoyi-admin-inspect.jar \
  | grep -Ei 'EnterpriseAssistant|JdDocument|LiveKitToken|enterprise/service|BOOT-INF/lib/.*(enterprise|ai|agent|ruoyi).*\.jar$' \
  | head -200
```

再确认应用类目录中是否存在相关 service package：

```bash
unzip -Z1 /tmp/ruoyi-admin-inspect.jar \
  | grep '^BOOT-INF/classes/com/ruoyi/enterprise/service/' \
  | head -200
```

以及列出内嵌依赖包名称：

```bash
unzip -Z1 /tmp/ruoyi-admin-inspect.jar \
  | grep '^BOOT-INF/lib/.*\.jar$' \
  | head -200
```

若 Service 类型位于 `BOOT-INF/lib` 中的某个嵌套 JAR，需要进一步检查该依赖包，而不是继续只搜索外层 JAR 的类条目。

### K.4 无需 Java 的嵌套 JAR 检查方法

如果 `unzip -Z1` 显示可疑的依赖包，例如：

```text
BOOT-INF/lib/some-module.jar
```

可先将该内嵌 JAR 单独提取到临时目录，再列出其内部条目。示例中的文件名必须替换成实际输出的路径：

```bash
mkdir -p /tmp/hr-jar-check
unzip -p /tmp/ruoyi-admin-inspect.jar 'BOOT-INF/lib/实际依赖包名.jar' \
  > /tmp/hr-jar-check/module.jar

unzip -Z1 /tmp/hr-jar-check/module.jar \
  | grep -Ei 'EnterpriseAssistantService|JdDocumentService|LiveKitTokenService|Assistant.*Service|Jd.*Service|LiveKit.*Service' \
  | head -200
```

不要原样使用 `实际依赖包名.jar` 占位符。确认完成后删除临时文件：

```bash
rm -rf /tmp/hr-jar-check
rm -f /tmp/ruoyi-admin-inspect.jar
```

以上步骤只读取和复制归档，不会修改或重启生产容器。

### K.5 进一步定位实现类的原则

- 如果找到 `EnterpriseAssistantService.class`，继续提取其字符串，并寻找它引用的其他 Service、模型客户端和存储类。
- 如果找到的是接口而没有实现类，继续搜索 `EnterpriseAssistantServiceImpl`、`DefaultEnterpriseAssistantService` 等候选命名，但不要假定实现类一定采用 `Impl` 后缀。
- 如果外层和嵌套 JAR 都没有匹配条目，需要重新检查 JAR 版本、打包模块和依赖来源；Controller 中存在接口类型字符串并不等于该类型一定作为独立条目出现在外层 JAR。
- `strings` 只能发现可读字符串，无法完整还原字节码控制流程。需要确认模型调用、短期记忆、工具执行或异常处理时，应对准确定位的目标类使用兼容的反编译工具，或取得匹配版本的源码。

### K.6 当前结论

本轮 Service 名称搜索没有结果，因此暂时没有新增 Service 方法级证据。此前确认的 Controller 路由、SSE 返回类型、JD 文档解析接口以及 LiveKit Token Service 调用线索仍然有效。下一步应先确认临时 JAR 文件存在，再检查外层包条目、服务包路径和内嵌依赖，避免把一次空搜索结果误判为功能不存在。

---

## 附录 L：完整 JAR 校验通过，但 Service 类尚未定位（2026-10-29）

### L.1 本轮输出结论

用户执行 `unzip -t /tmp/ruoyi-admin-inspect.jar`，返回 `No errors detected in compressed data`，说明外层 JAR 的压缩结构通过校验。

本轮外层 JAR 条目搜索结果包括：

- `BOOT-INF/classes/com/ruoyi/web/controller/enterprise/EnterpriseAssistantController.class`
- `BOOT-INF/classes/com/ruoyi/web/controller/enterprise/EnterpriseJdDocumentController.class`
- `BOOT-INF/lib/ruoyi-framework-3.9.2.jar`
- `BOOT-INF/lib/ruoyi-system-3.9.2.jar`
- `BOOT-INF/lib/ruoyi-quartz-3.9.2.jar`
- `BOOT-INF/lib/ruoyi-common-3.9.2.jar`
- `BOOT-INF/lib/ruoyi-generator-3.9.2.jar`

但以下搜索没有返回条目：

```text
BOOT-INF/classes/com/ruoyi/enterprise/service/
```

这意味着当前没有在外层 JAR 的主应用类目录中找到该 Service 包路径。**这不等于相关类不存在**：它们可能在其他模块、嵌套 JAR、不同的包路径中，或当前运行 JAR 与先前检查的构建版本/类布局存在差异。必须进一步扫描所有归档层级。

### L.2 用 Python 标准库扫描外层与全部嵌套 JAR

宿主机已有 `/usr/bin/python3`，不需要安装 Java 或修改运行容器。以下脚本只读取 JAR 中的文件名，不打印环境变量或配置文件内容，也不会执行归档内代码。

确保 `/tmp/ruoyi-admin-inspect.jar` 仍存在，然后执行：

```bash
python3 - <<'PY'
import io
import zipfile

path = "/tmp/ruoyi-admin-inspect.jar"
needles = (
    "EnterpriseAssistantService",
    "IJdDocumentService",
    "LiveKitTokenService",
    "EnterpriseAssistant",
    "JdDocumentService",
    "LiveKitToken",
    "com/ruoyi/enterprise/service/",
    "com/ruoyi/system/service/",
)

with zipfile.ZipFile(path) as outer:
    names = outer.namelist()
    print("=== Outer JAR matching entries ===")
    for name in names:
        if any(key.lower() in name.lower() for key in needles):
            print(name)

    print("\n=== Nested JAR matching entries ===")
    for name in names:
        if not (name.startswith("BOOT-INF/lib/") and name.endswith(".jar")):
            continue
        try:
            data = outer.read(name)
            with zipfile.ZipFile(io.BytesIO(data)) as nested:
                matches = [
                    item for item in nested.namelist()
                    if any(key.lower() in item.lower() for key in needles)
                ]
                if matches:
                    print(f"\n[{name}]")
                    for item in matches[:100]:
                        print(item)
        except (zipfile.BadZipFile, KeyError, OSError) as exc:
            print(f"[WARN] Could not inspect {name}: {type(exc).__name__}")
PY
```

此脚本会检查外层 JAR 及 `BOOT-INF/lib/*.jar` 中的类名和包路径。如果某个依赖包含目标类，会显示对应的内嵌 JAR 名称及条目。

### L.3 如果脚本依旧找不到 Service

如果外层和全部嵌套 JAR 都没有目标类，下一步应：

1. 列出主应用的相关类：`unzip -Z1 /tmp/ruoyi-admin-inspect.jar | grep '^BOOT-INF/classes/.*\.class$' | grep -Ei 'enterprise|assistant|jd|document|conference|livekit|agent|chat|memory' | head -300`
2. 对比容器当前实际运行的 JAR 与本次复制文件的时间、大小及 SHA-256（例如 `sha256sum /tmp/ruoyi-admin-inspect.jar`），避免分析错版本。
3. 重新检查所有内嵌 JAR 中是否存在相关 `com/ruoyi/enterprise/` 包；不要只检查 `ruoyi-system` 一个依赖。
4. 若确实没有相应类型，需考虑构建产物不一致、类加载方式特殊或控制器在当前运行路径下未被加载等情况；不能只靠 Controller 的字符串常量断言 Service 实现完整可用。

### L.4 当前证据边界

- **已确认：** 外层 JAR 压缩结构通过校验；企业助手、JD 文档 Controller 类存在；Controller 字符串中引用了相应 Service 类型；外层包包含多个 RuoYi 模块依赖。
- **未确认：** 三个 Service 类型的实际归档位置、实现类名称、模型调用、会话记忆与工具执行细节。
- **下一步：** 先运行 L.2 的递归归档扫描，并分享输出；随后再针对确切的嵌套 JAR 定位 Service 类，不需要重新启动服务。

---

## 附录 M：递归扫描发现 `ruoyi-system` 中的企业业务包（2026-10-29）

### M.1 本轮已确认的归档证据

递归扫描外层 Spring Boot JAR 及 `BOOT-INF/lib/*.jar` 后，发现以下条目位于 `BOOT-INF/lib/ruoyi-system-3.9.2.jar` 内：

```text
com/ruoyi/enterprise/service/
com/ruoyi/enterprise/service/jd/
com/ruoyi/enterprise/service/screening/
com/ruoyi/enterprise/service/impl/
mapper/enterprise/EnterpriseAssistantMapper.xml
com/ruoyi/system/service/ILiveKitTokenService.class
```

这解释了为什么在外层 `BOOT-INF/classes/com/ruoyi/enterprise/service/` 下搜索不到类：业务服务包位于嵌套模块 JAR 中，而不是外层应用类目录中。

扫描还发现 APP AI 相关类：

```text
com/ruoyi/system/service/app/ai/AgentModelClient.class
com/ruoyi/system/service/app/ai/AgentTools.class
com/ruoyi/system/service/app/ai/AppAiService.class
com/ruoyi/system/service/app/ai/QdrantMemoryIndex.class
com/ruoyi/system/service/app/ai/AppAiMemoryService.class
com/ruoyi/system/service/app/ai/AppAiLongTermMemoryService.class
com/ruoyi/system/service/app/ai/AppAiLongTermMemoryWorker.class
```

这些类名可作为后续代码追踪线索，但包名明确属于 `system/service/app/ai`。在没有看到企业助手 Service 的直接调用之前，不能把它们写成企业助手 Agent 的确定实现。

### M.2 先提取嵌套模块 JAR

服务器已有外层临时文件 `/tmp/ruoyi-admin-inspect.jar` 时，执行：

```bash
unzip -p /tmp/ruoyi-admin-inspect.jar \
  BOOT-INF/lib/ruoyi-system-3.9.2.jar \
  > /tmp/ruoyi-system-inspect.jar

ls -lh /tmp/ruoyi-system-inspect.jar
unzip -t /tmp/ruoyi-system-inspect.jar | tail -5
```

这只会把嵌套 JAR 复制到临时文件，不会更改运行中的容器或原始 JAR。

### M.3 列出全部企业 Service 类

```bash
unzip -Z1 /tmp/ruoyi-system-inspect.jar \
  | grep '^com/ruoyi/enterprise/service/.*\.class$' \
  | sort
```

重点筛选助手、JD、筛选、Agent 和模型相关类：

```bash
unzip -Z1 /tmp/ruoyi-system-inspect.jar \
  | grep -Ei 'assistant|jd|document|screening|agent|model|tool|memory|chat|livekit|conference' \
  | grep '\.class$' \
  | sort \
  | head -300
```

检查 LiveKit Token 服务接口和实现类：

```bash
unzip -Z1 /tmp/ruoyi-system-inspect.jar \
  | grep -Ei 'LiveKitTokenService|LiveKit.*Impl|Conference.*Service|conference/.*\.class$' \
  | sort
```

### M.4 从真实类名中提取字符串

先从 M.3 的输出中找到实际的类路径，再将路径替换到以下命令。不要猜测类名：

```bash
unzip -p /tmp/ruoyi-system-inspect.jar \
  'com/ruoyi/enterprise/service/实际类路径.class' \
  | strings
```

优先检查以下内容：

- 企业助手 Service 接口和实现类；
- JD 文档 Service 及实现类；
- 企业助手 Mapper 与相关 Entity/DTO；
- LiveKit Token Service 实现类；
- Service 引用的模型 HTTP 客户端、工具注册类、记忆管理类。

如果类文件路径中带有 `$`（内部类），在 shell 中用单引号包住路径，避免特殊字符被 shell 解释。

### M.5 读取 Mapper XML 的 SQL 线索

```bash
unzip -p /tmp/ruoyi-system-inspect.jar \
  mapper/enterprise/EnterpriseAssistantMapper.xml \
  | head -240
```

该 XML 可能揭示企业助手相关的数据库查询、会话或消息实体映射。它只能说明持久化映射，不足以单独证明模型调用和短期记忆机制。

### M.6 当前结论与边界

- **已确认：** 企业业务 Service 包目录和企业助手 Mapper XML 位于 `ruoyi-system-3.9.2.jar`；LiveKit Token Service 接口也位于该模块。
- **已发现但归属尚未确认：** APP AI 包中存在模型客户端、工具、Qdrant 记忆索引与 AI 服务类。
- **待核实：** 企业助手 Service 的具体类名、实现方法、模型提供商、短期记忆保存方式、工具调用循环、JD 文档具体解析链和 LiveKit Token 的授权细节。
- **下一步：** 先执行 M.3 的两个类名清单命令，再根据实际结果提取具体 Service 类，避免把 APP AI 代码误写成企业助手的实现。

---

## 附录 N：核心 Service 类已定位，进入实现链路分析（2026-10-29）

### N.1 本轮实际扫描到的类

从 `/tmp/ruoyi-system-inspect.jar` 的类条目清单中，已确认存在以下类：

#### 企业 AI 助手

```text
com/ruoyi/enterprise/service/EnterpriseAssistantService.class
com/ruoyi/enterprise/service/EnterpriseAssistantService$LiveRun.class
com/ruoyi/enterprise/mapper/EnterpriseAssistantMapper.class
mapper/enterprise/EnterpriseAssistantMapper.xml
```

`EnterpriseAssistantService` 与此前 Controller 字段类型完全一致，是接下来应优先检查的核心类。`LiveRun` 是内部类，可能承载运行期数据，但不能仅凭名称断言其字段和职责。

#### JD 文档识别与结构化

```text
com/ruoyi/enterprise/service/IJdDocumentService.class
com/ruoyi/enterprise/service/impl/JdDocumentServiceImpl.class
com/ruoyi/enterprise/service/jd/JdAiStructurer.class
com/ruoyi/enterprise/domain/JdDocumentDraft.class
```

其中 `JdDocumentServiceImpl` 是 `IJdDocumentService` 的实现类候选，`JdAiStructurer` 从类名看与 AI 结构化相关。实际文件解析器、模型调用和字段映射仍需检查方法体与依赖。

#### 岗位筛选 / AI 评估

```text
com/ruoyi/enterprise/service/impl/ScreeningServiceImpl.class
com/ruoyi/enterprise/service/screening/ScreeningAiEvaluator.class
com/ruoyi/enterprise/mapper/ScreeningMapper.class
```

这些类是继续追踪筛选业务与 AI 评估的优先目标，但不能仅凭名称断言岗位适配度算法、权重或提示词内容。

#### LiveKit 会议

```text
com/ruoyi/system/service/ILiveKitTokenService.class
com/ruoyi/system/service/impl/LiveKitTokenServiceImpl.class
com/ruoyi/system/service/impl/ConferenceServiceImpl.class
com/ruoyi/system/service/ILiveKitEgressService.class
com/ruoyi/system/service/impl/LiveKitEgressServiceImpl.class
```

这些类可以用于追踪 Token 签发、会议业务以及 Egress 相关实现。是否在当前视频面试流程中使用录制或 Egress，仍需检查调用关系。

#### APP AI Agent 相关类（与企业助手的关系待确认）

```text
com/ruoyi/system/service/app/ai/AgentModelClient.class
com/ruoyi/system/service/app/ai/AgentTools.class
com/ruoyi/system/service/app/ai/AppAiService.class
com/ruoyi/system/service/app/ai/AppAiMemoryService.class
com/ruoyi/system/service/app/ai/AppAiLongTermMemoryService.class
com/ruoyi/system/service/app/ai/QdrantMemoryIndex.class
```

这些类属于 `system/service/app/ai` 包。从命名上可作为模型客户端、工具、对话记忆与向量检索的研究线索，但在找到企业助手 Service 对它们的引用前，不能把它们写成企业助手的确定实现。

### N.2 下一步：一次性提取五个优先类

确保 `/tmp/ruoyi-system-inspect.jar` 仍存在。直接在服务器 SSH shell 中运行：

```bash
echo '========== EnterpriseAssistantService =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/enterprise/service/EnterpriseAssistantService.class | strings

echo '========== EnterpriseAssistantService$LiveRun =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  'com/ruoyi/enterprise/service/EnterpriseAssistantService$LiveRun.class' | strings

echo '========== JdDocumentServiceImpl =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/enterprise/service/impl/JdDocumentServiceImpl.class | strings

echo '========== JdAiStructurer =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/enterprise/service/jd/JdAiStructurer.class | strings

echo '========== ScreeningAiEvaluator =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/enterprise/service/screening/ScreeningAiEvaluator.class | strings
```

输出可能比较长。如果终端滚动内容不便复制，可以将输出保存为文本文件，再查看文件：

```bash
{
  echo '========== EnterpriseAssistantService =========='
  unzip -p /tmp/ruoyi-system-inspect.jar \
    com/ruoyi/enterprise/service/EnterpriseAssistantService.class | strings

  echo '========== EnterpriseAssistantService$LiveRun =========='
  unzip -p /tmp/ruoyi-system-inspect.jar \
    'com/ruoyi/enterprise/service/EnterpriseAssistantService$LiveRun.class' | strings

  echo '========== JdDocumentServiceImpl =========='
  unzip -p /tmp/ruoyi-system-inspect.jar \
    com/ruoyi/enterprise/service/impl/JdDocumentServiceImpl.class | strings

  echo '========== JdAiStructurer =========='
  unzip -p /tmp/ruoyi-system-inspect.jar \
    com/ruoyi/enterprise/service/jd/JdAiStructurer.class | strings

  echo '========== ScreeningAiEvaluator =========='
  unzip -p /tmp/ruoyi-system-inspect.jar \
    com/ruoyi/enterprise/service/screening/ScreeningAiEvaluator.class | strings
} > /tmp/eapp-core-service-strings.txt

wc -l /tmp/eapp-core-service-strings.txt
cat /tmp/eapp-core-service-strings.txt
```

请注意，输出里可能包含业务配置键或内部路径。分享之前不要复制 API 密钥、访问令牌、密码、数据库连接凭据或其他秘密值。

### N.3 再检查 LiveKit Token 实现

```bash
echo '========== LiveKitTokenServiceImpl =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/system/service/impl/LiveKitTokenServiceImpl.class | strings

echo '========== ConferenceServiceImpl =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/system/service/impl/ConferenceServiceImpl.class | strings
```

重点寻找房间名、identity、grant、过期时间、配置属性和业务授权相关字符串。字符串线索只能辅助判断，不能完整替代方法体分析。

### N.4 再核对 AgentModelClient 与 AgentTools

如果需要明确系统中是否实现了模型 API 调用与工具执行，可提取：

```bash
echo '========== AgentModelClient =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/system/service/app/ai/AgentModelClient.class | strings

echo '========== AgentTools =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/system/service/app/ai/AgentTools.class | strings

echo '========== AppAiService =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/system/service/app/ai/AppAiService.class | strings
```

接下来还应从 `EnterpriseAssistantService` 的字段与方法引用中确认它是否直接调用这些类。若没有直接调用证据，应将企业助手与 APP AI Agent 分开描述。

### N.5 本轮结论

- **已确认类条目存在：** 企业助手 Service、JD 文档 Service 实现候选、JD AI 结构化类、筛选 AI 评估类、LiveKit Token Service 实现类。
- **尚未确认：** 模型供应商与请求协议、Agent 工具调用循环、短期记忆具体存储方式、岗位适配度算法细节、JD 文件解析器、LiveKit Token 的具体权限字段。
- **建议顺序：** 先看 `EnterpriseAssistantService` 和 `LiveRun`，再看 `JdDocumentServiceImpl` 与 `JdAiStructurer`，然后看 `ScreeningAiEvaluator`，最后核对 LiveKit Token 实现。
- **安全提醒：** 以上操作只读取嵌套 JAR 内的 class 字节码，不需要修改、重启或重新部署线上服务。

---

## 附录 O：核心 Service 字符串分析结果（2026-10-29）

本节根据服务器输出的 `/tmp/eapp-core-service-strings.txt` 整理。`strings` 能显示类常量、方法名、字段名和部分字符串，但不等同于完整反编译；涉及精确执行顺序的结论均应继续通过方法体或调用关系核实。

### O.1 企业 AI 助手：已确认的实现线索

类：`com.ruoyi.enterprise.service.EnterpriseAssistantService`

**已观察到的依赖和机制：**

- `EnterpriseAssistantMapper`：企业助手会话、消息和运行记录相关的数据访问入口。
- `DashboardMapper`：存在 `selectCompanyIdByUser`，用于根据用户解析企业 ID。
- `AgentModelClient`：企业助手直接依赖共享模型客户端。
- `TransactionTemplate`：使用编程式事务。
- `ThreadPoolExecutor`、`ArrayBlockingQueue`：存在专用任务执行线程池及有界队列相关实现。
- `ScheduledExecutorService`：存在定时任务执行器，类中还有 SSE keepalive / heartbeat 相关线索。
- `ConcurrentHashMap`、`AtomicBoolean`、`AtomicReference`、`Future`：用于并发运行状态、取消标记、任务引用等管理。
- `SseEmitter`：服务端通过 SSE 向客户端发送事件。
- `@PreDestroy` 与 `shutdownNow`：存在服务关闭时清理线程资源的实现线索。

可见方法/符号包括 `sessions`、`create`、`messages`、`request`、`start`、`events`、`cancel`、`delete`、`lockSession`、`updateRun`、`insertMessage`、`createSession`、`finish`、`snapshot`、`touch` 等。

**当前可支持的结论：** 企业助手不仅包含模型调用，还实现了会话管理、运行任务管理、异步执行和 SSE 事件处理。确切的数据库字段、每个方法的完整逻辑以及事务边界仍需查看 Mapper XML 或反编译方法体。

### O.2 Agent 工具调用：出现了直接证据

`EnterpriseAssistantService` 中出现以下模型交互符号：

```text
AgentModelClient.complete(...)
message
tool_calls
function
name
arguments
tool_call_id
tools
calls
step
TOOL_LIMIT
STEP_LIMIT
```

还发现一段函数工具定义，其名称与参数如下：

#### `list_company_jobs`

```json
{
  "type": "function",
  "function": {
    "name": "list_company_jobs",
    "parameters": {
      "type": "object",
      "properties": {
        "keyword": {
          "type": "string"
        }
      }
    }
  }
}
```

用途：从名称和参数可确认这是一个查询企业岗位列表的工具，支持 `keyword` 字符串参数。

#### `get_company_job`

```json
{
  "type": "function",
  "function": {
    "name": "get_company_job",
    "parameters": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer"
        }
      },
      "required": ["id"]
    }
  }
}
```

用途：从名称和参数可确认这是一个根据岗位 ID 查询岗位详情的工具。

这两段工具定义采用常见的 function-tool schema 形态。结合 `tool_calls`、`tool_call_id` 和 `STEP_LIMIT` 等符号，可以确认系统有模型发起工具调用的实现线索，而不只是简单的单次文本问答。具体请求协议、工具结果如何写回 messages、循环退出条件和限制值仍需进一步检查方法体。

### O.3 企业助手的 SSE 与任务状态

类和内部类中出现以下线索：

```text
SseEmitter
event
data
send
keepalive
heartbeat
onCompletion
onTimeout
onError
cancel
finished
progress
deadlineNanos
future
QUEUE_TIMEOUT
OUTPUT_LIMIT
```

因此可以确认服务具备 SSE 事件推送、连接生命周期回调、任务取消、进度/完成状态、截止时间及输出/队列限制相关实现线索。

建议把“模型生成”与“前端实时展示”分开理解：

1. 后端任务线程负责执行 AI 工作。
2. SSE 连接负责把运行事件交给前端。
3. 连接断开、超时或取消需要与后台任务状态协调。

以上是基于符号的架构总结；具体 SSE event 名称、前端收到的 JSON 结构、心跳间隔、队列大小和输出上限都还不能仅凭 `strings` 确定。

### O.4 JD 文档处理：文件解析与 AI 结构化是两个步骤

类：`JdDocumentServiceImpl`

观察到的主要依赖：

```text
ResumePdfParser
ResumePdfProperties
JdAiProperties
JdAiStructurer
DashboardMapper
Semaphore
MultipartFile
```

可见流程线索：

1. `requireEnterprise`：先校验企业身份或企业访问权限。
2. 获取文件扩展名、大小与 Content-Type，并进行验证。
3. 使用 `Semaphore` 和 `getMaxConcurrentRequests` 限制并发请求。
4. 读取受大小限制的文件内容。
5. PDF 分支调用 `ResumePdfParser.parse(...)`，结果包含 `text`、`method`、`warnings` 等字段。
6. DOCX 分支引用 Apache POI 的 `XWPFDocument` 和 `XWPFWordExtractor`，调用 `getText()` 获取文本。
7. 取得文本后调用 `JdAiStructurer.structure(...)`，把自然语言 JD 转成结构化草稿。
8. 将解析警告与结构化结果中的 warnings 汇总。

类字符串中还出现 `getMaxPages`、`getMaxInputChars`、`MAX_ZIP_ENTRIES`、`MAX_UNCOMPRESSED_BYTES`、`MAX_PROPERTIES_BYTES`、`20MB` 等限制或常量线索，以及禁止 DOCTYPE、限制外部 DTD/Schema 的 XML 解析安全设置。

注意：类字符串中能看到 `.doc`、`.docx`、`.pdf` 等扩展名判断，但本轮尚未完整验证旧版 Word `.doc` 的实际解析分支。不要在项目介绍中直接承诺所有扩展名均能成功解析，建议后续检查 `parseDocument` 的完整字节码或进行真实文件测试。

### O.5 JD AI 结构化：输出字段和防护措施

类：`JdAiStructurer`

该类直接依赖 `AgentModelClient` 和 `JdAiProperties`，并使用 `Semaphore` 控制并发。可见结构化字段包括：

- 基本信息：`title`、`dept`、`city`、`experience`、`education`、`jobType`
- 薪资：`salaryMin`、`salaryMax`
- 文本描述：`summary`、`responsibilities`、`requirements`、`softRequirements`
- 技能：`skills`，单项包含 `name` 与 `required`
- 解析提示：`warnings`

还发现以下 JSON 校验相关设置：

- `STRICT_DUPLICATE_DETECTION`
- `FAIL_ON_TRAILING_TOKENS`
- 对 JSON 对象类型、字段集合和字段值进行检查
- 处理 Markdown JSON 代码围栏的线索
- `CALL_TIMEOUT_SECONDS`、`MAX_TOKENS`、`MODEL_OUTPUT_LIMIT`、`MODEL_STREAM_INCOMPLETE` 等调用限制或错误标识
- 对错误日志中的 API Key、Bearer Token、JWT 风格字符串、邮箱、手机号和身份证号进行脱敏的规则字符串

因此可将此模块描述为：调用配置的模型，将 JD 文本结构化为业务草稿，再对模型输出进行 JSON 解析、字段约束和数据校验，并返回可供后续业务确认的结果。具体 prompt 内容和全部校验边界应继续通过反编译核实。

### O.6 候选人 AI 评估：六个维度和可追溯证据

类：`ScreeningAiEvaluator`

观察到的评估维度：

```text
skillMatch
projectMatch
educationMatch
industryMatch
researchMatch
awardMatch
```

每个维度的输出结构包含 `score` 和 `evidence`；总结果还出现 `recommendation`、`totalScore`、`evidenceCoverage`、`sourceWarnings` 等字段。

类字符串显示分数区间标签：

```text
0-39
40-59
60-79
80-100
```

还出现以下策略标识：

```text
evaluationStrategy = independent-v1
scoringPolicy = missing-zero-v1
WEIGHTS
weights
weighted
covered
```

可支持的结论：

1. 候选人评估使用六个维度组织模型输出。
2. 每个维度不仅有分数，还设计了证据字段。
3. 实现中存在维度权重、加权汇总、证据覆盖率和推荐结果相关逻辑。
4. 存在 `missing-zero-v1` 策略标识，提示缺失分数的处理与默认策略有关；其具体作用需结合方法体确认，不能仅凭名字直接断言所有缺失值一定按零分处理。
5. 结果中保留来源警告的线索，可用于提示资料不足或输入质量问题。

`deepseek-chat` 字符串出现在该评估器中，但实际使用哪个模型仍由 `ModelProvider` 配置和 `AgentModelClient.resolve()` 的运行逻辑决定。不要把单个默认模型名当成所有环境的固定模型。

### O.7 本轮整体业务链路

根据已看到的类和符号，企业端 AI 相关功能可初步分成三个独立业务链：

```text
企业 AI 助手
Controller
  -> EnterpriseAssistantService
  -> AgentModelClient
  -> 模型回复 / 工具调用
  -> 查询企业岗位数据
  -> 继续模型处理
  -> 持久化运行结果并通过 SSE 推送

JD 文档结构化
EnterpriseJdDocumentController
  -> JdDocumentServiceImpl
  -> 文件验证与 PDF/DOCX 文本提取
  -> JdAiStructurer
  -> AgentModelClient
  -> JSON 解码与字段校验
  -> JD 草稿 + warnings

候选人 AI 评估
ScreeningServiceImpl（调用关系仍需确认）
  -> ScreeningAiEvaluator
  -> AgentModelClient
  -> 六维评分与 evidence
  -> 加权结果 / recommendation / evidenceCoverage
```

第一条链路已经能从 `EnterpriseAssistantService` 的符号中直接看到工具调用线索；第二条链路的文件解析与结构化依赖较明确；第三条链路中评估器的输出结构已明确，但调用方和结果持久化方式仍需检查。

### O.8 下一步：检查模型客户端与 SQL 映射

下一轮建议先提取 `AgentModelClient`，因为企业助手、JD 结构化和候选人评估都依赖它。

```bash
echo '========== AgentModelClient =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/system/service/app/ai/AgentModelClient.class | strings

echo '========== AgentModelClient$Call =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  'com/ruoyi/system/service/app/ai/AgentModelClient$Call.class' | strings

echo '========== AgentModelClient$Reply =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  'com/ruoyi/system/service/app/ai/AgentModelClient$Reply.class' | strings

echo '========== ModelProvider =========='
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/system/domain/ModelProvider.class | strings
```

随后检查企业助手 Mapper XML 是否在当前嵌套 JAR 中：

```bash
unzip -Z1 /tmp/ruoyi-system-inspect.jar \
  | grep -Ei 'EnterpriseAssistantMapper|enterprise.*assistant.*xml'
```

如果 XML 存在，再提取它：

```bash
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/enterprise/mapper/EnterpriseAssistantMapper.xml
```

若路径不同，以 `unzip -Z1` 返回的真实路径为准。

这些结果可以继续确认模型请求/响应结构、配置模型选择、消息表操作以及会话数据的持久化字段。

---

## 附录 P：AgentModelClient 模型调用层分析（2026-10-29）

本节依据服务器对 `AgentModelClient.class`、内部类 `Call`、`Reply` 和 `ModelProvider.class` 执行 `strings` 的结果整理。由于这不是完整 Java 源码或反编译结果，方法内部的精确执行顺序、默认参数值和过滤条件仍应以字节码或源代码为准。

### P.1 关键结论

`com.ruoyi.system.service.app.ai.AgentModelClient` 是系统统一的大模型调用客户端。已发现的符号表明，它使用 Java 原生 `java.net.http.HttpClient` 构建 HTTP 请求，并处理流式模型响应、文本增量、工具调用增量、调用超时和输出限制。

结合前面 `EnterpriseAssistantService` 中的 `tool_calls`、`tool_call_id`、工具定义及执行循环相关符号，可以初步将系统分为两层：

- **模型通信层：** `AgentModelClient` 负责构造请求、访问模型 API、解析流式响应并返回模型消息。
- **Agent 编排层：** `EnterpriseAssistantService` 负责组织企业助手上下文、识别模型要求的工具、执行本地业务工具、把工具结果交回模型并管理整个运行过程。

因此，不能把“模型发起工具调用”和“Java 执行工具”混为一谈：模型返回的是结构化的工具调用意图；实际业务方法仍由服务端 Java 代码执行。

### P.2 模型供应商解析与配置

`AgentModelClient` 依赖 `IModelProviderService`，调用 `selectModelProviderList(...)` 获取模型供应商列表，再经过过滤并 `findFirst()` 选取一个配置。`resolve()` 中具体使用什么条件过滤，仍需进一步检查对应 lambda 的字节码。

`ModelProvider` 实体包含以下字段：

| 字段 | 含义 |
|---|---|
| `mppId` | 供应商配置 ID |
| `mppName` | 供应商名称 |
| `mppApiUrl` | API 地址 |
| `mppApiKey` | API 密钥 |
| `mppModelName` | 模型名称 |
| `mppParamsJson` | 模型参数 JSON |
| `mppStatus` | 配置状态 |
| `mppCreatedAt` / `mppUpdatedAt` | 创建与更新时间 |

客户端字符串中可见以下回退值：

- API URL：`https://api.deepseek.com/chat/completions`
- 模型名：`deepseek-chat`

这只能说明代码中存在回退默认值，**不能证明当前生产环境一定使用 DeepSeek 或该默认模型**。运行时实际值需要结合供应商配置和 `resolve()` 的逻辑确认。

### P.3 HTTP 请求构建

已观察到以下 Java 类和请求字段：

```text
java.net.http.HttpClient
HttpRequest
HttpResponse
BodyPublishers.ofString
BodyHandlers.ofInputStream
Content-Type: application/json
Authorization: Bearer ...
POST
connectTimeout
timeout
followRedirects(NEVER)
```

据此可确认客户端采用 HTTP POST 方式发送 JSON 请求，并设置 JSON 内容类型及 Bearer 认证头。客户端还设置连接超时、请求超时，并将 HTTP 重定向策略设为 `NEVER`。

可见请求对象字段包括：

```text
model
messages
tools
tool_choice
stream_options
include_usage
temperature
max_tokens
```

其中 `tool_choice` 的可见值为 `auto`，`stream_options` 中出现 `include_usage`。这些字段符合 OpenAI 风格聊天补全 API 的请求形态。具体请求 JSON 的完整内容以及 `stream` 字段、温度、最大 token 等最终值，仍应通过 `javap -c -p` 或反编译源码确认。

### P.4 流式响应解析

以下字符串共同表明客户端具有流式响应解析逻辑：

```text
BodyHandlers.ofInputStream
BufferedReader
InputStreamReader
readLine
readStream
data:
[DONE]
choices
delta
content
finish_reason
usage
total_tokens
```

可确认的处理线索包括：

1. 将 HTTP 响应体作为 `InputStream` 读取。
2. 使用 UTF-8 字符集和 `BufferedReader` 逐行读取。
3. 识别以 `data:` 开头的事件数据，并处理 `[DONE]` 结束标志。
4. 从响应 JSON 中读取 `choices`、`delta`、`content` 和 `finish_reason` 等字段。
5. 处理 `usage.total_tokens`，并将 token 统计放入返回结果的相关数据结构。

这意味着模型响应可以分段到达，客户端需要逐段解析，而不是只等待一个完整 JSON 文本响应。SSE 流式协议中的每个数据片段也不一定是完整的句子或完整的工具调用对象。

### P.5 流式工具调用的组装

客户端中出现以下符号：

```text
tool_calls
index
computeIfAbsent
AgentModelClient$Call
name
function
arguments
TOOL_CALL_LIMIT
TOOL_ARGUMENT_LIMIT
INVALID_TOOL_CALL
```

这表明客户端会处理分段返回的工具调用，并使用工具调用的 `index` 将同一调用的多个增量归并到对应的 `Call` 对象中；`Call` 对象中可见 `name` 和 `arguments` 字段。

这一步非常重要，因为模型在流式模式下可能先返回某个工具调用的部分信息，再陆续返回函数名或 JSON 参数的其他片段。服务端必须把片段组合后再进行解析和执行，而不能把每个 chunk 都当成完整调用。

结合 `EnterpriseAssistantService` 已发现的 `tool_calls`、`function`、`arguments` 和 `tool_call_id` 处理逻辑，初步链路如下：

```text
EnterpriseAssistantService 构造 messages 和 tools
        |
        v
AgentModelClient 发送模型请求
        |
        v
逐段读取流式响应
        |
        +---- 文本增量：累积内容，并通过回调传递增量
        |
        +---- tool_calls 增量：按 index 组装 name / arguments
        |
        v
AgentModelClient 返回 Reply(message, tokens)
        |
        v
EnterpriseAssistantService 检查 message.tool_calls
        |
        v
按工具名称分发到对应 Java 业务方法
        |
        v
将工具结果及 tool_call_id 关联后交回模型继续处理
```

最后三步的精确消息格式和循环条件，应继续通过 `EnterpriseAssistantService` 的 `start` 方法字节码确认。

### P.6 超时、输出限制与异常

客户端中可见下列限制或异常标识：

```text
MODEL_TIMEOUT
MODEL_STREAM_ERROR
MODEL_RESPONSE_LIMIT
TOOL_CALL_LIMIT
TOOL_ARGUMENT_LIMIT
MODEL_STREAM_INCOMPLETE
INVALID_TOOL_CALL
MODEL_HTTP_
MAX_OUTPUT_TOKENS
MAX_OUTPUT_CHARS
OutputLimitException
```

这些符号表明实现考虑了模型调用超时、HTTP 错误、流读取失败或不完整、模型输出超限，以及工具调用数量和参数长度的限制。另有 `ScheduledExecutorService`、`ScheduledFuture.cancel(...)` 和 `deadlineNanos` 等符号，表明客户端存在基于截止时间的超时控制线索。

本轮无法从 `strings` 确认这些常量的具体数值、不同异常对应的 HTTP 状态码映射，以及超时任务在所有异常分支下的清理行为。

### P.7 Reply 返回结构

`AgentModelClient$Reply` 是 Java `Record`，可见两个字段：

```text
message: JsonNode
tokens: int
```

因此调用方得到的主要结果是模型消息 JSON 以及 token 数量。对于普通回复，`message` 可包含文本内容；对于工具调用场景，消息中还可能包含 `tool_calls`。这与上层 `EnterpriseAssistantService` 对 `message` 和 `tool_calls` 的读取线索相吻合。

### P.8 是否使用 LangChain4j

在本轮检查的 `AgentModelClient` 字符串中，直接可见的底层 HTTP 实现是 Java 原生 `HttpClient`，并且客户端自己实现了流式解析与工具调用增量组装。这支持以下谨慎结论：

> 至少在该模型调用层，项目采用了自定义客户端实现，而不是把所有模型通信和流式解析完全交给一个 Agent 框架。

但仅凭这个类不能证明整个项目从未使用 LangChain4j 或其他框架；如需确认全项目依赖，应继续检查 `BOOT-INF/lib` 中的 JAR 列表、Maven/Gradle 依赖或其他模块的字节码。

### P.9 安全检查建议

`ModelProvider` 包含 `mppApiKey` 字段，客户端会将该值放入 Bearer 认证头。后续建议检查：

1. 供应商配置接口返回对象是否会把 API Key 原文暴露给前端。
2. API Key 是否被写入请求日志、异常日志或调试输出。
3. 供应商配置的数据库访问权限与密钥更新流程是否受控。
4. API 地址是否始终限制为可信 HTTPS 地址，避免服务端请求伪造或意外向不可信地址发送凭据。

这些是根据现有字段和 HTTP 调用方式提出的安全审查项目，不代表已经确认系统存在上述漏洞。

### P.10 下一步：反编译关键方法体

如果服务器安装了 JDK 的 `javap`，可以直接查看字节码及私有方法：

```bash
javap -classpath /tmp/ruoyi-system-inspect.jar \
  -p -c -constants \
  com.ruoyi.system.service.app.ai.AgentModelClient \
  > /tmp/AgentModelClient-javap.txt

javap -classpath /tmp/ruoyi-system-inspect.jar \
  -p -c -constants \
  com.ruoyi.enterprise.service.EnterpriseAssistantService \
  > /tmp/EnterpriseAssistantService-javap.txt
```

然后查看模型客户端中与请求构建、流解析和供应商解析有关的部分：

```bash
grep -nE 'resolve\\(|complete\\(|readStream\\(|lambda\\$resolve|lambda\\$readStream|lambda\\$complete' \
  /tmp/AgentModelClient-javap.txt
```

以及企业助手中的 Agent 主循环与工具分发部分：

```bash
grep -nE 'start\\(|complete\\(|tool_calls|tool_call_id|STEP_LIMIT|TOOL_LIMIT|insertMessage|updateRun' \
  /tmp/EnterpriseAssistantService-javap.txt
```

`javap` 输出会比 `strings` 更接近实际控制流；若需要精确理解局部变量和条件分支，可以再用 CFR 等 Java 反编译器生成近似源码。反编译结果仍应视为字节码的重建表示，而非原始源代码。



---

## 附录 Q：无侵入式核验结果——AgentModelClient 与企业助手 SQL（2026-10-29）

> 本节根据服务器上已有的 `/tmp/ruoyi-system-inspect.jar` 执行 `unzip -p ... | strings` 的输出，以及从同一 JAR 中读取的 `EnterpriseAssistantMapper.xml` 整理。全程只读，不安装软件、不拉取镜像、不重启或修改任何线上容器。
>
> **证据边界：** `strings` 能确认类中存在的符号、字段名和错误标识，但不能完整还原 `if` 分支、循环边界、配置过滤条件或所有异常分支。以下将“确认的结构”和“仍待验证的细节”分开表述。

### Q.1 本轮新增的结论

1. `AgentModelClient` 使用 Java 原生 `java.net.http.HttpClient`，构造 JSON POST 请求，并以 `InputStream` 方式读取响应体。
2. 模型调用层处理流式响应数据、文本增量、工具调用增量、token 统计、超时和输出限制。
3. `AgentModelClient$Call` 保存工具调用的 `name` 和 `arguments`；`AgentModelClient$Reply` 是包含 `message` 与 `tokens` 的 Java `Record`。
4. 企业助手会话、用户消息和助手运行记录由 `EnterpriseAssistantMapper.xml` 映射到 MySQL 表 `t_ai_chat_session`、`t_ai_chat_message`。
5. Mapper 中包含企业岗位列表与岗位详情查询，SQL 使用 `pos_company_id=#{companyId}` 限定企业范围。
6. Mapper 中存在活动运行状态标记、运行超时回收和会话行锁逻辑；但完整的事务边界及这些 SQL 在 Service 中的调用顺序仍需查看 Service 类。

### Q.2 AgentModelClient：模型供应商选择

可见调用链包含 `IModelProviderService.selectModelProviderList(...)`、Stream `filter(...)` 和 `findFirst()`。因此客户端会从模型供应商配置中筛选一条配置使用。`ModelProvider` 中可见的字段包括 `mppApiUrl`、`mppApiKey`、`mppModelName`、`mppParamsJson` 和 `mppStatus`。

类常量中出现以下回退值：

```text
https://api.deepseek.com/chat/completions
deepseek-chat
```

这些是代码中的默认值线索，**不能据此断定生产环境当前一定使用默认 URL 或 `deepseek-chat`**。供应商具体筛选条件、状态判断及参数 JSON 如何覆盖默认参数，还需要查看 `resolve()` 的实际方法体或对应源码。

### Q.3 AgentModelClient：HTTP 请求构建

本轮输出中可见 `HttpClient`、`HttpRequest`、`HttpResponse`、`connectTimeout`、`followRedirects(NEVER)`、`BodyPublishers.ofString`、`BodyHandlers.ofInputStream`、`POST`、`Content-Type` 和 `Authorization` 等符号。

可见的请求 JSON 字段包括：

```text
model
messages
tools
tool_choice
stream_options.include_usage
temperature
max_tokens
```

其中工具选择策略可见值为 `auto`。请求使用 JSON 内容类型和 Bearer 认证头，响应体通过输入流读取。客户端还包含 URL 解析与校验相关调用（`URI.create`、`getScheme`、`getHost`、`getUserInfo`、`getFragment`）；由于当前只有 `strings` 输出，不能进一步断言所有 URL 校验分支的具体规则。

### Q.4 AgentModelClient：流式响应与工具调用增量

可见的流读取结构包括 `BufferedReader`、`InputStreamReader`、`StandardCharsets.UTF_8`、`readLine()`、`data:`、`[DONE]`、`choices`、`delta`、`content`、`finish_reason` 和 `usage.total_tokens`。这支持如下实现概括：客户端逐行读取模型流，将数据事件解析为 JSON，并从中读取文本增量、工具调用增量和 token 使用信息。

工具调用组装相关符号包括：

```text
tool_calls
index
computeIfAbsent
AgentModelClient$Call
name
function
arguments
```

这说明工具调用会按 `index` 归并多个增量，并在 `Call` 对象中积累名称和参数。因为模型可能分多段返回函数名和 JSON 参数，服务端需要先组装完整调用，再由上层 Agent 编排层校验并执行，而不能把每个流片段直接当作一个完整工具调用。

`AgentModelClient$Reply` 可见字段为 `message` 与 `tokens`。这与“模型客户端负责模型通信、上层服务负责工具执行”的分层设计一致。

### Q.5 超时、输出限制与错误处理线索

本轮可见的标识包括：

```text
MODEL_TIMEOUT
MODEL_STREAM_ERROR
MODEL_RESPONSE_LIMIT
TOOL_CALL_LIMIT
TOOL_ARGUMENT_LIMIT
MODEL_STREAM_INCOMPLETE
INVALID_TOOL_CALL
MAX_OUTPUT_TOKENS
MAX_OUTPUT_CHARS
OutputLimitException
```

另外存在 `ScheduledExecutorService`、`ScheduledFuture`、`deadlineNanos`、线程中断检查等符号，表明客户端实现了截止时间/超时控制，并对模型响应长度、工具调用数量、工具参数长度及不完整流进行防护。

当前输出不能确认这些限制的具体数值，也不能确认所有异常分支是否均以同样方式清理定时任务和关闭流。

### Q.6 企业助手会话与消息：Mapper 的持久化结构

`EnterpriseAssistantMapper.xml` 中出现以下表和字段：

- 会话表：`t_ai_chat_session`，主要字段包括 `acs_id`、`acs_user_id`、`acs_status`、`acs_updated_at`。
- 消息表：`t_ai_chat_message`，主要字段包括 `acm_id`、`acm_session_id`、`acm_role`、`acm_content`、`acm_intent`、`acm_created_at`。

对应 SQL 显示：

- `createSession` 向 `t_ai_chat_session` 插入用户 ID 和状态。
- `insertMessage` 将会话 ID、角色、消息内容和意图标记写入消息表。
- `sessions` 查询会话列表，并按会话 ID 倒序分页，SQL 限制为 21 条。
- `messages` 查询用户和助手消息，使用 `before` 和 `limit` 进行游标式分页；返回结果按消息 ID 倒序排列。
- `request` 将用户消息与对应运行记录关联，关联条件通过 `acm_intent` 中的 `r:<用户消息ID>:` 前缀表达。
- `run` 读取单条助手运行记录，并校验其属于当前用户/企业可访问的会话。

**重要区分：** SQL 证明会话与消息具有数据库持久化能力，但单凭 Mapper 不能证明 Service 每次调用模型时一定会把多少条历史消息放入 prompt。持久化历史和实际送入模型的短期上下文是两个不同的问题。

### Q.7 企业隔离与会话访问控制线索

Mapper 的 `owned` SQL 片段包含：

```sql
s.acs_user_id = #{userId}
and s.acs_status = 7
and exists (
  select 1
  from t_ai_chat_message marker
  where marker.acm_session_id = s.acs_id
    and marker.acm_role = 0
    and marker.acm_intent = concat('enterprise:', #{companyId})
)
```

这表明会话查询不仅按用户 ID 和会话状态过滤，还会检查消息表中是否存在带有当前企业标记的记录。另有 `lockSession` 使用 `FOR UPDATE` 锁定指定用户的有效会话行。

这些 SQL 是企业/用户范围隔离的直接线索，但仍需要核对创建会话时是否总是写入正确的企业标记、Service 是否在所有读写路径上都使用对应校验，以及数据库事务边界是否正确。不要仅凭单个 SQL 片段就宣称整个系统的多租户安全性已被完整审计。

### Q.8 运行状态与超时回收

Mapper 中可见以下行为：

- `active` 统计当前会话中以 `:R` 结尾的助手运行记录。
- `updateRun` 只更新当前仍处于 `:R` 状态的运行记录，并修改内容和状态尾标。
- `expire` 将超过 150 秒且仍处于活动状态的运行标记改为 `F`。
- `sessionColumns` 会查找最近活动运行记录，并将其 ID 作为 `activeRunId` 返回。

这些字段说明系统有运行状态标记和超时清理机制。`R`、`F` 等状态的全部语义、其他可能的状态值以及定时任务如何触发 `expire`，仍需要结合 Service/调度器代码确认。

### Q.9 企业岗位查询工具的数据来源

Mapper 的 `jobs` 查询返回岗位 ID、名称、城市、状态、薪资下限和薪资上限，并支持按岗位名称关键词过滤，最多返回 15 条。

`job` 查询返回岗位详情，包括经验要求、学历要求和岗位描述，并同时限定企业 ID 与岗位 ID；岗位描述通过 `left(cast(pos_jd_json as char), 8000)` 截取最多 8000 个字符。

这为企业助手提供岗位查询工具提供了明确的数据访问依据。后续读取 `EnterpriseAssistantService.class` 后，还发现企业助手内置的工具 schema 名称为 `list_company_jobs(keyword)` 和 `get_company_job(id)`；`AgentTools.class` 则包含面向求职者资料/求职流程的另一组工具名，不能因为类名相近就将两组工具混为一谈。具体工具分支的完整参数校验与 SQL 调用顺序仍需字节码方法体或匹配版本源码确认。

### Q.10 更新后的企业 AI 助手分层图

```text
企业端前端
   │ HTTP / SSE
   ▼
EnterpriseAssistantController
   │
   ▼
EnterpriseAssistantService
   ├─ 会话/消息/运行状态：EnterpriseAssistantMapper → MySQL
   ├─ 工具编排：解析模型 tool_calls，调用 Java 业务工具
   │      └─ 企业岗位列表/详情查询 → EnterpriseAssistantMapper → MySQL
   └─ 模型请求：AgentModelClient
          ├─ 选择 ModelProvider 配置
          ├─ Java HttpClient 发送 JSON POST
          ├─ 读取流式响应并组装文本/工具调用增量
          └─ 返回 Reply(message, tokens)
```

该图是根据控制器、`EnterpriseAssistantService`/`AgentModelClient` 的类符号和 Mapper SQL 汇总出的逻辑分层图。现已能确认服务类具有工具调用步骤/数量限制、历史消息构造、任务执行器和 SSE 事件管理的实现线索；但 `strings` 不能完整还原每个分支的执行顺序、确切循环边界、消息 JSON 的所有字段或事务覆盖范围。

### Q.11 下一步：继续使用完全只读的方式检查

服务器没有 `javap`，而且当前目标是避免改变环境，因此**不安装 JDK、不拉取临时镜像，也不运行任何会修改服务的命令**。`EnterpriseAssistantService` 与 `AgentTools` 的只读 `strings` 输出已取得并在附录 R 分析；若继续核验，应优先对照 GitHub 中与线上 JAR 匹配的源码，而不是重复执行本节命令。

```bash
# 只读取企业助手 Service 中的符号
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/enterprise/service/EnterpriseAssistantService.class \
  | strings

# 只读取工具定义类中的符号
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/system/service/app/ai/AgentTools.class \
  | strings
```

若输出过长，可只在终端输出中筛选关键词（仍然只读）：

```bash
unzip -p /tmp/ruoyi-system-inspect.jar \
  com/ruoyi/enterprise/service/EnterpriseAssistantService.class \
  | strings \
  | grep -Ei 'start|cancel|complete|tool_calls|tool_call_id|messages|insertMessage|updateRun|SseEmitter|STEP|LIMIT|memory|history|company|jobs|job'
```

本轮已通过上述命令获得了企业助手 Service 与工具类的结构证据。`strings` 能补充方法名、关键字段和常量，但无法单独证明循环每一步的确切执行顺序；后续应以匹配版本源码或离线字节码反汇编补足控制流，继续保留证据等级，避免把推断写成已验证事实。

### Q.12 对面试介绍的稳妥表述

> 企业招聘助手采用自定义的 Java Agent 编排方式。模型调用层基于 Java 原生 `HttpClient`，将对话消息和工具定义封装为 JSON 请求，并以流式方式解析模型返回的文本与工具调用增量。模型提出工具调用后，由后端编排层完成参数校验和本地业务执行，再将执行结果关联到对话消息并继续请求模型。会话、消息和运行状态通过 MyBatis Mapper 持久化到 MySQL；岗位查询使用带企业 ID 条件的 SQL，读取企业自身的岗位列表与详情。模型客户端还设置了超时、输出长度和工具参数等限制。

这段介绍与目前已检查的类符号和 SQL 相符。现已确认企业助手 Service 存在工具调用循环相关符号、历史上下文构造线索、任务并发/SSE 管理及限制常量；仍未精确确认的是各分支的完整顺序、实际上下文条数、工具失败时的回退细节和 SSE 每种事件的 payload 格式。


---

## 附录 R：EnterpriseAssistantService 与 AgentTools 的只读核验（2026-10-29）

> **核验方式：** 读取服务器已有 `/tmp/ruoyi-system-inspect.jar` 中的 `EnterpriseAssistantService.class` 与 `AgentTools.class`，执行 `strings`；同时结合前一轮读取的 `EnterpriseAssistantMapper.xml`。本轮未安装任何软件、未拉取镜像、未修改 Compose 或应用配置、未重启线上服务。
>
> **证据边界：** `strings` 能确认符号、方法名、工具名称、字段名和限制常量存在，但不能完整还原 Java 方法体中的条件分支与执行顺序。以下将“已确认的结构”与“仍待确认的细节”分开。

### R.1 企业助手服务的运行结构

`EnterpriseAssistantService.class` 中出现以下组件与字段：

- 并发执行：`ThreadPoolExecutor`、`ArrayBlockingQueue`、`workers`、`streamWorkers`、`ScheduledExecutorService`。
- 运行状态：`ConcurrentHashMap`、`streams`、`live`、`userRuns`、`AtomicBoolean`、`AtomicReference`、`Future`。
- 数据访问：`EnterpriseAssistantMapper`、`DashboardMapper`、`TransactionTemplate`。
- 模型调用：`AgentModelClient`，并调用 `resolve()` 和 `complete(...)`。
- 流式传输：`SseEmitter`、`events`、`event`、`data`、`send`、`keepalive`、`comment`、`heartbeat`。
- 生命周期处理：`onCompletion`、`onTimeout`、`onError`、`cancel`、`close`、`@PreDestroy`、`shutdownNow`。
- 任务控制线索：`deadlineNanos`、`QUEUE_TIMEOUT`、`STEP_LIMIT`、`TOOL_LIMIT`、`EMPTY_REPLY`、`finished`、`progress`。

由此可以较有把握地描述：企业助手服务不只是同步调用一次模型，而是具备专用执行器、运行状态跟踪、流式事件管理、任务取消/结束处理以及限制条件相关实现。线程池具体线程数、队列容量、超时数值、清理顺序仍不能仅凭 `strings` 确认。

### R.2 企业助手的主要方法与数据路径

可见的业务方法包括 `sessions`、`create`、`messages`、`request`、`start`、`events`、`cancel`、`delete`、`snapshot`、`finish`、`touch`、`clean`、`close` 等。

结合 Mapper 的 SQL，当前可确认的职责划分如下：

| 组件/方法线索 | 能够支持的结论 | 仍需注意 |
|---|---|---|
| `sessions`、`create`、`messages` | 企业助手有会话创建、会话列表与消息读取能力 | 页面分页行为与所有参数边界需结合 Controller/前端确认 |
| `request`、`start`、`runId`、`requestId` | 支持提交一次助手请求并创建/关联运行记录 | `requestId` 的完整去重语义需看方法体 |
| `mapper.messages(...)`、`Collections.reverse`、`history`、`context` | 服务端会读取历史消息，并存在将结果反转、构建模型上下文的实现线索 | 具体历史条数、截断规则、是否摘要及 token 预算尚未确认 |
| `TransactionTemplate`、`doInTransaction` | 使用编程式事务处理部分业务逻辑 | 事务边界、提交/回滚条件尚未还原 |
| `lockSession`、`active`、`expire`、`updateRun` | 存在会话并发控制与运行状态管理机制 | 各状态码完整含义仍需结合 SQL 与方法体核实 |
| `events`、`SseEmitter`、`keepalive`、`heartbeat` | 服务端提供 SSE 事件流及保活相关处理 | 事件名称、payload schema 与心跳周期尚未确认 |
| `cancel`、`Future.cancel`、`AtomicBoolean` | 存在运行取消标记与 Future 取消相关逻辑 | 取消是否能中断底层 HTTP 流的每一种情况尚未确认 |

### R.3 企业助手的公司身份与数据范围

`EnterpriseAssistantService` 引用了 `DashboardMapper.selectCompanyIdByUser(userId)`，并出现 `companyId`、`userId` 与企业岗位工具相关字段。这表明服务端会根据当前用户取得企业标识，并将企业标识带入助手业务逻辑。

此前读取的 `EnterpriseAssistantMapper.xml` 中，岗位 SQL 明确使用 `pos_company_id = #{companyId}`；会话归属查询还会检查当前用户、会话状态以及 `enterprise:<companyId>` 标记。

因此，项目介绍可以稳妥地说：**企业助手的岗位查询设计具有企业 ID 范围约束，会话查询也有用户/企业归属校验线索。** 但这不是完整的多租户安全审计；仍应核对每条读写路径是否都执行同样的授权校验。

### R.4 企业助手内置的两个 Function Calling 工具

在 `EnterpriseAssistantService.class` 中直接发现工具 schema：

#### `list_company_jobs`

参数为可选的 `keyword` 字符串。结合 Mapper 的 `jobs` 查询，作用是查询当前企业岗位列表，并支持按岗位标题关键词筛选；SQL 最多返回 15 条。

#### `get_company_job`

参数为必填整数 `id`。结合 Mapper 的 `job` 查询，作用是查询指定岗位详情；SQL 同时限定岗位 ID 和企业 ID，返回城市、薪资、经验要求、学历要求及岗位描述等字段。

类符号还出现 `tool_calls`、`function`、`name`、`arguments`、`tool_call_id`、`role`、`assistant`、`tool`、`step`、`calls`、`STEP_LIMIT` 和 `TOOL_LIMIT`。这支持如下高层描述：

1. 服务端向模型提交可用工具定义；
2. 解析模型返回的工具调用名称与参数；
3. 校验/解析参数并执行服务端业务查询；
4. 关联工具调用 ID 和工具结果，再继续模型处理；
5. 受步骤数量、工具数量及总截止时间等限制约束。

这是基于类符号组合得到的高可信结构结论，但并非逐行控制流还原。面试时可讲清职责分工，不应在未查看方法体前编造精确循环次数、每种异常分支或全部 JSON 字段。

### R.5 SSE、异步任务和取消机制

企业助手服务中存在 `SseEmitter` 与 `ScheduledExecutorService`，并有 `event`、`data`、`send`、`keepalive`、`comment`、`heartbeat` 等符号。还出现 `onCompletion`、`onTimeout`、`onError` 回调及 `cancel`、`Future.cancel`、`finished` 等状态。

可据此介绍：**后端通过 SSE 向前端发送助手运行事件，并为连接生命周期、保活和任务取消提供了相应实现结构。** 由于当前没有完整方法体，尚不能确定所有事件的确切名称、心跳间隔、每个事件的 JSON 格式，以及用户取消时模型 HTTP 连接是否一定立即关闭。

### R.6 `AgentTools` 是另一组工具，不应与企业助手混为一谈

`AgentTools.class` 的构造依赖是：

- `IAppResumeService`
- `IAgentJobService`
- `IAgentApplicationService`

它包含求职者简历、职位和投递申请相关的数据操作符号；可见的工具名称包括：

- `list_resumes`
- `get_resume`
- `search_jobs`
- `get_job_detail`
- `get_application_history`

类中还出现 `resume_analysis`、`job_recommendation`、`interview_preparation`、`writing_polish` 等动作/意图标识，以及 `resumeId`、`applicationId`、`jobId`、`keyword`、`city`、`salaryMin`、`page`、`size`、`sort` 等参数线索。实现符号还包括工具定义构建、允许列表校验、简历字段映射、岗位分页查询与 `refreshCards`。

此外，能看到邮箱、手机号、身份证号等模式的正则表达式。这说明该类包含对这些文本模式进行清理或脱敏的实现线索；仅凭字符串无法确定所有调用路径是否均会执行脱敏。

**归属判断：** 这些依赖和工具名称明显偏向求职者端的 Agent 能力，与企业助手中的 `list_company_jobs`、`get_company_job` 不同。当前没有证据表明企业助手直接调用了这个 `AgentTools` 类；不能把求职者侧的简历分析、岗位推荐工具直接描述成企业助手已经注册的工具。

### R.7 更新后的架构图

```text
E-App / 企业招聘助手
    │
    ▼
EnterpriseAssistantController
    │
    ▼
EnterpriseAssistantService
    ├─ 会话、历史消息、运行状态
    │      └─ EnterpriseAssistantMapper ── MySQL
    ├─ 企业身份与岗位范围
    │      └─ DashboardMapper / companyId
    ├─ Function Calling 编排
    │      ├─ list_company_jobs(keyword)
    │      └─ get_company_job(id)
    ├─ 异步任务、SSE、保活与取消状态
    └─ AgentModelClient
           ├─ 选择模型供应商配置
           ├─ Java HttpClient / Chat Completions 兼容请求
           ├─ 解析流式文本和工具调用增量
           └─ Reply(message, tokens)

求职者侧 Agent 工具（独立类，调用关系待核实）
    └─ AgentTools
           ├─ 简历读取
           ├─ 岗位搜索/详情
           └─ 投递历史
```

### R.8 面试时可以使用的准确表述

> 企业招聘助手的后端采用自定义 Java Agent 编排。`EnterpriseAssistantService` 负责会话和运行状态管理、历史上下文组织、异步任务与 SSE 事件推送，并向模型提供企业岗位查询工具。`AgentModelClient` 基于 Java 原生 `HttpClient` 发送兼容 Chat Completions 的 JSON 请求，逐段解析模型返回的文本和工具调用信息；后端再对工具请求进行处理，调用企业岗位查询逻辑，并受步骤数、工具数、超时和输出限制约束。会话、消息和运行记录通过 MyBatis Mapper 持久化到 MySQL，岗位查询 SQL 带有企业 ID 条件。

> 注意：以上是根据实际部署 JAR 的类符号和 SQL 映射总结的服务端实现结构。若面试官追问精确的循环顺序、历史窗口大小、SSE 事件 payload 或工具异常回退，应以匹配版本源码/方法体为准，不要虚构尚未核验的数值或分支。

