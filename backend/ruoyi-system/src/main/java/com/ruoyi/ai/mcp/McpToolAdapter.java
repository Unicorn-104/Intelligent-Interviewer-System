package com.ruoyi.ai.mcp;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.ai.core.AgentTool;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * 把一个 MCP Server 暴露的工具适配成本系统的 AgentTool。
 *
 * <p>只读语义：适配器只转发 tools/call，不产生本地写操作；是否允许使用由 allowTools 白名单控制。</p>
 */
public class McpToolAdapter implements AgentTool
{
    private static final Logger logger = LoggerFactory.getLogger(McpToolAdapter.class);

    private final String exposedName;

    private final String remoteName;

    private final String description;

    private final JsonNode inputSchema;

    private final McpStdioClient client;

    public McpToolAdapter(String serverName, String remoteName, String description, JsonNode inputSchema,
            McpStdioClient client)
    {
        this.remoteName = remoteName;
        this.exposedName = "mcp_" + clean(serverName) + "_" + clean(remoteName);
        this.description = description;
        this.inputSchema = inputSchema;
        this.client = client;
    }

    private static String clean(String value)
    {
        String cleaned = value == null ? "" : value.replaceAll("[^A-Za-z0-9_]", "_");
        if (cleaned.length() > 40)
        {
            cleaned = cleaned.substring(0, 40);
        }
        return cleaned.isEmpty() ? "tool" : cleaned;
    }

    @Override
    public String name()
    {
        return exposedName;
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode tool = json.createObjectNode();
        tool.put("type", "function");
        ObjectNode fn = tool.putObject("function");
        fn.put("name", exposedName);
        String desc = description == null || description.isBlank() ? "外部 MCP 工具" : description;
        fn.put("description", "[MCP 外部工具] " + desc);
        if (inputSchema != null && inputSchema.isObject())
        {
            fn.set("parameters", inputSchema);
        }
        else
        {
            ObjectNode params = json.createObjectNode();
            params.put("type", "object");
            params.putObject("properties");
            fn.set("parameters", params);
        }
        return tool;
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        try
        {
            ObjectNode params = new com.fasterxml.jackson.databind.ObjectMapper().createObjectNode();
            params.put("name", remoteName);
            params.set("arguments", args == null ? new com.fasterxml.jackson.databind.ObjectMapper().createObjectNode()
                    : args);
            JsonNode response = client.request("tools/call", params);
            JsonNode result = response.path("result");
            logger.info("MCP tool {} executed, isError={}", exposedName, result.path("isError").asBoolean(false));
            StringBuilder text = new StringBuilder();
            JsonNode content = result.path("content");
            if (content.isArray())
            {
                for (JsonNode item : content)
                {
                    if ("text".equals(item.path("type").asText("")))
                    {
                        text.append(item.path("text").asText("")).append('\n');
                    }
                }
            }
            if (text.length() == 0 && result.has("structuredContent"))
            {
                text.append(result.path("structuredContent").toString());
            }
            if (text.length() == 0)
            {
                text.append(response.toString());
            }
            if (result.path("isError").asBoolean(false))
            {
                return ToolResult.read("[MCP 工具返回错误] " + text.toString().trim());
            }
            return ToolResult.read(text.toString().trim());
        }
        catch (Exception e)
        {
            return ToolResult.read("MCP 工具调用失败：" + e.getMessage());
        }
    }
}
