package com.ruoyi.ai.mcp;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.ai.core.AgentTool;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;

/**
 * MCP 工具注册表：按配置启动外部 MCP Server，拉取 tools/list 并按白名单注册为 AgentTool。
 *
 * <p>默认关闭；未配置 allowTools 的 Server 不会被注册，避免把任意本地进程能力暴露给模型。</p>
 */
@Component
public class McpToolRegistry
{
    private static final Logger logger = LoggerFactory.getLogger(McpToolRegistry.class);

    private final ObjectMapper json = new ObjectMapper();

    private final List<AgentTool> tools = new CopyOnWriteArrayList<>();

    private final List<McpStdioClient> clients = new CopyOnWriteArrayList<>();

    private final McpServerProperties properties;

    public McpToolRegistry(McpServerProperties properties)
    {
        this.properties = properties;
    }

    @PostConstruct
    public void init()
    {
        if (!properties.isEnabled())
        {
            logger.info("MCP disabled");
            return;
        }
        for (McpServerProperties.Server server : properties.getServers())
        {
            if (server.getAllowTools() == null || server.getAllowTools().isEmpty())
            {
                logger.warn("MCP server {} skipped: allowTools empty", server.getName());
                continue;
            }
            try
            {
                McpStdioClient client = new McpStdioClient(server.getCommand(), server.getArgs(), server.getWorkDir(),
                        server.isInheritEnv(), server.getEnv(), server.getTimeoutSeconds());
                clients.add(client);
                client.request("initialize", initializeParams());
                client.notify("notifications/initialized", null);
                JsonNode response = client.request("tools/list", null);
                JsonNode remoteTools = response.path("result").path("tools");
                int registered = 0;
                for (JsonNode remote : remoteTools)
                {
                    String name = remote.path("name").asText("");
                    if (name.isEmpty() || !server.getAllowTools().contains(name))
                    {
                        continue;
                    }
                    tools.add(new McpToolAdapter(server.getName(), name,
                            remote.path("description").asText(""), remote.path("inputSchema"), client));
                    registered++;
                }
                logger.info("MCP server {} registered {} tool(s)", server.getName(), registered);
            }
            catch (Exception e)
            {
                logger.warn("MCP server {} init failed: {}", server.getName(), e.getMessage());
            }
        }
    }

    private ObjectNode initializeParams()
    {
        ObjectNode params = json.createObjectNode();
        params.put("protocolVersion", "2024-11-05");
        params.putObject("capabilities");
        ObjectNode clientInfo = params.putObject("clientInfo");
        clientInfo.put("name", "ruoyi-admin");
        clientInfo.put("version", "1.0");
        return params;
    }

    public List<AgentTool> tools()
    {
        return tools;
    }

    @PreDestroy
    public void close()
    {
        clients.forEach(McpStdioClient::close);
        clients.clear();
        tools.clear();
    }
}
