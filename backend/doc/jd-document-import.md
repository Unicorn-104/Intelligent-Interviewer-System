# 企业端 JD 文档解析（后端）

## 当前阶段

后端实现、清理编译、两组Mock测试和无Key接口验证已完成；尚未执行真实模型调用。真实LLM联调等待用户明确确认密钥配置完成后进行。

## 接口

`POST /enterprise/jd/parse-document`，`multipart/form-data`，字段 `file`，每次仅一个 PDF 或 DOCX。

接口要求已登录的企业角色或超级管理员；普通账号还必须存在审核通过的企业绑定。接口返回 `AjaxResult.data` 中的 JD 草稿，不创建岗位，不调用岗位或技能写入，不持久保存附件。

草稿标量字段：`title`、`dept`、`city`、`salaryMin`、`salaryMax`、`experience`、`education`、`jobType`、`summary`；列表字段：`responsibilities`、`requirements`、`softRequirements`、`skills`、`warnings`。技能为 `{name, required}`，`required` 未知为 NULL。金额为人民币元/月。用户核对后，仍通过已有岗位发布接口确认保存。

## 文档范围

PDF 复用现有 `ResumePdfParser`，沿用现有大小、页数、文件头、加密和 OCR 约束，不修改简历配置。DOCX 使用现有 POI，提取段落、表格文字；限制上传体积、ZIP条目数及解压规模，拒绝伪装格式和含宏文档。旧 `.doc` 提示转换为 PDF/DOCX。

DOCX 的页数只可从文档元数据读取，无法保证等于实际排版页数。有声明且超过既有限制时拒绝；无有效页数元数据时按大小与文本长度限制，并返回明确警告。图片型Word不做OCR，建议转换为PDF。文档缺少的信息不靠模型猜测。

## 模型配置

将 `jd-ai-config.example.yml` 中的配置段合入已加载的私有 `application.yml`。本地已添加同样配置段，主配置被根 `.gitignore` 排除。真实密钥放在后端启动进程的 `ANTHROPIC_AUTH_TOKEN` 环境变量中，不放入文档、Git、请求体或前端。

`JdAiProperties` 绑定 `app.jd.ai.*`。基础地址默认 `https://api.deepseek.com/anthropic`，实际发送 `/v1/messages`；使用 `x-api-key`、`anthropic-version: 2023-06-01`、JDK `HttpClient`，默认60秒。请求模型为 `deepseek-v4-pro`，`max_tokens=4096`，非流式。响应只读 `content[0].text`，不采用 OpenAI `choices` 或 `response_format`。

空密钥返回 `ServiceException("后端尚未配置模型密钥")`，不调用模型。解析服务启用与手动发布互不依赖。配置环境变量后需让后端进程继承新环境再启动，旧进程不会自动获得新增变量。

## 已执行验证

1. `mvn clean compile -DskipTests`：七个模块通过，耗时25.060秒。
2. `JdAiStructurerTest`、`JdDocumentServiceImplTest`：各9项，共18项通过，失败和错误均为0；HTTP客户端和AI均为Mock，不调用真实模型。首轮金额测试因15000.50与15000.5的字符串表示差异失败，已改为数值比较并保留小数位约束，重跑通过。
3. 已打包并以空Key启动后端；使用PowerShell `curl.exe`、真实企业登录态上传1292字节的合成DOCX，实际HTTP 200，业务响应为 `{"msg":"后端尚未配置模型密钥","code":500}`。响应不含堆栈，后端没有NPE或启动失败。
4. 无Key时在文档提取前返回配置提示；真实curl的DOCX文本提取与LLM完整链路尚未验证。文档提取已有合成文档单元测试覆盖。

## 待执行验证

用户明确确认环境变量配置完成后，再验证真实PDF/DOCX的提取、LLM编排和草稿响应，并确认不新增岗位、技能记录。无Key验证进程使用过 `--app.jd.ai.api-key=` 强制空值；真实联调重启时必须移除该参数，避免覆盖环境变量。

本阶段不修改任何前端文件、已有 JD 解析实现或简历 AI 配置，不增加 Maven 依赖，也不进行数据库迁移。
