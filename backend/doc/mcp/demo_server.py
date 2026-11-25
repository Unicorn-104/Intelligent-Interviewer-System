"""最小 MCP stdio 示例服务器：只暴露一个 echo 工具，用于联调 MCP 接入。

启动方式（由后端按 mcp.servers 配置拉起）：
    python backend/doc/mcp/demo_server.py

协议：JSON-RPC 2.0，每行一个 JSON，stdin 读请求、stdout 写响应。
"""

import json
import os
import sys
import datetime


def log_call(name, arguments):
    path = os.path.join(os.environ.get("TEMP", "."), "mcp_demo_calls.log")
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(f"{datetime.datetime.now().isoformat()} {name} {json.dumps(arguments, ensure_ascii=False)}\n")


def respond(request_id, result):
    print(json.dumps({"jsonrpc": "2.0", "id": request_id, "result": result}, ensure_ascii=False), flush=True)


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            continue
        method = request.get("method")
        request_id = request.get("id")
        if method == "initialize":
            respond(request_id, {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "demo", "version": "1.0"},
            })
        elif method == "notifications/initialized":
            continue
        elif method == "tools/list":
            respond(request_id, {
                "tools": [{
                    "name": "echo",
                    "description": "回显传入的文本",
                    "inputSchema": {
                        "type": "object",
                        "properties": {"text": {"type": "string", "description": "要回显的文本"}},
                        "required": ["text"],
                    },
                }],
            })
        elif method == "tools/call":
            arguments = (request.get("params") or {}).get("arguments") or {}
            log_call(request.get("params", {}).get("name", ""), arguments)
            text = str(arguments.get("text", ""))
            respond(request_id, {"content": [{"type": "text", "text": "echo: " + text}], "isError": False})
        elif request_id is not None:
            respond(request_id, {"content": [], "isError": True})


if __name__ == "__main__":
    main()
