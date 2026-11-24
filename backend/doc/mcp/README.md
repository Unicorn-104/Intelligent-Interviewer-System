# 管理端 AI 助手 MCP 接入

后台助手支持把外部 **MCP Server**（Model Context Protocol，stdio 传输）的工具注册为可调用工具。
实现位于 `ruoyi-system` 的 `com.ruoyi.ai.mcp`：`McpServerProperties` / `McpStdioClient` /
`McpToolRegistry` / `McpToolAdapter`，由 `AdminToolPackage` 合并进管理端工具包。

## 安全边界

- **默认关闭**：`mcp.enabled=false` 时不启动任何外部进程。
- **白名单**：每个 Server 必须配置 `allow-tools`，未列出的工具不会暴露给模型；未配置白名单的 Server 直接跳过。
- **只读接入**：适配器只转发 `tools/call`，不会产生本地写操作或待确认草稿；外部工具的写行为由该 Server 自己负责，接入方需自行确认其安全性。
- **进程环境**：MCP Server 子进程继承后端 JVM 的环境变量（可能包含数据库口令、模型密钥等），因此只应配置可信的本地 server，不要接入来源不明的脚本。
- **本系统写库仍走草稿**：题目、企业等写操作仍由内置工具 + 用户点卡片确认完成，MCP 工具不参与。

## 配置

```yaml
mcp:
  enabled: true
  servers:
    - name: demo                 # 工具前缀来源，最终工具名为 mcp_demo_<tool>
      command: C:\Windows\py.exe # 可执行文件，建议绝对路径
      work-dir: C:\path\to\project
      args:
        - -X
        - utf8
        - backend/doc/mcp/demo_server.py
      allow-tools:               # 只注册白名单内的工具
        - echo
      timeout-seconds: 30
```

未配置 `work-dir` 时，子进程继承后端 JVM 的工作目录（`backend/`），相对路径参数会按该目录解析。

## 工具命名

`mcp_<serverName>_<toolName>`，非字母数字字符替换为下划线，单段最长 40 字符。
模型侧看到的描述带 `[MCP 外部工具]` 前缀，便于区分内置工具。

## 联调与排障

```bash
# 1. 起一个最小示例 server（也可由后端按配置拉起）
python backend/doc/mcp/demo_server.py
```

- 启动日志出现 `MCP server <name> registered N tool(s)` 表示注册成功。
- `MCP server <name> init failed` 常见原因：命令不存在、脚本路径不对、子进程启动即退出。
- 调用日志：`MCP tool mcp_xxx executed, isError=...`；示例 server 另会把调用写入 `%TEMP%\mcp_demo_calls.log`。
- 助手只有在问题命中工具链触发词时才携带工具定义；直接问"调用 echo 工具"会命中 `mcp` 关键词。

## 关闭

把 `mcp.enabled` 改回 `false` 并重启后端即可，进程随应用关闭（`@PreDestroy` 中销毁）。
