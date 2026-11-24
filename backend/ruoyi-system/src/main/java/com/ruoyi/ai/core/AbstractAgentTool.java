package com.ruoyi.ai.core;

import org.springframework.beans.factory.annotation.Autowired;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * 工具基类：统一 JSON 实例、schema 组装与草稿登记，具体工具只写自己的参数与业务逻辑。
 */
public abstract class AbstractAgentTool implements AgentTool
{
    protected final ObjectMapper json = new ObjectMapper();

    @Autowired
    protected AgentActionStore actionStore;

    /** 组装 type=function 的工具定义。 */
    protected ObjectNode toolDef(String description, ObjectNode parameters)
    {
        ObjectNode tool = json.createObjectNode();
        tool.put("type", "function");
        ObjectNode fn = tool.putObject("function");
        fn.put("name", name());
        fn.put("description", description);
        fn.set("parameters", parameters);
        return tool;
    }

    /** 登记一条草稿并补上 scope / 操作人 / 卡片标题；摘要由工具在拼好返回文本后自行赋值。 */
    protected PendingAction register(ToolContext ctx, String scope, String kind, String title,
            PendingAction action)
    {
        action.scope = scope;
        action.kind = kind;
        action.title = title;
        action.operator = ctx == null ? "system" : ctx.getOperator();
        actionStore.save(action);
        return action;
    }
}
