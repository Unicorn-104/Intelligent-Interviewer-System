# PDF 简历解析与原文件存储

## 使用流程

简历页选择「上传 PDF 简历」→ 提取文字/OCR → DeepSeek 语义编排 → 对照原文核对结构化信息 → 保存。
保存会一次提交修正后的信息和原 PDF；取消编辑不会创建简历或保存原 PDF。
编辑已保存简历只修改结构化信息，不覆盖原 PDF；列表和编辑页显示已保存的文件名。

## 解析配置

配置文件：`backend/ruoyi-system/src/main/resources/resume-pdf.properties`。
修改打包默认配置后需要重新打包、重启后端；可通过 Spring 配置、命令行或环境变量覆盖。

本机 AI 配置使用 `backend/config/application.yml`，已加入 Git 忽略。将 DeepSeek 密钥填写到 `app.resume.structure.api-key` 的双引号内，从 `backend/` 启动时自动加载；修改此私有文件后只需重启后端，无需重新打包。空模板见 [application.example.yml](../backend/config/application.example.yml)，不要把真实密钥填写到示例文件。

| 配置 | 默认值 | 用途 |
| --- | --- | --- |
| `app.resume.pdf.parser` | `AUTO` | `AUTO` 逐页提取文本，文本不足的页走 OCR；`OCR` 全页 OCR；`TEXT` 只提取文本层 |
| `app.resume.pdf.dpi` | `220` | OCR 渲染精度，范围 100–300 |
| `app.resume.pdf.page-seg-mode` | `3` | Tesseract 自动版面分析；单块正文可选 6 |
| `app.resume.pdf.language` | `chi_sim+eng` | 简体中文和英文模型 |
| `app.resume.pdf.tessdata-directory` | 空 | 使用打包的模型；填写时使用本机指定模型目录 |
| `app.resume.pdf.storage-directory` | 空 | 默认使用 `ruoyi.profile` 的同级 `resume-pdf` 目录 |
| `app.resume.pdf.max-size-mb` / `max-pages` | `10` / `8` | 上传大小和页数限制，允许下调 |
| `app.resume.pdf.max-concurrent-parses` | `2` | 并发识别上限；繁忙时返回可重试提示 |

环境变量：`RESUME_PDF_PARSER`、`RESUME_OCR_TESSDATA`、`RESUME_PDF_STORAGE`。
例如强制 OCR：`$env:RESUME_PDF_PARSER = 'OCR'`，在同一个终端启动后端。
Pandoc 不提供 PDF 输入解析器，本阶段采用 PDFBox 与 Tesseract；解析入口接口为
`ResumePdfParser`，便于后续扩展及管理员配置接入。
简历模块固定使用 Tess4J 5.19.0，避开 5.20.0 在 Windows 初始化原生库时的
`Invalid memory access` 兼容问题（上游 issue #286）。原生访问错误转换为业务提示，
不会将 Java 堆栈作为上传提示返回。

## AI 编排配置与字段映射

AI 编排使用同一个配置文件中的 `app.resume.structure.*`，默认开启。
后端将提取文字发送给已配置的 DeepSeek `deepseek-chat`，按内容语义识别经历，
不要求原 PDF 使用「教育经历」「工作经历」等固定小标题。

| 配置 | 默认值 | 用途 |
| --- | --- | --- |
| `app.resume.structure.enabled` | `true` | OCR 后调用 API；显式关闭时采用旧规则并提示核对 |
| `app.resume.structure.api-url` | `https://api.deepseek.com/chat/completions` | 可覆盖的 API 地址 |
| `app.resume.structure.model` | `deepseek-chat` | 编排模型 |
| `app.resume.structure.api-key` | 环境变量注入 | 通过 `RESUME_STRUCTURE_API_KEY` 设置，禁止填入受版本控制的配置 |
| `app.resume.structure.timeout-seconds` | `60` | 模型调用超时 |
| `app.resume.structure.max-tokens` / `max-input-chars` | `8192` / `40000` | 输出预算及输入长度上限，超过输入限制不截断原文 |

相关环境变量：`RESUME_STRUCTURE_ENABLED`、`RESUME_STRUCTURE_API_URL`、
`RESUME_STRUCTURE_MODEL`、`RESUME_STRUCTURE_API_KEY`。
手动启动时在后端终端交互输入密钥，避免写入命令历史：

```powershell
$secureResumeApiKey = Read-Host '请输入简历编排 API 密钥' -AsSecureString
$resumeApiCredential = [System.Management.Automation.PSCredential]::new('resume-api', $secureResumeApiKey)
$env:RESUME_STRUCTURE_API_KEY = $resumeApiCredential.GetNetworkCredential().Password
```

模型采用 JSON Output，输出 `jobDirection`、`educations`、`works`、`projects`、`skills`，
分别对应现有主表求职方向和教育、工作、项目、技能明细表。
数据库用户 ID、简历 ID、附件路径和是否默认始终由服务器及用户确认决定，模型额外输出这些字段时直接忽略。
账号资料不会被 PDF 内容自动覆盖。

未知学历、技能水平、日期等保留为 `null`，不能自动猜为本科或「熟悉」。
AI 参考后端字段编排，后端宽松映射并直接填充：接受常见字段别名、数据库列名、中文学历、字符串数值、年月/中文日期、单个经历对象和技能字符串。
无法转换的学历、绩点、日期等保留为空并保留原值；其余经历正常填入，不整份拒绝。过长字段按数据库长度保存摘要，完整内容继续保留。
学历和技能数值按数据库枚举转换；不要求每次响应完全符合严格 JSON 字段列表，额外字段不影响已识别内容。
无法映射的证书、自我介绍等通过 `unmappedText` 展示；该部分目前不另建数据库表，原内容保存在原 PDF。
疑点通过 `parseWarnings` 返回；页面显示简明核对提示，不直接展示技术诊断。
AI 结果仅供辅助，用户仍须逐项核对。

只有响应无法解析为 JSON 或没有任何可填充经历时，Agent 根据原文和字段要求自动修正并重试一次。
成功后直接填入教育、工作、项目和技能卡片，用户无需重新点击「添加」录入已识别内容。
超时、鉴权失败或修正后仍无有效结果时返回失败并保留所选 PDF 的重试入口，
不打开空白编辑页，也不把空草稿伪装为成功。解析阶段不写数据库、不存原 PDF。

## 本地存储及数据库

沿用头像的本地磁盘存储方式，PDF 使用「用户 ID / 年 / 月 / 日 / 随机文件名.pdf」目录。
例如公开头像根目录为 `D:/ruoyi/uploadPath` 时，私有 PDF 默认保存到
`D:/ruoyi/resume-pdf/<userId>/2026/10/13/<uuid>.pdf`。
自定义目录必须位于公开上传目录之外，避免 `/profile/**` 匿名读取简历。
数据库保存相对文件引用，不保存文件内容或绝对磁盘路径。

复用 `t_res_base.rbs_file_path`、`rbs_file_name`、`rbs_file_size`；这些字段来自现有
`backend/doc/migration_resume_management_20261008.sql`。
若本机数据库还未升级，可执行仅补充上述三个字段的幂等脚本：
`backend/doc/migration_capp_resume_pdf_20261013.sql`。
回滚代码时保留字段及原文件，避免影响其他客户端的数据。

新增 PDF 的下载使用 C-APP 的鉴权接口；其他客户端现有的
`/common/download/resource` 不能读取新的私有文件引用，尚未为其他客户端增加下载适配。
已存在的 `/profile/...pdf` 附件仍可在校验当前用户归属后通过 C-APP 读取。

## 接口和字段

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| POST | `/app/resumes/parse-pdf` | multipart `file`，提取文字后调用 AI，返回草稿及原文；不落盘、不落库 |
| POST | `/app/resumes/import-pdf` | multipart `file` + `resume`（application/json），确认后创建简历并保存 PDF |
| POST | `/app/resumes/{resumeId}/import-pdf` | 同上，校验所有权后替换该简历 PDF 和结构化信息 |
| GET | `/app/resumes/{resumeId}/pdf` | 携带 Bearer Token，只允许本人读取，返回 application/pdf |
| DELETE | `/app/resumes/{resumeId}` | 携带 Bearer Token 软删除本人简历；已关联投递/人才档案时拒绝删除 |

保存和列表响应增加 `fileName`、`fileSize`、`pdfUrl`；无附件时为空。
简历列表对已保存的原始 PDF 显示文件名入口，点击后调用本人鉴权接口在 App 内预览，支持捏合缩放、翻页和重试；无附件的简历不显示入口。
预览 PDF 以 Bearer Token 请求现有读取接口，不向系统浏览器暴露私有文件地址；客户端最多接收 10 MB，并在页面关闭时释放文档资源。
自动导入成功草稿的 `structureMethod` 为 AI，另包含 `unmappedText` 和 `parseWarnings`；这些诊断字段不参与保存。客户端拒绝未完成 AI 编排的导入草稿。
不接收客户端指定服务器路径；普通 JSON 保存忽略附件元数据并保留已有附件。
PDF 替换成功提交后清理旧文件，数据库回滚时清理新文件。
删除简历会先锁定并校验所有权；已被投递记录或人才档案引用的简历拒绝删除以保留历史流程。未被引用的简历软删除并清理经历明细，默认简历删除后自动将最近更新的其他简历设为默认；原始 PDF 在事务提交后删除，回滚时保留。
简历内容和识别原文不进入操作审计的请求、响应日志。

## 验证

- `mvn -B -ntp package`：后端编译、打包及现有测试。
- `flutter analyze --no-pub`、`flutter test --no-pub`。
- 解析测试使用合成文本 PDF 和扫描 PDF，实际执行打包模型 OCR；样例在
  `backend/ruoyi-system/target/resume-pdf-samples/`。
- 数据库测试在 H2 的 MySQL 模式下执行真实 MyBatis Mapper 和事务，验证字段对齐、
  原始字节、普通编辑保留附件、越权、路径校验、替换及失败回滚。
- 客户端测试在本地 HTTP 服务验证 multipart JSON、中文文件名、PDF 字节及响应字段。
- 原始 PDF 预览测试验证 Bearer 鉴权、401、越权/不存在、异常响应、重定向、PDF 文件头及 10 MB 上限。
- AI 测试用本地模拟服务验证不同标题的字段映射、日期与枚举、超长内容保留、
  超时、限流/鉴权失败、不完整 JSON，以及失败时保留原文。
- 获得授权后的实际 DeepSeek 验证仅发送合成简历，不输出密钥、请求原文或模型原文。
- 设备验收：上传样例 → 核对 → 保存 → 返回列表 → 再次编辑；确认原 PDF 标识仍存在。
