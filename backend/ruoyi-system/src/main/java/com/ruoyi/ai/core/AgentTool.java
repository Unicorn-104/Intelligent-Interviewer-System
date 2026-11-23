package com.ruoyi.ai.core;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * 一个可被模型调用的能力。只读工具与写提案工具同形，区别在于返回的 ToolResult 是否带草稿。
 */
public interface AgentTool
{
    /** 工具名，模型据此调用；同一端内必须唯一。 */
    String name();

    /** 给模型看的完整定义（type=function）。 */
    ObjectNode definition(ObjectMapper json);

    ToolResult execute(ToolContext ctx, JsonNode args);
}
